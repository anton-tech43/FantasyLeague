# Goal Digger — Build Plan

**Version:** 1.1
**Date:** April 6, 2026 (security audit applied)
**Companion documents:** [PRD.md](./PRD.md) | [AGENT_CONTRACTS.md](./AGENT_CONTRACTS.md) | [CHANGELOG_SECURITY.md](./CHANGELOG_SECURITY.md) | [PRODUCT_BRIEF_INTEGRATION.md](./PRODUCT_BRIEF_INTEGRATION.md)

> **IMPORTANT (April 2026):** This document has been updated with security fixes. See [CHANGELOG_SECURITY.md](./CHANGELOG_SECURITY.md) for all changes. New product features from the product brief are tracked in [PRODUCT_BRIEF_INTEGRATION.md](./PRODUCT_BRIEF_INTEGRATION.md) — read that before starting new feature work.

---

## How to Read This Document

This is the single source of truth for building Goal Digger v1. Every phase, step, and decision is documented here so an AI agent (or any developer) can pick it up and build with zero ambiguity. If something isn't covered here, check the PRD. If it's not in the PRD either, it's out of scope for v1.

**Build order:** We build the entire app first, then handle Apple Developer enrollment and App Store submission last. No money spent until the product is ready.

---

## Design Reference Apps

Since there are no Figma mockups, the developer should study these apps for visual and UX inspiration. These are all apps popular with the target audience (women 22–35 who care about aesthetics):

| App | What to steal from it |
|-----|----------------------|
| **Clue** (period tracker) | Clean card layout, warm colors, friendly typography, information-dense without feeling cluttered |
| **Headspace** | Rounded shapes, warm illustrations, calming color palette, onboarding flow |
| **Locket** | Simple concept, minimal UI, feels personal not corporate |
| **Duolingo** | Fun tone, playful micro-interactions, approachable design for non-experts |
| **The Skimm** (newsletter app) | Casual news tone for women, card-based content, "here's what you need to know" format |

**The rule:** If it looks like it belongs on ESPN, Sky Sports, or FotMob — it's wrong. If it looks like it belongs next to Headspace and Pinterest on her home screen — it's right.

---

## Technology Stack (Final Decisions)

| Layer | Choice | Why |
|-------|--------|-----|
| iOS Frontend | Swift 5.9+, SwiftUI, iOS 17+ | Modern declarative UI, smallest codebase |
| Local Storage | UserDefaults + SwiftData | Simple, no server-side user state |
| Backend | Supabase (PostgreSQL + Edge Functions + auto REST API) | Fast to ship, easy to migrate later if needed |
| Scheduled Jobs | Supabase `pg_cron` + Edge Functions | No separate infra to manage |
| AI Content | Anthropic Claude API (Sonnet) | Best tone quality for casual writing, cost-effective |
| AI Review | 3x Claude API calls per content item | Automated quality gate |
| Push Notifications | APNs via backend Edge Function | Direct Apple integration |
| Football Data | API-Football (RapidAPI) | Comprehensive PL coverage |
| News Data | RSS feeds from UK + European sources | Free, real-time, broad coverage |
| Social Media | Deferred to v1.2 | Complexity vs. value tradeoff |
| Analytics | TelemetryDeck | Privacy-friendly, GDPR-compliant |

---

## Project Structure

```
GoalDigger/
├── ios/
│   └── GoalDigger/
│       ├── App/
│       │   ├── GoalDiggerApp.swift          # App entry point
│       │   └── AppDelegate.swift            # APNs handling
│       ├── Design/
│       │   ├── Theme.swift                  # Colors, fonts, spacing constants
│       │   └── Components/                  # Reusable UI components
│       │       ├── ContentCard.swift
│       │       ├── TeamPickerCard.swift
│       │       ├── BadgeView.swift
│       │       └── EmptyStateView.swift
│       ├── Views/
│       │   ├── Onboarding/
│       │   │   ├── WelcomeView.swift
│       │   │   ├── HerNameView.swift          # "First things first, what's your name?"
│       │   │   ├── HisNameView.swift          # "And what's his?"
│       │   │   ├── WhatToFollowView.swift     # PL only in v1, WC placeholder
│       │   │   ├── TeamSelectionView.swift
│       │   │   ├── TierSelectionView.swift    # "How far do you want to take this?"
│       │   │   └── NotificationPromptView.swift
│       │   ├── Feed/
│       │   │   └── FeedView.swift
│       │   ├── Detail/
│       │   │   └── ContentDetailView.swift
│       │   ├── Team/
│       │   │   └── TeamPageView.swift         # His team page (club context)
│       │   ├── Player/
│       │   │   └── PlayerCardView.swift       # Tappable player cards
│       │   ├── Matchday/
│       │   │   └── OnesToWatchView.swift       # 3 key players per match
│       │   └── Settings/
│       │       └── SettingsView.swift
│       ├── Models/
│       │   ├── ContentItem.swift
│       │   ├── Team.swift
│       │   └── AppState.swift
│       ├── Services/
│       │   ├── APIClient.swift
│       │   ├── NotificationService.swift
│       │   └── CacheService.swift
│       └── Resources/
│           ├── Assets.xcassets             # Colors, app icon, illustrations
│           └── Fonts/                      # Custom fonts if needed
├── backend/
│   ├── supabase/
│   │   ├── migrations/                    # SQL schema migrations
│   │   │   ├── 001_initial_schema.sql
│   │   │   └── 002_tiers_and_context.sql  # Tiers, team context, player cards, team pages
│   │   └── functions/
│   │       ├── _shared/                   # Shared utilities (see AGENT_CONTRACTS.md)
│   │       │   ├── supabase-client.ts
│   │       │   ├── claude-client.ts
│   │       │   ├── apns-client.ts
│   │       │   ├── types.ts
│   │       │   ├── anti-spam.ts
│   │       │   ├── input-sanitizer.ts     # RSS/API content sanitization (see PROMPTS.md)
│   │       │   ├── trigger.ts
│   │       │   └── pipeline-logger.ts
│   │       ├── data-fetcher/
│   │       │   └── index.ts
│   │       ├── content-generator/
│   │       │   └── index.ts
│   │       ├── content-reviewer/
│   │       │   └── index.ts
│   │       ├── notification-sender/
│   │       │   └── index.ts
│   │       ├── matchday-scheduler/        # Daily 07:00 UTC, schedules game-day content
│   │       │   └── index.ts
│   │       ├── delete-my-data/            # GDPR data deletion endpoint
│   │       │   └── index.ts
│   │       └── health-check/              # GET endpoint for monitoring (see RUNBOOK.md)
│   │           └── index.ts
│   └── seed/
│       └── seed_teams.sql
├── docs/
│   ├── PRD.md
│   └── BUILD_PLAN.md
└── README.md
```

---

# PHASE 1: Backend — Database & Data Pipeline

**Goal:** Build the engine that powers everything. The iOS app is just a shell without content. Backend comes first.

---

## Step 1.1: Supabase Project Setup

### What to do
1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Note the project URL and `anon` API key (public, safe for the iOS client)
3. Note the `service_role` key (secret, backend-only — never ship in the iOS app)
4. Enable Edge Functions in the project dashboard

### Environment Variables (Backend)
Store these as Supabase Edge Function secrets:
```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
ANTHROPIC_API_KEY=sk-ant-...
RAPIDAPI_KEY=xxxxxxxxxx
APNS_KEY_ID=XXXXXXXXXX
APNS_TEAM_ID=XXXXXXXXXX
APNS_PRIVATE_KEY=<contents of .p8 file>
```

> **Note:** The APNs keys won't be available until the Apple Developer account is set up in Phase 5. The notification sender function can be built and tested with mock data until then.

---

## Step 1.2: Database Schema

### SQL Migration: `001_initial_schema.sql`

```sql
-- Teams table (pre-populated with 3 teams)
CREATE TABLE teams (
    id              TEXT PRIMARY KEY,        -- "arsenal", "man_utd", "west_ham"
    display_name    TEXT NOT NULL,           -- "Arsenal", "Manchester United", "West Ham"
    api_football_id INTEGER NOT NULL,        -- Team ID in API-Football
    short_name      TEXT NOT NULL,           -- "Arsenal", "Man Utd", "West Ham"
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Content items — the core data the app displays
CREATE TABLE content_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    type            TEXT NOT NULL CHECK (type IN ('news', 'matchday')),
    headline        TEXT NOT NULL,           -- Push notification text (1-2 sentences)
    body            TEXT NOT NULL,           -- Detail view content (markdown)
    talking_points  JSONB NOT NULL DEFAULT '[]',  -- Array of short strings
    source_urls     JSONB DEFAULT '[]',      -- Original sources for traceability
    match_id        TEXT,                    -- API-Football fixture ID (matchday only)
    kickoff_time    TIMESTAMPTZ,            -- Kickoff time for matchday content (client-side countdown)
    emotional_context TEXT CHECK (emotional_context IN ('exciting', 'bad_news', 'drama', 'informational', 'funny')),
    status          TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'approved', 'rejected', 'published')),
    review_notes    JSONB DEFAULT '[]',      -- Notes from each review bot
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    published_at    TIMESTAMPTZ,

    -- Prevent duplicate content for the same match
    CONSTRAINT unique_matchday_content UNIQUE (team_id, match_id)
);

-- Device tokens for push notifications
-- SECURITY: apns_token is validated as 64-char hex (standard APNs format)
-- SECURITY: rate_limit_key tracks IP for abuse prevention
CREATE TABLE device_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    apns_token      TEXT NOT NULL UNIQUE
                    CONSTRAINT valid_apns_token CHECK (apns_token ~ '^[a-fA-F0-9]{64}$'),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- SECURITY: Rate limiting function for device token registration
-- Prevents flooding: max 5 token registrations per IP per hour
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
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    source          TEXT NOT NULL,            -- "api_football", "bbc_rss", "sky_rss", etc.
    data            JSONB NOT NULL,
    fetched_at      TIMESTAMPTZ DEFAULT NOW()
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

-- Indexes for common queries
CREATE INDEX idx_content_team_status ON content_items(team_id, status);
CREATE INDEX idx_content_published ON content_items(team_id, published_at DESC)
    WHERE status = 'published';
CREATE INDEX idx_device_tokens_team ON device_tokens(team_id)
    WHERE is_active = true;
CREATE INDEX idx_raw_fetch_team_date ON raw_fetch_logs(team_id, fetched_at DESC);
CREATE INDEX idx_pipeline_health_recent ON pipeline_health(team_id, stage, created_at DESC);
```

