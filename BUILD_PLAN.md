# Goal Digger — Build Plan

**Version:** 1.0
**Date:** February 8, 2026
**Companion documents:** [PRD.md](./PRD.md) | [AGENT_CONTRACTS.md](./AGENT_CONTRACTS.md)

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
│       │   │   ├── TeamSelectionView.swift
│       │   │   └── NotificationPromptView.swift
│       │   ├── Feed/
│       │   │   └── FeedView.swift
│       │   ├── Detail/
│       │   │   └── ContentDetailView.swift
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
│   │   │   └── 001_initial_schema.sql
│   │   └── functions/
│   │       ├── _shared/                   # Shared utilities (see AGENT_CONTRACTS.md)
│   │       │   ├── supabase-client.ts
│   │       │   ├── claude-client.ts
│   │       │   ├── apns-client.ts
│   │       │   ├── types.ts
│   │       │   ├── anti-spam.ts
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
    source          TEXT NOT NULL,            -- "api_football", "bbc_rss", "sky_rss", etc.
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

-- Indexes for common queries
CREATE INDEX idx_content_team_status ON content_items(team_id, status);
CREATE INDEX idx_content_published ON content_items(team_id, published_at DESC)
    WHERE status = 'published';
CREATE INDEX idx_device_tokens_team ON device_tokens(team_id)
    WHERE is_active = true;
CREATE INDEX idx_raw_fetch_team_date ON raw_fetch_logs(team_id, fetched_at DESC);
CREATE INDEX idx_pipeline_health_recent ON pipeline_health(team_id, stage, created_at DESC);
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
- `device_tokens`: Insert/update via `anon` key (iOS client). Delete via `service_role` key.
- `teams`: Public read access.
- `raw_fetch_logs`: No public access. `service_role` only.
- `pipeline_health`: No public access. `service_role` only.

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

**Model:** `claude-sonnet-4-6` (cost-effective for summarization, excellent tone quality)

**Prompts:** All system prompts, user message templates, and tool definitions for the content generator are documented in [PROMPTS.md](./PROMPTS.md). See:
- Section 1 (Content Generator — News) for news content generation
- Section 2 (Content Generator — Matchday) for matchday briefings
- Section 6 (Newsworthy Filter) for the decision logic and anti-spam rules
- Section 7 (Prompt Variables Reference) for all template variables

**Request Format:**
```json
{
    "model": "claude-sonnet-4-6",
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

    // Persisted
    var selectedTeam: Team? {
        didSet {
            if let team = selectedTeam {
                UserDefaults.standard.set(team.rawValue, forKey: "selectedTeam")
            }
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
        let teamRaw = UserDefaults.standard.string(forKey: "selectedTeam")
        self.selectedTeam = teamRaw.flatMap { Team(rawValue: $0) }
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.notificationPermissionRequested = UserDefaults.standard.bool(forKey: "notificationPermissionRequested")
    }
}
```

---

## Step 2.3: Networking Layer — `APIClient.swift`

```swift
class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://xxxxx.supabase.co/rest/v1")!
    private let apiKey = "SUPABASE_ANON_KEY_HERE"  // Move to config/env in production

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

### Color Palette

```swift
extension Color {
    // Backgrounds
    static let appBackground = Color(hex: "#FAF8F5")    // Warm off-white
    static let cardBackground = Color.white
    static let feedDivider = Color(hex: "#F0ECE6")       // Subtle warm gray

    // Text
    static let textPrimary = Color(hex: "#1A1A1A")       // Near-black, softer than pure black
    static let textSecondary = Color(hex: "#8A8480")      // Warm gray
    static let textTertiary = Color(hex: "#B8B2AA")       // Light warm gray (timestamps)

    // Accents
    static let accentWarm = Color(hex: "#D4956A")         // Warm terracotta/peach — primary accent
    static let accentSoft = Color(hex: "#E8CEB8")         // Lighter warm accent — badge backgrounds
    static let accentGreen = Color(hex: "#7DB07E")        // Soft sage green — for "matchday" badges

