-- 021_team_season_state.sql
-- v1.1 Season Primer (V1.1_FEATURE_BUNDLE.md task A1)
--
-- Stores a daily-refreshed "where are they in the season" snapshot per team
-- plus three ready-to-send one-liners (the "welcome drop" used by the
-- post-onboarding primer screen).
--
-- The iOS app reads this via the team-season-state Edge Function and renders
-- a one-screen primer between onboarding completion and the news feed.

CREATE TABLE team_season_state (
    team_id          TEXT PRIMARY KEY REFERENCES teams(id),
    phase            TEXT NOT NULL CHECK (phase IN (
                         'pre_season',
                         'mid_season',
                         'run_in',
                         'off_season',
                         'post_season'
                     )),
    summary          TEXT NOT NULL,         -- 2 sentences; where they're at
    key_fact         TEXT NOT NULL,         -- one surprising or notable line
    welcome_lines    JSONB NOT NULL DEFAULT '[]',  -- ["text", "text", "text"]
    next_fixture     JSONB,                 -- {opponent, kickoff_time, venue}
    generated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS: read-only public access via anon key; writes only via service role.
-- Pattern matches team_pages from migration 002.
ALTER TABLE team_season_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "team_season_state is publicly readable"
    ON team_season_state
    FOR SELECT
    USING (true);

-- ---------------------------------------------------------------------------
-- pg_cron: regenerate daily at 06:00 UTC
-- ---------------------------------------------------------------------------
-- Use the get_cron_service_key() SECURITY DEFINER accessor introduced in
-- migration 020. The inline `SELECT FROM vault.decrypted_secrets` pattern
-- (used by migration 019) silently fails because pg_cron's execution role
-- cannot read the Vault view directly — the SELECT returns NULL and
-- `'Bearer ' || NULL = NULL`, leaving an empty Authorization header.
-- The accessor function bypasses that with SECURITY DEFINER.

SELECT cron.schedule(
    'team-season-state-daily',
    '0 6 * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/team-season-state-generator',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb
    )$$
);
