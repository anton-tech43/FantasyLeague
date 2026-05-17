-- 036_diagnostics_rpc_http_responses.sql
-- Extend get_pipeline_diagnostics() with HTTP-response visibility.
--
-- Why this exists:
-- The May 17 2026 outage (Phase 27.3) lasted SIX DAYS because we monitored
-- `cron.job_run_details.status='succeeded'` and assumed the cron had hit the
-- function. In reality the Supabase gateway was returning 401 on every tick
-- because the Vault held a sb_secret_* format key instead of a JWT.
--
-- The fix to NEVER MISS THIS AGAIN is to surface `net._http_response` rows
-- in the diagnostics output, alongside a "key shape check" so a glance at
-- the diagnostics tells you whether the cron auth is going to work.
--
-- New fields in the returned JSONB:
--   - recent_http_responses: last 20 rows from net._http_response with
--     status_code + first 200 chars of content + created timestamp
--   - http_health_summary: rolling 24h count by status_code
--   - key_shape_check: prefix + length of get_cron_service_key().
--     If prefix != 'eyJ' or length < 100, this Vault entry will 401 the
--     gateway on every cron tick — flag is set to false.

CREATE OR REPLACE FUNCTION get_pipeline_diagnostics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    result JSONB;
    cron_jobs JSONB;
    cron_runs JSONB;
    vault_secret_present BOOLEAN;
    accessor_present BOOLEAN;
    recent_http JSONB;
    http_health JSONB;
    key_prefix TEXT;
    key_len INT;
    key_shape_ok BOOLEAN;
BEGIN
    -- Cron job bodies (sanitized: only first 400 chars of command).
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'jobname', jobname,
        'schedule', schedule,
        'active', active,
        'command_excerpt', LEFT(command, 400)
    ) ORDER BY jobname), '[]'::jsonb)
    INTO cron_jobs
    FROM cron.job
    WHERE jobname IN ('match-watcher-1min', 'notification-sweep',
                      'goaldigger-cron-heartbeat-check', 'goaldigger-daily-pipeline');

    -- Last 20 runs of match-watcher-1min (pg_cron-level status — necessary
    -- but not sufficient; see http_responses below for actual HTTP outcome).
    SELECT COALESCE(jsonb_agg(row_to_json(r) ORDER BY r.start_time DESC), '[]'::jsonb)
    INTO cron_runs
    FROM (
        SELECT jrd.start_time, jrd.end_time, jrd.status, jrd.return_message
        FROM cron.job_run_details jrd
        JOIN cron.job j ON j.jobid = jrd.jobid
        WHERE j.jobname = 'match-watcher-1min'
        ORDER BY jrd.start_time DESC
        LIMIT 20
    ) r;

    -- Last 20 actual HTTP responses (the layer cron.job_run_details misses).
    -- A 401 here while cron.job_run_details says "succeeded" is the exact
    -- silent-failure pattern that killed pushes for 6 days.
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'status_code', status_code,
        'content_preview', LEFT(content::text, 200),
        'created', created
    ) ORDER BY id DESC), '[]'::jsonb)
    INTO recent_http
    FROM (
        SELECT id, status_code, content, created
        FROM net._http_response
        ORDER BY id DESC
        LIMIT 20
    ) h;

    -- Rolling 24h health summary — at-a-glance "what fraction of cron
    -- invocations are actually reaching the function".
    SELECT COALESCE(jsonb_object_agg(status_code::text, n) FILTER (WHERE status_code IS NOT NULL), '{}'::jsonb)
    INTO http_health
    FROM (
        SELECT status_code, COUNT(*) AS n
        FROM net._http_response
        WHERE created > NOW() - INTERVAL '24 hours'
        GROUP BY status_code
    ) s;

    -- Vault secret existence + KEY SHAPE CHECK. If the Vault contains a
    -- non-JWT-shape key the gateway will 401 on every cron tick. JWT shape
    -- starts with `eyJ` (the base64 of `{"alg":...`) and is ~219 chars.
    SELECT EXISTS (
        SELECT 1 FROM vault.secrets WHERE name = 'cron_service_key'
    ) INTO vault_secret_present;

    BEGIN
        SELECT LEFT(public.get_cron_service_key(), 3) INTO key_prefix;
        SELECT LENGTH(public.get_cron_service_key()) INTO key_len;
        key_shape_ok := (key_prefix = 'eyJ' AND key_len > 100);
    EXCEPTION WHEN OTHERS THEN
        key_prefix := NULL;
        key_len := NULL;
        key_shape_ok := FALSE;
    END;

    -- SECURITY DEFINER accessor existence
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'get_cron_service_key'
    ) INTO accessor_present;

    result := jsonb_build_object(
        'cron_jobs', cron_jobs,
        'match_watcher_recent_runs', cron_runs,
        'recent_http_responses', recent_http,
        'http_health_summary_24h', http_health,
        'vault_secret_cron_service_key_present', vault_secret_present,
        'get_cron_service_key_function_present', accessor_present,
        'key_shape_check', jsonb_build_object(
            'prefix', key_prefix,
            'length', key_len,
            'is_jwt_shape', key_shape_ok
        ),
        'snapshot_at', NOW()
    );

    RETURN result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_pipeline_diagnostics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_pipeline_diagnostics() TO service_role;
