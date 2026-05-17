-- 033_device_tokens_country_id.sql
-- V2.0 World Cup support — push routing per country.
--
-- The V2.0 onboarding makes WC country the primary entity. A user can have:
--   - just a country (WC-only audience — the inbound during marketing push)
--   - both a club AND a country (existing PL fans plus their national team)
--   - just a club (V1.x users who haven't done the WC upgrade prompt yet)
--
-- The device_tokens row needs to express which entity (or both) this token
-- subscribes to so notification-sender can fan out per-team and per-country.
-- We do this by:
--   1. Adding a nullable `country_id` column alongside the existing `team_id`.
--   2. Making `team_id` nullable so WC-only users have a valid row.
--
-- After this migration:
--   - V1.x users: team_id='arsenal', country_id=null (unchanged)
--   - WC migration-prompt accepted: team_id='arsenal', country_id='england'
--   - New V2.0 WC-only user: team_id=null, country_id='england'
--   - New V2.0 with both: team_id='arsenal', country_id='england'
--
-- Push routing: notification-sender already filters device_tokens by team_id
-- on each content_item. Phase 2 extends it to OR with country_id when the
-- content_item is country-tagged. For now this migration just makes the
-- column available; the function update is a follow-on.

-- ---------------------------------------------------------------------------
-- 1. Add country_id column
-- ---------------------------------------------------------------------------

ALTER TABLE device_tokens
  ADD COLUMN IF NOT EXISTS country_id TEXT REFERENCES teams(id);

-- ---------------------------------------------------------------------------
-- 2. Relax NOT NULL on team_id
-- ---------------------------------------------------------------------------
-- Existing column was NOT NULL (V1.0 invariant: every device subscribes to
-- exactly one PL club). V2.0 breaks this — WC-only users have no club.
-- The unique constraint on apns_token (one row per token) is unchanged.

ALTER TABLE device_tokens
  ALTER COLUMN team_id DROP NOT NULL;

-- ---------------------------------------------------------------------------
-- 3. Index for country_id lookups
-- ---------------------------------------------------------------------------
-- Partial index — only non-null country_id rows are indexed. Keeps the
-- index small (V2.0 launch will have many V1.x rows with country_id=null).

CREATE INDEX IF NOT EXISTS idx_device_tokens_country_id
  ON device_tokens (country_id) WHERE country_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. Sanity check (commented — paste into SQL Editor or psql to verify)
-- ---------------------------------------------------------------------------
-- \d device_tokens
-- Expected: team_id is nullable, country_id is present (text, nullable, FK to teams.id).
