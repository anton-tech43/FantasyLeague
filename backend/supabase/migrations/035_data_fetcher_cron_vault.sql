-- 035_data_fetcher_cron_vault.sql
-- Move the data-fetcher daily cron off its inline legacy JWT and onto the
-- Vault-based pattern that every other cron uses.
--
-- Why now:
-- The May 17 2026 outage (Vault contained sb_secret_* format key instead
-- of JWT — gateway 401'd every match-watcher + notification-sweep tick for
-- 6 days) prompted an audit of remaining inline-JWT crons. Found
-- `goaldigger-daily-pipeline` still inlines the legacy JWT directly. It
-- happens to work today (legacy JWT is still valid for Edge Function
-- invocation), but the moment that key is fully rotated this cron silently
-- dies the same way.
--
-- This migration:
--  1. Unschedules the old goaldigger-daily-pipeline.
--  2. Reschedules with `'Bearer ' || get_cron_service_key()` from migration
--     020's SECURITY DEFINER accessor.
--
-- After this, all four Edge-Function-invoking crons share one auth path,
-- and a single Vault key rotation either succeeds for all or fails for all
-- (and the new health-check diagnostics in migration 036 will catch it).

SELECT cron.unschedule('goaldigger-daily-pipeline');

SELECT cron.schedule(
    'goaldigger-daily-pipeline',
    '0 7 * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/data-fetcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb
    )$$
);

-- Sanity check (commented — paste into psql to verify):
-- SELECT command FROM cron.job WHERE jobname='goaldigger-daily-pipeline';
-- Expected: contains `get_cron_service_key()` and does NOT contain `Bearer eyJ` literal.
