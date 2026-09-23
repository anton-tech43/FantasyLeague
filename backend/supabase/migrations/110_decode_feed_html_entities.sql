-- 110_decode_feed_html_entities.sql
-- API-Football HTML-escapes apostrophes in player names.
--
-- Found by the stale-data audit on 2026-09-23. `players.name` held
-- `N. O&apos;Reilly`, `M. O&apos;Riley`, `J. O&apos;Brien`, `D. O&apos;Shea`,
-- `L. O&apos;Nien` and `J. O&apos;Brien-Whitmarsh`. Traced to the source: the
-- live `/players/squads?team=50` response says `N. O&apos;Reilly` too, so this
-- is the feed, not our ingest. It is present in four of its payloads
-- (`api_football_squad`, `api_football_transfers`, `api_football_players_stats`
-- and the `mirror` source), which is why a single-surface fix is not enough.
--
-- Two things this breaks, neither of which fails loudly:
--
--   1. Anything that prints a player's name from this table. A goal by one of
--      the six would push a notification reading "N. O&apos;Reilly".
--   2. `post_team_page.sh`'s grounding guard, which checks every ones_to_know
--      player against the raw squad snapshot by surname. The routine writes
--      prose, so it spells the name `O'Reilly`; the snapshot says
--      `o&apos;reilly`; they do not match and the club's ENTIRE page payload is
--      rejected. None of the six is in an ones_to_know card today, so nothing
--      is blocked yet — this lands before one of them is picked, not after.
--
-- Decoded at ingest so `players` is clean for every reader. The raw payloads in
-- raw_fetch_logs are left exactly as the feed sent them: they are evidence.
-- `&apos;` is the only entity observed, but `&amp;` has to be decoded last or
-- it would corrupt a doubly-escaped `&amp;apos;`, so the order below matters.

CREATE OR REPLACE FUNCTION public.decode_feed_entities(txt text)
RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT replace(replace(replace(replace(replace(
           txt, '&apos;', ''''), '&#39;', ''''), '&quot;', '"'),
           '&lt;', '<'), '&amp;', '&')
$$;

COMMENT ON FUNCTION public.decode_feed_entities(text) IS
  'Undo API-Football''s HTML escaping of player names (mig 110). &amp; last.';

CREATE OR REPLACE FUNCTION public.sync_players_from_squads()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
           -- mig 110: the feed sends `N. O&apos;Reilly`. Decode here, once, so
           -- no reader has to know that.
           public.decode_feed_entities(p->>'name') AS name,
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
$function$;

-- Clean the rows already stored, including the inactive clubs the sync skips.
UPDATE public.players SET name = public.decode_feed_entities(name), updated_at = now()
 WHERE name <> public.decode_feed_entities(name);

-- Verification:
--   SELECT count(*) FROM players WHERE name LIKE '%&%';   -- 0
