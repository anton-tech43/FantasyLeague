-- 048_morning_push_cron.sql
--
-- Schedules the new morning-push Edge Function to fire at 08:00 UTC
-- daily. The function queries today's fixtures (kickoff in next 18h)
-- and pushes a "Game day at <team>" notification to every device_token
-- subscribed to either side of each fixture.
--
-- Timezone choice: 08:00 UTC covers ~09:00 BST and ~10:00 CEST. Per-user
-- timezone scheduling is out of scope for V2.0; tracked as V2.1 (would
-- need a device_tokens.timezone column + a per-timezone queue).
--
-- Auth: uses the same get_cron_service_key() Vault accessor pattern as
-- goaldigger-daily-pipeline and goaldigger-cron-heartbeat-check
-- (migrations 019 + 045).

SELECT cron.schedule(
  'gd-morning-push',
  '0 8 * * *',
  $$
    SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/morning-push',
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
--    WHERE jobname = 'gd-morning-push';
-- Expected: schedule = '0 8 * * *', active = true.