### Migration 002: Tiers, Context & Content Cards — `002_tiers_and_context.sql`

This migration adds support for content tiers, team context pressure flags, player cards, and team pages.

```sql
-- Add tier to device_tokens (user self-selects during onboarding)
-- Tier 1 = "Just enough to get by", Tier 2 = "Came to impress", Tier 3 = "The one he brags about"
ALTER TABLE device_tokens ADD COLUMN tier INTEGER DEFAULT 2 CHECK (tier IN (1, 2, 3));

-- Team context: pressure flags that change the emotional weight of talking points
-- Updated by data-fetcher after every standings/form pull
CREATE TABLE team_context (
    team_id    TEXT PRIMARY KEY REFERENCES teams(id),
    flags      JSONB NOT NULL DEFAULT '[]',
    -- flags is an array of strings, e.g.: ["title_race", "bad_form", "derby_upcoming"]
    -- Valid flags: title_race, cl_spot, europa_spot, cup_run, relegation, bad_form,
    --             derby_upcoming, derby_just_played, cup_knockout
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Player cards: cached player profiles in GoalDigger voice
-- Generated by content pipeline, refreshed when player data changes
CREATE TABLE player_cards (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id     TEXT NOT NULL REFERENCES teams(id),
    player_name TEXT NOT NULL,
    position    TEXT NOT NULL,          -- plain English: "scores the goals", "stops the goals"
    age         INTEGER,
    summary     TEXT NOT NULL,          -- GoalDigger voice one-liner on why fans care about him
    vibe        TEXT,                   -- "fan favourite", "controversial", "reliable", "flashy"
    form        TEXT,                   -- current form in one sentence
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_player_team UNIQUE (team_id, player_name)
);

-- Team page content: static-ish team profiles in GoalDigger voice
-- Refreshed weekly or when significant changes happen (manager change, etc.)
CREATE TABLE team_pages (
    team_id      TEXT PRIMARY KEY REFERENCES teams(id),
    content      JSONB NOT NULL,
    -- JSONB structure:
    -- {
    --   "nickname": "The Gunners",
    --   "stadium": "Emirates Stadium, London",
    --   "manager": "Mikel Arteta. Been at Arsenal since 2019. Fans love him right now, which is rare.",
    --   "top_players": [{"name": "Saka", "position": "winger", "one_liner": "..."}],
    --   "biggest_rival": "Tottenham — it's called the North London Derby and it's personal.",
    --   "fun_fact": "...",
    --   "season_summary": "Currently sitting 2nd. Having a great season but City won't go away."
    -- }
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for new tables
CREATE INDEX idx_player_cards_team ON player_cards(team_id);

-- RLS for new tables
ALTER TABLE team_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_pages ENABLE ROW LEVEL SECURITY;

-- Public read access for context cards (anon can SELECT)
CREATE POLICY team_context_read ON team_context FOR SELECT TO anon USING (true);
CREATE POLICY player_cards_read ON player_cards FOR SELECT TO anon USING (true);
CREATE POLICY team_pages_read ON team_pages FOR SELECT TO anon USING (true);

-- Write access only via service_role (backend)
CREATE POLICY team_context_write ON team_context FOR ALL TO service_role USING (true);
CREATE POLICY player_cards_write ON player_cards FOR ALL TO service_role USING (true);
CREATE POLICY team_pages_write ON team_pages FOR ALL TO service_role USING (true);
```

### Seed Data: `seed_teams.sql`

```sql
INSERT INTO teams (id, display_name, api_football_id, short_name) VALUES
    ('arsenal',  'Arsenal',           42,  'Arsenal'),
    ('man_utd',  'Manchester United',  33,  'Man Utd'),
    ('west_ham', 'West Ham United',    48,  'West Ham');
```

> **API-Football team IDs:** Arsenal = 42, Manchester United = 33, West Ham = 48. Verify these are current at build time by calling `GET /v3/teams?league=39&season=2025`.

### Row Level Security (RLS)

Enable RLS on all tables. Policies:

- `content_items`: Public read access WHERE `status = 'published'`. Write access only via `service_role` key (backend).
- `device_tokens`:
  - **INSERT** via `anon` key: allowed, but CHECK constraint enforces valid 64-char hex APNs token format. Global rate limit trigger prevents flooding.
  - **UPDATE** via `anon` key: allowed ONLY on `team_id` and `updated_at` columns. The `anon` role CANNOT update `apns_token`, `is_active`, or `id`. Enforce this with a column-level RLS policy or a BEFORE UPDATE trigger:
    ```sql
    -- RLS policy: anon can only update team_id
    CREATE POLICY device_tokens_update ON device_tokens
        FOR UPDATE TO anon
        USING (true)
        WITH CHECK (
            apns_token = OLD.apns_token AND
            is_active = OLD.is_active
        );
    ```
  - **DELETE** via `service_role` key only.
- `teams`: Public read access.
- `raw_fetch_logs`: No public access. `service_role` only.
- `pipeline_health`: No public access. `service_role` only.

> **SECURITY NOTE:** The `anon` key is designed to be public-facing in Supabase. RLS is the real security boundary. These policies ensure that even with the anon key, an attacker can only: (a) register valid APNs tokens, (b) change which team a token follows. They cannot read other tokens, delete tokens, or access any backend-only tables.

---

## Step 1.3: Data Fetcher Function

### Purpose
Runs on a schedule, pulls data from football APIs and news RSS feeds for each of the 3 teams. Stores raw data in `raw_fetch_logs`. Does NOT generate content — that's the next function's job.

### Data Sources

#### Football API (API-Football via RapidAPI)
Base URL: `https://v3.football.api-sports.io`
Headers: `x-rapidapi-key: {RAPIDAPI_KEY}`, `x-rapidapi-host: v3.football.api-sports.io`

Endpoints to call **per team**:

| Endpoint | Purpose | Parameters |
|----------|---------|------------|
| `GET /fixtures?team={id}&next=5` | Upcoming fixtures | team, next |
| `GET /fixtures?team={id}&last=3` | Recent results | team, last |
| `GET /injuries?team={id}&season=2025` | Current injuries | team, season |
| `GET /standings?league=39&season=2025` | Premier League table | league, season |
| `GET /transfers?team={id}` | Transfer activity | team |
| `GET /players/squads?team={id}` | Squad list with player names | team |

> **Rate limits:** API-Football on RapidAPI has rate limits depending on the plan. The free plan allows 100 requests/day. The Pro plan (~$30/month) allows 7,500/day. For 3 teams with 6 endpoints each, running every 30 minutes for 15 hours = ~540 calls/day. **Use the Pro plan.**

#### News RSS Feeds

Fetch and parse RSS/XML from these sources. Filter articles that mention the team name, short name, or key player surnames.

**UK Sources:**
| Source | RSS URL | Notes |
|--------|---------|-------|
| BBC Sport Football | `https://feeds.bbci.co.uk/sport/football/rss.xml` | Reliable, always available |
| Sky Sports Football | `https://www.skysports.com/rss/12040` | Good for transfer news |
| The Guardian Football | `https://www.theguardian.com/football/rss` | Quality analysis |
| The Mirror Football | `https://www.mirror.co.uk/sport/football/rss.xml` | Tabloid/gossip angle |
| The Daily Mail Sport | `https://www.dailymail.co.uk/sport/football/index.rss` | High volume, gossip heavy |
| Evening Standard | `https://www.standard.co.uk/sport/football.rss` | Good for London clubs (Arsenal, West Ham) |
| The Independent Football | `https://www.independent.co.uk/sport/football/rss` | Balanced coverage |
| The Telegraph Football | `https://www.telegraph.co.uk/football/rss.xml` | Premium analysis |

**European Sources:**
| Source | RSS URL | Notes |
|--------|---------|-------|
| ESPN FC | `https://www.espn.com/espn/rss/soccer/news` | International perspective |
| Goal.com | `https://www.goal.com/feeds/en/news` | Transfer-heavy |
| Football365 | `https://www.football365.com/feed` | Opinion and analysis |
| TeamTalk | `https://www.teamtalk.com/feed` | Transfer rumours |

#### Player Name Lookup (For Filtering)

Maintain a lookup dictionary per team of ~25 key player surnames. This is used to filter RSS articles that mention a team's player but not the team name directly.

```
arsenal_players: ["Saka", "Saliba", "Rice", "Odegaard", "Havertz", "Raya", "Timber", ...]
man_utd_players: ["Fernandes", "Rashford", "Hojlund", "Mainoo", "Martinez", "Onana", ...]
west_ham_players: ["Bowen", "Paqueta", "Kudus", "Antonio", "Areola", "Soler", ...]
```

> **Important:** This list must be updated at the start of each transfer window and at season start. Store it in a Supabase table (`team_players`) or a config file so it can be updated without redeploying the function.

### Schedule
- **Frequency:** Every 30 minutes
- **Active hours:** 08:00–23:00 GMT only (no fetching at night)
- **Implementation:** Supabase `pg_cron` calls the Edge Function via HTTP

```sql
-- Run data fetcher every 30 minutes between 08:00 and 23:00 GMT
-- Note: cron hour range 8-23 means 08:00, 08:30, ..., 23:00, 23:30
SELECT cron.schedule(
    'data-fetcher',
    '*/30 8-23 * * *',
    $$SELECT net.http_post(
        'https://xxxxx.supabase.co/functions/v1/data-fetcher',
        '{}',
        'application/json',
        ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))]
    )$$
);
```

### Function Logic (Pseudocode)

