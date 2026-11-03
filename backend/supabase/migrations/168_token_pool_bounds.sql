-- 168: the push-token pool gets a bound again, a dead token stays dead, and
-- token volume pages Anton within the hour (bug hunt 2026-11-03, regression
-- of A-C2: rpc/register-tokens/global-cap-lockout-unbounded-pool/regression).
--
-- 160 removed 129's per-hour refusal (it locked real installs out) and put
-- nothing in its place:
--   * no bound at all: with the key in the binary, an anon caller could add
--     tokens without limit, and every junk follower of her club sits in the
--     same fan-out as her phone (PUSH_CONCURRENCY 100, 400 s wall clock);
--   * APNs' BadDeviceToken deactivated a junk token, and the next call to
--     register_* set is_active = true again, uncounted, every time;
--   * the only alarm was a pipeline_health row nothing reads in real time.
-- All three reproduced in a rolled-back transaction before this migration.
--
-- Now:
--   ONE   a ceiling on ACTIVE tokens, 20 000 device and 50 000 Live Activity
--         (today 92 and 134; real peaks 10 and 43 new a day, so ~200x and
--         ~370x today). Past it a new token or a re-activation is refused:
--         at that size it is an attack, not a launch, and the alarm below
--         has already fired. A token already active always passes, so a
--         phone that is already registered keeps updating its follows.
--   TWO   bad_token_envs: the APNs environments in which APNs answered
--         BadDeviceToken for this token (written by the senders through
--         mark_tokens_bad). register_* keeps such a token inactive in that
--         environment. Apple never makes a BadDeviceToken valid again in the
--         same environment, and a reinstall gets a new token, so a real phone
--         loses nothing; one whose row carried the wrong environment still
--         comes back by registering with the right one. Unregistered (410) is
--         NOT recorded: Apple's rule is that a token re-registered after the
--         410 is valid again, and junk tokens never get a 410. Neither is
--         DeviceTokenNotForTopic: that one is also what a wrong topic on OUR
--         side would produce for every real token.
--         Recovery if a sender bug ever marks real tokens:
--           UPDATE device_tokens SET bad_token_envs = '{}';  (same for LA)
--   THREE check_token_volume(), hourly: pushes the dev phone through
--         client-error-alert (148's path) when new tokens in the last hour
--         pass the warn line or the active pool passes half the ceiling. At
--         most once per 6 h.
--
-- ponytail: the ceiling is global, so a flood that reaches it does lock new
-- installs out, at a size that is an incident anyway. The upgrade is a
-- per-IP cap once Anton confirms x-forwarded-for is set by Supabase's gateway.

BEGIN;

-- TWO (columns first: the triggers and RPCs below read them) ---------------
ALTER TABLE public.device_tokens
  ADD COLUMN IF NOT EXISTS bad_token_envs text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.live_activity_tokens
  ADD COLUMN IF NOT EXISTS bad_token_envs text[] NOT NULL DEFAULT '{}';

-- Called by the senders (service role) with the tokens APNs answered
-- BadDeviceToken and the environment each was sent to. Marks only a row still
-- in that environment, so a phone that re-registered in the other one mid-send
-- is not marked there.
CREATE OR REPLACE FUNCTION public.mark_tokens_bad(
  p_table  text,
  p_tokens text[],
  p_envs   text[]
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  n integer;
BEGIN
  IF cardinality(p_tokens) IS DISTINCT FROM cardinality(p_envs) THEN
    RAISE EXCEPTION 'p_tokens and p_envs must be the same length';
  END IF;
  IF p_table = 'device_tokens' THEN
    UPDATE public.device_tokens d
       SET is_active = false, updated_at = now(),
           bad_token_envs = CASE WHEN d.apns_environment = ANY (d.bad_token_envs)
                                 THEN d.bad_token_envs
                                 ELSE d.bad_token_envs || d.apns_environment END
      FROM unnest(p_tokens, p_envs) AS b(token, env)
     WHERE d.apns_token = b.token AND d.apns_environment = b.env;
  ELSIF p_table = 'live_activity_tokens' THEN
    UPDATE public.live_activity_tokens l
       SET is_active = false, updated_at = now(),
           bad_token_envs = CASE WHEN l.apns_environment = ANY (l.bad_token_envs)
                                 THEN l.bad_token_envs
                                 ELSE l.bad_token_envs || l.apns_environment END
      FROM unnest(p_tokens, p_envs) AS b(token, env)
     WHERE l.token = b.token AND l.apns_environment = b.env;
  ELSE
    RAISE EXCEPTION 'unknown table %', p_table;
  END IF;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_tokens_bad(text, text[], text[]) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_tokens_bad(text, text[], text[]) TO service_role;

-- ONE: the ceiling, in 160's triggers -------------------------------------
-- The ceiling counts active rows on every new registration; without these
-- the count reads every row, inactive ones included (seq scan), which went
-- quadratic in the rolled-back test.
CREATE INDEX IF NOT EXISTS idx_device_tokens_active ON public.device_tokens (id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_la_tokens_active     ON public.live_activity_tokens (id) WHERE is_active;

CREATE OR REPLACE FUNCTION public.check_token_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    warn_per_hour  CONSTANT INTEGER := 25;
    alarm_per_hour CONSTANT INTEGER := 1000;   -- 129's hard cap, now a log line
    max_active     CONSTANT INTEGER := 20000;  -- CHANGED (168): ~200x today
    v_active       BOOLEAN;
    v_exists       BOOLEAN;
    recent         INTEGER;
BEGIN
    SELECT is_active INTO v_active FROM public.device_tokens WHERE apns_token = NEW.apns_token;
    v_exists := FOUND;
    -- A token already active is not new volume (the RPC's ON CONFLICT upsert).
    IF v_exists AND v_active IS TRUE THEN
        RETURN NEW;
    END IF;

    -- CHANGED (168): new or re-activated, it must fit under the ceiling.
    IF (SELECT count(*) FROM (SELECT 1 FROM public.device_tokens
         WHERE is_active LIMIT max_active) s) >= max_active THEN
        RAISE EXCEPTION 'device_tokens ceiling: % active tokens (migration 168)', max_active;
    END IF;
    IF v_exists THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO recent FROM (
        SELECT 1 FROM public.device_tokens
         WHERE created_at > now() - interval '1 hour'
         LIMIT alarm_per_hour + 1) s;

    IF recent = warn_per_hour OR recent = alarm_per_hour THEN
        -- Best effort. A failure to log must never fail a registration.
        BEGIN
            INSERT INTO public.pipeline_health (stage, status, message, target)
            VALUES ('token_register',
                    CASE WHEN recent >= alarm_per_hour THEN 'failure' ELSE 'partial' END,
                    format('%s device_tokens rows in the last hour (warn at %s, alarm at %s; refused only past %s active since 168)',
                           recent, warn_per_hour, alarm_per_hour, max_active),
                    'rate_limit');
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_la_token_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    -- Twice device_tokens': an install vends one push-to-start token and one
    -- update token per live match it shows.
    warn_per_hour  CONSTANT INTEGER := 50;
    alarm_per_hour CONSTANT INTEGER := 2000;
    max_active     CONSTANT INTEGER := 50000;  -- CHANGED (168): ~370x today
    v_active       BOOLEAN;
    v_exists       BOOLEAN;
    recent         INTEGER;
BEGIN
    SELECT is_active INTO v_active FROM public.live_activity_tokens WHERE token = NEW.token;
    v_exists := FOUND;
    IF v_exists AND v_active IS TRUE THEN
        RETURN NEW;
    END IF;

    -- CHANGED (168): new or re-activated, it must fit under the ceiling.
    IF (SELECT count(*) FROM (SELECT 1 FROM public.live_activity_tokens
         WHERE is_active LIMIT max_active) s) >= max_active THEN
        RAISE EXCEPTION 'live_activity_tokens ceiling: % active tokens (migration 168)', max_active;
    END IF;
    IF v_exists THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO recent FROM (
        SELECT 1 FROM public.live_activity_tokens
         WHERE created_at > now() - interval '1 hour'
         LIMIT alarm_per_hour + 1) s;

    IF recent = warn_per_hour OR recent = alarm_per_hour THEN
        BEGIN
            INSERT INTO public.pipeline_health (stage, status, message, target)
            VALUES ('token_register',
                    CASE WHEN recent >= alarm_per_hour THEN 'failure' ELSE 'partial' END,
                    format('%s live_activity_tokens rows in the last hour (warn at %s, alarm at %s; refused only past %s active since 168)',
                           recent, warn_per_hour, alarm_per_hour, max_active),
                    'la_rate_limit');
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_token_rate_limit()    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_la_token_rate_limit() FROM PUBLIC, anon, authenticated;

-- TWO: the RPCs keep a BadDeviceToken inactive in its environment ----------
-- Live bodies (129 / 156) with only the is_active line changed.
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_apns_token text, p_team_ids text[], p_country_ids text[], p_tier integer,
  p_apns_environment text, p_timezone text DEFAULT 'Europe/London'::text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
    -- CHANGED (168): never back on in an environment APNs called it bad in.
    is_active        = NOT COALESCE(EXCLUDED.apns_environment = ANY (dt.bad_token_envs), false),
    updated_at       = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.register_la_token(
  p_token text, p_kind text, p_fixture_id integer, p_country_ids text[],
  p_apns_environment text, p_team_ids text[] DEFAULT '{}'::text[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
    -- CHANGED (168): never back on in an environment APNs called it bad in.
    is_active        = NOT COALESCE(EXCLUDED.apns_environment = ANY (la.bad_token_envs), false),
    updated_at       = now(),
    user_agent       = EXCLUDED.user_agent,
    app_build        = EXCLUDED.app_build,
    darwin_major     = EXCLUDED.darwin_major;
END;
$$;

-- CREATE OR REPLACE keeps the existing grants; restated so the file says it.
REVOKE EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text) TO anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[]) TO anon, authenticated, service_role;

-- THREE: the hourly alarm -------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_token_volume()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  -- Real peaks: 3 device and 33 Live Activity tokens in an hour (2026-11-03).
  -- ponytail: fixed for ~100 devices; raise both with a real launch.
  dt_warn_per_hour CONSTANT integer := 100;
  la_warn_per_hour CONSTANT integer := 300;
  dt_warn_active   CONSTANT integer := 10000;   -- half of the 20 000 ceiling
  la_warn_active   CONSTANT integer := 25000;   -- half of the 50 000 ceiling
  v_dt_hour   bigint;
  v_la_hour   bigint;
  v_dt_active bigint;
  v_la_active bigint;
BEGIN
  SELECT count(*) INTO v_dt_hour FROM (SELECT 1 FROM public.device_tokens
    WHERE created_at > now() - interval '1 hour' LIMIT dt_warn_per_hour) s;
  SELECT count(*) INTO v_la_hour FROM (SELECT 1 FROM public.live_activity_tokens
    WHERE created_at > now() - interval '1 hour' LIMIT la_warn_per_hour) s;
  SELECT count(*) INTO v_dt_active FROM (SELECT 1 FROM public.device_tokens
    WHERE is_active LIMIT dt_warn_active) s;
  SELECT count(*) INTO v_la_active FROM (SELECT 1 FROM public.live_activity_tokens
    WHERE is_active LIMIT la_warn_active) s;
  IF v_dt_hour < dt_warn_per_hour AND v_la_hour < la_warn_per_hour
     AND v_dt_active < dt_warn_active AND v_la_active < la_warn_active THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.client_errors
              WHERE error_type = 'token_volume_high'
                AND created_at > now() - interval '6 hours') THEN
    RETURN;
  END IF;
  PERFORM net.http_post(
    url     := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/client-error-alert',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || public.get_cron_service_key()),
    body    := jsonb_build_object(
      'error_type', 'token_volume_high',
      'message', format('New push tokens in the last hour: %s device (warn %s), %s Live Activity (warn %s). Active: %s device, %s LA (refused past 20000 / 50000). A registration flood or a launch.',
                        v_dt_hour, dt_warn_per_hour, v_la_hour, la_warn_per_hour,
                        v_dt_active, v_la_active),
      'app_version', 'backend-cron'));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_token_volume() FROM PUBLIC, anon, authenticated;

SELECT cron.schedule('token_volume_alarm', '27 * * * *', 'SELECT public.check_token_volume()');

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification (run 2026-11-03, see the bug-hunt report):
--   SELECT has_function_privilege('anon', 'public.mark_tokens_bad(text, text[], text[])', 'EXECUTE');  -- f
--   SELECT has_function_privilege('anon', 'public.check_token_volume()', 'EXECUTE');                   -- f
--   SELECT has_function_privilege('anon', 'public.register_device_token(text, text[], text[], integer, text, text)', 'EXECUTE'); -- t
--   SELECT has_function_privilege('anon', 'public.register_la_token(text, text, integer, text[], text, text[])', 'EXECUTE');      -- t
