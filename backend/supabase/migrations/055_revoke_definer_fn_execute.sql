-- 055_revoke_definer_fn_execute.sql
--
-- 🔴 CRITICAL pre-launch fix. Three SECURITY DEFINER functions in the
-- public schema had EXECUTE granted to anon + authenticated (the
-- Postgres default grants EXECUTE to PUBLIC on function creation, and
-- PostgREST exposes public-schema functions as RPC endpoints).
--
-- The catastrophic one:
--
--   get_cron_service_key() — SECURITY DEFINER, reads
--   vault.decrypted_secrets and RETURNS the decrypted cron_service_key
--   (the service_role JWT). With anon EXECUTE, ANYONE holding the
--   publishable key (embedded + extractable from the iOS binary) could:
--       POST /rest/v1/rpc/get_cron_service_key
--   and receive the service_role key → bypass ALL RLS, read/modify/
--   delete every table, dump the entire user base. Full compromise.
--
-- The other two are internal diagnostics that shouldn't be anon-callable
-- either:
--   get_device_tokens_acl()    — RLS/grant introspection (migration 030)
--   get_pipeline_diagnostics() — pipeline health dump (migration 029/036)
--
-- FIX: revoke EXECUTE from PUBLIC + anon + authenticated on all three.
-- They remain callable by the table owner (postgres) and service_role,
-- which is all that's needed:
--   - get_cron_service_key is only ever called inside pg_cron job SQL,
--     which runs as the job owner (postgres) — unaffected by these
--     revokes.
--   - the diagnostics are run manually as service_role / via the
--     diagnose-matchday Edge Function (service key) — unaffected.
-- No Edge Function or iOS path calls any of these three via the anon
-- role.
--
-- See STATUS.md launch-day security audit + Lesson 79.

REVOKE EXECUTE ON FUNCTION public.get_cron_service_key()     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_device_tokens_acl()    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_pipeline_diagnostics() FROM PUBLIC, anon, authenticated;
