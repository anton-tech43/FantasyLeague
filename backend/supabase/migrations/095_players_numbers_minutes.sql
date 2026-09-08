-- 095_players_numbers_minutes.sql
--
-- The Quiz's "His squad" pack asks photo → name, name → shirt number and
-- name → position, and the player sheet says who he is. Three things were
-- missing for that:
--
--   1. `players` had no shirt number, though API-Football's /players/squads
--      payload we already store has carried `number` all along (mig 084 just
--      never read it).
--   2. Nothing in the schema said who actually plays. Without minutes, "his
--      squad" is 40 names of which half are academy cover, and the dossier
--      routine has no way to pick the starting XI.
--   3. `players` was service-role only (mig 077), so the app could not read
--      the table it is now meant to render.
--
-- Minutes/appearances come from the new `api_football_players_stats` source
-- that data-fetcher writes once a day (~40 calls/day for 20 clubs, gated on
-- "no row for this team in the last 20 hours" — see data-fetcher/index.ts and
-- _shared/player-stats.ts). This file only reads what has landed in
-- raw_fetch_logs; it never calls an API and costs nothing to re-run.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE, DROP POLICY IF
-- EXISTS, cron.unschedule guarded. Applied by hand (schema_migrations only
-- tracks 001-017).

-- ---------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------
ALTER TABLE players
  ADD COLUMN IF NOT EXISTS number int,
  ADD COLUMN IF NOT EXISTS appearances int,
  ADD COLUMN IF NOT EXISTS minutes int,
  ADD COLUMN IF NOT EXISTS stats_updated_at timestamptz;

COMMENT ON COLUMN players.number IS 'Shirt number from /players/squads. NULL for a squad member without one.';
COMMENT ON COLUMN players.minutes IS 'Minutes played this season for this club, all competitions. NULL = no stats record yet; 0 = named but unused.';
COMMENT ON COLUMN players.stats_updated_at IS 'When sync_player_stats_from_raw() last touched appearances/minutes.';

-- ---------------------------------------------------------------------------
-- 2. Squad sync now writes the shirt number too (mig 084 + `number`)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_players_from_squads()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  n integer;
BEGIN
  WITH latest AS (
    SELECT DISTINCT ON (r.team_id) r.team_id, r.data
    FROM public.raw_fetch_logs r
    JOIN public.teams t ON t.id = r.team_id
    WHERE r.source = 'api_football_squad'
      AND t.is_active
      AND jsonb_array_length(COALESCE(r.data->'response', '[]'::jsonb)) > 0
    ORDER BY r.team_id, r.fetched_at DESC
  ),
  -- DISTINCT ON: a player on loan can sit in two clubs' squad payloads at once;
  -- one row per api_player_id or the upsert fails ("cannot affect row a second time").
  squad_rows AS (
    SELECT DISTINCT ON ((p->>'id')::int)
           (p->>'id')::int AS api_player_id,
           l.team_id,
           p->>'name' AS name,
           p->>'position' AS position,
           p->>'photo' AS photo_url,
           -- A squad member without a shirt number has JSON null here, which
           -- ::int would turn into SQL NULL anyway; the regex guard keeps a
           -- stray non-numeric value (never seen, but the feed is not ours)
           -- from aborting the whole sync.
           NULLIF(p->>'number', '')::int AS number
    FROM latest l,
         jsonb_array_elements(l.data->'response'->0->'players') p
    WHERE p->>'id' ~ '^[0-9]+$' AND COALESCE(p->>'name', '') <> ''
      AND (p->>'number' IS NULL OR p->>'number' ~ '^[0-9]+$')
    ORDER BY (p->>'id')::int, l.team_id
  ),
  up AS (
    INSERT INTO public.players (api_player_id, team_id, name, position, photo_url, number, updated_at)
    SELECT api_player_id, team_id, name, position, photo_url, number, now() FROM squad_rows
    ON CONFLICT (api_player_id) DO UPDATE SET
      team_id    = EXCLUDED.team_id,
      name       = EXCLUDED.name,
      position   = EXCLUDED.position,
      photo_url  = COALESCE(EXCLUDED.photo_url, public.players.photo_url),
      number     = EXCLUDED.number,
      updated_at = now()
    WHERE public.players.team_id IS DISTINCT FROM EXCLUDED.team_id
       OR public.players.name IS DISTINCT FROM EXCLUDED.name
       OR public.players.position IS DISTINCT FROM EXCLUDED.position
       OR public.players.number IS DISTINCT FROM EXCLUDED.number
       OR public.players.photo_url IS DISTINCT FROM COALESCE(EXCLUDED.photo_url, public.players.photo_url)
    RETURNING 1
  )
  SELECT count(*) INTO n FROM up;
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_players_from_squads() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_players_from_squads() TO service_role;

