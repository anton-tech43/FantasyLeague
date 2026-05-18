-- 049_content_affected_teams.sql
--
-- Adds an `affected_team_ids` array column to content_items so the iOS
-- ContentDetailView can render team crests for the teams referenced by
-- a news item. The user-facing contract:
--   - 1 entry  → render 1 crest above the headline
--   - 2 entries → render 2 crests side-by-side
--   - 3+ entries → render no crests (matchday-wide stories, "everyone's
--     talking" cross-team items)
--   - NULL (legacy rows pre-migration) → render no crests
--
-- Populated by:
--   - content-generator/index.ts (Edge Function): Claude judges which
--     teams the headline/body explicitly references.
--   - routines (post_news.sh, post_matchday.sh, etc.): forward the field
--     when the routine emits it. For matchday items the field is
--     mechanical ([home_team_id, away_team_id]); for news items Claude
--     judges.
--
-- Nullable for back-compat — old rows without the field render with no
-- crests, which matches the "3+ or unknown → none" UX fallback.

ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS affected_team_ids TEXT[];

COMMENT ON COLUMN content_items.affected_team_ids IS
  'Up to ~5 team_ids referenced by this content item. iOS renders crests for items with array length 1 or 2; >2 hides crests. Populated by content-generator + routine post scripts.';

-- Verification:
--   \d content_items
-- Expected: affected_team_ids | text[] | nullable.
