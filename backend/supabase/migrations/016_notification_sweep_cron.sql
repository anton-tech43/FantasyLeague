-- 016_notification_sweep_cron.sql
-- Schedule the hourly notification-sender sweep that catches unpushed items.
--
-- Migration 003 was supposed to create this cron, but it never landed on
-- remote (same as the match-watcher cron which had the broken
-- current_setting() pattern). Without this cron, my P0.2 'pushed_at +
-- sweep' resilience layer doesn't actually retry anything — items with
-- pushed_at IS NULL just sit there forever.
--
-- Schedule: hourly at :15 (matches the spec from migration 003).
-- Pattern: hardcoded URL + service_role_key, identical to the working
-- goaldigger-daily-pipeline cron.

SELECT cron.schedule(
    'notification-sweep',
    '15 * * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/notification-sender',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3Z3BzbWJ1bnJvY3JvZnppcWFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDYwNjc1NiwiZXhwIjoyMDkwMTgyNzU2fQ.YfGy-tG-7h7_rsAX3lLQ9mYJr-MtSWhtK1K7xAQlvGI'
        ),
        body := '{}'::jsonb
    )$$
);
