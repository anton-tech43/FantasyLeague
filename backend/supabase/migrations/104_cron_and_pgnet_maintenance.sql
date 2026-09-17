-- 104_cron_and_pgnet_maintenance.sql
-- The per-minute watcher could not start (2026-09-18).
--
-- 18% of match-watcher-1min runs never ran. Over 24 hours: 1,097 succeeded at
-- 0.65s average, 237 failed at 68s average, worst case 879s. pg_cron reported
-- `job startup timeout` 758 times in three days, worst between 11:00 and 18:00
-- UTC where up to 48 of 60 minutes in an hour were lost. A minute that does not
-- run is a minute where a goal, a kickoff or a final whistle passes unseen.
--
-- pg_stat_statements, by total execution time:
--
--   153,463s / 29,645 calls / 5,177ms  pg_net's cleanup of net._http_response
--    24,779s / 15,990 calls / 1,550ms  update cron.job_run_details set status
--    22,602s /  2,139 calls /10,566ms  update … set status, return_message
--    18,229s / 15,990 calls / 1,140ms  insert into cron.job_run_details
--
-- pg_cron INSERTs into job_run_details before a job is allowed to start, so a
-- 1.1s insert IS the startup timeout. And net._http_response held 17 MB with
-- zero live rows: an unlogged table autovacuum never visits, scanned 29,645
-- times at 5.2s each. A manual VACUUM (FULL, ANALYZE) on 2026-09-17 took it
-- from 17 MB to 336 kB. This migration is what stops it coming back.
--
-- What this role may do: we connect as `postgres`, which here is NOT a
-- superuser and NOT a member of supabase_admin. cron.job_run_details and
-- net._http_response are owned by supabase_admin and we hold only MAINTAIN on
-- them (PG17), so VACUUM and ANALYZE work and ALTER TABLE … SET (autovacuum_…)
-- does not. `cron.log_run = off` and a bigger max_worker_processes both need
-- superuser or a restart, so neither is available from SQL.
--
-- THE CEILING: this database runs the smallest Supabase compute,
-- max_worker_processes = 6 and max_parallel_workers = 2. Everything below buys
-- headroom on that instance. If the failure rate does not drop after 24 hours,
-- the remaining cause is compute, and the fix is an upgrade in the Supabase
-- dashboard rather than more SQL.
--
-- Nothing here touches the push pipeline, poll_leagues() or any Edge Function.

-- ============================================================
-- 1. Two days of cron history, not fourteen
-- ============================================================
-- The per-minute job alone writes 1,440 rows a day, so 14 days is ~20,000 rows
-- of noise churning under every insert. Three days was more than enough to
-- diagnose this outage.

SELECT cron.unschedule('cron_job_run_details_retention_sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cron_job_run_details_retention_sweep');

SELECT cron.schedule(
  'cron_job_run_details_retention_sweep',
  '20 3 * * *',
  $$DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL '2 days'$$
);

-- ============================================================
-- 2. Vacuum the cron history every day
-- ============================================================
-- A DELETE leaves dead tuples behind; without a vacuum the table stays as slow
-- as it was. Two constraints shape this:
--   * VACUUM cannot run inside a transaction block, and pg_cron wraps a
--     multi-statement command in one, so this job holds exactly one statement
--     and runs five minutes after the DELETE rather than alongside it.
--   * Plain VACUUM, never FULL: pg_cron writes to this table every minute and
--     FULL would take an ACCESS EXCLUSIVE lock on it.

SELECT cron.unschedule('cron_job_run_details_vacuum')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cron_job_run_details_vacuum');

SELECT cron.schedule(
  'cron_job_run_details_vacuum',
  '25 3 * * *',
  $$VACUUM (ANALYZE) cron.job_run_details$$
);

-- ============================================================
-- 3. Keep pg_net's response table from growing again
-- ============================================================
-- autovacuum has never run on net._http_response: it is UNLOGGED, and the
-- statistics that would trigger autovacuum read zero. Left alone it reaches
-- 17 MB in about eight days and pg_net's own cleanup query then costs five
-- seconds a call, in the same background worker that dispatches our HTTP
-- requests.
--
-- Plain VACUUM four times a day keeps the space reusable so the table stops
-- growing. The weekly FULL hands the space back to the operating system; the
-- table holds near-zero live rows, so its exclusive lock is momentary.

SELECT cron.unschedule('pgnet_response_vacuum')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pgnet_response_vacuum');

SELECT cron.schedule(
  'pgnet_response_vacuum',
  '40 */6 * * *',
  $$VACUUM (ANALYZE) net._http_response$$
);

SELECT cron.unschedule('pgnet_response_vacuum_full')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pgnet_response_vacuum_full');

SELECT cron.schedule(
  'pgnet_response_vacuum_full',
  '10 4 * * 0',
  $$VACUUM (FULL, ANALYZE) net._http_response$$
);

-- ============================================================
-- 4. The one table we own
-- ============================================================
-- pipeline_health is ours, so it can be tuned properly rather than swept.
-- 27 MB and 49,721 rows with its last autovacuum six days earlier: the default
-- 20% dead-tuple threshold is far too lax for a table every push writes to.
-- 2% instead, and 30 days of history rather than 90 (nothing reads past a
-- month; the audits in this repo all look at days).

ALTER TABLE public.pipeline_health SET (
  autovacuum_vacuum_scale_factor  = 0.02,
  autovacuum_analyze_scale_factor = 0.02
);

SELECT cron.unschedule('pipeline_health_retention_sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pipeline_health_retention_sweep');

SELECT cron.schedule(
  'pipeline_health_retention_sweep',
  '0 3 * * *',
  $$DELETE FROM pipeline_health WHERE created_at < NOW() - INTERVAL '30 days'$$
);

-- One-off catch-up so the new retention takes effect tonight rather than
-- leaving 60 days of rows in place until the next sweep.
DELETE FROM public.pipeline_health WHERE created_at < NOW() - INTERVAL '30 days';
VACUUM (ANALYZE) public.pipeline_health;
