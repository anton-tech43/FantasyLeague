-- 054_lock_open_tables.sql
--
-- Pre-launch RLS hardening. Two public-schema tables shipped with RLS
-- DISABLED and full anon/authenticated grants (SELECT/INSERT/UPDATE/
-- DELETE/TRUNCATE). Because the publishable (anon) key is embedded in
-- the iOS binary and trivially extractable, anyone could TRUNCATE or
-- corrupt these tables via the PostgREST endpoint:
--
--   match_status_state — match-watcher's fixture-state ledger. A
--     TRUNCATE blinds match-watcher (no FT detection → no matchday or
--     live-brief pushes); fake INSERTs trigger spurious pushes; UPDATEs
--     corrupt live scores. Highest-impact exploit pre-launch.
--   analogy_rejections — internal analogy-critic monitoring. Low impact
--     but still shouldn't be anon-writable.
--
-- Neither table is read or written by the iOS app directly:
--   - match_status_state is touched only server-side (match-watcher +
--     the live-brief-current Edge Function, both service_role; pg_cron
--     jobs run as table owner and bypass RLS).
--   - analogy_rejections is written only by content-reviewer
--     (service_role).
-- So locking to service_role is zero-risk to the client.
--
-- Pattern mirrors the already-locked tables (raw_fetch_logs,
-- pipeline_health, client_errors): enable RLS + a single service_role
-- ALL policy. We ALSO REVOKE the anon/authenticated grants as
-- defence-in-depth — the TRUNCATE/DELETE grants in particular have no
-- business being on these roles.
--
-- See STATUS.md launch-day security audit + Lesson 79.

-- ── match_status_state ──────────────────────────────────────────
ALTER TABLE match_status_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS match_status_state_service_only ON match_status_state;
CREATE POLICY match_status_state_service_only ON match_status_state
  FOR ALL TO public
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

REVOKE ALL ON match_status_state FROM anon, authenticated;

-- ── analogy_rejections ──────────────────────────────────────────
ALTER TABLE analogy_rejections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS analogy_rejections_service_only ON analogy_rejections;
CREATE POLICY analogy_rejections_service_only ON analogy_rejections
  FOR ALL TO public
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

REVOKE ALL ON analogy_rejections FROM anon, authenticated;
