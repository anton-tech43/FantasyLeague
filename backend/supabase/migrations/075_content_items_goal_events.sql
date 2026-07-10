-- 075_content_items_goal_events.sql
-- Show goal scorers + minutes inside the post-game NEWS article (the FT result
-- content_item written by match-watcher), not just the live box. Stores a
-- display-ready scorer list on the result row so iOS ContentDetailView can
-- render it with no extra fetch.
--
-- Shape (DisplayScorer[] from _shared/goal-push.ts):
--   [{ "side":"home"|"away", "team":"Norway", "player":"Haaland",
--      "minute":"23'", "penalty":false }, ...]  (chronological)

ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS goal_events JSONB;
