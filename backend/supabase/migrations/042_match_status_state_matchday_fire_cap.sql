-- 042_match_status_state_matchday_fire_cap.sql
-- Cap match-watcher's matchday-fire retry loop.
--
-- Context:
-- match-watcher gates the matchday-fire retry loop on
-- match_status_state.fired_finished_at, which is set ONLY when BOTH
-- home and away perspective fires succeed. If either perspective
-- returns non-2xx (429 from quota, 503 from routine API, etc.),
-- fired_finished_at stays NULL and the next 1-minute cron tick fires
-- again. Tonight (May 17 2026) we observed this firsthand: 4 PL
-- fixtures × 2 perspectives = 8 fire targets, each retrying every
-- minute for 30+ minutes, producing 288 wasted matchday_fire rows
-- in pipeline_health. CHECK 5 (migration 041) catches the SYMPTOM
-- but doesn't stop the LOOP.
--
-- Note on live_brief: it doesn't need the same fix. Live_brief uses
-- briefs_fired (JSONB array) which is updated UNCONDITIONALLY in the
-- upsert at end of tick, regardless of fire outcome. Once a trigger
-- label lands in briefs_fired, the trigger-detection predicate excludes
-- it from newTriggers on the next tick. Implicit single-attempt design.
-- A live-brief HT failure means no retry within the HT window — that's
-- a known trade-off, deferred to V2.x as "Live-brief HT retry within
-- window." For tonight, only matchday needs the cap.
--
-- Fix:
--  1. Add matchday_fire_capped BOOLEAN column. Match-watcher reads it as
--     part of the per-fixture prior-state load and uses it as a hard
--     "skip fire forever" gate.
--  2. Match-watcher does a pre-fire check against pipeline_health: count
--     failures for this fixture's matchday_fire targets in the last 6h.
--     If failures >= 5 OR first failure was > 2h ago, mark capped=TRUE
--     in the upsert and skip the fire.
--  3. Backfill the column for currently-stuck fixtures so the next tick
--     doesn't re-fire them. Tonight's 4 stuck fixtures should flip from
--     FALSE to TRUE on this migration's UPDATE.
--
-- fired_finished_at semantics are PRESERVED (still set only on success).
-- CHECK 4 continues to correctly catch the "fire succeeded but content
-- didn't land" class. The capped flag handles the orthogonal "fire never
-- succeeded after N attempts" class.

ALTER TABLE match_status_state
  ADD COLUMN IF NOT EXISTS matchday_fire_capped BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: mark currently-stuck fixtures as capped so match-watcher
-- doesn't re-fire them on the next tick after this migration applies.
-- A fixture is stuck if:
--   - it's at FT/AET/PEN status
--   - fired_finished_at is still NULL (matchday content didn't land)
--   - AND it has at least one matchday_fire target with >=5 failures
--     OR a first-failure older than 2h in the last 6h window
-- This matches the same cap logic match-watcher will apply going forward.
UPDATE match_status_state mss
SET matchday_fire_capped = TRUE
WHERE matchday_fire_capped = FALSE
  AND fired_finished_at IS NULL
  AND status IN ('FT', 'AET', 'PEN')
  AND fixture_id IN (
    SELECT DISTINCT SPLIT_PART(ph.target, ':', 3)::int
    FROM pipeline_health ph
    WHERE ph.stage = 'matchday_fire'
      AND ph.status = 'failure'
      AND ph.created_at > NOW() - INTERVAL '6 hours'
      AND ph.target LIKE 'matchday_fire:%:%'
    GROUP BY ph.target
    HAVING COUNT(*) >= 5
       OR MIN(ph.created_at) < NOW() - INTERVAL '2 hours'
  );

-- Verification:
--   SELECT fixture_id, home_team_id, away_team_id, status,
--          matchday_fire_capped, fired_finished_at
--   FROM match_status_state
--   WHERE matchday_fire_capped = TRUE;
-- Expected post-apply for tonight: rows for fixtures 1379332 (Brentford
-- vs Crystal Palace) and 1379335 (Leeds vs Brighton), both with
-- matchday_fire_capped = TRUE, fired_finished_at NULL.
