-- 094_poll_leagues_and_cup_entities.sql
-- Cup coverage, phase 1 (CUP_COVERAGE_PLAN.md, 2026-09-08).
--
-- Three things:
--
--  1. poll_leagues() — what match-watcher polls, and on which date. Supersedes
--     active_competition_ids() (087, widened in 093), which answered "which
--     competitions is somebody in" and therefore polled the Premier League 24/7
--     and every covered cup for a day either side of a fixture. Every polled
--     league costs 1 440 API calls a day (one a minute) against a 7 500 cap,
--     so with five cups that answer no longer fits. This one answers "what is
--     kicking off, or still being played, right now", which is what the poller
--     actually needs. The Premier League stops polling on days it has no game.
--
--     active_competition_ids() is left in place so a rollback of the
--     match-watcher deploy still works; nothing calls it after this ships.
--
--  2. The four remaining cups as tournament entities, so a competition-level
--     view (table, results, what is coming) has somewhere to live — the same
--     shape champions_league got in 087.
--
--  3. content_items.league_id, so a card can say which competition it is about.
--     Every surface that renders a card had to guess until now.

-- ============================================================
-- 1. What to poll, and when
-- ============================================================

CREATE OR REPLACE FUNCTION poll_leagues(at timestamptz DEFAULT now())
RETURNS TABLE (league_id integer, poll_date date)
LANGUAGE sql
STABLE
AS $$
  WITH covered AS (
    -- Home leagues of active entities plus the cups we cover. A league outside
    -- this set is never polled, whatever the fixture feed says (a club's
    -- pre-season friendlies live in their own league ids).
    SELECT DISTINCT t.league_id FROM teams t
    WHERE t.is_active AND t.league_id IS NOT NULL
    UNION
    SELECT unnest(ARRAY[2, 3, 848, 48, 45])
  ),
  latest AS (
    -- Newest fixture feed per active CLUB. Tournament entities are excluded on
    -- purpose: their feed is every club's fixtures in that competition, which
    -- would poll a Champions League night none of ours is playing in.
    SELECT DISTINCT ON (r.team_id) r.team_id, r.data, r.fetched_at
    FROM raw_fetch_logs r
    JOIN teams t ON t.id = r.team_id AND t.is_active AND t.league_id IS NOT NULL
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
    --    The lead is 35 minutes because the kickoff-soon push fires at 30 and
    --    needs a tick inside the window to see it. Polling stops when the
    --    fixture reaches a terminal status rather than at kickoff + 4h.
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

    -- B. Already observed and not finished. Covers extra time and penalties
    --    past the 4h mark, a delayed kickoff, a same-day reschedule, and the
    --    23:00 kickoff still being played after UTC midnight (which is what the
    --    old hangover query in match-watcher did). The 6h ceiling stops a row
    --    stuck in NS/SUSP/INT from polling all day.
    SELECT s.league_id, s.kickoff_time
    FROM match_status_state s
    WHERE s.status NOT IN ('FT','AET','PEN','PST','CANC','ABD','AWD','WO')
      AND s.kickoff_time BETWEEN at - INTERVAL '6 hours' AND at + INTERVAL '35 minutes'
      AND s.league_id IN (SELECT c.league_id FROM covered c)

    UNION ALL

    -- C. Degrade per club, not globally: a club with no fixture feed inside
    --    the same 3-day window the `latest` CTE uses cannot be reasoned about,
    --    so its home league goes back to always-on. Losing coverage of a match
    --    is worse than spending the calls. Normally this returns nothing.
    --
    --    The window has to match `latest`. An earlier draft used 3 HOURS, which
    --    fired every night for every club: the data pipeline runs 06:00-22:00
    --    UTC every two hours, so a 3-hour test is failing by 05:00 whatever the
    --    feed says. A feed fetched yesterday still lists tonight's fixture —
    --    fixtures_next carries the next ten.
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

COMMENT ON FUNCTION poll_leagues(timestamptz) IS
  'What match-watcher polls and on which UTC date: leagues with one of our '
  'clubs kicking off within 35 minutes or played in the last 4 hours, plus any '
  'observed fixture not yet terminal, plus a per-club fallback to the home '
  'league when that club''s fixture feed is stale. Derived, never stored.';

GRANT EXECUTE ON FUNCTION poll_leagues(timestamptz) TO service_role;

-- ============================================================
-- 2. The remaining cups as tournament entities
-- ============================================================
-- api_football_id IS the league id for a tournament row (data-fetcher reads it
-- that way). league_id stays NULL: a competition is not in a competition, and
-- migration 076's CHECK allows NULL only for entity_type = 'tournament'.

INSERT INTO teams (id, display_name, short_name, api_football_id, entity_type, league_id, is_active)
VALUES
  ('europa_league',     'Europa League',     'Europa League',     3,   'tournament', NULL, true),
  ('conference_league', 'Conference League', 'Conference Lg',     848, 'tournament', NULL, true),
  ('league_cup',        'League Cup',        'League Cup',        48,  'tournament', NULL, true),
  ('fa_cup',            'FA Cup',            'FA Cup',            45,  'tournament', NULL, true)
ON CONFLICT (id) DO UPDATE
  SET is_active = true,
      entity_type = 'tournament',
      api_football_id = EXCLUDED.api_football_id;

-- ============================================================
-- 3. Which competition a card is about
-- ============================================================
-- Nullable with no FK: league ids come from API-Football, not from us, and
-- every row written before today legitimately has no answer.

ALTER TABLE content_items ADD COLUMN IF NOT EXISTS league_id integer;

COMMENT ON COLUMN content_items.league_id IS
  'API-Football league id of the competition this card is about (39 Premier '
  'League, 2 Champions League, 3 Europa League, 848 Conference League, 48 '
  'League Cup, 45 FA Cup, 1 World Championship). NULL on pre-2026-09-08 rows '
  'and on cards that are not about one match.';

CREATE INDEX IF NOT EXISTS idx_content_items_league
  ON content_items (league_id, published_at DESC)
  WHERE league_id IS NOT NULL;
