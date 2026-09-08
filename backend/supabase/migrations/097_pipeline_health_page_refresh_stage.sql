-- 097_pipeline_health_page_refresh_stage.sql
--
-- match-watcher now re-fetches the standings and fixtures of the clubs that
-- just played, from the whistle rather than from the next two-hourly cron slot
-- (see _shared/page-refresh.ts). It logs one pipeline_health row per fixture so
-- "did the table move when Arsenal finished" is a query.
--
-- pipeline_health.stage is a CHECK-constrained enum-by-convention, so the new
-- stage has to be named here or every insert fails silently in a catch block.

ALTER TABLE pipeline_health DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;

ALTER TABLE pipeline_health ADD CONSTRAINT pipeline_health_stage_check
  CHECK (stage = ANY (ARRAY[
    'fetch',
    'generate',
    'review',
    'safety_review',
    'publish',
    'live_brief_fire',
    'matchday_fire',
    'routine_post',
    'apns_send',
    'cron_invoke',
    'morning_push',
    'starting_xi_fire',
    'consequence_fire',
    'content_audit',
    'watch',
    'page_refresh'
  ]));
