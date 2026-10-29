-- 144: push_delivered, the event that makes a push-only user visible.
--
-- A user who reads her pushes on the Lock Screen and never opens the app
-- left no trace in app_events: no app_opened, no push_opened. The app's
-- Notification Service Extension now runs on every alert push iOS shows
-- (mutable-content is already 1 on every user push, apns-client.ts) and logs
-- push_delivered under the same install id. iOS does not run the extension
-- when her notifications are off, so a delivery also says they are on.
--
-- Only the allow-list changes; the body is 142's.

BEGIN;

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
  IF (SELECT count(*) FROM (SELECT 1 FROM public.app_events
       WHERE created_at > now() - interval '1 minute'
       LIMIT global_per_minute) s) >= global_per_minute
     OR (SELECT count(*) FROM (SELECT 1 FROM public.app_events
          WHERE install_id = p_install_id
            AND occurred_at > now() - interval '1 hour'
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
      v_deleted := jsonb_build_object('props', v_props, 'at', v_at);
    ELSE
      INSERT INTO public.app_events (install_id, name, props, occurred_at)
      VALUES (p_install_id, v_name, v_props, v_at);
    END IF;
  END LOOP;

  -- Delete My Data: every event for this install goes, and the exit itself
  -- stays, anonymous, because its install_id is the thing being deleted.
  IF v_deleted IS NOT NULL THEN
    DELETE FROM public.app_events WHERE install_id = p_install_id;
    INSERT INTO public.app_events (install_id, name, props, occurred_at)
    VALUES (NULL, 'data_deleted', v_deleted -> 'props', (v_deleted ->> 'at')::timestamptz);
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_events(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.log_events(uuid, jsonb) TO anon, authenticated, service_role;

COMMIT;

-- Verification:
--   SELECT has_function_privilege('anon', 'public.log_events(uuid, jsonb)', 'EXECUTE');  -- t (by design)
--   SELECT prosrc LIKE '%push_delivered%' FROM pg_proc WHERE proname = 'log_events';     -- t
