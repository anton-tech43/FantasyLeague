-- 008_content_archive.sql
-- Goal Digger — auto-archive old content items.
--
-- Published items older than 7 days flip to status='archived' nightly.
-- The iOS app queries status=eq.published, so archived items disappear
-- from the feed while remaining in the DB for analytics/debugging.

-- Extend status check constraint to include 'archived' and 'retrying'
-- (retrying was added in code but never made it into the constraint).
ALTER TABLE content_items DROP CONSTRAINT IF EXISTS content_items_status_check;
ALTER TABLE content_items
  ADD CONSTRAINT content_items_status_check
  CHECK (status IN ('draft', 'approved', 'rejected', 'published', 'retrying', 'archived'));

-- Remove any previous schedule with the same name before re-creating (idempotent).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-archive-old-content') THEN
    PERFORM cron.unschedule('goaldigger-archive-old-content');
  END IF;
END $$;

-- Schedule: 06:00 UTC daily (1 hour before the 07:00 content pipeline).
SELECT cron.schedule(
    'goaldigger-archive-old-content',
    '0 6 * * *',
    $$
    UPDATE content_items
    SET status = 'archived'
    WHERE status = 'published'
      AND published_at < NOW() - INTERVAL '7 days';
    $$
);
