-- 001_initial_schema.sql
-- Goal Digger — Initial Database Schema
-- Tables: teams, content_items, device_tokens, raw_fetch_logs, pipeline_health
-- Includes: CHECK constraints, rate limit trigger, indexes, RLS policies

-- ============================================================
-- TABLES
-- ============================================================

-- Teams table (pre-populated via seed_teams.sql)
CREATE TABLE teams (
    id              TEXT PRIMARY KEY,
    display_name    TEXT NOT NULL,
    api_football_id INTEGER NOT NULL,
    short_name      TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Content items — the core data the app displays
CREATE TABLE content_items (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id           TEXT NOT NULL REFERENCES teams(id),
    type              TEXT NOT NULL CHECK (type IN ('news', 'matchday')),
    headline          TEXT NOT NULL,
    body              TEXT NOT NULL,
    talking_points    JSONB NOT NULL DEFAULT '[]',
    source_urls       JSONB DEFAULT '[]',
    match_id          TEXT,
    kickoff_time      TIMESTAMPTZ,
    emotional_context TEXT CHECK (emotional_context IN ('exciting', 'bad_news', 'drama', 'informational', 'funny')),
    status            TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'approved', 'rejected', 'published')),
    review_notes      JSONB DEFAULT '[]',
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    published_at      TIMESTAMPTZ,

    CONSTRAINT unique_matchday_content UNIQUE (team_id, match_id)
);

-- Device tokens for push notifications
-- SECURITY: apns_token validated as 64-char hex (standard APNs format)
CREATE TABLE device_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id     TEXT NOT NULL REFERENCES teams(id),
    apns_token  TEXT NOT NULL UNIQUE
                CONSTRAINT valid_apns_token CHECK (apns_token ~ '^[a-fA-F0-9]{64}$'),
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- SECURITY: Rate limiting function for device token registration
-- Prevents flooding: max 500 new registrations per hour globally
CREATE OR REPLACE FUNCTION check_token_rate_limit()
RETURNS TRIGGER AS $$
BEGIN
    IF (
        SELECT COUNT(*) FROM device_tokens
        WHERE created_at > NOW() - INTERVAL '1 hour'
    ) > 500 THEN
        RAISE EXCEPTION 'Global rate limit exceeded for token registration';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_token_rate_limit
    BEFORE INSERT ON device_tokens
    FOR EACH ROW EXECUTE FUNCTION check_token_rate_limit();

-- Raw fetched data for debugging and auditability
CREATE TABLE raw_fetch_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id     TEXT NOT NULL REFERENCES teams(id),
    source      TEXT NOT NULL,
    data        JSONB NOT NULL,
    fetched_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Pipeline health tracking for monitoring and debugging
CREATE TABLE pipeline_health (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    stage           TEXT NOT NULL CHECK (stage IN ('fetch', 'generate', 'review', 'safety_review', 'publish')),
    status          TEXT NOT NULL CHECK (status IN ('success', 'failure', 'skipped')),
    duration_ms     INTEGER,
    message         TEXT,
    content_item_id UUID REFERENCES content_items(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_content_team_status ON content_items(team_id, status);
CREATE INDEX idx_content_published ON content_items(team_id, published_at DESC)
    WHERE status = 'published';
CREATE INDEX idx_device_tokens_team ON device_tokens(team_id)
    WHERE is_active = true;
CREATE INDEX idx_raw_fetch_team_date ON raw_fetch_logs(team_id, fetched_at DESC);
CREATE INDEX idx_pipeline_health_recent ON pipeline_health(team_id, stage, created_at DESC);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_fetch_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_health ENABLE ROW LEVEL SECURITY;

-- teams: public read
CREATE POLICY teams_read ON teams FOR SELECT TO anon USING (true);
CREATE POLICY teams_service ON teams FOR ALL TO service_role USING (true);

-- content_items: public read only published items
CREATE POLICY content_items_read ON content_items
    FOR SELECT TO anon
    USING (status = 'published');
CREATE POLICY content_items_service ON content_items
    FOR ALL TO service_role USING (true);

-- device_tokens: anon can INSERT, restricted UPDATE (only team_id and updated_at)
CREATE POLICY device_tokens_insert ON device_tokens
    FOR INSERT TO anon
    WITH CHECK (true);

-- SECURITY: anon can only update team_id, tier, and updated_at
-- Cannot modify apns_token or is_active
-- Note: RLS WITH CHECK cannot reference OLD values in Postgres,
-- so we use a BEFORE UPDATE trigger to enforce column immutability.
CREATE POLICY device_tokens_update ON device_tokens
    FOR UPDATE TO anon
    USING (true)
    WITH CHECK (true);

-- Trigger-based enforcement: reject updates that change protected columns
CREATE OR REPLACE FUNCTION enforce_device_token_immutable_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.apns_token IS DISTINCT FROM OLD.apns_token THEN
        RAISE EXCEPTION 'Cannot modify apns_token via anon role';
    END IF;
    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
        RAISE EXCEPTION 'Cannot modify is_active via anon role';
    END IF;
    -- Force updated_at to now
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_device_token_columns
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW
    WHEN (current_setting('role') = 'anon')
    EXECUTE FUNCTION enforce_device_token_immutable_columns();

CREATE POLICY device_tokens_service ON device_tokens
    FOR ALL TO service_role USING (true);

-- raw_fetch_logs: service_role only
CREATE POLICY raw_fetch_logs_service ON raw_fetch_logs
    FOR ALL TO service_role USING (true);

-- pipeline_health: service_role only
CREATE POLICY pipeline_health_service ON pipeline_health
    FOR ALL TO service_role USING (true);
