#!/usr/bin/env bash
# publish_content.sh — push the My Turn content files to Supabase so the
# app picks them up without a release.
#
# Runs the validator first and refuses to publish anything that fails it. The
# app only downloads a module whose contentVersion is newer than what it holds,
# so bump `contentVersion` in the file (YYYY-MM-DD.N) for the change to reach
# anyone. Rollback = publish the previous file again with a newer version.
#
#   set -a && source backend/.env && set +a
#   bash tools/myturn/publish_content.sh
#
# Uses psql (the local REST keys are dead — CLAUDE.md), so it needs
# SUPABASE_DB_URL in the environment.
set -euo pipefail
cd "$(dirname "$0")/../.."

python3 tools/myturn/validate_content.py --quiet

: "${SUPABASE_DB_URL:?set SUPABASE_DB_URL (source backend/.env)}"
PSQL=${PSQL:-/opt/homebrew/opt/libpq/bin/psql}
DIR=ios/GoalDigger/Resources/MyTurn

# hype needs migration 101 (the module CHECK) applied first, or the insert
# is rejected by the constraint and the loop stops there.
for module in saythis lingo quiz hype; do
  file="$DIR/$module.json"
  version=$(jq -r .contentVersion "$file")
  # Pass the JSON through a psql variable so quoting is never an issue.
  "$PSQL" "$SUPABASE_DB_URL" -q -v m="$module" -v v="$version" -v body="$(cat "$file")" <<'SQL'
INSERT INTO my_turn_content (module, content_version, body, updated_at)
VALUES (:'m', :'v', :'body'::jsonb, now())
ON CONFLICT (module) DO UPDATE
  SET content_version = EXCLUDED.content_version, body = EXCLUDED.body, updated_at = now()
  WHERE my_turn_content.content_version <> EXCLUDED.content_version
     OR my_turn_content.body <> EXCLUDED.body;
SQL
  echo "published $module $version"
done

"$PSQL" "$SUPABASE_DB_URL" -c "select module, content_version, pg_size_pretty(length(body::text)::bigint) as size, updated_at from my_turn_content order by module;"
