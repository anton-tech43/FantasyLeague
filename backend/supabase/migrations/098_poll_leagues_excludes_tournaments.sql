-- 098_poll_leagues_excludes_tournaments.sql
-- poll_leagues() read the Champions League tournament row's fixture feed (2026-09-09).
--
-- The `latest` CTE in 094 excluded tournament entities only by
-- `t.league_id IS NOT NULL`, and its comment said so was enough. It was not:
-- `teams.champions_league` (087) carries league_id = 2, so its fixtures_next
-- feed — every club in Europe — drove branch A. At 16:30 UTC on 9 Sep the
-- function returned (2, 2026-09-09) for Barcelona v Feyenoord and Stuttgart v
-- Viking; ours kicked off at 19:00. About 135 wasted calls per Champions
-- League matchday, and on a knockout night without a Premier League club, a
-- whole evening of polling a competition nobody follows.
--
-- Branch C already said `entity_type <> 'tournament'`. Branch A now does too.
-- Same body as 094 otherwise. active_competition_ids() (087/093) is dropped:
-- nothing has called it since 094 shipped, it carried the same leak, and a
-- rollback that reinstated it would reinstate the leak.

CREATE OR REPLACE FUNCTION poll_leagues(at timestamptz DEFAULT now())
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

DROP FUNCTION IF EXISTS active_competition_ids(date);
DROP FUNCTION IF EXISTS active_competition_ids();
