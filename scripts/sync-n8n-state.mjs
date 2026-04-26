#!/usr/bin/env node

import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const workflowsRoot = path.join(repoRoot, 'workflows');
const defaultStateRoot = path.join(repoRoot, 'state', 'n8n');
const defaultLocalBaseUrl = process.env.N8N_LOCAL_BASE_URL ?? 'http://192.168.1.237:5678';
const defaultLocalApiKey =
  process.env.N8N_LOCAL_API_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxYWEyNTY0NC1kMzg0LTQ4MTAtYmVhYS1mNTgzMTRkM2U3MGMiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY4ODQwNjQwfQ.OztpaI1pkATZk8N9eB_oUvT7zaGN7YBtYRf6PmXRs3s';

const usage = `Usage:
  node scripts/sync-n8n-state.mjs pull <local|live> [--keys key1,key2]
  node scripts/sync-n8n-state.mjs push <local|live> [--keys key1,key2]
  node scripts/sync-n8n-state.mjs mirror <local|live> <local|live> [--keys key1,key2]

Environment:
  N8N_LOCAL_BASE_URL     Default: ${defaultLocalBaseUrl}
  N8N_LOCAL_API_KEY      Default: repo docker-compose key
  N8N_LIVE_BASE_URL      Required for live sync
  N8N_LIVE_API_KEY       Required for live sync
  N8N_STATE_ROOT         Default: state/n8n
`;

