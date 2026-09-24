-- 118_close_device_tokens_and_the_function_default.sql
-- Three things the 2026-09-24 red-team pass found in migrations 108, 115 and 116.
-- All three are cases of a statement that reads as the fix and is not.
--
-- ONE. `device_tokens` has NO TRIGGERS. The rate limit that migration 108
-- rewrote so carefully — warn at 500/hour, hard cap at 20 000 — has never once
-- run, because `enforce_token_rate_limit` is absent from production. So is
-- `enforce_device_token_columns`. Both are created by 001_initial_schema.sql
-- and no migration in the repo drops either, so this is undetected drift.
-- Migration 116 then listed `check_token_rate_limit` under "NOT touched,
-- deliberately — it is a trigger function", reasoning from the migration files
-- instead of `pg_trigger`. That is the same mistake 072 made with policy names
-- and 084/095/096/103 made with FROM PUBLIC.
--
-- TWO. The `device_tokens` INSERT/UPDATE that 115 kept for App Store 2.2 buys
-- nothing. 2.2's only direct write was `APIClient.updateTokenTier`, a
-- `PATCH /rest/v1/device_tokens?apns_token=eq.<token>` — and a FILTERED update
-- needs SELECT on the column in the WHERE clause, which migration 106 revoked
-- on 2026-09-23. Verified: has_table_privilege('anon','device_tokens','SELECT')
-- is false, and the UPDATE plans as "permission denied for table". That screen
-- has been failing since 106 regardless of 115. Registration itself never used
-- the grant: it goes through `register_device_token`, SECURITY DEFINER, owned
-- by postgres.
--
-- So the grant was pure attack surface. RLS behind it is `WITH CHECK (true)`,
-- which means a POST of a JSON ARRAY to /rest/v1/device_tokens inserts as many
-- rows as fit in the statement timeout, with no trigger to count them (see ONE)
-- — and `notification-sender` then fans every goal, HT and FT push out across
-- them before APNs 410 cleans up, on the compute that fell over on 30 August.
-- This is what `107_drop_anon_token_write.sql.PENDING_APP_RELEASE` was waiting
-- to do once 2.3 shipped. The wait is over: there is nothing left to break.
--
-- THREE. 116's `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM
-- anon, authenticated` does not close a new function. It removes the two
-- explicit grants Supabase seeds, but every function is BORN with an implicit
-- `EXECUTE TO PUBLIC`, and anon inherits through PUBLIC. Migration 117 proved
-- it one migration later: `player_name_parts` and `player_first_key` came out
-- with `=X/postgres` in their ACL and anon can execute both.
--
-- AND THE DEFAULT CANNOT BE MADE TO DO IT. Both documented forms were tried
-- here against this database and a newly created function still came out
-- anon-executable:
--     ALTER DEFAULT PRIVILEGES IN SCHEMA public
--       REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
--     ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
--       REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
-- `pg_default_acl` already held a row without PUBLIC, so revoking a grantee
-- that is not in it is a no-op, and the built-in PUBLIC default is applied on
-- top regardless. Tables and sequences DO respond to this (verified: a new
-- table comes out SELECT-only, a new sequence unwritable) — functions do not.
--
-- So the honest rule is the opposite of what 116 wrote: the default will not
-- save you, EVERY `CREATE FUNCTION` needs its own REVOKE, and the only
-- reliable defence is noticing. `scripts/db-health.sh` section 7 now lists
-- every anon-executable function outside the app's three RPCs and FAILs on it.
-- That check was tested by creating a bare function and watching it fail.

BEGIN;

-- ONE ---------------------------------------------------------------------
-- Re-attach the rate limit to the table it was written for. 108's body is
-- already correct (it counts recent rows and warns before it refuses, rather
-- than locking out the next honest installer).
DROP TRIGGER IF EXISTS enforce_token_rate_limit ON public.device_tokens;
CREATE TRIGGER enforce_token_rate_limit
  BEFORE INSERT ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.check_token_rate_limit();

-- `enforce_device_token_columns` is deliberately NOT restored: it existed to
-- stop an anon UPDATE rewriting apns_token/is_active, and after the revoke
-- below there is no anon UPDATE to guard.

-- TWO ---------------------------------------------------------------------
REVOKE INSERT, UPDATE ON public.device_tokens FROM anon, authenticated;
DROP POLICY IF EXISTS device_tokens_anon_insert ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_anon_update ON public.device_tokens;

-- THREE -------------------------------------------------------------------
-- The revoke that actually closes a new function, and the sequences 115's
-- ON TABLES clause did not cover.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;

-- The two that leaked out of 117 before the default was right.
REVOKE EXECUTE ON FUNCTION public.player_name_parts(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.player_first_key(text)  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;

COMMIT;

-- Self-check: assert the state, not the statements. This is the query whose
-- absence let 084, 095, 096, 103, 108, 115 and 116 all report success.
DO $check$
DECLARE bad text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'public.device_tokens'::regclass
                    AND NOT tgisinternal AND tgname = 'enforce_token_rate_limit')
    THEN bad := bad || ' rate-limit-trigger-missing'; END IF;
  IF has_table_privilege('anon','public.device_tokens','INSERT')
     OR has_table_privilege('anon','public.device_tokens','UPDATE')
    THEN bad := bad || ' anon-can-still-write-device_tokens'; END IF;
  IF has_function_privilege('anon','public.player_name_parts(text)','EXECUTE')
     OR has_function_privilege('anon','public.player_first_key(text)','EXECUTE')
    THEN bad := bad || ' leaked-117-functions-still-open'; END IF;
  IF NOT has_function_privilege('anon','public.register_device_token(text,text[],text[],integer,text,text)','EXECUTE')
    THEN bad := bad || ' registration-rpc-closed-by-mistake'; END IF;
  IF bad <> '' THEN RAISE EXCEPTION 'migration 118 self-check failed:%', bad; END IF;
  RAISE NOTICE 'migration 118 self-check passed';
END
$check$;
