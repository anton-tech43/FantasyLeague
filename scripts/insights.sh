#!/usr/bin/env bash
# insights.sh — on-demand launch dashboard (Lesson 87, Phase A).
#
# Reads the get_insights() RPC (migration 058) and prints a readable
# summary: audience, growth, churn, push delivery, content production,
# and empty WC feeds. Pure server-side aggregates — no PII, no per-user
# data. Honours the "we don't track you" promise.
#
# Usage:  ./scripts/insights.sh [DAYS]   (default 14)
#
# Reads SUPABASE_DB_URL from backend/.env.

set -euo pipefail
DAYS="${1:-14}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a && source "$HERE/backend/.env" && set +a
PSQL="/opt/homebrew/opt/libpq/bin/psql"

J=$("$PSQL" "$SUPABASE_DB_URL" -tA -X -c "SELECT get_insights($DAYS);")

echo "=========================================================="
echo " GoalDigger insights — last $DAYS days   ($(echo "$J" | jq -r '.snapshot_at'))"
echo "=========================================================="

echo
echo "── AUDIENCE (App Store users) ────────────────────────────"
echo "$J" | jq -r '.audience |
  "  Active:        \(.active)",
  "  Inactive:      \(.inactive)   (churned / dead tokens)",
  "  Following:     country \(.following_country) | club \(.following_team)",
  "  Tier mix:      T1 \(.tier1) · T2 \(.tier2) · T3 \(.tier3)"'

echo
echo "── TOP COUNTRIES (active followers) ──────────────────────"
echo "$J" | jq -r '(.top_countries // []) | if length==0 then "  (none yet)" else .[] | "  \(.active_followers | tostring | (" " * (5 - length)) + .)  \(.entity_id)" end'

echo
echo "── TOP TEAMS (active followers) ──────────────────────────"
echo "$J" | jq -r '(.top_teams // []) | if length==0 then "  (none yet)" else .[] | "  \(.active_followers | tostring | (" " * (5 - length)) + .)  \(.entity_id)" end'

echo
echo "── GROWTH (new registrations / day) ──────────────────────"
echo "$J" | jq -r '(.registrations // []) | if length==0 then "  (none)" else .[] | "  \(.day)   +\(.new_registrations)" end'

echo
echo "── CHURN (deactivated / day — lazy, on next push) ────────"
echo "$J" | jq -r '(.churn // []) | if length==0 then "  (none)" else .[] | "  \(.day)   -\(.deactivated)" end'

echo
echo "── PUSH DELIVERY / day ───────────────────────────────────"
echo "$J" | jq -r '(.push_delivery // []) | if length==0 then "  (none)" else .[] |
  "  \(.day)   sent \(.delivered)/\(.attempts)  (\(.success_pct // 0)%)   expired:\(.token_expired) bad:\(.bad_token)" end'

echo
echo "── CONTENT / day ─────────────────────────────────────────"
echo "$J" | jq -r '(.content // []) | if length==0 then "  (none)" else .[] |
  "  \(.day)   items \(.items)  pushed \(.pushed)  feed-only \(.feed_only)  consequences \(.consequence_events)" end'

echo
EMPTY=$(echo "$J" | jq -r '(.empty_feeds // []) | length')
echo "── WC FEED COVERAGE ──────────────────────────────────────"
echo "  Entities with ZERO content_items: $EMPTY"
if [[ "$EMPTY" -gt 0 ]]; then
  echo "$J" | jq -r '(.empty_feeds // []) | map(.entity_id) | join(", ") | "  " + .'
fi
echo
