-- 169: a per-token call limit on the three RPCs that rewrite a known token's
-- row (bug hunt 2026-11-03 A-C3, rpc/save_match_calls/no-call-rate-limit).
--
-- Before: save_match_calls and re-registration of a known token were uncapped.
-- One made-up token (inside 168's pool ceiling) could rewrite
-- device_tokens.match_calls (up to 4 KB, TOASTed) in a loop: WAL, TOAST and a
-- dead tuple per call on the table every push reads.
--
-- Real rates, measured 2026-11-04 (read-only; there is no per-call log, so
-- these are the closest proxies):
--   * re-registration happens on a follow/tier/timezone change only (current
--     builds); follow_changed peaks at 1 per install-hour. app_opened peaks
--     at 173 per install-hour (a screenshot harness), the ceiling if an old
--     build re-registered on every launch.
--   * save_match_calls fires once per pick change; a slip is at most 7 picks,
--     and only 3 rows have ever held a slip.
--   * LA tokens re-register when iOS rotates them, a handful per match.
--
-- Now, per token, per fixed one-hour window, counting WRITES only:
--   * under 100 writes: unchanged behaviour (>= 10x any real rate above).
--   * from 100: a call whose payload equals what the row already holds is
--     skipped silently (nothing would change but a timestamp already set this
--     hour), so an old build re-registering on every launch never errors.
--   * from 300: a call that would change the row is refused. No real phone
--     changes its picks or follows 300 times an hour.
-- Skipped calls are not counted: they cost one index read and write nothing.
--
-- device_tokens shares one counter between save_match_calls and
-- register_device_token (same row). The counter rides in the UPDATE the call
-- makes anyway, so a normal call writes no extra tuple.
--
-- ponytail: fixed window, so a caller can reach ~2x the limit across an hour
-- boundary. Still bounded; a sliding window needs a call log, not two columns.
-- No new functions: the three RPCs are replaced in place with their live
-- bodies (129/156/168) plus the limit, and keep their grants.

BEGIN;

ALTER TABLE public.device_tokens
  ADD COLUMN IF NOT EXISTS rpc_window_start timestamptz,
  ADD COLUMN IF NOT EXISTS rpc_calls integer NOT NULL DEFAULT 0;
ALTER TABLE public.live_activity_tokens
  ADD COLUMN IF NOT EXISTS rpc_window_start timestamptz,
  ADD COLUMN IF NOT EXISTS rpc_calls integer NOT NULL DEFAULT 0;

-- save_match_calls ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_match_calls(p_apns_token text, p_fixture_id bigint, p_picks jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_pick  jsonb;
  -- 169: per-token limits, see the header.
  c_skip_identical CONSTANT integer := 100;
  c_refuse         CONSTANT integer := 300;
  v_calls integer;
  v_same  boolean;
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
  -- 129: the whole slip. The largest real one is ~1.2k (7 x 171 chars).
  IF length(p_picks::text) > 4096 THEN
    RAISE EXCEPTION 'picks too large';
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
    -- 129: the largest real trigger is 76 chars.
    IF length((v_pick -> 'trigger')::text) > 512 THEN
      RAISE EXCEPTION 'pick.trigger too large';
    END IF;
  END LOOP;

  -- 169: per-token limit.
  SELECT CASE WHEN dt.rpc_window_start > now() - interval '1 hour' THEN dt.rpc_calls ELSE 0 END,
         COALESCE(dt.match_calls -> 'fixture_id' = to_jsonb(p_fixture_id)
                  AND dt.match_calls -> 'picks' = p_picks, false)
    INTO v_calls, v_same
    FROM public.device_tokens dt
   WHERE dt.apns_token = p_apns_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'unknown device';
  END IF;
  IF v_calls >= c_skip_identical AND v_same THEN
    RETURN;  -- already saved, nothing to change
  END IF;
  IF v_calls >= c_refuse THEN
    RAISE EXCEPTION 'too many calls for this device, try again later';
  END IF;

  -- One slip at a time: a new fixture replaces the old one, which is also what
  -- keeps match-calls.ts's stale-fixture guard from ever having much to do.
  UPDATE public.device_tokens
     SET match_calls = jsonb_build_object(
           'fixture_id', p_fixture_id,
           'picks',      p_picks,
           'picked_at',  now()
         ),
         rpc_calls        = v_calls + 1,
         rpc_window_start = CASE WHEN v_calls = 0 THEN now() ELSE rpc_window_start END
   WHERE apns_token = p_apns_token;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'unknown device';
  END IF;
END;
$function$;

-- register_device_token -----------------------------------------------------
CREATE OR REPLACE FUNCTION public.register_device_token(p_apns_token text, p_team_ids text[], p_country_ids text[], p_tier integer, p_apns_environment text, p_timezone text DEFAULT 'Europe/London'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tz text;
  -- 169: per-token limits, see the header.
  c_skip_identical CONSTANT integer := 100;
  c_refuse         CONSTANT integer := 300;
  v_calls integer;
  v_same  boolean;
BEGIN
  IF p_apns_token IS NULL OR p_apns_token !~ '^[a-fA-F0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid apns_token';
  END IF;
  IF p_apns_environment IS NOT NULL
     AND p_apns_environment NOT IN ('development', 'production') THEN
    RAISE EXCEPTION 'invalid apns_environment';
  END IF;

  -- 129: up to 2 clubs and 2 countries, each a slug we hold in teams.
  IF COALESCE(array_ndims(p_team_ids), 1) > 1 OR COALESCE(array_ndims(p_country_ids), 1) > 1
     OR cardinality(COALESCE(p_team_ids, ARRAY[]::text[])) > 2
     OR cardinality(COALESCE(p_country_ids, ARRAY[]::text[])) > 2 THEN
    RAISE EXCEPTION 'at most 2 team_ids and 2 country_ids';
  END IF;
  IF EXISTS (
    SELECT 1
      FROM unnest(COALESCE(p_team_ids, ARRAY[]::text[]) || COALESCE(p_country_ids, ARRAY[]::text[])) AS x(id)
     WHERE x.id IS NULL
        OR x.id !~ '^[a-z_]{2,32}$'
        OR NOT EXISTS (SELECT 1 FROM public.teams t WHERE t.id = x.id)
  ) THEN
    RAISE EXCEPTION 'unknown team or country id';
  END IF;

  -- IANA shape: "Europe/Stockholm", "America/Argentina/Buenos_Aires", "Etc/GMT+1".
  -- Anything else → London (the paying market). Never raise: registration must not fail on tz.
  v_tz := CASE
    WHEN p_timezone ~ '^[A-Za-z_]+(/[A-Za-z0-9_+\-]+){1,2}$' AND length(p_timezone) <= 64
      THEN p_timezone
    ELSE 'Europe/London'
  END;

  -- 169: per-token limit on a known token. "Same" means the upsert below
  -- would change nothing but updated_at.
  SELECT CASE WHEN dt.rpc_window_start > now() - interval '1 hour' THEN dt.rpc_calls ELSE 0 END,
         dt.team_ids = COALESCE(p_team_ids, ARRAY[]::text[])
           AND dt.country_ids = COALESCE(p_country_ids, ARRAY[]::text[])
           AND dt.tier = COALESCE(p_tier, 2)
           AND dt.apns_environment = COALESCE(p_apns_environment, 'development')
           AND dt.timezone IS NOT DISTINCT FROM v_tz
           AND dt.is_active = NOT COALESCE(COALESCE(p_apns_environment, 'development') = ANY (dt.bad_token_envs), false)
    INTO v_calls, v_same
    FROM public.device_tokens dt
   WHERE dt.apns_token = p_apns_token;
  IF FOUND THEN
    IF v_calls >= c_skip_identical AND COALESCE(v_same, false) THEN
      RETURN;
    END IF;
    IF v_calls >= c_refuse THEN
      RAISE EXCEPTION 'too many calls for this device, try again later';
    END IF;
  END IF;

  INSERT INTO public.device_tokens AS dt (
    apns_token, team_id, country_id, team_ids, country_ids,
    tier, apns_environment, timezone, is_active, updated_at,
    rpc_window_start, rpc_calls
  )
  VALUES (
    p_apns_token,
    (CASE WHEN array_length(p_team_ids, 1) > 0 THEN p_team_ids[1] END),
    (CASE WHEN array_length(p_country_ids, 1) > 0 THEN p_country_ids[1] END),
    COALESCE(p_team_ids, ARRAY[]::text[]),
    COALESCE(p_country_ids, ARRAY[]::text[]),
    COALESCE(p_tier, 2),
    COALESCE(p_apns_environment, 'development'),
    v_tz,
    true, now(),
    now(), 1
  )
  ON CONFLICT (apns_token) DO UPDATE SET
    team_id          = EXCLUDED.team_id,
    country_id       = EXCLUDED.country_id,
    team_ids         = EXCLUDED.team_ids,
    country_ids      = EXCLUDED.country_ids,
    tier             = EXCLUDED.tier,
    apns_environment = EXCLUDED.apns_environment,
    timezone         = EXCLUDED.timezone,
    -- CHANGED (168): never back on in an environment APNs called it bad in.
    is_active        = NOT COALESCE(EXCLUDED.apns_environment = ANY (dt.bad_token_envs), false),
    updated_at       = now(),
    -- 169
    rpc_calls        = CASE WHEN dt.rpc_window_start > now() - interval '1 hour' THEN dt.rpc_calls + 1 ELSE 1 END,
    rpc_window_start = CASE WHEN dt.rpc_window_start > now() - interval '1 hour' THEN dt.rpc_window_start ELSE now() END;
END;
$function$;

-- register_la_token ---------------------------------------------------------
CREATE OR REPLACE FUNCTION public.register_la_token(p_token text, p_kind text, p_fixture_id integer, p_country_ids text[], p_apns_environment text, p_team_ids text[] DEFAULT '{}'::text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  -- 156: which build and iOS sent this token, from the User-Agent PostgREST
  -- passes on ("GoalDigger/18 CFNetwork/... Darwin/24.6.0"; Darwin 24 is
  -- iOS 18). Needed to know who can take broadcast-channel Live Activities
  -- (iOS 18+). Never allowed to fail a registration.
  v_ua text;
  -- 169: per-token limits, see the header.
  c_skip_identical CONSTANT integer := 100;
  c_refuse         CONSTANT integer := 300;
  v_calls integer;
  v_same  boolean;
BEGIN
  BEGIN
    v_ua := left(current_setting('request.headers', true)::json->>'user-agent', 200);
  EXCEPTION WHEN others THEN
    v_ua := NULL;
  END;

  -- 129: capped. Production LA tokens are 160-256 hex chars. length(), not
  -- {16,512}: PostgreSQL refuses a regex repetition count above 255, and the
  -- error would fail every registration, not just the long ones.
  IF p_token IS NULL OR p_token !~ '^[a-fA-F0-9]+$'
     OR length(p_token) NOT BETWEEN 16 AND 512 THEN
    RAISE EXCEPTION 'invalid token';
  END IF;
  IF p_kind NOT IN ('push_to_start', 'update') THEN
    RAISE EXCEPTION 'invalid kind';
  END IF;
  IF p_apns_environment IS NOT NULL
     AND p_apns_environment NOT IN ('development', 'production') THEN
    RAISE EXCEPTION 'invalid apns_environment';
  END IF;

  -- 129: same follow-set guard as register_device_token.
  IF COALESCE(array_ndims(p_team_ids), 1) > 1 OR COALESCE(array_ndims(p_country_ids), 1) > 1
     OR cardinality(COALESCE(p_team_ids, ARRAY[]::text[])) > 2
     OR cardinality(COALESCE(p_country_ids, ARRAY[]::text[])) > 2 THEN
    RAISE EXCEPTION 'at most 2 team_ids and 2 country_ids';
  END IF;
  IF EXISTS (
    SELECT 1
      FROM unnest(COALESCE(p_team_ids, ARRAY[]::text[]) || COALESCE(p_country_ids, ARRAY[]::text[])) AS x(id)
     WHERE x.id IS NULL
        OR x.id !~ '^[a-z_]{2,32}$'
        OR NOT EXISTS (SELECT 1 FROM public.teams t WHERE t.id = x.id)
  ) THEN
    RAISE EXCEPTION 'unknown team or country id';
  END IF;

  -- 169: per-token limit on a known token, as in register_device_token.
  SELECT CASE WHEN la.rpc_window_start > now() - interval '1 hour' THEN la.rpc_calls ELSE 0 END,
         la.kind = p_kind
           AND la.fixture_id IS NOT DISTINCT FROM p_fixture_id
           AND la.country_ids = COALESCE(p_country_ids, ARRAY[]::text[])
           AND la.team_ids = COALESCE(p_team_ids, ARRAY[]::text[])
           AND la.apns_environment = COALESCE(p_apns_environment, 'development')
           AND la.user_agent IS NOT DISTINCT FROM v_ua
           AND la.is_active = NOT COALESCE(COALESCE(p_apns_environment, 'development') = ANY (la.bad_token_envs), false)
    INTO v_calls, v_same
    FROM public.live_activity_tokens la
   WHERE la.token = p_token;
  IF FOUND THEN
    IF v_calls >= c_skip_identical AND COALESCE(v_same, false) THEN
      RETURN;
    END IF;
    IF v_calls >= c_refuse THEN
      RAISE EXCEPTION 'too many calls for this token, try again later';
    END IF;
  END IF;

  INSERT INTO public.live_activity_tokens AS la (
    token, kind, fixture_id, country_id, country_ids, team_ids, apns_environment, is_active, updated_at,
    user_agent, app_build, darwin_major, rpc_window_start, rpc_calls
  )
  VALUES (
    p_token, p_kind, p_fixture_id,
    (CASE WHEN array_length(p_country_ids, 1) > 0 THEN p_country_ids[1] END),
    COALESCE(p_country_ids, ARRAY[]::text[]),
    COALESCE(p_team_ids, ARRAY[]::text[]),
    COALESCE(p_apns_environment, 'development'),
    true, now(),
    v_ua,
    (substring(v_ua FROM '^GoalDigger/([0-9]{1,6})'))::int,
    (substring(v_ua FROM 'Darwin/([0-9]{1,3})'))::int,
    now(), 1
  )
  ON CONFLICT (token) DO UPDATE SET
    kind             = EXCLUDED.kind,
    fixture_id       = EXCLUDED.fixture_id,
    country_id       = EXCLUDED.country_id,
    country_ids      = EXCLUDED.country_ids,
    team_ids         = EXCLUDED.team_ids,
    apns_environment = EXCLUDED.apns_environment,
    -- CHANGED (168): never back on in an environment APNs called it bad in.
    is_active        = NOT COALESCE(EXCLUDED.apns_environment = ANY (la.bad_token_envs), false),
    updated_at       = now(),
    user_agent       = EXCLUDED.user_agent,
    app_build        = EXCLUDED.app_build,
    darwin_major     = EXCLUDED.darwin_major,
    -- 169
    rpc_calls        = CASE WHEN la.rpc_window_start > now() - interval '1 hour' THEN la.rpc_calls + 1 ELSE 1 END,
    rpc_window_start = CASE WHEN la.rpc_window_start > now() - interval '1 hour' THEN la.rpc_window_start ELSE now() END;
END;
$function$;

-- CREATE OR REPLACE keeps the existing grants; restated so the file says it.
REVOKE EXECUTE ON FUNCTION public.save_match_calls(text, bigint, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.save_match_calls(text, bigint, jsonb) TO anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text) TO anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[]) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification (run 2026-11-04). Rolled-back test first: a new token, 100
-- writes, identical save and registration skipped without counting, a changed
-- registration still landing, writes to 300, the 301st refused, identical at
-- 300 still silent, a window older than an hour resetting to 1, a NULL window
-- (every existing row) counting from 1, and the same for an LA token. Then
-- applied; anon keeps EXECUTE on the five app RPCs:
--   save_match_calls, register_device_token, register_la_token, log_events,
--   delete_app_events  -- all t (has_function_privilege)
