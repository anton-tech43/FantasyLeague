-- 058_insights_views.sql
-- Phase A of the tracking/insights layer (Lesson 87). Read-only aggregate
-- VIEWs + a service-role get_insights() RPC, built ENTIRELY from data we
-- already collect to operate the service. No new tracking, no client/iOS
-- change, no privacy-policy change — honours the "we don't track you"
-- promise (every output is a COUNT; no apns_token, no per-user rows).
--
-- Mirrors two existing patterns:
--   - everyone_talking_daily VIEW (migration 005) — daily aggregates.
--   - get_pipeline_diagnostics() RPC (migrations 029/036) — service-role
--     JSONB bundle for one-call reads.
--
-- Signals surfaced (all already captured):
--   - device_tokens: team_id/country_id (who follows what), tier,
--     apns_environment (TestFlight vs App Store), created_at (growth),
--     is_active + updated_at (churn — notification-sender already flips
--     is_active=false on APNs 410/Unregistered + 400/BadDeviceToken).
--   - pipeline_health stage='apns_send': push delivery success + error_class.
--   - content_items: production by type, push vs feed-only, consequences.
--
-- What this CANNOT show (needs the app → Phase B / iOS 2.0.1):
--   push OPENS (Apple never reports them) and in-app SESSIONS.

-- ── Audience ──────────────────────────────────────────────────────────

-- Active followers per entity. A token may follow a club AND a country;
-- both are counted under their respective kind.
CREATE OR REPLACE VIEW v_audience_by_entity AS
  SELECT 'team'::text AS entity_kind, team_id AS entity_id, count(*) AS active_followers
  FROM device_tokens WHERE is_active AND team_id IS NOT NULL
  GROUP BY team_id
  UNION ALL
  SELECT 'country'::text, country_id, count(*)
  FROM device_tokens WHERE is_active AND country_id IS NOT NULL
  GROUP BY country_id;

-- Single-row headline totals.
CREATE OR REPLACE VIEW v_audience_summary AS
  SELECT
    count(*) FILTER (WHERE is_active)                                          AS active,
    count(*) FILTER (WHERE NOT is_active)                                      AS inactive,
    count(*) FILTER (WHERE is_active AND apns_environment = 'production')       AS active_app_store,
    count(*) FILTER (WHERE is_active AND apns_environment = 'development')      AS active_testflight,
    count(*) FILTER (WHERE is_active AND tier = 1)                             AS tier1,
    count(*) FILTER (WHERE is_active AND tier = 2)                             AS tier2,
    count(*) FILTER (WHERE is_active AND tier = 3)                             AS tier3,
    count(*) FILTER (WHERE is_active AND country_id IS NOT NULL)               AS following_country,
    count(*) FILTER (WHERE is_active AND team_id IS NOT NULL)                  AS following_team
  FROM device_tokens;

-- ── Growth + churn ────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_registrations_daily AS
  SELECT date_trunc('day', created_at)::date AS day, count(*) AS new_registrations
  FROM device_tokens
  GROUP BY 1;

-- Churn proxy: inactive rows by the day they were deactivated. Lazy —
-- a deletion only registers when notification-sender next attempts a push
-- to that token and APNs rejects it (updated_at is set at that flip).
CREATE OR REPLACE VIEW v_churn_daily AS
  SELECT date_trunc('day', updated_at)::date AS day, count(*) AS deactivated
  FROM device_tokens WHERE NOT is_active
  GROUP BY 1;

-- ── Push delivery ─────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_push_delivery_daily AS
  SELECT
    date_trunc('day', created_at)::date AS day,
    count(*)                                            AS attempts,
    count(*) FILTER (WHERE status = 'success')          AS delivered,
    count(*) FILTER (WHERE error_class = 'token_expired') AS token_expired,
    count(*) FILTER (WHERE error_class = 'bad_token')   AS bad_token,
    round(100.0 * count(*) FILTER (WHERE status = 'success') / NULLIF(count(*), 0), 1) AS success_pct
  FROM pipeline_health WHERE stage = 'apns_send'
  GROUP BY 1;

-- ── Content production ────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_content_daily AS
  SELECT
    date_trunc('day', created_at)::date AS day,
    count(*)                                          AS items,
    count(*) FILTER (WHERE push_eligible)             AS push_eligible,
    count(*) FILTER (WHERE NOT push_eligible)         AS feed_only,
    count(*) FILTER (WHERE pushed_at IS NOT NULL)     AS pushed,
    count(*) FILTER (WHERE consequence_type IS NOT NULL) AS consequence_events
  FROM content_items
  GROUP BY 1;

-- Per-entity content coverage (ties into the 47-empty-feed WC gap). Counts
-- ALL content_items per team/country; 0 = empty feed.
CREATE OR REPLACE VIEW v_content_coverage AS
  SELECT t.id AS entity_id, t.entity_type, count(c.id) AS content_items
  FROM teams t LEFT JOIN content_items c ON c.team_id = t.id
  GROUP BY t.id, t.entity_type;

-- ── One-call bundle (RPC) ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_insights(days integer DEFAULT 14)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'snapshot_at', now(),
    'window_days', days,
    'audience', (SELECT to_jsonb(s) FROM v_audience_summary s),
    'top_countries', (
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.active_followers DESC)
      FROM (SELECT entity_id, active_followers FROM v_audience_by_entity
            WHERE entity_kind = 'country' ORDER BY active_followers DESC LIMIT 15) t),
    'top_teams', (
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.active_followers DESC)
      FROM (SELECT entity_id, active_followers FROM v_audience_by_entity
            WHERE entity_kind = 'team' ORDER BY active_followers DESC LIMIT 15) t),
    'registrations', (
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.day DESC)
      FROM (SELECT day, new_registrations FROM v_registrations_daily
            WHERE day >= now()::date - days) t),
    'churn', (
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.day DESC)
      FROM (SELECT day, deactivated FROM v_churn_daily
            WHERE day >= now()::date - days) t),
    'push_delivery', (
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.day DESC)
      FROM (SELECT * FROM v_push_delivery_daily WHERE day >= now()::date - days) t),
    'content', (
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.day DESC)
      FROM (SELECT * FROM v_content_daily WHERE day >= now()::date - days) t),
    'empty_feeds', (
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_id)
      FROM (SELECT entity_id, entity_type FROM v_content_coverage
            WHERE content_items = 0) t)
  );
$$;

-- ── Lock down: aggregates are service-role only (off the anon surface) ──
-- Consistent with migration 055's posture for diagnostics RPCs.
REVOKE EXECUTE ON FUNCTION get_insights(integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION get_insights(integer) TO service_role;

REVOKE ALL ON v_audience_by_entity, v_audience_summary, v_registrations_daily,
              v_churn_daily, v_push_delivery_daily, v_content_daily,
              v_content_coverage
  FROM anon, authenticated;

-- Verification:
--   SELECT get_insights(14);   -- service role → JSONB bundle
--   SET ROLE anon; SELECT get_insights(14);  -- → permission denied
