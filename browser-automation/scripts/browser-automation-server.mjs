#!/usr/bin/env node

import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import { spawn } from 'node:child_process';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT ?? '3000');
const automationToken = process.env.BROWSER_AUTOMATION_TOKEN ?? process.env.EXPORTER_TOKEN ?? '';
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const runtimeScriptDir = process.env.EXPORTER_SCRIPT_DIR?.trim() || '';
const defaultScriptDir =
  process.env.EXPORTER_DEFAULT_SCRIPT_DIR?.trim()
  || path.resolve(scriptDir, '../../scripts');
const workerCwd = process.env.EXPORTER_WORKDIR?.trim() || os.tmpdir();

const clubSparkCredentialFields = {
  CLUBSPARK_EMAIL: [
    'credentials.clubspark.email',
    'credentials.clubSpark.email',
    'clubspark.email',
    'clubSpark.email',
    'clubsparkEmail',
    'clubSparkEmail',
  ],
  CLUBSPARK_PASSWORD: [
    'credentials.clubspark.password',
    'credentials.clubSpark.password',
    'clubspark.password',
    'clubSpark.password',
    'clubsparkPassword',
    'clubSparkPassword',
  ],
  LTA_USERNAME: [
    'credentials.lta.username',
    'lta.username',
    'ltaUsername',
  ],
  LTA_PASSWORD: [
    'credentials.lta.password',
    'lta.password',
    'ltaPassword',
  ],
};

function readHeader(req, name) {
  const value = req.headers[name];
  if (Array.isArray(value)) {
    return String(value[0] ?? '');
  }
  return typeof value === 'string' ? value : '';
}

function readPath(source, rawPath) {
  const segments = String(rawPath).split('.');
  let current = source;

  for (const segment of segments) {
    if (!current || typeof current !== 'object' || !Object.hasOwn(current, segment)) {
      return '';
    }
    current = current[segment];
  }

  return typeof current === 'string' ? current.trim() : '';
}

function readFirstPayloadString(payload, paths) {
  for (const candidatePath of paths) {
    const value = readPath(payload, candidatePath);
    if (value) {
      return value;
    }
  }

  return '';
}

function applyPayloadEnv(payload, credentialFields = {}, extraEnv = {}) {
  for (const [envName, paths] of Object.entries(credentialFields)) {
    const value = readFirstPayloadString(payload, paths);
    if (value) {
      extraEnv[envName] = value;
    }
  }

  return extraEnv;
}

async function resolveJobScriptDir() {
  if (runtimeScriptDir) {
    try {
      await fs.access(path.join(runtimeScriptDir, 'export-clubspark-contacts-local.mjs'));
      await fs.access(path.join(runtimeScriptDir, 'export-clubspark-members-local.mjs'));
      await fs.access(path.join(runtimeScriptDir, 'export-clubspark-auth-session-local.mjs'));
      await fs.access(path.join(runtimeScriptDir, 'export-metabase-dashboard-pdf.mjs'));
      return runtimeScriptDir;
    } catch {
      // Fall back to baked-in scripts.
    }
  }

  return defaultScriptDir;
}

const jobScriptDir = await resolveJobScriptDir();

const jobs = {
  'clubspark.contacts.export': {
    scriptPath: path.join(jobScriptDir, 'export-clubspark-contacts-local.mjs'),
    contentType: 'text/csv; charset=utf-8',
    responseType: 'text',
    credentialFields: clubSparkCredentialFields,
  },
  'clubspark.members.export': {
    scriptPath: path.join(jobScriptDir, 'export-clubspark-members-local.mjs'),
    contentType: 'text/csv; charset=utf-8',
    responseType: 'text',
    credentialFields: clubSparkCredentialFields,
  },
  'clubspark.members.main-contacts.export': {
    scriptPath: path.join(jobScriptDir, 'export-clubspark-members-local.mjs'),
    contentType: 'text/csv; charset=utf-8',
    responseType: 'text',
    credentialFields: clubSparkCredentialFields,
    extraEnv: {
      CLUBSPARK_MEMBER_VIEW_LABEL: 'Main Contacts',
      CLUBSPARK_MEMBER_VIEW_VALUE: 'contacts',
    },
  },
  'clubspark.auth-session': {
    scriptPath: path.join(jobScriptDir, 'export-clubspark-auth-session-local.mjs'),
    contentType: 'application/json; charset=utf-8',
    responseType: 'text',
    credentialFields: clubSparkCredentialFields,
  },
  'metabase.dashboard-pdf': {
    scriptPath: path.join(jobScriptDir, 'export-metabase-dashboard-pdf.mjs'),
    contentType: 'application/pdf',
    responseType: 'binary',
    outputExtension: '.pdf',
  },
};

const routes = new Map([
  ['/jobs/clubspark/contacts/export', jobs['clubspark.contacts.export']],
  ['/jobs/clubspark/members/export', jobs['clubspark.members.export']],
  ['/jobs/clubspark/members/main-contacts/export', jobs['clubspark.members.main-contacts.export']],
  ['/jobs/clubspark/auth-session', jobs['clubspark.auth-session']],
  ['/jobs/metabase/dashboard-pdf', jobs['metabase.dashboard-pdf']],
  ['/clubspark-export', jobs['clubspark.contacts.export']],
  ['/clubspark-members-export', jobs['clubspark.members.export']],
  ['/clubspark-members-main-contacts-export', jobs['clubspark.members.main-contacts.export']],
  ['/clubspark-auth-session', jobs['clubspark.auth-session']],
  ['/metabase-dashboard-pdf', jobs['metabase.dashboard-pdf']],
]);

const activeRuns = new Map();