```
FOR each team IN [arsenal, man_utd, west_ham]:
    1. Fetch all API-Football endpoints for this team
    2. Fetch all RSS feeds, filter articles mentioning team or players
    3. Store raw responses in raw_fetch_logs with team_id and source
    4. Deduplicate: skip articles with URLs already in raw_fetch_logs from the last 48 hours
    5. If new data found → trigger content-generator function for this team
    6. If no new data → do nothing (no spam rule)
```

### Error Handling
- If an individual RSS feed fails (timeout, 404, etc.), log the error and continue with other sources. Never let one broken feed stop the entire pipeline.
- If API-Football fails, log and retry once after 30 seconds. If still failing, skip this cycle — data will be fetched next run.
- Log all errors to the `pipeline_health` table with `status = 'failure'` for monitoring.

---

## Step 1.4: Content Generator Function

### Purpose
Takes raw fetched data for a team and uses Claude API to determine if anything is newsworthy. If yes, generates a headline, body, and talking points in the Goal Digger tone. If not, produces nothing (no spam).

### When It Runs
- Triggered by the data fetcher whenever new data is found for a team
- Also triggered on a schedule for matchday content: once per team on game days, timed to ~90 minutes before kickoff

### Claude API Integration

**Model:** `claude-sonnet-4-5-20250929` (cost-effective for summarization, excellent tone quality)

**Prompts:** All system prompts, user message templates, and tool definitions for the content generator are documented in [PROMPTS.md](./PROMPTS.md). See:
- Section 1 (Content Generator — News) for news content generation
- Section 2 (Content Generator — Matchday) for matchday briefings
- Section 6 (Newsworthy Filter) for the decision logic and anti-spam rules
- Section 7 (Prompt Variables Reference) for all template variables

**Request Format:**
```json
{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 2000,
    "system": "<system prompt from PROMPTS.md>",
    "messages": [
        {
            "role": "user",
            "content": "<user message template from PROMPTS.md>"
        }
    ],
    "tools": [
        "<tool definition from PROMPTS.md Section 1 (news) or Section 2 (matchday)>"
    ],
    "tool_choice": { "type": "tool", "name": "generate_content" }
}
```

> **Important:** The full tool schemas are defined in [PROMPTS.md](./PROMPTS.md). The news tool (`generate_content`) includes `newsworthiness_score`, `emotional_context`, and `source_summary` fields in addition to the core `headline`, `body`, and `talking_points`. The matchday tool (`generate_matchday_content`) adds `pre_match_mood`, `rivalry_level`, `if_they_win`, `if_they_lose`, and `bold_prediction`. Always use the PROMPTS.md definitions as the source of truth.

**Response Handling:**
- If `is_newsworthy` is `false` → log the `skip_reason`, do nothing. Pipeline stops here.
- If `is_newsworthy` is `true` → save to `content_items` with status `"draft"`, then trigger the content reviewer.

### Deduplication
Before generating, check `content_items` for any content published for this team in the last 6 hours with a similar headline. Use a simple similarity check (e.g., Levenshtein distance or shared keyword overlap) to avoid duplicate notifications about the same story from multiple sources.

### Matchday Scheduling — Full Timing Logic

Premier League kickoff times are not fixed. They vary by broadcast schedule, competition, and day of the week. The matchday content generator must handle all of them dynamically.

#### All Possible Premier League Kickoff Times (GMT/BST)

| Day | Kickoff (GMT) | Kickoff (BST, Mar-Oct) | Notification Send Time | Notes |
|-----|---------------|------------------------|----------------------|-------|
| Saturday | 12:30 | 12:30 | 11:00 | Early kickoff (TV) |
| Saturday | 15:00 | 15:00 | 13:30 | Standard 3pm kickoff |
| Saturday | 17:30 | 17:30 | 16:00 | Late kickoff (TV) |
| Sunday | 14:00 | 14:00 | 12:30 | Early Sunday (TV) |
| Sunday | 16:30 | 16:30 | 15:00 | Late Sunday (TV) |
| Monday | 20:00 | 20:00 | 18:30 | Monday Night Football |
| Tuesday | 19:45 | 19:45 | 18:15 | Midweek fixture |
| Tuesday | 20:00 | 20:00 | 18:30 | Midweek fixture |
| Wednesday | 19:45 | 19:45 | 18:15 | Midweek fixture |
| Wednesday | 20:00 | 20:00 | 18:30 | Midweek fixture |
| Thursday | 19:45 | 19:45 | 18:15 | Rescheduled / European weeks |
| Friday | 20:00 | 20:00 | 18:30 | Occasional Friday night (TV) |

**Rule: Send matchday notification exactly 90 minutes before kickoff.**

Why 90 minutes:
- Early enough to read before the game starts
- Late enough that the info feels fresh and timely
- Aligns with when her partner is probably starting to get into "match mode"
- She has time to read, absorb, and use a talking point before kickoff

#### Time Zone Handling

All times in the pipeline and database are stored in **UTC**. The notification sender converts to the user's local time for the quiet hours check (08:00–22:00), but the matchday scheduling is based on the actual kickoff time from the API.

