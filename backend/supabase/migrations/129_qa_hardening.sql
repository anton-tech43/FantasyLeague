-- 129_qa_hardening.sql
-- Five findings from the 2026-10-04 QA pass, each checked against production
-- (read-only) before it was written down here.
--
-- ONE (QA-05). The day-before push can never fire in winter. 125 scheduled
-- 'goaldigger-prep-reminder' at 07:00 and 08:00 UTC, and matchday-reminder
-- ?mode=prep sends only when londonHour(now) === 9. In BST 09:00 London is
-- 08:00 UTC; in GMT (from 25 October) it is 09:00 UTC, which is not
-- scheduled. The hours that bracket 09:00 London on both sides of the clock
-- change are 08 and 09 UTC. The job is paused (126) and stays paused:
-- cron.alter_job leaves `active` alone when it is not passed.
--
-- TWO (QA-10, F2). The three anon RPCs take unbounded input from anyone
-- holding the key in the binary:
--   register_device_token / register_la_token: p_team_ids and p_country_ids
--     of any length, any element, any slug. Every element is fanned out over
--     by the push senders' GIN lookups.
--   register_la_token: p_token was '^[a-fA-F0-9]{16,}$' — no ceiling.
--   save_match_calls: pick.trigger is "any json object", so seven picks can
--     each carry a megabyte, stored on device_tokens and read on every goal.
-- The app sends at most 2 clubs + 2 countries (V2.2 arrays model), and every
-- slug in Team.swift / Country.swift exists in teams.id (checked 2026-10-04;
-- so does every slug currently stored on 34 device and 118 LA rows).
-- LA tokens in production are 160-256 hex chars, so the cap is 512, not the
-- 200 the finding suggested — 200 would refuse real tokens today.
-- The largest legitimate slip is 7 x 171 chars (from MyTurn/lingo.json, the
-- largest trigger is 76 chars), so 4096 for the whole slip and 512 for one
-- trigger leave three to six times headroom.
-- NOTE for whoever prunes `teams`: an id removed from teams makes every
-- device still following it fail to register. Repoint those rows first.
--
-- THREE (QA-10). The device_tokens rate limit (108, re-attached by 120) warns
-- at 500 and refuses at 20 000 new rows an hour, for an app whose organic
-- signup is single digits a day. Now 25 / 1 000. And it used to refuse
-- re-registrations too: a BEFORE INSERT row trigger fires for the proposed
-- row of an INSERT ... ON CONFLICT DO UPDATE, so during a flood every
-- existing user's launch-time re-register failed with it. At 1 000 that is
-- far easier to reach, so a token we already hold now skips the count.
-- live_activity_tokens had no limit at all; it gets the same trigger at
-- 50 / 2 000 (an install vends a push-to-start token plus one update token
-- per live match). Both count created_at over the last hour, which had no
-- index on either table.
--
-- FOUR (QA-09, QA-16). Nothing ever deletes from live_activity_tokens,
-- device_tokens, client_errors or match_status_state. One SQL function, one
-- daily cron job, in the 03:xx retention slot beside 044's sweeps:
--   LA 'update' tokens      updated_at older than 3 days. One per running
--                           activity; an activity lives hours, not days.
--   LA 'push_to_start'      updated_at older than 90 days. The app re-asserts
--                           it on every foreground (LiveActivityManager.
--                           syncForegroundActivity), so 90 days untouched is
--                           90 days without opening the app.
--   device_tokens inactive  is_active = false, untouched for 90 days. APNs
--                           already told us they are dead; an install that
--                           comes back re-registers through the RPC.
--   client_errors           older than 90 days. client-error-alert reads only
--                           a recent alerted_at window.
--   match_status_state      FT/AET/PEN with kickoff more than 180 days ago.
--                           Every reader filters to a window of hours
--                           (match-watcher by fixture it is polling now,
--                           morning-push, matchday-reminder, live-*-current,
--                           poll_leagues, check_pipeline_heartbeat,
--                           suppress_wc_result_recap_push), or by recent
--                           fixture id (routines post_news.sh cup guard).
--                           The one unbounded reader is team-page-generator's
--                           WC openerPlayed, which only matters while a WC
--                           country has played 0 in standings. Only terminal
--                           statuses go: a PST/ABD row can come back to life
--                           under the same fixture id, and match-watcher's
--                           "first observation never fires" would then
--                           swallow its pushes.
-- raw_fetch_logs (job 21), pipeline_health (37), cron.job_run_details (33)
-- and team_page_prose_history (44) already have sweeps and are not touched.
--
-- FIVE (QA-17, F4). Nine service-only tables still hold `anon=r` and
-- `authenticated=r` from Supabase's default privileges. RLS stops the read
-- today (every policy is service_role-only, match_watcher_ticks has none),
-- but that is one policy edit away from a leak of APNs JWTs, raw feed
-- payloads and device ids. Inventory before revoking:
--   iOS reads only content_items, player_cards, team_pages, team_season_state,
--     team_insider_items, my_turn_content, players, teams (APIClient,
--     LiveClubPack, LiveSquadPack, MyTurnContentService) plus the 3 RPCs.
--   live-brief-current, live-match-current, quiz-current, team-season-state
--     and delete-my-data use getSupabaseClient(), i.e. the service key.
--   The only view on any of them, v_push_delivery_daily (pipeline_health),
--     is already closed to anon. No anon-executable function reads them.
-- So the revoke changes nothing that works and closes what RLS was guarding.

