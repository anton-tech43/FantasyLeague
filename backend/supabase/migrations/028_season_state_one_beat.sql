-- 028_season_state_one_beat.sql
-- A1 Season Primer redesign: one beat, one feeling, one CTA.
--
-- The original primer (migration 021) generated 2-sentence summaries +
-- key facts + 3 quotables. Smoke testing showed the surface is overwhelming
-- for brand-new users — too many content blocks, news-style voice, jargon
-- without context. The redesign collapses to two strings:
--
--   state_line   : 2-5 words, the punchy personalised headline
--                  ("Arsenal are flying", "Spurs are sliding")
--   feeling_line : 1-2 sentences (≤220 chars), sister-voice emotional
--                  translation focused on how HE will feel/act this week,
--                  not on stats.
--
-- Existing columns (summary, key_fact, welcome_lines) are kept but loosened
-- to NULL-able so the new routine can UPSERT without populating them. Old
-- rows keep their data, new ones land sparse.

ALTER TABLE team_season_state
    ADD COLUMN IF NOT EXISTS state_line   TEXT,
    ADD COLUMN IF NOT EXISTS feeling_line TEXT;

-- Loosen NOT NULL on the legacy fields so the routine can stop populating
-- them. The data already present in those columns stays put.
ALTER TABLE team_season_state ALTER COLUMN summary       DROP NOT NULL;
ALTER TABLE team_season_state ALTER COLUMN key_fact      DROP NOT NULL;
ALTER TABLE team_season_state ALTER COLUMN welcome_lines DROP NOT NULL;
