-- 006_pipeline_source.sql
-- Tag content_items by which pipeline produced them, so we can A/B the
-- Claude Code Routine experiment against the existing edge-function generator
-- (see /Users/anton/.claude/plans/glimmering-foraging-jellyfish.md).
--
-- Existing rows backfill to 'edge_function' via the column default.
-- The Routine will write rows with pipeline_source='routine'.

ALTER TABLE content_items
  ADD COLUMN pipeline_source TEXT NOT NULL
    DEFAULT 'edge_function'
    CHECK (pipeline_source IN ('edge_function', 'routine'));

CREATE INDEX idx_content_pipeline_source ON content_items(pipeline_source);
