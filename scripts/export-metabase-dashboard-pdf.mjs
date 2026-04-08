#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

import { chromium } from 'playwright';
import { PDFDocument } from 'pdf-lib';

const outputTarget = process.env.EXPORT_OUTPUT ?? process.env.CLUBSPARK_OUTPUT ?? './metabase-dashboard-report.pdf';
const outputPath = path.resolve(outputTarget);
const headless = process.env.HEADLESS !== 'false';
const slowMo = Number(process.env.SLOW_MO ?? '50');

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

function readPayload() {
  const raw = String(process.env.EXPORTER_PAYLOAD_JSON ?? '').trim();
  if (!raw) {
    throw new Error('Missing EXPORTER_PAYLOAD_JSON request payload.');
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new Error(`EXPORTER_PAYLOAD_JSON is not valid JSON: ${error.message}`);
  }

  return parsed ?? {};
}

function normalizeBaseUrl(value) {
  const text = String(value ?? '').trim();
  if (!text) {
    return '';
  }
  return text.replace(/\/+$/, '');
}

function buildDashboardUrl(baseUrl, dashboardId, filters = {}) {
  const url = new URL(`${baseUrl}/dashboard/${dashboardId}`);
  for (const [key, value] of Object.entries(filters ?? {})) {
    if (value === null || value === undefined) continue;
    const text = String(value).trim();
    if (!text) continue;
    url.searchParams.set(key, text);
  }
  return url.toString();
}

function normalizeTab(tab) {
  if (typeof tab === 'string') {
    const text = tab.trim();
    return text ? { id: text, name: text } : null;
  }

  if (!tab || typeof tab !== 'object') {
    return null;
  }

  const id = String(tab.id ?? '').trim();
  const name = String(tab.name ?? tab.label ?? '').trim();
  if (!id && !name) {
    return null;
  }

  return {
    id: id || name,
    name: name || id,
  };
}

function normalizePdfOptions(raw) {
  const source = raw && typeof raw === 'object' ? raw : {};
  return {
    format: String(source.format ?? 'A4'),
    landscape: source.landscape === true,
    printBackground: source.printBackground !== false,
    margin: {
      top: String(source.margin?.top ?? '10mm'),
      right: String(source.margin?.right ?? '10mm'),
      bottom: String(source.margin?.bottom ?? '12mm'),
      left: String(source.margin?.left ?? '10mm'),
    },
  };
}

function resolveCredentials(payload) {
  const login = payload.login && typeof payload.login === 'object' ? payload.login : {};
  const username = String(
    login.username
      ?? login.email
      ?? process.env.METABASE_EMAIL
      ?? process.env.METABASE_USERNAME
      ?? '',
  ).trim();
  const password = String(
    login.password
      ?? process.env.METABASE_PASSWORD
      ?? '',
  );

  return username && password ? { username, password } : null;
}

async function waitForIdle(page) {
  try {
    await page.waitForLoadState('networkidle', { timeout: 15000 });
  } catch {
    // Some dashboards keep background polling active.
  }
}

async function waitForDashboardShell(page) {
  const selectors = [
    '[role="main"]',
    '.Dashboard',
    '.dashboard-parameters-widget-container',
    '.dashboards-browser',
  ];

  await Promise.any(selectors.map((selector) =>
    page.waitForSelector(selector, { state: 'visible', timeout: 30000 }),
  ));
}

async function maybeLogin(page, baseUrl, credentials) {
  const loginSelectors = [
    'input[name="email"]',
    'input[name="username"]',
    'input[type="email"]',
    'input[type="password"]',
  ];

  const needsLogin =
    page.url().includes('/auth/login')
    || await Promise.any(
      loginSelectors.map((selector) =>
        page.locator(selector).first().isVisible().catch(() => false),
      ),
    ).catch(() => false);

  if (!needsLogin) {
    return;
  }

  if (!credentials) {
    throw new Error('Metabase login is required but no credentials were supplied in payload or environment.');
  }

  if (!page.url().includes('/auth/login')) {
    await page.goto(`${baseUrl}/auth/login`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await waitForIdle(page);
  }

  const usernameInput = page.locator('input[name="email"], input[name="username"], input[type="email"]').first();
  const passwordInput = page.locator('input[name="password"], input[type="password"]').first();

  await usernameInput.fill(credentials.username);
  await passwordInput.fill(credentials.password);

  const submitButton = page.getByRole('button', { name: /sign in|log in|login/i }).first();
  if (await submitButton.isVisible().catch(() => false)) {
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => null),
      submitButton.click(),
    ]);
  } else {
    await passwordInput.press('Enter');
    await page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => null);
  }

  await waitForIdle(page);
}

