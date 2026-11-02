-- 156_la_token_client.sql
--
-- Live Activity tokens remember which app build and iOS version registered
-- them, read from the User-Agent header (no app change, so 2.2-2.4 report it
-- too). Broadcast-channel Live Activities need iOS 18 (Darwin 24); this tells
-- us how many followers can take them before the server relies on it
-- (docs/LIVE_ACTIVITY_PLAN.md). Darwin major: 23 = iOS 17, 24 = iOS 18,
-- 25 = iOS 26.
--
-- Also prunes the push-to-start tokens from Xcode builds (apns_environment
-- 'development'): 36 of 170 on 2026-11-02, skewing every rate. A developer
-- phone re-registers the next time the app is opened (Anton, 2026-11-03).

BEGIN;

ALTER TABLE public.live_activity_tokens
  ADD COLUMN IF NOT EXISTS user_agent text,
  ADD COLUMN IF NOT EXISTS app_build integer,
  ADD COLUMN IF NOT EXISTS darwin_major integer;

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

  INSERT INTO public.live_activity_tokens AS la (
    token, kind, fixture_id, country_id, country_ids, team_ids, apns_environment, is_active, updated_at,
    user_agent, app_build, darwin_major
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
    (substring(v_ua FROM 'Darwin/([0-9]{1,3})'))::int
  )
  ON CONFLICT (token) DO UPDATE SET
    kind             = EXCLUDED.kind,
    fixture_id       = EXCLUDED.fixture_id,
    country_id       = EXCLUDED.country_id,
    country_ids      = EXCLUDED.country_ids,
    team_ids         = EXCLUDED.team_ids,
    apns_environment = EXCLUDED.apns_environment,
    is_active        = true,
    updated_at       = now(),
    user_agent       = EXCLUDED.user_agent,
    app_build        = EXCLUDED.app_build,
    darwin_major     = EXCLUDED.darwin_major;
END;
$function$;

DELETE FROM public.live_activity_tokens WHERE apns_environment = 'development';

COMMIT;
