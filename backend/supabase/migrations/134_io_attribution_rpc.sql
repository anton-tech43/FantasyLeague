-- 134_io_attribution_rpc.sql
-- The Disk IO measurement, readable from outside the database.
--
-- scripts/io-attribution.sh needs psql and SUPABASE_DB_URL. The routine
-- sandbox has neither — it has the REST URL and a service key. That is the
-- same split that made the October outage invisible for four days: everything
-- that could see the problem needed the thing that was broken.
--
-- Three times the budget has been drained and three times the cause was named
-- from a plausible story rather than a measurement. A restart zeroes pg_stat_*,
-- so the counters only mean "since a known moment" in the window after one.
-- This makes that window readable on a schedule, from anywhere.
--
-- Returns one JSONB document rather than a row set: the caller is a shell
-- script formatting a report, not a query planner.

CREATE OR REPLACE FUNCTION public.get_io_attribution()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, cron, net, pg_temp
AS $$
  -- pg_stat_database.stats_reset is NULL until something resets the counters,
  -- and a restart does not always record one — it read NULL on 2026-10-25,
  -- which made window_hours NULL and every per-hour figure with it. The
  -- counters start from zero at startup either way, so fall back to that.
  WITH w AS (
    SELECT greatest(extract(epoch FROM now() - coalesce(
             (SELECT stats_reset FROM pg_stat_database WHERE datname = current_database()),
             pg_postmaster_start_time())
           ) / 3600, 0.01) AS hours
  )
  SELECT jsonb_build_object(
    'measured_at', now(),
    'postmaster_start', pg_postmaster_start_time(),
    'stats_reset', coalesce((SELECT stats_reset FROM pg_stat_database WHERE datname = current_database()),
                            pg_postmaster_start_time()),
    'window_hours', round((SELECT hours FROM w)::numeric, 2),
    'db_size_mb', round(pg_database_size(current_database()) / 1048576.0, 1),
    'wal_mb', (SELECT round(sum(size) / 1048576.0, 1) FROM pg_ls_waldir()),
    'replication_slots', (SELECT count(*) FROM pg_replication_slots),
    -- Writes are what cost IO: each one dirties a page that must be written back.
    'top_writers', (
      SELECT jsonb_agg(x) FROM (
        SELECT relname AS tbl,
               round((n_tup_ins + n_tup_upd + n_tup_del) / (SELECT hours FROM w)) AS writes_per_h,
               n_dead_tup AS dead,
               round(pg_total_relation_size(relid) / 1048576.0, 1) AS mb
        FROM pg_stat_user_tables
        ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) DESC LIMIT 8
      ) x),
    -- The June failure mode: an index that did not cover the whole predicate,
    -- so every lookup read dozens of large rows off disk to filter the rest.
    'heap_churn', (
      SELECT jsonb_agg(x) FROM (
        SELECT relname AS tbl, idx_scan,
               CASE WHEN idx_scan > 0 THEN round(idx_tup_fetch::numeric / idx_scan, 1) END AS rows_per_index_scan,
               seq_scan
        FROM pg_stat_user_tables
        WHERE pg_total_relation_size(relid) > 8 * 1024 * 1024 AND idx_scan > 0
        ORDER BY idx_tup_fetch DESC LIMIT 5
      ) x),
    -- These have no autovacuum of their own and are held down only by the
    -- scheduled jobs from migrations 057/078/104/131.
    'vacuum_dependent', (
      SELECT jsonb_object_agg(tbl, mb) FROM (
        SELECT c.oid::regclass::text AS tbl, round(pg_total_relation_size(c.oid) / 1048576.0, 1) AS mb
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname || '.' || c.relname IN
          ('net._http_response', 'cron.job_run_details', 'public.raw_fetch_logs',
           'public.pipeline_health', 'public.team_page_prose_history')
      ) y),
    'cron_24h', (
      SELECT jsonb_build_object(
        'runs', count(*),
        'startup_timeouts', count(*) FILTER (WHERE return_message = 'job startup timeout'),
        'other_failures', count(*) FILTER (WHERE status <> 'succeeded'
                            AND return_message IS DISTINCT FROM 'job startup timeout'),
        'max_seconds', round(max(extract(epoch FROM end_time - start_time))::numeric, 1),
        'avg_seconds', round(avg(extract(epoch FROM end_time - start_time))::numeric, 2))
      FROM cron.job_run_details WHERE start_time > now() - interval '24 hours')
  );
$$;

REVOKE ALL ON FUNCTION public.get_io_attribution() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_io_attribution() TO service_role;

-- Verification:
--   SELECT jsonb_pretty(get_io_attribution());
--   SELECT has_function_privilege('anon','public.get_io_attribution()','EXECUTE'); -- f