async function hideChrome(page) {
  await page.addStyleTag({
    content: `
      header,
      nav,
      .Nav,
      .Navbar,
      .PageHeader,
      .Page-title,
      .QuestionBreadcrumbs,
      .AdminLayout-header,
      .mantine-AppShell-header {
        display: none !important;
      }

      body {
        background: #fff !important;
      }
    `,
  }).catch(() => {});
}

async function waitForTabRender(page, settleMs) {
  const busySelectors = [
    '[data-testid="loading-spinner"]',
    '[data-testid="spinner"]',
    '.LoadingSpinner',
    '.Icon-spinner',
    '.spinner-border',
  ];

  for (const selector of busySelectors) {
    await page.locator(selector).first().waitFor({ state: 'hidden', timeout: 5000 }).catch(() => {});
  }

  await waitForIdle(page);
  await page.waitForTimeout(settleMs);
}

async function selectTab(page, tab) {
  const preferred = page.getByRole('tab', { name: tab.name, exact: true }).first();
  const fallbacks = [
    preferred,
    page.getByRole('tab', { name: new RegExp(tab.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') }).first(),
    page.locator(`[data-tab-id="${tab.id}"]`).first(),
    page.locator(`[href*="tab=${tab.id}"]`).first(),
    page.locator('button, a').filter({ hasText: tab.name }).first(),
  ];

  for (const locator of fallbacks) {
    if (await locator.isVisible().catch(() => false)) {
      await locator.click({ timeout: 10000 }).catch(async () => {
        await locator.evaluate((element) => element.click());
      });
      return true;
    }
  }

  throw new Error(`Could not find dashboard tab "${tab.name}" (${tab.id}).`);
}

async function renderTabPdf(page, tab, pdfOptions) {
  await selectTab(page, tab);
  await waitForTabRender(page, 1500);
  return page.pdf(pdfOptions);
}

async function mergePdfBuffers(buffers) {
  const merged = await PDFDocument.create();

  for (const buffer of buffers) {
    const source = await PDFDocument.load(buffer);
    const copiedPages = await merged.copyPages(source, source.getPageIndices());
    copiedPages.forEach((page) => merged.addPage(page));
  }

  return Buffer.from(await merged.save());
}

function sanitizeFileComponent(value) {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    || 'tab';
}

const payload = readPayload();
const metabaseBaseUrl = normalizeBaseUrl(payload.metabaseBaseUrl ?? process.env.METABASE_BASE_URL);
const dashboardId = Number.parseInt(String(payload.dashboardId ?? ''), 10);
const dashboardName = String(payload.dashboardName ?? `dashboard-${dashboardId}`).trim() || `dashboard-${dashboardId}`;
const tabs = (Array.isArray(payload.tabs) ? payload.tabs : []).map(normalizeTab).filter(Boolean);
const filters = payload.filters && typeof payload.filters === 'object' ? payload.filters : {};
const pdfOptions = normalizePdfOptions(payload.pdf);
const credentials = resolveCredentials(payload);

if (!metabaseBaseUrl) {
  throw new Error('Missing metabaseBaseUrl in payload or METABASE_BASE_URL in environment.');
}

if (!Number.isInteger(dashboardId) || dashboardId <= 0) {
  throw new Error(`Invalid dashboardId: ${payload.dashboardId}`);
}

if (!tabs.length) {
  throw new Error('At least one dashboard tab is required.');
}

const browser = await chromium.launch(launchOptions);
const context = await browser.newContext({
  acceptDownloads: false,
  viewport: { width: 1600, height: 1200 },
});
const page = await context.newPage();

try {
  const dashboardUrl = buildDashboardUrl(metabaseBaseUrl, dashboardId, filters);
  console.error(`[metabase-report-export] Opening ${dashboardUrl}`);
  await page.goto(dashboardUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForIdle(page);
  await maybeLogin(page, metabaseBaseUrl, credentials);

  if (!page.url().includes(`/dashboard/${dashboardId}`)) {
    await page.goto(dashboardUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await waitForIdle(page);
  }

  await waitForDashboardShell(page);
  await hideChrome(page);
  await waitForTabRender(page, 1000);

  const buffers = [];
  for (const tab of tabs) {
    console.error(`[metabase-report-export] Rendering tab ${tab.name}`);
    const pdfBuffer = await renderTabPdf(page, tab, pdfOptions);
    buffers.push(pdfBuffer);
  }

  const merged = await mergePdfBuffers(buffers);
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, merged);
  console.error(`[metabase-report-export] Wrote merged PDF for ${dashboardName} to ${outputPath}`);
} finally {
  await context.close().catch(() => {});
  await browser.close().catch(() => {});
}
