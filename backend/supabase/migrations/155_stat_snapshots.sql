-- 155: live takes, phase 0 (docs/LIVE_TAKES_PLAN.md, Anton 2026-11-01).
--
-- match_status_state.stat_snapshots: one /fixtures/statistics reading per
--   moment, { "30": …, "ht": …, "70": …, "ft": … }, each
--   { "home": SideStats, "away": SideStats, "elapsed": n, "score": "h-a", "at": iso }.
--   The half-time reading is what makes "since half-time" takes possible.
-- pipeline_health stage 'live_take': the dry run's decision per side and
--   moment, target take:<fixture>:<team>:<moment>, message
--   "<kind> | <line> | <backup>" or "silent | <reason>". Nothing is sent.
-- No function is added, so there is nothing to revoke.
-- Apply BEFORE deploying the match-watcher that writes them.

BEGIN;

ALTER TABLE public.match_status_state ADD COLUMN IF NOT EXISTS stat_snapshots jsonb;

ALTER TABLE pipeline_health DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;
ALTER TABLE pipeline_health ADD CONSTRAINT pipeline_health_stage_check
    CHECK (stage = ANY (ARRAY[
        'fetch', 'generate', 'review', 'safety_review', 'publish',
        'live_brief_fire', 'matchday_fire', 'routine_post', 'apns_send',
        'cron_invoke', 'morning_push', 'starting_xi_fire', 'consequence_fire',
        'content_audit', 'watch', 'page_refresh', 'news_feeds',
        'token_register', 'la_send', 'live_take'
    ]));

COMMIT;
