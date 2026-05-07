-- 007_match_status_state.sql
-- State table for the match-watcher edge function.
--
-- match-watcher polls API-Football every 5 minutes for PL fixture
-- status. To detect transitions (e.g. LIVE → FT) without re-firing
-- the gd-matchday routine on every tick, we keep last-seen state here.
--
-- fired_finished_at is set the moment we POST to the routine's /fire
-- endpoint for that match's final whistle. Subsequent ticks see
-- fired_finished_at IS NOT NULL and skip the fire.

CREATE TABLE match_status_state (
    fixture_id        INTEGER PRIMARY KEY,
    league_id         INTEGER NOT NULL,
    home_team_id      TEXT NOT NULL REFERENCES teams(id),
    away_team_id      TEXT NOT NULL REFERENCES teams(id),
    status            TEXT NOT NULL,
    home_goals        INTEGER,
    away_goals        INTEGER,
    kickoff_time      TIMESTAMPTZ NOT NULL,
    last_checked      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fired_finished_at TIMESTAMPTZ
);

CREATE INDEX idx_match_status_active ON match_status_state(status)
    WHERE status IN ('1H', 'HT', '2H', 'LIVE');
