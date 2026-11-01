-- 148: usage events, three fixes from the app council (2026-10-29, accepted
-- 2026-11-01).
--
--   * Delete My Data gets its own call, delete_app_events. Until now the delete
--     rode on a data_deleted event inside log_events: the phone swallowed any
--     failure and rotated the install id anyway, so an offline delete orphaned
--     her rows for good, and the flood check could return before the delete
--     ran. The app now rotates the id only after this call succeeds.
--   * The anonymous exit line keeps what the privacy policy promises and no
--     more: "that someone deleted their data, and how many days after install".
--     It carried club, relationship, tier and app version. Not written for
--     TestFlight or Xcode builds, nor for an id that had no rows (so a made-up
--     id cannot write exit lines).
--   * The per-install rate limit counted occurred_at, which is the phone's
--     clock: a phone dating its events eight days back was never limited. It
--     counts created_at now.
--
-- Plus an alarm on the table's size and daily volume, which pushes through the
-- heartbeat's own path (client-error-alert). Old builds keep calling
-- log_events(uuid, jsonb) with data_deleted; that still deletes, through the
-- same function.

BEGIN;

-- ONE: Delete My Data ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_app_events(
  p_install_id         uuid,
  p_days_since_install integer DEFAULT NULL,
  -- 'appstore' | 'testflight' | 'debug' | NULL (unknown, old builds).
  p_channel            text    DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deleted integer;
BEGIN
  -- Callable with the key in the binary, for any id it is given. Install ids
  -- are random UUIDs that never leave the phone except in these two RPCs, so
  -- guessing one is not a practical attack; knowing one only deletes its rows.
  IF p_install_id IS NULL THEN
    RAISE EXCEPTION 'invalid install_id';
  END IF;
  DELETE FROM public.app_events WHERE install_id = p_install_id;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted > 0 AND coalesce(p_channel, 'unknown') NOT IN ('testflight', 'debug') THEN
    INSERT INTO public.app_events (install_id, name, props, occurred_at)
    VALUES (NULL, 'data_deleted',
            CASE WHEN p_days_since_install BETWEEN 0 AND 3650
                 THEN jsonb_build_object('days_since_install', p_days_since_install)
                 ELSE '{}'::jsonb END,
            now());
  END IF;
  RETURN v_deleted;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_app_events(uuid, integer, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.delete_app_events(uuid, integer, text) TO anon, authenticated, service_role;

-- The exit lines already written carried more than the policy says.
UPDATE public.app_events
   SET props = CASE WHEN props ? 'days_since_install'
                    THEN jsonb_build_object('days_since_install', props -> 'days_since_install')
                    ELSE '{}'::jsonb END
 WHERE name = 'data_deleted' AND install_id IS NULL;

-- TWO: log_events, 144's body with the two changes marked ------------------
CREATE OR REPLACE FUNCTION public.log_events(
  p_install_id uuid,
  p_events     jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  -- Must equal the app's AnalyticsEvent cases; scripts/verify-tracking-plan.sh checks it.
  allowed CONSTANT text[] := ARRAY[
    'app_opened', 'onboarding_step_viewed', 'onboarding_completed', 'push_opened',
    'tab_viewed', 'settings_opened', 'feed_card_opened', 'line_shared', 'line_saved',
    'my_turn_module_switched', 'pregame_opened', 'matchday_after_opened',
    'pregame_card_completed', 'practice_completed', 'overheard_round_finished',
    'hype_shown', 'follow_changed', 'tier_changed', 'notification_permission_changed',
    'notifications_banner', 'settings_row_opened', 'data_deleted', 'push_delivered'
  ];
  per_install_per_hour CONSTANT integer := 600;   -- ~20x a heavy evening
  global_per_minute    CONSTANT integer := 3000;  -- ~1 500x today's rate
  v_ev    jsonb;
  v_name  text;
  v_props jsonb;
  v_at    timestamptz;
  v_val   jsonb;
  v_deleted jsonb := NULL;
BEGIN
  IF p_install_id IS NULL THEN
    RAISE EXCEPTION 'invalid install_id';
  END IF;
  IF p_events IS NULL OR jsonb_typeof(p_events) <> 'array' THEN
    RAISE EXCEPTION 'events must be a json array';
  END IF;
  IF jsonb_array_length(p_events) > 50 THEN
    RAISE EXCEPTION 'at most 50 events';
  END IF;
  IF octet_length(p_events::text) > 8192 THEN
    RAISE EXCEPTION 'batch over 8 KB';
  END IF;

  -- Floods are dropped, not refused: a refusal makes the phone resend.
  -- LIMIT inside: during a flood the count stops at the cap instead of
  -- reading every row of it.
  -- CHANGED (148): counted on created_at, our clock. occurred_at is the
  -- phone's and only bounds the index scan: it is never stored more than 8
  -- days before created_at (the clamp below), so the extra hour is exact.
  IF (SELECT count(*) FROM (SELECT 1 FROM public.app_events
       WHERE created_at > now() - interval '1 minute'
       LIMIT global_per_minute) s) >= global_per_minute
     OR (SELECT count(*) FROM (SELECT 1 FROM public.app_events
          WHERE install_id = p_install_id
            AND occurred_at > now() - interval '8 days 1 hour'
            AND created_at  > now() - interval '1 hour'
          LIMIT per_install_per_hour) s) >= per_install_per_hour THEN
    RETURN;
  END IF;

  FOR v_ev IN SELECT * FROM jsonb_array_elements(p_events) LOOP
    IF jsonb_typeof(v_ev) <> 'object' THEN
      RAISE EXCEPTION 'each event must be a json object';
    END IF;
    v_name  := v_ev ->> 'name';
    v_props := coalesce(v_ev -> 'props', '{}'::jsonb);
    IF v_name IS NULL OR NOT (v_name = ANY (allowed)) THEN
      RAISE EXCEPTION 'unknown event %', left(coalesce(v_name, 'null'), 40);
    END IF;
    IF jsonb_typeof(v_props) <> 'object' THEN
      RAISE EXCEPTION 'props must be a json object';
    END IF;
    IF (SELECT count(*) FROM jsonb_object_keys(v_props)) > 16 THEN
      RAISE EXCEPTION 'at most 16 props';
    END IF;
    -- Scalars only, short strings only: an event can carry a slug, a number
    -- or a flag, never a sentence (TRACKING_PLAN "Never in an event").
    FOR v_val IN SELECT value FROM jsonb_each(v_props) LOOP
      IF jsonb_typeof(v_val) NOT IN ('string', 'number', 'boolean', 'null')
         OR (jsonb_typeof(v_val) = 'string' AND length(v_val #>> '{}') > 64) THEN
        RAISE EXCEPTION 'prop values must be scalars, strings up to 64 chars';
      END IF;
    END LOOP;

    -- The phone's clock, clamped: queued at most 7 days, never in the future.
    BEGIN
      v_at := (v_ev ->> 'at')::timestamptz;
    EXCEPTION WHEN OTHERS THEN
      v_at := NULL;
    END;
    v_at := least(greatest(coalesce(v_at, now()), now() - interval '8 days'), now());

    IF v_name = 'data_deleted' THEN
      v_deleted := v_props;
    ELSE
      INSERT INTO public.app_events (install_id, name, props, occurred_at)
      VALUES (p_install_id, v_name, v_props, v_at);
    END IF;
  END LOOP;

  -- Delete My Data from builds before 148's app change. CHANGED (148): the
  -- exit line is delete_app_events', so it keeps only the days since install.
  IF v_deleted IS NOT NULL THEN
    PERFORM public.delete_app_events(
      p_install_id,
      CASE WHEN jsonb_typeof(v_deleted -> 'days_since_install') = 'number'
           THEN (v_deleted ->> 'days_since_install')::numeric::integer END,
      CASE WHEN v_deleted ->> 'env' = 'development' THEN 'debug' ELSE v_deleted ->> 'channel' END);
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_events(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.log_events(uuid, jsonb) TO anon, authenticated, service_role;

-- THREE: the size alarm ----------------------------------------------------
-- The one table that grows with users rather than clubs (142's budget: ~2 000
-- rows a day, under 1 MB a week). log_events' global cap still lets through
-- 4.3 M rows a day, so a flood fills the disk in days; a twice-weekly
-- db-health run is too slow for that. Hourly, through the heartbeat's path:
-- client-error-alert logs the row and pushes the dev phone.
CREATE OR REPLACE FUNCTION public.check_app_events_budget()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  -- ponytail: fixed for today's ~70 devices. Raise both past ~500 users
  -- (1 000 users is ~30 000 rows a day, TRACKING_PLAN).
  max_mb      CONSTANT bigint  := 100;     -- ~2 years of today's volume
  max_per_day CONSTANT integer := 50000;   -- ~25x today's rate
  v_mb  bigint := pg_total_relation_size('public.app_events') / 1048576;
  v_day bigint;
BEGIN
  SELECT count(*) INTO v_day FROM (SELECT 1 FROM public.app_events
    WHERE created_at > now() - interval '1 day' LIMIT max_per_day) s;
  IF v_mb < max_mb AND v_day < max_per_day THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.client_errors
              WHERE error_type = 'app_events_over_budget'
                AND created_at > now() - interval '6 hours') THEN
    RETURN;
  END IF;
  PERFORM net.http_post(
    url     := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/client-error-alert',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || public.get_cron_service_key()),
    body    := jsonb_build_object(
      'error_type', 'app_events_over_budget',
      'message', format('app_events is %s MB with %s%s rows in 24 h (budget %s MB, %s a day). A flood or a stopped roll-up.',
                        v_mb, v_day, CASE WHEN v_day >= max_per_day THEN '+' ELSE '' END, max_mb, max_per_day),
      'app_version', 'backend-cron'));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_app_events_budget() FROM PUBLIC, anon, authenticated;

SELECT cron.schedule('app_events_budget', '17 * * * *', 'SELECT public.check_app_events_budget()');

COMMIT;

-- Verification:
--   SELECT has_function_privilege('anon', 'public.delete_app_events(uuid, integer, text)', 'EXECUTE');  -- t (by design)
--   SELECT has_function_privilege('anon', 'public.check_app_events_budget()', 'EXECUTE');                -- f
--   SELECT count(*) FROM app_events WHERE name = 'data_deleted'
--      AND props - 'days_since_install' <> '{}'::jsonb;                                                  -- 0
