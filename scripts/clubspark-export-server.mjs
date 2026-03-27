#!/usr/bin/env node

import fs from 'node:fs/promises';
import { spawn } from 'node:child_process';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT ?? '3001');
const exporterToken = process.env.EXPORTER_TOKEN ?? '';
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const exporters = new Map([
  ['/clubspark-export', {
    scriptPath: path.join(scriptDir, 'export-clubspark-contacts-local.mjs'),
    contentType: 'text/csv; charset=utf-8',
  }],
  ['/clubspark-members-export', {
    scriptPath: path.join(scriptDir, 'export-clubspark-members-local.mjs'),
    contentType: 'text/csv; charset=utf-8',
  }],
  ['/clubspark-auth-session', {
    scriptPath: path.join(scriptDir, 'export-clubspark-auth-session-local.mjs'),
    contentType: 'application/json; charset=utf-8',
  }],
]);

const activeRuns = new Map();

function runExporter(scriptPath, extraEnv = {}) {
  const runKey = JSON.stringify([scriptPath, extraEnv]);

  if (activeRuns.has(runKey)) {
    return activeRuns.get(runKey);
  }

  const runPromise = new Promise((resolve) => {
    const outputPath = path.join(
      os.tmpdir(),
      `clubspark-export-${path.basename(scriptPath)}-${Date.now()}-${Math.random().toString(36).slice(2)}.csv`,
    );
    const child = spawn(process.execPath, [scriptPath], {
      cwd: scriptDir,
      env: {
        ...process.env,
        ...extraEnv,
        HEADLESS: 'true',
        CLUBSPARK_OUTPUT: outputPath,
      },
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

    child.on('close', async (code) => {
      let body = stdout;

      if (code === 0) {
        try {
          body = await fs.readFile(outputPath, 'utf8');
        } catch {
          // Fall back to stdout if the exporter did not write the temp file.
        }
      }

      await fs.rm(outputPath, { force: true }).catch(() => { });

      const result = { code: code ?? 1, stdout: body, stderr };
      activeRuns.delete(runKey);
      resolve(result);
    });
  });

  activeRuns.set(runKey, runPromise);
  return runPromise;
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  if (req.method !== 'POST') {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  const exporter = exporters.get(req.url);
  if (!exporter) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  if (exporterToken && req.headers.authorization !== `Bearer ${exporterToken}`) {
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
  if (typeof payload.targetUrl === 'string' && payload.targetUrl.trim()) {
    extraEnv.CLUBSPARK_AUTH_TARGET_URL = payload.targetUrl.trim();
  }

  const result = await runExporter(exporter.scriptPath, extraEnv);

  if (result.code !== 0) {
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(result.stderr || 'ClubSpark export failed');
    return;
  }

  res.writeHead(200, { 'Content-Type': exporter.contentType });
  res.end(result.stdout);
});

server.listen(port, '0.0.0.0', () => {
  process.stdout.write(`ClubSpark exporter listening on ${port}\n`);
});
