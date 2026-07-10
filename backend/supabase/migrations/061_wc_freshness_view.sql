-- 061_wc_freshness_view.sql
-- WC data-freshness tracking (Lesson 97). A read-only lens over the 48 WC
-- country pages so staleness is easy to spot going forward: it surfaces the
-- page-level updated_at AND each card's own updated_at (the cards carry their
-- own ISO timestamp), with ages in hours and a stale flag.
--
-- Why two tiers of card:
--   DYNAMIC cards (standings, next_fixture, form, upcoming_fixtures) are
--   rebuilt every data-fetcher cycle via team-page-generator dynamic_only.
--   data-fetcher fires every 2h during 06:00-22:00 UTC (migration 050) and is
--   silent overnight, so a healthy page is <2h old by day and up to ~8h old
--   overnight. The `stale` flag trips at >14h — a page that has missed a full
--   waking cycle (genuinely stuck), not a normal overnight gap.
--   STATIC/LLM cards (manager, ones_to_know, season, basics) are written only
--   on a full regen or a deterministic override, so they are legitimately
--   days/weeks old — surfaced for visibility but NOT counted as stale.
--
-- Mirrors migration 058 (insights views + a service-role get_* RPC bundle).

-- ── Per-country freshness row ─────────────────────────────────────────────
-- Drop-then-create (not CREATE OR REPLACE): re-applying with new/reordered
-- columns is otherwise rejected. The RPC depends on the view, so drop it first.
DROP FUNCTION IF EXISTS get_wc_freshness(integer);
DROP VIEW IF EXISTS v_wc_page_freshness;

CREATE VIEW v_wc_page_freshness AS
  SELECT
    t.id AS team_id,
    (tp.content->'cards'->'standings'->>'competition_label') AS group_label,
    tp.updated_at AS page_updated_at,
    round(EXTRACT(EPOCH FROM (now() - tp.updated_at)) / 3600.0, 1) AS page_age_hours,
    -- dynamic cards (should track the refresh cadence). *_hours pre-computed
    -- so consumers (the dashboard script) needn't parse JSONB timestamps.
    (tp.content->'cards'->'standings'->>'updated_at')::timestamptz    AS standings_at,
    round(EXTRACT(EPOCH FROM (now() - (tp.content->'cards'->'standings'->>'updated_at')::timestamptz)) / 3600.0, 1)    AS standings_hours,
    (tp.content->'cards'->'next_fixture'->>'updated_at')::timestamptz AS next_fixture_at,
    round(EXTRACT(EPOCH FROM (now() - (tp.content->'cards'->'next_fixture'->>'updated_at')::timestamptz)) / 3600.0, 1) AS next_fixture_hours,
    (tp.content->'cards'->'form'->>'updated_at')::timestamptz         AS form_at,
    round(EXTRACT(EPOCH FROM (now() - (tp.content->'cards'->'form'->>'updated_at')::timestamptz)) / 3600.0, 1)         AS form_hours,
    coalesce(jsonb_array_length(tp.content->'cards'->'upcoming_fixtures'), 0) AS n_upcoming,
    -- static / LLM cards (legitimately old — for visibility, not staleness)
    (tp.content->'cards'->'manager'->>'updated_at')::timestamptz      AS manager_at,
    round(EXTRACT(EPOCH FROM (now() - (tp.content->'cards'->'manager'->>'updated_at')::timestamptz)) / 3600.0, 1)      AS manager_hours,
    (tp.content->'cards'->'manager'->>'name')                         AS manager_name,
    (tp.content->'cards'->'ones_to_know'->>'updated_at')::timestamptz AS ones_to_know_at,
    round(EXTRACT(EPOCH FROM (now() - (tp.content->'cards'->'ones_to_know'->>'updated_at')::timestamptz)) / 3600.0, 1) AS ones_to_know_hours,
    coalesce(jsonb_array_length(tp.content->'cards'->'ones_to_know'->'players'), 0) AS n_players,
    (tp.content->'cards'->'season'->>'updated_at')::timestamptz       AS season_at,
    round(EXTRACT(EPOCH FROM (now() - (tp.content->'cards'->'season'->>'updated_at')::timestamptz)) / 3600.0, 1)       AS season_hours,
    (tp.content->'cards'->'basics'->>'updated_at')::timestamptz       AS basics_at,
    -- stale = page hasn't refreshed across a full waking cycle (not overnight)
    (tp.updated_at < now() - interval '14 hours') AS stale
  FROM teams t
  JOIN team_pages tp ON tp.team_id = t.id
  WHERE t.entity_type = 'country';

-- ── One-call bundle (RPC), service-role only ──────────────────────────────
-- stale_hours lets the caller tune the threshold (default 14h, per the
-- overnight-gap reasoning above).
CREATE OR REPLACE FUNCTION get_wc_freshness(stale_hours integer DEFAULT 14)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'snapshot_at', now(),
    'stale_threshold_hours', stale_hours,
    'total', (SELECT count(*) FROM v_wc_page_freshness),
    'stale_count', (
      SELECT count(*) FROM v_wc_page_freshness
      WHERE page_updated_at < now() - make_interval(hours => stale_hours)),
    'oldest_page_hours', (SELECT max(page_age_hours) FROM v_wc_page_freshness),
    'stale_teams', (
      SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.page_age_hours DESC), '[]'::jsonb)
      FROM (
        SELECT team_id, group_label, page_age_hours
        FROM v_wc_page_freshness
        WHERE page_updated_at < now() - make_interval(hours => stale_hours)
      ) s),
    'pages', (
      SELECT jsonb_agg(to_jsonb(s) ORDER BY s.group_label, s.team_id)
      FROM v_wc_page_freshness s)
  );
$$;

-- Aggregates stay off the anon surface (mirrors migration 055/058 posture).
REVOKE ALL ON v_wc_page_freshness FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION get_wc_freshness(integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION get_wc_freshness(integer) TO service_role;

-- Verification:
--   SELECT team_id, page_age_hours, stale FROM v_wc_page_freshness ORDER BY page_age_hours DESC;
--   SELECT get_wc_freshness();          -- service role → JSONB bundle
--   SET ROLE anon; SELECT get_wc_freshness();  -- → permission denied
