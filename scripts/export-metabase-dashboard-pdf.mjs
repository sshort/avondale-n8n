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

function normalizeStringArray(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item ?? '').trim())
      .filter(Boolean);
  }

  const text = String(value ?? '').trim();
  if (!text) {
    return [];
  }

  return text
    .split(/[\n,;]+/)
    .map((item) => item.trim())
    .filter(Boolean);
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

function normalizeRedactionProfile(raw) {
  const profile = raw && typeof raw === 'object' ? raw : {};
  return {
    useRegex: profile.useRegex === true,
    wholeWordSearch: profile.wholeWordSearch === true,
    convertPdfToImage: profile.convertPdfToImage === true,
    customPadding: profile.customPadding ?? 2,
    redactColor: String(profile.redactColor ?? '#000000'),
    columnHeaders: normalizeStringArray(profile.columnHeaders),
    terms: normalizeStringArray(profile.terms),
  };
}

function normalizeHeaderName(value) {
  return String(value ?? '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
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
    'main',
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

async function preparePdfRendering(page) {
  await page.addStyleTag({
    content: `
      [data-export-map-image="true"] {
        display: block !important;
        width: 100% !important;
        height: 100% !important;
        object-fit: contain !important;
        print-color-adjust: exact !important;
        -webkit-print-color-adjust: exact !important;
      }
    `,
  }).catch(() => {});
}

async function protectSensitiveColumns(page, rawColumnHeaders, reportMode = 'render') {
  const targetHeaders = normalizeStringArray(rawColumnHeaders)
    .map(normalizeHeaderName)
    .filter(Boolean);

  if (!targetHeaders.length) {
    return;
  }

  await page.evaluate(({ headers, mode }) => {
    const normalized = (value) => String(value ?? '')
      .trim()
      .replace(/\s+/g, ' ')
      .toLowerCase();
    const targets = new Set(headers.map(normalized).filter(Boolean));
    if (!targets.size) {
      return;
    }

    const hideElement = (element) => {
      if (!element) return;
      element.style.setProperty('display', 'none', 'important');
      element.setAttribute('data-export-hidden-column', 'true');
    };

    const maskText = (value) => String(value ?? '').replace(/[^\s]/g, '*');

    const stripSensitiveLinks = (element) => {
      if (!element) return;
      for (const link of element.querySelectorAll('a')) {
        link.removeAttribute('href');
        link.removeAttribute('target');
        link.removeAttribute('rel');
        link.style.setProperty('pointer-events', 'none', 'important');
        link.style.setProperty('text-decoration', 'none', 'important');
        link.style.setProperty('color', 'inherit', 'important');
      }
    };

    const maskElement = (element) => {
      if (!element) return;
      stripSensitiveLinks(element);

      const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
      const textNodes = [];
      let current = walker.nextNode();
      while (current) {
        textNodes.push(current);
        current = walker.nextNode();
      }

      for (const textNode of textNodes) {
        textNode.textContent = maskText(textNode.textContent);
      }

      element.setAttribute('data-export-masked-column', 'true');
    };

    const gridSelectors = [
      '[data-testid="table-scroll-container"][role="grid"]',
      '[role="grid"][data-testid="table-scroll-container"]',
      '[role="grid"]',
    ];

    for (const selector of gridSelectors) {
      for (const grid of document.querySelectorAll(selector)) {
        const matchedHeaders = new Set();

        for (const headerWrapper of grid.querySelectorAll('[data-header-id]')) {
          const headerId = headerWrapper.getAttribute('data-header-id') ?? '';
          const headerText =
            headerWrapper.querySelector('[role="columnheader"], [data-testid="cell-data"]')?.textContent
            ?? headerWrapper.textContent
            ?? headerId;
          const normalizedHeaderId = normalized(headerId);
          const normalizedHeaderText = normalized(headerText);

          if (targets.has(normalizedHeaderId) || targets.has(normalizedHeaderText)) {
            if (headerId) {
              matchedHeaders.add(headerId);
            }
            if (mode === 'anonymise') {
              hideElement(headerWrapper);
            }
          }
        }

        for (const cell of grid.querySelectorAll('[data-column-id]')) {
          const columnId = cell.getAttribute('data-column-id') ?? '';
          if (targets.has(normalized(columnId)) || matchedHeaders.has(columnId)) {
            if (mode === 'anonymise') {
              hideElement(cell);
            } else if (mode === 'redact') {
              maskElement(cell);
            }
          }
        }
      }
    }

    for (const table of document.querySelectorAll('table')) {
      const headerIndexes = [];
      const headers = Array.from(table.querySelectorAll('thead th'));

      headers.forEach((headerCell, index) => {
        if (targets.has(normalized(headerCell.textContent))) {
          headerIndexes.push(index);
          if (mode === 'anonymise') {
            hideElement(headerCell);
          }
        }
      });

      if (!headerIndexes.length) {
        continue;
      }

      for (const row of table.querySelectorAll('tr')) {
        headerIndexes.forEach((index) => {
          const cell = row.children[index];
          if (mode === 'anonymise') {
            hideElement(cell);
          } else if (mode === 'redact' && row.parentElement?.tagName !== 'THEAD') {
            maskElement(cell);
          }
        });
      }
    }
  }, { headers: targetHeaders, mode: reportMode });
}

function bufferToDataUrl(buffer, mimeType = 'image/png') {
  return `data:${mimeType};base64,${buffer.toString('base64')}`;
}

async function isMeaningfulMapCapture(page, dataUrl) {
  return page.evaluate(async (source) => {
    const image = new Image();
    image.src = source;

    if (typeof image.decode === 'function') {
      await image.decode().catch(() => {});
    } else {
      await new Promise((resolve) => {
        image.addEventListener('load', resolve, { once: true });
        image.addEventListener('error', resolve, { once: true });
      });
    }

    const width = image.naturalWidth || image.width;
    const height = image.naturalHeight || image.height;
    if (!width || !height) {
      return false;
    }

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;

    const context = canvas.getContext('2d', { willReadFrequently: true });
    if (!context) {
      return false;
    }

    context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, width, height).data;
    const sampleStepX = Math.max(1, Math.floor(width / 32));
    const sampleStepY = Math.max(1, Math.floor(height / 24));
    let sampled = 0;
    let nonBlank = 0;

    for (let y = 0; y < height; y += sampleStepY) {
      for (let x = 0; x < width; x += sampleStepX) {
        const offset = ((y * width) + x) * 4;
        const red = pixels[offset];
        const green = pixels[offset + 1];
        const blue = pixels[offset + 2];
        const alpha = pixels[offset + 3];
        sampled += 1;

        const nearWhite = red > 245 && green > 245 && blue > 245;
        const nearTransparent = alpha < 10;
        if (!nearWhite && !nearTransparent) {
          nonBlank += 1;
        }
      }
    }

    return sampled > 0 && (nonBlank / sampled) >= 0.04;
  }, dataUrl);
}

async function captureStableMapSnapshot(page, mapContent) {
  const maxAttempts = 5;
  let lastCapture = null;

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    await mapContent.scrollIntoViewIfNeeded().catch(() => {});
    await mapContent.locator('.leaflet-tile-loaded').first().waitFor({ state: 'visible', timeout: 10000 }).catch(() => {});
    await page.waitForTimeout(1200 + (attempt * 300));

    const bounds = await mapContent.boundingBox().catch(() => null);
    if (!bounds || bounds.width < 40 || bounds.height < 40) {
      continue;
    }

    const clip = {
      x: Math.max(0, Math.floor(bounds.x)),
      y: Math.max(0, Math.floor(bounds.y)),
      width: Math.max(1, Math.floor(bounds.width)),
      height: Math.max(1, Math.floor(bounds.height)),
    };

    const screenshot = await page.screenshot({ clip, type: 'png' });
    const dataUrl = bufferToDataUrl(screenshot);
    lastCapture = {
      bounds,
      dataUrl,
    };

    if (await isMeaningfulMapCapture(page, dataUrl)) {
      return lastCapture;
    }
  }

  return lastCapture;
}

