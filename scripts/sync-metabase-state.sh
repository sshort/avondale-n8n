#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state_root="${METABASE_STATE_ROOT:-$repo_root/state/metabase}"
export_dir="${METABASE_EXPORT_DIR:-$state_root/export}"
metabase_version="${METABASE_VERSION:-v58}"
conflict_mode="${METABASE_CONFLICT_MODE:-overwrite}"
include_archived="${METABASE_INCLUDE_ARCHIVED:-0}"
include_dashboards="${METABASE_INCLUDE_DASHBOARDS:-1}"
include_permissions="${METABASE_INCLUDE_PERMISSIONS:-0}"
apply_permissions="${METABASE_APPLY_PERMISSIONS:-0}"
refresh_db_map="${METABASE_REFRESH_DB_MAP:-0}"
exclude_root_collection_names="${METABASE_EXCLUDE_ROOT_COLLECTION_NAMES:-Examples,Trash}"

usage() {
  cat <<EOF
Usage:
  bash scripts/sync-metabase-state.sh pull <local|live>
  bash scripts/sync-metabase-state.sh push <local|live>
  bash scripts/sync-metabase-state.sh mirror <local|live> <local|live>

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
  METABASE_EXPORT_DIR              Default: state/metabase/export
  METABASE_VERSION                 Default: v58
  METABASE_DB_MAP                  Optional explicit db map path
  METABASE_DB_NAME_MAP             Optional comma-separated source=target db name overrides
  METABASE_REFRESH_DB_MAP          Default: 0 (set to 1 to rebuild db map before push/mirror)
  METABASE_EXCLUDE_ROOT_COLLECTION_NAMES  Default: Examples,Trash
  METABASE_ROOT_COLLECTIONS        Optional comma-separated root collection ids for export
  METABASE_INCLUDE_ARCHIVED        Default: 0
  METABASE_CONFLICT_MODE           Default: overwrite
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

instance_url() {
  case "$1" in
    local) printf '%s' "${METABASE_LOCAL_URL:-http://192.168.1.138:3000}" ;;
    live) printf '%s' "${METABASE_LIVE_URL:-}" ;;
    *) return 1 ;;
  esac
}

append_auth_args() {
  local prefix="$1"
  local role="$2"
  local token_var="METABASE_${prefix}_TOKEN"
  local username_var="METABASE_${prefix}_USERNAME"
  local password_var="METABASE_${prefix}_PASSWORD"
  local default_token=""

  if [[ "$prefix" == "LOCAL" ]]; then
    default_token="mb_QZv1nRGkOw0sC4395vpxm3RSk0pguw0o3O5PPHm5J9U="
  fi

  local token="${!token_var:-$default_token}"
  local username="${!username_var:-}"
  local password="${!password_var:-}"

  if [[ -n "$token" ]]; then
    auth_args+=( "--${role}-token" "$token" )
    return
  fi

  if [[ -n "$username" && -n "$password" ]]; then
    auth_args+=( "--${role}-username" "$username" "--${role}-password" "$password" )
    return
  fi

  echo "Missing Metabase credentials for ${role}" >&2
  exit 1
}

append_export_flags() {
  local root_collections="${METABASE_ROOT_COLLECTIONS:-}"

  if [[ -z "$root_collections" && -n "$exclude_root_collection_names" ]]; then
    require_cmd node
    root_collections="$(node "$repo_root/scripts/resolve-metabase-root-collections.mjs" "$source_env")"
  fi

  if [[ "$include_dashboards" == "1" ]]; then
    export_flags+=(--include-dashboards)
  fi
  if [[ "$include_archived" == "1" ]]; then
    export_flags+=(--include-archived)
  fi
  if [[ "$include_permissions" == "1" ]]; then
    export_flags+=(--include-permissions)
  fi
  if [[ -n "$root_collections" ]]; then
    export_flags+=(--root-collections "$root_collections")
  fi
}

