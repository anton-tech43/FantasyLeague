-- 069_device_tokens_multi_follow.sql
-- Multi-team following (V2.2): a device can follow up to 2 WC countries + 2 PL
-- clubs. Model = ARRAY columns on the existing one-row-per-device table, NOT a
-- row per entity. Rationale (see V2.2_DESIGN_MULTI_TEAM.md):
--   * iOS registers via a direct PostgREST merge-duplicates upsert keyed on
--     UNIQUE(apns_token) (APIClient.registerToken). Dropping that unique would
--     break every already-installed app. So it STAYS — one row per device.
--   * One row per device => a push fan-out can never hit the same apns_token
--     twice, even when a device follows BOTH teams in one fixture.
--
-- The scalar country_id/team_id columns remain the back-compat path: old apps
-- write only scalars; the new app writes the full arrays AND mirrors array[0]
-- into the scalar. Every push read matches scalar OR array, so both worlds work
-- with no trigger and no divergence.

ALTER TABLE device_tokens
  ADD COLUMN IF NOT EXISTS country_ids TEXT[],
  ADD COLUMN IF NOT EXISTS team_ids    TEXT[];

-- Backfill so existing (old-app) rows already satisfy the array predicate the
-- rewritten push queries use. Single-element arrays mirror today's scalars.
UPDATE device_tokens
  SET country_ids = ARRAY[country_id]
  WHERE country_id IS NOT NULL AND country_ids IS NULL;
UPDATE device_tokens
  SET team_ids = ARRAY[team_id]
  WHERE team_id IS NOT NULL AND team_ids IS NULL;

-- GIN indexes back the && (overlap) / @> (contains) filters used by the push
-- fan-outs (match-watcher, morning-push, notification-sender, matchday-reminder).
CREATE INDEX IF NOT EXISTS idx_device_tokens_country_ids
  ON device_tokens USING GIN (country_ids) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_device_tokens_team_ids
  ON device_tokens USING GIN (team_ids) WHERE is_active;

-- NB: UNIQUE(apns_token) is intentionally LEFT IN PLACE.
