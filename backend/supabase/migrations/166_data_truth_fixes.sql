-- 166: facts the 2026-11-03 bug hunt (hunter D, data truth) found wrong on
-- stored rows. Data only, no schema. Every change is a guarded text replace:
-- a row the routines have since rewritten no longer matches and is left alone
-- (each block raises a NOTICE for a pair that matched nothing).
--
-- Checked against the 2026-11-03 06:00 standings snapshot, match_status_state
-- and `players` (stats_updated_at 2026-11-02):
--   Arsenal 24 pts (9), Man City 21 (9), Everton 7th 13 (9), Newcastle 13th
--   11 (9), Hull 11th 11 (9: 2W 5D 2L, 11-10 goals), Ipswich 14th 11 (14-18),
--   Coventry 16th 9 (3W 0D 6L, 9-16), Sunderland 20th 5 (1W 2D 6L, 7-17).
--   Arsenal and Man City have no draws either, so Coventry are not "the only"
--   club without one. Only Crystal Palace (21) have conceded more than Ipswich.
--   N. Mendy: 7 starts in 7 appearances; Hull have played 9 league games.
--   M. Tavernier: 6 goals (5 league), the squad's top scorer; Evanilson 5+4.
--   Ipswich were First Division runners-up in 1980-81, the UEFA Cup season
--   (Aston Villa won the title); their only title is 1962.
--   Hull played Premier League seasons 2008-10, 2013-15 and 2016-17 (mig 154).
--   Adli's goal for Bournemouth v Leeds was 90+5 (goal_events).
--
-- D-C5 man_city season summary; D-C6 everton/newcastle prose written before
-- their Monday game; D-C4 two ones_to_know superlatives; D-C7 insider items;
-- D-C12 player dossiers; D-C13 feed points/games claims and the Hull "first
-- win" headline; D-C11 the Leeds "90th"; D-C10 the Liverpool match_result.
-- The routines that wrote them are fixed separately (goaldigger-routines).
BEGIN;

