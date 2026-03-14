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

const outputTarget = process.env.CLUBSPARK_OUTPUT ?? './clubspark-contacts-export.csv';
const outputPath = outputTarget === '-' ? null : path.resolve(outputTarget);
const headless = process.env.HEADLESS === 'true';
const slowMo = Number(process.env.SLOW_MO ?? '100');
const contactsUrl =
  process.env.CLUBSPARK_CONTACTS_URL ??
  'https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts';

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
  acceptDownloads: true,
  viewport: { width: 1440, height: 1000 },
});
const page = await context.newPage();
const rl = readline.createInterface({ input, output });

function logStage(message) {
  console.error(`[clubspark-export] ${message}`);
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

async function findExportCsvAction() {
  return page.evaluate(() => {
    const candidate = Array.from(document.querySelectorAll('.dropdown-menu a, a')).find((element) =>
      /Export CSV/i.test((element.textContent || '').trim()),
    );

    if (!candidate) {
      return null;
    }

    return {
      href: candidate.getAttribute('href'),
      onclick: candidate.getAttribute('onclick'),
      text: (candidate.textContent || '').trim(),
    };
  });
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

try {
  logStage(`Opening ${contactsUrl}`);
  await page.goto(contactsUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForIdle();
  await ensureNotBlocked('initial page load');
  await dismissCookieBanner();
  logStage(`Initial page loaded: ${page.url()}`);

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

  if (!page.url().includes('/Admin/Contacts')) {
    logStage('Navigating back to contacts page');
    await page.goto(contactsUrl, { waitUntil: 'networkidle', timeout: 60000 });
    await waitForIdle();
  }

  await ensureNotBlocked('contacts page');
  await dismissCookieBanner();
  logStage('On contacts page, preparing export');

  await clickIfVisible('.js-filter-reset');
  await clickIfVisible("input[name='select_all']");

  const downloadPromise = page.waitForEvent('download', { timeout: 30000 }).catch(() => null);
  const responsePromise = page
    .waitForResponse(
      (response) =>
        response.url().includes('/Admin/Contacts/Export') &&
        response.request().method() === 'POST',
      { timeout: 30000 },
    )
    .catch(() => null);

  const exportAction = await findExportCsvAction();

  if (exportAction?.href && exportAction.href !== '#') {
    const exportUrl = new URL(exportAction.href, page.url()).toString();
    logStage(`Triggering CSV export directly via ${exportUrl}`);
    await page.goto(exportUrl, { waitUntil: 'networkidle', timeout: 60000 }).catch(() => null);
  } else if (exportAction) {
    logStage(`Triggering CSV export directly via DOM action: ${exportAction.text}`);
    await page.evaluate(() => {
      const candidate = Array.from(document.querySelectorAll('.dropdown-menu a, a')).find((element) =>
        /Export CSV/i.test((element.textContent || '').trim()),
      );
      candidate?.click();
    });
  } else {
    const dropdownSelector = await waitForAnySelector(
      [
        'a.btn-more.dropdown-toggle:not(.inactive)',
        'a.btn-more:not(.inactive)',
        'a.btn-more',
      ],
      20000,
    );
    await page.click(dropdownSelector);
    await waitForIdle();
    logStage('Opened export dropdown');

    const exportSelector = await waitForAnySelector(
      [
        "a[href*='/Contacts/Export']",
        "a[href*='Contacts/Export']",
        "a[href*='Export']",
        "a:has-text('Export CSV')",
        "a:has-text('Export contacts')",
        "a:has-text('Export')",
      ],
      20000,
    );

    await page.click(exportSelector);
    logStage('Triggered CSV export via dropdown');
  }

  const download = await downloadPromise;
  if (download) {
    const downloadPath = await download.path();
    if (!downloadPath) {
      throw new Error('Playwright did not provide a download path for the ClubSpark CSV export.');
    }
    const csvBuffer = await fs.readFile(downloadPath);
    if (outputPath) {
      await fs.mkdir(path.dirname(outputPath), { recursive: true });
      await fs.writeFile(outputPath, csvBuffer);
      logStage(`Saved CSV download to ${outputPath}`);
    } else {
      process.stdout.write(csvBuffer);
    }
    process.exit(0);
  }

  const response = await responsePromise;
  if (response) {
    const csvText = await response.text();
    if (!csvText.trim()) {
      throw new Error('Export response was empty.');
    }
    if (outputPath) {
      await fs.mkdir(path.dirname(outputPath), { recursive: true });
      await fs.writeFile(outputPath, csvText, 'utf8');
      logStage(`Saved CSV response to ${outputPath}`);
    } else {
      process.stdout.write(csvText);
    }
    process.exit(0);
  }

  throw new Error('No CSV download or export response was captured.');
} catch (error) {
  console.error(String(error instanceof Error ? error.message : error));
  const screenshotPath = path.resolve('./clubspark-export-debug.png');
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
