-- 047_pipeline_health_morning_push_stage.sql
--
-- Adds two V2.0 stages to the pipeline_health.stage CHECK constraint:
--
-- 1. 'morning_push' — written by the new morning-push Edge Function (cron
--    0 8 * * * UTC) per (user_token, fixture) push attempt. Target shape:
--    morning_push:<team_id>:<fixture_id>.
-- 2. 'starting_xi_fire' — written by match-watcher's new pre-kickoff
--    trigger that fires the gd-starting-xi cloud routine ~60min before
--    kickoff. Target shape: starting_xi_fire:<team_id>:<fixture_id>:STARTING_XI.
--
-- Mirrors migration 040's pattern: drop and re-add the constraint with
-- the new values included. Idempotent.

ALTER TABLE pipeline_health
  DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;

ALTER TABLE pipeline_health
  ADD CONSTRAINT pipeline_health_stage_check
  CHECK (stage = ANY (ARRAY[
    -- Legacy stages (data-fetcher + content-generator path)
    'fetch',
    'generate',
    'review',
    'safety_review',
    'publish',
    -- V2.x observability stages (added in 038, 040)
    'live_brief_fire',
    'matchday_fire',
    'routine_post',
    'apns_send',
    'cron_invoke',
    -- V2.0 push surfaces (added in this migration)
    'morning_push',
    'starting_xi_fire'
  ]));
