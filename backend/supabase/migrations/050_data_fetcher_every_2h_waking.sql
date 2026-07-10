-- 050_data_fetcher_every_2h_waking.sql
--
-- Walk data-fetcher back from hourly (migration 045) to EVERY 2 HOURS
-- DURING WAKING HOURS (06:00-22:00 UTC = ~07:00-23:00 BST). Quiet
-- between 22:00 and 06:00 UTC — no news lands overnight that we can't
-- wait until 06:00 for, and overnight fires were doubling our API spend
-- for zero user value.
--
-- Migration 045 (hourly, all 24h) burned through API-Football's
-- 7,500/day Pro-tier quota by ~18:00 UTC on May 18, which killed
-- match-watcher's fixture polling and broke Arsenal-Burnley's FT push.
--
-- Budget math (steady state):
--   - Per data-fetcher fire: ~430 API-Football calls (71 teams ×
--     ~6 endpoints + 2 league standings).
--   - Every 2h × 9 waking fires (06,08,10,12,14,16,18,20,22 UTC) =
--     ~3,870 calls/day from data-fetcher.
--   - match-watcher = 2 leagues × 1440 ticks/day = 2,880 calls/day.
--   - Total: ~6,750 calls/day. Under the 7,500/day Pro-tier ceiling
--     with ~750 headroom for ad-hoc work (one-off regenerations,
--     manual smoke tests).
--
-- Cron syntax: `0 6-22/2 * * *` = minute 0 of every 2nd hour in the
-- range [6,22] UTC inclusive. Produces 9 fires/day.
--
-- See IMPLEMENTATION_PROGRESS.md Lesson 71 for the full debug arc.

SELECT cron.unschedule('goaldigger-daily-pipeline');

SELECT cron.schedule(
  'goaldigger-daily-pipeline',
  '0 6-22/2 * * *',
  $$
    SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/data-fetcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb
    )
  $$
);

-- Verification:
--   SELECT jobname, schedule, active FROM cron.job
--    WHERE jobname = 'goaldigger-daily-pipeline';
-- Expected: schedule = '0 6-22/2 * * *', active = true.
