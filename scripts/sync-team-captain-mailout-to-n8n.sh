#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_DIR="${TEAM_MAILOUT_GENERATED_DIR:-$ROOT_DIR/Teams/generated}"
REMOTE_HOST="${TEAM_MAILOUT_SSH_HOST:-root@n8n}"
REMOTE_DIR="${TEAM_MAILOUT_REMOTE_DIR:-/var/lib/n8n/teams-mailout/current}"
CONTAINER_DIR="${TEAM_MAILOUT_CONTAINER_DIR:-/home/node/.n8n-files/teams-mailout/current}"

manifest_json="$GENERATED_DIR/team-captain-email-jobs.json"
manifest_csv="$GENERATED_DIR/team-captain-email-jobs.csv"
captain_list="$GENERATED_DIR/team-captains-email-list.txt"
review_md="$GENERATED_DIR/CAPTAIN_EMAIL_SEND_LIST.md"
bcc_file_source="${TEAM_MAILOUT_BCC_FILE:-$ROOT_DIR/Teams/team-captain-mailout-bcc.txt}"
bcc_file_name="team-captain-mailout-bcc.txt"

if [[ ! -f "$manifest_json" ]]; then
  echo "Missing manifest: $manifest_json" >&2
  exit 1
fi

shopt -s nullglob
pdfs=("$GENERATED_DIR"/*.pdf)
if [[ ${#pdfs[@]} -eq 0 ]]; then
  echo "No PDFs found in $GENERATED_DIR" >&2
  exit 1
fi

extra_files=()
if [[ -f "$bcc_file_source" ]]; then
  extra_files+=("$bcc_file_source")
fi

ssh "$REMOTE_HOST" "mkdir -p '$REMOTE_DIR' && docker exec n8n mkdir -p '$CONTAINER_DIR'"
scp \
  "$manifest_json" \
  "$manifest_csv" \
  "$captain_list" \
  "$review_md" \
  "${extra_files[@]}" \
  "${pdfs[@]}" \
  "$REMOTE_HOST:$REMOTE_DIR/"

if [[ -f "$bcc_file_source" && "$(basename "$bcc_file_source")" != "$bcc_file_name" ]]; then
  ssh "$REMOTE_HOST" "mv '$REMOTE_DIR/$(basename "$bcc_file_source")' '$REMOTE_DIR/$bcc_file_name'"
fi

ssh "$REMOTE_HOST" "for file in '$REMOTE_DIR'/*; do docker cp \"\$file\" n8n:'$CONTAINER_DIR'/; done"

echo "Synced team captain mailout bundle to $REMOTE_HOST:$REMOTE_DIR and n8n:$CONTAINER_DIR"
