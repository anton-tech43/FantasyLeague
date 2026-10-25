#!/usr/bin/env bash
# io-attribution.sh — what is actually spending the Disk IO budget?
#
# Three times now the budget has been drained and three times the cause was
# named from a plausible story rather than a measurement (2026-06-01: guessed
# row count, was a missing composite index; 2026-08-30: "orsakshypotes, ej
# bevisad" because the stats had been wiped by the restart; 2026-10-24: open).
#
# A restart zeroes pg_stat_*, so the window right after one is the only time
# the counters mean "since a known moment". Run this once soon after a reboot
# and again ~24h later: the second run attributes the churn.
#
# Read-only. Needs SUPABASE_DB_URL.
set -uo pipefail
PSQL="${PSQL:-/opt/homebrew/opt/libpq/bin/psql}"
[ -n "${SUPABASE_DB_URL:-}" ] || { echo "SUPABASE_DB_URL not set (source backend/.env)" >&2; exit 1; }
q() { "$PSQL" "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=1 -c "$1"; }

echo "── WINDOW ────────────────────────────────────────────────"
q "SELECT pg_postmaster_start_time() AS postmaster_start,
         (SELECT stats_reset FROM pg_stat_database WHERE datname=current_database()) AS stats_reset,
         round(extract(epoch FROM now()-(SELECT stats_reset FROM pg_stat_database
              WHERE datname=current_database()))/3600, 2) AS window_hours;"

# Writes are what cost IO: every insert/update/delete dirties a page that must
# be written back, and on an unindexed read the heap churn costs more again.
echo "── WRITE PRESSURE PER TABLE (per hour, since stats_reset) ─"
q "WITH w AS (SELECT greatest(extract(epoch FROM now()-(SELECT stats_reset FROM pg_stat_database
                WHERE datname=current_database()))/3600, 0.01) AS h)
   SELECT relname,
          round((n_tup_ins+n_tup_upd+n_tup_del)/w.h)::bigint AS writes_per_h,
          n_tup_ins AS ins, n_tup_upd AS upd, n_tup_del AS del,
          n_dead_tup AS dead,
          pg_size_pretty(pg_total_relation_size(relid)) AS size
   FROM pg_stat_user_tables, w
   ORDER BY (n_tup_ins+n_tup_upd+n_tup_del) DESC LIMIT 15;"

# A sequential scan on a hot path reads the whole heap every time. That is how
# the June budget went: the index existed but did not match the query.
echo "── SEQ SCANS ON BIG TABLES (the June failure mode) ───────"
q "SELECT relname, seq_scan, idx_scan,
          CASE WHEN seq_scan>0 THEN (seq_tup_read/seq_scan)::bigint END AS avg_rows_per_seq_scan,
          pg_size_pretty(pg_total_relation_size(relid)) AS size
   FROM pg_stat_user_tables
   WHERE pg_total_relation_size(relid) > 8*1024*1024 AND seq_scan > 0
   ORDER BY seq_tup_read DESC LIMIT 10;"

# These three have no autovacuum (UNLOGGED or supabase_admin-owned) and are
# kept down only by the scheduled jobs from migrations 078/104.
echo "── THE TABLES THAT ONLY SCHEDULED VACUUM KEEPS DOWN ──────"
q "SELECT c.oid::regclass AS tbl, pg_size_pretty(pg_total_relation_size(c.oid)) AS size
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname||'.'||c.relname IN
     ('net._http_response','cron.job_run_details','public.raw_fetch_logs',
      'public.pipeline_health','public.team_page_prose_history');"

echo "── DID THE CLEANUP JOBS ACTUALLY RUN? ────────────────────"
q "SELECT j.jobname, max(r.start_time) AS last_run,
          max(r.start_time) FILTER (WHERE r.status='succeeded') AS last_success
   FROM cron.job j LEFT JOIN cron.job_run_details r USING (jobid)
   WHERE j.jobname LIKE '%vacuum%' OR j.jobname LIKE '%retention%'
   GROUP BY 1 ORDER BY 1;"
