#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
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
planka_dir="$backup_dir/planka"
planka_projects_dir="$planka_dir/projects"
planka_boards_dir="$planka_dir/boards"

pg_host="${PGHOST:-192.168.1.248}"
pg_port="${PGPORT:-5432}"
pg_database="${PGDATABASE:-postgres}"
pg_user="${PGUSER:-postgres}"
pg_password="${PGPASSWORD:-6523Tike}"
public_backup_mode="${PUBLIC_BACKUP_MODE:-lean}"
n8n_backup_mode="${N8N_BACKUP_MODE:-config}"

metabase_url="${METABASE_URL:-http://192.168.1.138:3000}"
metabase_api_key="${METABASE_API_KEY:-mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U=}"
planka_url="${PLANKA_URL:-http://192.168.1.139}"
planka_email="${PLANKA_EMAIL:-steve.short@gmail.com}"
planka_password="${PLANKA_PASSWORD:-CbJ5S0RcwU1dBrz5LJL3}"

require_cmd curl
require_cmd jq
require_cmd pg_dump
require_cmd pg_restore
require_cmd psql
require_cmd tar

mkdir -p "$cards_dir" "$dashboards_dir" "$collections_dir" "$workflows_dir" "$planka_projects_dir" "$planka_boards_dir"

export PGPASSWORD="$pg_password"

db_url="postgresql://${pg_user}:${pg_password}@${pg_host}:${pg_port}/${pg_database}"

log "Starting full backup into $backup_dir"
log "public backup mode: $public_backup_mode"
log "n8n backup mode: $n8n_backup_mode"

api_get() {
  local path="$1"
  curl --fail --silent --show-error --max-time 120 \
    -H "x-api-key: $metabase_api_key" \
    "${metabase_url%/}${path}"
}

planka_login() {
  curl --fail --silent --show-error --max-time 120 \
    -F "emailOrUsername=$planka_email" \
    -F "password=$planka_password" \
    "${planka_url%/}/api/access-tokens" | jq -r '.item'
}

planka_api_get() {
  local token="$1"
  local path="$2"
  curl --fail --silent --show-error --max-time 120 \
    -H "Authorization: Bearer $token" \
    "${planka_url%/}${path}"
}

public_dump_args=(-h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -n public -Fc -f "$backup_dir/local-public.dump")

case "$public_backup_mode" in
  full)
    ;;
  lean)
    # Skip bulky audit data that is useful for investigations but not needed for a normal restore.
    public_dump_args+=(
      --exclude-table-data='public.raw_reconcile_match_audit'
    )
    ;;
  *)
    echo "Unsupported PUBLIC_BACKUP_MODE: $public_backup_mode (expected: lean or full)" >&2
    exit 1
    ;;
esac

n8n_dump_args=(-h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" -n n8n -Fc -f "$backup_dir/local-n8n.dump")
case "$n8n_backup_mode" in
  full)
    ;;
  config)
    # Keep workflow/config tables but skip bulky runtime and execution history payloads by default.
    n8n_dump_args+=(
      --exclude-table-data='n8n.execution_data'
      --exclude-table-data='n8n.execution_entity'
      --exclude-table-data='n8n.execution_metadata'
      --exclude-table-data='n8n.execution_annotations'
      --exclude-table-data='n8n.execution_annotation_tags'
      --exclude-table-data='n8n.insights_by_period'
      --exclude-table-data='n8n.insights_raw'
      --exclude-table-data='n8n.insights_metadata'
      --exclude-table-data='n8n.chat_hub_messages'
      --exclude-table-data='n8n.chat_hub_sessions'
      --exclude-table-data='n8n.chat_hub_agents'
      --exclude-table-data='n8n.test_case_execution'
      --exclude-table-data='n8n.test_run'
      --exclude-table-data='n8n.processed_data'
      --exclude-table-data='n8n.workflow_history'
      --exclude-table-data='n8n.workflow_publish_history'
      --exclude-table-data='n8n.workflow_statistics'
      --exclude-table-data='n8n.invalid_auth_token'
      --exclude-table-data='n8n.oauth_access_tokens'
      --exclude-table-data='n8n.oauth_refresh_tokens'
      --exclude-table-data='n8n.oauth_authorization_codes'
      --exclude-table-data='n8n.auth_provider_sync_history'
    )
    ;;
  *)
    echo "Unsupported N8N_BACKUP_MODE: $n8n_backup_mode (expected: config or full)" >&2
    exit 1
    ;;
esac

log "Dumping PostgreSQL public schema ($public_backup_mode mode)"
pg_dump "${public_dump_args[@]}"
log "Dumping PostgreSQL n8n schema ($n8n_backup_mode mode)"
pg_dump "${n8n_dump_args[@]}"

log "Fetching Metabase inventory"
api_get "/api/card" | jq '.' > "$backup_dir/local-metabase-cards.json"
api_get "/api/dashboard" | jq '.' > "$backup_dir/local-metabase-dashboards.json"
api_get "/api/table" | jq '.' > "$backup_dir/local-metabase-tables.json"
api_get "/api/collection" | jq '.' > "$backup_dir/local-metabase-collections.json"
api_get "/api/database" | jq '.' > "$backup_dir/local-metabase-databases.json"

