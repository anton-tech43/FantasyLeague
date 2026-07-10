-- 030_device_tokens_anon_select.sql
-- Fix RLS so the iOS app can use Prefer: resolution=merge-duplicates on
-- /rest/v1/device_tokens.
--
-- BACKGROUND
-- The iOS app's APIClient.registerToken POSTs with `Prefer: resolution=
-- merge-duplicates` so the second registration of the same token (e.g.,
-- after a fresh install where APNs reissues the same token) is a no-op
-- via ON CONFLICT DO UPDATE. PostgREST translates this into an
-- INSERT ... ON CONFLICT ... DO UPDATE SET ... statement.
--
-- PostgreSQL's ON CONFLICT path needs SELECT on the existing row to
-- detect the conflict. Even with `return=minimal`, the internal conflict
-- check requires the policy. Until now `device_tokens` had only INSERT
-- and UPDATE policies for anon — no SELECT — so every merge-duplicates
-- POST 401'd with 42501 "new row violates row-level security policy".
--
-- The iOS try? swallow at NotificationService.handleTokenRegistration
-- masked the failure: token saved to UserDefaults locally, no row on the
-- server, and the user got zero pushes despite "successful" onboarding.
-- Discovered tonight during the App Store launch smoke test (first real
-- TestFlight install, registered fine but device_tokens stayed empty).
--
-- This migration also records the diagnostic RPC `get_device_tokens_acl`
-- used to find the issue, so a fresh-environment rebuild can re-run it.
--
-- PRIVACY IMPACT
-- anon can now SELECT all device_tokens rows. The rows contain:
--   - team_id (which PL team — mild PII at best)
--   - apns_token (opaque 64-char hex — useless without our .p8 key)
--   - tier, apns_environment, timestamps, is_active
--
-- The publishable key (sb_publishable_*) ships in the iOS binary anyway,
-- so anyone reverse-engineering the app could already query reads. The
-- additional surface from this policy is: enumerate-all-tokens-by-team
-- counts. Acceptable for launch with <20 users.
--
-- V1.1 follow-up: move the upsert behind a SECURITY DEFINER Edge Function
-- so anon doesn't need SELECT at all. Drop this policy after that lands.

-- ---------------------------------------------------------------------------
-- 1. The fix: anon SELECT policy
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS device_tokens_anon_select ON device_tokens;
CREATE POLICY device_tokens_anon_select ON device_tokens
    FOR SELECT TO public USING (true);

-- ---------------------------------------------------------------------------
-- 2. Diagnostic RPC used to discover the issue
-- ---------------------------------------------------------------------------
-- Exposes RLS policies + table grants for device_tokens, so the
-- diagnose-matchday Edge Function can surface them in its health snapshot.
-- SECURITY DEFINER + locked search_path. service_role only.

CREATE OR REPLACE FUNCTION get_device_tokens_acl()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    policies JSONB;
    grants JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(p)), '[]'::jsonb)
    INTO policies
    FROM (
        SELECT policyname, cmd, roles, qual, with_check
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'device_tokens'
        ORDER BY policyname
    ) p;

    SELECT COALESCE(jsonb_agg(row_to_json(g)), '[]'::jsonb)
    INTO grants
    FROM (
        SELECT grantee, privilege_type, is_grantable
        FROM information_schema.role_table_grants
        WHERE table_schema = 'public' AND table_name = 'device_tokens'
        ORDER BY grantee, privilege_type
    ) g;

    RETURN jsonb_build_object(
        'policies', policies,
        'grants', grants
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION get_device_tokens_acl() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_device_tokens_acl() TO service_role;
