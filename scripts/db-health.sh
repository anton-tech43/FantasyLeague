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
# In the cloud (routines) backend/.env is absent and SUPABASE_DB_URL is injected
# as an env var; source the file only when it exists so the script also runs there.
[ -f "$HERE/backend/.env" ] && { set -a && source "$HERE/backend/.env" && set +a; }
# psql is at the Homebrew path on the dev's mac, on PATH in the cloud image.
PSQL=/opt/homebrew/opt/libpq/bin/psql
[ -x "$PSQL" ] || PSQL=psql
export PGCONNECT_TIMEOUT=10

XCCONFIG="$HERE/ios/GoalDigger/Configuration.xcconfig"
if [ -f "$XCCONFIG" ]; then
  HOST=$(grep -E '^SUPABASE_HOST' "$XCCONFIG" | awk -F'= *' '{print $2}' | tr -d ' \r')
  KEY=$(grep -E '^SUPABASE_ANON_KEY' "$XCCONFIG" | awk -F'= *' '{print $2}' | tr -d ' \r')
else
  # Cloud fallback: derive host from SUPABASE_URL, use whatever key the env has.
  # ponytail: SUPABASE_SERVICE_KEY is the privileged path, not the phone's
  # publishable key, so section 1 then tests reachability, not the exact anon
  # grant a phone gets. Add the publishable key to gd-env to restore parity.
  HOST="${SUPABASE_URL#http*://}"; HOST="${HOST%/}"
  KEY="${SUPABASE_ANON_KEY:-${SUPABASE_SERVICE_KEY:-}}"
fi
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
  echo; echo "Postgres unreachable — skipping sections 3-8."; exit 1
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
echo "── 8. IS THE CONTENT STILL TRUE? ─────────────────────────"
# Every other section here asks whether the machinery ran. None of them asks
# whether what it produced is right, and on 2026-09-30 that gap cost a month:
# the "ones to know" card named players who were not playing — 20 of 60 picks
# outside their own squad's top fifteen by minutes, Newcastle leading on a
# goalkeeper with zero minutes — while every job reported green throughout,
# because every job had done its job. `content-audit` is the one existing
# correctness check and its findings go to `pipeline_health`, which nothing
# reads; these live here instead because this is what a human actually sees,
# through MAINTENANCE.md row A1.
#
# WARN, not FAIL, until the measurement period ends: we do not yet know how
# often these trip, and an alarm calibrated before you know the frequency is
# how you train yourself to ignore it. Flip each `warn` to `fail` once the
# history table has a fortnight of evidence.
#
# Unlike section 7, an empty answer here is NOT proof of health — these
# queries return nothing both when all is well and when the database did not
# answer. So each one counts the population first and says "could not read"
# rather than quietly passing.

