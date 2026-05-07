-- 015_fix_cron_settings.sql
-- Fix two crons that reference `current_setting('app.settings.supabase_url')`
-- and `app.settings.service_role_key` — settings that aren't configured on
-- this Supabase project (and ALTER DATABASE is blocked for our role).
--
-- Symptoms before this fix:
--   - match-watcher-5min cron: 2,444 consecutive failures since deployment
--     ("ERROR: unrecognized configuration parameter app.settings.supabase_url")
--   - goaldigger-cron-heartbeat-check (013): silently no-ops because it
--     uses current_setting(..., true) which returns NULL, so net.http_post
--     gets a NULL URL and the POST never goes anywhere.
--
-- Fix: drop both crons and re-create with hardcoded URL + service_role_key,
-- matching the pattern that goaldigger-daily-pipeline (from migration 006)
-- already uses successfully.

-- Drop the broken jobs (idempotent — succeeds even if they don't exist)
SELECT cron.unschedule('match-watcher-5min')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-watcher-5min');

SELECT cron.unschedule('goaldigger-cron-heartbeat-check')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-cron-heartbeat-check');

-- Re-create match-watcher-5min with hardcoded auth.
SELECT cron.schedule(
    'match-watcher-5min',
    '*/5 * * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3Z3BzbWJ1bnJvY3JvZnppcWFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDYwNjc1NiwiZXhwIjoyMDkwMTgyNzU2fQ.YfGy-tG-7h7_rsAX3lLQ9mYJr-MtSWhtK1K7xAQlvGI'
        ),
        body := '{}'::jsonb
    )$$
);

-- Re-create goaldigger-cron-heartbeat-check. Calls the SQL function created
-- in migration 013, which now needs no external HTTP because we use a fixed
-- URL inside the function itself. We just need to update that function too.
SELECT cron.schedule(
    'goaldigger-cron-heartbeat-check',
    '*/30 * * * *',
    $$SELECT check_pipeline_heartbeat();$$
);

-- Replace the heartbeat function so it uses a hardcoded URL + key for the
-- net.http_post call (instead of current_setting which returns NULL).
CREATE OR REPLACE FUNCTION check_pipeline_heartbeat()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    last_fetch TIMESTAMPTZ;
    threshold INTERVAL := INTERVAL '26 hours';
BEGIN
    SELECT MAX(created_at) INTO last_fetch
    FROM pipeline_health
    WHERE stage = 'fetch' AND status = 'success';

    IF last_fetch IS NOT NULL AND last_fetch > NOW() - threshold THEN
        RETURN;
    END IF;

    -- Throttle: don't spam alerts.
    IF EXISTS (
        SELECT 1 FROM client_errors
        WHERE error_type = 'cron_silent_failure'
          AND created_at > NOW() - INTERVAL '2 hours'
    ) THEN
        RETURN;
    END IF;

    INSERT INTO client_errors (error_type, message, app_version)
    VALUES (
        'cron_silent_failure',
        FORMAT(
            'No data-fetcher pipeline_health row in the last %s. Last fetch: %s. Cron may have stopped.',
            threshold,
            COALESCE(last_fetch::TEXT, 'never')
        ),
        'backend-cron'
    );

    -- Fire client-error-alert so the dev iPhone gets a push immediately.
    PERFORM net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/client-error-alert',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3Z3BzbWJ1bnJvY3JvZnppcWFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDYwNjc1NiwiZXhwIjoyMDkwMTgyNzU2fQ.YfGy-tG-7h7_rsAX3lLQ9mYJr-MtSWhtK1K7xAQlvGI'
        ),
        body := jsonb_build_object(
            'error_type', 'cron_silent_failure',
            'message', 'data-fetcher cron has stopped firing. Check Supabase pg_cron status.',
            'app_version', 'backend-cron'
        )
    );
END;
$$;
