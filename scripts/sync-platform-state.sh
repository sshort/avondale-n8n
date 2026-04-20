#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service="all"
args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service)
      service="$2"
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

run_n8n() {
  node "$repo_root/scripts/sync-n8n-state.mjs" "${args[@]}"
}

run_metabase() {
  bash "$repo_root/scripts/sync-metabase-state.sh" "${args[@]}"
}

case "$service" in
  all)
    run_n8n
    run_metabase
    ;;
  n8n)
    run_n8n
    ;;
  metabase)
    run_metabase
    ;;
  *)
    echo "Unknown service: $service" >&2
    exit 1
    ;;
esac
