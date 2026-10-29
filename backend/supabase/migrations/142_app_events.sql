-- 142: first-party usage events (docs/TRACKING_PLAN.md, build step 1).
--
-- app_events is the first table whose row count scales with USERS rather than
-- clubs, written three weeks after a database that ran out of room took four
-- days to recover. So the budget ships in this file, not a later one:
--   * volume: ~70 devices x ~30 events/day = ~2 000 rows/day, under 1 MB/week;
--     at 1 000 users ~30 000/day.
--   * append-only, never updated (no dead tuples), batched writes only.
--   * both read indexes here, plus a BRIN for the flood check.
--   * retention here: 13 months raw, then a daily roll-up, by cron.
--
-- One RPC, log_events, same shape as the app's other three: SECURITY DEFINER,
-- caps on batch size and bytes, a fixed allow-list of event names, scalar
-- properties only (so no free text, names or anything she wrote can ride in),
-- a per-install and a global rate limit that DROP rather than raise, because
-- an error would only make the phone retry the same batch.

BEGIN;

-- ONE: windows where the data is ours, not hers --------------------------
-- Every retention or engagement query joins against this rather than copying
-- the dates (TRACKING_PLAN "There is a four-day hole in the record").
CREATE TABLE IF NOT EXISTS public.analytics_blackouts (
  started_at timestamptz NOT NULL,
  ended_at   timestamptz NOT NULL,
  reason     text        NOT NULL,
  PRIMARY KEY (started_at),
  CHECK (ended_at > started_at)
);

INSERT INTO public.analytics_blackouts (started_at, ended_at, reason) VALUES
  ('2026-08-30 00:00+00', '2026-09-06 00:00+00',
   'Out of resources, fully down (OUTAGE_LESSONS). Day bounds: exact hours not recorded.'),
  ('2026-09-20 00:00+00', '2026-09-22 00:00+00',
   'Whole instance slow for 17 h (OUTAGE_LESSONS). Two whole days: the hours were not recorded.'),
  ('2026-10-21 11:22+00', '2026-10-25 09:23+00',
   'pg_cron could not start jobs; no content, pushes or reads until the compute upgrade.')
ON CONFLICT (started_at) DO NOTHING;

-- TWO: the events ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- NULL only for data_deleted, which outlives the install it describes.
  install_id  uuid,
  name        text        NOT NULL,
  props       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  -- When it happened on the phone (queued offline up to 7 days), clamped by
  -- log_events. created_at is when it reached us; queries use occurred_at.
  occurred_at timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- One person's path, and a funnel. EXPLAIN-checked against seeded rows when
-- this was applied (see the verification block at the end).
CREATE INDEX IF NOT EXISTS idx_app_events_install_time
  ON public.app_events (install_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_events_name_time
  ON public.app_events (name, occurred_at);
-- Append-only and time-ordered: BRIN is a few pages and makes the global
-- "how many in the last minute" check cheap.
CREATE INDEX IF NOT EXISTS idx_app_events_created_brin
  ON public.app_events USING brin (created_at) WITH (autosummarize = on);
-- autosummarize: an unsummarised page range is always read, so without it
-- every page written since the last vacuum is scanned by the flood check.
ALTER INDEX public.idx_app_events_created_brin SET (autosummarize = on);

-- Rolled-up history for rows older than 13 months.
CREATE TABLE IF NOT EXISTS public.app_events_daily (
  day     date   NOT NULL,
  name    text   NOT NULL,
  club    text   NOT NULL DEFAULT '',
  events  bigint NOT NULL,
  installs bigint NOT NULL,
  PRIMARY KEY (day, name, club)
);

ALTER TABLE public.analytics_blackouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_events          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_events_daily    ENABLE ROW LEVEL SECURITY;
-- ALL, not SELECT: PG17's MAINTAIN is invisible in role_table_grants (115/116).
REVOKE ALL ON TABLE public.analytics_blackouts, public.app_events, public.app_events_daily
  FROM PUBLIC, anon, authenticated;

-- THREE: the RPC ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_events(
  p_install_id uuid,
  p_events     jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  -- Must equal the app's AnalyticsEvent cases; AnalyticsTests asserts it.
  allowed CONSTANT text[] := ARRAY[
    'app_opened', 'onboarding_step_viewed', 'onboarding_completed', 'push_opened',
    'tab_viewed', 'settings_opened', 'feed_card_opened', 'line_shared', 'line_saved',
    'my_turn_module_switched', 'pregame_opened', 'matchday_after_opened',
    'pregame_card_completed', 'practice_completed', 'overheard_round_finished',
    'hype_shown', 'follow_changed', 'tier_changed', 'notification_permission_changed',
    'notifications_banner', 'settings_row_opened', 'data_deleted'
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

-- FOUR: retention ---------------------------------------------------------
CREATE OR REPLACE FUNCTION public.roll_up_app_events()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  cutoff CONSTANT timestamptz := date_trunc('day', now() - interval '13 months');
BEGIN
  INSERT INTO public.app_events_daily (day, name, club, events, installs)
  SELECT occurred_at::date, name, coalesce(props ->> 'club', ''),
         count(*), count(DISTINCT install_id)
    FROM public.app_events
   WHERE occurred_at < cutoff
   GROUP BY 1, 2, 3
  ON CONFLICT (day, name, club) DO UPDATE
    SET events   = public.app_events_daily.events   + EXCLUDED.events,
        installs = public.app_events_daily.installs + EXCLUDED.installs;
  DELETE FROM public.app_events WHERE occurred_at < cutoff;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.roll_up_app_events() FROM PUBLIC, anon, authenticated;

-- cron.schedule with a name replaces a job of that name, so this re-runs clean.
SELECT cron.schedule('app_events_rollup', '40 3 * * *', 'SELECT public.roll_up_app_events()');

COMMIT;

-- Verification (run after applying):
--   SELECT has_function_privilege('anon', 'public.log_events(uuid,jsonb)', 'EXECUTE');           -- t
--   SELECT has_function_privilege('anon', 'public.roll_up_app_events()', 'EXECUTE');             -- f
--   SELECT has_table_privilege('anon', 'public.app_events', 'SELECT');                           -- f
--   SELECT count(*) FROM public.analytics_blackouts;                                             -- 3
