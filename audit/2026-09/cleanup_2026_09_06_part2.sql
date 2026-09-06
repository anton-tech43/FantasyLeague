-- Del 2 av cleanup_2026_09_06.sql — de steg som inte gick igenom i första körningen
-- (ny gallrings-cron för cron.job_run_details + 48 VM-länder inaktiva).
-- Kör:  set -a && source backend/.env && set +a &&
--   /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -X -v ON_ERROR_STOP=1 -f audit/2026-09/cleanup_2026_09_06_part2.sql
\set ON_ERROR_STOP on

\echo '=== 2b  ny daglig gallrings-cron (mig 078) ==='
SELECT cron.schedule(
  'cron_job_run_details_retention_sweep',
  '20 3 * * *',
  'DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL ''14 days'';'
);
SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'cron_job_run_details_retention_sweep';

\echo '=== 3   48 VM-länder inaktiva (mig 079) ==='
UPDATE teams SET is_active = false WHERE entity_type = 'country' AND is_active;
SELECT entity_type, is_active, count(*) FROM teams GROUP BY 1,2 ORDER BY 1,2;
