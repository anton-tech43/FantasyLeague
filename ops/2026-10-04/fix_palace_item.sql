-- QA 2026-10-04: the Crystal Palace feed item called the Europa League league
-- phase a "group" and said "joint top"; Palace were 2nd on goal difference
-- behind Juventus with 16 teams on three points. It also carried fan claims
-- with no source. Rewrite every user-visible field from the facts we hold
-- (team_pages.crystal_palace europe_standings + recent_results + fixtures).
BEGIN;
UPDATE content_items SET
  headline = 'Crystal Palace are second in the Europa League table after one game, level on points with leaders Juventus.',
  body = 'Crystal Palace beat Lech Poznan 4-0 in their first Europa League game. The competition is one big 36-team table now, not groups, and Palace sit second on goal difference behind Juventus, with plenty of teams also on three points. Their next European game is away at Lyon on 15 October.',
  push_text = 'Palace are second in the Europa League table, level with Juventus. He''ll start checking flights.',
  immersive_headline = E'palace.\nsecond in europe.\nbehind juventus.',
  immersive_context_fallback = 'Crystal Palace beat Lech Poznan 4-0 in their first Europa League game and sit second in the table on goal difference behind Juventus.',
  everyone_talking_headline = 'Crystal Palace second in the Europa League table behind Juventus',
  everyone_talking_body = 'Pierre Sage''s Crystal Palace opened their Europa League campaign with a 4-0 win over Lech Poznan and sit second in the 36-team table, behind Juventus on goal difference.',
  everyone_talking_talking_points = '["Crystal Palace are second in the Europa League table after their 4-0 win over Lech Poznan, behind Juventus on goal difference.", "Pierre Sage''s side play Lyon away on 15 October in their next European game."]'::jsonb,
  talking_points = '["Tell him Crystal Palace are second in the Europa League table, level on points with Juventus. He''ll probably do a double-take.", "Ask him: is Europe actually a bigger deal for Palace this season than their Premier League position?", "Did you know their next Europa League game is away at Lyon on 15 October? Drop it in and watch him work out the geography."]'::jsonb,
  info_cards = jsonb_set(jsonb_set(info_cards,
      '{0,text}', '"Pierre Sage''s Palace started their Europa League campaign with a 4-0 win. The Europa League is one 36-team table now, so after one game lots of teams are level on three points."'),
      '{2,text}', '"Crystal Palace beat Lech Poznan 4-0 at home in their first Europa League game."')
WHERE id = '09f8dbbd-262a-4ffa-a5c7-2666cfa50ba7';
-- Expect 1 row; check the text before COMMIT.
SELECT headline, info_cards->0->>'text' AS gist, info_cards->2->>'text' AS impress
FROM content_items WHERE id = '09f8dbbd-262a-4ffa-a5c7-2666cfa50ba7';
COMMIT;