async function snapshotMapVisualizations(page) {
  const mapRoots = page.locator('[data-viz-ui-name="Map"]');
  const mapCount = await mapRoots.count();

  for (let index = 0; index < mapCount; index += 1) {
    const mapRoot = mapRoots.nth(index);
    const mapContent = mapRoot.locator('[data-element-id], .CardVisualization').first();

    if (!await mapContent.isVisible().catch(() => false)) {
      continue;
    }

    const capture = await captureStableMapSnapshot(page, mapContent);
    if (!capture?.dataUrl) {
      continue;
    }

    await mapContent.evaluate(async (element, payload) => {
      if (element.querySelector('[data-export-map-image="true"]')) {
        return;
      }

      const replacement = document.createElement('img');
      replacement.src = payload.imageSrc;
      replacement.alt = 'Map snapshot';
      replacement.setAttribute('data-export-map-image', 'true');
      replacement.style.width = '100%';
      replacement.style.height = '100%';
      replacement.style.display = 'block';
      replacement.style.objectFit = 'contain';
      replacement.style.background = '#ffffff';
      if (payload.width && payload.height) {
        element.style.width = `${payload.width}px`;
        element.style.height = `${payload.height}px`;
        element.style.minHeight = `${payload.height}px`;
      }

      if (typeof replacement.decode === 'function') {
        await replacement.decode().catch(() => {});
      } else {
        await new Promise((resolve) => {
          replacement.addEventListener('load', resolve, { once: true });
          replacement.addEventListener('error', resolve, { once: true });
        });
      }

      while (element.firstChild) {
        element.removeChild(element.firstChild);
      }

      element.appendChild(replacement);
    }, {
      imageSrc: capture.dataUrl,
      width: capture.bounds?.width ? Math.round(capture.bounds.width) : null,
      height: capture.bounds?.height ? Math.round(capture.bounds.height) : null,
    });
  }
}

