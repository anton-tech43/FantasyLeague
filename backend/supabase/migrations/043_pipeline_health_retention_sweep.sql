-- 043_pipeline_health_retention_sweep.sql
-- Daily cron: delete pipeline_health rows older than 90 days.
--
-- Why:
-- At ~5 rows/min baseline (match-watcher fires + APNs sends + routine
-- posts + cron invokes), pipeline_health grows ~7,200 rows/day. WC
-- matchdays will push that to 10-15k/day for ~30 days. By end of WC
-- the table will be ~600k rows. The new (stage, created_at DESC) and
-- (target) indexes from migration 038 bloat with row count; query plans
-- for CHECK 1-5 stay sub-second only while the working set is small.
--
-- 90-day retention is enough for:
--  - heartbeat checks (30-min lookback windows in CHECK 1-5)
--  - incident postmortems (typical < 2 weeks back)
--  - quarterly trend analysis
--
-- pipeline_health is observability, not the source of truth for any
-- user-facing data. Deleting old rows is safe; nothing depends on
-- pipeline_health rows older than 30 days.

SELECT cron.schedule(
  'pipeline_health_retention_sweep',
  '0 3 * * *',  -- daily at 03:00 UTC = 04:00/05:00 Stockholm (low-traffic)
  $$
    DELETE FROM pipeline_health
    WHERE created_at < NOW() - INTERVAL '90 days';
  $$
);

-- Verification:
--   SELECT jobname, schedule, active FROM cron.job
--    WHERE jobname = 'pipeline_health_retention_sweep';
-- Expected: one row, schedule = '0 3 * * *', active = TRUE.
--
-- On day one of the sweep, nothing will be deleted (pipeline_health
-- only started getting heavy writes today). Once we cross the 90-day
-- horizon (~mid-August), the sweep will start removing the oldest rows.