TOTAL_PICKS=$(q "SELECT count(*) FROM team_pages tp JOIN teams t ON t.id = tp.team_id,
                   jsonb_array_elements(tp.content->'cards'->'ones_to_know'->'players') p
                  WHERE t.entity_type = 'club' AND t.is_active;")
if [ -z "$TOTAL_PICKS" ] || [ "$TOTAL_PICKS" -eq 0 ] 2>/dev/null; then
  warn "could not read the ones-to-know cards"
else
  # 8a. Is the man on the card playing? This asserts the picker's OWN rule —
  # 90 minutes AND 40% of the squad leader's — rather than a rank cutoff of its
  # own. The first draft used "outside the top twelve by minutes" and promptly
  # flagged Brentford's Collins (287 min against a 216 threshold, two goals, the
  # squad's best rating) and Coventry's Torp (240 against 229, three goal
  # involvements). Both were correct picks; the check was simply stricter than
  # the rule it exists to police, which is how a check teaches you to ignore it.
  #
  # The constants are duplicated from _shared/featured-players.ts
  # (MIN_REGULAR_MINUTES, REGULAR_SHARE) and TEAM_PAGE_PROMPT.md. That is
  # deliberate — an independent restatement is what makes this a check and not
  # an echo — but the three move together or this starts lying.
  # Match through resolve_player_id (migration 117), never on the raw string.
  # The cards spell first names out and the squad feed abbreviates them, and
  # which form a card uses varies run to run: on 2026-10-01 a rewrite took the
  # exact-match rate from 60/60 to 11/60 without a single bad pick, and an
  # earlier draft of this check duly reported 49 false positives. The resolver
  # already handles the abbreviation, the accents and the shared surnames.
  UNKNOWN=$(q "WITH card AS (
                 SELECT tp.team_id, jsonb_array_elements(tp.content->'cards'->'ones_to_know'->'players')->>'name' AS n
                   FROM team_pages tp JOIN teams t ON t.id = tp.team_id
                  WHERE t.entity_type = 'club' AND t.is_active)
               SELECT string_agg(c.team_id || '/' || c.n, ', ' ORDER BY c.team_id)
                 FROM card c WHERE public.resolve_player_id(c.team_id, c.n) IS NULL;")
  if [ -z "$UNKNOWN" ]; then
    note "OK" "every featured name resolves to someone in the squad"
  else
    # Spelling a name out means supplying a forename the squad feed only gives
    # as an initial, and the model will invent one: on 2026-10-01 Ipswich's card
    # named "Omari Clarke" for a squad holding `J. Clarke`, and Hull's "Riyad
    # Belloumi" for `M. Belloumi`. A wrong first name on a real player is the
    # kind of thing she repeats and is corrected on.
    warn "featured name matches nobody in the squad: $UNKNOWN"
  fi

  BENCHED=$(q "WITH card AS (
                 SELECT tp.team_id, jsonb_array_elements(tp.content->'cards'->'ones_to_know'->'players')->>'name' AS n
                   FROM team_pages tp JOIN teams t ON t.id = tp.team_id
                  WHERE t.entity_type = 'club' AND t.is_active),
               bar AS (
                 SELECT team_id, GREATEST(90, MAX(minutes) * 0.4) AS floor_minutes
                   FROM players WHERE minutes IS NOT NULL GROUP BY team_id)
               SELECT string_agg(c.team_id || '/' || c.n ||
                        ' (' || coalesce(pl.minutes::text, 'no') || ' min, needs ' || round(b.floor_minutes) || ')',
                        ', ' ORDER BY c.team_id)
                 FROM card c
                 JOIN players pl ON pl.team_id = c.team_id
                                AND pl.api_player_id = public.resolve_player_id(c.team_id, c.n)
                 JOIN bar b ON b.team_id = c.team_id
                WHERE pl.minutes IS NULL OR pl.minutes < b.floor_minutes;")
  if [ -z "$BENCHED" ]; then
    note "OK" "all $TOTAL_PICKS featured players clear their squad's minutes bar"
  else
    warn "featured below the minutes bar: $BENCHED"
  fi

  # 8b. Does a card claim a rank we cannot see? We hold this club's squad and
  # the league table — never a league-wide player ranking — so "the most in the
  # Premier League", "the league's top scorer" and their kin are ungrounded by
  # construction, whatever the numbers happen to be. That is exactly how
  # Haaland's card came to read "Seven goals in five games, which is the most in
  # the Premier League": seven is his all-competitions tally, five is his league
  # tally, and no column here can settle the superlative either way.
  #
  # An earlier draft flagged any league word beside a player whose `goals` and
  # `league_goals` disagree. It was 7 false positives out of 8 the moment the
  # cards were rewritten, because the prompt fix had taught the model to
  # separate the figures itself — "Four goals this season, including two in the
  # Premier League" is right and was flagged anyway. That line is held by the
  # prompt, not by a linter; this check keeps only the part a linter can settle.
  #
  # The squad exclusion is the same lesson a second time. Ranking a player
  # against his own squad is both allowed and checkable, and the first regex
  # flagged "the most of anyone in the squad in the league" because the tail
  # matched. Against the league is the ungrounded claim; against the squad is
  # the one the prompt asks for.
  UNGROUNDED=$(q "WITH card AS (
                    SELECT tp.team_id,
                           jsonb_array_elements(tp.content->'cards'->'ones_to_know'->'players') AS p
                      FROM team_pages tp JOIN teams t ON t.id = tp.team_id
                     WHERE t.entity_type = 'club' AND t.is_active)
                  SELECT string_agg(c.team_id || '/' || (c.p->>'name'), ', ' ORDER BY c.team_id)
                    FROM card c
                   WHERE (c.p->>'one_liner' ~* '(most|top|best|highest|leading|first|only)[^.]{0,40}(in|of) the (premier )?league([^a-z]|$)'
                      OR c.p->>'one_liner' ~* 'league.{0,20}(top scorer|leading scorer|golden boot)')
                     AND c.p->>'one_liner' !~* '(in|of|at|within) the (squad|club|side|team)';")
  if [ -z "$UNGROUNDED" ]; then
    note "OK" "no card claims a league-wide ranking we do not hold"
  else
    warn "claims a league-wide rank we cannot verify: $UNGROUNDED"
  fi
fi

# 8c. Has the prose been written at all lately? The routine runs Mondays, so
# eight days means a Monday was missed — which happened twice in September and
# went unnoticed for sixteen days.
STALE=$(q "SELECT string_agg(tp.team_id, ', ' ORDER BY tp.team_id)
             FROM team_pages tp JOIN teams t ON t.id = tp.team_id
            WHERE t.entity_type = 'club' AND t.is_active
              AND (tp.content->>'last_routine_run' IS NULL
                   OR (tp.content->>'last_routine_run')::timestamptz < NOW() - INTERVAL '8 days');")
if [ -z "$STALE" ]; then
  note "OK" "every club's prose was rewritten within the last eight days"
else
  warn "prose older than eight days: $STALE"
fi

# 8d. Does a club's fun fact contradict its own promotion year? `basics` is
# hand-seeded (migration 004) and nothing ever rewrites it, while `pl_since`
# right beside it IS maintained. So they drift apart every time a club goes
# down and comes back, and the card then tells a newcomer two different stories
# at once: Leeds' fun fact had them "clawing their way back in 2020" over a
# `pl_since` of 2025, both true — promoted 2020, relegated 2023, promoted 2025 —
# and impossible to reconcile if you are new to this. Expect this to fire every
# May, which is exactly why it is worth having.
#
# Word boundaries matter here: the first version used a bare `up` as one of the
# trigger words and matched inside "European C-up-", reporting Villa's 1982
# European Cup and Forest's 1979 as promotion years.
MIXED=$(q "SELECT string_agg(tp.team_id || ' (fact says ' || f.yr || ', pl_since says ' || s.yr || ')', ', ' ORDER BY tp.team_id)
             FROM team_pages tp JOIN teams t ON t.id = tp.team_id
             CROSS JOIN LATERAL (SELECT substring(tp.content->'cards'->'basics'->>'fun_fact'
                                   from '\\m(?:back|returned?|promoted|climbed)\\M[^.]{0,40}?([12][09][0-9][0-9])') AS yr) f
             CROSS JOIN LATERAL (SELECT substring(tp.content->'cards'->'basics'->>'pl_since'
                                   from '([12][09][0-9][0-9])') AS yr) s
            WHERE t.entity_type = 'club' AND t.is_active
              AND f.yr IS NOT NULL AND s.yr IS NOT NULL AND f.yr <> s.yr;")
if [ -z "$MIXED" ]; then
  note "OK" "no club's fun fact argues with its own pl_since"
else
  warn "fun fact and pl_since give different years: $MIXED"
fi

# 8e. Do cards 5 and 6 say the same thing twice? "How they're doing"
# (form_summary) sits directly above "The season so far" (season.summary) in
# TeamPageView, and both are written in the same run from the same numbers, so
# they restate each other unless somebody is watching: Hull's read "Two wins
# and two draws in five, sitting eighth" and then "sitting eighth with eight
# points after five games... Two wins, two draws, one loss". 75% of the first
# card's vocabulary repeated immediately underneath it.
#
# Words of four letters or more only, so "the" and "with" do not carry the
# score. 60% is calibrated on the 2026-10-02 sample, where the spread ran from
# 10% (Coventry, fine) to 75% (Hull, not fine).
ECHOED=$(q "WITH p AS (
              SELECT tp.team_id,
                regexp_split_to_array(lower(regexp_replace(tp.content->'cards'->'form'->>'form_summary','[^a-zA-Z ]','','g')),'\s+') AS a,
                regexp_split_to_array(lower(regexp_replace(tp.content->'cards'->'season'->>'summary','[^a-zA-Z ]','','g')),'\s+') AS b
                FROM team_pages tp JOIN teams t ON t.id = tp.team_id
               WHERE t.entity_type = 'club' AND t.is_active
                 AND tp.content->'cards'->'form'->>'form_summary' IS NOT NULL
                 AND tp.content->'cards'->'season'->>'summary' IS NOT NULL)
            SELECT string_agg(team_id || ' (' || pct || '%)', ', ' ORDER BY pct DESC)
              FROM (SELECT team_id, round(100.0 *
                      (SELECT count(DISTINCT x) FROM unnest(a) x WHERE x = ANY(b) AND length(x) > 3) /
                      NULLIF((SELECT count(DISTINCT x) FROM unnest(a) x WHERE length(x) > 3), 0)) AS pct
                      FROM p) q
             WHERE pct >= 60;")
if [ -z "$ECHOED" ]; then
  note "OK" "no club repeats its form card in its season card"
else
  warn "cards 5 and 6 say the same thing: $ECHOED"
fi

# 8f. Does a rivalry card say a rival is absent who is in fact here? `rivalry`
# is hand-seeded alongside `basics` and preserved by every writer, so it carries
# whatever was true the day it was written. Promotion makes it false silently:
# Newcastle's card said "Sunderland are not in the Premier League right now"
# while Sunderland's own card, two rows away, said "Both are in the Premier
# League this season, so [his name] gets the fixture back". The derby was back
# and half our data had not noticed.
#
# Precise because it only fires when the named rival is an ACTIVE club.
# Forest's card says Derby and Leicester are absent and both genuinely are, so
# it stays quiet.
GONE=$(q "SELECT string_agg(DISTINCT tp.team_id || ' says ' || r.display_name || ' is away', ', ')
            FROM team_pages tp
            JOIN teams t ON t.id = tp.team_id
            JOIN teams r ON r.entity_type = 'club' AND r.is_active AND r.id <> tp.team_id
             AND tp.content->'cards'->'rivalry'->>'text' LIKE '%' || r.display_name || '%'
           WHERE t.entity_type = 'club' AND t.is_active
             AND tp.content->'cards'->'rivalry'->>'text'
                 ~* '(not in the premier league|neither is in|outside the premier league|not in the top flight)';")
if [ -z "$GONE" ]; then
  note "OK" "no rivalry card writes off a club that is actually in the league"
else
  warn "rivalry card contradicts the team list: $GONE"
fi

# 8g. Is any club's manager still coming from the feed we do not trust?
# `/coachs` omits sitting managers and lists assistants as if they were head
# coaches — DATA_SOURCES.md has the evidence, and it is how the app once showed
# Bournemouth's assistant as its manager. The fix was `teams.manager_name`
# (migration 085), human-verified, and team-page-generator prefers it: when it
# is set, that row's name AND photo decide, including deciding there is no
# photo. All 20 clubs are covered today, so the feed branch is dead code — but
# it is one newly promoted club away from being live again, and the symptom
# would be a real person's face attached to the wrong job.
UNVERIFIED=$(q "SELECT string_agg(id, ', ' ORDER BY id) FROM teams
                 WHERE entity_type = 'club' AND is_active AND manager_name IS NULL;")
if [ -z "$UNVERIFIED" ]; then
  note "OK" "every club's manager is the human-verified one, not the feed's"
else
  fail "no verified manager, so the unreliable /coachs feed decides: $UNVERIFIED  (set teams.manager_name)"
fi

# 8h. The canary on the history table itself. Scoped to the prose it should sit
# in the hundreds of kilobytes; if the trigger ever starts following the
# two-hourly numeric churn instead it becomes ~8 MB a day, which is how
# raw_fetch_logs drained the Disk IO budget in June. This one FAILs, because it
# is a defect in our own machinery rather than a judgement about content.
HIST=$(q "SELECT pg_total_relation_size('public.team_page_prose_history');")
if [ -z "$HIST" ]; then
  warn "could not read the prose history size"
elif [ "$HIST" -gt 5242880 ]; then
  fail "team_page_prose_history is $((HIST / 1048576)) MB — the trigger is following numeric churn, check its scope"
else
  note "OK" "prose history is $((HIST / 1024)) kB"
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
