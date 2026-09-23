-- 113_match_calls.sql — "Called it": store the three lines she picked before kickoff.
--
-- She picks up to three lines from her slip; the goal / half-time / full-time
-- push that was going out anyway tells her when one of them landed. The app
-- never asks whether she actually said it.
--
-- ONE COLUMN, NOT A NEW TABLE (CALLED_IT_CONTRACT.md, contract 2). `delete-my-data`
-- already deletes the device_tokens row; putting the picks on that row means it
-- keeps working with no change and no second place to forget.
--
-- THE STORED PICK CARRIES ITS OWN TEXT. lingo.json ships in the binary and the
-- server has no copy of it, so `line` travels with the pick and the push can be
-- rendered from this row alone. That is also why `line` is capped here: it is
-- the only place the text is ever validated.
--
-- Write path is a SECURITY DEFINER RPC, never a table upsert, for the same
-- reason register_device_token is one (071, SEC-1/2): anon holds no SELECT on
-- device_tokens since 106, so an ON CONFLICT upsert would fail with 42501, and
-- granting the table back would re-open the PII leak 106 closed.
--
-- Migration 116 revoked the default EXECUTE grant on new functions in `public`,
-- so a new RPC does NOT come out callable from the app. The explicit GRANT at
-- the bottom is what makes this one callable, exactly as 116 instructs.

BEGIN;

ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS match_calls JSONB;

COMMENT ON COLUMN device_tokens.match_calls IS
  '"Called it" slip for ONE fixture: {fixture_id, picks:[{id,line,trigger}], picked_at}. '
  'Written only by save_match_calls(). Read by match-watcher via _shared/match-calls.ts, '
  'which resolves a stale fixture_id to nothing.';

-- Save (or replace) this device's slip for one fixture.
--
-- Deliberately NOT an upsert: an unknown token is an error, not an invitation
-- to create a row. A device that has never registered has no follows and no
-- APNs environment, so a row created here could never receive a push anyway,
-- and accepting one would let anybody mint device_tokens rows with the
-- publishable key.
--
-- Validation is strict and total, because this is the trust boundary: the
-- caller is the shipped anon key, and everything it sends is hostile until
-- proven otherwise. An empty array is allowed and means "she cleared her slip".
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
  -- One banker, one likely, one longshot. Three is the slip, and the ceiling.
  IF jsonb_array_length(p_picks) > 3 THEN
    RAISE EXCEPTION 'at most 3 picks';
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
    -- 120 is the storage cap, not the display cap: appendCallLine measures the
    -- RENDERED push body and drops her line rather than overflow it.
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
--   -- callable by the shipped key, and the table still is not readable by it
--   SELECT has_function_privilege('anon', 'public.save_match_calls(text,bigint,jsonb)', 'EXECUTE');  -- t
--   SELECT has_table_privilege('anon', 'public.device_tokens', 'SELECT');                            -- f
--   -- an unknown token is refused rather than inserted
--   SELECT save_match_calls(repeat('a', 64), 1, '[]'::jsonb);  -- ERROR: unknown device
