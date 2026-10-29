-- 145_held_ties_settle_late.sql  (2026-10-29)
--
-- A level single-leg cup tie the feed calls "Match Finished" is held by
-- match-watcher as 'BT' until the feed says PEN or AET (3880ce0). Two things
-- still ended that wait too early:
--
-- 1. poll_leagues() stopped looking six hours after kickoff (branch B). New
--    branch D keeps a held row polled every tenth minute up to fourteen hours.
-- 2. match-status-reaper turned any unfinished row four hours past kickoff
--    into 'ABD' at 05:00 UTC, which would end branch D's wait at 05:00. Held
--    rows younger than fourteen hours are left alone; the next morning's run
--    still reaps them.
--
-- Anton, 2026-10-29: "rather the right result the same evening than none at
-- all". Whether a late result still pushes is decided in code
-- (push-tiers.ts resultStillNews), not here.

CREATE OR REPLACE FUNCTION public.poll_leagues(at timestamptz DEFAULT now())
RETURNS TABLE (league_id integer, poll_date date)
LANGUAGE sql
STABLE
AS $$
  WITH covered AS (
    SELECT DISTINCT t.league_id FROM teams t
    WHERE t.is_active AND t.league_id IS NOT NULL AND t.entity_type <> 'tournament'
    UNION
    SELECT unnest(ARRAY[2, 3, 848, 48, 45])
  ),
  latest AS (
    -- Newest fixture feed per active CLUB or COUNTRY. A tournament row's feed
    -- is every club's fixtures in that competition, so it is excluded by
    -- entity_type, not by whether it happens to have a league_id.
    SELECT DISTINCT ON (r.team_id) r.team_id, r.data, r.fetched_at
    FROM raw_fetch_logs r
    JOIN teams t ON t.id = r.team_id
      AND t.is_active
      AND t.league_id IS NOT NULL
      AND t.entity_type <> 'tournament'
    WHERE r.source = 'api_football_fixtures_next'
      AND r.fetched_at > at - INTERVAL '3 days'
      -- A rate-limited 200 is stored too, with response []. Taking it as the
      -- newest feed hid that club's next match from branch A, and since 133
      -- an empty result means match-watcher is not called at all (138).
      AND jsonb_typeof(r.data->'response') = 'array'
      AND jsonb_array_length(r.data->'response') > 0
    ORDER BY r.team_id, r.fetched_at DESC
  ),
  upcoming AS (
    SELECT (f->'league'->>'id')::int AS league_id,
           (f->'fixture'->>'id')::int AS fixture_id,
           (f->'fixture'->>'date')::timestamptz AS kickoff
    FROM latest, LATERAL jsonb_array_elements(latest.data->'response') f
    WHERE f->'league'->>'id' ~ '^[0-9]+$'
      AND f->'fixture'->>'date' IS NOT NULL
  )
  SELECT DISTINCT league_id, (kickoff AT TIME ZONE 'UTC')::date AS poll_date FROM (

    -- A. Kicking off, or should be under way, per the fixture feed.
    SELECT u.league_id, u.kickoff
    FROM upcoming u
    WHERE u.league_id IN (SELECT c.league_id FROM covered c)
      AND u.kickoff BETWEEN at - INTERVAL '4 hours' AND at + INTERVAL '35 minutes'
      AND NOT EXISTS (
        SELECT 1 FROM match_status_state s
        WHERE s.fixture_id = u.fixture_id
          AND s.status IN ('FT','AET','PEN','PST','CANC','ABD','AWD','WO')
      )

    UNION ALL

    -- B. Already observed and not finished.
    SELECT s.league_id, s.kickoff_time
    FROM match_status_state s
    WHERE s.status NOT IN ('FT','AET','PEN','PST','CANC','ABD','AWD','WO')
      AND s.kickoff_time BETWEEN at - INTERVAL '6 hours' AND at + INTERVAL '35 minutes'
      AND s.league_id IN (SELECT c.league_id FROM covered c)

    UNION ALL

    -- D. (145) A level cup tie held as 'BT' after the feed called it finished
    --    (match-watcher levelSingleLegFt). The shootout result can land hours
    --    later: Fleetwood v Arsenal still read "FT 1-1" at 22:00 and "PEN 5-3"
    --    by 06:00. Past branch B's six hours, look every tenth minute until
    --    fourteen hours after kickoff, about 50 calls, so the cards are right
    --    by morning. match-watcher decides whether it is still worth a push.
    SELECT s.league_id, s.kickoff_time
    FROM match_status_state s
    WHERE s.status = 'BT'
      AND s.kickoff_time BETWEEN at - INTERVAL '14 hours' AND at - INTERVAL '6 hours'
      AND extract(minute FROM at)::int % 10 = 0
      AND s.league_id IN (SELECT c.league_id FROM covered c)

    UNION ALL

    -- C. Degrade per club whose fixture feed is stale.
    SELECT t.league_id, at
    FROM teams t
    WHERE t.is_active AND t.league_id IS NOT NULL AND t.entity_type <> 'tournament'
      AND NOT EXISTS (
        SELECT 1 FROM raw_fetch_logs r
        WHERE r.team_id = t.id
          AND r.source = 'api_football_fixtures_next'
          AND r.fetched_at > at - INTERVAL '3 days'
      )
  ) x;
$$;
REVOKE EXECUTE ON FUNCTION public.poll_leagues(timestamptz) FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule('match-status-reaper');
SELECT cron.schedule(
  'match-status-reaper',
  '0 5 * * *',
  $reaper$
    UPDATE match_status_state
    SET status = 'ABD',
        la_ended = true,
        last_checked = now()
    WHERE status NOT IN ('FT','AET','PEN','ABD','PST','CANC','AWD','WO','TBD')
      AND kickoff_time < now() - interval '4 hours'
      AND NOT (status = 'BT' AND kickoff_time > now() - interval '14 hours')
  $reaper$
);

-- Verification:
--   SELECT * FROM poll_leagues('2026-10-28 04:10+00');  -- with a held row from 20:00 the night before
--   SELECT has_function_privilege('anon', 'public.poll_leagues(timestamptz)', 'EXECUTE');  -- false
--   SELECT command FROM cron.job WHERE jobname = 'match-status-reaper';
