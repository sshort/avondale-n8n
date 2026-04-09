#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

safe_name() {
  printf '%s' "${1:-unnamed}" | sed 's/[^A-Za-z0-9._-]/_/g'
}

timestamp="${1:-$(date +%Y%m%d-%H%M%S)}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_root="${BACKUP_ROOT:-$repo_root/backups}"
backup_dir="$backup_root/${timestamp}-full-backup"
cards_dir="$backup_dir/cards"
dashboards_dir="$backup_dir/dashboards"
collections_dir="$backup_dir/collections"
workflows_dir="$backup_dir/workflows"

pg_host="${PGHOST:-192.168.1.248}"
pg_port="${PGPORT:-5432}"
pg_database="${PGDATABASE:-postgres}"
pg_user="${PGUSER:-postgres}"
pg_password="${PGPASSWORD:-6523Tike}"

metabase_url="${METABASE_URL:-http://192.168.1.138:3000}"
metabase_api_key="${METABASE_API_KEY:-mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U=}"

require_cmd curl
require_cmd jq
require_cmd pg_dump
require_cmd pg_restore
require_cmd psql
require_cmd tar

mkdir -p "$cards_dir" "$dashboards_dir" "$collections_dir" "$workflows_dir"

export PGPASSWORD="$pg_password"

db_url="postgresql://${pg_user}:${pg_password}@${pg_host}:${pg_port}/${pg_database}"

api_get() {
  local path="$1"
  curl --fail --silent --show-error --max-time 120 \
    -H "x-api-key: $metabase_api_key" \
    "${metabase_url%/}${path}"
}

pg_dump -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -n public -Fc -f "$backup_dir/local-public.dump"
pg_dump -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -n n8n -Fc -f "$backup_dir/local-n8n.dump"

api_get "/api/card" | jq '.' > "$backup_dir/local-metabase-cards.json"
api_get "/api/dashboard" | jq '.' > "$backup_dir/local-metabase-dashboards.json"
api_get "/api/table" | jq '.' > "$backup_dir/local-metabase-tables.json"
api_get "/api/collection" | jq '.' > "$backup_dir/local-metabase-collections.json"
api_get "/api/database" | jq '.' > "$backup_dir/local-metabase-databases.json"

jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-cards.json" | \
while IFS=$'\t' read -r card_id card_name; do
  api_get "/api/card/$card_id" | jq '.' > "$cards_dir/${card_id}-$(safe_name "$card_name").json"
done

jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-dashboards.json" | \
while IFS=$'\t' read -r dashboard_id dashboard_name; do
  api_get "/api/dashboard/$dashboard_id" | jq '.' > "$dashboards_dir/${dashboard_id}-$(safe_name "$dashboard_name").json"
done

jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-collections.json" | \
while IFS=$'\t' read -r collection_id collection_name; do
  api_get "/api/collection/$collection_id/items" | jq '.' > "$collections_dir/${collection_id}-$(safe_name "$collection_name")-items.json"
done

api_get "/api/collection/root/items" | jq '.' > "$collections_dir/root-Our_analytics-items.json"

psql "$db_url" -Atc "
  select coalesce(
    json_agg(
      json_build_object(
        'id', id,
        'name', name,
        'active', active,
        'updatedAt', \"updatedAt\"
      )
      order by name
    )::text,
    '[]'
  )
  from n8n.workflow_entity;
" | jq '.' > "$backup_dir/local-workflow-list.json"

psql "$db_url" -F $'\t' -Atc "
  select id, regexp_replace(name, '[^A-Za-z0-9._-]+', '_', 'g')
  from n8n.workflow_entity
  order by name;
" | while IFS=$'\t' read -r workflow_id workflow_name; do
  psql "$db_url" -Atc "
    select row_to_json(w)::text
    from (
      select *
      from n8n.workflow_entity
      where id = '$workflow_id'
    ) w;
  " | jq '.' > "$workflows_dir/${workflow_id}-${workflow_name}.json"
done

pg_restore -l "$backup_dir/local-public.dump" >/dev/null
pg_restore -l "$backup_dir/local-n8n.dump" >/dev/null

card_count="$(jq 'length' "$backup_dir/local-metabase-cards.json")"
dashboard_count="$(jq 'length' "$backup_dir/local-metabase-dashboards.json")"
collection_count="$(jq 'length' "$backup_dir/local-metabase-collections.json")"
table_count="$(jq 'length' "$backup_dir/local-metabase-tables.json")"
database_count="$(jq 'length' "$backup_dir/local-metabase-databases.json")"
workflow_count="$(jq 'length' "$backup_dir/local-workflow-list.json")"

jq -n \
  --arg timestamp "$timestamp" \
  --arg backup_dir "$backup_dir" \
  --arg archive_path "${backup_dir}.tar.gz" \
  --arg pg_host "$pg_host" \
  --arg pg_port "$pg_port" \
  --arg pg_database "$pg_database" \
  --arg metabase_url "$metabase_url" \
  --argjson card_count "$card_count" \
  --argjson dashboard_count "$dashboard_count" \
  --argjson collection_count "$collection_count" \
  --argjson table_count "$table_count" \
  --argjson database_count "$database_count" \
  --argjson workflow_count "$workflow_count" \
  '{
    timestamp: $timestamp,
    backup_dir: $backup_dir,
    archive_path: $archive_path,
    postgres: {
      host: $pg_host,
      port: $pg_port,
      database: $pg_database,
      dumps: [
        "local-public.dump",
        "local-n8n.dump"
      ]
    },
    metabase: {
      base_url: $metabase_url,
      card_count: $card_count,
      dashboard_count: $dashboard_count,
      collection_count: $collection_count,
      table_count: $table_count,
      database_count: $database_count
    },
    n8n: {
      workflow_count: $workflow_count
    }
  }' > "$backup_dir/backup-summary.json"

tar -C "$backup_root" -czf "${backup_dir}.tar.gz" "$(basename "$backup_dir")"

printf '%s\n' "$backup_dir"
printf '%s\n' "${backup_dir}.tar.gz"
