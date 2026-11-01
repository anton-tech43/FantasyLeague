-- 149: TestFlight builds stop counting as users (app council 2026-10-29).
--
-- env only separates Xcode builds: TestFlight and the App Store are both
-- Release builds with production APNs, so every tester's tap was counted as a
-- user's. The app now stamps props.channel on every event: 'appstore',
-- 'testflight' or 'debug' (from AppTransaction.environment). The view drops
-- testflight and debug; an event without a channel (every build before this
-- one) reads as unknown and is kept, as it was. TestFlight usage is still in
-- app_events for anyone who wants it.

BEGIN;

CREATE OR REPLACE VIEW public.analytics_events AS
SELECT e.id, e.install_id, e.name, e.props, e.occurred_at,
       CASE WHEN e.props ->> 'club' = 'arsenal' THEN 'arsenal' ELSE 'other' END AS club_group
  FROM public.app_events e
 WHERE coalesce(e.props ->> 'env', 'production') = 'production'
   AND coalesce(e.props ->> 'channel', 'unknown') NOT IN ('testflight', 'debug')
   AND NOT EXISTS (SELECT 1 FROM public.analytics_blackouts b
                    WHERE e.occurred_at >= b.started_at AND e.occurred_at < b.ended_at);

REVOKE ALL ON public.analytics_events FROM PUBLIC, anon, authenticated;

COMMIT;

-- Verification:
--   SELECT has_table_privilege('anon', 'public.analytics_events', 'SELECT');  -- f