async function waitForTabRender(page, settleMs) {
  const busySelectors = [
    '[data-testid="loading-spinner"]',
    '[data-testid="spinner"]',
    '[data-testid="loading-indicator"]',
    '.LoadingSpinner',
    '.Icon-spinner',
    '.spinner-border',
  ];

  for (const selector of busySelectors) {
    await page.waitForFunction(
      (currentSelector) => Array.from(document.querySelectorAll(currentSelector))
        .every((element) => {
          const htmlElement = element;
          const style = window.getComputedStyle(htmlElement);
          return style.display === 'none'
            || style.visibility === 'hidden'
            || htmlElement.getClientRects().length === 0;
        }),
      selector,
      { timeout: 30000 },
    ).catch(() => {});
  }

  await page.waitForFunction(
    () => !/\b\d+\/\d+\s+loaded\b/i.test(document.title),
    { timeout: 20000 },
  ).catch(() => {});

  await waitForIdle(page);
  await page.waitForTimeout(settleMs);
}

async function selectTab(page, tab) {
  const preferred = page.getByRole('tab', { name: tab.name, exact: true }).first();
  if (await preferred.isVisible().catch(() => false)) {
    const selected = await preferred.getAttribute('aria-selected').catch(() => null);
    if (selected === 'true') {
      return false;
    }
  }

  const caseInsensitiveTab = page.getByRole('tab', {
    name: new RegExp(tab.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'),
  }).first();
  if (await caseInsensitiveTab.isVisible().catch(() => false)) {
    const selected = await caseInsensitiveTab.getAttribute('aria-selected').catch(() => null);
    if (selected === 'true') {
      return false;
    }
  }

  const fallbacks = [
    preferred,
    caseInsensitiveTab,
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

async function renderTabPdf(page, tab, pdfOptions, sensitiveColumnHeaders = [], reportMode = 'render') {
  await page.emulateMedia({ media: 'screen' }).catch(() => {});
  await selectTab(page, tab);
  await waitForTabRender(page, 1500);
  await page.emulateMedia({ media: 'print' }).catch(() => {});
  await waitForTabRender(page, 800);
  await snapshotMapVisualizations(page);
  await protectSensitiveColumns(page, sensitiveColumnHeaders, reportMode);
  await page.waitForTimeout(200);
  const pdfBuffer = await page.pdf(pdfOptions);
  await page.emulateMedia({ media: 'screen' }).catch(() => {});
  return pdfBuffer;
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

async function runStirling(stirlingBaseUrl, pathSuffix, sourceBuffer, fields = {}, apiKey = "") {
  const form = new FormData();
  form.append('fileInput', new Blob([sourceBuffer], { type: 'application/pdf' }), 'report.pdf');

  for (const [key, value] of Object.entries(fields)) {
    if (value === null || value === undefined) continue;
    const text = String(value).trim();
    if (!text) continue;
    form.append(key, text);
  }

  const headers = apiKey ? { 'X-API-KEY': apiKey } : undefined;

  const response = await fetch(`${stirlingBaseUrl}${pathSuffix}`, {
    method: 'POST',
    headers,
    body: form,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Stirling request failed (${response.status}) for ${pathSuffix}: ${errorText}`);
  }

  return Buffer.from(await response.arrayBuffer());
}

async function postProcessPdfBuffer(sourceBuffer, options) {
  const stirlingBaseUrl = normalizeBaseUrl(options.stirlingBaseUrl);
  const stirlingApiKey = String(options.stirlingApiKey ?? '').trim();
  if (!stirlingBaseUrl) {
    return sourceBuffer;
  }

  let resultBuffer = await runStirling(stirlingBaseUrl, '/api/v1/security/sanitize-pdf', sourceBuffer, {}, stirlingApiKey);

  if (options.reportMode !== 'redact') {
    return resultBuffer;
  }

  const profile = normalizeRedactionProfile(options.redactionProfile);
  const extraTerms = normalizeStringArray(options.extraRedactionTerms);
  const redactTerms = [...profile.terms, ...extraTerms].filter(Boolean);

  if (!redactTerms.length) {
    throw new Error('Redact mode was selected but no redaction terms were provided.');
  }

  resultBuffer = await runStirling(stirlingBaseUrl, '/api/v1/security/auto-redact', resultBuffer, {
    listOfText: redactTerms.join('\n'),
    useRegex: profile.useRegex ? 'true' : 'false',
    wholeWordSearch: profile.wholeWordSearch ? 'true' : 'false',
    customPadding: profile.customPadding ?? 2,
    redactColor: profile.redactColor,
    convertPDFToImage: profile.convertPdfToImage ? 'true' : 'false',
  }, stirlingApiKey);

  return resultBuffer;
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
const stirlingBaseUrl = normalizeBaseUrl(payload.stirlingBaseUrl ?? process.env.STIRLING_BASE_URL);
const stirlingApiKey = String(payload.stirlingApiKey ?? process.env.STIRLING_API_KEY ?? '').trim();
const reportMode = String(payload.reportMode ?? 'render').trim().toLowerCase();
const redactionProfile = payload.redactionProfile && typeof payload.redactionProfile === 'object'
  ? payload.redactionProfile
  : {};
const normalizedRedactionProfile = normalizeRedactionProfile(redactionProfile);
const extraRedactionTerms = normalizeStringArray(payload.extraRedactionTerms);
const sensitiveColumnHeaders = ['redact', 'anonymise'].includes(reportMode)
  ? normalizedRedactionProfile.columnHeaders
  : [];

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
  await preparePdfRendering(page);
  await waitForTabRender(page, 1000);

  const buffers = [];
  for (const tab of tabs) {
    console.error(`[metabase-report-export] Rendering tab ${tab.name}`);
    const pdfBuffer = await renderTabPdf(page, tab, pdfOptions, sensitiveColumnHeaders, reportMode);
    buffers.push(pdfBuffer);
  }

  const merged = await mergePdfBuffers(buffers);
  const finalBuffer = await postProcessPdfBuffer(merged, {
    stirlingBaseUrl,
    stirlingApiKey,
    reportMode,
    redactionProfile: normalizedRedactionProfile,
    extraRedactionTerms,
  });
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, finalBuffer);
  console.error(`[metabase-report-export] Wrote processed PDF for ${dashboardName} to ${outputPath}`);
} finally {
  await context.close().catch(() => {});
  await browser.close().catch(() => {});
}
