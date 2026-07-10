-- 051_consequence_layer.sql
--
-- Cross-team consequence layer. When a match FTs, match-watcher runs a
-- deterministic detector (`_shared/detect-consequences.ts`, pure math, no
-- LLM) against the latest standings snapshot in `raw_fetch_logs`. For each
-- non-playing team whose race state mathematically changes (title-won,
-- relegated, UCL-clinched, etc), we INSERT a templated content_items row
-- with the affected team's team_id. notification-sender's existing per-
-- team routing then pushes to that team's subscribers — no change to the
-- push pipeline required.
--
-- Two structural changes here:
--
-- 1. `consequence_type` column on content_items. NULL for normal content
--    (news/matchday/insider/quiz/etc); SET for templated cross-team rows.
--    Examples: TITLE_WON, RELEGATED, UCL_CLINCHED, EUROPE_CLINCHED,
--    WC_KNOCKOUT_QUALIFIED, WC_KNOCKOUT_ELIMINATED, WC_GROUP_WON.
--
-- 2. Partial unique index on (team_id, consequence_type) for non-null
--    values. Same consequence for the same team is a no-op INSERT via
--    ON CONFLICT — we never push "Arsenal are champions" twice. At PL
--    season boundary, run a one-line UPDATE to NULL prior-season rows so
--    next season's clinches can fire (RUNBOOK).
--
-- 3. Extend pipeline_health.stage CHECK with `consequence_fire` so Phase
--    J observability captures every consequence INSERT attempt.
--
-- Context: 2026-05-19 Bournemouth-City 1-1 mathematically confirmed
-- Arsenal as PL champions. Arsenal subscribers got zero push because
-- notification-sender only routes by content_items.team_id (=man_city),
-- and the next gd-news fire wasn't until 06:30 the next morning. This
-- migration + detector closes that gap. See IMPLEMENTATION_PROGRESS
-- Lesson 74.

-- 1. consequence_type column
ALTER TABLE content_items ADD COLUMN consequence_type TEXT;
COMMENT ON COLUMN content_items.consequence_type IS
  'When set, marks this row as a templated cross-team consequence push '
  '(TITLE_WON, RELEGATED, UCL_CLINCHED, EUROPE_CLINCHED, '
  'WC_KNOCKOUT_QUALIFIED, WC_KNOCKOUT_ELIMINATED, WC_GROUP_WON). '
  'Inserted by match-watcher after FT via the deterministic detector. '
  'Idempotent per (team_id, consequence_type) via the partial unique '
  'index below. See migration 051 + Lesson 74.';

-- 2. Partial unique index — one row per team per consequence type. The
-- partial-index predicate (WHERE consequence_type IS NOT NULL) means
-- normal content_items with NULL consequence_type are unaffected.
CREATE UNIQUE INDEX idx_one_consequence_per_team_per_type
  ON content_items (team_id, consequence_type)
  WHERE consequence_type IS NOT NULL;

-- 3. pipeline_health.stage CHECK — add consequence_fire. Mirror the
-- drop+re-add pattern from migrations 040, 047.
ALTER TABLE pipeline_health
  DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;

ALTER TABLE pipeline_health
  ADD CONSTRAINT pipeline_health_stage_check
  CHECK (stage = ANY (ARRAY[
    -- Legacy stages
    'fetch',
    'generate',
    'review',
    'safety_review',
    'publish',
    -- V2.x observability stages
    'live_brief_fire',
    'matchday_fire',
    'routine_post',
    'apns_send',
    'cron_invoke',
    -- V2.0 push surfaces
    'morning_push',
    'starting_xi_fire',
    -- V2.0 cross-team consequence layer (this migration)
    'consequence_fire'
  ]));
