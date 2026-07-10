-- 041_pipeline_health_fire_failure_check.sql
-- Add CHECK 5 to check_pipeline_heartbeat(): persistent fire-attempt failures.
--
-- Context:
-- CHECK 3 (live_brief SLA) and CHECK 4 (matchday SLA) both detect
-- "downstream artifact didn't land" — they look at live_match_briefs /
-- content_items for the EXPECTED output. They fail to fire when the
-- pipeline transition itself never completed: match-watcher's fire was
-- rejected (429 / 401 / 503), so `fired_finished_at` never got set on
-- match_status_state, and the SLA windows in CHECK 3/4 never qualify.
--
-- Tonight (May 17) we observed this gap firsthand: 4 PL fixtures
-- (Brentford vs Crystal Palace, Leeds vs Brighton — 2 perspectives each)
-- had match-watcher firing every minute for 30+ minutes, every fire
-- returning HTTP 429 ("Routine limit reached") from the routine API.
-- 288 failure rows in pipeline_health.matchday_fire, fired_finished_at
-- on match_status_state stayed NULL, and CHECK 4 stayed silent.
--
-- CHECK 5 closes this gap: alert when a fire TARGET (e.g.,
-- 'matchday_fire:brentford:1379332') has any failures in the last
-- 30 min AND zero successes. Surface the http_status + error_class so
-- the diagnostic is in the alert message itself ("4 targets, codes:
-- 429, classes: fire_failed").
--
-- Throttled to 1/hr per check via client_errors dedup, same pattern as
-- CHECK 1-4.

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
    failing_fire_count INT;
    failing_fire_http TEXT;
    failing_fire_classes TEXT;
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
    -- CHECK 3: live_brief SLA (from migration 039)
    -- =======================================================================
    SELECT COUNT(*) INTO missing_brief_count
    FROM pipeline_health ph
    WHERE ph.stage = 'live_brief_fire'
      AND ph.status = 'success'
      AND ph.target LIKE '%:HT'
      AND ph.created_at > NOW() - INTERVAL '30 minutes'
      AND NOT EXISTS (
          SELECT 1 FROM live_match_briefs lmb
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
    -- CHECK 4: matchday SLA (from migration 039)
    -- =======================================================================
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

    -- =======================================================================
    -- CHECK 5 (NEW): persistent fire failures
    -- =======================================================================
    -- Distinct from CHECK 3+4: those look at the OUTPUT side (did the
    -- artifact land?). CHECK 5 looks at the FIRE side (is match-watcher
    -- successfully reaching the routine API at all?). Catches the case
    -- where the fire itself fails repeatedly: 429 (quota), 401/403 (auth),
    -- 503 (routine API down). When fires fail, no fired_finished_at gets
    -- set → CHECK 4 stays silent. CHECK 5 fills that gap.
    --
    -- A "failing target" is one where, in the last 30 min, there's >= 1
    -- pipeline_health row with status='failure' AND zero with status='success'
    -- for the same target. The target encodes the routine + team + fixture,
    -- so each stuck fixture-perspective shows up as one failing target.
    WITH fire_outcomes AS (
        SELECT
            target,
            stage,
            COUNT(*) FILTER (WHERE status = 'failure') AS failures,
            COUNT(*) FILTER (WHERE status = 'success') AS successes,
            MAX(http_status) FILTER (WHERE status = 'failure') AS last_http,
            MAX(error_class) FILTER (WHERE status = 'failure') AS last_class
        FROM pipeline_health
        WHERE stage IN ('matchday_fire', 'live_brief_fire')
          AND created_at > NOW() - INTERVAL '30 minutes'
        GROUP BY target, stage
    )
    -- STRING_AGG(DISTINCT …) doesn't accept an outer ORDER BY; the values
    -- are sorted lexicographically when DISTINCT is applied.
    SELECT
        COUNT(*),
        STRING_AGG(DISTINCT last_http::text, ','),
        STRING_AGG(DISTINCT last_class, ',')
    INTO failing_fire_count, failing_fire_http, failing_fire_classes
    FROM fire_outcomes
    WHERE failures > 0 AND successes = 0;

    IF failing_fire_count IS NOT NULL AND failing_fire_count > 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM client_errors
            WHERE error_type = 'persistent_fire_failure'
              AND created_at > NOW() - INTERVAL '1 hour'
        ) THEN
            INSERT INTO client_errors (error_type, message, app_version)
            VALUES (
                'persistent_fire_failure',
                FORMAT(
                    '%s match-watcher fire target(s) failing repeatedly in last 30 min (http codes: %s, error classes: %s). No success rows for these targets.',
                    failing_fire_count,
                    COALESCE(failing_fire_http, 'unknown'),
                    COALESCE(failing_fire_classes, 'unknown')
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
                        'error_type', 'persistent_fire_failure',
                        'message', FORMAT(
                            '%s fire targets stuck; http %s',
                            failing_fire_count,
                            COALESCE(failing_fire_http, '?')
                        ),
                        'app_version', 'backend-cron'
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'check_pipeline_heartbeat (CHECK 5): alert push failed: %', SQLERRM;
            END;
        END IF;
    END IF;
END;
$$;

-- Verification:
--   SELECT check_pipeline_heartbeat();
-- Expected: returns void. If tonight's 4 stuck PL fixtures' 429-storm
-- targets are still in the 30-min window, CHECK 5 should fire on first
-- run (and then be throttled for 1h). Confirm with:
--   SELECT error_type, message, created_at FROM client_errors
--    WHERE error_type = 'persistent_fire_failure'
--    ORDER BY created_at DESC LIMIT 5;