card_count="$(jq 'length' "$backup_dir/local-metabase-cards.json")"
dashboard_count="$(jq 'length' "$backup_dir/local-metabase-dashboards.json")"
collection_count="$(jq 'length' "$backup_dir/local-metabase-collections.json")"
table_count="$(jq 'length' "$backup_dir/local-metabase-tables.json")"
database_count="$(jq 'length' "$backup_dir/local-metabase-databases.json")"

log "Exporting $card_count Metabase cards"
jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-cards.json" | \
while IFS=$'\t' read -r card_id card_name; do
  api_get "/api/card/$card_id" | jq '.' > "$cards_dir/${card_id}-$(safe_name "$card_name").json"
done

log "Exporting $dashboard_count Metabase dashboards"
jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-dashboards.json" | \
while IFS=$'\t' read -r dashboard_id dashboard_name; do
  api_get "/api/dashboard/$dashboard_id" | jq '.' > "$dashboards_dir/${dashboard_id}-$(safe_name "$dashboard_name").json"
done

log "Exporting $collection_count Metabase collection item lists"
jq -r '.[] | [.id, (.name // "unnamed")] | @tsv' "$backup_dir/local-metabase-collections.json" | \
while IFS=$'\t' read -r collection_id collection_name; do
  api_get "/api/collection/$collection_id/items" | jq '.' > "$collections_dir/${collection_id}-$(safe_name "$collection_name")-items.json"
done

log "Exporting Metabase root collection items"
api_get "/api/collection/root/items" | jq '.' > "$collections_dir/root-Our_analytics-items.json"

log "Exporting n8n workflow list"
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

workflow_count="$(jq 'length' "$backup_dir/local-workflow-list.json")"

log "Exporting $workflow_count n8n workflow definitions"
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

log "Logging into Planka"
planka_token="$(planka_login)"
if [[ -z "$planka_token" || "$planka_token" == "null" ]]; then
  echo "Failed to obtain Planka API token" >&2
  exit 1
fi

log "Exporting Planka user profile"
planka_api_get "$planka_token" "/api/users/me" | jq '.' > "$planka_dir/local-planka-user.json"

log "Exporting Planka project inventory"
planka_api_get "$planka_token" "/api/projects" | jq '.' > "$planka_dir/local-planka-projects.json"

planka_project_count="$(jq '.items | length' "$planka_dir/local-planka-projects.json")"
planka_board_count="$(jq '.included.boards | length' "$planka_dir/local-planka-projects.json")"

log "Exporting $planka_project_count Planka projects"
jq -r '.items[] | [.id, (.name // "unnamed")] | @tsv' "$planka_dir/local-planka-projects.json" | \
while IFS=$'\t' read -r project_id project_name; do
  planka_api_get "$planka_token" "/api/projects/$project_id" | jq '.' > "$planka_projects_dir/${project_id}-$(safe_name "$project_name").json"
done

log "Exporting $planka_board_count Planka boards"
jq -r '.included.boards[] | [.id, (.name // "unnamed")] | @tsv' "$planka_dir/local-planka-projects.json" | \
while IFS=$'\t' read -r board_id board_name; do
  planka_api_get "$planka_token" "/api/boards/$board_id" | jq '.' > "$planka_boards_dir/${board_id}-$(safe_name "$board_name").json"
done

log "Validating PostgreSQL dump files"
pg_restore -l "$backup_dir/local-public.dump" >/dev/null
pg_restore -l "$backup_dir/local-n8n.dump" >/dev/null

log "Writing backup summary"
jq -n \
  --arg timestamp "$timestamp" \
  --arg backup_dir "$backup_dir" \
  --arg archive_path "${backup_dir}.tar.gz" \
  --arg pg_host "$pg_host" \
  --arg pg_port "$pg_port" \
  --arg pg_database "$pg_database" \
  --arg public_backup_mode "$public_backup_mode" \
  --arg n8n_backup_mode "$n8n_backup_mode" \
  --arg metabase_url "$metabase_url" \
  --arg planka_url "$planka_url" \
  --argjson card_count "$card_count" \
  --argjson dashboard_count "$dashboard_count" \
  --argjson collection_count "$collection_count" \
  --argjson table_count "$table_count" \
  --argjson database_count "$database_count" \
  --argjson workflow_count "$workflow_count" \
  --argjson planka_project_count "$planka_project_count" \
  --argjson planka_board_count "$planka_board_count" \
  '{
    timestamp: $timestamp,
    backup_dir: $backup_dir,
    archive_path: $archive_path,
    postgres: {
      host: $pg_host,
      port: $pg_port,
      database: $pg_database,
      public_backup_mode: $public_backup_mode,
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
      backup_mode: $n8n_backup_mode,
      workflow_count: $workflow_count
    },
    planka: {
      base_url: $planka_url,
      project_count: $planka_project_count,
      board_count: $planka_board_count
    }
  }' > "$backup_dir/backup-summary.json"

log "Creating compressed archive ${backup_dir}.tar.gz"
tar -C "$backup_root" -czf "${backup_dir}.tar.gz" "$(basename "$backup_dir")"

log "Backup complete"
printf '%s\n' "$backup_dir"
printf '%s\n' "${backup_dir}.tar.gz"
