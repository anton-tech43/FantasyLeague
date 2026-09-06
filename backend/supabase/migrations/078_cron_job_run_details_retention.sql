-- 078_cron_job_run_details_retention.sql
-- Daily cron: prune pg_cron's own run log to 14 days.
--
-- Why (audit 2026-09, A16): cron.job_run_details had 177 070 rows / 88 MB on
-- 2026-09-06 — the second-largest relation in the DB — because pg_cron never
-- prunes it and match-watcher alone adds 1 440 rows/day. On a t4g.nano the
-- table contributed to the Disk-IO exhaustion that took prod down 30 Aug–6 Sep
-- (A14). Supabase's own guidance is a daily DELETE on end_time.
--
-- Applied manually to prod 2026-09-06 via audit/2026-09/cleanup_2026_09_06.sql
-- (schema_migrations is not tracked beyond 017 — see A12). Kept here so git
-- mirrors prod.

SELECT cron.unschedule('cron_job_run_details_retention_sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cron_job_run_details_retention_sweep');

SELECT cron.schedule(
  'cron_job_run_details_retention_sweep',
  '20 3 * * *',  -- 03:20 UTC, after pipeline_health (03:00) and raw_fetch_logs (03:15) sweeps
  $$DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL '14 days';$$
);

-- Verification:
--   SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'cron_job_run_details_retention_sweep';
--   SELECT count(*), min(start_time) FROM cron.job_run_details;   -- oldest ≤ 14 d
