-- 039_pipeline_health_sla_checks.sql
-- Extend check_pipeline_heartbeat() with two new SLA checks driven by the
-- expanded pipeline_health table (migration 038):
--
--   CHECK 3 — live_brief SLA: match-watcher marked briefs_fired='HT' on a
--             fixture in the last 30 min, but no live_match_briefs row
--             landed within 5 min of that mark. Means gd-live-brief was
--             fired by match-watcher (we have the row in pipeline_health
--             at stage='live_brief_fire') but the routine session
--             produced no output. Alerts on the silent-routine-session
--             failure class.
--
--   CHECK 4 — matchday SLA: a match's fired_finished_at is set (FT) in
--             the last 1 hour, but no content_item with type='matchday'
--             AND match_id=<fixture_id> exists. Same pattern — gd-matchday
--             fire succeeded at the API level, but the session didn't
--             produce a content_item.
--
-- Both checks alert via client_errors + (best-effort) the existing push
-- path. Throttled to once per hour per check.
--
-- Why this matters: Phase J observability (migration 038 + match-watcher
-- instrumentation) makes the per-hop status visible. These SLA checks
-- automate "did the downstream artifact actually land?" so we don't have
-- to manually inspect after each match.

CREATE OR REPLACE FUNCTION check_pipeline_heartbeat()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    last_fetch TIMESTAMPTZ;
    fetch_threshold INTERVAL := INTERVAL '26 hours';
    bearer_token TEXT;
    http_total_1h INT;
    http_200_1h INT;
    http_failure_rate FLOAT;
    failure_threshold FLOAT := 0.5;
    missing_brief_count INT;
    missing_matchday_count INT;
