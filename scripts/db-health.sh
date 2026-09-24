#!/usr/bin/env bash
# db-health.sh — is the backend actually serving the app right now, and if
# not, which layer is broken?
#
# Written after 2026-09-21, when the Supabase dashboard said "database
# unhealthy" for an hour while Postgres answered every single query we sent
# it. The database was fine. PostgREST — the HTTP layer the app talks to —
# was the thing that had fallen over, and no check we owned could tell the
# two apart. This one can, because it probes them separately.
#
# The existing check_pipeline_heartbeat() (every 30 min, migration 037+)
# covers content freshness, but it runs INSIDE the database via pg_cron and
# alerts through pg_net. When the database or its HTTP path is the casualty,
# it cannot run and cannot tell anyone. That is why this script runs from
# outside, from a laptop, over the same public internet the app uses.
#
# Usage:  ./scripts/db-health.sh
# Exit:   0 all clear · 1 something needs a human
#
# Reads backend/.env for SUPABASE_DB_URL and the app's own publishable key
# from ios/GoalDigger/Configuration.xcconfig, so section 1 tests exactly what
# a phone gets, not what a privileged key gets.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a && source "$HERE/backend/.env" && set +a
PSQL=/opt/homebrew/opt/libpq/bin/psql
export PGCONNECT_TIMEOUT=10

HOST=$(grep -E '^SUPABASE_HOST' "$HERE/ios/GoalDigger/Configuration.xcconfig" | awk -F'= *' '{print $2}' | tr -d ' \r')
KEY=$(grep -E '^SUPABASE_ANON_KEY' "$HERE/ios/GoalDigger/Configuration.xcconfig" | awk -F'= *' '{print $2}' | tr -d ' \r')
REST="https://${HOST}/rest/v1"

FAILED=0
note() { printf '  %-8s %s\n' "$1" "$2"; }
warn() { note "WARN" "$1"; }
fail() { FAILED=1; note "FAIL" "$1"; }

# One-shot scalar query. Prints nothing and returns empty on any failure, so
# a dead database degrades each section to "could not read" instead of a
# stack of shell errors.
q() { $PSQL "$SUPABASE_DB_URL" -X -t -A -F'|' -c "$1" 2>/dev/null | head -1; }

echo "=========================================================="
echo " GoalDigger backend health — $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "=========================================================="

