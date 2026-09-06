-- 081_heartbeat_format_fix_and_stall_check.sql
-- Audit 2026-09, A15 + A17.
--
-- A15: CHECK 2 used FORMAT('… %.0f%% …'). Postgres format() only knows %s %I %L,
--      so the alert that should fire when cron HTTP calls fail crashed with
--      'unrecognized format() type specifier "."' — 13 times 25–30 Aug 2026,
--      i.e. exactly while prod was dying. Fixed with ROUND(...)::text + %s.
-- A17: new CHECK 6 — a live/imminent fixture whose match_status_state.last_checked
--      is older than 5 minutes means match-watcher is not landing writes.
--
-- Body below is the PROD definition as of 2026-09-06 (pg_get_functiondef), not
-- migration 041, because prod and git had drifted (A12). Applied manually.

CREATE OR REPLACE FUNCTION public.check_pipeline_heartbeat()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
    stalled_count INT;
    stalled_fixtures TEXT;
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
                        'pg_cron HTTP health degraded: %s / %s calls in last hour returned non-200 (%s%% failure).',
                        http_total_1h - http_200_1h, http_total_1h, ROUND((http_failure_rate * 100)::numeric, 0)::text
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

    -- =======================================================================
    -- CHECK 6 (NEW, audit 2026-09 A17): match-watcher polling has stalled
    -- =======================================================================
    -- CHECKs 3–5 all start from an EVENT (a fire, an FT). They stay silent when
    -- match-watcher never gets as far as observing the match — which is exactly
    -- what happened 21 Aug–6 Sep 2026 (1 of 30 PL fixtures ever seen). This check
    -- starts from the FIXTURE: any row whose kickoff is between 15 min ahead and
    -- 150 min behind now, still in a non-terminal status, must have been touched
    -- (last_checked) within the last 5 minutes. match-watcher runs every minute,
    -- so 5 min of silence during a live window = the cron/function is not
    -- landing writes. The reaper (05:00 UTC) marks abandoned rows ABD, so this
    -- cannot fire forever on a dead fixture.
    SELECT COUNT(*), STRING_AGG(mss.fixture_id::text || ':' || mss.status, ',')
    INTO stalled_count, stalled_fixtures
    FROM match_status_state mss
    WHERE mss.kickoff_time BETWEEN NOW() - INTERVAL '150 minutes' AND NOW() + INTERVAL '15 minutes'
      AND mss.status NOT IN ('FT','AET','PEN','PST','CANC','ABD','AWD','WO','TBD')
      AND mss.last_checked < NOW() - INTERVAL '5 minutes';

    IF stalled_count IS NOT NULL AND stalled_count > 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM client_errors
            WHERE error_type = 'match_watcher_stalled'
              AND created_at > NOW() - INTERVAL '30 minutes'
        ) THEN
            INSERT INTO client_errors (error_type, message, app_version)
            VALUES (
                'match_watcher_stalled',
                FORMAT('%s live/imminent fixture(s) not touched by match-watcher for >5 min: %s',
                       stalled_count, COALESCE(stalled_fixtures, '?')),
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
                        'error_type', 'match_watcher_stalled',
                        'message', FORMAT('match-watcher stalled on %s live fixture(s)', stalled_count),
                        'app_version', 'backend-cron'
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'check_pipeline_heartbeat (CHECK 6): alert push failed: %', SQLERRM;
            END;
        END IF;
    END IF;
END;
$function$

-- Verification:
--   SELECT check_pipeline_heartbeat();          -- must not raise
--   SELECT prosrc LIKE '%%CHECK 6%%' FROM pg_proc WHERE proname = 'check_pipeline_heartbeat';
--   -- Simulate CHECK 2 formatting:
--   SELECT FORMAT('(%s%% failure)', ROUND((0.5 * 100)::numeric, 0)::text);   -- '(50% failure)'
