-- 101_my_turn_content_hype.sql
-- A fourth remote content module, `hype` (2026-09-09): the lines the app shows
-- when a quiz round ends or she gets three in a row. Content, not code, so the
-- copy can grow from twelve lines a category to fifty without an app build.
-- `drills` stays in the list only so an old row cannot violate the constraint.

ALTER TABLE public.my_turn_content DROP CONSTRAINT IF EXISTS my_turn_content_module_check;
ALTER TABLE public.my_turn_content
  ADD CONSTRAINT my_turn_content_module_check
  CHECK (module IN ('saythis', 'lingo', 'quiz', 'drills', 'hype'));