BEGIN;

SET LOCAL lock_timeout = '5s';

-- ONE ----------------------------------------------------------------------
DO $one$
DECLARE
  v_jobid  bigint;
  v_active boolean;
BEGIN
  SELECT jobid, active INTO v_jobid, v_active
    FROM cron.job WHERE jobname = 'goaldigger-prep-reminder';
  IF v_jobid IS NULL THEN
    RAISE EXCEPTION 'goaldigger-prep-reminder is missing; apply 125 first';
  END IF;
  PERFORM cron.alter_job(v_jobid, schedule := '0 8,9 * * *');
  IF (SELECT active FROM cron.job WHERE jobid = v_jobid) IS DISTINCT FROM v_active THEN
    RAISE EXCEPTION 'cron.alter_job changed the active flag of goaldigger-prep-reminder';
  END IF;
END
$one$;

-- TWO ----------------------------------------------------------------------
-- Bodies are production's (pg_get_functiondef, 2026-10-04) with only the
-- guards added. Signatures, SECURITY DEFINER and search_path are unchanged.

CREATE OR REPLACE FUNCTION public.register_device_token(p_apns_token text, p_team_ids text[], p_country_ids text[], p_tier integer, p_apns_environment text, p_timezone text DEFAULT 'Europe/London'::text)
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
    is_active        = true,
    updated_at       = now();
END;
$function$;

