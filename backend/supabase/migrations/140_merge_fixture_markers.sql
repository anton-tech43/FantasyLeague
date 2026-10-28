-- 140_merge_fixture_markers.sql  (bug hunt 2026-10-27)
--
-- match-watcher's state upsert wrote the whole briefs_fired array as it was
-- read at the start of the fixture. A tick that runs past a minute overlaps
-- the next one (the lease only stops two ticks in the same minute), and the
-- slower tick's upsert then wiped a marker the other had just claimed with
-- claim_fixture_marker (GOAL_PUSH:1-0, FT_PUSH) — whose claim then succeeded
-- again: the push went out twice.
--
-- Now the upsert leaves briefs_fired alone on an existing row, and this adds
-- the tick's markers and removes the ones it retired (a VAR-overturned goal),
-- in one atomic statement against the CURRENT array.
CREATE OR REPLACE FUNCTION public.merge_fixture_markers(
  p_fixture_id integer, p_add text[], p_remove text[] DEFAULT '{}'
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $$
  UPDATE public.match_status_state
     SET briefs_fired = (
       SELECT COALESCE(jsonb_agg(DISTINCT m), '[]'::jsonb)
       FROM (
         SELECT jsonb_array_elements_text(COALESCE(briefs_fired, '[]'::jsonb)) AS m
         UNION
         SELECT unnest(p_add)
       ) x
       WHERE m <> ALL (p_remove)
     )
   WHERE fixture_id = p_fixture_id;
$$;
REVOKE EXECUTE ON FUNCTION public.merge_fixture_markers(integer, text[], text[]) FROM PUBLIC, anon, authenticated;
