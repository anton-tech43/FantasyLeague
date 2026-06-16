-- 070_la_tokens_multi_country.sql
-- Multi-country Live Activities (V2.2). A device has exactly ONE push-to-start
-- token per activity type (Activity<MatchActivityAttributes>.pushToStartToken),
-- and live_activity_tokens is UNIQUE(token) (migration 062). So that single PTS
-- token must be able to trigger for EITHER followed country. Add a country_ids
-- array; the start fan-out (match-watcher) matches country_id OR country_ids.
--
-- UNIQUE(token) stays — one row per token, so a match still starts exactly one
-- Live Activity on the device.

ALTER TABLE live_activity_tokens
  ADD COLUMN IF NOT EXISTS country_ids TEXT[];

UPDATE live_activity_tokens
  SET country_ids = ARRAY[country_id]
  WHERE country_id IS NOT NULL AND country_ids IS NULL;

CREATE INDEX IF NOT EXISTS idx_la_tokens_pts_country_ids
  ON live_activity_tokens USING GIN (country_ids)
  WHERE kind = 'push_to_start' AND is_active;
