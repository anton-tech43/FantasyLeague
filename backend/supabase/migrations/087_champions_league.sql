-- 087_champions_league.sql
-- Champions League coverage, integrated into the Premier League app.
--
-- The gap: a man who follows Arsenal also follows the Champions League, and he
-- knows which big sides are still in it, when the quarter-finals are, and who
-- went out on Tuesday. The app covered none of that. Five PL clubs are in the
-- 2026-27 competition (Arsenal, Man City, Man Utd, Liverpool, Aston Villa) and
-- the league phase starts 8 September 2026.
--
-- Two pieces here:
--
--  1. `champions_league` as a tournament entity, the same shape
--     `world_championship` used, so tournament-level cards ("Real Madrid are
--     out", "quarter-final draw Friday") have somewhere to live. They reach
--     users through the shared Football feed (`everyone_talking`), not through
--     a follow — nobody follows a competition, and a card about Bayern has no
--     business in an Arsenal feed.
--
--  2. `active_competition_ids()` — which leagues match-watcher should poll.
--     Deliberately DERIVED from the fixtures we already hold rather than stored
--     in a column. A club's European participation changes every August and
--     again the moment they are knocked out; a manual column would be wrong
--     within weeks, which is the whole lesson of DATA_SOURCES.md. This reads
--     the leagues our active clubs actually have fixtures in, so it corrects
--     itself on the next data-fetcher run.

-- ============================================================
-- 1. The tournament entity
-- ============================================================

INSERT INTO teams (id, display_name, short_name, api_football_id, entity_type, league_id, is_active)
VALUES ('champions_league', 'Champions League', 'Champions League', 2, 'tournament', NULL, true)
ON CONFLICT (id) DO UPDATE
  SET is_active = true,
      entity_type = 'tournament',
      api_football_id = EXCLUDED.api_football_id;

-- ============================================================
-- 2. Which competitions to poll, derived from real fixtures
-- ============================================================

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

  -- Plus every competition those clubs actually have an upcoming fixture in.
  -- `fixtures_next` is fetched without a league filter, so a PL club's
  -- Champions League and cup games are already in there.
  SELECT DISTINCT (f->'league'->>'id')::int
  FROM (
    SELECT DISTINCT ON (r.team_id) r.team_id, r.data
    FROM raw_fetch_logs r
    JOIN teams t ON t.id = r.team_id AND t.is_active
    WHERE r.source = 'api_football_fixtures_next'
      AND r.fetched_at > NOW() - INTERVAL '3 days'
    ORDER BY r.team_id, r.fetched_at DESC
  ) latest,
  LATERAL jsonb_array_elements(latest.data->'response') f
  WHERE f->'league'->>'id' ~ '^[0-9]+$'
    -- Only competitions we are prepared to cover. A club also appears in the
    -- League Cup and the FA Cup; polling those every minute would triple the
    -- API spend for coverage we do not write content for yet.
    AND (f->'league'->>'id')::int IN (2)
    AND (f->'fixture'->>'date')::timestamptz > NOW() - INTERVAL '1 day';
$$;

COMMENT ON FUNCTION active_competition_ids() IS
  'Leagues match-watcher polls: every active entity''s home league, plus any '
  'covered competition (currently Champions League = 2) our active clubs have '
  'a live or upcoming fixture in. Derived from raw_fetch_logs rather than '
  'stored, so a club being knocked out stops the polling on its own.';

GRANT EXECUTE ON FUNCTION active_competition_ids() TO service_role;
