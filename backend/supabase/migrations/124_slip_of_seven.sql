-- 124: a slip of up to seven lines.
--
-- The app now offers seven sayings for the game, not three, each one "Save
-- for the game" or "Ignore for now". save_match_calls refused more than three
-- picks; this raises the ceiling to seven and changes nothing else. The
-- function body is 117's with that one check edited.
--
-- CREATE OR REPLACE keeps the function's ACL, but the grants are restated so
-- this file says on its own who can call it (CLAUDE.md: every function names
-- FROM PUBLIC, anon, authenticated).

BEGIN;

CREATE OR REPLACE FUNCTION public.save_match_calls(
  p_apns_token text,
  p_fixture_id bigint,
  p_picks      jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_pick jsonb;
BEGIN
  IF p_apns_token IS NULL OR p_apns_token !~ '^[a-fA-F0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid apns_token';
  END IF;
  IF p_fixture_id IS NULL OR p_fixture_id <= 0 THEN
    RAISE EXCEPTION 'invalid fixture_id';
  END IF;
  IF p_picks IS NULL OR jsonb_typeof(p_picks) <> 'array' THEN
    RAISE EXCEPTION 'picks must be a json array';
  END IF;
  -- Seven lines for the game since 2026-10-02 (Anton: "save for the game"
  -- seven of them, like the seven words). match-watcher only ever uses the
  -- first pick that lands on a push it is sending anyway, so more picks never
  -- means more pushes.
  IF jsonb_array_length(p_picks) > 7 THEN
    RAISE EXCEPTION 'at most 7 picks';
  END IF;

  FOR v_pick IN SELECT * FROM jsonb_array_elements(p_picks) LOOP
    IF jsonb_typeof(v_pick) <> 'object' THEN
      RAISE EXCEPTION 'each pick must be a json object';
    END IF;
    -- Exactly {id, line, trigger}. An unknown key is refused rather than
    -- stored: this column is read back and rendered into a push, so it holds
    -- what the contract names and nothing a future reader has to wonder about.
    IF EXISTS (
      SELECT 1 FROM jsonb_object_keys(v_pick) AS k
       WHERE k NOT IN ('id', 'line', 'trigger')
    ) THEN
      RAISE EXCEPTION 'unexpected key in pick';
    END IF;
    IF jsonb_typeof(v_pick -> 'id') <> 'string'
       OR length(v_pick ->> 'id') = 0 OR length(v_pick ->> 'id') > 64 THEN
      RAISE EXCEPTION 'pick.id must be a string of 1..64 chars';
    END IF;
    -- 120 is the STORAGE cap and deliberately loose. The cap that matters is
    -- MAX_CALL_LINE in _shared/match-calls.ts, currently 50, which is what a
    -- line can be and still render inside the push body behind the longest
    -- possible scorer lead. A longer line is stored and then dropped at send
    -- time rather than truncated, so authoring belongs under 50; this check
    -- only stops the column being used as a text field.
    IF jsonb_typeof(v_pick -> 'line') <> 'string'
       OR length(v_pick ->> 'line') = 0 OR length(v_pick ->> 'line') > 120 THEN
      RAISE EXCEPTION 'pick.line must be a string of 1..120 chars';
    END IF;
    IF jsonb_typeof(v_pick -> 'trigger') <> 'object' THEN
      RAISE EXCEPTION 'pick.trigger must be a json object';
    END IF;
  END LOOP;

  -- One slip at a time: a new fixture replaces the old one, which is also what
  -- keeps match-calls.ts's stale-fixture guard from ever having much to do.
  UPDATE public.device_tokens
     SET match_calls = jsonb_build_object(
           'fixture_id', p_fixture_id,
           'picks',      p_picks,
           'picked_at',  now()
         )
   WHERE apns_token = p_apns_token;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'unknown device';
  END IF;
END;
$$;

-- FROM PUBLIC alone is not enough: anon and authenticated hold (held) an
-- EXPLICIT grant from Supabase's default privileges, which FROM PUBLIC does not
-- touch. That is the bug migrations 084, 095, 096 and 103 all shipped and 116
-- had to clean up. Name the roles.
REVOKE EXECUTE ON FUNCTION public.save_match_calls(text, bigint, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.save_match_calls(text, bigint, jsonb)
  TO anon, authenticated, service_role;

COMMIT;

-- Verification:
--   SELECT has_function_privilege('anon', 'public.save_match_calls(text,bigint,jsonb)', 'EXECUTE');  -- t
--   SELECT prosrc LIKE '%at most 7 picks%' FROM pg_proc WHERE proname = 'save_match_calls';     -- t
