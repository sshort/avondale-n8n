#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="test"
SKIP_GENERATE=0
SKIP_SYNC=0
SKIP_TRIGGER=0
GENERATE_ONLY=0
LIST_ONLY=0
ATTACHMENT_MODE=""
INCLUDE_SHARED_BCC_IN_TEST=1

usage() {
  cat <<'EOF'
Usage: run-team-captain-mailout.sh [options]

Options:
  --test
      Send in test mode.
  --production
      Send in production mode.
  --attachment-mode <mode>
      Choose which PDFs each captain receives.
      Modes:
        1 | own-plus-reserves
            Own team sheet plus reserves.
        2 | own-next-plus-reserves
            Own team sheet, next team down, plus reserves.
        3 | all-in-section
            Every team sheet in the captain's section. This is the default.
  --list-only
      Generate the files and print the captain/file send list without syncing or sending.
  --shared-bcc-in-test
      Include recipients from team-captain-mailout-bcc.txt during test sends.
      This is the default.
  --no-shared-bcc-in-test
      Do not include recipients from team-captain-mailout-bcc.txt during test sends.
  --generate-only
      Generate the files only. Do not sync or trigger n8n.
  --skip-generate
      Reuse the existing generated files.
  --skip-sync
      Do not copy the generated bundle to n8n.
  --skip-trigger
      Do not trigger the n8n webhook.
  -h, --help
      Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
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
    --list-only)
      LIST_ONLY=1
      ;;
    --shared-bcc-in-test)
      INCLUDE_SHARED_BCC_IN_TEST=1
      ;;
    --no-shared-bcc-in-test)
      INCLUDE_SHARED_BCC_IN_TEST=0
      ;;
    --attachment-mode)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --attachment-mode" >&2
        exit 1
      fi
      ATTACHMENT_MODE="$2"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$GENERATE_ONLY" -eq 1 ]]; then
  SKIP_SYNC=1
  SKIP_TRIGGER=1
fi

if [[ "$LIST_ONLY" -eq 1 ]]; then
  SKIP_SYNC=1
  SKIP_TRIGGER=1
fi

if [[ "$SKIP_GENERATE" -eq 0 ]]; then
  if [[ -n "$ATTACHMENT_MODE" ]]; then
    TEAM_CAPTAIN_ATTACHMENT_MODE="$ATTACHMENT_MODE" \
      /mnt/c/dev/postgres-mcp-venv-linux/bin/python "$ROOT_DIR/Teams/generate_team_contact_lists.py"
  else
    /mnt/c/dev/postgres-mcp-venv-linux/bin/python "$ROOT_DIR/Teams/generate_team_contact_lists.py"
  fi
fi

if [[ "$LIST_ONLY" -eq 1 ]]; then
  review_md="${TEAM_MAILOUT_GENERATED_DIR:-$ROOT_DIR/Teams/generated}/CAPTAIN_EMAIL_SEND_LIST.md"
  if [[ ! -f "$review_md" ]]; then
    echo "Missing send list: $review_md" >&2
    exit 1
  fi
  cat "$review_md"
  exit 0
fi

if [[ "$SKIP_SYNC" -eq 0 ]]; then
  bash "$ROOT_DIR/scripts/sync-team-captain-mailout-to-n8n.sh"
fi

if [[ "$SKIP_TRIGGER" -eq 0 ]]; then
  base_url="${TEAM_MAILOUT_WEBHOOK_BASE_URL:-http://192.168.1.237:5678}"
  webhook_url="${base_url%/}/webhook/send-team-captain-contact-lists"
  manifest_json="${TEAM_MAILOUT_GENERATED_DIR:-$ROOT_DIR/Teams/generated}/team-captain-email-jobs.json"
  shared_bcc_file="$ROOT_DIR/Teams/team-captain-mailout-bcc.txt"
  payload_file="$(mktemp)"
  trap 'rm -f "$payload_file"' EXIT
  jq --arg mode "$MODE" \
    --arg base_dir "${TEAM_MAILOUT_CONTAINER_DIR:-/home/node/.n8n-files/teams-mailout/current}" \
    --rawfile shared_bcc "$shared_bcc_file" \
    --argjson include_shared_bcc_in_test "$INCLUDE_SHARED_BCC_IN_TEST" \
    '{delivery_mode: $mode, base_dir: $base_dir, attachment_mode: .attachment_mode, include_shared_bcc_in_test: $include_shared_bcc_in_test, shared_bcc: $shared_bcc, jobs: .jobs}' \
    "$manifest_json" > "$payload_file"
  echo "Triggering: $webhook_url"
  curl -sS \
    -H 'Content-Type: application/json' \
    --data-binary @"$payload_file" \
    "$webhook_url"
  echo
fi