function buildRunKey(job, requestBody, extraEnv) {
  return createHash('sha256')
    .update(JSON.stringify([job.scriptPath, requestBody, extraEnv]))
    .digest('hex');
}

function runJob(job, requestBody = '', extraEnv = {}) {
  const runKey = buildRunKey(job, requestBody, extraEnv);

  if (activeRuns.has(runKey)) {
    return activeRuns.get(runKey);
  }

  const runPromise = new Promise((resolve) => {
    const outputExtension =
      typeof job.outputExtension === 'string' && job.outputExtension.startsWith('.')
        ? job.outputExtension
        : job.responseType === 'binary'
          ? '.bin'
          : '.txt';
    const outputPath = path.join(
      os.tmpdir(),
      `browser-automation-${path.basename(job.scriptPath)}-${Date.now()}-${Math.random().toString(36).slice(2)}${outputExtension}`,
    );
    const childEnv = {
      ...process.env,
      ...extraEnv,
      HEADLESS: process.env.HEADLESS ?? 'true',
      CLUBSPARK_OUTPUT: outputPath,
      EXPORT_OUTPUT: outputPath,
      EXPORTER_PAYLOAD_JSON: requestBody,
    };
    fs.mkdir(workerCwd, { recursive: true })
      .then(() => {
        const child = spawn(process.execPath, [job.scriptPath], {
          cwd: workerCwd,
          env: childEnv,
          stdio: ['ignore', 'pipe', 'pipe'],
        });

        let stdout = '';
        let stderr = '';

        child.stdout.setEncoding('utf8');
        child.stderr.setEncoding('utf8');

        child.stdout.on('data', (chunk) => {
          stdout += chunk;
        });

        child.stderr.on('data', (chunk) => {
          stderr += chunk;
        });

        child.on('error', (error) => {
          activeRuns.delete(runKey);
          resolve({ code: 1, stdout: '', stderr: error.message });
        });

        child.on('close', async (code) => {
          let body = stdout;

          if (code === 0) {
            try {
              body = job.responseType === 'binary'
                ? await fs.readFile(outputPath)
                : await fs.readFile(outputPath, 'utf8');
            } catch {
              // Fall back to stdout if the exporter did not write the temp file.
            }
          }

          await fs.rm(outputPath, { force: true }).catch(() => {});

          const result = { code: code ?? 1, stdout: body, stderr };
          activeRuns.delete(runKey);
          resolve(result);
        });
      })
      .catch((error) => {
        activeRuns.delete(runKey);
        resolve({ code: 1, stdout: '', stderr: error.message });
      });
  });

  activeRuns.set(runKey, runPromise);
  return runPromise;
}

const server = http.createServer(async (req, res) => {
  const requestUrl = new URL(req.url ?? '/', 'http://localhost');
  const pathname = requestUrl.pathname;

  if (req.method === 'GET' && pathname === '/health') {
    process.stdout.write(`[${new Date().toISOString()}] GET ${pathname}\n`);
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ status: 'ok', service: 'browser-automation' }));
    return;
  }

  if (req.method === 'GET' && pathname === '/jobs') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      jobs: Array.from(routes.keys()).filter((route) => route.startsWith('/jobs/')),
    }));
    return;
  }

  process.stdout.write(`[${new Date().toISOString()}] ${req.method} ${pathname}\n`);

  if (req.method !== 'POST') {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  const job = routes.get(pathname);
  if (!job) {
    process.stdout.write(`[${new Date().toISOString()}] Not found: ${pathname}\n`);
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  if (automationToken && req.headers.authorization !== `Bearer ${automationToken}`) {
    process.stdout.write(`[${new Date().toISOString()}] Unauthorized: ${pathname}\n`);
    res.writeHead(401, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Unauthorized');
    return;
  }

  let requestBody = '';
  for await (const chunk of req) {
    requestBody += chunk;
  }

  let payload = {};
  if (requestBody.trim()) {
    try {
      payload = JSON.parse(requestBody);
    } catch {
      res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Request body must be valid JSON');
      return;
    }
  }

  const extraEnv = {};
  const targetUrl =
    (typeof payload.targetUrl === 'string' && payload.targetUrl.trim())
    || readHeader(req, 'x-clubspark-target-url').trim();
  const cookieHeader =
    (typeof payload.cookieHeader === 'string' && payload.cookieHeader.trim())
    || readHeader(req, 'x-clubspark-cookie-header').trim();
  const userAgent =
    (typeof payload.userAgent === 'string' && payload.userAgent.trim())
    || readHeader(req, 'x-clubspark-user-agent').trim();

  if (targetUrl) {
    extraEnv.CLUBSPARK_AUTH_TARGET_URL = targetUrl;
  }
  if (cookieHeader) {
    extraEnv.CLUBSPARK_COOKIE_HEADER = cookieHeader;
  }
  if (userAgent) {
    extraEnv.CLUBSPARK_USER_AGENT = userAgent;
  }
  applyPayloadEnv(payload, job.credentialFields, extraEnv);

  process.stdout.write(`[${new Date().toISOString()}] Running job: ${job.scriptPath}\n`);
  const result = await runJob(job, requestBody, {
    ...(job.extraEnv ?? {}),
    ...extraEnv,
  });

  if (result.code !== 0) {
    process.stdout.write(`[${new Date().toISOString()}] FAILED: ${job.scriptPath} (code ${result.code})\n`);
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(result.stderr || 'Browser automation job failed');
    return;
  }

  process.stdout.write(`[${new Date().toISOString()}] SUCCESS: ${job.scriptPath}\n`);

  res.writeHead(200, { 'Content-Type': job.contentType });
  res.end(result.stdout);
});

server.listen(port, '0.0.0.0', () => {
  process.stdout.write(`Browser automation listening on ${port} using scripts from ${jobScriptDir}\n`);
});
