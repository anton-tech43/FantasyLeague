-- 067_team_strength_rank.sql
-- Seed a per-team strength signal so the app can show pre-game "favorite" tags
-- and post-result "upset / as predicted" framing.
--
-- teams.strength_rank is NULLABLE and its meaning depends on entity_type:
--   * entity_type='country' (World Championship participants): holds the team's
--     FIFA men's world ranking POSITION as an integer. LOWER = STRONGER
--     (rank 1 is the best team in the world). Seeded below.
--   * entity_type='club' (e.g. Premier League): stays NULL. Club strength is
--     derived at runtime from the team's current league standings position, so
--     there is nothing to seed here.
--
-- Source of the country ranks: the official FIFA/Coca-Cola Men's World Ranking
-- released on 11 June 2026 (the most recent published edition as of the
-- 2026-06-16 migration date). Top-50 positions taken from ESPN's reproduction
-- of that ranking; positions 51-85 cross-checked against whereig.com and
-- per-country reporting. See 067_team_strength_rank_NOTES.md for the full
-- country->rank table, the exact source URLs, and mapping notes.
--
-- These ranks are a snapshot; FIFA republishes roughly monthly. Re-seed via a
-- follow-up migration when the app needs fresher numbers — do NOT loop an LLM
-- backfill for this (see /BACKFILL_RULES.md).

ALTER TABLE teams ADD COLUMN IF NOT EXISTS strength_rank INTEGER;

-- FIFA Men's World Ranking, 11 June 2026 — WC participant countries.
-- One UPDATE per WC country slug (keys of WC_COUNTRY_META in
-- _shared/wc-countries.ts). All 48 participants are mapped.

UPDATE teams SET strength_rank = 28 WHERE id = 'algeria';
UPDATE teams SET strength_rank = 1  WHERE id = 'argentina';
UPDATE teams SET strength_rank = 27 WHERE id = 'australia';
UPDATE teams SET strength_rank = 24 WHERE id = 'austria';
UPDATE teams SET strength_rank = 9  WHERE id = 'belgium';
UPDATE teams SET strength_rank = 64 WHERE id = 'bosnia_herzegovina';
UPDATE teams SET strength_rank = 6  WHERE id = 'brazil';
UPDATE teams SET strength_rank = 30 WHERE id = 'canada';
UPDATE teams SET strength_rank = 67 WHERE id = 'cape_verde';
UPDATE teams SET strength_rank = 13 WHERE id = 'colombia';
UPDATE teams SET strength_rank = 46 WHERE id = 'congo_dr';
UPDATE teams SET strength_rank = 11 WHERE id = 'croatia';
UPDATE teams SET strength_rank = 82 WHERE id = 'curacao';
UPDATE teams SET strength_rank = 40 WHERE id = 'czech_republic';
UPDATE teams SET strength_rank = 23 WHERE id = 'ecuador';
UPDATE teams SET strength_rank = 29 WHERE id = 'egypt';
UPDATE teams SET strength_rank = 4  WHERE id = 'england';
UPDATE teams SET strength_rank = 3  WHERE id = 'france';
UPDATE teams SET strength_rank = 10 WHERE id = 'germany';
UPDATE teams SET strength_rank = 73 WHERE id = 'ghana';
UPDATE teams SET strength_rank = 83 WHERE id = 'haiti';
UPDATE teams SET strength_rank = 20 WHERE id = 'iran';
UPDATE teams SET strength_rank = 57 WHERE id = 'iraq';
UPDATE teams SET strength_rank = 33 WHERE id = 'ivory_coast';
UPDATE teams SET strength_rank = 18 WHERE id = 'japan';
UPDATE teams SET strength_rank = 63 WHERE id = 'jordan';
UPDATE teams SET strength_rank = 14 WHERE id = 'mexico';
UPDATE teams SET strength_rank = 7  WHERE id = 'morocco';
UPDATE teams SET strength_rank = 8  WHERE id = 'netherlands';
UPDATE teams SET strength_rank = 85 WHERE id = 'new_zealand';
UPDATE teams SET strength_rank = 31 WHERE id = 'norway';
UPDATE teams SET strength_rank = 34 WHERE id = 'panama';
UPDATE teams SET strength_rank = 41 WHERE id = 'paraguay';
UPDATE teams SET strength_rank = 5  WHERE id = 'portugal';
UPDATE teams SET strength_rank = 56 WHERE id = 'qatar';
UPDATE teams SET strength_rank = 61 WHERE id = 'saudi_arabia';
UPDATE teams SET strength_rank = 42 WHERE id = 'scotland';
UPDATE teams SET strength_rank = 15 WHERE id = 'senegal';
UPDATE teams SET strength_rank = 60 WHERE id = 'south_africa';
UPDATE teams SET strength_rank = 25 WHERE id = 'south_korea';
UPDATE teams SET strength_rank = 2  WHERE id = 'spain';
UPDATE teams SET strength_rank = 38 WHERE id = 'sweden';
UPDATE teams SET strength_rank = 19 WHERE id = 'switzerland';
UPDATE teams SET strength_rank = 45 WHERE id = 'tunisia';
UPDATE teams SET strength_rank = 22 WHERE id = 'turkiye';
UPDATE teams SET strength_rank = 16 WHERE id = 'uruguay';
UPDATE teams SET strength_rank = 17 WHERE id = 'usa';
UPDATE teams SET strength_rank = 50 WHERE id = 'uzbekistan';
