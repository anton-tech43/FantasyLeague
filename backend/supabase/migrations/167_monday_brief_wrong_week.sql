-- 167: the 2026-11-02 Monday briefs described the WRONG matchweek. Data only.
--
-- Found while correcting hunter D's rows (bug hunt 2026-11-03), checked brief
-- by brief against match_status_state: 15 of the 20 briefs gd-sunday-brief
-- published (and pushed) at 08:36 UTC on 2026-11-02 report the 24-25 October
-- round as "Saturday/Sunday", e.g. Chelsea "lost the London derby 2-0 to
-- Tottenham on Saturday" (they beat Man Utd 2-0; Chelsea 0-2 Spurs was 24
-- Oct), Bournemouth "thrashed Manchester United 3-0 on Sunday" (25 Oct; on
-- Saturday they beat Leeds), Ipswich "last played two weeks ago" (drew 2-2 at
-- Hull on Saturday), Man City "lost 2-1 at Aston Villa on Saturday" (lost 1-0
-- to Brighton). Those 15 are archived: the brief's subject is the result, so
-- there is nothing left to keep. The other five have one wrong clause each
-- and are corrected in place.
--
-- Arsenal's 2026-11-01 matchday card used the pre-match table: "lifts Arsenal
-- to 21 points from 8 games, level with leaders Manchester City". After the
-- win they were top on 24 from 9, three clear (standings 2026-11-03 06:00).
--
-- Undo the archive with: UPDATE content_items SET status = 'published' WHERE
-- id IN (<the ids below>);
BEGIN;

UPDATE public.content_items SET status = 'archived'
WHERE type = 'sunday_brief' AND status = 'published' AND id IN (
  'af40aafa-adf5-4cdb-8977-f04f9c525aa6', -- aston_villa: "three wins in a row" (drew Fulham, lost 3-0 at Bournemouth)
  '5c326495-dc40-480e-a38b-d22ad7ad2fac', -- bournemouth: 3-0 at Old Trafford "on Sunday" (25 Oct)
  '604451ad-04f7-4be2-9739-d96f659ac36f', -- brentford: "drew 1-1 with Hull on Sunday" (25 Oct; beat Forest 2-0)
  '5c252756-907d-43fb-8ea7-f9aa5f2f8c94', -- brighton: "lost 2-0 to Liverpool on Sunday" (won 1-0 at City)
  'cde69cea-4a5b-403b-935b-af0277c5d40e', -- chelsea: "lost 2-0 to Tottenham on Saturday" (beat Man Utd 2-0)
  '764da173-eddf-496e-bbeb-130457a7c49a', -- coventry: "haven't played since ... Spurs" (beat Sunderland 3-1)
  'd4086961-5cba-4cc8-a8b7-f70d8e4dd164', -- crystal_palace: "lost 2-0 to Newcastle on Sunday" (lost 2-0 at Spurs)
  '6b1eb4f0-1a49-4548-8dd4-ac36f99f965a', -- fulham: "won 1-0 at Coventry on Saturday" (drew 1-1 at Villa)
  'd9dcc881-ca92-4209-87ff-c2ea79ed317c', -- hull: "drew 1-1 at Brentford on Sunday" (drew 2-2 with Ipswich)
  '0a0ecf23-b690-442a-9f17-df62c86e6399', -- ipswich: "last played two weeks ago" (drew 2-2 at Hull)
  '66aacb0e-4cf7-4f5a-9a3c-7c156074353b', -- leeds: "drew 1-1 with Man Utd" (lost 2-0 at Bournemouth)
  'f9f6ef65-b59a-4b60-b6ed-12292702d8bf', -- liverpool: "beat Brighton 2-0 on Sunday" (lost 1-0 to Arsenal)
  '6ee91c36-57c6-42e9-81bf-5cd9c04f8469', -- man_city: "lost 2-1 at Aston Villa on Saturday" (lost 1-0 to Brighton)
  '28695001-a586-4dfa-8e56-ff7ed2b2eb6b', -- newcastle: "lost their last two Premier League games" (won 2-0 at Palace)
  '51d4c057-0f86-42ee-82fe-2a2b714c84c9'  -- spurs: "beat Coventry 3-1 last time out" (beat Palace 2-0)
);