function slugify(value) {
  return (
    String(value ?? '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .replace(/-{2,}/g, '-') || 'unnamed'
  );
}

function parseCli(argv) {
  const args = [...argv];
  const options = {
    keys: null,
    stateRoot: process.env.N8N_STATE_ROOT ? path.resolve(process.env.N8N_STATE_ROOT) : defaultStateRoot,
  };

  while (args.length > 0) {
    const token = args[0];
    if (!token.startsWith('--')) break;
    args.shift();

    if (token === '--keys') {
      const value = args.shift();
      if (!value) throw new Error('--keys requires a comma-separated value');
      options.keys = new Set(
        value
          .split(',')
          .map((entry) => entry.trim())
          .filter(Boolean),
      );
      continue;
    }

    if (token === '--state-root') {
      const value = args.shift();
      if (!value) throw new Error('--state-root requires a path');
      options.stateRoot = path.resolve(value);
      continue;
    }

    throw new Error(`Unknown option: ${token}`);
  }

  if (args.length < 2) throw new Error(usage);

  const command = args.shift();
  if (!['pull', 'push', 'mirror'].includes(command)) throw new Error(usage);

  const source = args.shift();
  if (!['local', 'live'].includes(source)) throw new Error(usage);

  const target = command === 'mirror' ? args.shift() : null;
  if (command === 'mirror' && !['local', 'live'].includes(target)) throw new Error(usage);

  if (args.length > 0) throw new Error(`Unexpected arguments: ${args.join(' ')}`);

  return {
    command,
    source,
    target,
    ...options,
  };
}

function resolveInstance(instanceName) {
  if (instanceName === 'local') {
    return {
      name: 'local',
      baseUrl: defaultLocalBaseUrl,
      apiKey: defaultLocalApiKey,
    };
  }

  const baseUrl = process.env.N8N_LIVE_BASE_URL ?? '';
  const apiKey = process.env.N8N_LIVE_API_KEY ?? '';
  if (!baseUrl || !apiKey) {
    throw new Error('N8N_LIVE_BASE_URL and N8N_LIVE_API_KEY are required for live sync');
  }

  return {
    name: 'live',
    baseUrl,
    apiKey,
  };
}

async function api(instance, method, requestPath, body) {
  const response = await fetch(`${instance.baseUrl.replace(/\/$/, '')}${requestPath}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-N8N-API-KEY': instance.apiKey,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const error = new Error(
      `${method} ${requestPath} on ${instance.name} failed: ${response.status} ${text}`,
    );
    error.status = response.status;
    throw error;
  }

  return data?.data ?? data;
}

async function listWorkflows(instance) {
  const workflows = [];
  let cursor = null;

  while (true) {
    const query = new URLSearchParams({ limit: '250' });
    if (cursor) query.set('cursor', cursor);
    const payload = await api(instance, 'GET', `/api/v1/workflows?${query.toString()}`);
    const items = Array.isArray(payload) ? payload : payload?.data ?? [];
    workflows.push(...items);
    cursor = payload?.nextCursor ?? null;
    if (!cursor || items.length === 0) break;
  }

  workflows.sort((left, right) => String(left.name ?? '').localeCompare(String(right.name ?? '')));
  return workflows;
}

async function getWorkflow(instance, workflowId) {
  return api(instance, 'GET', `/api/v1/workflows/${encodeURIComponent(workflowId)}`);
}

async function createWorkflow(instance, payload) {
  return api(instance, 'POST', '/api/v1/workflows', payload);
}

async function updateWorkflow(instance, workflowId, payload) {
  return api(instance, 'PUT', `/api/v1/workflows/${encodeURIComponent(workflowId)}`, payload);
}

function canonicalizeWorkflow(workflow) {
  return {
    name: workflow.name ?? '',
    active: Boolean(workflow.active),
    nodes: workflow.nodes ?? [],
    connections: workflow.connections ?? {},
    settings: workflow.settings ?? {},
    staticData: workflow.staticData ?? {},
    pinData: workflow.pinData ?? {},
    meta: workflow.meta ?? {},
    tags: workflow.tags ?? [],
    description: workflow.description ?? '',
  };
}

async function loadJson(filePath, fallback) {
  try {
    return JSON.parse(await readFile(filePath, 'utf8'));
  } catch (error) {
    if (error?.code === 'ENOENT') return fallback;
    throw error;
  }
}

async function saveJson(filePath, data) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

async function loadManifest(manifestPath) {
  const manifest = await loadJson(manifestPath, { version: 1, resources: [] });
  if (!Array.isArray(manifest.resources)) manifest.resources = [];
  return manifest;
}

function sortManifest(manifest) {
  manifest.resources.sort((left, right) => left.key.localeCompare(right.key));
  return manifest;
}

function selectedEntries(resources, keys) {
  if (!keys) return resources;
  return resources.filter((resource) => keys.has(resource.key));
}

function inferKeyFromFile(filePath) {
  return path.basename(filePath, '.json');
}

async function hydrateManifestFromWorkflows(manifest) {
  const entries = await readdir(workflowsRoot, { withFileTypes: true });
  const knownFiles = new Set(manifest.resources.map((resource) => resource.file));
  const knownKeys = new Set(manifest.resources.map((resource) => resource.key));

  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (!entry.name.endsWith('.json')) continue;
    if (entry.name.endsWith('.live-export.json')) continue;

    const relativeFile = `workflows/${entry.name}`;
    if (knownFiles.has(relativeFile)) continue;

    const filePath = path.join(workflowsRoot, entry.name);
    const workflow = await loadJson(filePath, null);
    if (!workflow || typeof workflow !== 'object') continue;

    const derivedName = String(workflow.name ?? inferKeyFromFile(entry.name)).trim() || inferKeyFromFile(entry.name);
    let key = inferKeyFromFile(entry.name);
    if (knownKeys.has(key)) {
      key = slugify(derivedName);
    }
    while (knownKeys.has(key)) {
      key = `${key}-copy`;
    }

    manifest.resources.push({
      key,
      name: derivedName,
      file: relativeFile,
      ids: {},
    });
    knownFiles.add(relativeFile);
    knownKeys.add(key);
  }

  return manifest;
}

async function ensureWorkflowManifest(manifestPath) {
  const manifest = await loadManifest(manifestPath);
  return hydrateManifestFromWorkflows(manifest);
}

async function pullFromInstance(instanceName, stateRoot, keys) {
  const manifestPath = path.join(stateRoot, 'manifest.json');
  const manifest = await ensureWorkflowManifest(manifestPath);
  const instance = resolveInstance(instanceName);
  const summaries = await listWorkflows(instance);
  const selectedSummaries = keys
    ? summaries.filter((summary) => {
        const existing =
          manifest.resources.find((resource) => resource.ids?.[instanceName] === summary.id) ??
          manifest.resources.find((resource) => resource.name === summary.name) ??
          manifest.resources.find((resource) => resource.key === slugify(summary.name));
        return keys.has(existing?.key ?? slugify(summary.name));
      })
    : summaries;

  const pulledKeys = [];
  for (const summary of selectedSummaries) {
    let full;
    try {
      full = await getWorkflow(instance, summary.id);
    } catch (error) {
      if (error?.status === 404) {
        console.warn(`Skipping stale workflow id ${summary.id} from ${instanceName}; it is listed but not fetchable`);
        continue;
      }
      throw error;
    }
    const canonical = canonicalizeWorkflow(full);
    let resource =
      manifest.resources.find((entry) => entry.ids?.[instanceName] === summary.id) ??
      manifest.resources.find((entry) => entry.name === canonical.name);

    if (!resource) {
      resource = {
        key: slugify(canonical.name),
        name: canonical.name,
        file: `workflows/${slugify(canonical.name)}.json`,
        ids: {},
      };
      manifest.resources.push(resource);
    }

    resource.name = canonical.name;
    resource.file = resource.file || `workflows/${resource.key}.json`;
    resource.ids = resource.ids ?? {};
    resource.ids[instanceName] = summary.id;

    const filePath = path.join(repoRoot, resource.file);
    await saveJson(filePath, canonical);
    pulledKeys.push(resource.key);
  }

  await saveJson(manifestPath, sortManifest(manifest));
  return pulledKeys;
}

async function pushToInstance(instanceName, stateRoot, keys) {
  const manifestPath = path.join(stateRoot, 'manifest.json');
  const manifest = await ensureWorkflowManifest(manifestPath);
  const instance = resolveInstance(instanceName);
  const resources = selectedEntries(manifest.resources, keys);
  const summaries = await listWorkflows(instance);
  const summariesByName = new Map(summaries.map((summary) => [summary.name, summary]));
  const pushedKeys = [];

  for (const resource of resources) {
    const filePath = path.join(repoRoot, resource.file);
    const payload = canonicalizeWorkflow(await loadJson(filePath));
    if (!payload.name) throw new Error(`Workflow file is missing a name: ${resource.file}`);

    let targetId = resource.ids?.[instanceName] ?? summariesByName.get(payload.name)?.id ?? null;
    let result;

    if (targetId) {
      result = await updateWorkflow(instance, targetId, payload);
    } else {
      result = await createWorkflow(instance, payload);
      targetId = result?.id ?? result?.data?.id ?? null;
    }

    if (!resource.ids) resource.ids = {};
    if (targetId) resource.ids[instanceName] = targetId;
    resource.name = payload.name;
    pushedKeys.push(resource.key || inferKeyFromFile(resource.file));
  }

  await saveJson(manifestPath, sortManifest(manifest));
  return pushedKeys;
}

async function main() {
  const cli = parseCli(process.argv.slice(2));

  if (cli.command === 'pull') {
    const pulled = await pullFromInstance(cli.source, cli.stateRoot, cli.keys);
    console.log(`Pulled ${pulled.length} workflows from ${cli.source} into workflows/`);
    return;
  }

  if (cli.command === 'push') {
    const pushed = await pushToInstance(cli.source, cli.stateRoot, cli.keys);
    console.log(`Pushed ${pushed.length} workflows from workflows/ to ${cli.source}`);
    return;
  }

  const pulled = await pullFromInstance(cli.source, cli.stateRoot, cli.keys);
  const pushed = await pushToInstance(cli.target, cli.stateRoot, cli.keys);
  console.log(
    `Mirrored ${pulled.length} workflows from ${cli.source} through workflows/ into ${cli.target} (${pushed.length} pushed)`,
  );
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
