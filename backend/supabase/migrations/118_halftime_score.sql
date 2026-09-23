-- 118_halftime_score.sql — keep the half-time score we were already being sent.
--
-- API-Football returns `score.halftime` on every /fixtures row match-watcher
-- polls each minute. The `ApiFixture` interface narrowed it away, declaring
-- only `score.extratime` and `score.penalty`, so the number arrived once a
-- minute for the whole match and was thrown out every time.
--
-- "Called it" needs it: the `comeback` trigger is "behind at the break, won by
-- the whistle", and until now that had to be COUNTED off goal_events by minute,
-- which is right whenever the events list is complete and silently 0-0 when it
-- is not. Reading the feed's own number costs zero extra calls.
--
-- Nullable with no default and no backfill on purpose. A row written before
-- this migration has no half-time score and must not be given a fabricated
-- 0-0, so match-watcher falls back to counting goal_events for those, which is
-- what it did for all of them yesterday.

ALTER TABLE match_status_state
  ADD COLUMN IF NOT EXISTS ht_home smallint,
  ADD COLUMN IF NOT EXISTS ht_away smallint;

COMMENT ON COLUMN match_status_state.ht_home IS
  'Half-time score from API-Football score.halftime, stamped every tick from 1H onward. '
  'NULL means not known (pre-kickoff, or a row that predates migration 118), never 0-0.';
COMMENT ON COLUMN match_status_state.ht_away IS
  'See ht_home.';