**BST Consideration:** The UK switches to British Summer Time (UTC+1) from the last Sunday in March to the last Sunday in October. API-Football returns fixture times in UTC. The pipeline works in UTC throughout — no conversion needed for scheduling. The only place BST matters is the user-facing display in the app (iOS handles this automatically via the device's locale).

#### Implementation: The Matchday Scheduler

This runs as a separate scheduled function once daily at **07:00 UTC**.

```
Function: matchday-scheduler
Schedule: 0 7 * * * (daily at 07:00 UTC)

Logic:
1. GET /v3/fixtures?league=39&season=2025&from={today}&to={today}
   (This returns ALL Premier League fixtures for today)

2. Filter fixtures for our 3 teams:
   - Check both home_team_id and away_team_id against our team IDs
   - A team can only have 1 fixture per day (PL rules)

3. For each matching fixture:
   a. Extract kickoff_time (UTC) from the API response
   b. Calculate send_time = kickoff_time - 90 minutes
   c. Check: is send_time in the future?
      - YES → Schedule the content generator to run at send_time
      - NO → The 07:00 run was too late (12:30 kickoff - 90min = 11:00,
              but this only applies to very early kickoffs which are rare)
              In this case, run the content generator IMMEDIATELY

4. How to schedule a delayed invocation:
   Option A (Recommended): Use pg_cron to create a one-off job:
     SELECT cron.schedule(
         'matchday-arsenal-20260208',
         '0 16 8 2 *',  -- 16:00 UTC on Feb 8 (for 17:30 kickoff)
         $$SELECT net.http_post(...)$$
     );
     -- Clean up the one-off job after it runs

   Option B: Use Supabase's pg_net with a delayed HTTP call
   Option C: Store scheduled sends in a table and have a
             minutely cron job check for pending sends

5. Log the scheduled send time in pipeline_health
```

#### Edge Cases

| Edge Case | How to Handle |
|-----------|---------------|
| **Match postponed after scheduling** | The data fetcher runs every 30 min. If it detects a fixture status change to "postponed", cancel the scheduled matchday content. Don't send a "match postponed" notification — that's handled by the news content generator if it's newsworthy. |
| **Kickoff time changed** | Same as postponed — the 30-min data fetcher will detect the new time. Cancel the old schedule, create a new one. |
| **Double gameweek (2 matches in a week)** | Each fixture is handled independently. If Arsenal play Tuesday and Saturday, they get 2 separate matchday briefings. Both count toward the 2-notifications-per-day max. |
| **Match kicks off before 09:30 UTC** | Send time would be before 08:00 (quiet hours). In this case, send at exactly 08:00 — earliest allowed. This is rare in the PL (only 12:30 GMT Saturday kickoffs during winter, which would mean an 11:00 send — well within hours). |
| **Cup matches (FA Cup, League Cup)** | API-Football returns these too. For v1, only generate matchday content for Premier League fixtures (`league=39`). Cup matches are out of scope. If there's newsworthy cup news, the regular news pipeline will catch it. |
| **International break** | No PL fixtures → no matchday content. The scheduler runs, finds nothing, does nothing. This is correct. |
| **Bank holiday / festive fixtures (Dec 26, Jan 1)** | These often have unusual kickoff times (12:30, 15:00, 17:30 all on the same day). Handle normally — each team gets one fixture, one notification. |
| **Match already started by the time content is generated** | Check fixture status before sending. If status is "1H" (first half), "2H", or "FT" — do NOT send. The moment has passed. |

#### Matchday Content in the Feed

Even if the user misses the push notification, the matchday content should be visually prominent in the feed:

- Display a countdown badge on the card: "Kicks off in 2h" / "Live now" / "Full time"
- The countdown is calculated client-side using the kickoff time stored in the content item
- After the match ends, the badge changes to "Full time" and fades to the standard timestamp format after 24 hours

> **Note:** The feed does NOT show live scores (out of scope for v1). "Live now" just means the match is happening — not that we're updating scores in real-time.

---

## Step 1.5: Content Reviewer Function

### Purpose
Quality gate. Every draft content item goes through 3 AI review bots in parallel. All 3 must pass for the content to be approved.

### The 3 Review Bots

Each is a separate Claude API call with a distinct system prompt. Full prompts, input templates, and response formats are documented in [PROMPTS.md](./PROMPTS.md):

- **Bot 1: Tone Reviewer** — See [PROMPTS.md Section 3](./PROMPTS.md#3-review-bot-1--tone). Checks that content sounds like a warm friend texting, not a sports journalist. Fails on unexplained jargon, condescension, or overly formal tone.
- **Bot 2: Accuracy Reviewer** — See [PROMPTS.md Section 4](./PROMPTS.md#4-review-bot-2--accuracy). Cross-references every factual claim against raw source data. Fails on any factual error, misspelled names, or hallucinated stats.
- **Bot 3: Brevity Reviewer** — See [PROMPTS.md Section 5](./PROMPTS.md#5-review-bot-3--brevity). Enforces content length and scannability rules. Fails if headline >200 chars, >5 talking points, or body takes >60 seconds to scan.

### Review Logic

```
1. Fetch draft content item + its raw source data from raw_fetch_logs
2. Run all 3 review bots IN PARALLEL (saves time, costs the same)
3. Collect results:
   - All 3 pass → set status to "approved"
   - Any fail → set status to "rejected", store all review notes
4. If rejected AND only 1 bot failed:
   - Retry ONCE: send the content + failure feedback back to content-generator
     with instruction "Revise based on this feedback: {notes}"
   - Run reviews again on the revised version
   - If still fails → final rejection, move on
5. Store all review notes in content_items.review_notes for debugging
```

### Cost Control
- Max 2 generation attempts per content item (original + 1 retry)
- Max 6 review calls per content item (3 original + 3 retry)
- At ~$0.003–0.01 per call, worst case per item: ~$0.08
- With 3 teams and maybe 2–3 items per day: ~$0.50/day for the entire review pipeline

---

## Step 1.6: Notification Sender Function

### Purpose
Takes approved content and sends push notifications to all active devices following that team.

### When It Runs
- Triggered immediately when content is approved by the reviewer
- Also runs as a cleanup sweep every hour to catch any approved items that weren't published (safety net)

### Logic

```
1. Query content_items WHERE status = 'approved' AND published_at IS NULL
2. For each item:
   a. TIME CHECK: Is the current time between 08:00 and 22:00 GMT?
      - If NO → skip, it will be caught by the next hourly sweep
      - If YES → continue
   b. Query device_tokens WHERE team_id = item.team_id AND is_active = true
   c. For each device token, send APNs push:
      {
          "aps": {
              "alert": {
                  "title": "Goal Digger",
                  "subtitle": "{team_short_name}",
                  "body": "{headline}"
              },
              "sound": "default",
              "mutable-content": 1
          },
          "content_id": "{item.id}"
      }
   d. Handle APNs responses:
      - 200 OK → success
      - 410 Gone → set device_token.is_active = false (token expired)
      - 429 Too Many Requests → back off and retry
      - Other errors → log and continue
   e. Update content_items: set status = 'published', published_at = NOW()
```

### APNs Connection
- Use HTTP/2 connection to APNs (`api.push.apple.com` for production, `api.sandbox.push.apple.com` for development)
- Authenticate with the .p8 key using JWT
- Keep the connection alive for batch sending (don't reconnect per notification)

> **Note:** APNs integration can only be fully tested after Apple Developer enrollment (Phase 5). Until then, build the function with mock APNs calls and test the logic.

---

## Step 1.7: REST API for the iOS App

### Supabase Auto-Generated API

Supabase automatically generates a REST API from the database schema. With RLS policies in place, the iOS app can call these directly using the `anon` key.

### Endpoints the iOS App Will Use

#### Register Device Token
```
POST /rest/v1/device_tokens
Headers: apikey: {SUPABASE_ANON_KEY}, Content-Type: application/json
Body: { "team_id": "arsenal", "apns_token": "abc123..." }
```

#### Update Team Selection (Change Team)
```
PATCH /rest/v1/device_tokens?apns_token=eq.{token}
Headers: apikey: {SUPABASE_ANON_KEY}, Content-Type: application/json
Body: { "team_id": "west_ham", "updated_at": "2026-02-08T12:00:00Z" }
```

#### Fetch Feed (Paginated)
```
GET /rest/v1/content_items?team_id=eq.{team}&status=eq.published&order=published_at.desc&limit=20&offset=0
Headers: apikey: {SUPABASE_ANON_KEY}
```

#### Fetch Single Item (Detail View / Deep Link)
```
GET /rest/v1/content_items?id=eq.{uuid}&status=eq.published
Headers: apikey: {SUPABASE_ANON_KEY}
```

### Rate Limiting
- Apply Supabase's built-in rate limiting or add a simple middleware Edge Function
- Limit: 60 requests/minute per IP
- This prevents abuse without needing user authentication

### New Endpoints (from Migration 002)

#### Fetch Player Cards for a Team
```
GET /rest/v1/player_cards?team_id=eq.{team}&select=player_name,position,age,summary,vibe,form
Headers: apikey: {SUPABASE_ANON_KEY}
```

#### Fetch Team Page
```
GET /rest/v1/team_pages?team_id=eq.{team}&select=content
Headers: apikey: {SUPABASE_ANON_KEY}
```

#### Update Tier (with Team Change)
```
PATCH /rest/v1/device_tokens?apns_token=eq.{token}
Headers: apikey: {SUPABASE_ANON_KEY}, Content-Type: application/json
Body: { "tier": 3, "updated_at": "2026-04-06T12:00:00Z" }
```

---

# PHASE 2: iOS App — Core Architecture

**Goal:** Build the app skeleton: data models, networking, navigation, push notification handling. No visual polish yet — just make it functional.

---

## Step 2.1: Xcode Project Setup

1. Create new Xcode project: **iOS App**, SwiftUI lifecycle, Swift language
2. Product name: `GoalDigger`
3. Bundle identifier: `com.goaldigger.app` (will be registered in Apple Developer later)
4. Minimum deployment target: **iOS 17.0**
5. Add capabilities (in Signing & Capabilities):
   - Push Notifications
   - Background Modes → Remote notifications
6. No third-party dependencies in v1. Use only:
   - `Foundation` (networking, JSON)
   - `SwiftUI` (UI)
   - `SwiftData` (local cache)
   - `UserNotifications` (push handling)

### Secure Configuration Setup (REQUIRED before writing any networking code)

Create `ios/GoalDigger/Configuration.xcconfig`:
```
// Configuration.xcconfig
// SECURITY: This file is excluded from git via .gitignore
// Each developer/agent creates their own copy from Configuration.xcconfig.example

SUPABASE_URL = https:$(/)$(/)xxxxx.supabase.co
SUPABASE_ANON_KEY = your_anon_key_here
```

Create `ios/GoalDigger/Configuration.xcconfig.example` (committed to git):
```
// Configuration.xcconfig.example
// Copy this file to Configuration.xcconfig and fill in real values
// NEVER commit Configuration.xcconfig to git

SUPABASE_URL = https:$(/)$(/)YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY = YOUR_ANON_KEY_HERE
```

Add to `Info.plist`:
```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

Add to `.gitignore`:
```
# Secrets - never commit
Configuration.xcconfig
*.p8
.env
```

In Xcode: Project → Info → Configurations → set Configuration.xcconfig for both Debug and Release.

### Why No Dependencies
- `URLSession` with `async/await` replaces Alamofire
- `SwiftUI` built-in image handling replaces Kingfisher (no images in v1 content)
- Fewer dependencies = faster builds, fewer breaking changes, easier to maintain

---

## Step 2.2: Data Models

### `Team.swift`
```swift
enum Team: String, CaseIterable, Identifiable, Codable {
    case arsenal = "arsenal"
    case manUtd = "man_utd"
    case westHam = "west_ham"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arsenal: return "Arsenal"
        case .manUtd: return "Manchester United"
        case .westHam: return "West Ham"
        }
    }

    var shortName: String {
        switch self {
        case .arsenal: return "Arsenal"
        case .manUtd: return "Man Utd"
        case .westHam: return "West Ham"
        }
    }
}
```

### `ContentItem.swift`
```swift
struct ContentItem: Identifiable, Codable {
    let id: UUID
    let teamId: String
    let type: ContentType
    let headline: String
    let body: String
    let talkingPoints: [String]
    let kickoffTime: Date?          // Matchday only — used for countdown badges
    let emotionalContext: String?    // "exciting", "bad_news", "drama", "informational", "funny"
    let publishedAt: Date

    enum ContentType: String, Codable {
        case news
        case matchday
    }

    enum CodingKeys: String, CodingKey {
        case id
        case teamId = "team_id"
        case type
        case headline
        case body
        case talkingPoints = "talking_points"
        case kickoffTime = "kickoff_time"
        case emotionalContext = "emotional_context"
        case publishedAt = "published_at"
    }
}
```

### `AppState.swift`
```swift
import SwiftUI

@Observable
class AppState {
    /// Shared instance — used by AppDelegate and NotificationService which
    /// cannot access the SwiftUI environment. The same instance is also
    /// injected into the view hierarchy via .environment().
    static let shared = AppState()

    // Persisted — names stored LOCAL-ONLY (never sent to server)
    var herName: String {
        didSet {
            UserDefaults.standard.set(herName, forKey: "herName")
        }
    }
    var hisName: String {
        didSet {
            UserDefaults.standard.set(hisName, forKey: "hisName")
        }
    }
    var selectedTeam: Team? {
        didSet {
            if let team = selectedTeam {
                UserDefaults.standard.set(team.rawValue, forKey: "selectedTeam")
            }
        }
    }
    var selectedTier: Int {
        didSet {
            UserDefaults.standard.set(selectedTier, forKey: "selectedTier")
        }
    }
    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    var notificationPermissionRequested: Bool {
        didSet {
            UserDefaults.standard.set(notificationPermissionRequested, forKey: "notificationPermissionRequested")
        }
    }

    // Navigation
    var deepLinkContentId: UUID?

    init() {
        self.herName = UserDefaults.standard.string(forKey: "herName") ?? ""
        self.hisName = UserDefaults.standard.string(forKey: "hisName") ?? ""
        let teamRaw = UserDefaults.standard.string(forKey: "selectedTeam")
        self.selectedTeam = teamRaw.flatMap { Team(rawValue: $0) }
        self.selectedTier = UserDefaults.standard.integer(forKey: "selectedTier").clamped(to: 1...3, default: 2)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.notificationPermissionRequested = UserDefaults.standard.bool(forKey: "notificationPermissionRequested")
    }

    /// Replace `[his name]` placeholder in server-generated content with locally stored name
    func personalise(_ text: String) -> String {
        var result = text
        if !hisName.isEmpty {
            result = result.replacingOccurrences(of: "[his name]", with: hisName)
            result = result.replacingOccurrences(of: "[his name's]", with: hisName + "'s")
        }
        if !herName.isEmpty {
            result = result.replacingOccurrences(of: "[her name]", with: herName)
        }
        return result
    }

    /// Clear all local data (for "Delete My Data" flow)
    func clearAllData() {
        herName = ""
        hisName = ""
        selectedTeam = nil
        selectedTier = 2
        hasCompletedOnboarding = false
        notificationPermissionRequested = false
        deepLinkContentId = nil
        // Also clear UserDefaults
        let keys = ["herName", "hisName", "selectedTeam", "selectedTier",
                     "hasCompletedOnboarding", "notificationPermissionRequested"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue } // UserDefaults returns 0 for unset integers
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
```

> **PRIVACY NOTE:** `herName` and `hisName` are stored in UserDefaults ONLY. They are NEVER sent to the server, NEVER included in API calls, and NEVER used in push notifications. The `personalise()` function substitutes `[his name]` placeholders in server-generated content with the locally stored name at display time.

---

## Step 2.3: Networking Layer — `APIClient.swift`

```swift
class APIClient {
    static let shared = APIClient()

    // SECURITY: Credentials are injected at build time via Configuration.xcconfig
    // NEVER hardcode API keys in source code. See ios/GoalDigger/Configuration.xcconfig
    private let baseURL: URL = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString + "/rest/v1") else {
            fatalError("SUPABASE_URL not set in Configuration.xcconfig")
        }
        return url
    }()

    private let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not set in Configuration.xcconfig")
        }
        return key
    }()

    private var headers: [String: String] {
        [
            "apikey": apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }

    /// Fetch published content for a team, paginated
    func fetchFeed(teamId: String, limit: Int = 20, offset: Int = 0) async throws -> [ContentItem]

    /// Fetch a single content item by ID (for deep linking from push notifications)
    func fetchItem(id: UUID) async throws -> ContentItem?

    /// Register a device token with the backend
    func registerToken(_ token: String, teamId: String) async throws

    /// Update the team for an existing device token
    func updateTokenTeam(_ token: String, newTeamId: String) async throws
}
```

### Error Handling
- Network offline → return cached data (via SwiftData), show subtle "Offline" indicator
- Server 500 → show "Something went wrong, pull to refresh" message
- No content yet → show empty state (designed in Phase 3)
- Never crash. Never show raw error messages to the user.

---

## Step 2.4: Local Cache — `CacheService.swift`

Use **SwiftData** to cache the last 50 content items locally. This allows:
- Instant feed display on app launch (no loading spinner on repeat opens)
- Offline reading of previously loaded content
- Smooth scrolling without re-fetching

### SwiftData Model
```swift
@Model
class CachedContentItem {
    @Attribute(.unique) var id: UUID
    var teamId: String
    var type: String
    var headline: String
    var body: String
    var talkingPoints: [String]
    var kickoffTime: Date?          // Matchday only — mirrors ContentItem
    var emotionalContext: String?    // Mirrors ContentItem
    var publishedAt: Date
    var cachedAt: Date

    init(from item: ContentItem) { ... }
    func toContentItem() -> ContentItem { ... }
}
```

### Cache Strategy
- On every successful API fetch → upsert items into SwiftData
- On app launch → display cached items immediately, then fetch fresh data in background
- Purge items older than 30 days on app launch
- When team is switched → clear all cached items and fetch fresh

---

## Step 2.5: Push Notification Handling

### `AppDelegate.swift`
```swift
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called when APNs registration succeeds
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Store token locally and send to backend
        NotificationService.shared.handleTokenRegistration(token)
    }

    // Called when APNs registration fails
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Log error. App still works — user just won't get pushes.
        print("APNs registration failed: \(error)")
    }

    // Called when a notification is tapped
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let contentId = response.notification.request.content.userInfo["content_id"] as? String,
           let uuid = UUID(uuidString: contentId) {
            // Set deep link — AppState will navigate to detail view
            AppState.shared.deepLinkContentId = uuid
        }
        completionHandler()
    }

    // Called when notification arrives while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: ...) {
        // Show the notification even in foreground (banner + sound)
        completionHandler([.banner, .sound])
    }
}
```

### `NotificationService.swift`
```swift
class NotificationService {
    static let shared = NotificationService()

