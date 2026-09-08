-- 093_cup_polling_window.sql
-- Cup coverage, phase 0 (CUP_COVERAGE_PLAN.md, 2026-09-08).
--
-- The League Cup last 32 starts tonight with 19 of our 20 clubs in it, the
-- Europa League on 16 September, the Conference League on 15 October, the FA
-- Cup in January. match-watcher polled only the Champions League beyond the
-- home league (migration 087), so none of those nights existed for the app.
--
-- Two changes to active_competition_ids():
--
--  1. The covered set widens from (2) to the five club cups.
--  2. A cup league is polled only while one of our clubs has a fixture in it
--     dated within a day of now. match-watcher polls every active league every
--     minute (1 440 API calls a day per league); with five cups "someone is in
--     it" would be 8 640 a day against a 7 500 cap. Phase 1 replaces this with
--     poll_leagues(), which applies the same idea to the Premier League too.
--
-- The rest of 087 stands: derived from the fixture feed, never stored.

CREATE OR REPLACE FUNCTION active_competition_ids()
RETURNS TABLE (league_id integer)
LANGUAGE sql
STABLE
AS $$
  -- Home leagues of every active entity: today's behaviour, and the floor if
  -- the fixture data is empty or stale.
  SELECT DISTINCT t.league_id
  FROM teams t
  WHERE t.is_active AND t.league_id IS NOT NULL

  UNION

  -- Plus every covered cup one of our active clubs plays in within a day.
  SELECT DISTINCT (f->'league'->>'id')::int
  FROM (
    SELECT DISTINCT ON (r.team_id) r.team_id, r.data
    FROM raw_fetch_logs r
    JOIN teams t ON t.id = r.team_id AND t.is_active AND t.league_id IS NOT NULL
    WHERE r.source = 'api_football_fixtures_next'
      AND r.fetched_at > NOW() - INTERVAL '3 days'
    ORDER BY r.team_id, r.fetched_at DESC
  ) latest,
  LATERAL jsonb_array_elements(latest.data->'response') f
  WHERE f->'league'->>'id' ~ '^[0-9]+$'
    AND (f->'league'->>'id')::int IN (2, 3, 848, 48, 45)
    AND (f->'fixture'->>'date')::timestamptz BETWEEN NOW() - INTERVAL '1 day'
                                               AND NOW() + INTERVAL '1 day';
$$;

COMMENT ON FUNCTION active_competition_ids() IS
  'Leagues match-watcher polls: every active entity''s home league, plus any '
  'covered cup (Champions League 2, Europa League 3, Conference League 848, '
  'League Cup 48, FA Cup 45) one of our active clubs has a fixture in within '
  'a day. Derived from raw_fetch_logs rather than stored.';
