#!/usr/bin/env node

import { spawn } from 'node:child_process';
import http from 'node:http';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT ?? '3001');
const exporterToken = process.env.EXPORTER_TOKEN ?? '';
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const exporterPath = path.join(scriptDir, 'export-clubspark-contacts-local.mjs');

let activeRun = null;

function runExporter() {
  if (activeRun) {
    return activeRun;
  }

  activeRun = new Promise((resolve) => {
    const child = spawn(process.execPath, [exporterPath], {
      cwd: scriptDir,
      env: {
        ...process.env,
        HEADLESS: 'true',
        CLUBSPARK_OUTPUT: '-',
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

    child.on('close', (code) => {
      const result = { code: code ?? 1, stdout, stderr };
      activeRun = null;
      resolve(result);
    });
  });

  return activeRun;
}

const server = http.createServer(async (req, res) => {
  if (req.url !== '/clubspark-export' || req.method !== 'POST') {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  if (exporterToken && req.headers.authorization !== `Bearer ${exporterToken}`) {
    res.writeHead(401, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Unauthorized');
    return;
  }

  const result = await runExporter();

  if (result.code !== 0) {
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(result.stderr || 'ClubSpark export failed');
    return;
  }

  res.writeHead(200, { 'Content-Type': 'text/csv; charset=utf-8' });
  res.end(result.stdout);
});

server.listen(port, '0.0.0.0', () => {
  process.stdout.write(`ClubSpark exporter listening on ${port}\n`);
});
