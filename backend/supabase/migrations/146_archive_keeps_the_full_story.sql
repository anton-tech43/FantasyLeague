-- 146_archive_keeps_the_full_story.sql
--
-- The daily archive job (goaldigger-archive-old-content, 06:00 UTC) had two
-- blind spots, both found by the app council on 2026-10-29.
--
-- 1. FEED-01-53 / MD-07-16. The full-time article (type 'matchday') was archived
--    like any other card after seven days. It is also what Matchday > After's
--    "The full story" opens (APIClient.fetchMatchArticle filters
--    status='published'), and that card shows the club's LAST match however old
--    it is: over an international break the link pointed at an archived row and
--    vanished. A full-time article now stays published while it is its club's
--    latest one; once a newer one exists it archives on the normal seven days.
--
-- 2. MY-16-03. Rows with preview_fixture_id were exempt outright (a preview is
--    often written days before its game), so they were never archived at all:
--    7 World Championship previews from July were still 'published' in the
--    shared Football feed in late October, beside ~45 country previews from
--    May-June. A preview now archives once its fixture is a day past. The
--    fixture day comes from kickoff_time, else the date inside the id
--    ("england:2026-06-17:croatia"), else match_status_state, else 30 days after
--    publishing. Compared as ISO date TEXT, never cast, so one malformed id
--    cannot make the whole daily UPDATE throw and stop archiving everything.
--
-- The seven World Championship rows are archived here and now (counted at 7 on
-- 2026-10-30 before writing this). The country previews and the two finished
-- club previews (man_utd 10-17, arsenal after 11-03) go with the next 06:00 run.

BEGIN;

UPDATE content_items
SET status = 'archived'
WHERE status = 'published'
  AND team_id = 'world_championship'
  AND preview_fixture_id IS NOT NULL
  AND published_at < '2026-08-01';

SELECT cron.schedule('goaldigger-archive-old-content', '0 6 * * *', $job$
    UPDATE content_items c
    SET status = 'archived'
    WHERE c.status = 'published'
      AND c.published_at < NOW() - INTERVAL '7 days'
      AND (
        -- a preview: once its fixture is a day past
        (c.preview_fixture_id IS NOT NULL
          AND coalesce(to_char(c.kickoff_time AT TIME ZONE 'UTC', 'YYYY-MM-DD'),
                       substring(c.preview_fixture_id from '\d{4}-\d{2}-\d{2}'),
                       (SELECT to_char(m.kickoff_time AT TIME ZONE 'UTC', 'YYYY-MM-DD')
                          FROM match_status_state m WHERE m.fixture_id::text = c.preview_fixture_id),
                       to_char(c.published_at + INTERVAL '30 days', 'YYYY-MM-DD'))
              < to_char(NOW() - INTERVAL '1 day', 'YYYY-MM-DD'))
        -- a full-time article: only once its club has a newer one
        OR (c.preview_fixture_id IS NULL AND c.type = 'matchday'
          AND EXISTS (SELECT 1 FROM content_items n
                       WHERE n.team_id = c.team_id AND n.type = 'matchday'
                         AND n.status = 'published' AND n.published_at > c.published_at))
        -- everything else: seven days, as before
        OR (c.preview_fixture_id IS NULL AND c.type <> 'matchday')
      );
$job$);

COMMIT;
