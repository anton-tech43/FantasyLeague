-- 025_live_match_briefs.sql
-- v1.1 Match-day Live Card (V1.1_FEATURE_BUNDLE.md task C5)
--
-- Rolling in-match commentary card. The gd-live-brief cloud routine writes
-- one row per trigger window during a live PL match (HT, 75' for v1; goal
-- triggers in a follow-up). iOS polls the live-brief-current Edge Function
-- every 60s for the user's team during a live window and renders a
-- LiveMatchCard at the top of the feed. T2+ tier-gated client-side.

CREATE TABLE live_match_briefs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id       TEXT NOT NULL REFERENCES teams(id),
    -- API-Football fixture id (text) — we already keep it as text in
    -- match_status_state, keep it consistent here. Lets a single match
    -- have multiple briefs (HT, 75', future goal triggers).
    match_id      TEXT NOT NULL,
    headline      TEXT NOT NULL,   -- the hook the LiveMatchCard renders
    body          TEXT NOT NULL,   -- 1-2 sentences of context
    minute        INTEGER,         -- match minute when the trigger fired
    trigger_label TEXT,            -- 'HT' | '75' | future: 'goal' | 'redcard' | etc.
    generated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index serves the read endpoint: "give me the newest brief for this team
-- in the active window." Composite descending by generated_at + match_id
-- so we can also scope to a single match for analytics.
CREATE INDEX idx_live_briefs_team_generated
    ON live_match_briefs (team_id, generated_at DESC);

CREATE INDEX idx_live_briefs_match
    ON live_match_briefs (match_id, generated_at DESC);

-- RLS: read-only public access, writes only via service role. Matches the
-- pattern of team_pages / team_season_state / team_insider_items.
ALTER TABLE live_match_briefs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "live_match_briefs is publicly readable"
    ON live_match_briefs
    FOR SELECT
    USING (true);

-- Idempotency support on match_status_state. The match-watcher cron fires
-- every minute, so each trigger window (e.g., "HT" = ~15 minutes of
-- status='HT') will repeat the trigger condition many times. The
-- briefs_fired JSONB array tracks which labels we've already fired per
-- fixture so we don't generate 15 briefs in a single HT.
--
-- Default to empty array. Writes happen as JSONB array containment checks:
--   UPDATE match_status_state
--   SET briefs_fired = briefs_fired || '"HT"'::jsonb
--   WHERE fixture_id = $1 AND NOT (briefs_fired @> '["HT"]');
-- The WHERE clause is the atomic guard — first writer wins.
ALTER TABLE match_status_state
    ADD COLUMN IF NOT EXISTS briefs_fired JSONB NOT NULL DEFAULT '[]'::jsonb;