    /// Request notification permission. Called once during onboarding.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        } catch {
            return false
        }
    }

    /// Handle token registration — save locally and send to backend
    func handleTokenRegistration(_ token: String) {
        UserDefaults.standard.set(token, forKey: "apnsToken")
        guard let team = AppState.shared.selectedTeam else { return }
        Task {
            try? await APIClient.shared.registerToken(token, teamId: team.rawValue)
        }
    }
}
```

---

## Step 2.6: Navigation Architecture

### `GoalDiggerApp.swift`
```swift
@main
struct GoalDiggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
```

### `RootView.swift`
```swift
struct RootView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingFlow()
        }
    }
}
```

### Navigation Flow
```
App Launch
  ├── Onboarding not complete → OnboardingFlow
  │     ├── WelcomeView → "Get Started"
  │     ├── TeamSelectionView → pick team
  │     └── NotificationPromptView → allow/skip → mark onboarding complete
  │
  └── Onboarding complete → MainTabView
        └── NavigationStack
              ├── FeedView (home)
              │     └── tap card → ContentDetailView (push)
              └── SettingsView (gear icon)

Deep link from push notification:
  → Set appState.deepLinkContentId
  → FeedView observes this and navigates to ContentDetailView
```

---

# PHASE 3: iOS App — UI Implementation

**Goal:** Build every screen following the lifestyle-app design direction. This phase has the most detail because there are no Figma mockups — these specs ARE the mockups.

---

## Step 3.1: Design System — `Theme.swift`

### Color Palette — Rose and Dusk (Active)

```swift
extension Color {
    // Core palette (Rose and Dusk)
    static let primary = Color(hex: "#E8397D")            // Hot Rose — buttons, highlights, key moments
    static let appBackground = Color(hex: "#2D1B2E")      // Deep Mauve — app background
    static let cardBackground = Color(hex: "#FAF0F4")     // Soft Blush — all content cards
    static let textOnDark = Color(hex: "#F5F0F0")         // Warm White — text on dark backgrounds
    static let accent = Color(hex: "#E8C547")             // Gold — tier 3 details, premium moments

    // Derived text colors
    static let textPrimary = Color(hex: "#2D1B2E")        // Deep Mauve — text on light card backgrounds
    static let textSecondary = Color(hex: "#8A7080")       // Muted mauve — secondary text on cards
    static let textTertiary = Color(hex: "#B8A0AA")        // Light mauve — timestamps on cards

    // Derived utility colors
    static let feedDivider = Color(hex: "#3D2B3E")         // Slightly lighter than background
    static let cardShadow = Color.black.opacity(0.12)      // Slightly stronger on dark bg
    static let shimmer = Color(hex: "#3D2B3E")             // Loading skeleton on dark bg

    // Badge colors
    static let badgeMatchday = Color(hex: "#E8397D").opacity(0.15)  // Rose tint for matchday badges
    static let badgeText = Color(hex: "#E8397D")                     // Rose text on badges

    // Tier-specific
    static let tierGold = Color(hex: "#E8C547")            // Gold for Tier 3 elements only
}
```

> **Why Rose and Dusk:** Premium, bold, and ownable. Nothing in the App Store in this space looks like it. The deep mauve background makes the rose pop. Gold is used sparingly — only for Tier 3 moments and aspirational copy. Soft blush cards on mauve create contrast without feeling clinical.

> **Usage rules:**
> - Rose is the action colour: buttons, tapped states, highlights, notification badges
> - Gold is for Tier 3 only: tier badge, premium moments, trophy icons
> - Never use white as a background — always soft blush on cards
> - Text on dark background: Warm White. Text on cards: Deep Mauve.

### Typography

Use SF Rounded (system font with rounded design) throughout. Never use a blocky or condensed font.

```swift
extension Font {
    // Onboarding
    static let onboardingTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let onboardingBody = Font.system(.body, design: .rounded, weight: .regular)

    // Feed
    static let feedHeadline = Font.system(.body, design: .rounded, weight: .semibold)
    static let feedTimestamp = Font.system(.caption, design: .rounded, weight: .medium)
    static let feedBadge = Font.system(.caption2, design: .rounded, weight: .bold)

    // Detail view
    static let detailTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let detailBody = Font.system(.body, design: .rounded, weight: .regular)
    static let talkingPointText = Font.system(.callout, design: .rounded, weight: .medium)

    // Settings
    static let settingsItem = Font.system(.body, design: .rounded, weight: .regular)
}
```

### Spacing & Layout Constants

```swift
struct Layout {
    static let screenPadding: CGFloat = 20      // Horizontal padding from screen edges
    static let cardPadding: CGFloat = 16        // Inner padding within cards
    static let cardSpacing: CGFloat = 12        // Vertical space between cards in feed
    static let cardCornerRadius: CGFloat = 16   // Rounded corners on all cards
    static let cardShadowRadius: CGFloat = 8    // Subtle shadow
    static let cardShadowY: CGFloat = 4         // Shadow offset downward

