-- 008_match_watcher_cron.sql
-- Schedule the match-watcher edge function to run every 5 minutes.
-- Detects PL fixture status transitions (e.g. LIVE → FT) and fires
-- the gd-matchday Claude Code Routine for both teams in the match.
--
-- Could be smarter (only matchdays, only during match windows ~12-23 UTC)
-- but 5min ticks across a day are well within our API-Football quota
-- (288 ticks/day × 1 call each = 288 calls/day, paid plan handles that fine).

SELECT cron.schedule(
    'match-watcher-5min',
    '*/5 * * * *',
    $$SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/match-watcher',
        body := '{}'::jsonb,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        )
    )$$
);
