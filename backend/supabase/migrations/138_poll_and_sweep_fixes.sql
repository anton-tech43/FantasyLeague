-- 138_poll_and_sweep_fixes.sql  (bug hunt 2026-10-27)
--
-- 1. poll_leagues(): skip empty fixture feeds. data-fetcher stores API-
--    Football's rate-limit replies (HTTP 200, response []) like any other, and
--    the newest row per club was taken whether or not it held a fixture. One
--    empty batch at 12:00 hid a 12:30 kickoff from branch A, and branch B has
--    no row yet before the first poll — so no goal pushes and no Live Activity
--    until the next fetch. _shared/cached-fixtures.ts already skips them.
--
-- 2. la_sweep_due(): the "kicked off over 3 hours ago" branch also ended
--    activities for a match still being played (a delayed kickoff, extra time,
--    penalties). Only when it is not live. match-watcher's sweepLiveActivities
--    applies the same rule.

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

CREATE OR REPLACE FUNCTION public.la_sweep_due()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM live_activity_tokens t
    LEFT JOIN match_status_state s ON s.fixture_id = t.fixture_id
    WHERE t.kind = 'update' AND t.is_active
      AND (
        s.status IN ('FT','AET','PEN','ABD','CANC','PST','AWD','WO')
        OR (s.kickoff_time < now() - interval '3 hours'
            AND s.status NOT IN ('1H','HT','2H','ET','BT','P','INT','SUSP','LIVE'))
        OR s.kickoff_time < now() - interval '6 hours'
        OR (s.fixture_id IS NULL AND t.created_at < now() - interval '3 hours')
      )
  );
$$;
REVOKE ALL ON FUNCTION public.la_sweep_due() FROM PUBLIC, anon, authenticated;

-- Verification:
--   SELECT * FROM poll_leagues();
--   SELECT la_sweep_due();
--   SELECT has_function_privilege('anon', 'public.poll_leagues(timestamptz)', 'EXECUTE');  -- false
