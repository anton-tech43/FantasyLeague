#!/usr/bin/env bash
# tracking-digest.sh — the weekly usage digest (docs/TRACKING_PLAN.md, "What we
# look at"). The digest is the product, not a dashboard: a number nobody is
# sent is a number nobody reads.
#
# Reads public.analytics_events (migration 143), which already keeps production
# only, drops the blackout windows and splits Arsenal from everyone else. Every
# line names its denominator. With this few users every percentage is an
# anecdote with a denominator — read paths, not rates.
#
#   ./scripts/tracking-digest.sh        # last 7 days
#   ./scripts/tracking-digest.sh 28     # last 28
#
# Read-only. Runs locally (backend/.env) or in a routine (SUPABASE_DB_URL).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$HERE/backend/.env" ] && { set -a && source "$HERE/backend/.env" && set +a; }
PSQL=/opt/homebrew/opt/libpq/bin/psql
[ -x "$PSQL" ] || PSQL=psql
DAYS="${1:-7}"
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "days must be a number" >&2; exit 1; }

q() { echo; echo "── $1"; $PSQL "$SUPABASE_DB_URL" -X -q -P footer=off -v ON_ERROR_STOP=1 -c "$2"; }
W="occurred_at > now() - interval '$DAYS days'"

echo "USAGE DIGEST — last $DAYS days, production builds, blackout windows excluded"

q "WHO (denominator for everything below: active = any event in the window)" "
SELECT club_group,
       count(DISTINCT install_id) AS active,
       count(DISTINCT install_id) FILTER (WHERE name = 'onboarding_completed') AS new_onboarded,
       count(*) AS events
  FROM analytics_events WHERE $W GROUP BY 1 ORDER BY 1"

q "ONBOARDING FUNNEL (installs that saw each step)" "
SELECT props->>'step' AS step, count(DISTINCT install_id) AS installs
  FROM analytics_events WHERE $W AND name = 'onboarding_step_viewed'
 GROUP BY 1 ORDER BY min(occurred_at)"

q "WHERE SHE GOES (of active installs, how many opened each tab)" "
SELECT club_group, props->>'tab' AS tab, count(DISTINCT install_id) AS installs
  FROM analytics_events WHERE $W AND name = 'tab_viewed' GROUP BY 1, 2 ORDER BY 1, 3 DESC"

q "READY FOR A MATCH (fixtures she did a pre-game card for; denominator: installs that opened Before)" "
SELECT club_group,
       count(DISTINCT install_id) FILTER (WHERE name = 'pregame_opened') AS opened_before,
       count(DISTINCT install_id) FILTER (WHERE name = 'pregame_card_completed' AND props->>'phase' = 'before') AS completed_a_card,
       count(DISTINCT (install_id, props->>'fixture_key')) FILTER (WHERE name = 'pregame_card_completed' AND props->>'phase' = 'before') AS ready_fixture_pairs,
       count(*) FILTER (WHERE name = 'pregame_opened' AND props->>'entry' = 'tab') AS before_opens_from_tab,
       count(*) FILTER (WHERE name = 'pregame_opened' AND props->>'entry' = 'link') AS before_opens_from_link
  FROM analytics_events WHERE $W GROUP BY 1 ORDER BY 1"

q "PUSH OPENS vs SENDS (sends from pipeline_health apns_send, all builds; opens production only)" "
WITH sent AS (
  SELECT CASE split_part(target, ':', 1) WHEN 'item' THEN 'article'
              ELSE regexp_replace(split_part(target, ':', 1), '^live_', '') END AS kind,
         sum(substring(message FROM '(\d+) sent')::int) AS sent
    FROM pipeline_health
   WHERE stage = 'apns_send' AND created_at > now() - interval '$DAYS days'
   GROUP BY 1),
opened AS (
  SELECT props->>'kind' AS kind, count(*) AS opened
    FROM analytics_events WHERE $W AND name = 'push_opened' GROUP BY 1)
SELECT coalesce(s.kind, o.kind) AS kind, coalesce(s.sent, 0) AS sent, coalesce(o.opened, 0) AS opened
  FROM sent s FULL JOIN opened o ON o.kind = s.kind ORDER BY 2 DESC"

