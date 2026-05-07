-- 013_cron_heartbeat_alert.sql
-- Make silent cron failures loud.
--
-- Today: data-fetcher cron is supposed to fire daily at 07:00 UTC and write a
-- pipeline_health row per team with stage='fetch'. If the cron silently stops
-- firing (Supabase issue, secret rotation, job removed), nobody finds out
-- until users complain about a stale feed days later.
--
-- This migration adds:
--   1. A SQL function `check_pipeline_heartbeat()` that inspects pipeline_health
--      for recent 'fetch' rows and inserts into client_errors if none found
--      in the expected window.
--   2. A pg_cron entry that runs that function every 30 min.
--
-- The existing client-error-alert edge function picks up new client_errors
-- rows (via the iOS-error reporting path, but it polls — see throttling
-- via alerted_at column). To wire this trigger into push delivery without
-- waiting for the iOS code path, we directly POST to client-error-alert
-- via pg_net so the dev iPhone gets a push within minutes.

-- 1. The check function
CREATE OR REPLACE FUNCTION check_pipeline_heartbeat()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    last_fetch TIMESTAMPTZ;
    threshold INTERVAL := INTERVAL '26 hours';  -- data-fetcher runs daily; 26h gives a 2h grace window
    error_id UUID;
BEGIN
    -- Find the most recent successful 'fetch' event across any team.
    SELECT MAX(created_at) INTO last_fetch
    FROM pipeline_health
    WHERE stage = 'fetch' AND status = 'success';

    -- Healthy path: fetch happened within the threshold.
    IF last_fetch IS NOT NULL AND last_fetch > NOW() - threshold THEN
        RETURN;
    END IF;

    -- Throttle: don't spam alerts. Only insert if the last cron_silent_failure
    -- alert is older than 2 hours (matches the 30-min check cadence × 4).
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
    )
    RETURNING id INTO error_id;

    -- Fire the client-error-alert edge function so the dev iPhone gets a push
    -- without waiting for an iOS poll. Best-effort; if pg_net is unavailable
    -- the row still sits in client_errors for the next iOS poll to find.
    PERFORM net.http_post(
        url := current_setting('app.settings.supabase_url', true) || '/functions/v1/client-error-alert',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := jsonb_build_object(
            'error_type', 'cron_silent_failure',
            'message', 'data-fetcher cron has stopped firing. Check Supabase pg_cron status.',
            'app_version', 'backend-cron'
        )
    );
END;
$$;

-- 2. Schedule the check every 30 min.
SELECT cron.schedule(
    'goaldigger-cron-heartbeat-check',
    '*/30 * * * *',
    $$SELECT check_pipeline_heartbeat();$$
);
