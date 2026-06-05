-- 059_content_audit.sql
-- Deterministic content auditor: adds the 'content_audit' observability
-- stage and a nightly cron that invokes the content-audit Edge Function.
--
-- WHY:
-- On 2026-05-31 a Sunday-brief item told West Ham followers they "stayed
-- up" while West Ham finished 18th (relegated — the PL drops the bottom
-- THREE). The routine had the right standings and reasoned wrongly. The
-- content-audit function cross-checks every recent content_item's
-- terminal claims (safe/relegated/champions/top-four) against the ACTUAL
-- league table using pure integer comparison — no LLM, no API-Football,
-- no push — and logs contradictions here for a human to act on.
--
-- The function is read-only over content_items: it NEVER mutates an item
-- and NEVER sends a push. Correcting a flagged item stays a human call.

-- 1. Allow the new pipeline_health stage.
ALTER TABLE pipeline_health DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;
ALTER TABLE pipeline_health ADD CONSTRAINT pipeline_health_stage_check
  CHECK (stage = ANY (ARRAY[
    'fetch','generate','review','safety_review','publish',
    'live_brief_fire','matchday_fire','routine_post','apns_send',
    'cron_invoke','morning_push','starting_xi_fire','consequence_fire',
    'content_audit'  -- NEW
  ]));

-- 2. Nightly cron. 03:30 UTC — after the 03:00 pipeline_health retention
--    sweep (mig 043) and the 03:15 raw_fetch_logs retention (mig 057),
--    and well clear of the 06:30 news routines so the table is settled.
--    Uses get_cron_service_key() (Vault) so no literal key lives in the
--    job body; require-service-auth accepts it via CRON_AUTH_KEY.
SELECT cron.schedule(
  'content-audit-nightly',
  '30 3 * * *',
  $$
    SELECT net.http_post(
      url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/content-audit',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || get_cron_service_key()
      ),
      body := '{"days": 7}'::jsonb
    )
  $$
);

-- Verification:
--   SELECT jobname, schedule, active FROM cron.job WHERE jobname='content-audit-nightly';
--     -> one row, '30 3 * * *', active = true
--   Manual run (service key from backend/.env):
--     curl -sX POST .../functions/v1/content-audit -H "Authorization: Bearer $KEY" \
--          -H 'Content-Type: application/json' -d '{"days":30,"dryRun":true}'
--   Review findings:
--     SELECT created_at, team_id, error_class, message FROM pipeline_health
--      WHERE stage='content_audit' AND status IN ('failure','partial')
--      ORDER BY created_at DESC;