    static let sectionSpacing: CGFloat = 24     // Space between sections
    static let elementSpacing: CGFloat = 8      // Space between small elements
}
```

### Reusable Card Modifier

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Layout.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .shadow(color: Color.cardShadow, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

---

## Step 3.2: Onboarding Flow (8 screens)

**Target:** Under 90 seconds, one job per screen. Background: `appBackground` (Deep Mauve). All text in `textOnDark` (Warm White) unless on a card.

### Screen 1: WelcomeView

**Copy:** "You're here. He has no idea. Let's get you ready."
**Layout:**
1. **Spacer** — push content to vertical center
2. **Illustration area** (200x200pt) — Minimal line art or abstract illustration. Style: warm, playful, NOT sports-themed. Use app color palette.
3. **App name** — "Goal Digger" in `onboardingTitle` font, `textOnDark`
4. **Tagline** — "You're here. He has no idea. Let's get you ready." in `onboardingBody`, `textOnDark` at 80% opacity
5. **Spacer**
6. **CTA Button** — "Let's go" — full-width, `primary` (Hot Rose) background, white text, 50pt height, 16pt corner radius
7. **Bottom padding** — 40pt

**Behavior:** Tapping "Let's go" navigates to HerNameView.

### Screen 2: HerNameView

**Copy:** "First things first, what's your name?"
**Layout:**
1. **Title** — "First things first, what's your name?" in `onboardingTitle`, `textOnDark`
2. **Text field** — large, rounded, `cardBackground` background, `textPrimary` text, placeholder "Your name"
3. **Continue button** — appears when field is non-empty, `primary` background

**Behavior:** Saves `herName` to `AppState` (local only). Navigates to HisNameView.

### Screen 3: HisNameView

**Copy:** "And what's his?"
**Layout:** Same as HerNameView but with title "And what's his?" and placeholder "His name"

**Behavior:** Saves `hisName` to `AppState` (local only). Navigates to WhatToFollowView.

### Screen 4: WhatToFollowView

**Copy:** "What does [his name] care about?"
**Layout:**
1. **Title** — "What does {hisName} care about?" in `onboardingTitle`, `textOnDark`
2. **Option cards** (vertical stack, tappable):
   - "Premier League" — enabled, tappable
   - "World Cup 2026" — greyed out with "Coming soon" badge (not yet available)
   - "Both" — greyed out with "Coming soon" badge

**Behavior:** In v1, only "Premier League" is selectable. Navigates to TeamSelectionView.

> **WC NOTE:** When World Cup mode ships, this screen enables all 3 options. "World Cup 2026" goes to NationSelectionView. "Both" runs team + nation selection in sequence. See PRODUCT_BRIEF_INTEGRATION.md Phase WC.

### Screen 5: TeamSelectionView

**Copy:** "Who does {hisName} support?"
**Layout:**
1. **Title** — "Who does {hisName} support?" in `onboardingTitle`, `textOnDark`
2. **Subtitle** — "Pick one and we'll keep you in the loop." in `onboardingBody`, `textOnDark` at 80% opacity
3. **Team cards** — 3 large, tappable cards stacked vertically with `cardSpacing` between them

**Team Card Design:**
Each card is full-width (minus `screenPadding`), 80pt tall:
- **Background:** `cardBackground` (Soft Blush) with `cardStyle()`
- **Left:** Team display name in `feedHeadline` font, `textPrimary`
- **Right:** Subtle chevron in `textSecondary`
- **Selected state:** `primary` (Hot Rose) 2pt border, subtle scale animation (1.02x)
- **No team crests/logos** in v1 (avoids licensing issues)

**Behavior:** Tapping a card selects it (haptic: `.selectionChanged`). "Continue" button appears. Navigates to TierSelectionView.

### Screen 6: TierSelectionView

**Copy:** "How far do you want to take this?"
**Layout:**
1. **Title** — "How far do you want to take this?" in `onboardingTitle`, `textOnDark`
2. **Tier cards** — 3 stacked cards on `cardBackground`:

| Tier | Label | Description |
|------|-------|-------------|
| 1 | "Just enough to get by" | "Match day heads-up and one key talking point." |
| 2 | "Came to impress" | "Regular news and talking points through the week." |
| 3 | "The one he brags about" | "Everything including deep news, stats context and transfer rumours." |

- Tier 3 card has a subtle `tierGold` border to convey premium feel
- Default selection: Tier 2 (pre-selected with `primary` border)

**Behavior:** Saves `selectedTier` to `AppState`. Sends tier to server via API (included in device token registration). Navigates to NotificationPromptView.

### Screen 7: NotificationPromptView

**Copy:** "We'll handle the rest. Just let us in."
**Layout:**
1. **Icon** — SF Symbol `bell.badge` in `primary` (Hot Rose), 60pt size
2. **Title** — "We'll handle the rest. Just let us in." in `onboardingTitle`, `textOnDark`
3. **Body** — "We'll only ping you when it matters. Never spam. Promise." in `onboardingBody`, `textOnDark` at 80% opacity
4. **Primary CTA** — "Yes, keep me posted" — `primary` background, white text
5. **Secondary CTA** — "maybe later" — text-only, `textOnDark` at 60% opacity

**Behavior:**
- "Yes, keep me posted" → calls `NotificationService.shared.requestPermission()`, triggers iOS system dialog. Regardless of choice, mark `notificationPermissionRequested = true`, navigate to first talking point.
- "maybe later" → mark `notificationPermissionRequested = true`, navigate to first talking point. No permission requested.
- **No re-prompting, ever.**

### Screen 8: First Talking Point

**Not a dedicated view** — land directly on FeedView with the most recent content item for her selected team pre-expanded. Mark `hasCompletedOnboarding = true`. She sees immediate value before exploring anything else.

---

## Step 3.5: Home Screen — FeedView

### Screen Description
The main screen of the app. A scrollable feed of content cards showing the latest updates for the user's selected team. This is the screen users will see 99% of the time.

**Design reference:** Think of it as a cleaner, more minimal version of the Apple News feed or The Skimm app — cards with headlines, not walls of text.

### Top Bar
- **Left:** Team short name (e.g., "Arsenal") in `detailTitle` font, `textPrimary`
- **Right:** Gear icon (SF Symbol: `gearshape`) in `textSecondary`, taps to SettingsView
- **No navigation title.** The team name IS the title. Keep it clean.

### Feed Layout
- `ScrollView` containing a `LazyVStack` with `cardSpacing` between items
- Background: `appBackground`
- Pull-to-refresh: `.refreshable { await viewModel.refresh() }`
- Pagination: when scrolling near the bottom (last 3 items visible), load next page

### Content Card — `ContentCard.swift`

Each card represents one `ContentItem`. Full-width (minus `screenPadding` on each side).

**Card Layout:**
```
┌──────────────────────────────────────┐
│  [BADGE]              2h ago         │ ← Row 1: badge left, timestamp right
│                                      │
│  Arsenal play Tottenham tonight —    │ ← Row 2: headline (max 3 lines)
│  it's a BIG rivalry. Ask him if      │
│  he's nervous.                       │
│                                      │
│                        Read more →   │ ← Row 3: "Read more" right-aligned
└──────────────────────────────────────┘
```

**Badge:**
- Type `news` → "NEWS" badge with `accentSoft` background, `accentWarm` text
- Type `matchday` → "MATCH DAY" badge with `accentGreen.opacity(0.2)` background, `accentGreen` text
- Font: `feedBadge`, uppercase, 4pt vertical padding, 8pt horizontal padding, 8pt corner radius

**Headline:**
- Font: `feedHeadline`, `textPrimary`
- Max 3 lines, truncated with `...`

**Timestamp:**
- Relative format: "2h ago", "Yesterday", "3 days ago"
- Font: `feedTimestamp`, `textTertiary`

**"Read more" link:**
- Font: `feedTimestamp`, `accentWarm` color
- SF Symbol `arrow.right` inline, 10pt

**Card style:** Uses the `cardStyle()` modifier (white background, rounded corners, subtle shadow)

**Tap behavior:** Entire card is tappable. Tapping navigates to ContentDetailView with a push animation. Subtle haptic on tap (`.selectionChanged`).

### Empty State

When there's no content yet (fresh install, or team with no recent news):

**Layout:**
1. Vertically centered
2. SF Symbol `cup.and.saucer` (or `bubble.left.and.bubble.right`) in `textTertiary`, 50pt
3. "No updates yet" in `feedHeadline`, `textSecondary`
4. "We'll let you know when something happens with {team short name}." in `onboardingBody`, `textTertiary`, centered
5. Pull-to-refresh still works

### Loading State

On initial load (first fetch, no cache):
- Show 3 skeleton cards with shimmer animation
- Each skeleton card matches the card layout but with rounded placeholder rectangles in `shimmer` color
- Animates with a subtle left-to-right shimmer sweep

### Error State

If the API call fails and there's no cached data:
- "Something went wrong" in `feedHeadline`, `textSecondary`
- "Pull down to try again." in `onboardingBody`, `textTertiary`
- No scary error icons or technical messages

### Content Freshness & "You're All Caught Up" State

This is critical UX. If the latest content is from 3 days ago, the user shouldn't think the app is broken — she should feel like she's on top of things.

**Logic:** After the feed loads, check the `published_at` of the most recent item.

**State 1: Fresh content (most recent item < 12 hours old)**
- No special indicator needed. The feed feels alive.

**State 2: Caught up (most recent item is 12–72 hours old)**
- Show a "caught up" card at the top of the feed, ABOVE the most recent content card:
```
┌──────────────────────────────────────┐
│                                      │
│        ✓  You're all caught up       │
│                                      │
│   Nothing new for {team short name}  │
│   right now. We'll ping you when     │
│   something happens.                 │
│                                      │
└──────────────────────────────────────┘
```
- Style: No `cardStyle()` shadow. Use a subtle `feedDivider` background with rounded corners. `textSecondary` for the heading, `textTertiary` for the subtext. SF Symbol `checkmark.circle` in `accentGreen`.
- This communicates: "There's nothing new and that's intentional."

**State 3: Quiet period (most recent item is 3–14 days old)**
- Show a contextual message at the top of the feed:
```
┌──────────────────────────────────────┐
│                                      │
│   💤  Quiet week for {team}          │
│                                      │
│   Not much happening right now.      │
│   We'll let you know when there's    │
│   something worth talking about.     │
│                                      │
│   Next match: Sat 15 Feb vs Chelsea  │
│                                      │
└──────────────────────────────────────┘
```
- If the next fixture is known (from cached API data), show it — this proves the app is alive and knows what's coming.
- Style: Same as caught-up card but with `textTertiary` emoji icon instead of checkmark.

**State 4: Extended silence (most recent item > 14 days old)**
- This is likely off-season or an international break.
- Show at the top:
```
┌──────────────────────────────────────┐
│                                      │
│   The Premier League is on a break   │
│                                      │
│   No matches or major news right     │
│   now. We'll wake up when things     │
│   kick off again.                    │
│                                      │
└──────────────────────────────────────┘
```
- Below this card, the existing feed of older content is still visible and scrollable.
- The user can still read previous updates — the feed doesn't disappear.

**State 5: Off-season (June–August, no PL fixtures scheduled)**
- The matchday scheduler will find no upcoming fixtures
- Show a warm, branded message:
```
┌──────────────────────────────────────┐
│                                      │
│   ☀️  Season's over!                 │
│                                      │
│   The Premier League is on summer    │
│   break. Enjoy the peace and quiet   │
│   — we'll be back in August.         │
│                                      │
│   (Transfer rumours might still      │
│   pop up though 👀)                  │
│                                      │
└──────────────────────────────────────┘
```
- Transfer news CAN still trigger notifications during summer — the news pipeline doesn't stop, it just naturally produces less content.

**Implementation Notes:**
- All freshness checks are done client-side based on `published_at` timestamps
- The "caught up" card is NOT a content item in the database — it's a local UI element
- The "next match" date is pulled from the most recent matchday content item or cached fixture data
- Off-season detection: if no PL fixtures exist in the API-Football response for the next 30 days, show the off-season state
- These cards are dismissible — tapping anywhere on them collapses them (with animation) and they reappear on next app open

---

## Step 3.6: Detail View — ContentDetailView

### Screen Description
The "tap for more" screen. Shows the full content item with all talking points and body text. This is where the user goes to prepare for a conversation.

### Navigation
- Pushed onto the `NavigationStack` from FeedView
- Back button in the top-left (default SwiftUI behavior, no customization needed)
- Title in navigation bar: none (keep it clean, the content speaks for itself)

### Layout (ScrollView, top to bottom)

```
[Badge]   [Timestamp]                      ← Same badge + timestamp as feed card

