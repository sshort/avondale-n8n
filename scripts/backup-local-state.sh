#!/usr/bin/env bash
set -euo pipefail

timestamp="${1:-$(date +%Y%m%d-%H%M%S)}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_root="${BACKUP_ROOT:-$repo_root/backups}"
backup_dir="$backup_root/${timestamp}-local-state"
workflows_dir="$backup_dir/workflows"
cards_dir="$backup_dir/cards"
dashboards_dir="$backup_dir/dashboards"

pg_host="${PGHOST:-192.168.1.248}"
pg_port="${PGPORT:-5432}"
pg_database="${PGDATABASE:-postgres}"
pg_user="${PGUSER:-postgres}"
pg_password="${PGPASSWORD:-6523Tike}"

metabase_url="${METABASE_URL:-http://192.168.1.138:3000}"
metabase_api_key="${METABASE_API_KEY:-mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U=}"

mkdir -p "$workflows_dir" "$cards_dir" "$dashboards_dir"

export PGPASSWORD="$pg_password"

pg_dump -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -n public -Fc -f "$backup_dir/local-public.dump"
pg_dump -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -n n8n -Fc -f "$backup_dir/local-n8n.dump"

curl --fail --silent --show-error --max-time 120 \
  -H "x-api-key: $metabase_api_key" \
  "$metabase_url/api/card" \
  > "$backup_dir/local-metabase-cards.json"

curl --fail --silent --show-error --max-time 120 \
  -H "x-api-key: $metabase_api_key" \
  "$metabase_url/api/dashboard" \
  > "$backup_dir/local-metabase-dashboards.json"

curl --fail --silent --show-error --max-time 120 \
  -H "x-api-key: $metabase_api_key" \
  "$metabase_url/api/table" \
  > "$backup_dir/local-metabase-tables.json"

jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-cards.json" | \
while IFS=$'\t' read -r card_id card_name; do
  safe_card_name="$(printf '%s' "$card_name" | sed 's/[^A-Za-z0-9._-]/_/g')"
  curl --fail --silent --show-error --max-time 120 \
    -H "x-api-key: $metabase_api_key" \
    "$metabase_url/api/card/$card_id" \
    | jq '.' > "$cards_dir/${card_id}-${safe_card_name}.json"
done

jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-dashboards.json" | \
while IFS=$'\t' read -r dashboard_id dashboard_name; do
  safe_dashboard_name="$(printf '%s' "$dashboard_name" | sed 's/[^A-Za-z0-9._-]/_/g')"
  curl --fail --silent --show-error --max-time 120 \
    -H "x-api-key: $metabase_api_key" \
    "$metabase_url/api/dashboard/$dashboard_id" \
    | jq '.' > "$dashboards_dir/${dashboard_id}-${safe_dashboard_name}.json"
done

psql -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -Atc "
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

psql -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -F $'\t' -Atc "
  select id, regexp_replace(name, '[^A-Za-z0-9._-]+', '_', 'g')
  from n8n.workflow_entity
  order by name;
" | while IFS=$'\t' read -r workflow_id workflow_name; do
  psql -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -Atc "
    select row_to_json(w)::text
    from (
      select *
      from n8n.workflow_entity
      where id = '$workflow_id'
    ) w;
  " | jq '.' > "$workflows_dir/${workflow_id}-${workflow_name}.json"
done

pg_restore -l "$backup_dir/local-public.dump" > /dev/null
pg_restore -l "$backup_dir/local-n8n.dump" > /dev/null

printf '%s\n' "$backup_dir"
