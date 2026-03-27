#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import readline from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';

import { chromium } from 'playwright';

const requiredEnv = [
  'CLUBSPARK_EMAIL',
  'CLUBSPARK_PASSWORD',
  'LTA_USERNAME',
  'LTA_PASSWORD',
];

for (const name of requiredEnv) {
  if (!process.env[name]) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(1);
  }
}

const outputTarget = process.env.CLUBSPARK_OUTPUT ?? './clubspark-members-export.csv';
const outputPath = outputTarget === '-' ? null : path.resolve(outputTarget);
const headless = process.env.HEADLESS === 'true';
const slowMo = Number(process.env.SLOW_MO ?? '100');
const membersUrl =
  process.env.CLUBSPARK_MEMBERS_URL ??
  'https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Membership/Members';
const providedCookieHeader = (process.env.CLUBSPARK_COOKIE_HEADER ?? '').trim();
const providedUserAgent = (process.env.CLUBSPARK_USER_AGENT ?? '').trim();

const launchOptions = {
  headless,
  slowMo,
  args: ['--disable-dev-shm-usage', '--no-sandbox'],
};

function parseCookieHeader(header) {
  return String(header)
    .split(/;\s*/)
    .map((part) => {
      const separatorIndex = part.indexOf('=');
      if (separatorIndex <= 0) {
        return null;
      }
      return {
        name: part.slice(0, separatorIndex).trim(),
        value: part.slice(separatorIndex + 1),
      };
    })
    .filter(Boolean);
}

async function applyCookieHeaderToContext(context, url, cookieHeader) {
  const cookies = parseCookieHeader(cookieHeader).map(({ name, value }) => ({
    name,
    value,
    url,
  }));

  if (!cookies.length) {
    return 0;
  }

  await context.addCookies(cookies);
  return cookies.length;
}

if (process.env.PLAYWRIGHT_CHANNEL) {
  launchOptions.channel = process.env.PLAYWRIGHT_CHANNEL;
}

for (const candidate of [
  process.env.PLAYWRIGHT_EXECUTABLE_PATH,
  '/usr/bin/chromium-browser',
  '/usr/bin/chromium',
]) {
  if (!candidate) continue;
  try {
    await fs.access(candidate);
    launchOptions.executablePath = candidate;
    break;
  } catch {
    // Try the next candidate path.
  }
}

const browser = await chromium.launch(launchOptions);

const contextOptions = {
  acceptDownloads: true,
  viewport: { width: 1440, height: 1000 },
};

if (providedUserAgent) {
  contextOptions.userAgent = providedUserAgent;
}

const context = await browser.newContext(contextOptions);

if (providedCookieHeader) {
  const cookieCount = await applyCookieHeaderToContext(context, membersUrl, providedCookieHeader);
  if (cookieCount) {
    console.error(`[clubspark-members-export] Applied ${cookieCount} cookies from reusable auth session`);
  }
}

const page = await context.newPage();
const rl = readline.createInterface({ input, output });

function logStage(message) {
  console.error(`[clubspark-members-export] ${message}`);
}

async function textSnapshot() {
  return page.evaluate(() => ({
    url: location.href,
    title: document.title || '',
    bodyText: document.body ? document.body.innerText.slice(0, 2000) : '',
  }));
}

async function ensureNotBlocked(stage) {
  const snapshot = await textSnapshot();
  const combined = `${snapshot.title}\n${snapshot.bodyText}`;

  if (/Attention Required!|Sorry, you have been blocked|Cloudflare/i.test(combined)) {
    throw new Error(
      `Cloudflare blocked access at ${stage}.\nURL: ${snapshot.url}\nTitle: ${snapshot.title}`,
    );
  }
}

async function waitForIdle() {
  try {
    await page.waitForLoadState('networkidle', { timeout: 15000 });
  } catch {
    // Some pages keep background requests open. This is non-fatal.
  }
}

async function waitForAnySelector(selectors, timeout = 60000) {
  return Promise.any(
    selectors.map((selector) =>
      page
        .waitForSelector(selector, { state: 'visible', timeout })
        .then(() => selector),
    ),
  );
}

async function waitForInitialLoginState(timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await page.locator('#Email').isVisible().catch(() => false)) {
      return 'clubspark-email';
    }
    if (await page.locator('input[placeholder="Username"]').isVisible().catch(() => false)) {
      return 'lta-username';
    }
    if (await page.getByRole('button', { name: /^Login$/ }).first().isVisible().catch(() => false)) {
      return 'lta-login-button';
    }
    if (await page.getByText('Login with another method', { exact: true }).isVisible().catch(() => false)) {
      return 'alternate-login-link';
    }
    await page.waitForTimeout(250);
  }
  return null;
}

async function clickIfVisible(selector) {
  const locator = page.locator(selector).first();
  if (await locator.isVisible().catch(() => false)) {
    await locator.click();
    await waitForIdle();
    return true;
  }
  return false;
}

