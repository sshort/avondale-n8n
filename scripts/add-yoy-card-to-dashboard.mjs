#!/usr/bin/env node

const API_KEY = process.env.METABASE_API_KEY ?? 'mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U=';
const HOST = process.env.METABASE_HOST ?? '192.168.1.138';
const PORT = Number(process.env.METABASE_PORT ?? '3000');
const DASHBOARD_ID = 11;
const NEW_CARD_ID = 1625;

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

console.log('Fetching dashboard...');
const dashboard = await api('GET', `/api/dashboard/${DASHBOARD_ID}`);

// Find the existing card 1500 dashcard
const existingDashcard = dashboard.dashcards.find(dc => dc.card_id === 1500);
if (!existingDashcard) {
  console.error('Could not find card 1500 on dashboard');
  process.exit(1);
}

console.log(`Found existing dashcard for card 1500: id=${existingDashcard.id}, row=${existingDashcard.row}, col=${existingDashcard.col}, tab=${existingDashcard.dashboard_tab_id}`);

// Add the new card below the existing one
const newDashcard = {
  card_id: NEW_CARD_ID,
  row: existingDashcard.row + existingDashcard.size_y,
  col: existingDashcard.col,
  size_x: existingDashcard.size_x,
  size_y: existingDashcard.size_y + 4, // taller for the extra series
  dashboard_tab_id: existingDashcard.dashboard_tab_id,
  parameter_mappings: [],
  series: [],
};

console.log(`Adding new dashcard at row=${newDashcard.row}, col=${newDashcard.col}, tab=${newDashcard.dashboard_tab_id}`);

const result = await api('POST', `/api/dashboard/${DASHBOARD_ID}/dashcard`, {
  dashcard: newDashcard,
});

console.log(`New dashcard created with id: ${result.id}`);
console.log(`Dashboard: http://${HOST}:${PORT}/dashboard/${DASHBOARD_ID}`);
