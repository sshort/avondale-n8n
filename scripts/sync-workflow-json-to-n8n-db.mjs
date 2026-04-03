#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';

const dbUrl = process.env.N8N_DB_URL ?? 'postgresql://postgres:6523Tike@192.168.1.248:5432/postgres';

const args = process.argv.slice(2);
if (args.length === 0 || args.length % 2 !== 0) {
  console.error('Usage: sync-workflow-json-to-n8n-db.mjs <workflow-id> <workflow-json-file> [<workflow-id> <workflow-json-file> ...]');
  process.exit(1);
}

const dollarQuote = (tag, value) => {
  const text = String(value ?? '');
  if (text.includes(`$${tag}$`)) {
    throw new Error(`Value unexpectedly contains $${tag}$ delimiter`);
  }
  return `$${tag}$${text}$${tag}$`;
};

const buildUpdateSql = (workflowId, workflow) => {
  const parts = [
    `name = ${dollarQuote('name', workflow.name)}`,
    `nodes = ${dollarQuote('nodes', JSON.stringify(workflow.nodes ?? []))}::json`,
    `connections = ${dollarQuote('connections', JSON.stringify(workflow.connections ?? {}))}::json`,
    `settings = ${dollarQuote('settings', JSON.stringify(workflow.settings ?? {}))}::json`,
    `"pinData" = ${dollarQuote('pinData', JSON.stringify(workflow.pinData ?? {}))}::json`,
    `"updatedAt" = NOW()`,
  ];

  return `UPDATE n8n.workflow_entity
SET ${parts.join(',\n    ')}
WHERE id = ${dollarQuote('id', workflowId)};`;
};

const statements = [];
for (let index = 0; index < args.length; index += 2) {
  const workflowId = args[index];
  const workflowPath = args[index + 1];
  const workflow = JSON.parse(await readFile(workflowPath, 'utf8'));
  statements.push(buildUpdateSql(workflowId, workflow));
}

const sql = `BEGIN;\n${statements.join('\n')}\nCOMMIT;\n`;

const result = spawnSync('psql', [dbUrl, '-v', 'ON_ERROR_STOP=1', '-f', '-'], {
  input: sql,
  encoding: 'utf8',
});

if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}
