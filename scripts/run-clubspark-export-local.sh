#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_DIR="${HOME}/.cache/avondale-n8n-playwright"

mkdir -p "${TMP_DIR}"

export CLUBSPARK_EMAIL='steve@shortcentral.com'
export CLUBSPARK_PASSWORD='HQ#zo7P8C$'
export LTA_USERNAME='sshort'
export LTA_PASSWORD='fH8Urv2XrtZwXra!'
export TMPDIR="${TMP_DIR}"

exec node "${ROOT_DIR}/scripts/export-clubspark-contacts-local.mjs" "$@"
