-- anon_rpc_limits_check.sql — the runnable check for migrations 159-160
-- (bug hunt 2026-11-03 A-C1, A-C2).
--
--   ./scripts/sql.sh -f backend/supabase/tests/anon_rpc_limits_check.sql
--
-- One transaction, ROLLED BACK. Calls the RPCs as anon, the way a phone does,
-- and raises on the first wrong answer. Nothing is written.
BEGIN;

-- 159: a long or non-snake_case key, or props over 1 KB, drops that event only.
SET LOCAL ROLE anon;
SELECT public.log_events('00000000-0000-4000-8000-00000000c159', jsonb_build_array(
  jsonb_build_object('name','app_opened','props', jsonb_build_object((SELECT string_agg(md5(random()::text),'') FROM generate_series(1,245)), true)),
  jsonb_build_object('name','app_opened','props', jsonb_build_object('Club', 'arsenal')),
  jsonb_build_object('name','tab_viewed','props', jsonb_build_object('tab','home','tier',2,'club','arsenal','app_version','2.4','build','412','days_since_install',3,'env','production','relationship','partner'))));
RESET ROLE;
DO $$
DECLARE n int; big int;
BEGIN
  SELECT count(*), max(pg_column_size(props)) INTO n, big FROM public.app_events
   WHERE install_id = '00000000-0000-4000-8000-00000000c159';
  ASSERT n = 1, format('159: expected only the valid event to land, got %s', n);
  ASSERT big < 400, format('159: row too big: %s B', big);
  ASSERT NOT EXISTS (SELECT 1 FROM public.app_events e
     WHERE e.install_id <> '00000000-0000-4000-8000-00000000c159'
       AND (octet_length(e.props::text) > 1024
            OR EXISTS (SELECT 1 FROM jsonb_object_keys(e.props) k WHERE k !~ '^[a-z_]{1,32}$'))),
    '159: a real app_events row would now be dropped';
END $$;

-- 160: a flood of new tokens is logged, never refused, and the log stays small.
DO $$ BEGIN
  FOR i IN 1..1000 LOOP
    PERFORM public.register_device_token(md5('zzjunk'||i)||md5('zzjunk2'||i), ARRAY['arsenal'], NULL, 2, 'production');
  END LOOP;
  FOR i IN 1..2000 LOOP
    PERFORM public.register_la_token(md5('zzla'||i)||md5('zzla2'||i), 'push_to_start', NULL, NULL, 'production', ARRAY['arsenal']);
  END LOOP;
END $$;
SET LOCAL ROLE anon;
SELECT public.register_device_token(md5('zzreal')||md5('zzreal2'), ARRAY['arsenal'], NULL, 2, 'production');
SELECT public.register_la_token(md5('zzreal')||md5('zzreal2')||md5('zzreal3'), 'push_to_start', NULL, NULL, 'production', ARRAY['arsenal']);
RESET ROLE;
DO $$
DECLARE dt int; la int;
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.device_tokens WHERE apns_token = md5('zzreal')||md5('zzreal2')),
    '160: a real install was refused during a flood';
  ASSERT EXISTS (SELECT 1 FROM public.live_activity_tokens WHERE token = md5('zzreal')||md5('zzreal2')||md5('zzreal3')),
    '160: a real LA token was refused during a flood';
  SELECT count(*) FILTER (WHERE target = 'rate_limit'), count(*) FILTER (WHERE target = 'la_rate_limit')
    INTO dt, la FROM public.pipeline_health
   WHERE stage = 'token_register' AND created_at = now();
  ASSERT dt BETWEEN 1 AND 2 AND la BETWEEN 1 AND 2,
    format('160: expected 1-2 log rows per table for a flood, got %s / %s', dt, la);
END $$;

-- The key in the binary reaches exactly the five app RPCs (plus three trigger
-- functions Postgres refuses to call outside a trigger).
DO $$
DECLARE extra text;
BEGIN
  SELECT string_agg(p.oid::regprocedure::text, ', ') INTO extra
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.prorettype <> 'trigger'::regtype
     AND has_function_privilege('anon', p.oid, 'EXECUTE')
     AND p.oid::regprocedure::text NOT IN (
       'register_device_token(text,text[],text[],integer,text,text)',
       'register_la_token(text,text,integer,text[],text,text[])',
       'save_match_calls(text,bigint,jsonb)',
       'log_events(uuid,jsonb)',
       'delete_app_events(uuid,integer,text)');
  ASSERT extra IS NULL, format('anon can execute more than the app RPCs: %s', extra);
  ASSERT (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
            AND p.prorettype <> 'trigger'::regtype
            AND has_function_privilege('anon', p.oid, 'EXECUTE')) = 5,
    'anon lost EXECUTE on one of the five app RPCs';
END $$;

\echo 'anon_rpc_limits_check: all asserts passed'
ROLLBACK;