-- ── team_pages prose ────────────────────────────────────────────────────────
DO $$
DECLARE r record; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('man_city', '{cards,season,summary}',
      'They are just a point behind Arsenal', 'They are three points behind Arsenal'),
    ('everton', '{cards,season,summary}',
      'Everton are 14th in the Premier League after eight games with ten points, two wins, four draws and two losses from a steady but unspectacular start.',
      'Everton are seventh in the Premier League after nine games with 13 points, three wins, four draws and two losses from a steady start.'),
    ('everton', '{cards,form,form_summary}',
      'Two losses and a draw from the last three league games has [his name] a little anxious, even if Everton picked up a big League Cup win against Newcastle midweek to give some encouragement.',
      'Monday''s 1-0 win at Newcastle ended a run of two league defeats, on top of a League Cup win over the same opponents the week before, so [his name] has reason to be cheerful.'),
    ('newcastle', '{cards,season,summary}',
      'Newcastle are 12th in the Premier League after eight games with 11 points, three wins, two draws and three losses',
      'Newcastle are 13th in the Premier League after nine games with 11 points, three wins, two draws and four losses'),
    ('newcastle', '{cards,season,summary}',
      'with Everton at home next in a league game', 'with Fulham away next in a league game')
  ) v(team_id, path, old, new) LOOP
    UPDATE public.team_pages
       SET content = jsonb_set(content, r.path::text[], to_jsonb(replace(content #>> r.path::text[], r.old, r.new)))
     WHERE team_id = r.team_id AND strpos(content #>> r.path::text[], r.old) > 0;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN RAISE NOTICE 'team_pages no match: % %', r.team_id, left(r.old, 40); END IF;
  END LOOP;

  -- ones_to_know one-liners (an array element; the phrase is unique in the page)
  FOR r IN SELECT * FROM (VALUES
    ('hull', 'who has started every game and been', 'who has started every game he has played and been'),
    ('bournemouth', 'has been directly involved in more goals than anyone else in the squad this season',
      'is the squad''s top scorer this season with six goals')
  ) v(team_id, old, new) LOOP
    UPDATE public.team_pages SET content = replace(content::text, r.old, r.new)::jsonb
     WHERE team_id = r.team_id AND strpos(content -> 'cards' ->> 'ones_to_know', r.old) > 0;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN RAISE NOTICE 'ones_to_know no match: % %', r.team_id, left(r.old, 40); END IF;
  END LOOP;
END $$;

-- ── team_insider_items (the newest of each type is what His Team shows) ─────
DO $$
DECLARE r record; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('c7d931b5-b697-44ca-b3b8-b309185c5e28', 'Hull nearly went to League One. Now they''re fourth in the Premier League.',
      'Hull nearly went to League One. Now they''re in the Premier League.',
      'Hull City were fighting Championship relegation not long ago, with League One a real possibility. They turned it around, earned promotion to the Premier League, and are holding their own in it. Mohamed Belloumi has been their standout player, scoring twice against Chelsea and grabbing a point against Everton.'),
    ('589ded3e-74d1-48b9-a111-c6c7154bcfe3', 'Hull City have not had back-to-back results of any kind in the Premier League.',
      'Hull City have drawn five of their nine Premier League games.',
      'Two wins, five draws and two defeats. Eleven points has them 11th, with 11 goals scored and 10 conceded.'),
    ('ee323393-c6bc-4184-82d3-fb3e5df88002', 'Ipswich won the 1981 UEFA Cup despite finishing fifth in the First Division.',
      'Ipswich won the 1981 UEFA Cup in a season they also finished second in the First Division.',
      'Bobby Robson''s side beat AZ Alkmaar 5-4 on aggregate in the final and only missed the league title to Aston Villa. The win remains Ipswich''s only European trophy and one of the most unlikely in the competition''s history given the club''s size.'),
    ('0f02654e-8bd5-473a-9b60-8ffde6a18150', 'Ipswich''s 16 Premier League goals conceded is the most of any top-half club.',
      'Only Crystal Palace have conceded more Premier League goals than Ipswich''s 18.',
      'They have also scored 14, so they are producing results but leaking plenty. Eleven points from nine games has them 14th.'),
    ('bee801a8-d316-422b-8bcc-d2aa708a456d', 'Coventry are the only Premier League club with no draws in their 8 games.',
      'Coventry have not drawn any of their nine Premier League games.',
      'Six defeats and three wins from nine. Every point they have earned has come from a win, but 16 goals conceded shows how exposed they have been at the back. Nine points has them 16th.'),
    ('ca321f28-c276-4d37-a618-4cb81f53452a', 'Sunderland are bottom of the Premier League on 5 points after 8 games.',
      'Sunderland are bottom of the Premier League on 5 points after 9 games.',
      'One win, two draws and six defeats, with 7 scored and 17 conceded. The goal difference stands at -10.')
  ) v(id, old_title, new_title, new_body) LOOP
    UPDATE public.team_insider_items SET title = r.new_title, body = r.new_body
     WHERE id = r.id::uuid AND title = r.old_title;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN RAISE NOTICE 'insider no match: %', r.id; END IF;
  END LOOP;
END $$;

-- ── player_cards (dossiers) ─────────────────────────────────────────────────
DO $$
DECLARE r record; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('c7c8019d-21b1-4e46-a4ab-ea58c313d1ff', 'Hull''s first Premier League season.', 'Hull''s first Premier League season since 2017.'),
    ('467781d5-6046-4e6b-b2e0-f173cd0a2df6', 'their first Premier League season.', 'their first Premier League season since 2017.'),
    ('e0bf7e48-bbed-4ac4-ba64-7121753b929a', 'their first Premier League season.', 'their first Premier League season since 2017.'),
    ('111a8d63-28ce-4037-ae1c-342d398e0290',
      'for Newcastle, a regular across all 7 of their appearances. He scored the late winner as Newcastle edged Millwall out of the Carabao Cup.',
      'for Newcastle. He scored the late winner as Newcastle edged Millwall out of the Carabao Cup, before Everton knocked them out in the next round.')
  ) v(id, old, new) LOOP
    UPDATE public.player_cards SET summary = replace(summary, r.old, r.new)
     WHERE id = r.id::uuid AND strpos(summary, r.old) > 0;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN RAISE NOTICE 'player_cards no match: %', r.id; END IF;
  END LOOP;
END $$;

-- ── content_items (feed) ────────────────────────────────────────────────────
DO $$
DECLARE r record; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    -- Hull have two league wins (D-C13)
    ('4b45eb00-e117-4533-9ff5-47c4bc1135d7', 'ends the Tigers'' hopes of a first Premier League win', 'denies the Tigers a win'),
    ('4b45eb00-e117-4533-9ff5-47c4bc1135d7', 'Newly promoted, still searching for their first win, and yet sitting', 'Newly promoted, with two wins and plenty of draws, and sitting'),
    ('4b45eb00-e117-4533-9ff5-47c4bc1135d7', 'They looked like they were finally going to end their wait.', 'They looked like they were going to hold on for the win.'),
    ('4b45eb00-e117-4533-9ff5-47c4bc1135d7', 'deny Hull their first win.', 'deny Hull the win.'),
    ('4b45eb00-e117-4533-9ff5-47c4bc1135d7', 'No wins yet, ninth in the table', 'Two wins, five draws, ninth in the table'),
    ('4b45eb00-e117-4533-9ff5-47c4bc1135d7', 'The win will come', 'More wins will come'),
    -- Villa: written after the game it calls upcoming, with the pre-match table
    ('a30d373f-c157-4cca-9527-146f615e6522', 'Aston Villa host Fulham ahead of their Champions League tie', 'Aston Villa now turn to their Champions League tie'),
    ('a30d373f-c157-4cca-9527-146f615e6522', 'Aston Villa are 12th in the Premier League with 11 points from eight games.', 'Aston Villa have 12 points from nine Premier League games.'),
    -- Fulham: 9 after the Villa draw; eight games before it
    ('3181171f-a863-4a69-977c-9f93a156570b', 'Fulham are 16th with 8 points, still in the bottom half', 'Fulham are on 9 points, still in the bottom half'),
    ('3181171f-a863-4a69-977c-9f93a156570b', 'Fulham are 16th in the Premier League with 8 points.', 'Fulham are on 9 points in the Premier League.'),
    ('0224c008-ee30-47fb-8dd3-db2382328f39', 'with 8 points from nine games', 'with 8 points from eight games'),
    -- Man Utd and Palace matchday cards, written after their ninth game
    ('a4772c7f-671d-44ee-a6a3-c6a686f182e4', 'United stay 16th on 7 points from 8 games. Chelsea are 5th on 13.', 'United stay on 7 points from 9 games. Chelsea move up to 16.'),
    ('a4772c7f-671d-44ee-a6a3-c6a686f182e4', 'United are 16th with 7 points from 8 games', 'United have 7 points from 9 games'),
    ('a4772c7f-671d-44ee-a6a3-c6a686f182e4', 'United are 16th on 7 points from 8 games. Chelsea are 5th on 13 points.', 'United are on 7 points from 9 games. Chelsea move up to 16 points.'),
    ('9dc34667-d764-4a95-bb05-d046ca5c2a2b', 'Palace sit 18th with 7 points from 8 games.', 'Palace sit 18th with 7 points from 9 games.'),
    ('9dc34667-d764-4a95-bb05-d046ca5c2a2b', 'Palace are 18th on 7 points after 8 games.', 'Palace are 18th on 7 points after 9 games.'),
    ('9dc34667-d764-4a95-bb05-d046ca5c2a2b', '7 points from 8 games, with 2 wins, 1 draw and 5 defeats.', '7 points from 9 games, with 2 wins, 1 draw and 6 defeats.'),
    -- Adli scored on 90+5 (D-C11)
    ('532a065a-5bed-43e5-aad2-a354dcf6d811', 'added a second in the 90th.', 'added a second deep into stoppage time.'),
    ('532a065a-5bed-43e5-aad2-a354dcf6d811', 'a 90th-minute goal sealing it', 'a stoppage-time goal sealing it'),
    ('532a065a-5bed-43e5-aad2-a354dcf6d811', 'the second coming in the 90th minute.', 'the second coming deep into stoppage time.'),
    ('532a065a-5bed-43e5-aad2-a354dcf6d811', 'Adli on 90.', 'Adli on 90+5.'),
    ('532a065a-5bed-43e5-aad2-a354dcf6d811', 'Adli''s goal in the 90th made it 2-0', 'Adli''s goal deep into stoppage time made it 2-0'),
    -- the app's label regex wants "(X-Y pens)" (D-C10)
    ('5e4a9349-197e-41e2-a883-092f2cf45c6e', 'Liverpool 1-1 Chelsea, 6-5 on penalties', 'Liverpool 1-1 Chelsea (6-5 pens)')
  ) v(id, old, new) LOOP
    UPDATE public.content_items SET
      headline = replace(headline, r.old, r.new),
      body = replace(body, r.old, r.new),
      push_title = replace(push_title, r.old, r.new),
      push_text = replace(push_text, r.old, r.new),
      immersive_headline = replace(immersive_headline, r.old, r.new),
      immersive_context = replace(immersive_context, r.old, r.new),
      immersive_context_fallback = replace(immersive_context_fallback, r.old, r.new),
      match_result = replace(match_result, r.old, r.new),
      talking_points = replace(talking_points::text, r.old, r.new)::jsonb,
      info_cards = replace(info_cards::text, r.old, r.new)::jsonb
     WHERE id = r.id::uuid
       AND strpos(concat_ws('|', headline, body, push_title, push_text, immersive_headline, immersive_context,
                            immersive_context_fallback, match_result, talking_points::text, info_cards::text), r.old) > 0;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN RAISE NOTICE 'content_items no match: % %', r.id, left(r.old, 40); END IF;
  END LOOP;
END $$;

COMMIT;
