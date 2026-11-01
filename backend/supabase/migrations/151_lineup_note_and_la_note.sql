-- 151: two small columns for match-watcher (app council 2026-11-01).
--
-- fixture_lineups.note: the line the lineup check would say about our side
--   (LOCK-02-14). With the LINEUP_PUSH_ENABLED secret set it replaces the T−30
--   kickoff body; until then it is read by nobody but Anton.
-- match_status_state.la_note: the Live Activity's shootout line ("Arsenal win
--   4-2 on penalties"), so la-end-sweep can end an activity the full-time tick
--   missed with the same words (LOCK-03-16).
-- Apply BEFORE deploying the match-watcher that reads them.
ALTER TABLE public.fixture_lineups ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE public.match_status_state ADD COLUMN IF NOT EXISTS la_note text;
