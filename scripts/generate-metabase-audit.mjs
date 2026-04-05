#!/usr/bin/env node

import { writeFile } from 'node:fs/promises';
import process from 'node:process';

const API_KEY = process.env.METABASE_API_KEY ?? 'mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U=';
const HOST = process.env.METABASE_HOST ?? '192.168.1.138';
const PORT = Number(process.env.METABASE_PORT ?? '3000');
const DASHBOARD_ID = Number(process.env.METABASE_DASHBOARD_ID ?? '11');
const ROOT = process.env.METABASE_AUDIT_ROOT ?? '/mnt/c/dev/avondale-n8n';

async function getJson(path) {
  const url = `http://${HOST}:${PORT}${path}`;
  const response = await fetch(url, {
    headers: { 'x-api-key': API_KEY },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`${path} -> ${response.status}: ${body.slice(0, 200)}`);
  }

  return response.json();
}

function collectQuestionLinks(value, deps) {
  if (!value) return;

  if (typeof value === 'string') {
    for (const match of value.matchAll(/\/question\/(\d+)/g)) {
      deps.add(Number(match[1]));
    }
    return;
  }

  if (Array.isArray(value)) {
    value.forEach((item) => collectQuestionLinks(item, deps));
    return;
  }

  if (typeof value === 'object') {
    Object.values(value).forEach((item) => collectQuestionLinks(item, deps));
  }
}

function linkDepsFromCard(card) {
  const deps = new Set();

  collectQuestionLinks(card.visualization_settings || {}, deps);
  collectQuestionLinks(card.parameter_mappings || [], deps);

  const stages = card.dataset_query?.stages ?? [];
  for (const stage of stages) {
    collectQuestionLinks(stage?.native, deps);
    collectQuestionLinks(stage, deps);
  }

  collectQuestionLinks(card.dataset_query?.native?.query, deps);
  collectQuestionLinks(card.dataset_query?.query, deps);

  return [...deps];
}

function countBy(items, keyFn) {
  return items.reduce((acc, item) => {
    const key = keyFn(item);
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});
}

function buildAudit(cards, dashboard, collections) {
  const cardMap = new Map(cards.map((card) => [card.id, card]));
  const collectionMap = new Map(collections.map((collection) => [collection.id, collection.name]));
  const tabsById = new Map((dashboard.tabs || []).map((tab) => [tab.id, tab.name]));

  const direct = [];
  const usedIds = new Set();
  const indirect = [];
  const seenIndirect = new Set();

  for (const dashcard of dashboard.dashcards || []) {
    if (!dashcard.card_id) continue;

    const card = cardMap.get(dashcard.card_id);
    if (!card) continue;

    usedIds.add(card.id);
    const deps = linkDepsFromCard(card).filter((id) => cardMap.has(id));

    direct.push({
      dashcard_id: dashcard.id,
      card_id: card.id,
      name: card.name,
      type: card.type,
      tab: tabsById.get(dashcard.dashboard_tab_id) || 'Unassigned',
      deps,
    });

    for (const depId of deps) {
      usedIds.add(depId);
      if (seenIndirect.has(depId)) continue;
      seenIndirect.add(depId);

      const dep = cardMap.get(depId);
      indirect.push({
        card_id: dep.id,
        name: dep.name,
        type: dep.type,
        via: card.id,
        via_dashcard_id: dashcard.id,
      });
    }
  }

  direct.sort((a, b) => a.tab.localeCompare(b.tab) || a.card_id - b.card_id);
  indirect.sort((a, b) => a.card_id - b.card_id);

  const used = cards.filter((card) => usedIds.has(card.id));
  const unused = cards
    .filter((card) => !usedIds.has(card.id))
    .map((card) => ({
      id: card.id,
      name: card.name,
      type: card.type,
      database_id: card.database_id ?? null,
      collection_id: card.collection_id ?? null,
      collection_name:
        card.collection_id == null
          ? 'No Collection'
          : (collectionMap.get(card.collection_id) || `Collection ${card.collection_id}`),
      source_card_id: card.source_card_id ?? null,
    }));

  const unusedCounts = {
    total: unused.length,
    by_type: countBy(unused, (item) => item.type),
    by_collection_name: countBy(unused, (item) => item.collection_name),
    by_database_id: countBy(unused, (item) => String(item.database_id)),
  };

  const unusedByTypeThenCollection = {};
  for (const item of unused) {
    if (!unusedByTypeThenCollection[item.type]) unusedByTypeThenCollection[item.type] = {};
    if (!unusedByTypeThenCollection[item.type][item.collection_name]) {
      unusedByTypeThenCollection[item.type][item.collection_name] = [];
    }
    unusedByTypeThenCollection[item.type][item.collection_name].push(item);
  }

  for (const type of Object.keys(unusedByTypeThenCollection)) {
    for (const collectionName of Object.keys(unusedByTypeThenCollection[type])) {
      unusedByTypeThenCollection[type][collectionName].sort(
        (a, b) => a.name.localeCompare(b.name) || a.id - b.id,
      );
    }
  }

  return {
    generated_at: new Date().toISOString(),
    dashboard: {
      id: dashboard.id,
      name: dashboard.name,
      tab_count: (dashboard.tabs || []).length,
      dashcard_count: (dashboard.dashcards || []).length,
      question_dashcards: direct.filter((item) => item.type === 'question').length,
    },
    used_counts: {
      total: used.length,
      by_type: countBy(used, (item) => item.type),
    },
    unused_counts: unusedCounts,
    direct,
    indirect,
    unused_by_type_then_collection: unusedByTypeThenCollection,
    unused,
  };
}