# ----------------------------------------------------------------------
# 1. The layer the app talks to (PostgREST over HTTPS)
# ----------------------------------------------------------------------
# This is the only section that reflects what a user sees. Everything below
# can be perfectly healthy while this one is down — that is exactly what
# happened on 2026-09-21.
echo
echo "── 1. CAN THE APP READ ITS DATA? (PostgREST) ─────────────"
REST_OK=0; REST_N=0
probe_rest() {                       # $1 = path, $2 = human label
  REST_N=$((REST_N + 1))
  local out code secs bytes
  out=$(curl -s -o /tmp/gd_health_body -w '%{http_code} %{time_total}' --max-time 12 \
        -H "apikey: $KEY" -H "Authorization: Bearer $KEY" "$REST/$1" 2>/dev/null) || out="000 timeout"
  code=${out%% *}; secs=${out##* }
  bytes=$(wc -c < /tmp/gd_health_body 2>/dev/null | tr -d ' ')
  if [ "$code" = "200" ] && [ "${bytes:-0}" -gt 2 ]; then
    REST_OK=$((REST_OK + 1)); note "OK" "$(printf '%-26s %ss, %s bytes' "$2" "$secs" "$bytes")"
  elif [ "$code" = "200" ]; then
    fail "$(printf '%-26s 200 but EMPTY — no rows came back' "$2")"
  elif [ "$code" = "000" ]; then
    fail "$(printf '%-26s no response in 12s (hung, not refused)' "$2")"
  else
    fail "$(printf '%-26s HTTP %s' "$2" "$code")"
  fi
}
probe_rest "content_items?select=id&limit=5"                   "feed"
probe_rest "team_pages?team_id=eq.arsenal&select=team_id"      "team page"
probe_rest "players?team_id=eq.arsenal&select=name&limit=5"    "squad"
probe_rest "team_season_state?team_id=eq.arsenal&select=phase" "season state"

# ----------------------------------------------------------------------
# 2. The database itself, reached a different way
# ----------------------------------------------------------------------
# Deliberately a separate network path (Supavisor pooler, not the direct
# IPv6 endpoint). If section 1 fails and this passes, the data is safe and
# the fault is in Supabase's HTTP layer — nothing to fix on our side, and no
# reason to touch the database.
echo
echo "── 2. IS POSTGRES ITSELF UP? (pooler) ────────────────────"
PG_UP=0
for _ in 1 2 3; do
  [ "$(q "select 'up';")" = "up" ] && PG_UP=$((PG_UP + 1))
done
if   [ "$PG_UP" -eq 3 ]; then note "OK" "answered 3 of 3 probes"
elif [ "$PG_UP" -gt 0 ]; then fail "answered only $PG_UP of 3 probes — flapping"
else                          fail "no answer on 3 of 3 probes"; fi

# The verdict today's outage needed and nothing we owned could give.
echo
if   [ "$REST_OK" -eq "$REST_N" ] && [ "$PG_UP" -eq 3 ]; then
  note "VERDICT" "both layers healthy"
elif [ "$PG_UP" -eq 3 ] && [ "$REST_OK" -lt "$REST_N" ]; then
  note "VERDICT" "DATABASE IS FINE — the HTTP layer is down. Supabase's to fix."
  note ""        "Restarting the database will not help. See the skill."
elif [ "$PG_UP" -eq 0 ] && [ "$REST_OK" -eq 0 ]; then
  note "VERDICT" "whole project unreachable — check status.supabase.com"
else
  note "VERDICT" "mixed signals, read the lines above"
fi

if [ "$PG_UP" -eq 0 ]; then
  echo; echo "Postgres unreachable — skipping sections 3-6."; exit 1
fi

# ----------------------------------------------------------------------
# 3. The per-minute watcher
# ----------------------------------------------------------------------
# 18% of these minutes went missing in September and nobody noticed for
# days. A missed minute is a goal, a kickoff or a final whistle nobody was
# told about, so this is the check most likely to catch a real user-facing
# loss that no dashboard will ever show you.
echo
echo "── 3. IS THE PER-MINUTE WATCHER RUNNING? ─────────────────"
CRON=$(q "SELECT count(*), count(*) FILTER (WHERE status = 'succeeded')
          FROM cron.job_run_details d JOIN cron.job j USING (jobid)
          WHERE j.jobname = 'match-watcher-1min'
            AND d.start_time > now() - interval '24 hours';")
if [ -z "$CRON" ]; then
  warn "could not read cron history"
else
  TOTAL=${CRON%%|*}; OK=${CRON##*|}
  MISS=$((1440 - TOTAL))
  PCT=$(( TOTAL > 0 ? OK * 100 / TOTAL : 0 ))
  note "INFO" "recorded $TOTAL of 1440 minutes, ${PCT}% of those succeeded"
  if [ "$PCT" -lt 90 ] || [ "$MISS" -gt 200 ]; then
    fail "$MISS minutes never ran — expect missed goal and kickoff pushes"
  else
    note "OK" "within normal range"
  fi
fi

# ----------------------------------------------------------------------
# 4. Bloat
# ----------------------------------------------------------------------
# net._http_response is UNLOGGED, so autovacuum never visits it and it grows
# forever. At 17 MB it cost pg_net 5.2s per call and starved pg_cron of its
# only background worker. Migration 104 added the vacuum jobs; these lines
# are how you know they are still doing their job.
echo
echo "── 4. IS ANYTHING BLOATING? ──────────────────────────────"
for t in net._http_response cron.job_run_details public.pipeline_health; do
  MB=$(q "SELECT pg_total_relation_size('$t')/1024/1024;")
  if   [ -z "$MB" ];        then warn "$(printf '%-24s could not read size' "$t")"
  elif [ "$MB" -gt 20 ];    then warn "$(printf '%-24s %s MB — vacuum job may have stopped' "$t" "$MB")"
  else                           note "OK" "$(printf '%-24s %s MB' "$t" "$MB")"; fi
done

# ----------------------------------------------------------------------
# 5. Freshness
# ----------------------------------------------------------------------
# The app can be perfectly reachable and still be showing yesterday's world.
echo
echo "── 5. IS CONTENT STILL ARRIVING? ─────────────────────────"
HRS=$(q "SELECT round(extract(epoch FROM now() - max(created_at))/3600)::int FROM content_items;")
if   [ -z "$HRS" ];     then warn "could not read content_items"
elif [ "$HRS" -gt 24 ]; then fail "newest feed item is ${HRS}h old"
elif [ "$HRS" -gt 12 ]; then warn "newest feed item is ${HRS}h old"
else                         note "OK" "newest feed item is ${HRS}h old"; fi

# ----------------------------------------------------------------------
# 6. Connections
# ----------------------------------------------------------------------
# Always the first thing blamed and almost never the cause — but it costs
# one query to rule out, and ruling it out is what let us find the real
# fault both times this month.
echo
echo "── 6. CONNECTIONS ────────────────────────────────────────"
CONN=$(q "SELECT (SELECT count(*) FROM pg_stat_activity),
                 current_setting('max_connections')::int,
                 (SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock');")
if [ -z "$CONN" ]; then
  warn "could not read pg_stat_activity"
else
  USED=$(echo "$CONN" | cut -d'|' -f1)
  MAXC=$(echo "$CONN" | cut -d'|' -f2)
  LOCKED=$(echo "$CONN" | cut -d'|' -f3)
  if [ "$USED" -gt $((MAXC * 80 / 100)) ]; then fail "$USED of $MAXC used"
  else                                          note "OK" "$USED of $MAXC used"; fi
  if [ "$LOCKED" -gt 0 ]; then warn "$LOCKED queries waiting on a lock"
  else                         note "OK" "nothing waiting on a lock"; fi
fi

echo
echo "── 7. WHAT CAN THE SHIPPED KEY REACH? ────────────────────"
# A new function is BORN with EXECUTE granted to PUBLIC, and `anon` inherits
# through PUBLIC. ALTER DEFAULT PRIVILEGES cannot take that away — tested both
# documented forms on 2026-09-24, and a freshly created function still came out
# anon-executable. So this cannot be prevented at creation, only noticed: every
# CREATE FUNCTION needs its own REVOKE, and this is what catches the one that
# forgets. Migrations 084/095/096/103 went a year without anybody noticing.
ALLOWED='register_device_token|register_la_token|save_match_calls'
OPEN=$(q "SELECT string_agg(p.proname, ', ' ORDER BY p.proname)
            FROM pg_proc p
           WHERE p.pronamespace = 'public'::regnamespace
             AND p.prorettype <> 'trigger'::regtype
             AND has_function_privilege('anon', p.oid, 'EXECUTE')
             AND p.proname !~ '^($ALLOWED)\$';")
if [ -z "$OPEN" ]; then
  note "OK" "only the app's own RPCs are callable by anon"
else
  fail "anon can execute: $OPEN  (add REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated)"
fi

WRITABLE=$(q "SELECT string_agg(DISTINCT c.relname, ', ')
                FROM information_schema.role_table_grants g
                JOIN pg_class c ON c.relname = g.table_name
                 AND c.relnamespace = 'public'::regnamespace
               WHERE g.grantee IN ('anon','authenticated')
                 AND g.privilege_type <> 'SELECT';")
if [ -z "$WRITABLE" ]; then
  note "OK" "anon cannot write any table"
else
  fail "anon can write: $WRITABLE"
fi

echo
echo "=========================================================="
if [ "$FAILED" -eq 0 ]; then
  echo " All clear. Anything marked WARN is worth a glance, not a fix."
else
  echo " SOMETHING IS WRONG — see the FAIL lines above."
fi
echo "=========================================================="
exit $FAILED
