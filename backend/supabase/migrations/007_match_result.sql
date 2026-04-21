-- 007_match_result.sql
-- Goal Digger — Add match_result to content_items
--
-- Short formatted string like "Liverpool 2-1 Everton" for match-related items.
-- Shown as a header pill in the iOS detail view so users who don't read the
-- body still see the score + teams involved.
-- Nullable: only populated when is_match_related=true.

ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS match_result TEXT;
