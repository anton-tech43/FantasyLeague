-- 096_players_prune_departed.sql
-- The squad sync only ever added (2026-09-09).
--
-- sync_players_from_squads() (084, 095) upserts every player in the latest
-- squad payload and never deletes, so a man who left in the summer stays in
-- `players` under his old club for ever. Arsenal had 39 rows against a 31-man
-- payload: Gabriel Jesus, Nwaneri, Fábio Vieira, Martinelli and four academy
-- names, all with updated_at from July or the first days of September. The
-- Quiz now builds "Who is this?" from this table, and a confident question
-- about a man who plays for someone else is worse than no question.
--
-- Rule: for each active club, a row is pruned when the player is NOT in that
-- club's latest non-empty squad payload AND has no recorded minutes for the
-- club this season. The minutes clause is the safety: one flaky payload
-- (API-Football's nightly cache refresh returns empty arrays for a few
-- minutes, and the sync already skips those) must never drop a player who
-- demonstrably played for the club last week.
--
-- Wrapped as its own function and appended to the existing 05:30 cron, so the
-- order stays: sync squads, then prune.

CREATE OR REPLACE FUNCTION public.prune_departed_players()
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
  in_payload AS (
    SELECT l.team_id, (p->>'id')::int AS api_player_id
    FROM latest l, jsonb_array_elements(l.data->'response'->0->'players') p
    WHERE p->>'id' ~ '^[0-9]+$'
  ),
  gone AS (
    DELETE FROM public.players pl
    USING public.teams t
    WHERE t.id = pl.team_id
      AND t.is_active
      -- Only clubs whose payload we actually hold: no payload, no judgement.
      AND EXISTS (SELECT 1 FROM latest l WHERE l.team_id = pl.team_id)
      AND NOT EXISTS (
        SELECT 1 FROM in_payload ip
        WHERE ip.team_id = pl.team_id AND ip.api_player_id = pl.api_player_id
      )
      AND COALESCE(pl.minutes, 0) = 0
    RETURNING 1
  )
  SELECT count(*) INTO n FROM gone;
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.prune_departed_players() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.prune_departed_players() TO service_role;

COMMENT ON FUNCTION public.prune_departed_players() IS
  'Removes players rows for active clubs that are absent from the club''s latest '
  'squad payload and have no minutes this season. Runs after '
  'sync_players_from_squads() so a departed player does not linger under his old club.';

-- Chain it onto the existing daily squad sync (084: 05:30 UTC).
SELECT cron.unschedule('goaldigger-players-sync')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-players-sync');
SELECT cron.schedule(
  'goaldigger-players-sync',
  '30 5 * * *',
  $$SELECT public.sync_players_from_squads(); SELECT public.prune_departed_players();$$
);

-- Run once now.
SELECT public.prune_departed_players() AS pruned_now;
