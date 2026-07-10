-- 029_diagnostics_rpc.sql
-- Read-only diagnostic RPC for the pipeline health snapshot.
--
-- Why this exists: tables in the `cron` schema (cron.job, cron.job_run_details)
-- and the `vault` schema are not exposed by PostgREST, so Edge Functions
-- cannot SELECT from them directly. This RPC, owned by a role with read
-- access, returns a JSON blob covering the four things the diagnose-matchday
-- endpoint needs to confirm whether the watcher pipeline is alive:
--
--   1. cron.job rows for our three scheduled jobs — including the command
--      body so we can see whether the Authorization header reads from
--      vault.decrypted_secrets (migration 020) or contains the legacy
--      hardcoded JWT (migration 017).
--   2. Last 20 entries from cron.job_run_details for match-watcher-1min,
--      so we can see HTTP status codes / error messages over time.
--   3. Whether the vault secret named `cron_service_key` exists.
--   4. Whether the SECURITY DEFINER function get_cron_service_key() exists.
--
-- SECURITY DEFINER + restricted search_path so the function runs with its
-- owner's privileges (necessary for cron + vault) but cannot be redirected
-- to a shadowed table.
--
-- Returns JSONB. Caller is the diagnose-matchday edge function, which calls
-- via supabase.rpc("get_pipeline_diagnostics").

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
BEGIN
    -- Cron job bodies (sanitized: only first 400 chars of command, which
    -- is enough to see whether the Authorization line references vault or
    -- the legacy 'eyJhbGciOiJIUzI1...' literal).
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

    -- Last 20 runs of match-watcher-1min
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

    -- Vault secret existence (don't return the value)
    SELECT EXISTS (
        SELECT 1 FROM vault.secrets WHERE name = 'cron_service_key'
    ) INTO vault_secret_present;

    -- SECURITY DEFINER accessor existence
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'get_cron_service_key'
    ) INTO accessor_present;

    result := jsonb_build_object(
        'cron_jobs', cron_jobs,
        'match_watcher_recent_runs', cron_runs,
        'vault_secret_cron_service_key_present', vault_secret_present,
        'get_cron_service_key_function_present', accessor_present,
        'snapshot_at', NOW()
    );

    RETURN result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_pipeline_diagnostics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_pipeline_diagnostics() TO service_role;
