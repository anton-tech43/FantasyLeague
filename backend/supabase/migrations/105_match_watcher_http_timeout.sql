-- 105_match_watcher_http_timeout.sql
-- A hung name lookup should not block the watcher for half a minute (2026-09-20).
--
-- pg_net cannot resolve the project's own hostname for hours at a time. From
-- net._http_response yesterday:
--
--   Timeout of 30000 ms reached. Total time: 30000.950000 ms (DNS time: 30000.950000 ms)
--   Timeout of 30000 ms reached. Total time: 30001.695000 ms (DNS time: 17947.905000 ms)
--
--   hour (UTC)   calls   timed out
--   16:00           13          13
--   19:00           10          10
--   20:00          223         174
--   21:00           61           0
--
-- Between 16:00 and 20:00 essentially every call from the database to the Edge
-- Function died before it was sent, and at 21:00 it recovered on its own. That
-- is the real cause of the `job startup timeout` storm that migration 104 did
-- NOT fix: pg_net runs a single background worker, a request that hangs 30s
-- occupies it, `net.http_post` inserts then contend, pg_cron's own writes to
-- job_run_details contend behind them, jobs cannot start, and the backlog
-- arrives later as a burst (235 runs in the 20:00 hour against a ceiling of 60).
-- Migration 103's claim_match_watcher_tick() is what keeps that burst from
-- becoming duplicate pushes.
--
-- The lookup itself is Supabase's to fix and is going to support with the
-- errors above. What is ours is how long we wait: 30s was chosen as "the whole
-- tick's budget" and is far more than a tick needs. Measured over seven days,
-- the slowest step inside a tick is the full-time page refresh at 1.2s average
-- and 4.1s worst case. 15s leaves better than three times that headroom and
-- frees the pg_net worker twice as fast when a lookup hangs.
--
-- Every other cron job here uses pg_net's 5s default and was never affected.

SELECT cron.unschedule('match-watcher-1min');

SELECT cron.schedule(
  'match-watcher-1min',
  '* * * * *',
  $job$
    SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 15000
    )
  $job$
);