BEGIN
    -- =======================================================================
    -- CHECK 1: data-fetcher freshness (preserved from migration 037)
    -- =======================================================================
    SELECT MAX(created_at) INTO last_fetch
    FROM pipeline_health
    WHERE stage = 'fetch' AND status = 'success';

    IF last_fetch IS NOT NULL AND last_fetch > NOW() - fetch_threshold THEN
        NULL;
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM client_errors
            WHERE error_type = 'cron_silent_failure'
              AND created_at > NOW() - INTERVAL '2 hours'
        ) THEN
            INSERT INTO client_errors (error_type, message, app_version)
            VALUES (
                'cron_silent_failure',
                FORMAT('No data-fetcher pipeline_health row in the last %s. Last fetch: %s.',
                       fetch_threshold, COALESCE(last_fetch::TEXT, 'never')),
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
    -- CHECK 2: HTTP-level cron gateway health (preserved from migration 037)
    -- =======================================================================
    SELECT COUNT(*) INTO http_total_1h
    FROM net._http_response
    WHERE created > NOW() - INTERVAL '1 hour';

    SELECT COUNT(*) INTO http_200_1h
    FROM net._http_response
    WHERE created > NOW() - INTERVAL '1 hour' AND status_code = 200;

    IF http_total_1h >= 10 THEN
        http_failure_rate := 1.0 - (http_200_1h::float / http_total_1h::float);

        IF http_failure_rate > failure_threshold THEN
            IF NOT EXISTS (
                SELECT 1 FROM client_errors
                WHERE error_type = 'cron_http_gateway_failure'
                  AND created_at > NOW() - INTERVAL '1 hour'
            ) THEN
                INSERT INTO client_errors (error_type, message, app_version)
                VALUES (
                    'cron_http_gateway_failure',
                    FORMAT(
                        'pg_cron HTTP health degraded: %s / %s calls in last hour returned non-200 (%.0f%% failure).',
                        http_total_1h - http_200_1h, http_total_1h, http_failure_rate * 100
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
                            'message', FORMAT('%s%% of cron HTTP calls failing', ROUND((http_failure_rate * 100)::numeric, 0)),
                            'app_version', 'backend-cron'
                        )
                    );
                EXCEPTION WHEN OTHERS THEN
                    RAISE WARNING 'check_pipeline_heartbeat (CHECK 2): alert push failed: %', SQLERRM;
                END;
            END IF;
        END IF;
    END IF;

    -- =======================================================================
    -- CHECK 3 (NEW): live_brief SLA
    -- =======================================================================
    -- For every match-watcher fire of gd-live-brief at the HT trigger in
    -- the last 30 minutes, a row in live_match_briefs should exist within
    -- 5 minutes of the fire. If not, the routine session silently produced
    -- no output (the May 17 confusion). Alert.
    --
    -- Uses pipeline_health rows (from match-watcher's logFire) as the
    -- source of truth for "we successfully fired this brief" — they have
    -- target='live_brief_fire:<team>:<fixture>:HT' and status='success'.
    SELECT COUNT(*) INTO missing_brief_count
    FROM pipeline_health ph
    WHERE ph.stage = 'live_brief_fire'
      AND ph.status = 'success'
      AND ph.target LIKE '%:HT'
      AND ph.created_at > NOW() - INTERVAL '30 minutes'
      AND NOT EXISTS (
          SELECT 1 FROM live_match_briefs lmb
          -- Extract fixture_id from target string ('live_brief_fire:<team>:<fixture>:HT')
          WHERE lmb.match_id = SPLIT_PART(ph.target, ':', 3)
            AND lmb.trigger_label = 'HT'
            AND lmb.generated_at > ph.created_at - INTERVAL '1 minute'
            AND lmb.generated_at < ph.created_at + INTERVAL '10 minutes'
      );

    IF missing_brief_count > 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM client_errors
            WHERE error_type = 'live_brief_silent_failure'
              AND created_at > NOW() - INTERVAL '1 hour'
        ) THEN
            INSERT INTO client_errors (error_type, message, app_version)
            VALUES (
                'live_brief_silent_failure',
                FORMAT('%s HT brief fire(s) succeeded at the API but produced no live_match_briefs row within 10 min', missing_brief_count),
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
                        'error_type', 'live_brief_silent_failure',
                        'message', FORMAT('%s HT briefs fired but produced no output', missing_brief_count),
                        'app_version', 'backend-cron'
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'check_pipeline_heartbeat (CHECK 3): alert push failed: %', SQLERRM;
            END;
        END IF;
    END IF;

    -- =======================================================================
    -- CHECK 4 (NEW): matchday SLA
    -- =======================================================================
    -- For every match that transitioned to FT in the last 1 hour
    -- (fired_finished_at set on match_status_state), a content_item with
    -- type='matchday' and match_id=fixture_id should exist within 15 min.
    -- If not, gd-matchday's routine session silently produced no output.
    -- This is exactly today's 4-PL-club silent-failure case the Phase J
    -- observability surfaced via 429s; this check automates the alert.
    SELECT COUNT(*) INTO missing_matchday_count
    FROM match_status_state mss
    WHERE mss.fired_finished_at > NOW() - INTERVAL '1 hour'
      AND NOT EXISTS (
          SELECT 1 FROM content_items ci
          WHERE ci.match_id = mss.fixture_id::text
            AND ci.type = 'matchday'
            AND ci.created_at > mss.fired_finished_at - INTERVAL '1 minute'
            AND ci.created_at < mss.fired_finished_at + INTERVAL '15 minutes'
      );

    IF missing_matchday_count > 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM client_errors
            WHERE error_type = 'matchday_silent_failure'
              AND created_at > NOW() - INTERVAL '1 hour'
        ) THEN
            INSERT INTO client_errors (error_type, message, app_version)
            VALUES (
                'matchday_silent_failure',
                FORMAT('%s match(es) hit FT in last hour but produced no matchday content_item within 15 min', missing_matchday_count),
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
                        'error_type', 'matchday_silent_failure',
                        'message', FORMAT('%s matchday FT transitions silently failed', missing_matchday_count),
                        'app_version', 'backend-cron'
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'check_pipeline_heartbeat (CHECK 4): alert push failed: %', SQLERRM;
            END;
        END IF;
    END IF;
END;
$$;

-- Verification:
-- After applying, manually run:
--   SELECT check_pipeline_heartbeat();
-- Expected: returns void, possibly inserts client_errors rows for any
-- current SLA violations. Today's matchday_silent_failure for the 4
-- 429'd PL fixtures (Crystal Palace, Brentford, Leeds, Brighton) should
-- fire as a `matchday_silent_failure` row if they're still missing
-- content_items. The goaldigger-cron-heartbeat-check cron (every 30 min)
-- will pick it up automatically going forward.
