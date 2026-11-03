-- 163: a goal ruled out by VAR stayed in the stored goal list (bug hunt
-- 2026-11-03, P-C1). Data only, no schema.
--
-- Chelsea 2-0 Man Utd (fixture 1557450, 2026-10-31): Estêvão's 71' goal was
-- ruled out after match-watcher had stored its scorer, so goal_events kept
-- three goals and both clubs' Matchday › After cards listed "3–0 Chelsea"
-- under a 2-0 score (live until 2026-11-07). The feed's own article for the
-- game says the goal was ruled out by VAR. match-watcher now holds the list
-- to the score (reconcileGoalEvents) and re-reads the feed whenever the two
-- disagree, so this cannot recur; this removes the one live phantom.
--
-- Every other finished fixture whose list disagrees with its score has a list
-- that is SHORT (a scorer never published), which is missing data, not a
-- wrong goal, and their After cards expired long ago.
BEGIN;

UPDATE public.match_status_state
SET goal_events = (
  SELECT jsonb_agg(e ORDER BY ord)
  FROM jsonb_array_elements(goal_events) WITH ORDINALITY AS t(e, ord)
  WHERE NOT (e->>'playerApiId' = '425733' AND e->>'minute' = '71')
)
WHERE fixture_id = 1557450
  AND home_goals = 2 AND away_goals = 0
  AND jsonb_array_length(goal_events) = 3;

UPDATE public.team_pages
SET content = jsonb_set(content, '{cards,last_match,goals}', (
  SELECT jsonb_agg(g ORDER BY ord)
  FROM jsonb_array_elements(content->'cards'->'last_match'->'goals') WITH ORDINALITY AS t(g, ord)
  WHERE NOT (g->>'api_player_id' = '425733' AND g->>'minute' = '71''')
))
WHERE team_id IN ('chelsea', 'man_utd')
  AND content->'cards'->'last_match'->>'fixture_id' = '1557450'
  AND jsonb_array_length(content->'cards'->'last_match'->'goals') = 3;

COMMIT;