    // Utility
    static let cardShadow = Color.black.opacity(0.04)
    static let shimmer = Color(hex: "#F5F0EA")            // Loading skeleton color
}
```

> **Why these colors:** The warm off-white background avoids the clinical feel of pure white. The terracotta accent is feminine without being pink. The sage green for matchday badges gives visual variety without introducing "sports app" colors. Every color is muted and warm.

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

## Step 3.2: Onboarding — WelcomeView

### Screen Description
The first thing the user sees after downloading. It should feel warm, inviting, and immediately communicate what the app does without mentioning "football stats" or anything intimidating.

### Layout (Top to Bottom)
1. **Spacer** — push content to vertical center
2. **Illustration area** (200x200pt) — A simple, warm illustration. Suggestions:
   - Two people on a couch, one excited and one smiling (abstract/minimal style)
   - Or: a speech bubble with a heart and a football inside
   - Style: line art or flat illustration with the warm color palette, NOT realistic
   - If no custom illustration available, use a large friendly emoji combination as placeholder: e.g. a text-based visual
3. **App name** — "Goal Digger" in `onboardingTitle` font, `textPrimary` color
4. **Tagline** — "Stay in the loop. Win the conversation." in `onboardingBody` font, `textSecondary` color
5. **Spacer**
6. **CTA Button** — "Get Started" — full-width, rounded rectangle, `accentWarm` background, white text, 50pt height, 16pt corner radius
7. **Bottom padding** — 40pt

### Behavior
- Tapping "Get Started" navigates to TeamSelectionView
- No skip, no back button. This is the only path forward.

---

## Step 3.3: Onboarding — TeamSelectionView

### Screen Description
User picks their partner's team. This is the most important onboarding step — it determines all future content.

### Layout
1. **Title** — "Which team does he support?" in `onboardingTitle`, centered
2. **Subtitle** — "Pick one and we'll keep you in the loop." in `onboardingBody`, `textSecondary`, centered
3. **Spacer** (24pt)
4. **Team cards** — 3 large, tappable cards stacked vertically with `cardSpacing` between them

### Team Card Design
Each card is a horizontal rectangle, full-width (minus `screenPadding`), 80pt tall:
- **Left:** Team display name in `feedHeadline` font, `textPrimary`
- **Right:** A subtle chevron (SF Symbol: `chevron.right`) in `textTertiary`
- **Background:** `cardBackground` with `cardStyle()`
- **Selected state:** `accentWarm` 2pt border, subtle scale animation (1.02x)
- **No team crests/logos** in v1 (avoids licensing issues)

### Behavior
- Tapping a card selects it (with haptic: `.selectionChanged`)
- A "Continue" button appears at the bottom once a team is selected (same style as "Get Started")
- Tapping "Continue" saves the team to AppState and navigates to NotificationPromptView

---

## Step 3.4: Onboarding — NotificationPromptView

### Screen Description
Explains why notifications matter in a friendly, non-pushy way. This screen is shown ONCE and never again.

### Layout
1. **Icon** — SF Symbol `bell.badge` in `accentWarm`, 60pt size
2. **Title** — "Don't miss the good stuff" in `onboardingTitle`, centered
3. **Body** — "We'll ping you when something interesting happens — just the highlights, never spam. Promise." in `onboardingBody`, `textSecondary`, centered, max 300pt width
4. **Spacer**
5. **Primary CTA** — "Turn on Notifications" — full-width, `accentWarm` background, white text
6. **Secondary CTA** — "Maybe Later" — text-only button, `textSecondary`, no background
7. **Bottom padding** — 40pt

### Behavior
- "Turn on Notifications" → calls `NotificationService.shared.requestPermission()`, which triggers the iOS system dialog. Regardless of the user's choice in the system dialog, mark `notificationPermissionRequested = true` and `hasCompletedOnboarding = true`, navigate to FeedView.
- "Maybe Later" → mark `notificationPermissionRequested = true` and `hasCompletedOnboarding = true`, navigate to FeedView. No notification permission requested.
- **No re-prompting, ever.** If they said no, they said no.

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

5. **Privacy Policy:** Create a simple static page disclosing:
   - Device push notification token (collected for push delivery)
   - Team selection (stored locally on device, sent to server for content delivery)
   - No personal information collected
   - No tracking
   - No third-party analytics sharing

6. **App Privacy "Nutrition Label":**
   - Data linked to you: None
   - Data not linked to you: Identifiers (device token for push notifications)

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
