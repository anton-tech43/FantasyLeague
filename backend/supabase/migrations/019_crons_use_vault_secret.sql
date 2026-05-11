-- 019_crons_use_vault_secret.sql
-- Replace every cron job + SECURITY DEFINER function that embedded the
-- legacy service_role JWT inline with a Vault-based lookup of the new
-- sb_secret_* key.
--
-- BACKGROUND
-- Migrations 015, 016, and 017 (committed 2026-05-07 through 2026-05-11)
-- each hardcoded the project's legacy service_role JWT into the body of a
-- cron job's net.http_post call. Those migration files are checked into a
-- public GitHub repository, so the JWT was effectively public the moment
-- the commit was pushed.
--
-- On 2026-05-11 the project rotated to the new Supabase API key model:
--   * sb_publishable_* (replaces legacy `anon` JWT) — used by iOS
--   * sb_secret_*      (replaces legacy `service_role` JWT) — used here
--
-- The new sb_secret_* value was stored once in Postgres Vault by hand via
-- the SQL editor:
--   SELECT vault.create_secret('<sb_secret_...>', 'cron_service_key');
--
-- This migration:
--   1. Drops the three crons that embedded the legacy JWT.
--   2. Re-creates them with the same schedules and behaviour, but reading
--      the auth token from vault.decrypted_secrets at fire time. Only the
--      *name* of the secret is committed; the value never appears here.
--   3. Replaces check_pipeline_heartbeat() to do the same for its
--      embedded client-error-alert call.
--
-- After this migration runs, the legacy service_role JWT in the dashboard
-- can be disabled safely — nothing in the database references it anymore.
-- Production note: edge functions and routines were migrated to the new
-- key in parallel (see _shared/supabase-client.ts and routine env updates).
--
-- Future ops note: when the new sb_secret_* is itself rotated, you do
-- NOT need to re-run this migration. Just update the Vault secret value:
--   UPDATE vault.secrets
--   SET secret = '<new sb_secret_...>'
--   WHERE name = 'cron_service_key';
-- All three crons + the heartbeat function will pick up the new value on
-- their next tick.

-- ---------------------------------------------------------------------------
-- 1. Drop the three leak-bearing crons (idempotent)
-- ---------------------------------------------------------------------------

SELECT cron.unschedule('match-watcher-1min')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-watcher-1min');

SELECT cron.unschedule('notification-sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notification-sweep');

SELECT cron.unschedule('goaldigger-cron-heartbeat-check')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-cron-heartbeat-check');

-- ---------------------------------------------------------------------------
-- 2. Re-create the crons using vault.decrypted_secrets
-- ---------------------------------------------------------------------------
-- The cron job body is stored as a string in cron.job by pg_cron and is
-- executed verbatim each tick. The body below uses a subquery to fetch
-- the decrypted secret at each invocation; the secret is never inlined
-- into the body itself.
--
-- vault.decrypted_secrets is a view over vault.secrets that decrypts on
-- read using the project's Vault key (managed by Supabase, not committed).
-- Read access is restricted at the platform level to the postgres role,
-- which pg_cron jobs run as — so this is safe.

-- 2a. match-watcher (every minute) — was migration 017
SELECT cron.schedule(
    'match-watcher-1min',
    '* * * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (
                SELECT decrypted_secret
                FROM vault.decrypted_secrets
                WHERE name = 'cron_service_key'
                LIMIT 1
            )
        ),
        body := '{}'::jsonb
    )$$
);

-- 2b. notification-sweep (hourly at :15) — was migration 016
SELECT cron.schedule(
    'notification-sweep',
    '15 * * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/notification-sender',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (
                SELECT decrypted_secret
                FROM vault.decrypted_secrets
                WHERE name = 'cron_service_key'
                LIMIT 1
            )
        ),
        body := '{}'::jsonb
    )$$
);

-- 2c. heartbeat check (every 30 min) — was migration 015
-- The body calls check_pipeline_heartbeat(), which is itself rewritten
-- below to read from Vault for its internal net.http_post.
SELECT cron.schedule(
    'goaldigger-cron-heartbeat-check',
    '*/30 * * * *',
    $$SELECT check_pipeline_heartbeat();$$
);

-- ---------------------------------------------------------------------------
-- 3. Re-write check_pipeline_heartbeat() to read from Vault
-- ---------------------------------------------------------------------------
-- Function body matches migration 015 verbatim except the Authorization
-- header now reads from vault.decrypted_secrets instead of being inlined.

CREATE OR REPLACE FUNCTION check_pipeline_heartbeat()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    last_fetch TIMESTAMPTZ;
    threshold INTERVAL := INTERVAL '26 hours';
    cron_key TEXT;
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

    -- Pull the service-role key from Vault at call time, never inline.
    SELECT decrypted_secret INTO cron_key
    FROM vault.decrypted_secrets
    WHERE name = 'cron_service_key'
    LIMIT 1;

    IF cron_key IS NULL THEN
        -- Fail loud: the heartbeat function itself is the alarm.
        -- If the key is missing the rest is moot, log and bail.
        RAISE WARNING 'check_pipeline_heartbeat: vault secret cron_service_key missing — cannot fire client-error-alert';
        RETURN;
    END IF;

    PERFORM net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/client-error-alert',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || cron_key
        ),
        body := jsonb_build_object(
            'error_type', 'cron_silent_failure',
            'message', 'data-fetcher cron has stopped firing. Check Supabase pg_cron status.',
            'app_version', 'backend-cron'
        )
    );
END;
$$;
