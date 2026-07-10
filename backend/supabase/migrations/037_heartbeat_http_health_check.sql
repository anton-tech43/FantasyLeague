-- 037_heartbeat_http_health_check.sql
-- Extend check_pipeline_heartbeat() with HTTP-level health detection.
--
-- Why this exists:
-- The May 11 → May 17 push outage (Phase 27.3) was caused by Vault holding
-- a sb_secret_* format key instead of JWT. Every cron tick 401'd at the
-- gateway. The OLD check_pipeline_heartbeat() only looked at
-- `pipeline_health.stage='fetch'` rows — but data-fetcher (which writes
-- those rows) was on its own inline-JWT cron and was firing fine. The
-- pipeline-health check stayed silent while every push-related cron 401'd.
--
-- The heartbeat needs a SECOND check that catches this class of failure:
-- detect spikes of non-200 responses in net._http_response and alert.
--
-- Chicken-and-egg:
-- The heartbeat fires its own client-error-alert via Vault auth. If the
-- Vault key is broken, the heartbeat can detect the problem but the alert
-- push will fail too (it'd 401 just like everything else). Mitigation:
-- ALWAYS insert into client_errors table (already happens), so even if no
-- push fires, the diagnostic trail is recorded for `diagnose-matchday` and
-- any human investigator to find via psql.

CREATE OR REPLACE FUNCTION check_pipeline_heartbeat()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    last_fetch TIMESTAMPTZ;
    fetch_threshold INTERVAL := INTERVAL '26 hours';
    bearer_token TEXT;
    http_total_24h INT;
    http_200_24h INT;
    http_failure_rate FLOAT;
    failure_threshold FLOAT := 0.5;  -- alert if >50% of cron calls 401/5xx
BEGIN
    -- =======================================================================
    -- CHECK 1: data-fetcher freshness (the original behaviour)
    -- =======================================================================
    SELECT MAX(created_at) INTO last_fetch
    FROM pipeline_health
    WHERE stage = 'fetch' AND status = 'success';

    IF last_fetch IS NOT NULL AND last_fetch > NOW() - fetch_threshold THEN
        -- Data-fetcher is alive. Continue to Check 2.
        NULL;
    ELSE
        -- Throttle: don't spam alerts.
        IF NOT EXISTS (
            SELECT 1 FROM client_errors
            WHERE error_type = 'cron_silent_failure'
              AND created_at > NOW() - INTERVAL '2 hours'
        ) THEN
            INSERT INTO client_errors (error_type, message, app_version)
            VALUES (
                'cron_silent_failure',
                FORMAT(
                    'No data-fetcher pipeline_health row in the last %s. Last fetch: %s. Cron may have stopped.',
                    fetch_threshold,
                    COALESCE(last_fetch::TEXT, 'never')
                ),
                'backend-cron'
            );

            -- Push the alert (best-effort — may itself 401 if Vault is broken).
            BEGIN
                bearer_token := get_cron_service_key();
                PERFORM net.http_post(
                    url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/client-error-alert',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'Authorization', 'Bearer ' || bearer_token
                    ),
                    body := jsonb_build_object(
                        'error_type', 'cron_silent_failure',
                        'message', 'data-fetcher cron has stopped firing. Check Supabase pg_cron status.',
                        'app_version', 'backend-cron'
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'check_pipeline_heartbeat: alert push failed: %', SQLERRM;
            END;
        END IF;
    END IF;

    -- =======================================================================
    -- CHECK 2 (NEW): HTTP-level cron gateway health
    -- =======================================================================
    -- Watch the actual HTTP response codes returned to pg_cron. If >50% of
    -- cron HTTP calls in the last hour are non-200, that's the
    -- gateway-401-silent-failure pattern from May 11-17. Alert separately
    -- from CHECK 1 — they're orthogonal failure modes.
    SELECT COUNT(*) INTO http_total_24h
    FROM net._http_response
    WHERE created > NOW() - INTERVAL '1 hour';

    SELECT COUNT(*) INTO http_200_24h
    FROM net._http_response
    WHERE created > NOW() - INTERVAL '1 hour' AND status_code = 200;

    -- Only meaningful if there's a representative sample.
    IF http_total_24h >= 10 THEN
        http_failure_rate := 1.0 - (http_200_24h::float / http_total_24h::float);

        IF http_failure_rate > failure_threshold THEN
            -- Throttle alerts (1h cooldown — match-watcher runs every minute
            -- so a sustained issue would spam otherwise).
            IF NOT EXISTS (
                SELECT 1 FROM client_errors
                WHERE error_type = 'cron_http_gateway_failure'
                  AND created_at > NOW() - INTERVAL '1 hour'
            ) THEN
                INSERT INTO client_errors (error_type, message, app_version)
                VALUES (
                    'cron_http_gateway_failure',
                    FORMAT(
                        'pg_cron HTTP health degraded: %s / %s calls in last hour returned non-200 (%.0f%% failure). Likely Vault key shape regression — see IOS_GOTCHAS.md #14.',
                        http_total_24h - http_200_24h,
                        http_total_24h,
                        http_failure_rate * 100
                    ),
                    'backend-cron'
                );

                BEGIN
                    bearer_token := get_cron_service_key();
                    PERFORM net.http_post(
                        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/client-error-alert',
                        headers := jsonb_build_object(
                            'Content-Type', 'application/json',
                            'Authorization', 'Bearer ' || bearer_token
                        ),
                        body := jsonb_build_object(
                            'error_type', 'cron_http_gateway_failure',
                            'message', FORMAT('%s%% of cron HTTP calls failing — likely Vault key shape', ROUND((http_failure_rate * 100)::numeric, 0)),
                            'app_version', 'backend-cron'
                        )
                    );
                EXCEPTION WHEN OTHERS THEN
                    -- Chicken-egg: if the same Vault key powers this push,
                    -- it'll fail too. The client_errors row above is the
                    -- durable trail.
                    RAISE WARNING 'check_pipeline_heartbeat (CHECK 2): alert push failed (likely same root cause): %', SQLERRM;
                END;
            END IF;
        END IF;
    END IF;
END;
$$;

-- Verification:
-- After applying, peek at the function body:
--   \df+ check_pipeline_heartbeat
-- Run manually to confirm no errors:
--   SELECT check_pipeline_heartbeat();
