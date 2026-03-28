#!/usr/bin/env bash
set -euo pipefail

DB_URL="${1:-postgresql://postgres@homedb:5432/postgres}"

PSQL=(psql "$DB_URL" -v ON_ERROR_STOP=1 -F $'\t' -At)

"${PSQL[@]}" -f sql/023_member_contact_matching_regression_checks.sql >/dev/null

results="$("${PSQL[@]}" -c "select check_name, ok, expected, actual from public.run_member_contact_matching_regression_checks();")"
printf '%s\n' "$results"

if "${PSQL[@]}" -c "select exists (select 1 from public.run_member_contact_matching_regression_checks() where not ok);" | grep -qx 't'; then
  echo "Member/contact matching regression checks failed." >&2
  exit 1
fi

echo "Member/contact matching regression checks passed."
