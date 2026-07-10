-- 077_players_photo_lookup.sql
-- Adds a `players` lookup table (api_player_id -> photo_url/name/position) so
-- the app can render player headshots without re-fetching API-Football on
-- every read. Backfilled in this same migration from data ALREADY sitting in
-- raw_fetch_logs — $0 cost, per /BACKFILL_RULES.md (SQL beats looping an
-- Edge Function / Claude call over every team). One-time backfill: WC squads
-- are locked and the tournament ends 2026-07-19, so there's a short window
-- where this data is both needed and stable enough to snapshot once.
--
-- Verified JSONB shape (see notes at the bottom of this section):
-- raw_fetch_logs.data for source='api_football_squad' holds the FULL
-- API-Football envelope (confirmed against data-fetcher/index.ts, which does
-- `results.push({ source: 'api_football_squad', data })` where `data =
-- await response.json()` — the raw fetch response body, not just its
-- `.response` field; team-page-generator/index.ts's `isResponseEmpty()`
-- helper reads `(data as { response?: unknown[] }).response`, confirming
-- `.response` is a top-level key of the stored `data`, not the whole value).
-- For /players/squads?team=<id>, that shape is:
--   { response: [ { team: {...}, players: [ {id, name, age, number,
--                                             position, photo}, ... ] } ] }
-- i.e. ONE element in `response` (the requested team), so the path to the
-- player array is data->'response'->0->'players'.

-- ---------------------------------------------------------------------------
-- 1. Table + index + RLS (service-role-only — copies the single-policy
--    pattern from 064_apns_jwt_cache.sql; this table has no anon read/write
--    path, unlike 062_live_activity_tokens.sql's app-facing register flow).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS players (
  api_player_id INT PRIMARY KEY,
  team_id       TEXT NOT NULL REFERENCES teams(id),
  name          TEXT NOT NULL,
  position      TEXT,
  photo_url     TEXT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_players_team ON players (team_id);

ALTER TABLE players ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "players_service_only" ON players;
CREATE POLICY "players_service_only" ON players
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ---------------------------------------------------------------------------
-- 2. One-time backfill from the latest squad snapshot per team.
-- ---------------------------------------------------------------------------
-- DISTINCT ON (team_id) ... ORDER BY team_id, fetched_at DESC picks the
-- single newest api_football_squad row per team (raw_fetch_logs' retention
-- sweep — 057_raw_fetch_logs_retention.sql — always keeps this latest row
-- per (source, team_id), so it's guaranteed to exist for any team fetched in
-- the last 7 days). jsonb_array_elements is STRICT, so a team whose stored
-- payload is missing/empty (data->'response'->0->'players' evaluates to SQL
-- NULL) simply contributes zero rows rather than erroring.

INSERT INTO players (api_player_id, team_id, name, position, photo_url, updated_at)
SELECT
  (p->>'id')::INT,
  latest.team_id,
  p->>'name',
  p->>'position',
  p->>'photo',
  now()
FROM (
  SELECT DISTINCT ON (team_id) team_id, data
  FROM raw_fetch_logs
  WHERE source = 'api_football_squad'
  ORDER BY team_id, fetched_at DESC
) latest
CROSS JOIN LATERAL jsonb_array_elements(latest.data -> 'response' -> 0 -> 'players') AS p
WHERE p ->> 'id' IS NOT NULL
ON CONFLICT (api_player_id) DO UPDATE SET
  photo_url = EXCLUDED.photo_url,
  team_id   = EXCLUDED.team_id,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- Verification:
-- ---------------------------------------------------------------------------
-- SELECT team_id, COUNT(*) FROM players GROUP BY team_id ORDER BY team_id;
-- Expected: one row per team that had an api_football_squad fetch in the
-- last 7 days, each with a plausible squad size (~20-30).
