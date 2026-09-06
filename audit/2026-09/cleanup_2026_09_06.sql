-- audit/2026-09/cleanup_2026_09_06.sql
-- Tre åtgärder beslutade av Anton 2026-09-06 efter B1 (se SJALVRANNSAKAN_2026-09.md A14/A16, §4).
-- Körs av Anton mot prod:  set -a && source backend/.env && set +a &&
--   /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -X -v ON_ERROR_STOP=1 -f audit/2026-09/cleanup_2026_09_06.sql
--
-- Förutsättningar (uppfyllda 11:45–12:05 CEST): snapshoten i audit/2026-09/out/ är committad,
-- inkl. 42_cron_runs_daily_all.csv (hela cron-historiken aggregerad) och 39_raw_fetch_logs_by_source.csv.
-- VACUUM FULL tar ACCESS EXCLUSIVE-lås ~10–60 s per tabell; pg_cron-inserts och data-fetcher köar.
-- Undvik att köra kl 06,08,…,22 UTC ±2 min (data-fetcher) — i övrigt fritt.

\timing on
\set ON_ERROR_STOP on

\echo
\echo '=== 1/3  raw_fetch_logs: retention-sweepens egen DELETE (samma sats som cron 21), sedan VACUUM FULL ==='
SELECT count(*) AS before_rows, pg_size_pretty(pg_total_relation_size('raw_fetch_logs')) AS before_size FROM raw_fetch_logs;
DELETE FROM raw_fetch_logs r
WHERE r.fetched_at < NOW() - INTERVAL '7 days'
  AND r.id NOT IN (SELECT DISTINCT ON (source, team_id) id FROM raw_fetch_logs ORDER BY source, team_id, fetched_at DESC);
VACUUM (FULL, ANALYZE) raw_fetch_logs;
SELECT count(*) AS after_rows, pg_size_pretty(pg_total_relation_size('raw_fetch_logs')) AS after_size FROM raw_fetch_logs;

\echo
\echo '=== 2/3  cron.job_run_details: gallra >14 d, VACUUM FULL, ny daglig gallrings-cron (mig 078) ==='
SELECT count(*) AS before_rows, pg_size_pretty(pg_total_relation_size('cron.job_run_details')) AS before_size FROM cron.job_run_details;
DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL '14 days';
VACUUM (FULL, ANALYZE) cron.job_run_details;
SELECT count(*) AS after_rows, pg_size_pretty(pg_total_relation_size('cron.job_run_details')) AS after_size,
       min(start_time) AS oldest_utc FROM cron.job_run_details;
SELECT cron.unschedule('cron_job_run_details_retention_sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cron_job_run_details_retention_sweep');
SELECT cron.schedule(
  'cron_job_run_details_retention_sweep',
  '20 3 * * *',   -- 03:20 UTC, efter pipeline_health (03:00) och raw_fetch_logs (03:15)
  $$DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL '14 days';$$
);
SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'cron_job_run_details_retention_sweep';

\echo
\echo '=== 3/3  VM-länder inaktiva (mig 079): data-fetcher, content-audit och team-page-generator hoppar över dem ==='
SELECT entity_type, is_active, count(*) FROM teams GROUP BY 1,2 ORDER BY 1,2;
BEGIN;
UPDATE teams SET is_active = false WHERE entity_type = 'country' AND is_active;
-- Förväntat: UPDATE 48. Rulla tillbaka om inte.
SELECT count(*) AS countries_now_inactive FROM teams WHERE entity_type='country' AND NOT is_active;
COMMIT;
SELECT entity_type, is_active, count(*) FROM teams GROUP BY 1,2 ORDER BY 1,2;

\echo
\echo '=== Slutläge ==='
SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size_now;
SELECT jobname, schedule, active FROM cron.job ORDER BY jobname;
