-- 106_revoke_anon_token_read.sql — close the token PII leak (SEC-1, half of SEC-3)
--
-- Verified open on 2026-09-22 with the publishable key that ships in the App
-- Store binary:
--
--   GET /rest/v1/device_tokens?select=apns_token,team_ids,country_ids,tier
--     -> HTTP 200, every row
--
-- Both token tables carried `device_tokens_anon_select` / `la_tokens_anon_select`
-- with USING (true), so anyone who unpacks the app could read every user's APNs
-- token, the clubs and countries they follow, their tier and their APNs
-- environment. That read is also what made the write dangerous: the register
-- RPCs are keyed on the token alone, so being able to LIST tokens turned "you
-- can tamper with a row if you know its token" into "you can tamper with every
-- row".
--
-- Nothing reads these tables from any shipped build. `grep -rn
-- "device_tokens\|live_activity_tokens" ios/` returns comments plus exactly one
-- call, APIClient.updateTokenTier, and that is a PATCH. So revoking SELECT is
-- safe to apply immediately, ahead of the app release.
--
-- live_activity_tokens has no direct write path in any build either — iOS has
-- registered it through register_la_token (SECURITY DEFINER) since June 2026 —
-- so its INSERT/UPDATE go in the same change.
--
-- device_tokens INSERT/UPDATE are NOT dropped here: the live 2.2 build still
-- PATCHes the table to change tier. That is 107, staged for after 2.3 ships.
--
-- The policy names below were read from pg_policies, not from the migration
-- files. 072 was written from the files and got the live_activity_tokens names
-- wrong (`live_activity_tokens_anon_*` vs the real `la_tokens_anon_*`), and
-- DROP POLICY IF EXISTS would have silently done nothing.

BEGIN;

-- device_tokens: the read leak only. Writes stay until 107.
DROP POLICY IF EXISTS device_tokens_anon_select ON device_tokens;
REVOKE SELECT ON device_tokens FROM anon, authenticated;

-- live_activity_tokens: read and write, all of it.
DROP POLICY IF EXISTS la_tokens_anon_select ON live_activity_tokens;
DROP POLICY IF EXISTS la_tokens_anon_insert ON live_activity_tokens;
DROP POLICY IF EXISTS la_tokens_anon_update ON live_activity_tokens;
REVOKE SELECT, INSERT, UPDATE ON live_activity_tokens FROM anon, authenticated;

-- service_role keeps everything: the Edge Functions use the service key and
-- la_tokens_service_all / device_tokens_service_delete are untouched.

COMMIT;
