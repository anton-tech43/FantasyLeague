-- 031_team_season_state_next_fixtures.sql
-- V1.2 Onboarding redesign — Calendar opt-in step.
--
-- The new CalendarOptInView (step 9 of the V1.2 onboarding flow) syncs the
-- next ~10 fixtures into the user's iOS calendar in one tap. The existing
-- `next_fixture` column (added in migration 021) stores only the very next
-- match — not enough for a meaningful calendar slate.
--
-- This migration adds a sibling `next_fixtures` JSONB column carrying an
-- array of 5-10 upcoming fixtures (same shape as the singular). The
-- team-season-state-generator Edge Function populates both columns from the
-- same raw_fetch_logs entry; old iOS clients keep reading `next_fixture`
-- while the V1.2 client reads `next_fixtures`. One release cycle of overlap
-- is enough to avoid a hard cutover.
--
-- Shape of `next_fixtures`:
--   [
--     { "opponent": "Tottenham", "kickoff_time": "2026-05-17T14:00:00Z", "venue": "Home" },
--     { "opponent": "Liverpool", "kickoff_time": "2026-05-24T16:30:00Z", "venue": "Away" },
--     ...
--   ]
-- The columns share types so the iOS Codable struct (`TeamSeasonState.NextFixture`)
-- decodes both without branching.

ALTER TABLE team_season_state
    ADD COLUMN IF NOT EXISTS next_fixtures JSONB;

-- No CHECK constraint — the generator validates shape before upsert and the
-- iOS client decodes defensively (missing/empty arrays fall back to the
-- singular field via the `fixturesForSync` accessor).
