-- 040_pipeline_health_safety_review_stage.sql
-- Fix: restore 'safety_review' to the pipeline_health.stage CHECK constraint.
--
-- Migration 038 expanded the stage CHECK to add the V2.x observability
-- stages (live_brief_fire, matchday_fire, apns_send, routine_post,
-- cron_invoke) but dropped 'safety_review' from the legacy set without
-- noticing. content-reviewer/index.ts:257 still writes rows with
-- stage='safety_review' on every safety-review hop, so since 038 those
-- inserts have silently failed the CHECK — caught only by the
-- surrounding try/catch in the function, leaving zero observability
-- rows for the safety-review hop.
--
-- The fix: drop and re-add the constraint with 'safety_review' included.
-- Idempotent: safe to re-apply.

ALTER TABLE pipeline_health
  DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;

ALTER TABLE pipeline_health
  ADD CONSTRAINT pipeline_health_stage_check
  CHECK (stage = ANY (ARRAY[
    -- Legacy stages (data-fetcher + content-generator path)
    'fetch',
    'generate',
    'review',
    'safety_review',     -- RESTORED (was dropped by 038)
    'publish',
    -- V2.x observability stages (added in 038)
    'live_brief_fire',
    'matchday_fire',
    'routine_post',
    'apns_send',
    'cron_invoke'
  ]));

-- Verification:
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint
--    WHERE conname = 'pipeline_health_stage_check';
-- Expected: ARRAY contains 'safety_review'.
