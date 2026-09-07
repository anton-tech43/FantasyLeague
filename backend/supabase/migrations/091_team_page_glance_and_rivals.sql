-- 091: the three facts that place a club at a glance, and a rival name for
-- the rivalry card headline. Anton, 2026-09-07: "The info for each club should
-- give somewhat a glance of how long they have been in the premier league,
-- their placement last year and when they last won the league."
--
-- Hand-maintained content in team_pages.cards.basics (pl_since, last_season,
-- last_title) and cards.rivalry.rival. team-page-generator preserves basics
-- and rivalry verbatim, so these survive every refresh. Sources: 2025-26
-- final tables from API-Football (league 39 and 40, season 2025), title
-- history is settled record. Re-run this file after each season with the new
-- placings; the stale-data-audit skill lists it.
--
-- Also fixes two rivalry texts that had gone stale or were missing:
-- Nottingham Forest's said Leicester were "the current Premier League rival"
-- (relegated 2025); Leeds and Sunderland had no rivalry card at all.

WITH glance(team_id, pl_since, last_season, last_title, rival) AS (VALUES
  ('arsenal',        'Top flight every season since 1919',                       'Champions, 85 points',                    '2025-26, last season',          'Tottenham Hotspur'),
  ('aston_villa',    'In the Premier League since 2019',                         '4th, 65 points',                          '1980-81',                       'Birmingham City'),
  ('bournemouth',    'In the Premier League since 2022',                         '6th, 57 points',                          'Never',                         'Southampton'),
  ('brentford',      'In the Premier League since 2021',                         '9th, 53 points',                          'Never',                         'Fulham'),
  ('brighton',       'In the Premier League since 2017',                         '8th, 53 points',                          'Never',                         'Crystal Palace'),
  ('chelsea',        'Top flight every season since 1989',                       '10th, 52 points',                         '2016-17',                       'Tottenham Hotspur'),
  ('coventry',       'First top-flight season since 2000-01',                    'Championship winners, 95 points',         'Never',                         'Birmingham City'),
  ('crystal_palace', 'In the Premier League since 2013',                         '15th, 45 points',                         'Never',                         'Brighton'),
  ('everton',        'Top flight every season since 1954',                       '13th, 49 points',                         '1986-87',                       'Liverpool'),
  ('fulham',         'In the Premier League since 2022',                         '11th, 52 points',                         'Never',                         'Chelsea'),
  ('hull',           'Back in the top flight for the first time since 2016-17',  'Promoted through the play-offs, 6th',    'Never',                         'Leeds United'),
  ('ipswich',        'Back after one season in the Championship',                'Championship runners-up, 84 points',      '1961-62',                       'Norwich City'),
  ('leeds',          'In the Premier League since 2025',                         '14th, 47 points',                         '1991-92',                       'Manchester United'),
  ('liverpool',      'Top flight every season since 1962',                       '5th, 60 points',                          '2024-25',                       'Manchester United'),
  ('man_city',       'In the Premier League since 2002',                         '2nd, 78 points',                          '2023-24',                       'Manchester United'),
  ('man_utd',        'Top flight every season since 1975',                       '3rd, 71 points',                          '2012-13',                       'Liverpool'),
  ('newcastle',      'In the Premier League since 2017',                         '12th, 49 points',                         '1926-27',                       'Sunderland'),
  ('nottm_forest',   'In the Premier League since 2022',                         '16th, 44 points',                         '1977-78',                       'Derby County'),
  ('spurs',          'Top flight every season since 1978',                       '17th, 41 points',                         '1960-61',                       'Arsenal'),
  ('sunderland',     'In the Premier League since 2025',                         '7th, 54 points',                          '1935-36',                       'Newcastle United')
)
UPDATE team_pages tp
SET content = jsonb_set(
      jsonb_set(tp.content, '{cards,basics}',
        COALESCE(tp.content->'cards'->'basics', '{}'::jsonb)
          || jsonb_build_object('pl_since', g.pl_since, 'last_season', g.last_season, 'last_title', g.last_title,
                                'glance_updated_at', '2026-09-07T00:00:00Z')),
      '{cards,rivalry}',
      -- jsonb 'null' is not SQL NULL: COALESCE keeps it and '||' then builds an
      -- array. Leeds and Sunderland had a JSON null here (the first run of this
      -- file produced [null, {...}] for both — CLAUDE.md's JSONB null trap).
      (CASE WHEN jsonb_typeof(tp.content->'cards'->'rivalry') = 'object'
            THEN tp.content->'cards'->'rivalry' ELSE '{}'::jsonb END)
        || jsonb_build_object('rival', g.rival)),
    updated_at = now()
FROM glance g
WHERE tp.team_id = g.team_id;

-- Rivalry texts: two missing, one stale.
UPDATE team_pages SET content = jsonb_set(content, '{cards,rivalry}',
  (CASE WHEN jsonb_typeof(content->'cards'->'rivalry') = 'object' THEN content->'cards'->'rivalry' ELSE '{}'::jsonb END) || jsonb_build_object(
    'text', 'Manchester United — the Roses rivalry, Yorkshire against Lancashire, going back to the 1960s and 70s when both were at the top. Leeds fans dislike United more than anyone, and a win over them counts double for [his name].',
    'updated_at', '2026-09-07T00:00:00Z'))
WHERE team_id = 'leeds';

UPDATE team_pages SET content = jsonb_set(content, '{cards,rivalry}',
  (CASE WHEN jsonb_typeof(content->'cards'->'rivalry') = 'object' THEN content->'cards'->'rivalry' ELSE '{}'::jsonb END) || jsonb_build_object(
    'text', 'Newcastle United — the Tyne-Wear derby. Twelve miles apart and no love lost, for well over a century. Both are in the Premier League this season, so [his name] gets the fixture back. Do not mention Newcastle on derby weekend unless it is good news.',
    'updated_at', '2026-09-07T00:00:00Z'))
WHERE team_id = 'sunderland';

UPDATE team_pages SET content = jsonb_set(content, '{cards,rivalry}',
  (content->'cards'->'rivalry') || jsonb_build_object(
    'text', 'Derby County — the East Midlands derby and the deep one, Brian Clough having managed both. Leicester City are the other neighbours Forest love beating. Neither is in the Premier League right now, which [his name] will happily point out.',
    'updated_at', '2026-09-07T00:00:00Z'))
WHERE team_id = 'nottm_forest';
