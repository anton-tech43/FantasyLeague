-- 143: the one view every usage query reads (TRACKING_PLAN build step 4).
--
-- Three corrections live here so no query has to remember them:
--   * production only — Xcode builds log with env = 'development';
--   * blackout windows out — a gap that was ours, not hers (analytics_blackouts);
--   * club_group — Arsenal is ~78% of devices, so every number is split
--     Arsenal / everyone else (TRACKING_PLAN premise 1).
-- A view, not a copy: no rows, no IO, nothing to keep in sync.

BEGIN;

CREATE OR REPLACE VIEW public.analytics_events AS
SELECT e.id, e.install_id, e.name, e.props, e.occurred_at,
       CASE WHEN e.props ->> 'club' = 'arsenal' THEN 'arsenal' ELSE 'other' END AS club_group
  FROM public.app_events e
 WHERE coalesce(e.props ->> 'env', 'production') = 'production'
   AND NOT EXISTS (SELECT 1 FROM public.analytics_blackouts b
                    WHERE e.occurred_at >= b.started_at AND e.occurred_at < b.ended_at);

-- ALL, not SELECT: PG17's MAINTAIN is invisible in role_table_grants (115/116).
REVOKE ALL ON public.analytics_events FROM PUBLIC, anon, authenticated;

COMMIT;

-- Verification:
--   SELECT has_table_privilege('anon', 'public.analytics_events', 'SELECT');  -- f
