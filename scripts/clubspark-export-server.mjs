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
  ['/clubspark-export', path.join(scriptDir, 'export-clubspark-contacts-local.mjs')],
  ['/clubspark-members-export', path.join(scriptDir, 'export-clubspark-members-local.mjs')],
]);

const activeRuns = new Map();

function runExporter(scriptPath) {
  if (activeRuns.has(scriptPath)) {
    return activeRuns.get(scriptPath);
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

      await fs.rm(outputPath, { force: true }).catch(() => {});

      const result = { code: code ?? 1, stdout: body, stderr };
      activeRuns.delete(scriptPath);
      resolve(result);
    });
  });

  activeRuns.set(scriptPath, runPromise);
  return runPromise;
}

const server = http.createServer(async (req, res) => {
  if (req.method !== 'POST') {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  const scriptPath = exporters.get(req.url);
  if (!scriptPath) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  if (exporterToken && req.headers.authorization !== `Bearer ${exporterToken}`) {
    res.writeHead(401, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Unauthorized');
    return;
  }

  const result = await runExporter(scriptPath);

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
