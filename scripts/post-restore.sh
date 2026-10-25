#!/usr/bin/env bash
# post-restore.sh — the first sixty seconds after the database answers again.
#
# pg_cron starts firing the moment the instance is up: match-watcher every
# minute, plus whatever the 03:00 maintenance block queued. If the Disk IO
# budget is still thin that load can spend it again before anyone has looked
# at why it went. So: read the evidence FIRST, while it is still true, and
# only then decide whether to let the minute clock back in.
#
# Read-only. Prints the three answers and a suggested next step. Nothing is
# changed here — the unschedule is printed for you to run, not run for you.
set -uo pipefail
PSQL="${PSQL:-/opt/homebrew/opt/libpq/bin/psql}"
[ -n "${SUPABASE_DB_URL:-}" ] || { echo "SUPABASE_DB_URL not set (source backend/.env)" >&2; exit 1; }
q() { "$PSQL" "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=1 -c "$1" 2>&1; }

echo "── 1. IS ANY SLOT HOLDING WAL? (the hypothesis) ──────────"
q "SELECT slot_name, plugin, active, active_pid,
          pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_pinned
   FROM pg_replication_slots ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;"
q "SELECT pg_size_pretty(sum(size)) AS wal_total, count(*) AS segments FROM pg_ls_waldir();"

echo
echo "── 2. HOW BIG IS THE DATABASE REALLY? ────────────────────"
# September saw 478 MB on the dashboard against 308 MB here and never explained
# the gap. WAL is the usual answer; this is where it shows.
q "SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size;"

echo
echo "── 3. WHAT RAN LAST BEFORE IT DIED? ──────────────────────"
q "SELECT j.jobname, max(r.start_time) AS last_run, max(r.end_time) AS last_end
   FROM cron.job j LEFT JOIN cron.job_run_details r USING (jobid)
   GROUP BY 1 ORDER BY 2 DESC NULLS LAST LIMIT 12;"

cat <<'NOTE'

── IF A SLOT IS INACTIVE AND HOLDING GB ──────────────────
An inactive slot pins every WAL segment after its bookmark. Dropping it lets
the next checkpoint recycle all of it. Realtime recreates its own slot when
the service next needs one, and nothing in this app subscribes to Realtime,
so there is no consumer to lose:

    SELECT pg_drop_replication_slot('<slot_name>');   -- only when active = f

── TO TAKE THE LOAD OFF WHILE YOU LOOK ───────────────────
match-watcher is the only per-minute job. Pausing it costs live goal, kickoff
and FT pushes, so it is a deliberate trade for a quiet window, not a fix:

    UPDATE cron.job SET active = false WHERE jobname = 'match-watcher-1min';
    UPDATE cron.job SET active = true  WHERE jobname = 'match-watcher-1min';
NOTE
