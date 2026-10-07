#!/usr/bin/env bash
# arch-facts.sh — the facts in docs/system-map/, read out of the system instead
# of typed from memory.
#
# The map was hand-written, and hand-written facts rot the way eighteen root
# documents in this repo already have. Worse, one of them was wrong on the day
# it shipped: the map said client-error-alert had no caller, and a mechanical
# sweep found notification-sender calling it on an APNs auth failure. So the
# verifiable half of the map is generated here and the prose stays by hand.
#
#   ./scripts/arch-facts.sh            write docs/system-map/facts.json
#   ./scripts/arch-facts.sh --print    stdout only, change nothing
#
# Needs psql for the live half. Without it you still get the filesystem half
# and `db: false` — gd-env's egress blocks port 5432 (MAINTENANCE.md §1), so
# this is a laptop job and the committed JSON is what the cloud reads.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTINES="${GOALDIGGER_ROUTINES:-/Users/anton/goaldigger-routines}"
FN="$HERE/backend/supabase/functions"
OUT="$HERE/docs/system-map/facts.json"
[ -f "$HERE/backend/.env" ] && { set -a && source "$HERE/backend/.env" && set +a; }
PSQL=/opt/homebrew/opt/libpq/bin/psql; [ -x "$PSQL" ] || PSQL=psql
export PGCONNECT_TIMEOUT=10

q() { "$PSQL" "$SUPABASE_DB_URL" -X -t -A -F$'\x1f' -c "$1" 2>/dev/null; }

DB=true
if [ -z "${SUPABASE_DB_URL:-}" ] || ! q "select 1" >/dev/null 2>&1; then
  DB=false
  echo "note: no database — writing the filesystem half only, db:false" >&2
fi

