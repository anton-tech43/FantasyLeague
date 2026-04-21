-- 006_pipeline_schedule.sql
-- Goal Digger — Daily content pipeline cron job
--
-- Chains automatically via edge function triggers:
--   data-fetcher → content-generator (per team) → content-reviewer → (approve | retry | reject)
--
-- Runs 07:00 UTC daily.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Remove any previous schedule with the same name before re-creating (idempotent).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-daily-pipeline') THEN
    PERFORM cron.unschedule('goaldigger-daily-pipeline');
  END IF;
END $$;

-- Schedule: 07:00 UTC daily
SELECT cron.schedule(
    'goaldigger-daily-pipeline',
    '0 7 * * *',
    $$
    SELECT net.http_post(
      url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/data-fetcher',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3Z3BzbWJ1bnJvY3JvZnppcWFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDYwNjc1NiwiZXhwIjoyMDkwMTgyNzU2fQ.YfGy-tG-7h7_rsAX3lLQ9mYJr-MtSWhtK1K7xAQlvGI',
        'apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3Z3BzbWJ1bnJvY3JvZnppcWFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDYwNjc1NiwiZXhwIjoyMDkwMTgyNzU2fQ.YfGy-tG-7h7_rsAX3lLQ9mYJr-MtSWhtK1K7xAQlvGI'
      ),
      body := '{}'::jsonb
    );
    $$
);
