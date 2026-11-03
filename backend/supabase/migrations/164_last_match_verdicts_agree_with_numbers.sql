-- 164: Matchday › After verdicts that contradicted the numbers printed under
-- them (bug hunt 2026-11-03, D-C14). Data only, no schema.
--
-- `_shared/last-match.ts` called every clean-sheet win "X hardly got a look
-- in", whatever the shots (Brighton 1-0 at City above "7–20 shots"), and any
-- two-goal win with a goal against "without ever making it comfortable" above
-- "The second half was a formality." (Coventry). renderVerdict now uses the
-- same shot-gap line as the numbers (SHOT_GAP = 6). The live cards (expire
-- 2026-11-07) were recomputed by running the shipped renderVerdict and
-- pickThreeNumbers over the stored score, half-time score, goal list and the
-- card's own numbers. No feed call, no model. Each UPDATE only applies while
-- the card still holds the old verdict, so a newer card is never touched.
BEGIN;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"A clean sheet, and it took some defending."'::jsonb), '{cards,last_match,numbers}', '[{"value":"7–15","caption":"shots. Nottm Forest had more of it, Brentford had the goals."},{"value":"42%","caption":"possession."},{"value":"1–1","caption":"shots on target."}]'::jsonb)
WHERE team_id = 'brentford' AND content->'cards'->'last_match'->>'fixture_id' = '1557449'
  AND content->'cards'->'last_match'->>'verdict' = '"A clean sheet, and Nottm Forest hardly got a look in."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"Not their day. Coventry took their chances."'::jsonb), '{cards,last_match,numbers}', '[{"value":"0–2","caption":"at half-time."},{"value":"17–12","caption":"shots. Not much in it."},{"value":"57%","caption":"possession."}]'::jsonb)
WHERE team_id = 'sunderland' AND content->'cards'->'last_match'->>'fixture_id' = '1557451'
  AND content->'cards'->'last_match'->>'verdict' = '"Sunderland had the chances, Coventry had the goals."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"A clean sheet, and Liverpool never had a shot on target."'::jsonb), '{cards,last_match,numbers}', '[{"value":"0","caption":"Liverpool shots on target. In the whole game."},{"value":"10–17","caption":"shots. Liverpool had more of it, Arsenal had the goal."},{"value":"44%","caption":"possession."}]'::jsonb)
WHERE team_id = 'arsenal' AND content->'cards'->'last_match'->>'fixture_id' = '1557453'
  AND content->'cards'->'last_match'->>'verdict' = '"A clean sheet, and Liverpool hardly got a look in."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"Kept a clean sheet and took the points."'::jsonb), '{cards,last_match,numbers}', '[{"value":"11–10","caption":"shots. Not much in it."},{"value":"44%","caption":"possession."},{"value":"5–1","caption":"shots on target."}]'::jsonb)
WHERE team_id = 'bournemouth' AND content->'cards'->'last_match'->>'fixture_id' = '1557448'
  AND content->'cards'->'last_match'->>'verdict' = '"A clean sheet, and Leeds hardly got a look in."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"A clean sheet, and it took some defending."'::jsonb), '{cards,last_match,numbers}', '[{"value":"7–20","caption":"shots. Man City had more of it, Brighton had the goal."},{"value":"38%","caption":"possession."},{"value":"3–5","caption":"shots on target."}]'::jsonb)
WHERE team_id = 'brighton' AND content->'cards'->'last_match'->>'fixture_id' = '1557454'
  AND content->'cards'->'last_match'->>'verdict' = '"A clean sheet, and Man City hardly got a look in."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"Not their day. Bournemouth took their chances."'::jsonb), '{cards,last_match,numbers}', '[{"value":"10–11","caption":"shots. Not much in it."},{"value":"56%","caption":"possession."},{"value":"1–5","caption":"shots on target."}]'::jsonb)
WHERE team_id = 'leeds' AND content->'cards'->'last_match'->>'fixture_id' = '1557448'
  AND content->'cards'->'last_match'->>'verdict' = '"Not their day. Bournemouth were the better side."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"Kept a clean sheet and took the points."'::jsonb), '{cards,last_match,numbers}', '[{"value":"16–17","caption":"shots. Not much in it."},{"value":"48%","caption":"possession."},{"value":"5–2","caption":"shots on target."}]'::jsonb)
WHERE team_id = 'everton' AND content->'cards'->'last_match'->>'fixture_id' = '1557455'
  AND content->'cards'->'last_match'->>'verdict' = '"A clean sheet, and Newcastle hardly got a look in."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"Not their day. Everton took their chances."'::jsonb), '{cards,last_match,numbers}', '[{"value":"17–16","caption":"shots. Not much in it."},{"value":"52%","caption":"possession."},{"value":"2–5","caption":"shots on target."}]'::jsonb)
WHERE team_id = 'newcastle' AND content->'cards'->'last_match'->>'fixture_id' = '1557455'
  AND content->'cards'->'last_match'->>'verdict' = '"Not their day. Everton were the better side."'::jsonb->>0;

UPDATE public.team_pages
SET content = jsonb_set(jsonb_set(content, '{cards,last_match,verdict}', '"Clear by half-time, and they saw it out."'::jsonb), '{cards,last_match,numbers}', '[{"value":"2–0","caption":"at half-time. The second half was a formality."},{"value":"12–17","caption":"shots. Not much in it."},{"value":"43%","caption":"possession."}]'::jsonb)
WHERE team_id = 'coventry' AND content->'cards'->'last_match'->>'fixture_id' = '1557451'
  AND content->'cards'->'last_match'->>'verdict' = '"Won it, without ever making it comfortable."'::jsonb->>0;

COMMIT;
