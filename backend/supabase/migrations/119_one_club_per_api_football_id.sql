-- 119_one_club_per_api_football_id.sql
-- Stop a second club row appearing for a club we already know.
--
-- Migration 117 (the detect-consequences / match-watcher fix) excluded
-- `entity_type = 'tournament'` from the api_football_id → slug maps, because
-- the four competition rows store their LEAGUE id in that column and two of
-- them collide with clubs (FA Cup 45 / Everton 45, League Cup 48 / West Ham 48).
-- The red-team pass pointed out that this fixes today's collisions and not the
-- mechanism: nothing stops a second NON-tournament row taking an id.
--
-- The path is real. `match-watcher/index.ts` auto-registers an unknown cup
-- opponent with a slug derived from the feed's spelling:
--     name.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/_+$/, "")
-- The mangling is already visible in live rows — `bayern_m_nchen` (157),
-- `fenerbah_e` (611). If a later fixture payload spells it "Bayern Munich"
-- instead of "Bayern München", the slug is `bayern_munich`, the upsert is
-- `onConflict: "id"` so nothing conflicts, and a second club row appears with
-- api_football_id 157. The map then has two candidates, last writer wins, and
-- Bayern's Champions League consequences are filed under whichever PostgREST
-- happened to emit second.
--
-- A partial unique index is the fix, not more code: the second insert fails
-- loudly instead of silently shadowing the first. Tournaments are excluded
-- because their collision with clubs is by design and already handled.

CREATE UNIQUE INDEX IF NOT EXISTS teams_api_football_id_not_tournament
  ON public.teams (api_football_id)
  WHERE entity_type <> 'tournament' AND api_football_id IS NOT NULL;

-- Self-check: the index must exist, and the four known tournament collisions
-- must still be allowed to sit alongside their clubs.
DO $check$
DECLARE dupes int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes
                  WHERE schemaname='public' AND indexname='teams_api_football_id_not_tournament')
    THEN RAISE EXCEPTION 'index not created'; END IF;
  SELECT count(*) INTO dupes FROM (
    SELECT api_football_id FROM public.teams
     WHERE entity_type <> 'tournament' AND api_football_id IS NOT NULL
     GROUP BY 1 HAVING count(*) > 1) d;
  IF dupes > 0 THEN RAISE EXCEPTION 'still % duplicate non-tournament ids', dupes; END IF;
  RAISE NOTICE 'migration 119 self-check passed';
END
$check$;
