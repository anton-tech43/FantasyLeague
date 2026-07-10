-- 016_notification_sweep_cron.sql
--
-- ⚠️  HISTORICAL ARTIFACT — DO NOT EMULATE THE INLINE JWT BELOW.
-- The `Bearer eyJ...` literal in this migration is overwritten by migration
-- 019 + 020 (Vault-based auth via get_cron_service_key()). For any new cron,
-- use the Vault accessor pattern. See IOS_GOTCHAS.md #14 + lesson 57 for why.
--
-- Original migration purpose:
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
            'Authorization', 'Bearer <REDACTED-LEGACY-SERVICE-ROLE-JWT-ROTATED-2026-05-11>'
        ),
        body := '{}'::jsonb
    )$$
);
