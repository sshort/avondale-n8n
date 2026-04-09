#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="test"
SKIP_GENERATE=0
SKIP_SYNC=0
SKIP_TRIGGER=0
GENERATE_ONLY=0
GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --production)
      MODE="production"
      ;;
    --test)
      MODE="test"
      ;;
    --skip-generate)
      SKIP_GENERATE=1
      ;;
    --skip-sync)
      SKIP_SYNC=1
      ;;
    --skip-trigger)
      SKIP_TRIGGER=1
      ;;
    --generate-only)
      GENERATE_ONLY=1
      ;;
    --group)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --group" >&2
        exit 1
      fi
      GROUP="$2"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--test|--production] [--group <section>] [--generate-only] [--skip-generate] [--skip-sync] [--skip-trigger]" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$GENERATE_ONLY" -eq 1 ]]; then
  SKIP_SYNC=1
  SKIP_TRIGGER=1
fi

if [[ "$SKIP_GENERATE" -eq 0 ]]; then
  if [[ -n "$GROUP" ]]; then
    TEAM_CAPTAIN_MAILOUT_GROUP="$GROUP" \
      /mnt/c/dev/postgres-mcp-venv-linux/bin/python "$ROOT_DIR/Teams/generate_team_contact_lists.py"
  else
    /mnt/c/dev/postgres-mcp-venv-linux/bin/python "$ROOT_DIR/Teams/generate_team_contact_lists.py"
  fi
fi

if [[ "$SKIP_SYNC" -eq 0 ]]; then
  bash "$ROOT_DIR/scripts/sync-team-captain-mailout-to-n8n.sh"
fi

if [[ "$SKIP_TRIGGER" -eq 0 ]]; then
  base_url="${TEAM_MAILOUT_WEBHOOK_BASE_URL:-http://192.168.1.237:5678}"
  webhook_url="${base_url%/}/webhook/send-team-captain-contact-lists"
  manifest_json="${TEAM_MAILOUT_GENERATED_DIR:-$ROOT_DIR/Teams/generated}/team-captain-email-jobs.json"
  payload_file="$(mktemp)"
  trap 'rm -f "$payload_file"' EXIT
  jq --arg mode "$MODE" \
    --arg base_dir "${TEAM_MAILOUT_CONTAINER_DIR:-/home/node/.n8n-files/teams-mailout/current}" \
    '{delivery_mode: $mode, base_dir: $base_dir, jobs: .jobs}' \
    "$manifest_json" > "$payload_file"
  echo "Triggering: $webhook_url"
  curl -sS \
    -H 'Content-Type: application/json' \
    --data-binary @"$payload_file" \
    "$webhook_url"
  echo
fi