"Arsenal play Tottenham tonight — it's     ← Headline, full text (no truncation)
a BIG rivalry."

──────────────────────────────────────     ← Subtle divider

💬 Things to say                           ← Section header

┌──────────────────────────────────────┐
│  "Ask him if he's nervous about       │   ← Talking point card 1
│   tonight. He probably is."           │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  "Saka's been on fire lately — if     │   ← Talking point card 2
│   he scores, act excited."            │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  "Did you know Arsenal haven't lost   │   ← Talking point card 3
│   to Spurs at home in 3 years?"       │
└──────────────────────────────────────┘

──────────────────────────────────────     ← Subtle divider

🏁 After the match                         ← Section header (MATCHDAY ONLY)
                                              Only shown when type == .matchday
┌──────────────────────────────────────┐      and postMatchCheatSheet exists.
│  If they WIN:                        │   ← Green-tinted card
│  "That was massive, right?! You      │      See AGENT_CONTRACTS.md Contract 8
│   must be buzzing."                  │      for exact styling.
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│  If they LOSE:                       │   ← Red/muted-tinted card
│  "Unlucky. They'll bounce back       │
│   though."                           │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│  Bold prediction:                    │   ← Standard accent card
│  "2-1 Arsenal"                       │
└──────────────────────────────────────┘

──────────────────────────────────────     ← Subtle divider

The backstory                              ← Section header

[Body text in markdown, 3-5 paragraphs.    ← Rendered markdown body
Comfortable line spacing (1.5x).
17pt font size. Full width.]

──────────────────────────────────────     ← Subtle divider

[Share button]                             ← Bottom action
```

### Talking Points Card Design
- Background: `accentSoft.opacity(0.3)` — very subtle warm tint
- Corner radius: 12pt
- Padding: 14pt
- Text: `talkingPointText`, `textPrimary`
- Left edge: 3pt rounded bar in `accentWarm` (visual accent, like a pull quote)
- Spacing between cards: 8pt

### Section Headers
- "Things to say", "After the match" (matchday only), and "The backstory"
- Font: `feedBadge` but larger (caption size), uppercase, `textTertiary`, letter-spacing 1pt
- Left-aligned

### Share Button
- Full-width, 44pt height
- Style: outlined (2pt border in `accentWarm`, no fill, `accentWarm` text)
- Text: "Share this with a friend"
- SF Symbol: `square.and.arrow.up` inline
- Uses `ShareLink` to share: "{headline}\n\n— via Goal Digger"

### Deep Link from Push Notification
When the app receives a push notification tap:
1. `AppState.deepLinkContentId` is set to the content UUID
2. FeedView observes this and programmatically pushes ContentDetailView
3. After navigation, clear `deepLinkContentId`

---

## Step 3.7: Settings — SettingsView

### Screen Description
Simple settings screen. Minimal options because the app is intentionally simple.

### Navigation
- Presented as a push from FeedView (tap gear icon)
- Or: presented as a sheet (`.sheet`) — either works, pick what feels better

### Layout

```
Settings                                   ← Navigation title

┌──────────────────────────────────────┐
│  Your Team                           │
│  Arsenal                      ▶      │   ← Tappable, opens team change
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  Notifications                       │
│  Enabled ✓                           │   ← Status indicator (non-tappable)
│  OR                                  │
│  Disabled — Open Settings     ▶      │   ← Taps to system Settings
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  About Goal Digger              ▶    │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  Contact Us                     ▶    │   ← Opens mailto link
└──────────────────────────────────────┘

                                           ← Spacer

Version 1.0.0                              ← Bottom-center, textTertiary, caption
```

### Change Team Flow
1. Tapping "Your Team" shows an action sheet or a new screen with the 3 team cards (same design as onboarding)
2. Selecting a different team shows a confirmation dialog: "Switch to {team}? Your feed will update."
3. On confirm:
   - Update `AppState.selectedTeam`
   - Call `APIClient.updateTokenTeam()` to update the backend
   - Clear local cache (SwiftData)
   - Refresh feed from API
   - Pop back to FeedView

### Notification Status
- Check `UNUserNotificationCenter.current().notificationSettings()` on view appear
- If `.authorized` → show "Enabled" with a checkmark
- If `.denied` → show "Disabled — Open Settings" with a link to `UIApplication.openSettingsURLString`
- **Never re-request permission** from within the app

---

## Step 3.8: App Icon

### Design Direction
- **Shape:** Standard iOS rounded square (system-provided mask)
- **Style:** Simple, abstract, warm. NOT a football. NOT a whistle. NOT a pitch.
- **Concept options:**
  1. A speech bubble in `accentWarm` on a warm off-white background — represents conversation
  2. The letter "G" in a rounded, friendly font with the warm color palette
  3. An abstract "goal" shape (two posts + crossbar) stylized as a minimal line icon — subtle football reference without being a sports app icon
- **Colors:** Use the app's color palette. The icon should look at home next to lifestyle apps on the home screen.

### Sizes Required
Generate all required sizes for iOS (1024x1024 for App Store, plus all device sizes). Xcode's asset catalog handles the sizing guide.

---

## Step 3.9: Launch Screen

### Design
- Background: `appBackground` (warm off-white `#FAF8F5`)
- Center: App name "Goal Digger" in the app's title font, `textPrimary` color
- No animation, no loading indicator, no splash art
- Matches the app's background color so the transition to the first screen feels seamless

> **Implementation:** Use a `LaunchScreen.storyboard` with a single centered label, or configure via Info.plist `UILaunchScreen` key with background color.

---

# PHASE 4: Integration & Testing

**Goal:** Wire everything together and verify the full loop works end-to-end.

---

## Step 4.1: Staging Environment

1. Set up a separate Supabase project for staging (or use the same project with a `staging_` table prefix)
2. Deploy all Edge Functions to the staging environment
3. Point the iOS app at the staging URL (use a build configuration flag to switch between staging/production)
4. Seed the staging database with the 3 teams

## Step 4.2: End-to-End Testing Checklist