async function clickLocatorIfVisible(locator) {
  if (await locator.isVisible().catch(() => false)) {
    await locator.click();
    await waitForIdle();
    return true;
  }
  return false;
}

async function dismissCookieBanner() {
  const selectors = [
    'button.osano-cm-denyAll',
    'button.osano-cm-accept-all',
    'button.osano-cm-dialog__close',
  ];

  for (const selector of selectors) {
    if (await clickIfVisible(selector)) {
      logStage(`Dismissed cookie banner via ${selector}`);
      return true;
    }
  }

  return false;
}

async function submitLtaLoginChooserIfVisible() {
  const locator = page.locator('button[name="idp"][value="LTA2"]').first();
  if (!(await locator.isVisible().catch(() => false))) {
    return false;
  }

  try {
    await locator.click({ force: true, timeout: 10000 });
  } catch {
    await locator.evaluate((button) => {
      const form = button.closest('form');
      if (!form) {
        button.click();
        return;
      }
      if (typeof form.requestSubmit === 'function') {
        form.requestSubmit(button);
        return;
      }
      form.submit();
    });
  }

  await waitForIdle();
  return true;
}

async function isAuthenticatedMembersPage() {
  const snapshot = await textSnapshot();
  return (
    /\/Admin\/Membership\/Members(?:[/?#]|$)/i.test(snapshot.url)
    && /members-table|Contact Options|Reset filters|Export CSV|Membership/i.test(snapshot.bodyText)
    && !/Sign in|Log in/i.test(snapshot.title)
  );
}

async function getDirectExportRequest() {
  await page.waitForFunction(() => {
    const jq = window.jQuery;
    const appSettings = window.clubHouseApp?.AppSettings;

    if (!jq?.fn?.DataTable || !appSettings?.contactsTableEndPoint) {
      return false;
    }

    try {
      const params = jq('#members-table').DataTable().ajax.params();
      return Boolean(params && typeof params === 'object');
    } catch {
      return false;
    }
  }, { timeout: 30000 }).catch(() => null);

  return page.evaluate(() => {
    const jq = window.jQuery;
    const appSettings = window.clubHouseApp?.AppSettings;
    const inlineEndpoint = Array.from(document.scripts)
      .map((script) => script.textContent || '')
      .map((text) => text.match(/contactsTableEndPoint\s*=\s*"([^"]+)"/))
      .find(Boolean)?.[1];
    const endpointPath = appSettings?.contactsTableEndPoint || inlineEndpoint;

    if (!jq?.fn?.DataTable) {
      throw new Error('Members DataTable was not available on the ClubSpark members page.');
    }

    if (!endpointPath) {
      throw new Error('ClubSpark contactsTableEndPoint was not available on the members page.');
    }

    const params = jq('#members-table').DataTable().ajax.params();
    if (!params || typeof params !== 'object') {
      throw new Error('ClubSpark members DataTable params were not available.');
    }

    return {
      endpoint: new URL(
        endpointPath.replace('Lookup', 'Export'),
        location.origin,
      ).toString(),
      form: {
        ...params,
        SelectAll: 'True',
      },
    };
  });
}

try {
  logStage(`Opening ${membersUrl}`);
  await page.goto(membersUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForIdle();
  await ensureNotBlocked('initial page load');
  await dismissCookieBanner();
  logStage(`Initial page loaded: ${page.url()}`);

  const reusedAuthenticatedSession =
    Boolean(providedCookieHeader) && await isAuthenticatedMembersPage();

  if (reusedAuthenticatedSession) {
    logStage('Reused provided authenticated ClubSpark session');
  }

  const initialSelector = reusedAuthenticatedSession ? null : await waitForInitialLoginState(15000);

  if (!reusedAuthenticatedSession && !initialSelector) {
    if (headless || !process.stdin.isTTY || !process.stdout.isTTY) {
      throw new Error('Login form not detected automatically in non-interactive mode.');
    }
    console.error('Login form not detected automatically.');
    console.error('If ClubSpark or Cloudflare needs manual interaction, complete it in the browser window.');
    await rl.question('Press Enter when the ClubSpark or LTA login form is visible...');
  }

  await ensureNotBlocked('before ClubSpark login');

  if (!reusedAuthenticatedSession) {
    let openedLtaLogin = false;

    if (
      (await submitLtaLoginChooserIfVisible())
      || (await clickLocatorIfVisible(page.getByRole('button', { name: /^Login$/ }).first()))
    ) {
      logStage('Submitted LTA chooser');
      await page.waitForURL(/mylta\.my\.site\.com/i, { timeout: 60000 }).catch(() => null);
      await ensureNotBlocked('after opening LTA login form');
      logStage(`LTA login page reached: ${page.url()}`);
      openedLtaLogin = true;
    }

    if (
      !openedLtaLogin
      && (await clickLocatorIfVisible(page.getByText('Login with another method', { exact: true })))
    ) {
      logStage('Opened alternate login method');
      await ensureNotBlocked('after opening alternate login method');

      if (
        (await submitLtaLoginChooserIfVisible())
        || (await clickLocatorIfVisible(page.getByRole('button', { name: /^Login$/ }).first()))
      ) {
        logStage('Submitted LTA chooser after alternate login');
        await page.waitForURL(/mylta\.my\.site\.com/i, { timeout: 60000 }).catch(() => null);
        await ensureNotBlocked('after opening LTA login form');
        logStage(`LTA login page reached: ${page.url()}`);
        openedLtaLogin = true;
      }
    }

    if (await page.locator('#Email').isVisible().catch(() => false)) {
      logStage('Submitting ClubSpark email/password form');
      await page.fill('#Email', process.env.CLUBSPARK_EMAIL);
      await page.fill('#Password', process.env.CLUBSPARK_PASSWORD);
      await Promise.all([
        page.waitForNavigation({ waitUntil: 'networkidle', timeout: 60000 }).catch(() => null),
        page.click("button[type='submit']"),
      ]);
    }

    await waitForIdle();
    await ensureNotBlocked('after ClubSpark login submit');

    const ltaSelector = await waitForAnySelector(
      [
        'input[id*="username"]',
        'input[name="username"]',
        '#username',
        'input[placeholder="Username"]',
        'input[aria-label="Username"]',
      ],
      30000,
    ).catch(() => null);

    if (ltaSelector) {
      logStage(`Submitting LTA username/password form via ${ltaSelector}`);
      await page.fill(ltaSelector, process.env.LTA_USERNAME);

      const passwordSelector = await waitForAnySelector(
        [
          'input[id*="password"]',
          'input[name="password"]',
          '#password',
          'input[placeholder="Password"]',
          'input[aria-label="Password"]',
        ],
        10000,
      );
      await page.fill(passwordSelector, process.env.LTA_PASSWORD);

      const logInButton = page.getByRole('button', { name: /^Log in$/ }).first();
      if (await logInButton.isVisible().catch(() => false)) {
        await Promise.all([
          page.waitForNavigation({ waitUntil: 'networkidle', timeout: 60000 }).catch(() => null),
          logInButton.click(),
        ]);
      } else {
        const submitSelector = await waitForAnySelector(
          ["button[id*='Login']", "input[type='submit']", "button[type='submit']"],
          10000,
        );

        await Promise.all([
          page.waitForNavigation({ waitUntil: 'networkidle', timeout: 60000 }).catch(() => null),
          page.click(submitSelector),
        ]);
      }
    }

    await waitForIdle();
    await ensureNotBlocked('after LTA login submit');
    logStage(`Post-login page: ${page.url()}`);
  }

  if (!page.url().includes('/Admin/Membership/Members')) {
    logStage('Navigating back to members page');
    await page.goto(membersUrl, { waitUntil: 'networkidle', timeout: 60000 });
    await waitForIdle();
  }

  await ensureNotBlocked('members page');
  await dismissCookieBanner();
  logStage('On members page, preparing direct export request');
  if (await clickIfVisible('.js-filter-reset')) {
    await page.waitForTimeout(1000);
  }

  const exportRequest = await getDirectExportRequest();
  logStage(`Submitting direct CSV export to ${exportRequest.endpoint}`);

  const response = await page.request.post(exportRequest.endpoint, {
    form: exportRequest.form,
    headers: {
      referer: page.url(),
    },
    timeout: 60000,
  });

  const responseHeaders = response.headers();
  const contentType = responseHeaders['content-type'] || '';
  const contentDisposition = responseHeaders['content-disposition'] || '';
  const csvText = await response.text();

  if (!response.ok()) {
    throw new Error(`ClubSpark members export failed with HTTP ${response.status()}.`);
  }

  if (!/csv/i.test(contentType) && !/attachment/i.test(contentDisposition)) {
    throw new Error('ClubSpark members export did not return a CSV response.');
  }

  if (!csvText.trim()) {
    throw new Error('ClubSpark members export response was empty.');
  }

  if (outputPath) {
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await fs.writeFile(outputPath, csvText, 'utf8');
    logStage(`Saved CSV response to ${outputPath}`);
  } else {
    process.stdout.write(csvText);
  }
  process.exit(0);
} catch (error) {
  console.error(String(error instanceof Error ? error.message : error));
  const screenshotPath = path.resolve('./clubspark-members-export-debug.png');
  try {
    await page.screenshot({ path: screenshotPath, fullPage: true });
    logStage(`Saved debug screenshot to ${screenshotPath}`);
  } catch {
    // Ignore screenshot failures.
  }
  process.exit(1);
} finally {
  rl.close();
  await context.close();
  await browser.close();
}
