#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ps2pdf site/committee-overview.ps COMMITTEE_PROCESS_OVERVIEW.pdf
ps2pdf site/committee-overview-diagram.ps COMMITTEE_PROCESS_OVERVIEW_DIAGRAM_ONLY.pdf
