-- 131_raw_fetch_logs_three_days.sql
-- Cut raw_fetch_logs from seven days to three, and stop the weekly VACUUM FULL.
--
-- Why (the 2026-10-21 → 10-25 outage):
-- The instance stopped being able to START cron jobs at 2026-10-21 11:22 UTC
-- ("job startup timeout" ×268 on match-watcher), and degraded from 0.1 s
-- average job duration to 461 s over four days until nothing ran at all.
-- The known culprits were all clean — net._http_response at 48 kB, lesson 84's
-- composite index still in place, every retention sweep succeeding up to 10-22.
-- What was NOT clean: raw_fetch_logs at 87 MB of a 129 MB database, 67% of
-- everything, on an instance with six worker processes.
--
-- We cannot prove it was the trigger; the statistics that would have shown it
-- were reset by the restart that recovered the project. What we can say is that
-- it is the largest object in the database by a factor of ten, it is a cache of
-- raw upstream payloads, and nothing needs most of it.
--
-- Three days is not arbitrary. The widest reader is team-page-generator's
-- `.eq(team_id).order(fetched_at DESC).limit(100)`. Measured over the eight
-- days to 10-25, one club produces 73–89 rows a day, peaking at 126. Three days
-- is therefore between 2x and 3x the widest read, and the DISTINCT ON clause
-- below still preserves the latest row per (source, team_id) regardless of age,
-- so "get latest" can never lose data even for a source that stopped
-- refreshing. Expected steady state: ~11 MB of rows against ~37 MB today.
--
-- The VACUUM FULL is removed rather than rescheduled. Lesson 84 rule 3 says it
-- in as many words: "a locking VACUUM FULL to reclaim disk would have spiked
-- the very budget we were trying to protect". It rewrites the whole table and
-- takes an ACCESS EXCLUSIVE lock. On 2026-10-25 it ran for 32 minutes and
-- failed. pgnet_response_vacuum every six hours already keeps that table at
-- 48 kB, which is the proof the weekly rewrite was never what was holding it.

-- 1. Retention: seven days -> three.
SELECT cron.unschedule('raw_fetch_logs_retention_sweep');

SELECT cron.schedule(
  'raw_fetch_logs_retention_sweep',
  '15 3 * * *',
  $$
    DELETE FROM raw_fetch_logs r
    WHERE r.fetched_at < NOW() - INTERVAL '3 days'
      AND r.id NOT IN (
        SELECT DISTINCT ON (source, team_id) id
        FROM raw_fetch_logs
        ORDER BY source, team_id, fetched_at DESC
      );
  $$
);

-- 2. Drop the weekly VACUUM FULL. The six-hourly plain vacuum stays.
SELECT cron.unschedule('pgnet_response_vacuum_full')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pgnet_response_vacuum_full');

-- Verification:
--   SELECT jobname, schedule, active FROM cron.job
--    WHERE jobname IN ('raw_fetch_logs_retention_sweep','pgnet_response_vacuum_full');
--   -- expect one row (the sweep), and no pgnet_response_vacuum_full
--   SELECT pg_size_pretty(pg_total_relation_size('raw_fetch_logs'));
