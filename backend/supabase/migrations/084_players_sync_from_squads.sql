-- 084_players_sync_from_squads.sql
-- Keep `players` (api_player_id → team_id, name, position, photo_url) in step
-- with API-Football's /players/squads, which data-fetcher already stores in
-- raw_fetch_logs every 2h but nothing consumed. Audit 2026-09: players was last
-- written 2026-07-10 (mig 077 seed); after the summer window every active PL
-- club was missing 10–26 squad members, so scorer photos in the live box and
-- FT articles fell back to "no face" for any new signing.
--
-- Pure SQL, $0, idempotent: newest squad snapshot per active club, upsert on
-- api_player_id (a transferred player moves to his new team_id). Players who
-- left a club keep their row (photo lookups by id still resolve) — the
-- team_id is simply the last club we saw them at.
--
-- Scheduled daily 05:30 UTC (after the 04:00/06:00 fetches have landed).
-- Applied manually (schema_migrations only tracks 001–017, see A12).

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
           p->>'photo' AS photo_url
    FROM latest l,
         jsonb_array_elements(l.data->'response'->0->'players') p
    WHERE p->>'id' ~ '^[0-9]+$' AND COALESCE(p->>'name', '') <> ''
    ORDER BY (p->>'id')::int, l.team_id
  ),
  up AS (
    INSERT INTO public.players (api_player_id, team_id, name, position, photo_url, updated_at)
    SELECT api_player_id, team_id, name, position, photo_url, now() FROM squad_rows
    ON CONFLICT (api_player_id) DO UPDATE SET
      team_id    = EXCLUDED.team_id,
      name       = EXCLUDED.name,
      position   = EXCLUDED.position,
      photo_url  = COALESCE(EXCLUDED.photo_url, public.players.photo_url),
      updated_at = now()
    WHERE public.players.team_id IS DISTINCT FROM EXCLUDED.team_id
       OR public.players.name IS DISTINCT FROM EXCLUDED.name
       OR public.players.position IS DISTINCT FROM EXCLUDED.position
       OR public.players.photo_url IS DISTINCT FROM COALESCE(EXCLUDED.photo_url, public.players.photo_url)
    RETURNING 1
  )
  SELECT count(*) INTO n FROM up;
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_players_from_squads() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_players_from_squads() TO service_role;

SELECT cron.unschedule('goaldigger-players-sync')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-players-sync');
SELECT cron.schedule('goaldigger-players-sync', '30 5 * * *', $$SELECT public.sync_players_from_squads();$$);

-- Run once now so tonight's pages have the full squads.
SELECT public.sync_players_from_squads() AS players_written;

-- Verification:
--   SELECT team_id, count(*), max(updated_at)::date FROM players
--    WHERE team_id IN (SELECT id FROM teams WHERE league_id=39 AND is_active) GROUP BY 1 ORDER BY 1;
--   SELECT jobname, schedule FROM cron.job WHERE jobname='goaldigger-players-sync';
