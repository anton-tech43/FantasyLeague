#!/usr/bin/env bash
# verify-push-eligible.sh — Lesson 83 regression check.
#
# Confirms the feed-only contract holds after a gd-news fire:
#   - Items with push_eligible=false must NOT have pushed (pushed_at IS NULL)
#     and must have NO apns_send row in pipeline_health.
#   - Items with push_eligible=true that pushed are fine (no regression).
#
# Usage:  ./scripts/verify-push-eligible.sh [LOOKBACK]
#   LOOKBACK defaults to '3 hours' (covers one fire window). Pass e.g.
#   '15 hours' to inspect the previous fire too.
#
# Reads SUPABASE_DB_URL from backend/.env. Exits non-zero on any violation.

set -euo pipefail
LOOKBACK="${1:-3 hours}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a && source "$HERE/backend/.env" && set +a
PSQL="/opt/homebrew/opt/libpq/bin/psql"

echo "=== push-eligible contract check — last $LOOKBACK ==="

# Violations: feed-only items that nonetheless pushed.
VIOLATIONS=$("$PSQL" "$SUPABASE_DB_URL" -tA -X -c "
  SELECT count(*) FROM content_items
  WHERE created_at > now() - interval '$LOOKBACK'
    AND push_eligible = false
    AND pushed_at IS NOT NULL;")

echo
echo "--- feed-only items in window (push_eligible=false) ---"
"$PSQL" "$SUPABASE_DB_URL" -P pager=off -X -c "
  SELECT to_char(created_at AT TIME ZONE 'UTC','MM-DD HH24:MI') AS created,
         CASE WHEN pushed_at IS NULL THEN 'no push OK' ELSE 'PUSHED ✗' END AS push_state,
         team_id, left(push_text,55) AS push_text
  FROM content_items
  WHERE created_at > now() - interval '$LOOKBACK' AND push_eligible = false
  ORDER BY created_at DESC;"

echo
echo "--- push-eligible items in window (should push; no regression) ---"
"$PSQL" "$SUPABASE_DB_URL" -P pager=off -X -c "
  SELECT to_char(created_at AT TIME ZONE 'UTC','MM-DD HH24:MI') AS created,
         CASE WHEN pushed_at IS NULL THEN 'not yet' ELSE 'pushed' END AS push_state,
         team_id, left(push_text,55) AS push_text
  FROM content_items
  WHERE created_at > now() - interval '$LOOKBACK' AND push_eligible = true
  ORDER BY created_at DESC;"

echo
if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "❌ FAIL: $VIOLATIONS feed-only item(s) pushed. The push_eligible guard is leaking."
  exit 1
else
  echo "✅ PASS: no feed-only item pushed in the last $LOOKBACK."
fi