# ---------------------------------------------------------------- edge functions
# "Who calls this?" has three spellings and a naive grep finds one of them.
# Missing a caller marks a live function dormant, which is the expensive
# direction of this error, so all three are matched:
#   functions/v1/<name>          cron commands, the routines, some Edge calls
#   triggerFunction("<name>"     Edge -> Edge
#   appendingPathComponent("<n>" the iOS client
CRONCMD=$([ "$DB" = true ] && q "select coalesce(string_agg(command,' '),'') from cron.job" || echo "")
edge_json="[]"
for d in "$FN"/*/; do
  n=$(basename "$d"); [ "$n" = "_shared" ] && continue; [ -f "$d/index.ts" ] || continue
  callers=()
  grep -qs "functions/v1/$n" <<< "$CRONCMD" && callers+=("cron")
  grep -rqs -e "functions/v1/$n" -e "triggerFunction(\"$n\"" "$FN" --include=index.ts --exclude-dir="$n" && callers+=("edge")
  grep -qs "appendingPathComponent(\"$n\")" "$HERE/ios/GoalDigger/Services/APIClient.swift" && callers+=("ios")
  [ -d "$ROUTINES" ] && grep -rqs "functions/v1/$n" "$ROUTINES" && callers+=("routine")
  bills=$(grep -qs "claude-client" "$d/index.ts" && echo true || echo false)
  pushes=$(grep -qs "apns-client" "$d/index.ts" && echo true || echo false)
  edge_json=$(jq -c --arg n "$n" --argjson c "$(printf '%s\n' "${callers[@]:-}" | jq -Rc 'select(length>0)' | jq -sc .)" \
                   --argjson b "$bills" --argjson p "$pushes" --arg l "$(wc -l < "$d/index.ts" | tr -d ' ')" \
                   '. + [{name:$n, callers:$c, billsPaidApi:$b, canPush:$p, lines:($l|tonumber)}]' <<< "$edge_json")
done

# ---------------------------------------------------------------- cron
cron_json="[]"
if [ "$DB" = true ]; then
  while IFS=$'\x1f' read -r name sched active cmd; do
    [ -z "$name" ] && continue
    cron_json=$(jq -c --arg n "$name" --arg s "$sched" --argjson a "$([ "$active" = t ] && echo true || echo false)" \
                      --arg t "$cmd" '. + [{job:$n, schedule:$s, active:$a, calls:$t}]' <<< "$cron_json")
  done < <(q "select jobname, schedule, active,
                     coalesce(substring(command from 'functions/v1/([a-z-]+)'),
                              substring(command from 'SELECT ([a-z_.]+)[(]'), '(sql)')
                from cron.job order by jobname")
fi

# ---------------------------------------------------------------- routines
# Routine schedules live only in the claude.ai dashboard — the one column of
# this map that cannot be read from code. But they can be OBSERVED: every
# active routine leaves a dated trace. Where the README and the trace disagree,
# the trace is the one that ran. Two are invisible on purpose: gd-heartbeat
# writes nothing unless something is wrong, and gd-maintenance commits to git.
rt_json="[]"
if [ "$DB" = true ]; then
  add_rt() {  # name, signal, hours, last
    rt_json=$(jq -c --arg n "$1" --arg s "$2" --arg h "$3" --arg l "$4" \
      '. + [{routine:$n, observedVia:$s, hoursUtc:($h|split(",")|map(select(length>0))), lastProduced:$l}]' <<< "$rt_json")
  }
  while IFS=$'\x1f' read -r script hours last; do
    [ -z "$script" ] && continue
    add_rt "$script" "pipeline_health" "$hours" "$last"
  done < <(q "select split_part(target,':',1),
                     string_agg(distinct to_char(created_at,'HH24'), ',' order by to_char(created_at,'HH24')),
                     max(created_at)::date
                from pipeline_health
               where stage='routine_post' and created_at > now() - interval '21 days'
               group by 1 order by 1")
  while IFS=$'\x1f' read -r t hours last; do
    [ -z "$t" ] && continue; add_rt "content_items:$t" "content_items" "$hours" "$last"
  done < <(q "select type, string_agg(distinct to_char(published_at,'HH24'), ',' order by to_char(published_at,'HH24')),
                     max(published_at)::date
                from content_items where published_at > now() - interval '21 days' group by 1 order by 1")
  add_rt "gd-team-page" "team_page_prose_history" \
         "$(q "select coalesce(string_agg(distinct to_char(recorded_at,'HH24'),','),'') from team_page_prose_history where recorded_at > now() - interval '21 days'")" \
         "$(q "select coalesce(max(recorded_at)::date::text,'never') from team_page_prose_history")"
  add_rt "gd-content-review" "content_reviews" \
         "$(q "select coalesce(string_agg(distinct to_char(generated_at,'HH24'),','),'') from content_reviews where generated_at > now() - interval '28 days'")" \
         "$(q "select coalesce(max(generated_at)::date::text,'never') from content_reviews")"
fi

# ---------------------------------------------------------------- tables
tbl_json="[]"
if [ "$DB" = true ]; then
  while IFS=$'\x1f' read -r t rows newest; do
    [ -z "$t" ] && continue
    tbl_json=$(jq -c --arg t "$t" --arg r "$rows" --arg n "$newest" \
      '. + [{table:$t, rows:($r|tonumber), newest:$n}]' <<< "$tbl_json")
  done < <(q "
    select 'content_items', count(*)::text, coalesce(max(published_at)::date::text,'never') from content_items
    union all select 'team_pages', count(*)::text, coalesce(max(updated_at)::date::text,'never') from team_pages
    union all select 'player_cards', count(*)::text, coalesce(max(updated_at)::date::text,'never') from player_cards
    union all select 'team_insider_items', count(*)::text, coalesce(max(published_at)::date::text,'never') from team_insider_items
    union all select 'saturday_quiz_items', count(*)::text, coalesce(max(published_at)::date::text,'never') from saturday_quiz_items
    union all select 'live_match_briefs', count(*)::text, coalesce(max(generated_at)::date::text,'never') from live_match_briefs
    union all select 'team_season_state', count(*)::text, coalesce(max(generated_at)::date::text,'never') from team_season_state
    union all select 'players', count(*)::text, coalesce(max(updated_at)::date::text,'never') from players
    union all select 'teams', count(*) filter (where is_active and league_id=39)::text, 'n/a' from teams
    union all select 'raw_fetch_logs', count(*)::text, coalesce(max(fetched_at)::date::text,'never') from raw_fetch_logs
    union all select 'match_status_state', count(*)::text, coalesce(max(kickoff_time)::date::text,'never') from match_status_state
    union all select 'device_tokens', count(*)::text, coalesce(max(created_at)::date::text,'never') from device_tokens
    union all select 'pipeline_health', count(*)::text, coalesce(max(created_at)::date::text,'never') from pipeline_health
    union all select 'content_reviews', count(*)::text, coalesce(max(week_of)::text,'never') from content_reviews
    union all select 'my_turn_content', count(*)::text, coalesce(max(updated_at)::date::text,'never') from my_turn_content
    order by 1")
fi

# ---------------------------------------------------------------- counts
counts=$(jq -nc \
  --arg edge   "$(jq 'length' <<< "$edge_json")" \
  --arg cron   "$(jq 'length' <<< "$cron_json")" \
  --arg mig    "$(ls "$HERE"/backend/supabase/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')" \
  --arg swift  "$(find "$HERE/ios/GoalDigger" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')" \
  --arg shared "$(ls "$FN"/_shared/*.ts 2>/dev/null | grep -vc '\.test\.ts$' | tr -d ' ')" \
  --arg prompts "$([ -d "$ROUTINES" ] && ls "$ROUTINES"/*PROMPT*.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)" \
  --arg docs   "$(ls "$HERE"/*.md 2>/dev/null | wc -l | tr -d ' ')" \
  '{edgeFunctions:($edge|tonumber), cronJobs:($cron|tonumber), migrations:($mig|tonumber),
    swiftFiles:($swift|tonumber), sharedModules:($shared|tonumber),
    routinePrompts:($prompts|tonumber), rootDocs:($docs|tonumber)}')

FACTS=$(jq -n --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson db "$DB" \
  --argjson counts "$counts" --argjson edge "$edge_json" --argjson cron "$cron_json" \
  --argjson routines "$rt_json" --argjson tables "$tbl_json" \
  '{generatedAt:$at, db:$db, counts:$counts, edge:$edge, cron:$cron, routines:$routines, tables:$tables}')

if [ "${1:-}" = "--print" ]; then printf '%s\n' "$FACTS" | jq .; exit 0; fi
mkdir -p "$(dirname "$OUT")"
printf '%s\n' "$FACTS" | jq . > "$OUT"
echo "wrote $OUT"
jq -r '"  \(.counts.edgeFunctions) edge · \(.counts.cronJobs) cron · \(.routines|length) observed routines · \(.tables|length) tables · db=\(.db)"' "$OUT"