function buildAuditMarkdown(cards, audit) {
  const lines = [];

  lines.push('# Metabase Audit: Avondale Membership Dashboard', '');
  lines.push(`Generated: ${audit.generated_at}`, '');
  lines.push('## Scope');
  lines.push(`- Dashboard: ${audit.dashboard.name} (${audit.dashboard.id})`);
  lines.push(`- Tabs: ${audit.dashboard.tab_count}`);
  lines.push(`- Dashcards: ${audit.dashboard.dashcard_count}`);
  lines.push(`- Question/model/metric inventory: ${cards.length}`, '');
  lines.push('## Used By Dashboard');
  lines.push(`- Direct question cards on dashboard: ${audit.direct.length}`);
  lines.push(`- Indirect linked cards reachable from dashboard cards: ${audit.indirect.length}`);
  lines.push(`- Total used cards: ${audit.used_counts.total}`);
  lines.push(`- Used by type: ${JSON.stringify(audit.used_counts.by_type)}`);
  lines.push(`- Used models by dashboard: ${audit.used_counts.by_type.model || 0}`);
  lines.push(`- Used metrics by dashboard: ${audit.used_counts.by_type.metric || 0}`, '');
  lines.push('### Direct Dashboard Cards');

  for (const item of audit.direct) {
    const depText = item.deps.length ? ` -> links/references ${item.deps.join(', ')}` : '';
    lines.push(`- [${item.tab}] ${item.card_id} ${item.name} (${item.type})${depText}`);
  }

  lines.push('', '### Indirectly Used Cards');
  for (const item of audit.indirect) {
    lines.push(
      `- ${item.card_id} ${item.name} (${item.type}) via card:${item.via}, dashcard:${item.via_dashcard_id}`,
    );
  }

  lines.push('', '## Not Used By Dashboard');
  lines.push(`- Total unused items: ${audit.unused_counts.total}`);
  lines.push(`- Unused by type: ${JSON.stringify(audit.unused_counts.by_type)}`);
  lines.push(`- Unused by collection: ${JSON.stringify(audit.unused_counts.by_collection_name)}`);
  lines.push(`- Unused by database_id: ${JSON.stringify(audit.unused_counts.by_database_id)}`, '');
  lines.push('### Unused Items By Category');

  for (const type of Object.keys(audit.unused_by_type_then_collection).sort()) {
    const groups = audit.unused_by_type_then_collection[type];
    const typeCount = Object.values(groups).reduce((total, items) => total + items.length, 0);
    lines.push(`#### ${type.charAt(0).toUpperCase() + type.slice(1)}s (${typeCount})`);

    for (const collectionName of Object.keys(groups).sort()) {
      const items = groups[collectionName];
      lines.push(`- ${collectionName}: ${items.length}`);
      for (const item of items) {
        const src = item.source_card_id == null ? '' : ` source_card_id=${item.source_card_id}`;
        lines.push(
          `  - ${item.id} ${item.name} collection_id=${item.collection_id} database_id=${item.database_id}${src}`,
        );
      }
    }

    lines.push('');
  }

  return lines.join('\n') + '\n';
}

