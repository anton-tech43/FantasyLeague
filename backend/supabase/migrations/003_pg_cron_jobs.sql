-- 003_pg_cron_jobs.sql
-- Goal Digger — Scheduled jobs via pg_cron
-- Requires: pg_cron and pg_net extensions enabled in Supabase

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================
-- CORE PIPELINE CRON JOBS
-- ============================================================

-- Data fetcher: every 30 minutes, 08:00-23:00 GMT
SELECT cron.schedule(
    'data-fetcher',
    '*/30 8-23 * * *',
    $$SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/data-fetcher',
        body := '{}'::jsonb,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        )
    )$$
);

-- Matchday scheduler: daily at 07:00 UTC
SELECT cron.schedule(
    'matchday-scheduler',
    '0 7 * * *',
    $$SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/matchday-scheduler',
        body := '{}'::jsonb,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        )
    )$$
);

-- Notification sweep: hourly safety net for any approved but unpublished items
SELECT cron.schedule(
    'notification-sweep',
    '15 * * * *',
    $$SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/notification-sender',
        body := '{}'::jsonb,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        )
    )$$
);

-- ============================================================
-- CLEANUP CRON JOBS (from RUNBOOK.md)
-- ============================================================

-- Weekly: delete raw fetch logs older than 7 days (tight storage budget)
SELECT cron.schedule(
    'cleanup-raw-logs',
    '0 3 * * 0',
    $$DELETE FROM raw_fetch_logs WHERE fetched_at < NOW() - INTERVAL '7 days'$$
);

-- Weekly: delete pipeline health logs older than 90 days
SELECT cron.schedule(
    'cleanup-health-logs',
    '10 3 * * 0',
    $$DELETE FROM pipeline_health WHERE created_at < NOW() - INTERVAL '90 days'$$
);

-- Weekly: delete rejected content items older than 14 days
SELECT cron.schedule(
    'cleanup-rejected-content',
    '20 3 * * 0',
    $$DELETE FROM content_items
      WHERE status = 'rejected' AND created_at < NOW() - INTERVAL '14 days'$$
);

-- ============================================================
-- HELPER FUNCTION: Schedule one-off matchday jobs
-- Used by matchday-scheduler Edge Function
-- ============================================================

CREATE OR REPLACE FUNCTION schedule_matchday_job(
    job_name TEXT,
    cron_expression TEXT,
    function_url TEXT,
    service_key TEXT,
    payload TEXT
) RETURNS void AS $$
BEGIN
    -- Remove existing job with same name (idempotent)
    PERFORM cron.unschedule(job_name);

    -- Schedule the one-off job
    PERFORM cron.schedule(
        job_name,
        cron_expression,
        format(
            'SELECT net.http_post(url := %L, body := %L::jsonb, headers := jsonb_build_object(''Content-Type'', ''application/json'', ''Authorization'', ''Bearer %s''))',
            function_url,
            payload,
            service_key
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to schedule matchday job %: %', job_name, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
