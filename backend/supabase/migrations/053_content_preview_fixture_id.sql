-- 053_content_preview_fixture_id.sql
--
-- Adds an optional link from a content_items row to a specific upcoming
-- fixture. Pre-tournament WC previews (Lesson 78) write one content_item
-- per opponent and set this field so the iOS Calendar tab can navigate
-- from a fixture row to its preview detail.
--
-- The fixture id is a synthetic string of the form:
--   "<team_id>:<iso-date>:<opponent-slug>"
-- Example: "england:2026-06-17:croatia"
--
-- We use a synthetic string rather than api_football's fixture.id because
-- (a) the iOS Calendar tab's UpcomingFixture struct doesn't carry the
-- api_football fixture id today (it has date + opponent + venue), and
-- (b) we want the lookup to work even before match_status_state has the
-- fixture row populated.
--
-- Default NULL, no backfill needed — existing rows are unaffected.
-- Partial index on non-null values makes the calendar-tap lookup O(1).

ALTER TABLE content_items
  ADD COLUMN preview_fixture_id TEXT;

COMMENT ON COLUMN content_items.preview_fixture_id IS
  'Optional link to a specific upcoming fixture. When set, the iOS '
  'Calendar tab uses this to navigate from a fixture row to the '
  'preview''s ContentDetailView. Format: "<team_id>:<iso-date>:'
  '<opponent-slug>". See Lesson 78.';

CREATE INDEX idx_content_items_team_preview
  ON content_items (team_id, preview_fixture_id)
  WHERE preview_fixture_id IS NOT NULL;