function buildClassification(audit) {
  const unused = audit.unused;
  const byName = new Map();

  for (const item of unused) {
    const arr = byName.get(item.name) || [];
    arr.push(item);
    byName.set(item.name, arr);
  }

  const examples = unused.filter((item) => item.collection_name === 'Examples');
  const noCollection = unused.filter((item) => item.collection_name === 'No Collection');
  const sourceDerived = unused.filter((item) => item.source_card_id != null);
  const highDupGroups = [...byName.entries()]
    .map(([name, items]) => ({ name, count: items.length, items }))
    .filter((group) => group.count >= 4)
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));

  const duplicateItems = highDupGroups.reduce((total, group) => total + group.count, 0);

  const likelyOperationalNames = new Set([
    'Key Holders - Selected Year',
    'Keys In Stock',
    'Remaining Key Cases - Selected Year',
    'Completed Key Issues Since Stock Baseline',
    'Processed Signups Base',
    'Processed Signups base',
    'Consolidated by Payer Address (for labels) by Batch',
    'Email Status Count',
    'Contacts - Selected Year',
    'Members - Selected Year',
    'Members by category',
    'Current Members - Selected Year (Map)',
    'Count of Members - Selected Year',
    'Count of Non-Active Members - Selected Year',
    'Count of Non-Active Members - Previous Year',
    'Non-Active Members - Selected Year (Records)',
    'Non-Active Members - Previous Year (Records)',
    'Summary of Keys',
    'Age Ranges',
  ]);

  const likelyOperational = unused.filter((item) => likelyOperationalNames.has(item.name));
  const keepIds = new Set(
    [...examples, ...noCollection, ...sourceDerived, ...likelyOperational].map((item) => item.id),
  );
  const saferDeleteCandidates = unused.filter((item) => !keepIds.has(item.id));

  return {
    generated_at: new Date().toISOString(),
    totals: {
      unused_total: unused.length,
      questions: unused.filter((item) => item.type === 'question').length,
      models: unused.filter((item) => item.type === 'model').length,
    },
    categories: {
      examples_collection: { count: examples.length },
      no_collection: { count: noCollection.length },
      source_derived: { count: sourceDerived.length },
      high_duplication_items: { count: duplicateItems, group_count: highDupGroups.length },
      likely_operational_keep_for_now: { count: likelyOperational.length },
      heuristic_safer_delete_candidates: { count: saferDeleteCandidates.length },
    },
    top_duplicate_name_groups: highDupGroups.slice(0, 30).map((group) => ({
      name: group.name,
      count: group.count,
      collections: [...new Set(group.items.map((item) => item.collection_name))],
    })),
    likely_operational_items: likelyOperational.map((item) => ({
      id: item.id,
      name: item.name,
      type: item.type,
      collection_name: item.collection_name,
    })),
    safer_delete_candidates_sample: saferDeleteCandidates.slice(0, 120).map((item) => ({
      id: item.id,
      name: item.name,
      type: item.type,
      collection_name: item.collection_name,
      source_card_id: item.source_card_id,
    })),
  };
}

