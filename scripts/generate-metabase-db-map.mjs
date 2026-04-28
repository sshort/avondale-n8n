#!/usr/bin/env node

import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const defaultStateRoot = path.join(repoRoot, 'state', 'metabase');

const usage = `Usage:
  node scripts/generate-metabase-db-map.mjs <local|live> <local|live> [--out path]

Environment:
  METABASE_LOCAL_URL               Default: http://192.168.1.138:3000
  METABASE_LOCAL_TOKEN             Default: repo API key
  METABASE_LOCAL_USERNAME
  METABASE_LOCAL_PASSWORD
  METABASE_LIVE_URL
  METABASE_LIVE_TOKEN
  METABASE_LIVE_USERNAME
  METABASE_LIVE_PASSWORD
  METABASE_STATE_ROOT              Default: state/metabase
  METABASE_DB_NAME_MAP             Optional comma-separated source=target overrides
`;

function parseCli(argv) {
  const args = [...argv];
  const options = {
    stateRoot: process.env.METABASE_STATE_ROOT
      ? path.resolve(process.env.METABASE_STATE_ROOT)
      : defaultStateRoot,
    out: null,
  };

  while (args.length > 0) {
    const token = args[0];
    if (!token.startsWith('--')) break;
    args.shift();

    if (token === '--out') {
      const value = args.shift();
      if (!value) throw new Error('--out requires a file path');
      options.out = path.resolve(value);
      continue;
    }

    throw new Error(`Unknown option: ${token}`);
  }

  if (args.length !== 2) throw new Error(usage);
  const source = args[0];
  const target = args[1];
  if (!['local', 'live'].includes(source) || !['local', 'live'].includes(target) || source === target) {
    throw new Error(usage);
  }

  return { source, target, ...options };
}

function resolveInstance(instanceName) {
  const prefix = instanceName.toUpperCase();
  const url =
    instanceName === 'local'
      ? process.env.METABASE_LOCAL_URL ?? 'http://192.168.1.138:3000'
      : process.env.METABASE_LIVE_URL ?? '';
  const tokenVar = `METABASE_${prefix}_TOKEN`;
  const usernameVar = `METABASE_${prefix}_USERNAME`;
  const passwordVar = `METABASE_${prefix}_PASSWORD`;
  const defaultToken =
    instanceName === 'local' ? 'mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U=' : '';

  const token = process.env[tokenVar] ?? defaultToken;
  const username = process.env[usernameVar] ?? '';
  const password = process.env[passwordVar] ?? '';

  if (!url) {
    throw new Error(`Missing URL for ${instanceName}; set METABASE_${prefix}_URL`);
  }

  if (!token && !(username && password)) {
    throw new Error(
      `Missing credentials for ${instanceName}; set ${tokenVar} or ${usernameVar}/${passwordVar}`,
    );
  }

  return {
    name: instanceName,
    url: url.replace(/\/$/, ''),
    token,
    username,
    password,
  };
}

async function api(instance, method, requestPath, body) {
  const headers = { Accept: 'application/json' };
  if (instance.token) {
    headers['x-api-key'] = instance.token;
  } else {
    headers['Content-Type'] = 'application/json';
  }

  let payload = body;
  if (!instance.token && !requestPath.startsWith('/api/session')) {
    const sessionId = await getSessionId(instance);
    headers['X-Metabase-Session'] = sessionId;
  }

  const response = await fetch(`${instance.url}${requestPath}`, {
    method,
    headers,
    body: payload === undefined ? undefined : JSON.stringify(payload),
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${method} ${requestPath} on ${instance.name} failed: ${response.status} ${text}`);
  }

  return data;
}

async function getSessionId(instance) {
  if (instance.sessionId) return instance.sessionId;
  const response = await fetch(`${instance.url}/api/session`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      username: instance.username,
      password: instance.password,
    }),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok || !data?.id) {
    throw new Error(`POST /api/session on ${instance.name} failed: ${response.status} ${text}`);
  }
  instance.sessionId = data.id;
  return instance.sessionId;
}

function parseNameOverrides() {
  const raw = String(process.env.METABASE_DB_NAME_MAP ?? '').trim();
  if (!raw) return new Map();

  const overrides = new Map();
  for (const entry of raw.split(',')) {
    const trimmed = entry.trim();
    if (!trimmed) continue;
    const separator = trimmed.indexOf('=');
    if (separator === -1) {
      throw new Error(`Invalid METABASE_DB_NAME_MAP entry: ${trimmed}`);
    }
    const sourceName = trimmed.slice(0, separator).trim();
    const targetName = trimmed.slice(separator + 1).trim();
    if (!sourceName || !targetName) {
      throw new Error(`Invalid METABASE_DB_NAME_MAP entry: ${trimmed}`);
    }
    overrides.set(sourceName, targetName);
  }

  return overrides;
}

function buildDbMap(sourceDatabases, targetDatabases, nameOverrides) {
  const map = {
    by_id: {},
    by_name: {},
  };

  const targetByName = new Map(targetDatabases.map((database) => [database.name, database]));
  const sampleTarget = targetDatabases.find((database) => database.is_sample) ?? null;

  for (const sourceDatabase of sourceDatabases) {
    let targetDatabase = null;
    if (sourceDatabase.is_sample) {
      targetDatabase = sampleTarget;
    } else {
      const preferredName = nameOverrides.get(sourceDatabase.name) ?? sourceDatabase.name;
      targetDatabase = targetByName.get(preferredName) ?? null;
    }

    if (!targetDatabase) continue;

    map.by_id[String(sourceDatabase.id)] = targetDatabase.id;
    map.by_name[sourceDatabase.name] = targetDatabase.id;
  }

  return map;
}

async function saveJson(filePath, value) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

async function main() {
  const cli = parseCli(process.argv.slice(2));
  const source = resolveInstance(cli.source);
  const target = resolveInstance(cli.target);
  const nameOverrides = parseNameOverrides();
  const outPath =
    cli.out ?? path.join(cli.stateRoot, `db-map.${cli.source}-to-${cli.target}.json`);

  const sourceResponse = await api(source, 'GET', '/api/database');
  const targetResponse = await api(target, 'GET', '/api/database');
  const sourceDatabases = Array.isArray(sourceResponse?.data) ? sourceResponse.data : sourceResponse;
  const targetDatabases = Array.isArray(targetResponse?.data) ? targetResponse.data : targetResponse;

  if (!Array.isArray(sourceDatabases) || !Array.isArray(targetDatabases)) {
    throw new Error('Unexpected /api/database response shape');
  }

  const dbMap = buildDbMap(sourceDatabases, targetDatabases, nameOverrides);
  await saveJson(outPath, dbMap);

  const mappedCount = Object.keys(dbMap.by_id).length;
  console.log(`Wrote ${outPath} with ${mappedCount} mapped databases`);
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
