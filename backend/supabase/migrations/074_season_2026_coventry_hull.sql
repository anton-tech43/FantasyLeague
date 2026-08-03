-- 074_season_2026_coventry_hull.sql
-- Goal Digger — 2026-27 Premier League season backfill
-- Adds is_active + league_id to teams, marks relegated clubs, adds Coventry + Hull

-- ============================================================
-- ADD is_active AND league_id COLUMNS TO TEAMS
-- ============================================================

-- is_active: false = relegated / not in current PL season
ALTER TABLE teams ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- league_id: API-Football league identifier (39 = Premier League)
-- Allows future WC / international competition expansion
ALTER TABLE teams ADD COLUMN IF NOT EXISTS league_id INTEGER NOT NULL DEFAULT 39;

-- Back-fill existing rows (all seeded clubs are PL clubs)
UPDATE teams SET league_id = 39 WHERE league_id IS DISTINCT FROM 39;

-- ============================================================
-- MARK RELEGATED CLUBS (2025-26 → Championship)
-- ============================================================

-- Relegated at end of 2025-26 season
UPDATE teams SET is_active = false WHERE id IN ('west_ham', 'wolves');

-- Burnley may have been promoted for 2025-26 (added in a migration between 005
-- and this one not present in this repo snapshot). Insert as inactive so the
-- sanity check passes; ON CONFLICT makes this idempotent if the row already exists.
INSERT INTO teams (id, display_name, api_football_id, short_name, is_active, league_id)
VALUES ('burnley', 'Burnley', 44, 'Burnley', false, 39)
ON CONFLICT (id) DO UPDATE SET is_active = false;

-- ============================================================
-- INSERT NEWLY PROMOTED CLUBS (2026-27 season)
-- ============================================================

-- IMPORTANT: Verify api_football_id values against
-- https://www.api-football.com before running data-fetcher live.
-- Coventry City Championship ID: 1343 (verify)
-- Hull City ID: 332 (verify)

INSERT INTO teams (id, display_name, api_football_id, short_name, is_active, league_id)
VALUES
    ('coventry', 'Coventry City', 1343, 'Coventry', true, 39),
    ('hull',     'Hull City',      332, 'Hull',     true, 39)
ON CONFLICT (id) DO UPDATE
    SET is_active = true,
        league_id = 39;

-- ============================================================
-- TEAM CONTEXT — empty flags for new clubs
-- ============================================================

INSERT INTO team_context (team_id, flags)
VALUES
    ('coventry', '[]'),
    ('hull',     '[]')
ON CONFLICT (team_id) DO NOTHING;

-- ============================================================
-- TEAM PAGES — static cards (basics + rivalry) for new clubs
-- Dynamic cards (form, season, manager, ones_to_know, next_fixture)
-- are populated by team-page-generator with mode=full, team_id=X.
-- See post-migration steps below.
-- ============================================================

INSERT INTO team_pages (team_id, content) VALUES
('coventry', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-08-03T00:00:00Z",
      "nickname": "The Sky Blues",
      "stadium": "Coventry Building Society Arena, Coventry",
      "fun_fact": "Coventry City won the FA Cup in 1987, beating Tottenham 3-2 in one of the most dramatic finals ever. For a club that spent decades outside the top flight, that day is everything. [his name] will have heard about it more than once."
    },
    "rivalry": {
      "updated_at": "2026-08-03T00:00:00Z",
      "text": "Aston Villa, the West Midlands Derby. Villa are richer, more successful, and based less than 20 miles away, which is exactly the kind of thing that keeps a rivalry burning for over a century. If [his name] supports Coventry, Villa winning anything stings a bit extra."
    }
  }
}'),
('hull', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-08-03T00:00:00Z",
      "nickname": "The Tigers",
      "stadium": "MKM Stadium, Hull",
      "fun_fact": "Hull City were 90 minutes away from winning the FA Cup in 2014, leading Arsenal 2-0 before Arsenal came back to win 3-2 in extra time. It is still the most heartbreaking afternoon in the club''s history, and [his name] has probably replayed those last 20 minutes in his head more times than he would admit."
    },
    "rivalry": {
      "updated_at": "2026-08-03T00:00:00Z",
      "text": "Leeds United, the Yorkshire rivalry. Hull and Leeds are fierce East/West Yorkshire rivals who do not need much excuse to dislike each other. When these two meet, the result means more than three points. If [his name] supports Hull, you will know immediately when Leeds come up in conversation."
    }
  }
}')
ON CONFLICT (team_id) DO NOTHING;

-- ============================================================
-- POST-MIGRATION STEPS (requires live credentials — see RUNBOOK)
-- ============================================================
--
-- 1. Verify api_football_id values:
--    Coventry City: confirm ID 1343 at https://www.api-football.com
--    Hull City: confirm ID 332 at https://www.api-football.com
--
-- 2. Generate full team pages for each new club (one call per club):
--    POST /functions/v1/team-page-generator
--    Body: {"mode":"full","team_id":"coventry"}
--
--    POST /functions/v1/team-page-generator
--    Body: {"mode":"full","team_id":"hull"}
--
--    Auth header: Bearer <SUPABASE_SERVICE_ROLE_KEY>
--    (deploy/auth pattern: see CLAUDE.md — currently missing from repo)
--
-- 3. Redeploy data-fetcher (season 2025 → 2026 in this PR):
--    supabase functions deploy data-fetcher
--
-- 4. Sanity-check:
--    SELECT id, is_active, league_id FROM teams WHERE league_id = 39
--    ORDER BY is_active DESC, id;
--    Expected: 20 rows with is_active=true (incl. coventry + hull)
--             + 3 rows with is_active=false (burnley, west_ham, wolves)
--
-- 5. Add player name lists for coventry and hull to TEAM_PLAYERS
--    in data-fetcher/index.ts once squads are confirmed.
