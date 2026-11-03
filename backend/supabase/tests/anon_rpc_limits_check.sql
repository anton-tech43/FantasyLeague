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