function buildClassificationMarkdown(classification) {
  const lines = [];

  lines.push('# Metabase Unused Content Classification', '');
  lines.push(`Generated: ${classification.generated_at}`, '');
  lines.push('## Headline');
  lines.push(`- Total unused items: ${classification.totals.unused_total}`);
  lines.push(`- Questions: ${classification.totals.questions}`);
  lines.push(`- Models: ${classification.totals.models}`, '');
  lines.push('## Why So Many');
  lines.push('- Most of the unused set is repeated generations of the same saved questions over time.');
  lines.push('- A large block is unfiled work in `No Collection`.');
  lines.push(
    '- Another block is legacy content in the `Examples` collection, but on the real database rather than the removed Sample Database.',
  );
  lines.push(
    '- Some items are still plausibly useful operational helpers even though they are not linked from `Avondale Membership`.',
    '',
  );
  lines.push('## Classification Summary');
  lines.push(`- Examples collection: ${classification.categories.examples_collection.count}`);
  lines.push(
    `- No Collection exploratory/unfiled items: ${classification.categories.no_collection.count}`,
  );
  lines.push(
    `- Source-derived items with a parent card: ${classification.categories.source_derived.count}`,
  );
  lines.push(
    `- Items in high-duplication name groups: ${classification.categories.high_duplication_items.count} across ${classification.categories.high_duplication_items.group_count} name groups`,
  );
  lines.push(
    `- Likely operational keep-for-now items: ${classification.categories.likely_operational_keep_for_now.count}`,
  );
  lines.push(
    `- Heuristic safer-delete candidates after excluding the above: ${classification.categories.heuristic_safer_delete_candidates.count}`,
    '',
  );
  lines.push('## Top Duplicate Name Groups');

  for (const group of classification.top_duplicate_name_groups) {
    lines.push(`- ${group.name}: ${group.count} copies (${group.collections.join(', ')})`);
  }

  lines.push('', '## Likely Keep For Now');
  for (const item of classification.likely_operational_items) {
    lines.push(`- ${item.id} ${item.name} (${item.type}) [${item.collection_name}]`);
  }

  lines.push('', '## Safer Delete Candidates');
  lines.push(
    '- These are heuristic candidates only. They exclude `Examples`, `No Collection`, source-derived items, and a short allowlist of likely operational helpers.',
  );

  for (const item of classification.safer_delete_candidates_sample) {
    const src = item.source_card_id == null ? '' : ` source_card_id=${item.source_card_id}`;
    lines.push(`- ${item.id} ${item.name} (${item.type}) [${item.collection_name}]${src}`);
  }

  return lines.join('\n') + '\n';
}

const cards = await getJson('/api/card');
const dashboard = await getJson(`/api/dashboard/${DASHBOARD_ID}`);
const collections = await getJson('/api/collection');
const DOCS_DIR = `${ROOT}/docs`;

const audit = buildAudit(cards, dashboard, collections);
const classification = buildClassification(audit);

await writeFile(`${DOCS_DIR}/METABASE_DASHBOARD_11_AUDIT.json`, JSON.stringify(audit, null, 2));
await writeFile(`${DOCS_DIR}/METABASE_DASHBOARD_11_AUDIT.md`, buildAuditMarkdown(cards, audit));
await writeFile(`${DOCS_DIR}/METABASE_UNUSED_CLASSIFICATION.json`, JSON.stringify(classification, null, 2));
await writeFile(`${DOCS_DIR}/METABASE_UNUSED_CLASSIFICATION.md`, buildClassificationMarkdown(classification));

console.log(
  JSON.stringify(
    {
      generated_at: audit.generated_at,
      used_total: audit.used_counts.total,
      indirect_used: audit.indirect.length,
      unused_total: audit.unused_counts.total,
    },
    null,
    2,
  ),
);