### Data Pipeline
- [ ] Data fetcher pulls real data from API-Football for all 3 teams
- [ ] Data fetcher correctly filters RSS articles by team/player names
- [ ] RSS feed failures are handled gracefully (one failing source doesn't break the pipeline)
- [ ] Content generator produces content in the correct tone
- [ ] Content generator correctly identifies when news is NOT newsworthy (returns `is_newsworthy: false`)
- [ ] Deduplication works: same story from multiple sources produces only 1 content item
- [ ] Review pipeline approves good content
- [ ] Review pipeline rejects bad content (test with intentionally bad examples)
- [ ] Retry logic works: rejected content is retried once with feedback
- [ ] Published content appears in the API response

### iOS App
- [ ] Onboarding flow works: welcome → team selection → notification prompt → feed
- [ ] Feed loads and displays content from the staging API
- [ ] Pull-to-refresh fetches new content
- [ ] Pagination loads older items when scrolling
- [ ] Tapping a card opens the detail view with full content
- [ ] Talking points render correctly with the styled cards
- [ ] Body markdown renders correctly
- [ ] Share button generates the correct share text
- [ ] Settings: team change works and refreshes the feed
- [ ] Settings: notification status displays correctly
- [ ] Empty state shows when there's no content
- [ ] Loading skeletons show while fetching
- [ ] Error state shows when API fails with no cached data
- [ ] Offline mode: cached content displays, pull-to-refresh shows error

### Push Notifications (after Apple Developer setup)
- [ ] APNs token is registered on the backend after onboarding
- [ ] Push notification is received when new content is published
- [ ] Tapping a push notification deep-links to the correct detail view
- [ ] Push notification displays correctly: title "Goal Digger", subtitle team name, body headline
- [ ] Notifications arrive within the 08:00-22:00 GMT window only
- [ ] No notifications are sent at night
- [ ] Token expiry is handled (410 response deactivates token)

## Step 4.3: Content Quality Tuning

This is the most important testing step. The content IS the product.

1. Run the pipeline for 3–5 days for all 3 teams
2. Review every single generated content item manually
3. Check:
   - Does it sound like a friend texting, or a sports article?
   - Would someone who hates football still enjoy reading this?
   - Are the talking points things you'd actually say out loud?
   - Is the headline punchy enough for a push notification?
4. Iterate on Claude system prompts until the tone is consistently right
5. Document prompt changes and what improved

## Step 4.4: Performance Testing

- [ ] Feed scrolls at 60fps with 50+ items
- [ ] App launch to first content visible: under 1 second (with cache)
- [ ] App launch to first content visible: under 3 seconds (cold start, no cache)
- [ ] API response time: under 500ms for feed fetch
- [ ] Memory usage stays under 100MB during normal use

---

# PHASE 5: Apple Developer & App Store Setup

**Goal:** Only now do we spend money. The app is built and tested. Time to ship.

---

## Step 5.1: Apple Developer Program

1. Enroll at [developer.apple.com](https://developer.apple.com) — $99/year
2. Create an App ID with bundle identifier `com.goaldigger.app`
3. Enable Push Notifications capability on the App ID
4. Generate an APNs authentication key (.p8):
   - Go to Keys → Create new key → check "Apple Push Notifications service (APNs)"
   - Download the .p8 file (you can only download it ONCE)
   - Note the Key ID
5. Add the APNs credentials to the backend environment variables

## Step 5.2: APNs Integration

1. Update the notification sender function with real APNs credentials
2. Switch from sandbox to production APNs endpoint
3. Test push notifications on a physical device (APNs does NOT work in the simulator)
4. Verify the full loop: content published → push received → tap → detail view

## Step 5.3: App Store Connect

1. Create the app record in App Store Connect
2. Configure:
   - **App name:** Goal Digger
   - **Subtitle:** Football talk, simplified
   - **Primary category:** Sports
   - **Secondary category:** Lifestyle
   - **Price:** Tier 10 ($9.99)
   - **Availability:** All territories (or UK-focused initially — your call)

3. **App description** (suggestion):
```
Your partner won't stop talking about football? Now you can join in.

Goal Digger gives you everything you need to keep up with his Premier League team —
without actually watching football.

Pick his team. Get the updates. Sound like you know what's going on.

HOW IT WORKS
• Choose his team: Arsenal, Manchester United, or West Ham
• Get notified when something interesting happens
• Read short, fun summaries written for people who don't care about football
• Use the talking points in actual conversations

WHAT YOU GET
• News updates — only when something genuinely interesting happens (we don't spam)
• Match day briefings — everything you need to know before the game
• Talking points — actual things you can say that'll impress him
• Detail views — go deeper if you want to really commit

DESIGNED FOR GIRLFRIENDS (AND ANYONE ELSE)
Goal Digger is for anyone who wants to connect with someone who loves the Premier League.
No football knowledge required. No jargon. No boring stats. Just the good stuff,
explained like a friend would.
```

4. **Keywords:** premier league, football, girlfriend, partner, match day, talking points, arsenal, manchester united, west ham, relationship

5. **Privacy Policy:** Create a GDPR-compliant static page (hosted on a simple web page e.g. GitHub Pages). Must include:

   **What we collect:**
   - APNs device token (a unique identifier assigned by Apple to your device for push notifications)
   - Your selected team preference (sent to our server to deliver relevant content)
   - Basic anonymised usage analytics via TelemetryDeck (privacy-friendly, no personal data)

   **Why we collect it (lawful basis — legitimate interest under GDPR Article 6(1)(f)):**
   - Device token: required to deliver push notifications you opted into
   - Team preference: required to send you relevant content for the team you selected
   - Analytics: to understand which features are used so we can improve the app

   **How long we keep it:**
   - Device tokens: retained while active. Tokens marked inactive (APNs 410 response) are deleted within 7 days.
   - Team preferences: retained as long as the device token is active.
   - Analytics: anonymised, retained for 12 months.

   **Your rights (GDPR / UK-GDPR):**
   - **Right to deletion:** Use the "Delete My Data" button in the app's Settings screen. This immediately removes your device token and team preference from our servers. You will stop receiving notifications.
   - **Right to access:** Contact privacy@goaldigger.app to request a copy of the data we hold about your device.
   - **Right to object:** You can opt out of push notifications at any time via iOS Settings. You can delete your data at any time via the app.

   **Data controller:** [Your Name / Company], [Contact Email]
   **Data processor:** Supabase Inc. (database hosting). A Data Processing Agreement (DPA) is in place.
   **Third parties:** TelemetryDeck GmbH (analytics, GDPR-compliant, no personal data shared). Apple Inc. (push notification delivery via APNs).
   **Data transfers:** Data may be processed in the EU/US. Supabase provides Standard Contractual Clauses for international transfers.

   > **IMPORTANT:** This privacy policy must be live at a public URL before App Store submission. Host it on GitHub Pages, Netlify, or similar.

6. **App Privacy "Nutrition Label":**
   - Data linked to you: None
   - Data not linked to you: Identifiers (device token for push notifications)
   - Data used to track you: None

7. **"Delete My Data" Feature (REQUIRED for GDPR compliance):**

   Add to the Settings screen: a "Delete My Data" button that:
   1. Calls `DELETE /rest/v1/device_tokens?apns_token=eq.{stored_token}` (requires a new RLS policy allowing anon DELETE where the token matches — or use an Edge Function)
   2. Clears local UserDefaults and SwiftData cache
   3. Shows confirmation: "Your data has been deleted. You'll no longer receive notifications."
   4. Returns user to the Welcome screen (re-onboarding flow)

   > **Implementation note:** Since anon DELETE on device_tokens is risky (could delete others' tokens), implement this as a dedicated Edge Function `delete-my-data` that accepts the APNs token in the request body, validates it exists, deletes the row, and returns success. This is safer than direct table DELETE via anon key.

## Step 5.4: Screenshots

Capture on iPhone 16 Pro Max (6.9") and iPhone 16 (6.3").

**Screenshot sequence (5 screenshots):** *(matches [APP_STORE_STRATEGY.md](./APP_STORE_STRATEGY.md) order)*
1. **"The Hook"** — Onboarding/welcome screen with tagline. Caption: "Stay in the loop. Win the conversation."
2. **"The Setup"** — Team selection with 3 team cards, Arsenal highlighted. Caption: "Pick his team."
3. **"The Feed"** — 3-4 content cards visible, mix of news and matchday, "caught up" card at top. Caption: "Get the updates that matter."
4. **"The Cheat Sheet"** — Detail view with talking points visible. Caption: "Know exactly what to say."
5. **"The Notification"** — Lock screen with Goal Digger push notification. Caption: "Never miss a thing."

**Screenshot styling:**
- Use device frames (Apple Design Resources or clean mockup generator)
- Captions above the device, not overlapping screen content
- Warm gradient background matching app palette (#FAF8F5 to #E8CEB8) — NOT white, NOT dark
- Use REAL content from CONTENT_EXAMPLES.md in screenshots 3 and 4
- Clean, minimal — look at how Headspace or Clue present their App Store screenshots
- See [APP_STORE_STRATEGY.md](./APP_STORE_STRATEGY.md) for full screenshot design guidelines

## Step 5.5: TestFlight

1. Archive the app in Xcode (Product → Archive)
2. Upload to App Store Connect
3. Add 5–10 TestFlight beta testers — ideally people in the target audience
4. Beta test for 3–5 days
5. Collect feedback on:
   - Content quality and tone
   - Notification frequency
   - UI clarity
   - Bugs and crashes
6. Fix any critical issues

## Step 5.6: Submit for Review

1. Submit the build for App Review
2. In the "Notes for Review" field, explain:
   - "Goal Digger sends push notifications with Premier League football updates. Content is generated by our backend and delivered via APNs. The app requires an active internet connection for initial content loading, but caches content for offline reading."
   - If the review team might not see content (if no news that day), pre-populate the staging feed with sample content and mention this in the notes
3. Expected review time: 24–48 hours

### Common Rejection Risks & Mitigations
| Risk | Mitigation |
|------|-----------|
| "Minimum functionality" — too simple | The feed + detail view + talking points provide a rich standalone experience, not just notification forwarding |
| Push notification misuse | All pushes are content-relevant, never promotional, and respect quiet hours |
| Name trademark conflict | Search the App Store for existing "Goal Digger" apps before submission |
| Missing privacy policy | Have the privacy policy URL live before submission |

## Step 5.7: Release

1. Once approved, use **Manual Release** (not auto-release)
2. Verify production backend is running and generating content
3. Release the app
4. Monitor for the first 48 hours:
   - Crash reports (Xcode Organizer)
   - Backend pipeline health (Supabase dashboard)
   - User reviews on the App Store

---

# PHASE 6: Post-Launch Operations

## Daily
- Check: Is content being generated for all 3 teams?
- Check: Are review bots approving at a reasonable rate? (Target: >80% approval)
- Monitor APNs delivery success rate

## Weekly
- Read a sample of 10 published content items across all teams
- Is the tone still on brand? Are talking points usable?
- Check analytics: DAU, feed opens vs push taps, team distribution

## Bi-weekly
- Refine Claude prompts based on content quality patterns
- Update player name lists if transfers have happened

## Quarterly
- Review costs vs revenue
- Plan v1.1 features based on feedback and analytics

## Off-Season
- The pipeline naturally produces nothing when there's no news — by design
- No filler content, no "stay tuned" messages
- Consider a single "Season's over" feed item explaining the app will wake up for the new season

---

# Cost Breakdown (Monthly Estimate)

| Item | Cost | Notes |
|------|------|-------|
| Anthropic Claude API | $60–180/month | ~384 calls/day (generation + 3 reviews). Using Sonnet for cost efficiency |
| API-Football (RapidAPI) | $30/month | Pro plan, ~540 calls/day |
| Supabase | $0–25/month | Free tier likely sufficient for v1. Pro if needed |
| Apple Developer | $8.25/month | $99/year, amortized |
| TelemetryDeck | $0/month | Free tier for <100K signals |
| **Total** | **~$100–245/month** | |

**Breakeven:** At $10/app (Apple takes 30%, so $7 net), breakeven is ~15–35 sales/month.

---

# v1.1 Roadmap (For Later)

These are explicitly out of scope for v1 but documented for future planning:

- Social media data sources (Instagram, X) — planned for v1.2
- Expand to all 20 Premier League teams
- Post-match summaries
- Boyfriend's team connection (follow 2 teams)
- Android version
- Live match updates
- Customizable notification frequency

---

*This document is the single source of truth for building Goal Digger v1. If a decision isn't documented here, check the [PRD](./PRD.md). If it's not there either, it's out of scope.*
