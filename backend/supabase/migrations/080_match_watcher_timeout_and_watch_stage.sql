-- 080_match_watcher_timeout_and_watch_stage.sql
-- A17 hardening (audit 2026-09): match-watcher was blind to every PL fixture
-- 21 Aug–6 Sep 2026 while the nano DB was IO-starved. Two contributing gaps:
--
--  1. pg_net's default timeout is 5 000 ms (net.http_post ... timeout_milliseconds
--     DEFAULT 5000) and no cron command overrode it. match-watcher does 4–6
--     sequential PostgREST calls (each capped at the authenticator role's 8 s
--     statement_timeout) plus 1–2 API-Football calls; one slow query is enough
--     to abort the request client-side and lose the tick. Re-schedule with a
--     30 s timeout. Same command otherwise (Vault-backed key, migration 020).
--
--  2. match-watcher never wrote a pipeline_health row for its OWN run — only
--     for events (apns_send / matchday_fire / live_brief_fire / consequence_fire)
--     — so 27 days of "ran but wrote nothing" left no trace. Add a 'watch' stage
--     for the aggregated per-run row the patched function now writes (hourly
--     heartbeat + every anomalous tick; see match-watcher/index.ts).
--
-- Applied manually (schema_migrations only tracks 001–017, see A12).

-- 1. match-watcher cron: explicit 30 s pg_net timeout
SELECT cron.unschedule('match-watcher-1min')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-watcher-1min');

SELECT cron.schedule(
  'match-watcher-1min',
  '* * * * *',
  $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
    )$$
);

-- 2. pipeline_health.stage: allow 'watch'
ALTER TABLE pipeline_health DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;
ALTER TABLE pipeline_health ADD CONSTRAINT pipeline_health_stage_check CHECK (
  stage = ANY (ARRAY[
    'fetch','generate','review','safety_review','publish','live_brief_fire','matchday_fire',
    'routine_post','apns_send','cron_invoke','morning_push','starting_xi_fire',
    'consequence_fire','content_audit','watch'
  ])
);

-- Verification:
--   SELECT jobname, schedule, active, command FROM cron.job WHERE jobname = 'match-watcher-1min';
--     -- command contains timeout_milliseconds := 30000
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'pipeline_health_stage_check';
--   -- after deploying the patched function, on the next matchday:
--   SELECT created_at, status, message FROM pipeline_health WHERE stage = 'watch' ORDER BY created_at DESC LIMIT 5;
