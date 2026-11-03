-- 159: log_events checks prop keys and the size of one event (bug hunt
-- 2026-11-03 A-C1, MEDIUM).
--
-- 148 capped rows (50 a batch, 8 KB a batch, 16 props, values <= 64 chars) but
-- never looked at a KEY: {"<7 880 random hex chars>": true} passed every check
-- and stored a 7.85 KB row (reproduced as anon in a rolled-back transaction).
-- With S-1's fresh-install-id bypass that is ~1.4 GB an hour against a 131 MB
-- database on the smallest compute.
--
-- Now a key must match ^[a-z_]{1,32}$ and one event's props must be <= 1 KB.
-- An event that fails is skipped, not raised: the rest of its batch lands.
-- Checked against every app_events row (751, 18 distinct keys, max props 227 B):
-- none would be skipped. Builds 2.2-2.4 send only snake_case keys.
--
-- CREATE OR REPLACE keeps the grants; the REVOKE/GRANT pair is restated so
-- this file alone is the truth (CLAUDE.md: FROM PUBLIC, anon, authenticated).

BEGIN;

CREATE OR REPLACE FUNCTION public.log_events(p_install_id uuid, p_events jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    -- CHANGED (159): keys were never checked, so one key could carry ~7.9 KB
    -- of free text and a row weighed ~8 KB instead of ~200 B (bug hunt
    -- 2026-11-03 A-C1). Every real key is snake_case and at most 18 chars,
    -- and the largest real props is 227 B. An event outside that is dropped
    -- on its own: the rest of the batch still lands, and the phone (which
    -- drops a refused batch, Analytics.swift) loses nothing it really sent.
    IF octet_length(v_props::text) > 1024
       OR EXISTS (SELECT 1 FROM jsonb_object_keys(v_props) k WHERE k !~ '^[a-z_]{1,32}$') THEN
      CONTINUE;
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
$function$
;

REVOKE EXECUTE ON FUNCTION public.log_events(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.log_events(uuid, jsonb) TO anon, authenticated, service_role;

COMMIT;
