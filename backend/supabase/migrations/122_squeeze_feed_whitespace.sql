-- 122_squeeze_feed_whitespace.sql
--
-- API-Football occasionally sends a name with a doubled space — `J.  McGinn`,
-- `Ilyas  Ansah`. Nothing renders differently, so it went unnoticed for as long
-- as the rows have existed. It matters because every check that reconciles a
-- name across two surfaces joins on the string: the `ones_to_know` relevance
-- query added to the stale-data-audit skill on 2026-09-30 reported McGinn as
-- unmatched, and team-page-generator's new pre-selection guard would have
-- logged a substitution warning for a pick that was in fact correct and top of
-- his squad on minutes. A check that cries wolf gets ignored, which is the
-- failure this whole day's work has been about.
--
-- `decode_feed_entities()` (migration 110) is already the one place every name
-- passes through on ingest, so the squeeze belongs there rather than in each
-- consumer. Collapsing runs of whitespace and trimming is safe for a personal
-- name: no name distinguishes itself from another by a doubled space.

CREATE OR REPLACE FUNCTION public.decode_feed_entities(txt text)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE STRICT
  SET search_path TO ''
AS $function$
  SELECT btrim(regexp_replace(
           replace(replace(replace(replace(replace(
             txt, '&apos;', ''''), '&#39;', ''''), '&quot;', '"'),
             '&lt;', '<'), '&amp;', '&'),
           '\s+', ' ', 'g'))
$function$;

-- Every function is born with an implicit EXECUTE to PUBLIC that no
-- ALTER DEFAULT PRIVILEGES on this database removes (tested both documented
-- forms, 2026-09-24), so CREATE OR REPLACE re-opens nothing but the revoke is
-- restated here because it costs nothing and the next reader should see it.
REVOKE EXECUTE ON FUNCTION public.decode_feed_entities(text) FROM PUBLIC, anon, authenticated;

-- Repair the rows already stored. The squad sync would heal these on its next
-- run now that the function squeezes, but leaving them wrong until 05:30
-- tomorrow would leave the new audit query red overnight for no reason.
UPDATE public.players
   SET name = public.decode_feed_entities(name)
 WHERE name <> public.decode_feed_entities(name);

-- Self-check: no name may carry a doubled, leading or trailing space, and the
-- two known cases must now read correctly.
DO $$
DECLARE
  bad int;
  mcginn text;
BEGIN
  SELECT count(*) INTO bad FROM public.players WHERE name ~ '\s\s|^\s|\s$';
  IF bad <> 0 THEN
    RAISE EXCEPTION 'migration 122: % player name(s) still carry stray whitespace', bad;
  END IF;

  SELECT name INTO mcginn FROM public.players
   WHERE team_id = 'aston_villa' AND name LIKE '%McGinn%';
  IF mcginn IS DISTINCT FROM 'J. McGinn' THEN
    RAISE EXCEPTION 'migration 122: expected "J. McGinn", found %', quote_nullable(mcginn);
  END IF;

  IF public.decode_feed_entities('N. O&apos;Reilly') <> 'N. O''Reilly' THEN
    RAISE EXCEPTION 'migration 122: entity decoding regressed';
  END IF;
  IF public.decode_feed_entities('  a   b  ') <> 'a b' THEN
    RAISE EXCEPTION 'migration 122: whitespace squeeze did not apply';
  END IF;
END $$;
