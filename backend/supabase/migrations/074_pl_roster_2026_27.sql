-- 074_pl_roster_2026_27.sql
-- CONTENT-6: reconcile the PL club roster to the real 2026-27 season.
--
-- Source of truth (verified 2026-06-17, Premier League AGM / Wikipedia):
--   Promoted from the Championship: Coventry City, Ipswich Town, Hull City.
--   Relegated from the 2025-26 PL:  West Ham United, Burnley, Wolves.
--   Ipswich is already in our table (left over from 2024-25) and is promoted
--   back, so it just stays active.
--
-- The table had no relegation mechanism — clubs just lingered at league_id=39
-- (leicester/southampton were stale from 2024-25). Adds an `is_active` flag so
-- "active PL" = (league_id=39 AND is_active); relegation = is_active=false. We
-- DEACTIVATE rather than DELETE the outgoing clubs: they have 0 followers but
-- ~114 content_items / 147 insider rows / team_pages referencing them (14 FK
-- tables), and that history should be preserved, not cascade-deleted.

ALTER TABLE teams ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Relegated for 2026-27 + the two stale 2024-25 leftovers → inactive.
UPDATE teams SET is_active = false
  WHERE id IN ('west_ham', 'burnley', 'wolves', 'leicester', 'southampton');

-- Promoted in (Ipswich already present + active). api_football_id verified via
-- the API-Football /teams lookup. strength_rank stays null (only WC countries
-- use it). entity_type/league_id match the other PL clubs.
INSERT INTO teams (id, api_football_id, display_name, short_name, entity_type, league_id, is_active)
VALUES
  ('coventry', 1346, 'Coventry City', 'Coventry', 'club', 39, true),
  ('hull',       64, 'Hull City',     'Hull',     'club', 39, true)
ON CONFLICT (id) DO UPDATE SET
  api_football_id = EXCLUDED.api_football_id,
  display_name    = EXCLUDED.display_name,
  short_name      = EXCLUDED.short_name,
  entity_type     = EXCLUDED.entity_type,
  league_id       = EXCLUDED.league_id,
  is_active       = true;

-- Active PL clubs after this migration (20): arsenal, aston_villa, bournemouth,
-- brentford, brighton, chelsea, coventry, crystal_palace, everton, fulham, hull,
-- ipswich, leeds, liverpool, man_city, man_utd, newcastle, nottm_forest,
-- sunderland, spurs. (48 WC countries unaffected.)
--
-- FOLLOW-UP (not in this migration): backfill team_pages / season_state /
-- insider for coventry + hull via the gd-* claude.ai routines closer to the
-- 2026-27 kickoff (Aug 2026) — NOT a paid Edge loop — and flip data-fetcher's
-- PL season from 2025 to 2026 then.
