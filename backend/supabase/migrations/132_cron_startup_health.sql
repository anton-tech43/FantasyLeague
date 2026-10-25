-- 132_cron_startup_health.sql
-- One question the external heartbeat could not ask: is pg_cron still able to
-- START its jobs?
--
-- Why (the 2026-10-21 outage):
-- The first symptom was 'job startup timeout' on match-watcher at 2026-10-21
-- 11:22 UTC, 268 of them that day. That is not a job failing; it is the
-- scheduler unable to launch a worker at all. For three more days the
-- heartbeat kept passing, because everything it asks about was still true:
-- REST answered, content was recent, fetches were landing. The pipeline was
-- draining slowly rather than stopping, so no threshold tripped until
-- 10-24 06:17, by which point the instance was unrecoverable without a resize.
--
-- A startup timeout is the earliest honest signal we have. It is visible four
-- days before anything a user would notice, and it is zero on a healthy day
-- (2026-10-20: 1326 runs, zero failures).
--
-- SECURITY DEFINER because cron.job_run_details is owned by supabase_admin and
-- the service role cannot read it directly. Returns counts only — no command
-- bodies, which is what keeps this safe to expose to a key that lives in a
-- routine sandbox.

CREATE OR REPLACE FUNCTION public.get_cron_startup_health()
RETURNS TABLE (startup_timeouts_1h bigint, other_failures_1h bigint,
               runs_1h bigint, slowest_job text, slowest_seconds numeric)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, cron, pg_temp
AS $$
  WITH r AS (
    SELECT d.status, d.return_message, j.jobname,
           extract(epoch FROM d.end_time - d.start_time) AS secs
    FROM cron.job_run_details d JOIN cron.job j USING (jobid)
    WHERE d.start_time > now() - interval '1 hour'
  )
  SELECT count(*) FILTER (WHERE return_message = 'job startup timeout'),
         count(*) FILTER (WHERE status <> 'succeeded'
                            AND return_message IS DISTINCT FROM 'job startup timeout'),
         count(*),
         (SELECT jobname FROM r ORDER BY secs DESC NULLS LAST LIMIT 1),
         round((SELECT max(secs) FROM r)::numeric, 1)
  FROM r;
$$;

-- CLAUDE.md: every function is born with an implicit EXECUTE to PUBLIC that no
-- ALTER DEFAULT PRIVILEGES on this database removes, and `FROM PUBLIC` alone
-- does not touch the explicit grants Supabase hands anon/authenticated. Name
-- all three, then check the result rather than the statement.
REVOKE ALL ON FUNCTION public.get_cron_startup_health() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_cron_startup_health() TO service_role;

-- Verification:
--   SELECT * FROM get_cron_startup_health();
--   SELECT has_function_privilege('anon','public.get_cron_startup_health()','EXECUTE');
--   -- expect f