CREATE OR REPLACE FUNCTION public.register_la_token(p_token text, p_kind text, p_fixture_id integer, p_country_ids text[], p_apns_environment text, p_team_ids text[] DEFAULT '{}'::text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
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

CREATE OR REPLACE FUNCTION public.save_match_calls(p_apns_token text, p_fixture_id bigint, p_picks jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_pick jsonb;
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

  -- One slip at a time: a new fixture replaces the old one, which is also what
  -- keeps match-calls.ts's stale-fixture guard from ever having much to do.
  UPDATE public.device_tokens
     SET match_calls = jsonb_build_object(
           'fixture_id', p_fixture_id,
           'picks',      p_picks,
           'picked_at',  now()
         )
   WHERE apns_token = p_apns_token;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'unknown device';
  END IF;
END;
$function$;

-- CREATE OR REPLACE keeps the ACL, but write it out so the file states it:
-- exactly production's {postgres, anon, authenticated, service_role}, no PUBLIC.
REVOKE EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[])
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.save_match_calls(text, bigint, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text[], text[], integer, text, text)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_la_token(text, text, integer, text[], text, text[])
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_match_calls(text, bigint, jsonb)
  TO anon, authenticated, service_role;

-- THREE --------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_device_tokens_created_at
  ON public.device_tokens (created_at);
CREATE INDEX IF NOT EXISTS idx_la_tokens_created_at
  ON public.live_activity_tokens (created_at);

CREATE OR REPLACE FUNCTION public.check_token_rate_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    -- Organic signup for this app is in the single digits per day. 25 in an
    -- hour is already nothing like normal, which is why it is worth a row in
    -- pipeline_health; 1 000 is a flood (129, down from 500 / 20 000).
    warn_per_hour CONSTANT INTEGER := 25;
    hard_cap      CONSTANT INTEGER := 1000;
    recent        INTEGER;
BEGIN
    -- A token we already hold arrives here as the proposed row of the RPC's
    -- ON CONFLICT upsert. It is not new volume, and it must keep working
    -- during a flood, or every existing user's launch-time re-register fails.
    IF EXISTS (SELECT 1 FROM public.device_tokens WHERE apns_token = NEW.apns_token) THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO recent
    FROM public.device_tokens
    WHERE created_at > NOW() - INTERVAL '1 hour';

    IF recent >= hard_cap THEN
        RAISE EXCEPTION 'device_tokens registration flood: % rows in the last hour', recent;
    END IF;

    IF recent >= warn_per_hour THEN
        -- Best effort. A failure to log must never fail a registration.
        BEGIN
            INSERT INTO public.pipeline_health (stage, status, message, target)
            VALUES ('token_register', 'partial',
                    format('%s device_tokens rows in the last hour (warn at %s, reject at %s)',
                           recent, warn_per_hour, hard_cap),
                    'rate_limit');
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_la_token_rate_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    -- Twice device_tokens': an install vends one push-to-start token and one
    -- update token per live match it shows.
    warn_per_hour CONSTANT INTEGER := 50;
    hard_cap      CONSTANT INTEGER := 2000;
    recent        INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM public.live_activity_tokens WHERE token = NEW.token) THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO recent
    FROM public.live_activity_tokens
    WHERE created_at > NOW() - INTERVAL '1 hour';

    IF recent >= hard_cap THEN
        RAISE EXCEPTION 'live_activity_tokens registration flood: % rows in the last hour', recent;
    END IF;

    IF recent >= warn_per_hour THEN
        BEGIN
            INSERT INTO public.pipeline_health (stage, status, message, target)
            VALUES ('token_register', 'partial',
                    format('%s live_activity_tokens rows in the last hour (warn at %s, reject at %s)',
                           recent, warn_per_hour, hard_cap),
                    'la_rate_limit');
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$function$;

-- Trigger functions: PostgreSQL checks EXECUTE when the trigger is created,
-- not when it fires, and check_token_rate_limit has run without an anon grant
-- since 108. Closed like every other function.
REVOKE EXECUTE ON FUNCTION public.check_token_rate_limit()    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_la_token_rate_limit() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_la_token_rate_limit ON public.live_activity_tokens;
CREATE TRIGGER enforce_la_token_rate_limit
  BEFORE INSERT ON public.live_activity_tokens
  FOR EACH ROW EXECUTE FUNCTION public.check_la_token_rate_limit();

-- FOUR ---------------------------------------------------------------------
-- SECURITY INVOKER: pg_cron runs it as postgres, and nobody else should.
CREATE OR REPLACE FUNCTION public.purge_stale_rows()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  n_la_update   bigint;
  n_la_pts      bigint;
  n_dt_inactive bigint;
  n_errors      bigint;
  n_matches     bigint;