clear_export_dir() {
  find "$export_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}

resolve_db_map() {
  if [[ -n "${METABASE_DB_MAP:-}" ]]; then
    printf '%s' "$METABASE_DB_MAP"
    return
  fi
  printf '%s' "$state_root/db-map.$1-to-$2.json"
}

db_map_is_empty() {
  local db_map="$1"
  [[ ! -f "$db_map" ]] && return 0
  jq -e '((.by_id // {}) | length) == 0 and ((.by_name // {}) | length) == 0' "$db_map" >/dev/null 2>&1
}

maybe_generate_db_map() {
  local source_env="$1"
  local target_env="$2"
  local db_map
  db_map="$(resolve_db_map "$source_env" "$target_env")"

  if [[ "$refresh_db_map" != "1" ]] && ! db_map_is_empty "$db_map"; then
    printf '%s' "$db_map"
    return
  fi

  require_cmd node
  node "$repo_root/scripts/generate-metabase-db-map.mjs" "$source_env" "$target_env" --out "$db_map"
  printf '%s' "$db_map"
}

require_cmd find
require_cmd metabase-export
require_cmd metabase-import
require_cmd metabase-sync
require_cmd jq
mkdir -p "$export_dir"

command="${1:-}"
source_env="${2:-}"
target_env="${3:-}"

case "$command" in
  pull)
    [[ "$source_env" == "local" || "$source_env" == "live" ]] || { usage; exit 1; }
    source_url="$(instance_url "$source_env")"
    [[ -n "$source_url" ]] || { echo "Missing URL for $source_env" >&2; exit 1; }
    auth_args=()
    export_flags=()
    append_auth_args "${source_env^^}" source
    append_export_flags
    clear_export_dir
    metabase-export \
      --metabase-version "$metabase_version" \
      --source-url "$source_url" \
      --export-dir "$export_dir" \
      "${auth_args[@]}" \
      "${export_flags[@]}"
    ;;
  push)
    [[ "$source_env" == "local" || "$source_env" == "live" ]] || { usage; exit 1; }
    target_url="$(instance_url "$source_env")"
    [[ -n "$target_url" ]] || { echo "Missing URL for $source_env" >&2; exit 1; }
    auth_args=()
    append_auth_args "${source_env^^}" target
    db_map="$(maybe_generate_db_map "$([[ "$source_env" == "live" ]] && echo local || echo live)" "$source_env")"
    [[ -f "$db_map" ]] || { echo "Missing db map: $db_map" >&2; exit 1; }
    import_flags=()
    if [[ "$include_archived" == "1" ]]; then
      import_flags+=(--include-archived)
    fi
    if [[ "$apply_permissions" == "1" ]]; then
      import_flags+=(--apply-permissions)
    fi
    metabase-import \
      --metabase-version "$metabase_version" \
      --target-url "$target_url" \
      --export-dir "$export_dir" \
      --db-map "$db_map" \
      --conflict "$conflict_mode" \
      "${auth_args[@]}" \
      "${import_flags[@]}"
    ;;
  mirror)
    [[ "$source_env" == "local" || "$source_env" == "live" ]] || { usage; exit 1; }
    [[ "$target_env" == "local" || "$target_env" == "live" ]] || { usage; exit 1; }
    source_url="$(instance_url "$source_env")"
    target_url="$(instance_url "$target_env")"
    [[ -n "$source_url" && -n "$target_url" ]] || { echo "Missing source or target URL" >&2; exit 1; }
    db_map="$(maybe_generate_db_map "$source_env" "$target_env")"
    [[ -f "$db_map" ]] || { echo "Missing db map: $db_map" >&2; exit 1; }
    auth_args=()
    export_flags=()
    append_auth_args "${source_env^^}" source
    append_auth_args "${target_env^^}" target
    append_export_flags
    import_flags=()
    clear_export_dir
    if [[ "$apply_permissions" == "1" ]]; then
      import_flags+=(--apply-permissions)
    fi
    if [[ "$include_archived" == "1" ]]; then
      import_flags+=(--include-archived)
    fi
    metabase-sync \
      --metabase-version "$metabase_version" \
      --source-url "$source_url" \
      --target-url "$target_url" \
      --export-dir "$export_dir" \
      --db-map "$db_map" \
      --conflict "$conflict_mode" \
      "${auth_args[@]}" \
      "${export_flags[@]}" \
      "${import_flags[@]}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
