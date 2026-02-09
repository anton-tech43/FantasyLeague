-- Goal Digger — Initial Database Schema
-- Version: 1.0
-- Date: 2026-02-09
-- Companion: BUILD_PLAN.md Step 1.2

-- ============================================================================
-- TABLES
-- ============================================================================

-- Teams table (pre-populated via seed_teams.sql)
CREATE TABLE teams (
    id              TEXT PRIMARY KEY,           -- "arsenal", "man_utd", "west_ham"
    display_name    TEXT NOT NULL,              -- "Arsenal", "Manchester United", "West Ham"
    api_football_id INTEGER NOT NULL,           -- Team ID in API-Football
    short_name      TEXT NOT NULL,              -- "Arsenal", "Man Utd", "West Ham"
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Content items — the core data the app displays
CREATE TABLE content_items (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id           TEXT NOT NULL REFERENCES teams(id),
    type              TEXT NOT NULL CHECK (type IN ('news', 'matchday')),
    headline          TEXT NOT NULL,            -- Push notification text (1-2 sentences, max 200 chars)
    body              TEXT NOT NULL,            -- Detail view content (markdown)
    talking_points    JSONB NOT NULL DEFAULT '[]',   -- Array of short strings
    source_urls       JSONB DEFAULT '[]',       -- Original sources for traceability
    match_id          TEXT,                     -- API-Football fixture ID (matchday only)
    kickoff_time      TIMESTAMPTZ,             -- Kickoff time for matchday content (client-side countdown)
    emotional_context TEXT CHECK (emotional_context IN ('exciting', 'bad_news', 'drama', 'informational', 'funny')),
    status            TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'approved', 'rejected', 'published')),
    review_notes      JSONB DEFAULT '[]',       -- Notes from each review bot
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    published_at      TIMESTAMPTZ,

    -- Prevent duplicate content for the same match
    CONSTRAINT unique_matchday_content UNIQUE (team_id, match_id)
);

-- Device tokens for push notifications
CREATE TABLE device_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    apns_token      TEXT NOT NULL UNIQUE,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Raw fetched data for debugging and auditability
CREATE TABLE raw_fetch_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    source          TEXT NOT NULL,             -- "api_football", "bbc_rss", "sky_rss", etc.
    data            JSONB NOT NULL,
    fetched_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Pipeline health tracking for monitoring and debugging
CREATE TABLE pipeline_health (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    stage           TEXT NOT NULL CHECK (stage IN ('fetch', 'generate', 'review', 'publish')),
    status          TEXT NOT NULL CHECK (status IN ('success', 'failure', 'skipped')),
    duration_ms     INTEGER,
    message         TEXT,
    content_item_id UUID REFERENCES content_items(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_content_team_status ON content_items(team_id, status);
CREATE INDEX idx_content_published ON content_items(team_id, published_at DESC)
    WHERE status = 'published';
CREATE INDEX idx_device_tokens_team ON device_tokens(team_id)
    WHERE is_active = true;
CREATE INDEX idx_raw_fetch_team_date ON raw_fetch_logs(team_id, fetched_at DESC);
CREATE INDEX idx_pipeline_health_recent ON pipeline_health(team_id, stage, created_at DESC);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_fetch_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_health ENABLE ROW LEVEL SECURITY;

-- teams: Public read access
CREATE POLICY "teams_public_read" ON teams
    FOR SELECT USING (true);

-- content_items: Public read access for published items only
CREATE POLICY "content_items_public_read" ON content_items
    FOR SELECT USING (status = 'published');

-- content_items: Write access only via service_role key (backend)
CREATE POLICY "content_items_service_write" ON content_items
    FOR ALL USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- device_tokens: Insert/update via anon key (iOS client)
CREATE POLICY "device_tokens_anon_insert" ON device_tokens
    FOR INSERT WITH CHECK (true);

CREATE POLICY "device_tokens_anon_update" ON device_tokens
    FOR UPDATE USING (true)
    WITH CHECK (true);

-- device_tokens: Delete via service_role only
CREATE POLICY "device_tokens_service_delete" ON device_tokens
    FOR DELETE USING (auth.role() = 'service_role');

-- raw_fetch_logs: No public access, service_role only
CREATE POLICY "raw_fetch_logs_service_only" ON raw_fetch_logs
    FOR ALL USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- pipeline_health: No public access, service_role only
CREATE POLICY "pipeline_health_service_only" ON pipeline_health
    FOR ALL USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- ============================================================================
-- RPC FUNCTIONS
-- ============================================================================

-- schedule_matchday_job: Called by matchday-scheduler Edge Function to create
-- one-off pg_cron jobs that trigger content generation before kickoff.
-- Uses pg_net to make HTTP POST to the content-generator function.
CREATE OR REPLACE FUNCTION schedule_matchday_job(
    job_name TEXT,
    cron_schedule TEXT,
    function_url TEXT,
    payload TEXT
) RETURNS void AS $$
DECLARE
    _service_key TEXT;
BEGIN
    _service_key := current_setting('app.settings.service_role_key', true);

    -- Schedule a one-off cron job using pg_cron + pg_net
    PERFORM cron.schedule(
        job_name,
        cron_schedule,
        format(
            $$SELECT net.http_post(
                url := %L,
                body := %L::jsonb,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || %L
                )
            )$$,
            function_url,
            payload,
            _service_key
        )
    );

    -- Schedule removal of the one-off job 2 hours after it runs
    -- (cron jobs persist unless explicitly removed)
    PERFORM cron.schedule(
        job_name || '_cleanup',
        cron_schedule,
        format(
            $$SELECT cron.unschedule(%L); SELECT cron.unschedule(%L);$$,
            job_name,
            job_name || '_cleanup'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SCHEDULED JOBS (pg_cron)
-- ============================================================================

-- Data fetcher: every 30 minutes between 08:00 and 23:00 GMT
-- Note: Replace xxxxx.supabase.co with actual project URL after setup
-- SELECT cron.schedule(
--     'data-fetcher',
--     '*/30 8-23 * * *',
--     $$SELECT net.http_post(
--         'https://xxxxx.supabase.co/functions/v1/data-fetcher',
--         '{}',
--         'application/json',
--         ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))]
--     )$$
-- );

-- Matchday scheduler: daily at 07:00 UTC
-- SELECT cron.schedule(
--     'matchday-scheduler',
--     '0 7 * * *',
--     $$SELECT net.http_post(
--         'https://xxxxx.supabase.co/functions/v1/data-fetcher',
--         '{"matchday_check": true}',
--         'application/json',
--         ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))]
--     )$$
-- );

-- Notification cleanup sweep: every hour
-- SELECT cron.schedule(
--     'notification-sweep',
--     '0 * * * *',
--     $$SELECT net.http_post(
--         'https://xxxxx.supabase.co/functions/v1/notification-sender',
--         '{"sweep": true}',
--         'application/json',
--         ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))]
--     )$$
-- );

-- Weekly cleanup: purge raw_fetch_logs older than 90 days
-- SELECT cron.schedule(
--     'purge-old-logs',
--     '0 3 * * 0',
--     $$DELETE FROM raw_fetch_logs WHERE fetched_at < NOW() - INTERVAL '90 days'$$
-- );
