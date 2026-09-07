-- 086_content_significance.sql
-- Weight a news item, so the pipeline can tell a sacking from squad chatter.
--
-- Two things need this and neither could be built without it:
--
--  1. TIERS.md. The Light tier's promise is "she'll never be blindsided by
--     something big" and Match-fit's is "news that matters". Today every row in
--     content_items weighs the same, so the only tier filter that exists is
--     `type = 'sunday_brief' ? 2 : 1` — a Light user and a Deep user get the
--     same pushes minus one Sunday Brief. Nobody in prod has ever chosen Light.
--
--  2. PROMPT.md:413 already says "If the news is genuinely boring or too niche,
--     skip it. We NEVER spam." That is a sentiment, not a test. The 2026 World
--     Cup shipped "spain. betting favourites." (a bookmaker's price) and
--     "england. starting to click." (a manager's quote) as feed cards.
--
-- Deliberately not backfilled: the archive cron clears the feed after 7 days,
-- so the column fills itself within a week.

ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS significance smallint;

COMMENT ON COLUMN content_items.significance IS
  '2 = big (manager sacked/appointed, major signing or exit, serious injury, '
  'trophy, promotion/relegation, elimination). 1 = ordinary (a real event a '
  'follower would want: a result, a confirmed transfer, a squad announcement). '
  '0 = minor (gossip-column links, pundit opinion, betting odds, colour). '
  'NULL = written before migration 086. Set by the routines and validated in '
  'post_news.sh; read by notification-sender to decide the minimum tier.';

ALTER TABLE content_items
  DROP CONSTRAINT IF EXISTS content_items_significance_check;
ALTER TABLE content_items
  ADD CONSTRAINT content_items_significance_check
  CHECK (significance IS NULL OR significance BETWEEN 0 AND 2);

-- notification-sender's per-item lookup is by id, but the tier sweep and the
-- insights views scan by (team, published_at) and will want to filter on weight.
CREATE INDEX IF NOT EXISTS idx_content_significance
  ON content_items (team_id, significance, published_at DESC)
  WHERE status = 'published';
