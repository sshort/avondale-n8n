#!/usr/bin/env node

import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

if (!process.env.PORT) {
  process.env.PORT = '3001';
}

if (!process.env.EXPORTER_DEFAULT_SCRIPT_DIR) {
  process.env.EXPORTER_DEFAULT_SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
}

await import('../browser-automation/scripts/browser-automation-server.mjs');
