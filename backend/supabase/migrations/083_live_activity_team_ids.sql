-- 083_live_activity_team_ids.sql
-- Live Activity push-to-start tokens can follow CLUBS, not only WC countries
-- (audit 2026-09, customer review P0: every live push and the Live Activity
-- were hard-gated to league 1 in match-watcher, so a PL follower got nothing
-- between the morning reminder and the FT article).
--
-- 1. live_activity_tokens.team_ids — the followed PL clubs, mirroring
--    device_tokens.team_ids. country_ids stays as is.
-- 2. register_la_token gains p_team_ids (default '{}'). The 5-arg signature is
--    DROPPED, not overloaded (PostgREST cannot disambiguate two candidates that
--    differ only by a defaulted parameter, same as mig 082). Old app builds
--    that omit p_team_ids still resolve via the default.
--
-- Applied manually (schema_migrations only tracks 001–017, see A12).

ALTER TABLE live_activity_tokens
  ADD COLUMN IF NOT EXISTS team_ids text[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_la_tokens_pts_team_ids
  ON live_activity_tokens USING gin (team_ids)
  WHERE kind = 'push_to_start' AND is_active;

DROP FUNCTION IF EXISTS public.register_la_token(text, text, integer, text[], text);

CREATE OR REPLACE FUNCTION public.register_la_token(
  p_token text,
  p_kind text,
  p_fixture_id integer,
  p_country_ids text[],
  p_apns_environment text,
  p_team_ids text[] DEFAULT '{}'
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    token, kind, fixture_id, country_id, country_ids, team_ids, apns_environment, is_active, updated_at
  )
  VALUES (
    p_token, p_kind, p_fixture_id,
    (CASE WHEN array_length(p_country_ids, 1) > 0 THEN p_country_ids[1] END),
    COALESCE(p_country_ids, ARRAY[]::text[]),
    COALESCE(p_team_ids, ARRAY[]::text[]),
    COALESCE(p_apns_environment, 'development'),
    true, now()
  )
  ON CONFLICT (token) DO UPDATE SET
    kind             = EXCLUDED.kind,
    fixture_id       = EXCLUDED.fixture_id,
    country_id       = EXCLUDED.country_id,
    country_ids      = EXCLUDED.country_ids,
    team_ids         = EXCLUDED.team_ids,
    apns_environment = EXCLUDED.apns_environment,
    is_active        = true,
    updated_at       = now();
END;
$function$;

-- Grants do not survive DROP FUNCTION — restore the same set (anon,
-- authenticated, service_role) and revoke the implicit PUBLIC grant.
REVOKE EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[])
  TO anon, authenticated, service_role;

-- Verification:
--   \d live_activity_tokens                       -- team_ids text[] NOT NULL DEFAULT '{}'
--   SELECT grantee FROM information_schema.routine_privileges WHERE routine_name='register_la_token';
--   SELECT register_la_token('00112233445566778899aabbccddeeff','push_to_start',NULL,'{}','development','{arsenal}');
--   SELECT team_ids FROM live_activity_tokens WHERE token='00112233445566778899aabbccddeeff'; then DELETE that row.
