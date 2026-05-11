-- 020_vault_read_via_security_definer.sql
-- Fix the cron auth pipeline broken by 019: pg_cron's role couldn't read
-- vault.decrypted_secrets directly, so the inline SELECT inside each cron
-- body returned NULL, and 'Bearer ' || NULL = NULL → function got an empty
-- Authorization header → 401 → silent failure visible only as state rows
-- that never advance.
--
-- The fix: wrap the Vault read in a SECURITY DEFINER function owned by a
-- role that DOES have read access to vault.decrypted_secrets. SECURITY
-- DEFINER means the function executes with the owner's privileges, not
-- the caller's — so the pg_cron role can call it and get the secret back
-- even though it can't read the Vault view directly.
--
-- Why this is still safe:
--   * The function is restricted to the single secret name 'cron_service_key'.
--     It cannot be called to retrieve arbitrary Vault entries.
--   * Even if some other role gained EXECUTE on this function, the only
--     thing they'd get is the cron service key (which is already needed
--     by every cron and is in Vault, not in source).
--   * Granting Vault access to the postgres role directly would have
--     been broader; a single-purpose SECURITY DEFINER is the narrower path.
--
-- This migration also re-runs the three cron.schedule calls from 019 so
-- the new function name is wired in. It's idempotent (drop-then-create).

-- ---------------------------------------------------------------------------
-- 1. SECURITY DEFINER accessor
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_cron_service_key()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
-- Lock down search_path to prevent SQL-search-path injection
SET search_path = ''
AS $$
DECLARE
    key TEXT;
BEGIN
    SELECT decrypted_secret INTO key
    FROM vault.decrypted_secrets
    WHERE name = 'cron_service_key'
    LIMIT 1;

    IF key IS NULL THEN
        RAISE EXCEPTION 'get_cron_service_key: vault secret cron_service_key not found';
    END IF;

    RETURN key;
END;
$$;

-- pg_cron jobs run under whoever scheduled them. Allow the postgres role
-- (the typical Supabase pg_cron schedule owner) plus anyone else who'd
-- legitimately call this to invoke it. REVOKE PUBLIC for defence-in-depth.
REVOKE EXECUTE ON FUNCTION get_cron_service_key() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_cron_service_key() TO postgres;

-- ---------------------------------------------------------------------------
-- 2. Re-create the three crons to call the accessor function
-- ---------------------------------------------------------------------------

SELECT cron.unschedule('match-watcher-1min')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-watcher-1min');

SELECT cron.unschedule('notification-sweep')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notification-sweep');

SELECT cron.unschedule('goaldigger-cron-heartbeat-check')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-cron-heartbeat-check');

-- 2a. match-watcher every minute
SELECT cron.schedule(
    'match-watcher-1min',
    '* * * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb
    )$$
);

-- 2b. notification-sweep hourly at :15
SELECT cron.schedule(
    'notification-sweep',
    '15 * * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/notification-sender',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb
    )$$
);

-- 2c. heartbeat check every 30 min
SELECT cron.schedule(
    'goaldigger-cron-heartbeat-check',
    '*/30 * * * *',
    $$SELECT check_pipeline_heartbeat();$$
);

-- ---------------------------------------------------------------------------
-- 3. Update check_pipeline_heartbeat() to use the accessor too
-- ---------------------------------------------------------------------------
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

    cron_key := get_cron_service_key();

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
