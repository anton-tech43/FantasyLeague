#!/usr/bin/env bash
# wc-freshness.sh — WC team-page freshness dashboard (Lesson 97).
#
# Reads get_wc_freshness() (migration 061) and prints, for all 48 WC
# country pages: page age, the dynamic-card ages (standings / next_fixture /
# form — these should track the ~2h data-fetcher cadence) and the static/LLM
# card ages (manager / ones_to_know / season — legitimately old). Flags any
# page that has missed a full waking refresh cycle (>STALE_HOURS, default 14).
#
# Usage:  ./scripts/wc-freshness.sh [STALE_HOURS]   (default 14)
# Reads SUPABASE_DB_URL from backend/.env.

set -euo pipefail
STALE_HOURS="${1:-14}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a && source "$HERE/backend/.env" && set +a
PSQL="/opt/homebrew/opt/libpq/bin/psql"

J=$("$PSQL" "$SUPABASE_DB_URL" -tA -X -c "SELECT get_wc_freshness($STALE_HOURS);")

echo "=========================================================="
echo " WC page freshness   ($(echo "$J" | jq -r '.snapshot_at'))"
echo "=========================================================="
echo "$J" | jq -r '"  Pages: \(.total)   Stale (>\(.stale_threshold_hours)h): \(.stale_count)   Oldest page: \(.oldest_page_hours)h"'

echo
echo "── STALE PAGES (missed a full waking cycle) ──────────────"
echo "$J" | jq -r '(.stale_teams // []) | if length==0 then "  (none — all pages fresh)" else .[] | "  \(.team_id)  (\(.group_label // "?"))  \(.page_age_hours)h old" end'

echo
echo "── PER-PAGE AGES (hours since each card was last written) ─"
printf "  %-18s %-9s %6s %6s %6s   %7s %7s %7s\n" "team" "group" "page" "stnd" "next" "mgr" "otk" "seas"
echo "$J" | jq -r '
  def pad(n): tostring | (" " * (n - length)) + .;
  (.pages // []) | sort_by(.group_label, .team_id) | .[] |
  "  " + (.team_id | .[0:18] | . + (" " * (18 - length)))
      + " " + ((.group_label // "?") | .[0:9] | . + (" " * (9 - length)))
      + " " + ((.page_age_hours // 0) | pad(6))
      + " " + ((.standings_hours // 0) | pad(6))
      + " " + ((.next_fixture_hours // 0) | pad(6))
      + "   " + ((.manager_hours // 0) | pad(7))
      + " " + ((.ones_to_know_hours // 0) | pad(7))
      + " " + ((.season_hours // 0) | pad(7))'
echo
echo "  (page/stnd/next = dynamic cards, ~2h SLA by day; mgr/otk/seas = static/LLM cards, days old is normal)"
echo
