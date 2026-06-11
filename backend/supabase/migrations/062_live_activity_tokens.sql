-- 062_live_activity_tokens.sql
-- ActivityKit Live Activity support (Lesson 99): push-token store + per-fixture
-- drive state for the live WC match Live Activity (Lock Screen + Dynamic Island).
--
-- Token-write posture mirrors device_tokens: the app upserts directly via
-- PostgREST with the anon key (Prefer: resolution=merge-duplicates on the unique
-- `token`). The tokens are opaque APNs tokens — useless without the .p8 auth key
-- (which only the server holds) — so the residual read exposure is minor; moving
-- both device_tokens and this table behind a service-gated register function is
-- the documented Wave-2 follow-up.

CREATE TABLE IF NOT EXISTS live_activity_tokens (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- push-to-start + update tokens are longer than the 64-hex device token, so
  -- only assert "hex, reasonably long" rather than a fixed width.
  token            TEXT NOT NULL UNIQUE
                     CONSTRAINT valid_la_token CHECK (token ~ '^[a-fA-F0-9]{16,}$'),
  kind             TEXT NOT NULL CHECK (kind IN ('push_to_start', 'update')),
  fixture_id       INTEGER,        -- set for kind='update' (the activity's match)
  country_id       TEXT,           -- the follower's WC country slug
  apns_environment TEXT NOT NULL DEFAULT 'development'
                     CHECK (apns_environment IN ('development', 'production')),
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lookup paths the match-watcher uses: push-to-start by country (kickoff fan-out),
-- update tokens by fixture (in-match updates / end).
CREATE INDEX IF NOT EXISTS idx_la_tokens_pts
  ON live_activity_tokens (country_id) WHERE kind = 'push_to_start' AND is_active;
CREATE INDEX IF NOT EXISTS idx_la_tokens_update
  ON live_activity_tokens (fixture_id) WHERE kind = 'update' AND is_active;

ALTER TABLE live_activity_tokens ENABLE ROW LEVEL SECURITY;

-- anon: register (INSERT) + upsert (UPDATE, for merge-duplicates) + read the
-- conflict key (SELECT). Service role: full. Mirrors device_tokens.
DROP POLICY IF EXISTS la_tokens_anon_insert ON live_activity_tokens;
DROP POLICY IF EXISTS la_tokens_anon_update ON live_activity_tokens;
DROP POLICY IF EXISTS la_tokens_anon_select ON live_activity_tokens;
DROP POLICY IF EXISTS la_tokens_service_all ON live_activity_tokens;
CREATE POLICY la_tokens_anon_insert ON live_activity_tokens FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY la_tokens_anon_update ON live_activity_tokens FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY la_tokens_anon_select ON live_activity_tokens FOR SELECT TO anon USING (true);
CREATE POLICY la_tokens_service_all ON live_activity_tokens FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION touch_la_tokens_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_la_tokens_touch ON live_activity_tokens;
CREATE TRIGGER trg_la_tokens_touch BEFORE UPDATE ON live_activity_tokens
  FOR EACH ROW EXECUTE FUNCTION touch_la_tokens_updated_at();

-- Per-fixture Live Activity drive state (idempotency for start / update / end),
-- written by match-watcher alongside the existing status/score columns.
ALTER TABLE match_status_state ADD COLUMN IF NOT EXISTS la_started BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE match_status_state ADD COLUMN IF NOT EXISTS la_sig TEXT;        -- last pushed score+period signature
ALTER TABLE match_status_state ADD COLUMN IF NOT EXISTS la_ended BOOLEAN NOT NULL DEFAULT FALSE;