DO $$
DECLARE r record; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    -- arsenal brief: 24 v 21
    ('9c57394c-4691-452f-aceb-0b32f1956952', 'one point clear of City', 'three points clear of City'),
    ('9c57394c-4691-452f-aceb-0b32f1956952', 'by one point from Manchester City', 'by three points from Manchester City'),
    ('9c57394c-4691-452f-aceb-0b32f1956952', 'Top by a point.', 'Top by three points.'),
    -- everton brief: eight league games before Monday
    ('cfa0981e-5fc3-4999-9cb4-852d7a7b9998', 'They have ten points from nine games.', 'They have ten points from eight games.'),
    -- man_utd brief: Villa drew and lost last week
    ('7dfe0511-c8ca-4146-ae51-3224d3599d4d', 'Villa are in form after three consecutive wins. ', ''),
    -- nottm_forest brief: City lost to Brighton on Saturday
    ('84adb3b0-fb09-4fc9-bd6f-60641ebdc3e9', 'City lost at Aston Villa last weekend, but they', 'City lost at home to Brighton on Saturday, but they'),
    ('84adb3b0-fb09-4fc9-bd6f-60641ebdc3e9', 'City lost at Villa last weekend but do not let that fool you.', 'City lost to Brighton on Saturday but do not let that fool you.'),
    -- sunderland brief: lost 3-1 at Coventry on Saturday
    ('38a3edfd-2813-44d1-a91f-1afccce3bbe2', 'Sunderland drew 0-0 with Leeds on Sunday and sit bottom', 'Sunderland lost 3-1 at Coventry on Saturday and sit bottom'),
    -- arsenal matchday 2026-11-01: the post-match table
    ('d993312c-59f6-4d4c-a712-5a712eba0216', 'and they go level on points with Manchester City', 'and they go three points clear of Manchester City'),
    ('d993312c-59f6-4d4c-a712-5a712eba0216', 'It lifts Arsenal to 21 points from 8 games, level with leaders Manchester City and second on the table.',
      'It lifts Arsenal to 24 points from 9 games, three clear of Manchester City at the top of the table.'),
    ('d993312c-59f6-4d4c-a712-5a712eba0216', 'Arsenal are second on 21 points from 8 games, level with leaders Manchester City.',
      'Arsenal are top on 24 points from 9 games, three clear of Manchester City.'),
    ('d993312c-59f6-4d4c-a712-5a712eba0216', 'It leaves them second in the Premier League on 21 points, level with Manchester City.',
      'It leaves them top of the Premier League on 24 points, three clear of Manchester City.')
  ) v(id, old, new) LOOP
    UPDATE public.content_items SET
      headline = replace(headline, r.old, r.new),
      body = replace(body, r.old, r.new),
      push_title = replace(push_title, r.old, r.new),
      push_text = replace(push_text, r.old, r.new),
      immersive_headline = replace(immersive_headline, r.old, r.new),
      immersive_context = replace(immersive_context, r.old, r.new),
      immersive_context_fallback = replace(immersive_context_fallback, r.old, r.new),
      talking_points = replace(talking_points::text, r.old, r.new)::jsonb,
      info_cards = replace(info_cards::text, r.old, r.new)::jsonb
     WHERE id = r.id::uuid
       AND strpos(concat_ws('|', headline, body, push_title, push_text, immersive_headline, immersive_context,
                            immersive_context_fallback, talking_points::text, info_cards::text), r.old) > 0;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN RAISE NOTICE 'content_items no match: % %', r.id, left(r.old, 40); END IF;
  END LOOP;
END $$;

COMMIT;
