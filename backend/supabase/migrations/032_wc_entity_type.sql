-- 032_wc_entity_type.sql
-- V2.0 World Cup 2026 support.
--
-- Makes the `teams` table polymorphic: it can now hold both Premier League
-- clubs (entity_type='club') and World Cup national teams (entity_type='country').
-- All downstream tables (content_items, device_tokens, raw_fetch_logs,
-- match_status_state, team_pages, team_season_state, etc.) reference team_id
-- as TEXT and don't care whether the entity is a club or a country.
--
-- Why this approach instead of a parallel `countries` table:
--   - One set of code paths in Edge Functions (data-fetcher, team-page-
--     generator, notification-sender) handles both.
--   - Cross-content works naturally: a content_item about "Saka scoring for
--     England" can have team_id='england' AND a future "appears_in" tag for
--     'arsenal', so the same row surfaces in both feeds.
--   - When WC ends, countries stay in the table (dormant) — easy to revive
--     for World Cup 2030 without re-seeding.
--
-- The `league_id` column makes the entity's competition explicit:
--   - 39 = Premier League (matches API-Football's league_id)
--   -  1 = FIFA World Cup (matches API-Football's league_id; latest_season=2026)
--
-- Functions that previously hardcoded `league=39&season=2025` will read these
-- columns instead so they can iterate over both leagues in one pass.

-- ---------------------------------------------------------------------------
-- 1. Schema additions
-- ---------------------------------------------------------------------------

ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS entity_type TEXT NOT NULL DEFAULT 'club'
    CHECK (entity_type IN ('club', 'country')),
  ADD COLUMN IF NOT EXISTS league_id INTEGER;

-- Backfill: all existing rows are PL clubs.
UPDATE teams
SET league_id = 39
WHERE entity_type = 'club' AND league_id IS NULL;

-- ---------------------------------------------------------------------------
-- 2. Seed 48 WC 2026 countries
-- ---------------------------------------------------------------------------
-- api_football_id values verified against /teams?league=1&season=2026 on
-- 2026-05-16. The qualifier list will be finalised after the March 2026
-- intercontinental play-offs; if any team here is replaced, the relevant
-- row should be UPDATEd (don't delete — content_items may already reference
-- the team_id and we want history preserved).

INSERT INTO teams (id, display_name, short_name, api_football_id, entity_type, league_id) VALUES
  ('belgium',              'Belgium',                'Belgium',     1,    'country', 1),
  ('france',               'France',                 'France',      2,    'country', 1),
  ('croatia',              'Croatia',                'Croatia',     3,    'country', 1),
  ('sweden',               'Sweden',                 'Sweden',      5,    'country', 1),
  ('brazil',               'Brazil',                 'Brazil',      6,    'country', 1),
  ('uruguay',              'Uruguay',                'Uruguay',     7,    'country', 1),
  ('colombia',             'Colombia',               'Colombia',    8,    'country', 1),
  ('spain',                'Spain',                  'Spain',       9,    'country', 1),
  ('england',              'England',                'England',     10,   'country', 1),
  ('panama',               'Panama',                 'Panama',      11,   'country', 1),
  ('japan',                'Japan',                  'Japan',       12,   'country', 1),
  ('senegal',              'Senegal',                'Senegal',     13,   'country', 1),
  ('switzerland',          'Switzerland',            'Swiss',       15,   'country', 1),
  ('mexico',               'Mexico',                 'Mexico',      16,   'country', 1),
  ('south_korea',          'South Korea',            'Korea',       17,   'country', 1),
  ('australia',            'Australia',              'Australia',   20,   'country', 1),
  ('iran',                 'Iran',                   'Iran',        22,   'country', 1),
  ('saudi_arabia',         'Saudi Arabia',           'Saudi',       23,   'country', 1),
  ('germany',              'Germany',                'Germany',     25,   'country', 1),
  ('argentina',            'Argentina',              'Argentina',   26,   'country', 1),
  ('portugal',             'Portugal',               'Portugal',    27,   'country', 1),
  ('tunisia',              'Tunisia',                'Tunisia',     28,   'country', 1),
  ('morocco',              'Morocco',                'Morocco',     31,   'country', 1),
  ('egypt',                'Egypt',                  'Egypt',       32,   'country', 1),
  ('czech_republic',       'Czech Republic',         'Czechia',     770,  'country', 1),
  ('austria',              'Austria',                'Austria',     775,  'country', 1),
  ('turkiye',              'Türkiye',                'Türkiye',     777,  'country', 1),
  ('norway',               'Norway',                 'Norway',      1090, 'country', 1),
  ('scotland',             'Scotland',               'Scotland',    1108, 'country', 1),
  ('bosnia_herzegovina',   'Bosnia & Herzegovina',   'Bosnia',      1113, 'country', 1),
  ('netherlands',          'Netherlands',            'Netherlands', 1118, 'country', 1),
  ('ivory_coast',          'Ivory Coast',            'Ivory Coast', 1501, 'country', 1),
  ('ghana',                'Ghana',                  'Ghana',       1504, 'country', 1),
  ('congo_dr',             'Congo DR',               'DR Congo',    1508, 'country', 1),
  ('south_africa',         'South Africa',           'S. Africa',   1531, 'country', 1),
  ('algeria',              'Algeria',                'Algeria',     1532, 'country', 1),
  ('cape_verde',           'Cape Verde Islands',     'Cape Verde',  1533, 'country', 1),
  ('jordan',               'Jordan',                 'Jordan',      1548, 'country', 1),
  ('iraq',                 'Iraq',                   'Iraq',        1567, 'country', 1),
  ('uzbekistan',           'Uzbekistan',             'Uzbekistan',  1568, 'country', 1),
  ('qatar',                'Qatar',                  'Qatar',       1569, 'country', 1),
  ('paraguay',             'Paraguay',               'Paraguay',    2380, 'country', 1),
  ('ecuador',              'Ecuador',                'Ecuador',     2382, 'country', 1),
  ('usa',                  'USA',                    'USA',         2384, 'country', 1),
  ('haiti',                'Haiti',                  'Haiti',       2386, 'country', 1),
  ('new_zealand',          'New Zealand',            'NZ',          4673, 'country', 1),
  ('canada',               'Canada',                 'Canada',      5529, 'country', 1),
  ('curacao',              'Curaçao',                'Curaçao',     5530, 'country', 1)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Sanity check (commented — paste into SQL Editor to verify post-apply)
-- ---------------------------------------------------------------------------
-- SELECT entity_type, league_id, COUNT(*) FROM teams GROUP BY 1, 2 ORDER BY 1, 2;
-- Expected:
--   club    | 39 | 23   (20 current PL + 3 relegated, all unchanged)
--   country | 1  | 48