-- ---------------------------------------------------------------------------
-- 3. Minutes / appearances from the daily /players stats fetch
-- ---------------------------------------------------------------------------
-- `statistics` is one entry PER COMPETITION (Community Shield, Premier League,
-- a cup...), not a season total — reading statistics[0] would rank a squad by
-- whatever competition the feed happens to list first. We sum every entry
-- whose team.id is this club's, so `minutes` means "minutes for this club this
-- season, all competitions", which is what "who actually plays" needs in
-- September when the league is four games old.
--
-- A player who moved mid-window can appear in two clubs' payloads; DISTINCT ON
-- keeps the club he has played the most for, which is also the row the app
-- shows him under.
CREATE OR REPLACE FUNCTION public.sync_player_stats_from_raw()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  n integer;
BEGIN
  WITH latest AS (
    SELECT DISTINCT ON (r.team_id) r.team_id, t.api_football_id, r.data
    FROM public.raw_fetch_logs r
    JOIN public.teams t ON t.id = r.team_id
    WHERE r.source = 'api_football_players_stats'
      AND t.is_active
      AND jsonb_array_length(COALESCE(r.data->'response', '[]'::jsonb)) > 0
    ORDER BY r.team_id, r.fetched_at DESC
  ),
  per_club AS (
    SELECT (e->'player'->>'id')::int AS api_player_id,
           l.team_id,
           COALESCE(SUM(NULLIF(s->'games'->>'appearences', '')::int), 0) AS appearances,
           COALESCE(SUM(NULLIF(s->'games'->>'minutes', '')::int), 0) AS minutes
    FROM latest l,
         jsonb_array_elements(l.data->'response') e,
         jsonb_array_elements(e->'statistics') s
    WHERE e->'player'->>'id' ~ '^[0-9]+$'
      AND (s->'team'->>'id')::int = l.api_football_id
    GROUP BY 1, 2
  ),
  best AS (
    SELECT DISTINCT ON (api_player_id) api_player_id, appearances, minutes
    FROM per_club
    ORDER BY api_player_id, minutes DESC, appearances DESC
  ),
  upd AS (
    UPDATE public.players p
       SET appearances      = b.appearances,
           minutes          = b.minutes,
           stats_updated_at = now()
      FROM best b
     WHERE p.api_player_id = b.api_player_id
    RETURNING 1
  )
  SELECT count(*) INTO n FROM upd;
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_player_stats_from_raw() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_player_stats_from_raw() TO service_role;

-- 06:40 UTC: after the 05:30 squad sync and the 06:00 daily-pipeline run, so
-- numbers and minutes land on the same rows the same morning. The fetch gate
-- is "older than 20 hours", which settles on the 06:00 run (a 06:00 fetch is
-- due again at 02:00, and 06:00 is the day's first run) but drifts there over
-- a few days from whenever the first fetch happened. That is fine: this
-- function always reads the newest stored payload, however old.
SELECT cron.unschedule('goaldigger-player-stats-sync')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-player-stats-sync');
SELECT cron.schedule('goaldigger-player-stats-sync', '40 6 * * *', $$SELECT public.sync_player_stats_from_raw();$$);

-- ---------------------------------------------------------------------------
-- 4. The app can read `players`
-- ---------------------------------------------------------------------------
-- Mirrors player_cards_read (mig 002). Squad names, numbers, positions, photos
-- and minutes are all public football facts; nothing here is user data. Writes
-- stay on the service role — players_service_only (mig 077) is FOR ALL and
-- there is no anon INSERT/UPDATE/DELETE policy, so a publishable key can only
-- SELECT.
DROP POLICY IF EXISTS players_read ON players;
CREATE POLICY players_read ON players
  FOR SELECT TO anon, authenticated USING (true);

-- ---------------------------------------------------------------------------
-- 5. Run once now
-- ---------------------------------------------------------------------------
SELECT public.sync_players_from_squads() AS players_written;
SELECT public.sync_player_stats_from_raw() AS stats_written;

-- Verification:
--   SELECT team_id, count(*), count(number), count(minutes) FROM players
--    WHERE team_id IN (SELECT id FROM teams WHERE league_id=39 AND is_active)
--    GROUP BY 1 ORDER BY 1;
--   SELECT jobname, schedule FROM cron.job WHERE jobname LIKE 'goaldigger-player%';
