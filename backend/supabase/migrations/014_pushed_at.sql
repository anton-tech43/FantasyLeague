-- 014_pushed_at.sql
-- Track which content_items have actually shipped APNs pushes, so failed
-- pushes can be detected and re-sent.
--
-- Today: post_news.sh fires notification-sender best-effort after insert.
-- If APNs is down for 30 min, items publish but pushes are lost forever.
-- No audit trail. Users complain tomorrow; we can't tell which items missed
-- pushes vs got them.
--
-- Add pushed_at TIMESTAMPTZ. notification-sender writes it on a successful
-- send (or a deliberate skip — no eligible tokens, anti-spam blocked, etc.).
-- The hourly notification-sweep cron then has a definite "this item didn't
-- push, re-fire it" target.

ALTER TABLE content_items
ADD COLUMN pushed_at TIMESTAMPTZ;

-- Backfill: any item already published before this column existed has either
-- already been pushed (via the legacy path or post_news.sh) or it never will.
-- Mark them all as pushed so the sweep doesn't try to push 150+ historical
-- items in a flood.
UPDATE content_items
SET pushed_at = COALESCE(published_at, created_at)
WHERE status = 'published' AND pushed_at IS NULL;

-- Sparse index: only the rows the sweep cares about (status=published but
-- not yet pushed). Cheaper than indexing every row.
CREATE INDEX idx_content_items_unpushed ON content_items(published_at)
    WHERE status = 'published' AND pushed_at IS NULL;

COMMENT ON COLUMN content_items.pushed_at IS
  'When notification-sender finished processing this item (success, skip, or no-tokens). NULL means the push has not yet been attempted or the attempt failed and should be retried by the sweep.';
