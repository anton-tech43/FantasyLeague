-- 137_fixture_lineups.sql
-- Each lineup match-watcher fetches between T−75 and T−30 for a fixture one
-- of our clubs plays. The history is what makes "a regular is out" and
-- "heavy rotation" real: the previous league XI and each player's last role
-- (full-back or centre-back) come from here, not from API-Football's
-- four-way position. Small: two rows per fixture, ~40 fixtures a week.
-- Server-only. The app never reads it.
CREATE TABLE IF NOT EXISTS public.fixture_lineups (
  fixture_id   integer     NOT NULL,
  team_api_id  integer     NOT NULL,
  league_id    integer,
  formation    text,
  xi           jsonb       NOT NULL,   -- [{id, name, pos, grid}]
  bench        jsonb,
  fetched_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (fixture_id, team_api_id)
);
CREATE INDEX IF NOT EXISTS fixture_lineups_team_recent
  ON public.fixture_lineups (team_api_id, fetched_at DESC);

ALTER TABLE public.fixture_lineups ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fixture_lineups FROM PUBLIC, anon, authenticated;
