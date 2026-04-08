#!/usr/bin/env node

import { writeFile } from 'node:fs/promises';

const API_KEY = process.env.METABASE_API_KEY ?? 'mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U=';
const HOST = process.env.METABASE_HOST ?? '192.168.1.138';
const PORT = Number(process.env.METABASE_PORT ?? '3000');

async function api(method, path, body) {
  const url = `http://${HOST}:${PORT}${path}`;
  const opts = {
    method,
    headers: {
      'x-api-key': API_KEY,
      'Content-Type': 'application/json',
    },
  };
  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(url, opts);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${method} ${path} -> ${res.status}: ${text}`);
  }
  return res.json();
}

const sql = `WITH monthly AS (
  SELECT
    EXTRACT(YEAR FROM signup_date) AS yr,
    EXTRACT(MONTH FROM signup_date) AS mo,
    COUNT(*) AS cnt
  FROM member_signups
  WHERE (signup_date >= '2025-03-01' AND signup_date < '2026-03-01')
     OR (signup_date >= '2026-03-01' AND signup_date < '2027-03-01')
  GROUP BY 1, 2
),
pivoted AS (
  SELECT
    mo,
    COALESCE(SUM(CASE WHEN yr = 2025 THEN cnt END), 0) AS "Signups 2025-26",
    COALESCE(SUM(CASE WHEN yr = 2026 THEN cnt END), 0) AS "Signups 2026-27"
  FROM monthly
  GROUP BY mo
),
with_cumulative AS (
  SELECT
    mo,
    "Signups 2025-26",
    "Signups 2026-27",
    SUM("Signups 2025-26") OVER (ORDER BY mo) AS "Cumulative 2025-26",
    SUM("Signups 2026-27") OVER (ORDER BY mo) AS "Cumulative 2026-27"
  FROM pivoted
)
SELECT
  mo AS "Month",
  "Signups 2025-26",
  "Signups 2026-27",
  "Cumulative 2025-26",
  "Cumulative 2026-27"
FROM with_cumulative
ORDER BY mo`;

const cardPayload = {
  name: 'Member Signups by date - YoY Comparison',
  description: 'Year-over-year member signups: Mar 2025–Feb 2026 vs Mar 2026–Feb 2027, with cumulative totals',
  display: 'bar',
  database_id: 2,
  collection_id: 9,
  dataset_query: {
    database: 2,
    type: 'native',
    native: {
      query: sql,
      'template-tags': {},
    },
  },
  visualization_settings: {
    'graph.dimensions': ['Month'],
    'graph.metrics': ['Signups 2025-26', 'Signups 2026-27', 'Cumulative 2025-26', 'Cumulative 2026-27'],
    'graph.series_settings': {
      'Cumulative 2025-26': {
        display: 'line',
      },
      'Cumulative 2026-27': {
        display: 'line',
      },
    },
    'graph.y_axis.title': 'Signups',
    'graph.x_axis.title': 'Month (1=Mar, 2=Apr, ...)',
  },
};

console.log('Creating new card...');
const newCard = await api('POST', '/api/card', cardPayload);
console.log(`Created card ID: ${newCard.id}`);
console.log(`View at: http://${HOST}:${PORT}/question/${newCard.id}`);

await writeFile(
  `/mnt/c/dev/avondale-n8n/backups/new-card-${newCard.id}-yoy-signups.json`,
  JSON.stringify(newCard, null, 2),
);
console.log('Saved card backup.');
