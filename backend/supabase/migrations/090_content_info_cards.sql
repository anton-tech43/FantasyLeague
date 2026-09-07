-- 090: content_items.info_cards
--
-- Product change, 2026-09-07 (Anton, from the Champions League cards):
-- "Things to say" had become a place for information. The two talking points
-- on the CL opener were a fixture list. Useful, but not a line anyone says.
--
-- So the detail view gets two sections with two different jobs:
--   info_cards      — what she needs to KNOW. Up to three, levelled:
--                     1 = the gist, 2 = the wider picture (who they play,
--                     what it means), 3 = "to impress" — the detail that
--                     makes her sound like she follows it. Levels 1-2 show;
--                     level 3 sits behind a tap.
--   talking_points  — what she can SAY. Lines and openers only.
--
-- Shape: [{"level":1,"title":"...","text":"..."}, ...]. A level-3 card may
-- carry a "fixture" object so the app can render the two crests + kickoff
-- as the card's picture: {"home":"Napoli","away":"Arsenal",
-- "home_api_id":492,"away_api_id":42,"kickoff":"2026-09-09T19:00:00Z",
-- "competition":"Champions League"}.
--
-- Nullable: every existing row and the Edge templates leave it NULL and the
-- app hides the section.

ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS info_cards jsonb;

ALTER TABLE content_items
  DROP CONSTRAINT IF EXISTS content_items_info_cards_shape;
ALTER TABLE content_items
  ADD CONSTRAINT content_items_info_cards_shape CHECK (
    info_cards IS NULL
    OR (jsonb_typeof(info_cards) = 'array' AND jsonb_array_length(info_cards) <= 3)
  );

COMMENT ON COLUMN content_items.info_cards IS
  'Up to 3 {level 1-3, title, text, fixture?} cards. What she needs to know; talking_points is what she can say. Level 3 = to impress, behind a tap.';
