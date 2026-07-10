-- 057_raw_fetch_logs_retention.sql
-- Daily cron: trim raw_fetch_logs to the last 7 days, ALWAYS preserving the
-- latest snapshot per (source, team_id) so "get latest" reads never lose
-- data even for a source that stopped refreshing.
--
-- Why (Lesson 84 — the Disk IO budget alert, 2026-06-01):
-- raw_fetch_logs grew to 93,727 rows / 340 MB of large JSONB over six weeks,
-- never pruned. The hot reads —
--     .eq("team_id", X).eq("source", Y).order("fetched_at" DESC).limit(1)
-- run after EVERY full-time (detect-consequences) and on EVERY team-page
-- regen (once per source). Under the old (team_id, fetched_at) index those
-- seek the team then read ~55 large JSONB heap rows to filter by source —
-- ~1.39M heap tuples fetched across 25k scans. That heap churn drained the
-- Supabase Disk IO budget.
--
-- Shipped alongside this migration (not in this file — applied directly):
--   - Composite index idx_raw_fetch_team_source_date (team_id, source,
--     fetched_at DESC) so single-source "latest" reads do ONE heap fetch.
--   - One-time trim of 61,475 stale rows (93,727 -> 32,252).
--
-- This cron keeps the table bounded. Only the latest snapshot per
-- (source, team_id) is read for current data; 7 days is generous headroom
-- for team-page-generator's limit(100) recent-rows read. Nothing
-- user-facing depends on raw logs older than 7 days — team_pages and
-- content_items are the derived sources of truth.

SELECT cron.schedule(
  'raw_fetch_logs_retention_sweep',
  '15 3 * * *',  -- daily 03:15 UTC, just after pipeline_health sweep (03:00)
  $$
    DELETE FROM raw_fetch_logs r
    WHERE r.fetched_at < NOW() - INTERVAL '7 days'
      AND r.id NOT IN (
        SELECT DISTINCT ON (source, team_id) id
        FROM raw_fetch_logs
        ORDER BY source, team_id, fetched_at DESC
      );
  $$
);

-- Verification:
--   SELECT jobname, schedule, active FROM cron.job
--    WHERE jobname = 'raw_fetch_logs_retention_sweep';
-- Expected: one row, schedule = '15 3 * * *', active = TRUE.
