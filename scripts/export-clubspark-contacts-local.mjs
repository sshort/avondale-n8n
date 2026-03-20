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
    const candidate = Array.from(
      document.querySelectorAll(
        '.dropdown-menu a, .dropdown-menu button, a, button, [role="menuitem"]',
      ),
    ).find((element) => {
      const text = (element.textContent || '').trim();
      if (!/Export CSV/i.test(text)) {
        return false;
      }

      if (!(element instanceof HTMLElement)) {
        return true;
      }

      const style = window.getComputedStyle(element);
      const visible =
        style.visibility !== 'hidden'
        && style.display !== 'none'
        && element.getClientRects().length > 0;

      return visible;
    });

    if (!candidate) {
      return null;
    }

    return {
      tagName: candidate.tagName,
      href: candidate.getAttribute('href'),
      onclick: candidate.getAttribute('onclick'),
      text: (candidate.textContent || '').trim(),
    };
  });
}

async function enableBulkActions() {
  const selectAllByPlaywright = async (selector) => {
    const locator = page.locator(selector).first();
    if (await locator.isVisible().catch(() => false)) {
      await locator.check({ force: true }).catch(() => null);
      return true;
    }
    return false;
  };

  await selectAllByPlaywright("input[name='SelectAll']");
  await selectAllByPlaywright("input[name='select_all']");
  await selectAllByPlaywright('input[name="RecordID"]');
  await selectAllByPlaywright('thead input[type="checkbox"]');

  await page.evaluate(() => {
    const selectAllInputs = Array.from(
      document.querySelectorAll("input[name='SelectAll'], input[name='select_all']"),
    );

    for (const selectAll of selectAllInputs) {
      if (selectAll instanceof HTMLInputElement) {
        selectAll.checked = true;
        selectAll.dispatchEvent(new Event('input', { bubbles: true }));
        selectAll.dispatchEvent(new Event('change', { bubbles: true }));
        selectAll.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
      }
    }

    const selectAll = document.querySelector("input[name='select_all']");
    if (selectAll instanceof HTMLInputElement) {
      selectAll.checked = true;
      selectAll.dispatchEvent(new Event('input', { bubbles: true }));
      selectAll.dispatchEvent(new Event('change', { bubbles: true }));
      selectAll.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
    }

    const moreButton = Array.from(document.querySelectorAll('a.btn-more')).find(
      (element) => element instanceof HTMLElement,
    );

    if (moreButton instanceof HTMLElement) {
      moreButton.classList.remove('inactive', 'disabled');
      moreButton.removeAttribute('disabled');
      moreButton.setAttribute('aria-expanded', 'true');
      moreButton.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
      moreButton.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true }));
      moreButton.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));

      const parent = moreButton.closest('.btn-group, .dropdown, li');
      if (parent instanceof HTMLElement) {
        parent.classList.add('open', 'show');
      }
    }
  });
}

async function countCheckedBoxes() {
  return page.evaluate(
    () => document.querySelectorAll('input[type="checkbox"]:checked').length,
  );
}

async function countSelectedRecords() {
  return page.evaluate(
    () => document.querySelectorAll("input[name='RecordID']:checked").length,
  );
}

async function openContactOptionsMenu() {
  const button = page.getByRole('button', { name: /Contact options/i }).first();

  if (await button.isVisible().catch(() => false)) {
    await button.click().catch(async () => {
      await button.evaluate((element) => {
        if (element instanceof HTMLElement) {
          element.click();
        }
      });
    });
    await page.evaluate(() => {
      const dropdownButton = Array.from(
        document.querySelectorAll('button.dropdown-toggle, a.dropdown-toggle'),
      ).find((element) => /Contact Options/i.test((element.textContent || '').trim()));

      if (!(dropdownButton instanceof HTMLElement)) {
        return;
      }

      dropdownButton.setAttribute('aria-expanded', 'true');

      const dropdown = dropdownButton.closest('.btn-group, .dropdown');
      if (dropdown instanceof HTMLElement) {
        dropdown.classList.add('open', 'show');

        for (const menu of dropdown.querySelectorAll('.dropdown-menu')) {
          if (menu instanceof HTMLElement) {
            menu.classList.add('open', 'show');
            menu.style.display = 'block';
          }
        }
      }
    });
    await page.waitForTimeout(1000);
    return true;
  }

  return false;
}

async function listExportCandidates() {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('a, button, [role="menuitem"]'))
      .map((element) => ({
        tagName: element.tagName,
        text: (element.textContent || '').trim(),
        href: element.getAttribute('href'),
        onclick: element.getAttribute('onclick'),
        className: element.getAttribute('class'),
      }))
      .filter((entry) => /Export|Contact Options|More options/i.test(entry.text))
      .slice(0, 20),
  );
}

