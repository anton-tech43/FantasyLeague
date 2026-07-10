-- 045_data_fetcher_hourly_cadence.sql
-- Bump data-fetcher cron from daily to hourly.
--
-- Why:
-- WC 2026 kickoff is June 11. API-Football publishes the final 26-player
-- squad lists ~2 weeks before kickoff (May 28 onwards) — announcements
-- trickle in at unpredictable hours, often US daytime = European evening,
-- but not always. Today's daily fire at 07:00 UTC means a squad
-- announcement at 09:00 UTC waits 22 hours to land in raw_fetch_logs,
-- which is too long when downstream routines (gd-news-wc) are reading
-- it 2x/day.
--
-- New schedule: hourly at the top of every hour (0 * * * *).
-- Worst-case latency from squad announcement → raw_fetch_logs: 60 min.
--
-- Why hourly and not every 30 min:
-- data-fetcher makes ~70-80 API-Football calls per fire (68 teams ×
-- /players/squads endpoint + fixtures + standings). Hourly = ~1,900
-- calls/day, comfortably under API-Football Pro tier (7,500/day).
-- Every-30-min = ~3,800/day = closer to the ceiling without meaningful
-- freshness gain. Hourly is the right balance.
--
-- This is permanent, not a 2-week window. The freshness benefit applies
-- year-round; the WC squad window is just the immediate motivation.

-- Drop the existing daily schedule.
SELECT cron.unschedule('goaldigger-daily-pipeline');

-- Re-schedule hourly. Same command body — only the schedule changes.
SELECT cron.schedule(
  'goaldigger-daily-pipeline',
  '0 * * * *',
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
-- Expected: schedule = '0 * * * *', active = true.