BEGIN
  DELETE FROM public.live_activity_tokens
   WHERE kind = 'update' AND updated_at < now() - interval '3 days';
  GET DIAGNOSTICS n_la_update = ROW_COUNT;

  DELETE FROM public.live_activity_tokens
   WHERE kind = 'push_to_start' AND updated_at < now() - interval '90 days';
  GET DIAGNOSTICS n_la_pts = ROW_COUNT;

  DELETE FROM public.device_tokens
   WHERE is_active = false
     AND COALESCE(updated_at, created_at) < now() - interval '90 days';
  GET DIAGNOSTICS n_dt_inactive = ROW_COUNT;

  DELETE FROM public.client_errors
   WHERE created_at < now() - interval '90 days';
  GET DIAGNOSTICS n_errors = ROW_COUNT;

  DELETE FROM public.match_status_state
   WHERE status IN ('FT', 'AET', 'PEN')
     AND kickoff_time < now() - interval '180 days';
  GET DIAGNOSTICS n_matches = ROW_COUNT;

  RETURN jsonb_build_object(
    'la_update',          n_la_update,
    'la_push_to_start',   n_la_pts,
    'device_tokens_dead', n_dt_inactive,
    'client_errors',      n_errors,
    'match_status_state', n_matches
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.purge_stale_rows() FROM PUBLIC, anon, authenticated;

-- cron.schedule with a name replaces a job of that name, so this re-runs clean.
SELECT cron.schedule(
  'stale_rows_retention_sweep',
  '55 3 * * *',
  'SELECT public.purge_stale_rows()'
);

-- FIVE ---------------------------------------------------------------------
-- ALL, not SELECT: PG17's MAINTAIN is invisible in role_table_grants (115/116).
REVOKE ALL ON TABLE
  public.apns_jwt_cache,
  public.pipeline_health,
  public.client_errors,
  public.raw_fetch_logs,
  public.dev_alert_devices,
  public.matchday_reminders_sent,
  public.match_watcher_ticks,
  public.content_reviews,
  public.team_news_sources
FROM PUBLIC, anon, authenticated;

-- Self-check: assert the state, not the statements (120). Inside the
-- transaction, so a failure rolls the whole migration back. The RPC probes
-- all raise before their INSERT/UPDATE, so they write nothing.
DO $check$
DECLARE
  bad text := '';
  t   text;
  ok  boolean;
  tok text := repeat('a', 64);
BEGIN
  IF (SELECT schedule FROM cron.job WHERE jobname = 'goaldigger-prep-reminder') <> '0 8,9 * * *'
    THEN bad := bad || ' prep-schedule'; END IF;

  IF NOT has_function_privilege('anon', 'public.register_device_token(text,text[],text[],integer,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('anon', 'public.register_la_token(text,text,integer,text[],text,text[])', 'EXECUTE')
     OR NOT has_function_privilege('anon', 'public.save_match_calls(text,bigint,jsonb)', 'EXECUTE')
    THEN bad := bad || ' app-rpc-closed-by-mistake'; END IF;
  IF has_function_privilege('anon', 'public.purge_stale_rows()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.check_la_token_rate_limit()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.check_token_rate_limit()', 'EXECUTE')
    THEN bad := bad || ' new-function-anon-executable'; END IF;

  -- Guards refuse what they should.
  ok := false;
  BEGIN PERFORM public.register_device_token(tok, ARRAY['arsenal','spurs','leeds'], ARRAY[]::text[], 2, 'production');
  EXCEPTION WHEN raise_exception THEN ok := true; END;
  IF NOT ok THEN bad := bad || ' 3-clubs-accepted'; END IF;
  ok := false;
  BEGIN PERFORM public.register_device_token(tok, ARRAY['not_a_club'], ARRAY[]::text[], 2, 'production');
  EXCEPTION WHEN raise_exception THEN ok := true; END;
  IF NOT ok THEN bad := bad || ' unknown-slug-accepted'; END IF;
  ok := false;
  BEGIN PERFORM public.register_la_token(repeat('a', 513), 'push_to_start', NULL, ARRAY[]::text[], 'production');
  EXCEPTION WHEN raise_exception THEN ok := true; END;
  IF NOT ok THEN bad := bad || ' long-la-token-accepted'; END IF;
  ok := false;
  BEGIN PERFORM public.save_match_calls(tok, 1,
          jsonb_build_array(jsonb_build_object('id', 'x', 'line', 'y',
                            'trigger', jsonb_build_object('pad', repeat('z', 5000)))));
  EXCEPTION WHEN raise_exception THEN ok := true; END;
  IF NOT ok THEN bad := bad || ' huge-slip-accepted'; END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.live_activity_tokens'::regclass
                   AND NOT tgisinternal AND tgname = 'enforce_la_token_rate_limit')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.device_tokens'::regclass
                   AND NOT tgisinternal AND tgname = 'enforce_token_rate_limit')
    THEN bad := bad || ' rate-limit-trigger-missing'; END IF;
  IF to_regclass('public.idx_device_tokens_created_at') IS NULL
     OR to_regclass('public.idx_la_tokens_created_at') IS NULL
    THEN bad := bad || ' created_at-index-missing'; END IF;

  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'stale_rows_retention_sweep' AND active)
    THEN bad := bad || ' retention-job-missing'; END IF;

  FOREACH t IN ARRAY ARRAY['apns_jwt_cache','pipeline_health','client_errors','raw_fetch_logs',
                           'dev_alert_devices','matchday_reminders_sent','match_watcher_ticks',
                           'content_reviews','team_news_sources'] LOOP
    IF has_table_privilege('anon', 'public.' || t, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
       OR has_table_privilege('authenticated', 'public.' || t, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
      THEN bad := bad || ' ' || t || '-still-readable'; END IF;
  END LOOP;

  IF bad <> '' THEN RAISE EXCEPTION 'migration 129 self-check failed:%', bad; END IF;
  RAISE NOTICE 'migration 129 self-check passed';
END
$check$;

COMMIT;

-- Verification (run after applying):
--
-- ONE  SELECT schedule, active FROM cron.job WHERE jobname = 'goaldigger-prep-reminder';
--        -- 0 8,9 * * * | f   (still paused; re-enable per 126 when the app ships)
--
-- TWO  SELECT p.proname, p.prosecdef, p.proconfig, p.proacl FROM pg_proc p
--       WHERE p.pronamespace = 'public'::regnamespace
--         AND p.proname IN ('register_device_token','register_la_token','save_match_calls');
--        -- 3 rows, prosecdef t, {search_path=""},
--        -- proacl {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
--      Each of these must raise (they never reach the INSERT/UPDATE):
--      BEGIN;
--        SELECT public.register_device_token(repeat('a',64), ARRAY['arsenal','spurs','leeds'], '{}', 2, 'production');
--          -- ERROR: at most 2 team_ids and 2 country_ids
--      ROLLBACK;
--      BEGIN; SELECT public.register_device_token(repeat('a',64), ARRAY['not_a_club'], '{}', 2, 'production'); ROLLBACK;
--          -- ERROR: unknown team or country id
--      BEGIN; SELECT public.register_la_token(repeat('a',513), 'push_to_start', NULL, '{}', 'production'); ROLLBACK;
--          -- ERROR: invalid token
--      BEGIN; SELECT public.save_match_calls(repeat('a',64), 1, jsonb_build_array(jsonb_build_object(
--               'id','x','line','y','trigger',jsonb_build_object('pad',repeat('z',5000))))); ROLLBACK;
--          -- ERROR: picks too large
--
-- THREE SELECT tgrelid::regclass, tgname FROM pg_trigger
--        WHERE tgname IN ('enforce_token_rate_limit','enforce_la_token_rate_limit');
--        -- device_tokens | enforce_token_rate_limit ; live_activity_tokens | enforce_la_token_rate_limit
--       SELECT prosrc ~ 'hard_cap +CONSTANT INTEGER := 1000;' FROM pg_proc
--        WHERE oid = 'public.check_token_rate_limit()'::regprocedure;            -- t
--       SELECT indexrelid::regclass FROM pg_index
--        WHERE indexrelid::regclass::text IN ('idx_device_tokens_created_at','idx_la_tokens_created_at');  -- 2 rows
--
-- FOUR SELECT schedule, command, active FROM cron.job WHERE jobname = 'stale_rows_retention_sweep';
--        -- 55 3 * * * | SELECT public.purge_stale_rows() | t
--      SELECT has_function_privilege('anon', 'public.purge_stale_rows()', 'EXECUTE');  -- f
--      After 03:55 UTC the next day:
--      SELECT status, return_message FROM cron.job_run_details
--       WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'stale_rows_retention_sweep')
--       ORDER BY start_time DESC LIMIT 1;                                       -- succeeded | 1 row
--
-- FIVE SELECT c.relname,
--             has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') AS anon_any,
--             has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') AS auth_any
--        FROM pg_class c
--       WHERE c.relnamespace = 'public'::regnamespace
--         AND c.relname IN ('apns_jwt_cache','pipeline_health','client_errors','raw_fetch_logs','dev_alert_devices',
--                           'matchday_reminders_sent','match_watcher_ticks','content_reviews','team_news_sources');
--        -- 9 rows, all f | f
--
-- And the backstop: ./scripts/db-health.sh section 7 must still print
-- "OK only the app's own RPCs are callable by anon".
