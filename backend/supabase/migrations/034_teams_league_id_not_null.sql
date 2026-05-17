-- 034_teams_league_id_not_null.sql
-- V2.0 hardening.
--
-- After migration 032 backfilled league_id=39 for all PL clubs and seeded
-- 48 countries with league_id=1, every row in `teams` has a non-null
-- league_id. match-watcher and data-fetcher were updated to fail-loud-and-
-- skip when they encounter a null league_id (per V2.0 fix M2/M1) — that
-- application-layer guard catches future regressions but doesn't stop them
-- from being inserted. This migration makes the constraint DB-enforced.
--
-- Pre-apply verification:
--   SELECT COUNT(*) FROM teams WHERE league_id IS NULL;   -- expect 0
-- Confirmed zero rows on 2026-05-17 before applying.

ALTER TABLE teams
  ALTER COLUMN league_id SET NOT NULL;

-- Sanity check (commented — paste into psql to verify):
-- \d teams
-- Expected: `league_id | integer | not null` line.
