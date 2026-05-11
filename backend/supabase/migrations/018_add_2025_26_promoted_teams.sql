-- 018_add_2025_26_promoted_teams.sql
-- Add the three 2025-26 Premier League promoted teams.
--
-- Context: the `teams` table was seeded in 004 with the 2024-25 PL squad
-- and never updated when the season rolled over. As a result, every
-- fixture in the 2025-26 season involving Leeds (api_football_id=63),
-- Sunderland (746), or Burnley (44) was silently skipped by the match-
-- watcher edge function — its `if (!homeTeamId || !awayTeamId) continue`
-- guard short-circuited at the teamIdMap lookup.
--
-- We do NOT remove Ipswich, Leicester, Southampton (the three relegated
-- teams) — historical content_items reference them via FK, and keeping
-- their rows costs nothing.
--
-- Manual maintenance reminder: bump this list each August when the new
-- PL season's promoted teams are confirmed. The next time will be the
-- 2026-27 season transition.

INSERT INTO teams (id, display_name, short_name, api_football_id) VALUES
    ('leeds',      'Leeds United', 'Leeds',      63),
    ('sunderland', 'Sunderland',   'Sunderland', 746),
    ('burnley',    'Burnley',      'Burnley',    44)
ON CONFLICT (id) DO NOTHING;
