-- 064_apns_jwt_cache.sql
-- Fix APNs 429 TooManyProviderTokenUpdates.
--
-- The APNs client minted a fresh ES256 provider JWT on EVERY send
-- (apns-client.ts sendPushNotification), so a burst of N sends generated N
-- tokens within seconds. APNs requires ONE provider token to be reused for up
-- to an hour and rejects rapid regeneration with 429 — so only the first ~2 of
-- each burst landed and the rest failed (observed: "2 sent, 9 failed of 11
-- eligible" for every Sweden push). Most devices received nothing.
--
-- This single-row table lets every Edge Function share one cached token,
-- bounding generation to ~once per 50 min (well inside APNs's 60-min validity).
CREATE TABLE IF NOT EXISTS apns_jwt_cache (
  id           smallint PRIMARY KEY DEFAULT 1,
  jwt          text NOT NULL,
  generated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT apns_jwt_cache_singleton CHECK (id = 1)
);

ALTER TABLE apns_jwt_cache ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "apns_jwt_cache_service_only" ON apns_jwt_cache;
CREATE POLICY "apns_jwt_cache_service_only" ON apns_jwt_cache
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
