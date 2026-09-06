-- 082_device_timezone.sql
-- Per-device timezone so push copy can render kickoff times in the reader's own
-- zone (audit 2026-09, A5 follow-up). Until now every push used ONE fixed zone:
-- morning-push wrote London ("19:00 BST"), matchday-reminder wrote Stockholm.
-- iOS already renders in-app times device-locally; only the push text was fixed.
--
-- 1. device_tokens.timezone — IANA name, default Europe/London. Product call
--    (Anton, 2026-09-06): the app is marketed and PAID FOR in the UK; the ~20
--    existing devices are Swedish friends who will get the right time once the
--    app build that sends p_timezone ships. Until then unknown = London.
-- 2. register_device_token gains p_timezone (default London). The 5-arg
--    signature is DROPPED, not overloaded: PostgREST cannot disambiguate two
--    candidates that differ only by a defaulted parameter ("could not choose
--    the best candidate function"). Old app builds that omit p_timezone still
--    resolve to the 6-arg function via the default (London).
-- 3. Validation is a cheap shape check (Area/City[/Sub]); anything odd falls
--    back to London rather than raising, so a weird device never fails to
--    register. The Edge side guards Intl with try/catch as well.
--
-- Applied manually (schema_migrations only tracks 001–017, see A12).

ALTER TABLE device_tokens
  ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Europe/London';

DROP FUNCTION IF EXISTS public.register_device_token(text, text[], text[], integer, text);

CREATE OR REPLACE FUNCTION public.register_device_token(
  p_apns_token text,
  p_team_ids text[],
  p_country_ids text[],
  p_tier integer,
  p_apns_environment text,
  p_timezone text DEFAULT 'Europe/London'
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_tz text;
BEGIN
  IF p_apns_token IS NULL OR p_apns_token !~ '^[a-fA-F0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid apns_token';
  END IF;
  IF p_apns_environment IS NOT NULL
     AND p_apns_environment NOT IN ('development', 'production') THEN
    RAISE EXCEPTION 'invalid apns_environment';
  END IF;

  -- IANA shape: "Europe/Stockholm", "America/Argentina/Buenos_Aires", "Etc/GMT+1".
  -- Anything else → London (the paying market). Never raise: registration must not fail on tz.
  v_tz := CASE
    WHEN p_timezone ~ '^[A-Za-z_]+(/[A-Za-z0-9_+\-]+){1,2}$' AND length(p_timezone) <= 64
      THEN p_timezone
    ELSE 'Europe/London'
  END;

  INSERT INTO public.device_tokens AS dt (
    apns_token, team_id, country_id, team_ids, country_ids,
    tier, apns_environment, timezone, is_active, updated_at
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
    true, now()
  )
  ON CONFLICT (apns_token) DO UPDATE SET
    team_id          = EXCLUDED.team_id,
    country_id       = EXCLUDED.country_id,
    team_ids         = EXCLUDED.team_ids,
    country_ids      = EXCLUDED.country_ids,
    tier             = EXCLUDED.tier,
    apns_environment = EXCLUDED.apns_environment,
    timezone         = EXCLUDED.timezone,
    is_active        = true,
    updated_at       = now();
END;
$function$;

-- Grants do not survive DROP FUNCTION — restore the same set as before (mig 071).
-- CREATE FUNCTION also grants EXECUTE to PUBLIC by default; revoke it so the
-- surface stays exactly anon/authenticated/service_role (+ owner).
REVOKE EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text)
  TO anon, authenticated, service_role;

-- Verification:
--   SELECT column_name, column_default FROM information_schema.columns
--    WHERE table_name = 'device_tokens' AND column_name = 'timezone';
--   SELECT grantee FROM information_schema.routine_privileges WHERE routine_name = 'register_device_token';
--   -- shape check without touching a real device:
--   SELECT 'Europe/London' ~ '^[A-Za-z_]+(/[A-Za-z0-9_+\-]+){1,2}$', 'garbage;drop' ~ '^[A-Za-z_]+(/[A-Za-z0-9_+\-]+){1,2}$';
--   -- after the next app start on a device: SELECT timezone, count(*) FROM device_tokens GROUP BY 1;
