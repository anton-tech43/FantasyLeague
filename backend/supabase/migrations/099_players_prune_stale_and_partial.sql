-- 099_players_prune_stale_and_partial.sql
-- Two holes in prune_departed_players() (096), found in the 2026-09-09 review.
--
-- 1. A January departure was immortal. The "no minutes" safety in 096 exempted
--    any player who had played for the club this season, so a man sold in
--    January with 400 minutes stayed in `players` under his old club until
--    July, and the Quiz kept asking "Who is this?" about him. The sync touches
--    updated_at for every player in the payload each morning, so a row that
--    has not been touched for 14 days has been out of the squad payload for
--    14 consecutive days. That is a departure, minutes or not. A single flaky
--    payload still cannot prune anyone who has played.
--
-- 2. A truncated payload would have pruned real players. The squad endpoint
--    has returned empty arrays (skipped since 084) but never, in the retained
--    window, a short non-empty list; if it ever does, a payload under 18
--    players is not a Premier League squad and is not to be judged on.

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
      AND jsonb_array_length(COALESCE(r.data->'response'->0->'players', '[]'::jsonb)) >= 18
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
      AND EXISTS (SELECT 1 FROM latest l WHERE l.team_id = pl.team_id)
      AND NOT EXISTS (
        SELECT 1 FROM in_payload ip
        WHERE ip.team_id = pl.team_id AND ip.api_player_id = pl.api_player_id
      )
      AND (COALESCE(pl.minutes, 0) = 0 OR pl.updated_at < now() - INTERVAL '14 days')
    RETURNING 1
  )
  SELECT count(*) INTO n FROM gone;
  RETURN n;
END;
$$;

COMMENT ON FUNCTION public.prune_departed_players() IS
  'Removes players rows for active clubs that are absent from the club''s latest '
  'full squad payload (18+ players) and either have no minutes this season or '
  'have been absent for 14 days. Runs after sync_players_from_squads().';

SELECT public.prune_departed_players() AS pruned_now;
