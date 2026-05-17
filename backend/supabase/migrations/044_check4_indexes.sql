-- 044_check4_indexes.sql
-- Indexes to make CHECK 4 (matchday SLA) cheap at WC scale.
--
-- CHECK 4 (defined in migration 039) does:
--   SELECT COUNT(*) FROM match_status_state mss
--   WHERE mss.fired_finished_at > NOW() - INTERVAL '1 hour'
--     AND NOT EXISTS (
--       SELECT 1 FROM content_items ci
--       WHERE ci.match_id = mss.fixture_id::text
--         AND ci.type = 'matchday'
--         AND ci.created_at > mss.fired_finished_at - INTERVAL '1 minute'
--         AND ci.created_at < mss.fired_finished_at + INTERVAL '15 minutes'
--     );
--
-- At today's scale (~25 rows in match_status_state, ~few hundred
-- content_items), a Seq Scan + correlated subquery is fast. At WC
-- scale (~100s of match_status_state rows including PL + WC fixtures,
-- ~thousands of content_items), the planner benefits from explicit
-- indexes. The heartbeat cron runs every 30 min — every saved
-- millisecond matters because we run it for years.

-- Partial index on match_status_state.fired_finished_at: most rows
-- have NULL (matches not yet finished), so a partial index covers
-- only the rows that qualify for CHECK 4's outer filter.
CREATE INDEX IF NOT EXISTS idx_match_status_state_fired_finished_at
  ON match_status_state (fired_finished_at DESC)
  WHERE fired_finished_at IS NOT NULL;

-- Composite index on content_items (match_id, type) for the CHECK 4
-- correlated NOT EXISTS lookup. Partial index excludes rows with NULL
-- match_id (news content has no match_id; only matchday rows do).
CREATE INDEX IF NOT EXISTS idx_content_items_match_type
  ON content_items (match_id, type)
  WHERE match_id IS NOT NULL;

-- Verification:
--   \d match_status_state
--   \d content_items
-- Both indexes should appear. Optional:
--   EXPLAIN ANALYZE <CHECK 4's body query>;
-- Should show Index Scan / Index Only Scan, not Seq Scan.
