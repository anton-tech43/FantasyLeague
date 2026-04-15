-- 002_tiers_and_context.sql
-- Goal Digger — Tiers, Team Context, Player Cards, Team Pages
-- Adds tier column to device_tokens, creates team_context, player_cards, team_pages tables

-- ============================================================
-- ADD TIER TO DEVICE TOKENS
-- ============================================================

-- Tier 1 = "Just enough to get by"
-- Tier 2 = "Came to impress" (default)
-- Tier 3 = "The one he brags about"
ALTER TABLE device_tokens ADD COLUMN tier INTEGER DEFAULT 2 CHECK (tier IN (1, 2, 3));

-- ============================================================
-- TEAM CONTEXT TABLE
-- ============================================================

-- Pressure flags that change the emotional weight of talking points
-- Updated by data-fetcher after every standings/form pull
CREATE TABLE team_context (
    team_id    TEXT PRIMARY KEY REFERENCES teams(id),
    flags      JSONB NOT NULL DEFAULT '[]',
    -- Valid flags: title_race, cl_spot, europa_spot, cup_run, relegation,
    --             bad_form, derby_upcoming, derby_just_played, cup_knockout
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PLAYER CARDS TABLE
-- ============================================================

-- Cached player profiles in GoalDigger voice
CREATE TABLE player_cards (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id     TEXT NOT NULL REFERENCES teams(id),
    player_name TEXT NOT NULL,
    position    TEXT NOT NULL,
    age         INTEGER,
    summary     TEXT NOT NULL,
    vibe        TEXT,
    form        TEXT,
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_player_team UNIQUE (team_id, player_name)
);

-- ============================================================
-- TEAM PAGES TABLE
-- ============================================================

-- Static-ish team profiles in GoalDigger voice, refreshed weekly
CREATE TABLE team_pages (
    team_id    TEXT PRIMARY KEY REFERENCES teams(id),
    content    JSONB NOT NULL,
    -- JSONB structure:
    -- {
    --   "nickname": "The Gunners",
    --   "stadium": "Emirates Stadium, London",
    --   "manager": "Mikel Arteta. Been at Arsenal since 2019...",
    --   "top_players": [{"name": "Saka", "position": "winger", "one_liner": "..."}],
    --   "biggest_rival": "Tottenham — the North London Derby...",
    --   "fun_fact": "...",
    --   "season_summary": "Currently sitting 2nd..."
    -- }
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_player_cards_team ON player_cards(team_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE team_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_pages ENABLE ROW LEVEL SECURITY;

-- Public read access (anon can SELECT)
CREATE POLICY team_context_read ON team_context FOR SELECT TO anon USING (true);
CREATE POLICY player_cards_read ON player_cards FOR SELECT TO anon USING (true);
CREATE POLICY team_pages_read ON team_pages FOR SELECT TO anon USING (true);

-- Write access only via service_role (backend)
CREATE POLICY team_context_write ON team_context FOR ALL TO service_role USING (true);
CREATE POLICY player_cards_write ON player_cards FOR ALL TO service_role USING (true);
CREATE POLICY team_pages_write ON team_pages FOR ALL TO service_role USING (true);