async function inspectExportDom() {
  return page.evaluate(() => {
    const csvButton = document.querySelector('a.btn-csv');
    const pdfButton = document.querySelector('a.btn-pdf');
    const contactOptions = Array.from(
      document.querySelectorAll('button.dropdown-toggle, a.dropdown-toggle'),
    ).find((element) => /Contact Options/i.test((element.textContent || '').trim()));
    const forms = Array.from(document.querySelectorAll('form'))
      .map((form) => ({
        action: form.getAttribute('action'),
        method: form.getAttribute('method'),
        outerHTML: form.outerHTML.slice(0, 1200),
      }))
      .filter((form) => /Export|Contacts|contact/i.test(form.outerHTML));
    const operationsForm = document.querySelector('form.operations');
    const exportScripts = Array.from(document.scripts)
      .map((script) => script.textContent || '')
      .filter((text) => /btn-csv|Export CSV|Contacts\/Export|export/i.test(text))
      .slice(0, 5)
      .map((text) => text.slice(0, 1200));

    return {
      csvButton: csvButton ? {
        outerHTML: csvButton.outerHTML,
        dataset: { ...csvButton.dataset },
      } : null,
      pdfButton: pdfButton ? {
        outerHTML: pdfButton.outerHTML,
        dataset: { ...pdfButton.dataset },
      } : null,
      contactOptions: contactOptions ? {
        outerHTML: contactOptions.outerHTML,
        dataset: { ...contactOptions.dataset },
      } : null,
      forms,
      operationsForm: operationsForm ? {
        action: operationsForm.getAttribute('action'),
        method: operationsForm.getAttribute('method'),
        inputs: Array.from(operationsForm.querySelectorAll('input, select, textarea')).map((field) => ({
          tagName: field.tagName,
          type: field.getAttribute('type'),
          name: field.getAttribute('name'),
          value: field.getAttribute('value'),
          checked: field instanceof HTMLInputElement ? field.checked : undefined,
          className: field.getAttribute('class'),
        })),
      } : null,
      exportScripts,
    };
  });
}

async function getDirectExportRequest() {
  return page.evaluate(() => {
    const jq = window.jQuery;
    const appSettings = window.clubHouseApp?.AppSettings;

    if (!jq?.fn?.DataTable) {
      throw new Error('Contacts DataTable was not available on the ClubSpark contacts page.');
    }

    if (!appSettings?.contactsTableEndPoint) {
      throw new Error('ClubSpark contactsTableEndPoint was not available on the contacts page.');
    }

    const params = jq('#contacts-table').DataTable().ajax.params();
    if (!params || typeof params !== 'object') {
      throw new Error('ClubSpark contacts DataTable params were not available.');
    }

    const form = {
      ...params,
      SelectAll: 'True',
    };

    // Force the export endpoint to ignore the current DataTables page size.
    for (const [key, value] of [
      ['start', '0'],
      ['length', '-1'],
      ['iDisplayStart', '0'],
      ['iDisplayLength', '-1'],
    ]) {
      if (Object.prototype.hasOwnProperty.call(form, key)) {
        form[key] = value;
      }
    }

    return {
      endpoint: new URL(
        appSettings.contactsTableEndPoint.replace('Lookup', 'Export'),
        location.origin,
      ).toString(),
      form,
    };
  });
}

async function downloadCsvViaUi() {
  await enableBulkActions();
  logStage(`Checked checkbox count after bulk-action prep: ${await countCheckedBoxes()}`);
  logStage(`Selected record count after bulk-action prep: ${await countSelectedRecords()}`);

  await openContactOptionsMenu();

  const csvButton = page.locator('a.btn-csv').first();
  if (!(await csvButton.isVisible().catch(() => false))) {
    logStage(`Export candidates before UI fallback: ${JSON.stringify(await listExportCandidates())}`);
    logStage(`Export DOM inspection before UI fallback: ${JSON.stringify(await inspectExportDom())}`);
    return null;
  }

  const downloadPromise = page.waitForEvent('download', { timeout: 15000 }).catch(() => null);
  const responsePromise = page.waitForResponse(
    (response) => /\/Admin\/Contacts\/Export/i.test(response.url()),
    { timeout: 15000 },
  ).catch(() => null);

  await csvButton.click({ force: true }).catch(async () => {
    await csvButton.evaluate((element) => {
      if (!(element instanceof HTMLElement)) {
        return;
      }

      element.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
      element.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true }));
      element.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
      element.click();
    });
  });

  const [download, exportResponse] = await Promise.all([downloadPromise, responsePromise]);

  if (download) {
    const downloadPath = await download.path();
    if (!downloadPath) {
      throw new Error('ClubSpark export download completed without a readable file path.');
    }
    logStage(`Captured browser download: ${download.suggestedFilename()}`);
    return fs.readFile(downloadPath, 'utf8');
  }

  if (exportResponse) {
    logStage(`Captured export response via UI click: HTTP ${exportResponse.status()}`);
    return exportResponse.text();
  }

  logStage(`Export candidates after UI fallback: ${JSON.stringify(await listExportCandidates())}`);
  logStage(`Export DOM inspection after UI fallback: ${JSON.stringify(await inspectExportDom())}`);
  return null;
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
  logStage('On contacts page, attempting browser-driven CSV export');
  await clickIfVisible('.js-filter-reset');

  let csvText = await downloadCsvViaUi();

  if (!csvText) {
    logStage('UI-driven export did not produce a CSV. Falling back to direct export request.');
    const exportRequest = await getDirectExportRequest();
    logStage(
      `Export request paging params: ${JSON.stringify({
        start: exportRequest.form.start ?? null,
        length: exportRequest.form.length ?? null,
        iDisplayStart: exportRequest.form.iDisplayStart ?? null,
        iDisplayLength: exportRequest.form.iDisplayLength ?? null,
      })}`,
    );
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
    csvText = await response.text();

    if (!response.ok()) {
      throw new Error(`ClubSpark export failed with HTTP ${response.status()}.`);
    }

    if (!/csv/i.test(contentType) && !/attachment/i.test(contentDisposition)) {
      logStage(`Unexpected export response headers: ${JSON.stringify(responseHeaders)}`);
      logStage(`Export DOM inspection: ${JSON.stringify(await inspectExportDom())}`);
      throw new Error('ClubSpark export did not return a CSV response.');
    }
  }

  if (!csvText.trim()) {
    throw new Error('ClubSpark export response was empty.');
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
