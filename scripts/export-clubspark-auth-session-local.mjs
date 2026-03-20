#!/usr/bin/env node

import fs from 'node:fs/promises';
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

const headless = process.env.HEADLESS !== 'false';
const slowMo = Number(process.env.SLOW_MO ?? '100');
const defaultTargetUrl =
  process.env.CLUBSPARK_CONTACTS_URL ??
  'https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts';
const targetUrl = process.env.CLUBSPARK_AUTH_TARGET_URL ?? defaultTargetUrl;

const launchOptions = {
  headless,
  slowMo,
  args: ['--disable-dev-shm-usage', '--no-sandbox'],
};

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
const context = await browser.newContext({
  acceptDownloads: false,
  viewport: { width: 1440, height: 1000 },
});
const page = await context.newPage();
const rl = readline.createInterface({ input, output });

function logStage(message) {
  console.error(`[clubspark-auth] ${message}`);
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

function cookieMatchesTarget(cookie, url) {
  const hostname = url.hostname;
  const normalizedDomain = String(cookie.domain || '').replace(/^\./, '');
  if (normalizedDomain && hostname !== normalizedDomain && !hostname.endsWith(`.${normalizedDomain}`)) {
    return false;
  }

  const cookiePath = cookie.path || '/';
  if (!url.pathname.startsWith(cookiePath)) {
    return false;
  }

  if (cookie.secure && url.protocol !== 'https:') {
    return false;
  }

  if (cookie.expires && cookie.expires > 0 && (cookie.expires * 1000) <= Date.now()) {
    return false;
  }

  return true;
}

function buildCookieHeader(cookies, url) {
  return cookies
    .filter((cookie) => cookieMatchesTarget(cookie, url))
    .map((cookie) => `${cookie.name}=${cookie.value}`)
    .join('; ');
}

try {
  logStage(`Opening ${targetUrl}`);
  await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForIdle();
  await ensureNotBlocked('initial page load');
  await dismissCookieBanner();

  const initialSelector = await waitForInitialLoginState(15000);

  if (!initialSelector) {
    if (headless || !process.stdin.isTTY || !process.stdout.isTTY) {
      throw new Error('Login form not detected automatically in non-interactive mode.');
    }
    console.error('Login form not detected automatically.');
    console.error('If ClubSpark or Cloudflare needs manual interaction, complete it in the browser window.');
    await rl.question('Press Enter when the ClubSpark or LTA login form is visible...');
  }

  await ensureNotBlocked('before ClubSpark login');

  let openedLtaLogin = false;

  if (
    (await submitLtaLoginChooserIfVisible())
    || (await clickLocatorIfVisible(page.getByRole('button', { name: /^Login$/ }).first()))
  ) {
    logStage('Submitted LTA chooser');
    await page.waitForURL(/mylta\.my\.site\.com/i, { timeout: 60000 }).catch(() => null);
    await ensureNotBlocked('after opening LTA login form');
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

  if (page.url() !== targetUrl) {
    logStage(`Navigating back to target page ${targetUrl}`);
    await page.goto(targetUrl, { waitUntil: 'networkidle', timeout: 60000 });
    await waitForIdle();
  }

  await ensureNotBlocked('target page');
  await dismissCookieBanner();

  const snapshot = await textSnapshot();
  const combined = `${snapshot.title}\n${snapshot.bodyText}`;
  if (/sign in|log in/i.test(combined) && /auth\.clubspark\.uk|mylta\.my\.site\.com/i.test(snapshot.url)) {
    throw new Error(`Authentication did not complete successfully. Final URL: ${snapshot.url}`);
  }

  const target = new URL(targetUrl);
  const cookies = await context.cookies();
  const matchedCookies = cookies.filter((cookie) => cookieMatchesTarget(cookie, target));
  const cookieHeader = buildCookieHeader(cookies, target);
  const userAgent = await page.evaluate(() => navigator.userAgent);

  if (!cookieHeader) {
    throw new Error(`Authentication completed but no reusable cookies matched ${targetUrl}`);
  }

  const probeResponse = await page.request.get(targetUrl, {
    headers: {
      cookie: cookieHeader,
      'user-agent': userAgent,
      referer: snapshot.url,
    },
    timeout: 60000,
  });
  const probeText = await probeResponse.text();
  const probeAuthenticated = probeResponse.ok()
    && !/Sign in|Log in/i.test(probeText)
    && !/auth\.clubspark\.uk|mylta\.my\.site\.com/i.test(probeResponse.url());

  const payload = {
    authenticated: true,
    targetUrl,
    authenticatedUrl: snapshot.url,
    pageTitle: snapshot.title,
    userAgent,
    cookieHeader,
    cookieCount: matchedCookies.length,
    cookies: matchedCookies.map((cookie) => ({
      name: cookie.name,
      value: cookie.value,
      domain: cookie.domain,
      path: cookie.path,
      expires: cookie.expires,
      httpOnly: cookie.httpOnly,
      secure: cookie.secure,
      sameSite: cookie.sameSite,
    })),
    probe: {
      url: probeResponse.url(),
      status: probeResponse.status(),
      authenticated: probeAuthenticated,
      bodySnippet: probeText.replace(/\s+/g, ' ').slice(0, 400),
    },
  };

  process.stdout.write(`${JSON.stringify(payload)}\n`);
  process.exit(0);
} catch (error) {
  console.error(String(error instanceof Error ? error.message : error));
  process.exit(1);
} finally {
  rl.close();
  await context.close();
  await browser.close();
}
