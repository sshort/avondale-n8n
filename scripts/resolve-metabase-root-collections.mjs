#!/usr/bin/env node

import process from 'node:process';

const usage = `Usage:
  node scripts/resolve-metabase-root-collections.mjs <local|live>

Environment:
  METABASE_LOCAL_URL               Default: http://192.168.1.138:3000
  METABASE_LOCAL_TOKEN             Default: repo API key
  METABASE_LOCAL_USERNAME
  METABASE_LOCAL_PASSWORD
  METABASE_LIVE_URL
  METABASE_LIVE_TOKEN
  METABASE_LIVE_USERNAME
  METABASE_LIVE_PASSWORD
  METABASE_EXCLUDE_ROOT_COLLECTION_NAMES  Default: Examples,Trash
`;

function parseCli(argv) {
  if (argv.length !== 1 || !['local', 'live'].includes(argv[0])) {
    throw new Error(usage);
  }
  return argv[0];
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
    sessionId: null,
  };
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

async function api(instance, requestPath) {
  const headers = { Accept: 'application/json' };
  if (instance.token) {
    headers['x-api-key'] = instance.token;
  } else {
    headers['X-Metabase-Session'] = await getSessionId(instance);
  }

  const response = await fetch(`${instance.url}${requestPath}`, { headers });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`GET ${requestPath} on ${instance.name} failed: ${response.status} ${text}`);
  }

  return data;
}

function excludedNames() {
  return new Set(
    String(process.env.METABASE_EXCLUDE_ROOT_COLLECTION_NAMES ?? 'Examples,Trash')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

async function main() {
  const instanceName = parseCli(process.argv.slice(2));
  const instance = resolveInstance(instanceName);
  const exclude = excludedNames();
  const payload = await api(instance, '/api/collection');
  const collections = Array.isArray(payload) ? payload : payload?.data ?? [];

  if (!Array.isArray(collections)) {
    throw new Error('Unexpected /api/collection response shape');
  }

  const rootCollectionIds = collections
    .filter((collection) => collection.parent_id == null)
    .filter((collection) => !collection.personal_owner_id)
    .filter((collection) => !collection.archived)
    .filter((collection) => !exclude.has(String(collection.name ?? '')))
    .map((collection) => collection.id)
    .filter((id) => typeof id === 'number')
    .sort((left, right) => left - right);

  console.log(rootCollectionIds.join(','));
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
