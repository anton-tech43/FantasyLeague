-- 147_reaper_reads_the_feed.sql  (2026-11-01, app council 2026-10-29)
--
-- match-status-reaper (073, 145) turned every row still unfinished four hours
-- after kickoff into 'ABD', abandoned. On 24 Oct the scheduler was down
-- through three full times and the reaper filed Arsenal 2-0 Everton, Coventry
-- 0-1 Fulham and Chelsea 0-2 Spurs as abandoned matches. Two older rows were
-- the same (Arsenal v Burnley in May, Arsenal v Coventry in August, the
-- match-watcher outage). All five were played; the club's own fixture feed in
-- raw_fetch_logs said so the same evening.
--
-- The reaper now asks that feed first (api_football_fixtures_last of both
-- clubs, fetched after kickoff) and writes what it says. Only when the feed
-- has no end either does it write 'NOBS': we did not observe the end. That is
-- not a status API-Football sends, so nothing reads it as a result, and the
-- reaper looks at a NOBS row again every morning for 14 days, so a result that
-- reaches the feed later still lands.
--
-- Every reaped row is matchday_fire_capped: a game the reaper settles is too
-- old for a full-time push or a matchday article, and match-watcher's
-- justFinished would otherwise fire both if a later poll saw the row FT with
-- no fired_finished_at.
--
-- NOBS needs no other list: poll_leagues A stops at 4 h, B at 6 h, the
-- heartbeat stall check at 150 min, and la_sweep_due ends any Live Activity
-- three hours past kickoff whatever the status.

CREATE OR REPLACE FUNCTION public.reap_stuck_matches(at timestamptz DEFAULT now())
RETURNS integer
LANGUAGE sql
SET search_path = public, pg_temp
AS $$
  WITH stuck AS (
    SELECT s.fixture_id, s.status, s.kickoff_time, s.home_team_id, s.away_team_id
    FROM match_status_state s
    WHERE (s.status NOT IN ('FT','AET','PEN','ABD','PST','CANC','AWD','WO','TBD','NOBS')
           AND s.kickoff_time < at - interval '4 hours'
           -- 145: a level cup tie held as BT waits 14 h for the shootout.
           AND NOT (s.status = 'BT' AND s.kickoff_time > at - interval '14 hours'))
       OR (s.status = 'NOBS' AND s.kickoff_time > at - interval '14 days')
  ),
  feed AS (
    SELECT DISTINCT ON (k.fixture_id) k.fixture_id,
           f->'fixture'->'status'->>'short' AS st,
           (f->'goals'->>'home')::int AS hg,
           (f->'goals'->>'away')::int AS ag,
           (f->'fixture'->'status'->>'elapsed')::int AS el
    FROM stuck k
    JOIN raw_fetch_logs r
      ON r.team_id IN (k.home_team_id, k.away_team_id)
     AND r.source = 'api_football_fixtures_last'
     AND r.fetched_at > k.kickoff_time
     AND jsonb_typeof(r.data->'response') = 'array'
    CROSS JOIN LATERAL jsonb_array_elements(r.data->'response') f
    WHERE f->'fixture'->>'id' = k.fixture_id::text
    ORDER BY k.fixture_id, r.fetched_at DESC
  ),
  decided AS (
    SELECT k.fixture_id,
           CASE WHEN f.st IN ('FT','AET','PEN','ABD','PST','CANC','AWD','WO')
                     -- A held tie the feed still calls FT has not ended either.
                     AND NOT (k.status = 'BT' AND f.st = 'FT')
                THEN f.st ELSE 'NOBS' END AS status,
           f.hg, f.ag, f.el
    FROM stuck k LEFT JOIN feed f USING (fixture_id)
  ),
  done AS (
    UPDATE match_status_state s
    SET status = d.status,
        home_goals = CASE WHEN d.status = 'NOBS' THEN s.home_goals ELSE d.hg END,
        away_goals = CASE WHEN d.status = 'NOBS' THEN s.away_goals ELSE d.ag END,
        elapsed = CASE WHEN d.status = 'NOBS' THEN s.elapsed ELSE d.el END,
        la_ended = true,
        matchday_fire_capped = true,
        last_checked = at
    FROM decided d
    WHERE s.fixture_id = d.fixture_id
      AND NOT (s.status = 'NOBS' AND d.status = 'NOBS')
    RETURNING 1
  )
  SELECT count(*)::int FROM done;
$$;
REVOKE EXECUTE ON FUNCTION public.reap_stuck_matches(timestamptz) FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule('match-status-reaper');
SELECT cron.schedule('match-status-reaper', '0 5 * * *', $reaper$ SELECT public.reap_stuck_matches() $reaper$);

-- The five rows filed as abandoned. Every one is FT in the clubs' own feed
-- (checked 2026-11-01): the reaper's ABD is replaced by what was played.
UPDATE match_status_state s
SET status = 'FT', home_goals = v.hg, away_goals = v.ag, elapsed = 90,
    la_ended = true, matchday_fire_capped = true
FROM (VALUES (1379329, 1, 0),   -- Arsenal 1-0 Burnley, 2026-05-18
             (1557367, 3, 0),   -- Arsenal 3-0 Coventry, 2026-08-21
             (1557437, 2, 0),   -- Arsenal 2-0 Everton, 2026-10-24
             (1557440, 0, 1),   -- Coventry 0-1 Fulham, 2026-10-24
             (1557439, 0, 2))   -- Chelsea 0-2 Spurs, 2026-10-24
     AS v(fixture_id, hg, ag)
WHERE s.fixture_id = v.fixture_id AND s.status = 'ABD';

-- Verification:
--   SELECT fixture_id, status, home_goals, away_goals FROM match_status_state WHERE status IN ('ABD','NOBS');  -- 0 rows
--   SELECT has_function_privilege('anon', 'public.reap_stuck_matches(timestamptz)', 'EXECUTE');  -- false
--   SELECT command FROM cron.job WHERE jobname = 'match-status-reaper';