q "WHAT SHE CHANGES (net tier movement < 0 means we push more than she wants)" "
SELECT club_group,
       count(*) FILTER (WHERE name = 'tier_changed' AND (props->>'to')::int < (props->>'from')::int) AS tier_down,
       count(*) FILTER (WHERE name = 'tier_changed' AND (props->>'to')::int > (props->>'from')::int) AS tier_up,
       count(*) FILTER (WHERE name = 'follow_changed' AND props->>'action' = 'added') AS clubs_added,
       count(*) FILTER (WHERE name = 'follow_changed' AND props->>'action' = 'removed') AS clubs_removed,
       count(*) FILTER (WHERE name = 'notification_permission_changed' AND props->>'to' = 'denied') AS notifs_turned_off,
       count(*) FILTER (WHERE name = 'notification_permission_changed' AND props->>'to' = 'granted') AS notifs_turned_on
  FROM analytics_events WHERE $W GROUP BY 1 ORDER BY 1"

q "WEEKLY STATUS (installs seen in the last 8 weeks; active = opened the app, passive = no open but a push was delivered, quiet = neither)" "
WITH weeks AS (
  SELECT generate_series(date_trunc('week', now()) - interval '7 weeks', date_trunc('week', now()), interval '1 week') AS wk),
installs AS (
  SELECT install_id, club_group, date_trunc('week', min(occurred_at)) AS first_wk
    FROM analytics_events WHERE install_id IS NOT NULL GROUP BY 1, 2),
per_week AS (
  SELECT install_id, date_trunc('week', occurred_at) AS wk,
         bool_or(name = 'app_opened') AS opened, bool_or(name = 'push_delivered') AS delivered
    FROM analytics_events WHERE occurred_at > now() - interval '8 weeks' GROUP BY 1, 2)
SELECT to_char(w.wk, 'YYYY-MM-DD') AS week, i.club_group,
       count(*) FILTER (WHERE p.opened) AS active,
       count(*) FILTER (WHERE NOT coalesce(p.opened, false) AND p.delivered) AS passive,
       count(*) FILTER (WHERE NOT coalesce(p.opened, false) AND NOT coalesce(p.delivered, false)) AS quiet
  FROM weeks w JOIN installs i ON i.first_wk <= w.wk
  LEFT JOIN per_week p ON p.install_id = i.install_id AND p.wk = w.wk
 GROUP BY 1, 2 ORDER BY 1, 2"

q "RETAINED BY INSTALL WEEK (installs active or passive in week 1, 2 and 4 after their first event; denominator = installs; recent weeks have not reached wk4 yet)" "
WITH installs AS (
  SELECT install_id, club_group, date_trunc('week', min(occurred_at)) AS first_wk
    FROM analytics_events WHERE install_id IS NOT NULL GROUP BY 1, 2),
seen AS (
  SELECT DISTINCT install_id, date_trunc('week', occurred_at) AS wk
    FROM analytics_events WHERE name IN ('app_opened', 'push_delivered'))
SELECT to_char(i.first_wk, 'YYYY-MM-DD') AS install_week, i.club_group, count(*) AS installs,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM seen s WHERE s.install_id = i.install_id AND s.wk = i.first_wk + interval '1 week')) AS wk1,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM seen s WHERE s.install_id = i.install_id AND s.wk = i.first_wk + interval '2 weeks')) AS wk2,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM seen s WHERE s.install_id = i.install_id AND s.wk = i.first_wk + interval '4 weeks')) AS wk4
  FROM installs i WHERE i.first_wk > now() - interval '12 weeks'
 GROUP BY 1, 2 ORDER BY 1, 2"

q "PUSH DELIVERED vs OPENED (production; delivered = shown on the phone)" "
SELECT props->>'kind' AS kind,
       count(*) FILTER (WHERE name = 'push_delivered') AS delivered,
       count(*) FILTER (WHERE name = 'push_opened') AS opened
  FROM analytics_events WHERE $W AND name IN ('push_delivered', 'push_opened')
 GROUP BY 1 ORDER BY 2 DESC"

q "EXITS (Delete My Data; anonymous by design)" "
SELECT count(*) AS deleted, round(avg((props->>'days_since_install')::int), 1) AS avg_days_in
  FROM analytics_events WHERE $W AND name = 'data_deleted'"
