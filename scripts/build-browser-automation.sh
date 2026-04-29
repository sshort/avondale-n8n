#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root"

docker build \
  -f browser-automation/Dockerfile \
  -t local/browser-automation:latest \
  .
