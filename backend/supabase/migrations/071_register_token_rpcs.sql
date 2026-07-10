-- 071_register_token_rpcs.sql
-- SEC-1/2/3 (AUDIT_FINDINGS): close the anon read/tamper exposure on the token
-- tables. Today the iOS app registers via a direct PostgREST merge-duplicates
-- upsert, which REQUIRES anon SELECT + INSERT + UPDATE on device_tokens
-- (migration 030 documents that ON CONFLICT fails with 42501 without anon
-- SELECT). That blanket anon access lets anyone with the shipped publishable
-- key enumerate every device's apns_token + followed team/country (PII) and
-- PATCH any row (repoint follows).
--
-- Fix = move the write behind SECURITY DEFINER RPCs so anon needs only EXECUTE,
-- not table grants. Then anon SELECT/INSERT/UPDATE can be dropped (see
-- 072_drop_anon_token_access.sql — applied AFTER the RPC-using app build is
-- live, so shipped direct-upsert clients aren't broken).
--
-- These functions run as the definer (bypass RLS), validate input defensively,
-- and upsert one row per token (preserving the UNIQUE(apns_token)/UNIQUE(token)
-- one-row-per-device model). search_path is locked; EXECUTE is granted to anon.

-- device_tokens: full follow-set in one call (mirrors APIClient.registerToken).
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_apns_token       text,
  p_team_ids         text[],
  p_country_ids      text[],
  p_tier             int,
  p_apns_environment text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_apns_token IS NULL OR p_apns_token !~ '^[a-fA-F0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid apns_token';
  END IF;
  IF p_apns_environment IS NOT NULL
     AND p_apns_environment NOT IN ('development', 'production') THEN
    RAISE EXCEPTION 'invalid apns_environment';
  END IF;

  INSERT INTO public.device_tokens AS dt (
    apns_token, team_id, country_id, team_ids, country_ids,
    tier, apns_environment, is_active, updated_at
  )
  VALUES (
    p_apns_token,
    (CASE WHEN array_length(p_team_ids, 1) > 0 THEN p_team_ids[1] END),
    (CASE WHEN array_length(p_country_ids, 1) > 0 THEN p_country_ids[1] END),
    COALESCE(p_team_ids, ARRAY[]::text[]),
    COALESCE(p_country_ids, ARRAY[]::text[]),
    COALESCE(p_tier, 2),
    COALESCE(p_apns_environment, 'development'),
    true, now()
  )
  ON CONFLICT (apns_token) DO UPDATE SET
    team_id          = EXCLUDED.team_id,
    country_id       = EXCLUDED.country_id,
    team_ids         = EXCLUDED.team_ids,
    country_ids      = EXCLUDED.country_ids,
    tier             = EXCLUDED.tier,
    apns_environment = EXCLUDED.apns_environment,
    is_active        = true,
    updated_at       = now();
END;
$$;

-- live_activity_tokens: one push-to-start or update token, multi-country.
CREATE OR REPLACE FUNCTION public.register_la_token(
  p_token            text,
  p_kind             text,
  p_fixture_id       int,
  p_country_ids      text[],
  p_apns_environment text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_token IS NULL OR p_token !~ '^[a-fA-F0-9]{16,}$' THEN
    RAISE EXCEPTION 'invalid token';
  END IF;
  IF p_kind NOT IN ('push_to_start', 'update') THEN
    RAISE EXCEPTION 'invalid kind';
  END IF;
  IF p_apns_environment IS NOT NULL
     AND p_apns_environment NOT IN ('development', 'production') THEN
    RAISE EXCEPTION 'invalid apns_environment';
  END IF;

  INSERT INTO public.live_activity_tokens AS la (
    token, kind, fixture_id, country_id, country_ids, apns_environment, is_active, updated_at
  )
  VALUES (
    p_token, p_kind, p_fixture_id,
    (CASE WHEN array_length(p_country_ids, 1) > 0 THEN p_country_ids[1] END),
    COALESCE(p_country_ids, ARRAY[]::text[]),
    COALESCE(p_apns_environment, 'development'),
    true, now()
  )
  ON CONFLICT (token) DO UPDATE SET
    kind             = EXCLUDED.kind,
    fixture_id       = EXCLUDED.fixture_id,
    country_id       = EXCLUDED.country_id,
    country_ids      = EXCLUDED.country_ids,
    apns_environment = EXCLUDED.apns_environment,
    is_active        = true,
    updated_at       = now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], int, text) FROM public;
REVOKE EXECUTE ON FUNCTION public.register_la_token(text, text, int, text[], text) FROM public;
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], int, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_la_token(text, text, int, text[], text) TO anon, authenticated, service_role;
