-- 038_pipeline_health_expanded.sql
-- Extend pipeline_health into the universal observability table.
--
-- Why this exists:
-- The May 17 audit found that "silent push failure" had been hitting us
-- five separate times for five different reasons (see Lesson 62). The
-- common thread: every pipeline hop has its own failure mode, and most
-- hops only log to Edge Function stderr — invisible to the DB, invisible
-- to the user.
--
-- This migration:
--  1. Adds columns to pipeline_health so a single row captures the full
--     diagnosis: target, http_status, response_excerpt, error_class.
--  2. Loosens the stage CHECK constraint to allow rows from every hop
--     (match-watcher's routine fires, notification-sender's APNs sends,
--     routine post scripts' Supabase REST POSTs, pg_cron's invocations).
--
-- Phase P.2 follows up by wiring match-watcher to write rows on every
-- live_brief_fire and matchday_fire attempt. P.3-P.5 wire the other
-- hops + add SLA checks to check_pipeline_heartbeat.

ALTER TABLE pipeline_health
  ADD COLUMN IF NOT EXISTS target TEXT,
  ADD COLUMN IF NOT EXISTS http_status INTEGER,
  ADD COLUMN IF NOT EXISTS response_excerpt TEXT,
  ADD COLUMN IF NOT EXISTS error_class TEXT;

-- Drop the old stage CHECK and re-add with the expanded set.
ALTER TABLE pipeline_health
  DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;

ALTER TABLE pipeline_health
  ADD CONSTRAINT pipeline_health_stage_check
  CHECK (stage = ANY (ARRAY[
    -- Legacy stages (data-fetcher + content-generator path)
    'fetch',
    'generate',
    'review',
    'publish',
    -- New stages (V2.x observability expansion)
    'live_brief_fire',   -- match-watcher firing gd-live-brief via routine API
    'matchday_fire',     -- match-watcher firing gd-matchday via routine API
    'routine_post',      -- routine post_*.sh POSTing to Supabase REST
    'apns_send',         -- notification-sender calling APNs
    'cron_invoke'        -- pg_cron invoking an Edge Function (CHECK 2 already
                         -- covers this at the HTTP level; this is the
                         -- per-cron-tick durable record)
  ]));

-- Allow status='partial' for aggregated hop results where some children
-- succeeded and others failed (e.g., notification-sender batching pushes
-- to multiple device_tokens, half succeed).
ALTER TABLE pipeline_health
  DROP CONSTRAINT IF EXISTS pipeline_health_status_check;

ALTER TABLE pipeline_health
  ADD CONSTRAINT pipeline_health_status_check
  CHECK (status = ANY (ARRAY['success', 'failure', 'skipped', 'partial']));

-- Make team_id nullable. Some pipeline rows are system-level (cron_invoke,
-- heartbeat checks) and don't have a single team_id. Keeps existing
-- per-team rows valid.
ALTER TABLE pipeline_health
  ALTER COLUMN team_id DROP NOT NULL;

-- Index on (stage, created_at DESC) for the SLA queries in migration 039
-- ("how many live_brief_fire failures in the last hour for fixture X").
CREATE INDEX IF NOT EXISTS idx_pipeline_health_stage_recent
  ON pipeline_health (stage, created_at DESC);

-- Index on target for diagnostic queries ("show me all rows about
-- gd-live-brief:everton:1379334").
CREATE INDEX IF NOT EXISTS idx_pipeline_health_target
  ON pipeline_health (target)
  WHERE target IS NOT NULL;

-- Verification (paste into psql to confirm):
--   \d pipeline_health    -- new columns visible, expanded CHECK shown
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'pipeline_health_stage_check';
