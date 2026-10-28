#!/usr/bin/env bash
# sql.sh — run psql against the production database with backend/.env loaded.
#
#   ./scripts/sql.sh -c "SELECT 1"
#   ./scripts/sql.sh -f backend/supabase/migrations/136_players_known_as.sql
#
# Every argument goes straight to psql. Exists so one allow rule
# (Bash(./scripts/sql.sh:*)) covers database work without each command having
# to source the .env itself.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source backend/.env; set +a
exec /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 "$@"
