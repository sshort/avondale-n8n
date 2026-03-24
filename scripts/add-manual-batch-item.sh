#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/add-manual-batch-item.sh [options]

Adds a manual item to a signup batch without creating a fake member_signups row.

Required:
  One of:
    --member "First Last"
    --venue-id "12345"
    --btn "100012345"

  And at least one item count:
    --regular-tags N
    --parent-tags N
    --key-tags N

Optional:
  --batch-id N
      Use a specific batch. If omitted, the latest Processing batch is used.

  --payer "Payer Name"
  --email "name@example.com"
  --address-1 "Line 1"
  --address-2 "Line 2"
  --address-3 "Line 3"
  --town "Town"
  --postcode "GU51 4HB"
  --notes "Free text"
  --created-by "manual_cli"

  --base-url "http://n8n:5678"
      Override the n8n base URL.

Examples:
  bash scripts/add-manual-batch-item.sh \
    --member "Hamish Graham" \
    --regular-tags 2 \
    --key-tags 1 \
    --notes "Manual top-up for replacement items"

  bash scripts/add-manual-batch-item.sh \
    --batch-id 5 \
    --venue-id "70820" \
    --parent-tags 1 \
    --created-by "metabase_admin"
EOF
}

base_url="${N8N_BASE_URL:-http://n8n:5678}"
created_by="manual_cli"
member=""
venue_id=""
btn=""
batch_id=""
payer=""
email_address=""
address_1=""
address_2=""
address_3=""
town=""
postcode=""
notes=""
regular_tags=0
parent_tags=0
key_tags=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --member) member="${2:-}"; shift 2 ;;
    --venue-id) venue_id="${2:-}"; shift 2 ;;
    --btn) btn="${2:-}"; shift 2 ;;
    --batch-id) batch_id="${2:-}"; shift 2 ;;
    --payer) payer="${2:-}"; shift 2 ;;
    --email) email_address="${2:-}"; shift 2 ;;
    --address-1) address_1="${2:-}"; shift 2 ;;
    --address-2) address_2="${2:-}"; shift 2 ;;
    --address-3) address_3="${2:-}"; shift 2 ;;
    --town) town="${2:-}"; shift 2 ;;
    --postcode) postcode="${2:-}"; shift 2 ;;
    --notes) notes="${2:-}"; shift 2 ;;
    --created-by) created_by="${2:-}"; shift 2 ;;
    --regular-tags) regular_tags="${2:-0}"; shift 2 ;;
    --parent-tags) parent_tags="${2:-0}"; shift 2 ;;
    --key-tags) key_tags="${2:-0}"; shift 2 ;;
    --base-url) base_url="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$member" && -z "$venue_id" && -z "$btn" ]]; then
  echo "Provide --member, --venue-id, or --btn." >&2
  exit 2
fi

total_items=$((regular_tags + parent_tags + key_tags))
if (( total_items <= 0 )); then
  echo "At least one of --regular-tags, --parent-tags, or --key-tags must be greater than zero." >&2
  exit 2
fi

curl_args=(
  -sS
  -G
  "${base_url%/}/webhook/add-manual-batch-item"
  --data-urlencode "created_by=${created_by}"
  --data-urlencode "regular_tags=${regular_tags}"
  --data-urlencode "parent_tags=${parent_tags}"
  --data-urlencode "key_tags=${key_tags}"
)

if [[ -n "$batch_id" ]]; then curl_args+=(--data-urlencode "batch_id=${batch_id}"); fi
if [[ -n "$member" ]]; then curl_args+=(--data-urlencode "member=${member}"); fi
if [[ -n "$venue_id" ]]; then curl_args+=(--data-urlencode "venue_id=${venue_id}"); fi
if [[ -n "$btn" ]]; then curl_args+=(--data-urlencode "btn=${btn}"); fi
if [[ -n "$payer" ]]; then curl_args+=(--data-urlencode "payer=${payer}"); fi
if [[ -n "$email_address" ]]; then curl_args+=(--data-urlencode "email_address=${email_address}"); fi
if [[ -n "$address_1" ]]; then curl_args+=(--data-urlencode "address_1=${address_1}"); fi
if [[ -n "$address_2" ]]; then curl_args+=(--data-urlencode "address_2=${address_2}"); fi
if [[ -n "$address_3" ]]; then curl_args+=(--data-urlencode "address_3=${address_3}"); fi
if [[ -n "$town" ]]; then curl_args+=(--data-urlencode "town=${town}"); fi
if [[ -n "$postcode" ]]; then curl_args+=(--data-urlencode "postcode=${postcode}"); fi
if [[ -n "$notes" ]]; then curl_args+=(--data-urlencode "notes=${notes}"); fi

response="$(curl "${curl_args[@]}")"

if command -v jq >/dev/null 2>&1; then
  echo "$response" | jq .
else
  echo "$response"
fi
