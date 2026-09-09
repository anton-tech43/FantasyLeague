-- poll_leagues_check.sql — the one runnable check for poll_leagues() (094/098).
--
--   set -a && source backend/.env && set +a
--   /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f backend/supabase/tests/poll_leagues_check.sql
--
-- Runs inside one transaction that is ROLLED BACK: it inserts a fake club, a
-- fake tournament and fake fixture feeds, asks poll_leagues() at fixed times,
-- and raises on the first wrong answer. Nothing is written.
BEGIN;

INSERT INTO teams (id, display_name, short_name, api_football_id, entity_type, league_id, is_active)
VALUES ('zz_test_club', 'ZZ Test Club', 'ZZ Test', 9990001, 'club', 9901, true),
       ('zz_other', 'ZZ Other', 'ZZ Other', 9990002, 'club', 9901, false),
       ('zz_test_tournament', 'ZZ Test Cup', 'ZZ Cup', 9902, 'tournament', NULL, true);

-- The club's own feed: one fixture in its home league at 20:00 UTC on 2031-01-15.
INSERT INTO raw_fetch_logs (team_id, source, fetched_at, data)
VALUES ('zz_test_club', 'api_football_fixtures_next', '2031-01-15 06:00:00+00',
  jsonb_build_object('response', jsonb_build_array(jsonb_build_object(
    'fixture', jsonb_build_object('id', 999000001, 'date', '2031-01-15T20:00:00+00:00'),
    'league', jsonb_build_object('id', 9901),
    'teams', jsonb_build_object('home', jsonb_build_object('id', 9990001), 'away', jsonb_build_object('id', 9990002))
  ))));

-- The tournament's feed: a covered-cup fixture (League Cup, 48) at 17:00 UTC
-- involving nobody of ours. Must never drive polling.
INSERT INTO raw_fetch_logs (team_id, source, fetched_at, data)
VALUES ('zz_test_tournament', 'api_football_fixtures_next', '2031-01-15 06:00:00+00',
  jsonb_build_object('response', jsonb_build_array(jsonb_build_object(
    'fixture', jsonb_build_object('id', 999000002, 'date', '2031-01-15T17:00:00+00:00'),
    'league', jsonb_build_object('id', 48),
    'teams', jsonb_build_object('home', jsonb_build_object('id', 1), 'away', jsonb_build_object('id', 2))
  ))));

DO $$
DECLARE
  hit boolean;
BEGIN
  -- 19:24: eleven minutes before the 35-minute lead → not yet.
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-15 19:24:00+00') WHERE league_id = 9901) INTO hit;
  IF hit THEN RAISE EXCEPTION 'polled 36 minutes before kickoff'; END IF;

  -- 19:26: inside the lead → yes, on that date.
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-15 19:26:00+00') WHERE league_id = 9901 AND poll_date = '2031-01-15') INTO hit;
  IF NOT hit THEN RAISE EXCEPTION 'not polled 34 minutes before kickoff'; END IF;

  -- 23:59: kickoff + 3h59 → still polling (no terminal row).
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-15 23:59:00+00') WHERE league_id = 9901) INTO hit;
  IF NOT hit THEN RAISE EXCEPTION 'stopped polling before kickoff + 4h'; END IF;

  -- 00:01 next day, past the 4h ceiling, no observed row → stops.
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-16 00:01:00+00') WHERE league_id = 9901) INTO hit;
  IF hit THEN RAISE EXCEPTION 'still polling past kickoff + 4h with no live row'; END IF;

  -- The tournament's feed never drives branch A: at 17:10 league 48 is absent
  -- (unless some real club feed has a League Cup tie that day; guard with the date).
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-15 17:10:00+00') WHERE league_id = 48 AND poll_date = '2031-01-15') INTO hit;
  IF hit THEN RAISE EXCEPTION 'a tournament entity''s fixture feed drove polling'; END IF;
END $$;

-- A terminal state row stops branch A at once.
INSERT INTO match_status_state (fixture_id, league_id, home_team_id, away_team_id, status, kickoff_time, last_checked)
VALUES (999000001, 9901, 'zz_test_club', 'zz_other', 'FT', '2031-01-15 20:00:00+00', now());
DO $$
DECLARE hit boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-15 21:00:00+00') WHERE league_id = 9901) INTO hit;
  IF hit THEN RAISE EXCEPTION 'polled a fixture already at FT'; END IF;
END $$;

-- A live row keeps polling past 4h (extra time, penalties), under the KICKOFF's date.
UPDATE match_status_state SET status = 'P', kickoff_time = '2031-01-15 23:00:00+00' WHERE fixture_id = 999000001;
DO $$
DECLARE hit boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-16 01:30:00+00') WHERE league_id = 9901 AND poll_date = '2031-01-15') INTO hit;
  IF NOT hit THEN RAISE EXCEPTION 'a live row after UTC midnight did not poll under the kickoff date'; END IF;
END $$;

-- Branch C: a club with no fixture feed inside 3 days degrades to always-on.
DELETE FROM raw_fetch_logs WHERE team_id = 'zz_test_club';
DO $$
DECLARE hit boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM poll_leagues('2031-01-15 09:00:00+00') WHERE league_id = 9901) INTO hit;
  IF NOT hit THEN RAISE EXCEPTION 'a club with a stale feed was silenced instead of degraded'; END IF;
END $$;

SELECT 'poll_leagues_check: all assertions passed' AS result;
ROLLBACK;
