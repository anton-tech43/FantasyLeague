#!/usr/bin/env bash
# run_audit.sh — kör det read-only query-paketet för självrannsakan 2026-09.
#
# Läser SUPABASE_DB_URL ur backend/.env (samma mönster som scripts/insights.sh).
# Skriver ~40 CSV/JSON-filer till audit/2026-09/out/. Inget skrivs till DB.
#
# Usage:  ./audit/2026-09/run_audit.sh
#         (från repo-roten; ~1–3 min beroende på tabellstorlek)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
set -a && source "$ROOT/backend/.env" && set +a

PSQL="${PSQL:-/opt/homebrew/opt/libpq/bin/psql}"
command -v "$PSQL" >/dev/null 2>&1 || PSQL="psql"

mkdir -p "$HERE/out"
cd "$HERE"

echo "== Självrannsakan 2026-09: kör queries.sql (read-only) =="
"$PSQL" "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=0 -f queries.sql

echo
echo "== Filer =="
ls -la out/ | sed 's/^/  /'
echo
echo "Zippa och dela:  (cd audit/2026-09 && zip -r audit_out_$(date +%Y%m%d).zip out/)"
