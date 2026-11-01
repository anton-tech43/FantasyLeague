-- 154: data the app council (2026-11-01) found wrong. Data only, no schema.
--
-- 1. Archive man_utd card cdda8368 ("Carrick gets one more chance"): its body
--    states Newcastle wanted "around £3m in compensation" for Eddie Howe, a
--    rumour the feed carried as fact.
-- 2. Coventry and Hull manager cards called this their first top-flight /
--    Premier League season. Coventry were in the top flight 1967-2001 (founder
--    members of the Premier League in 1992, relegated 2001); Hull played
--    Premier League seasons in 2008-10, 2013-15 and 2016-17. Both are back,
--    not new. post_team_page.sh now rejects the claim (goaldigger-routines).
-- 3. Coventry's rival is Aston Villa, the club their supporters name as the
--    biggest rival (Football Ground Guide supporter survey,
--    https://footballgroundguide.com/news/coventry-city-biggest-rivals.html),
--    not Birmingham City (seed migration 091).
BEGIN;

UPDATE public.content_items SET status = 'archived'
WHERE id = 'cdda8368-d359-43a3-ab3e-6324c978b27d';

UPDATE public.team_pages SET content = jsonb_set(jsonb_set(content,
  '{cards,manager,talking_point}', to_jsonb('Lampard has been in charge since 2024, and this is Coventry''s first top-flight season since 2001.'::text)),
  '{cards,manager,summary}', to_jsonb('Frank Lampard has been in charge since late 2024. Coventry are back in the top flight for the first time since 2001, and the Premier League has been a very steep step up, which the results reflect.'::text))
WHERE team_id = 'coventry';

UPDATE public.team_pages SET content = jsonb_set(jsonb_set(content,
  '{cards,manager,talking_point}', to_jsonb('Jakirović has been in charge since 2025 and has Hull competitive on their return to the Premier League.'::text)),
  '{cards,manager,summary}', to_jsonb('Sergej Jakirović took over in the summer of 2025 and is now in his second year in charge, which includes Hull''s first Premier League season since 2017. Tenth place after eight games is a strong start for a newly promoted side.'::text))
WHERE team_id = 'hull';

UPDATE public.team_pages SET content = jsonb_set(content, '{cards,rivalry}',
  (content->'cards'->'rivalry') || jsonb_build_object(
    'rival', 'Aston Villa',
    'text', 'Coventry fans name Aston Villa as their biggest rivals, the Birmingham club up the road they met season after season in the top flight. With both in the Premier League again, Coventry v Villa is a Midlands derby with real needle.',
    'updated_at', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
WHERE team_id = 'coventry';

COMMIT;
