-- player_stats_sync_check.sql — the one runnable check for sync_player_stats_from_raw() (095/100).
--
--   set -a && source backend/.env && set +a
--   /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f backend/supabase/tests/player_stats_sync_check.sql
--
-- One transaction, rolled back: a fake club with one player who has a league
-- row and a cup row in the payload, plus a row for another club that must be
-- ignored. Asserts the sums, the league-only fields, the weighted rating and
-- the nationality. Nothing is written.
BEGIN;

INSERT INTO teams (id, display_name, short_name, api_football_id, entity_type, league_id, is_active)
VALUES ('zz_stats_club', 'ZZ Stats', 'ZZ Stats', 9980001, 'club', 39, true);
INSERT INTO players (api_player_id, team_id, name, position) VALUES (99800001, 'zz_stats_club', 'Z. Tester', 'Attacker');

INSERT INTO raw_fetch_logs (team_id, source, fetched_at, data)
VALUES ('zz_stats_club', 'api_football_players_stats', now(), jsonb_build_object('response', jsonb_build_array(
  jsonb_build_object(
    'player', jsonb_build_object('id', 99800001, 'name', 'Z. Tester', 'nationality', 'Sweden', 'age', 24),
    'statistics', jsonb_build_array(
      jsonb_build_object('team', jsonb_build_object('id', 9980001), 'league', jsonb_build_object('id', 39),
        'games', jsonb_build_object('appearences', 4, 'minutes', 360, 'lineups', 4, 'rating', '7.50', 'captain', false),
        'substitutes', jsonb_build_object('in', 0),
        'goals', jsonb_build_object('total', 5, 'assists', 1, 'saves', null, 'conceded', 0),
        'cards', jsonb_build_object('yellow', 1, 'red', 0)),
      jsonb_build_object('team', jsonb_build_object('id', 9980001), 'league', jsonb_build_object('id', 48),
        'games', jsonb_build_object('appearences', 1, 'minutes', 90, 'lineups', 0, 'rating', '6.50', 'captain', true),
        'substitutes', jsonb_build_object('in', 1),
        'goals', jsonb_build_object('total', 2, 'assists', 0, 'saves', null, 'conceded', 0),
        'cards', jsonb_build_object('yellow', 0, 'red', 0)),
      -- A row for another club (a loan spell): must not count.
      jsonb_build_object('team', jsonb_build_object('id', 1), 'league', jsonb_build_object('id', 39),
        'games', jsonb_build_object('appearences', 9, 'minutes', 800, 'lineups', 9, 'rating', '5.00', 'captain', false),
        'substitutes', jsonb_build_object('in', 0),
        'goals', jsonb_build_object('total', 9, 'assists', 9, 'saves', null, 'conceded', 0),
        'cards', jsonb_build_object('yellow', 9, 'red', 1))
    )))));

SELECT sync_player_stats_from_raw();

DO $$
DECLARE p players%ROWTYPE;
BEGIN
  SELECT * INTO p FROM players WHERE api_player_id = 99800001;
  IF p.goals <> 7 THEN RAISE EXCEPTION 'goals: expected 7 (5 league + 2 cup), got %', p.goals; END IF;
  IF p.assists <> 1 THEN RAISE EXCEPTION 'assists: expected 1, got %', p.assists; END IF;
  IF p.appearances <> 5 OR p.minutes <> 450 THEN RAISE EXCEPTION 'apps/minutes: expected 5/450, got %/%', p.appearances, p.minutes; END IF;
  IF p.starts <> 4 OR p.sub_appearances <> 1 THEN RAISE EXCEPTION 'starts/subs: expected 4/1, got %/%', p.starts, p.sub_appearances; END IF;
  IF p.league_goals <> 5 OR p.league_starts <> 4 THEN RAISE EXCEPTION 'league_goals/starts: expected 5/4, got %/%', p.league_goals, p.league_starts; END IF;
  IF p.yellow_cards <> 1 OR p.red_cards <> 0 THEN RAISE EXCEPTION 'cards wrong: %/%', p.yellow_cards, p.red_cards; END IF;
  IF p.captain IS NOT TRUE THEN RAISE EXCEPTION 'captain: expected true'; END IF;
  IF p.nationality <> 'Sweden' OR p.age <> 24 THEN RAISE EXCEPTION 'nationality/age wrong: %/%', p.nationality, p.age; END IF;
  -- (7.50*360 + 6.50*90) / 450 = 7.30
  IF p.rating <> 7.30 THEN RAISE EXCEPTION 'rating: expected 7.30 weighted, got %', p.rating; END IF;
END $$;

SELECT 'player_stats_sync_check: all assertions passed' AS result;
ROLLBACK;
