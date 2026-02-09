# Goal Digger — Agent Contracts & Ownership Map

**Version:** 1.0
**Date:** February 8, 2026
**Companion documents:** [BUILD_PLAN.md](./BUILD_PLAN.md) | [PROMPTS.md](./PROMPTS.md) | [RUNBOOK.md](./RUNBOOK.md)

---

## Why This Document Exists

This project can be built by multiple AI agents working in parallel **without communicating with each other**. For that to work, every shared boundary — every data format, API call, trigger mechanism, and file — must be defined here so no agent has to guess.

**The rule:** If two agents touch the same data (one writes, one reads), the contract is defined here. If only one agent touches it, it's defined in BUILD_PLAN.md.

---

## Table of Contents

1. [Agent Definitions & Ownership](#1-agent-definitions--ownership)
2. [File Ownership Map](#2-file-ownership-map)
3. [Environment Variables Registry](#3-environment-variables-registry)
4. [Contract 1: Inter-Function Triggering](#4-contract-1-inter-function-triggering)
5. [Contract 2: Push Notification Payload](#5-contract-2-push-notification-payload)
6. [Contract 3: Matchday JSONB Storage Format](#6-contract-3-matchday-jsonb-storage-format)
7. [Contract 4: Anti-Spam Business Rules](#7-contract-4-anti-spam-business-rules)
8. [Contract 5: Supabase REST API Queries](#8-contract-5-supabase-rest-api-queries)
9. [Contract 6: Review Bot API Call Format](#9-contract-6-review-bot-api-call-format)
10. [Contract 7: Edge Function Project Structure](#10-contract-7-edge-function-project-structure)
11. [Contract 8: ContentDetailView Post-Match Section](#11-contract-8-contentdetailview-post-match-section)
12. [Contract 9: Health Check Endpoint](#12-contract-9-health-check-endpoint)
13. [Build Order & Dependencies](#13-build-order--dependencies)
14. [Agent Reporting Protocol](#14-agent-reporting-protocol)
15. [Work Tracker — Live Status Board](#15-work-tracker--live-status-board)

---

## 1. Agent Definitions & Ownership

| Agent | Scope | Primary Docs |
|-------|-------|-------------|
| **Backend Agent** | Supabase schema, all Edge Functions (data-fetcher, content-generator, content-reviewer, notification-sender, health-check, matchday-scheduler), pg_cron jobs, RLS policies, APNs integration | BUILD_PLAN Phase 1, RUNBOOK.md |
| **iOS Agent** | Xcode project, SwiftUI views, data models, networking (APIClient), caching (SwiftData), push notification handling, all UI/UX | BUILD_PLAN Phases 2–4 |
| **Pipeline Agent** | Claude API prompts, review bot prompts, content generation logic, newsworthy filter logic, prompt iteration | PROMPTS.md, CONTENT_EXAMPLES.md |

### How They Connect

```
Pipeline Agent          Backend Agent              iOS Agent
─────────────          ─────────────              ─────────
Writes prompts    →    Backend embeds prompts
                       in Edge Functions    →
                       Backend writes to DB  →    iOS reads from DB
                       Backend sends APNs    →    iOS receives APNs
```

**Pipeline Agent delivers:** Prompt text files (system prompts, user message templates, tool schemas). Backend Agent copy-pastes these into Edge Functions. Pipeline Agent does NOT write TypeScript or Swift.

**Backend Agent delivers:** A working Supabase project with schema, Edge Functions, and cron jobs. iOS Agent never touches the backend — it only calls REST endpoints.

**iOS Agent delivers:** A working Xcode project. It never calls Claude API directly — all AI is server-side.

---

## 2. File Ownership Map

Every file has exactly ONE owner. If you're not the owner, don't create or modify it.

### Backend Agent Owns

```
backend/
├── supabase/
│   ├── migrations/
│   │   └── 001_initial_schema.sql
│   └── functions/
│       ├── _shared/                    ← Shared TypeScript utilities
│       │   ├── supabase-client.ts
│       │   ├── claude-client.ts
│       │   ├── apns-client.ts
│       │   ├── types.ts                ← Shared type definitions
│       │   └── anti-spam.ts            ← Anti-spam rule enforcement
│       ├── data-fetcher/
│       │   └── index.ts
│       ├── content-generator/
│       │   └── index.ts
│       ├── content-reviewer/
│       │   └── index.ts
│       ├── notification-sender/
│       │   └── index.ts
│       ├── matchday-scheduler/
│       │   └── index.ts
│       └── health-check/
│           └── index.ts
├── seed/
│   └── seed_teams.sql
└── .env.example
```

### iOS Agent Owns

```
ios/
└── GoalDigger/
    ├── App/
    │   ├── GoalDiggerApp.swift
    │   └── AppDelegate.swift
    ├── Design/
    │   ├── Theme.swift
    │   └── Components/
    │       ├── ContentCard.swift
    │       ├── TeamPickerCard.swift
    │       ├── BadgeView.swift
    │       └── EmptyStateView.swift
    ├── Views/
    │   ├── Onboarding/
    │   │   ├── WelcomeView.swift
    │   │   ├── TeamSelectionView.swift
    │   │   └── NotificationPromptView.swift
    │   ├── Feed/
    │   │   └── FeedView.swift
    │   ├── Detail/
    │   │   └── ContentDetailView.swift
    │   └── Settings/
    │       └── SettingsView.swift
    ├── Models/
    │   ├── ContentItem.swift
    │   ├── Team.swift
    │   └── AppState.swift
    ├── Services/
    │   ├── APIClient.swift
    │   ├── NotificationService.swift
    │   └── CacheService.swift
    └── Resources/
        ├── Assets.xcassets
        └── Fonts/
```

### Pipeline Agent Owns

```
docs/
├── PROMPTS.md                  ← All Claude prompts (source of truth)
└── CONTENT_EXAMPLES.md         ← Golden examples & anti-patterns
```

### Shared (Read-Only for Agents)

These files are NOT modified by any agent during development. They're reference documents:

```
PRD.md
BUILD_PLAN.md
APP_STORE_STRATEGY.md
RUNBOOK.md
AGENT_CONTRACTS.md              ← This file
```

---

## 3. Environment Variables Registry

Every secret, where it lives, and which agent sets it up.

### Backend Agent Creates These (in Supabase dashboard → Edge Functions → Secrets)

| Variable | Value | Used By |
|----------|-------|---------|
| `SUPABASE_URL` | `https://xxxxx.supabase.co` | All Edge Functions |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase dashboard → Settings → API | All Edge Functions |
| `SUPABASE_ANON_KEY` | Supabase dashboard → Settings → API | iOS Agent needs this too |
| `ANTHROPIC_API_KEY` | Anthropic Console → API Keys | content-generator, content-reviewer |
| `API_FOOTBALL_KEY` | RapidAPI dashboard | data-fetcher |
| `APNS_KEY_ID` | Apple Developer → Keys | notification-sender |
| `APNS_TEAM_ID` | Apple Developer → Membership | notification-sender |
| `APNS_KEY_P8` | Contents of the .p8 file (base64 encoded) | notification-sender |
| `APNS_BUNDLE_ID` | `com.goaldigger.app` | notification-sender |
| `APNS_ENVIRONMENT` | `development` or `production` | notification-sender |

### iOS Agent Needs These (hardcoded in v1, move to config later)

| Variable | Where It Goes | Value |
|----------|--------------|-------|
| `SUPABASE_URL` | `APIClient.swift` → `baseURL` | Same as backend's `SUPABASE_URL` |
| `SUPABASE_ANON_KEY` | `APIClient.swift` → `apiKey` | From Supabase dashboard |

### Pipeline Agent Needs These (for local testing only)

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Testing prompts against real Claude API |

### Handoff Procedure

1. Backend Agent sets up Supabase project and creates all secrets
2. Backend Agent outputs the `SUPABASE_URL` and `SUPABASE_ANON_KEY` values
3. iOS Agent plugs those two values into `APIClient.swift`
4. APNs keys are created during Phase 5 (Apple Developer enrollment) — until then, notification-sender uses mock mode

---

## 4. Contract 1: Inter-Function Triggering

This is the exact mechanism each Edge Function uses to invoke the next one. **No agent should invent their own triggering mechanism.**

### Trigger Chain

```
pg_cron (*/30 8-23)  →  data-fetcher
                              ↓
                    (HTTP POST if new data found)
                              ↓
                       content-generator
                              ↓
                    (HTTP POST if draft created)
                              ↓
                       content-reviewer
                              ↓
                    (HTTP POST if approved)
                              ↓
                      notification-sender
```

### Trigger Format

Every function-to-function trigger is an HTTP POST to the next Edge Function with a JSON body and the service role key for auth.

```typescript
// Shared utility: backend/supabase/functions/_shared/trigger.ts

async function triggerFunction(
    functionName: string,
    payload: Record<string, unknown>
): Promise<void> {
    const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/${functionName}`;
    const response = await fetch(url, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`
        },
        body: JSON.stringify(payload)
    });
    if (!response.ok) {
        throw new Error(`Trigger ${functionName} failed: ${response.status}`);
    }
}
```

### Trigger Payloads

**data-fetcher → content-generator:**
```json
{
    "team_id": "arsenal",
    "fetch_log_ids": ["uuid-1", "uuid-2"],
    "trigger": "new_data"
}
```

**matchday-scheduler → content-generator:**
```json
{
    "team_id": "arsenal",
    "trigger": "matchday",
    "fixture_id": "1234567",
    "kickoff_time": "2026-02-08T17:30:00Z",
    "opponent": "Tottenham"
}
```

**content-generator → content-reviewer:**
```json
{
    "content_item_id": "uuid-of-draft",
    "team_id": "arsenal"
}
```

**content-reviewer → notification-sender:**
```json
{
    "content_item_id": "uuid-of-approved-item",
    "team_id": "arsenal"
}
```

### Matchday Scheduler

This is a **6th Edge Function** (`matchday-scheduler/index.ts`) that runs daily at 07:00 UTC via pg_cron. It checks API-Football for today's fixtures, calculates send times (kickoff - 90 minutes), and creates one-off pg_cron jobs to trigger the content-generator at the right time.

```sql
-- Daily matchday scheduler
SELECT cron.schedule(
    'matchday-scheduler',
    '0 7 * * *',
    $$SELECT net.http_post(
        'https://xxxxx.supabase.co/functions/v1/matchday-scheduler',
        '{}',
        'application/json',
        ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))]
    )$$
);
```

---

## 5. Contract 2: Push Notification Payload

This is the **exact** APNs payload format. Backend Agent sends it, iOS Agent parses it. They must match perfectly.

### Payload Format

```json
{
    "aps": {
        "alert": {
            "title": "Goal Digger",
            "subtitle": "Arsenal",
            "body": "Big news — Arsenal just signed a new striker and your boyfriend is probably losing his mind right now."
        },
        "sound": "default",
        "mutable-content": 1,
        "category": "CONTENT_UPDATE"
    },
    "content_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

### Field Definitions

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `aps.alert.title` | String | Always `"Goal Digger"` | App name, constant |
| `aps.alert.subtitle` | String | `teams.short_name` | e.g. "Arsenal", "Man Utd", "West Ham" |
| `aps.alert.body` | String | `content_items.headline` | Max 200 characters (enforced by brevity bot) |
| `aps.sound` | String | Always `"default"` | System notification sound |
| `aps.mutable-content` | Int | Always `1` | Allows notification service extension (future) |
| `aps.category` | String | Always `"CONTENT_UPDATE"` | For notification action grouping |
| `content_id` | String (UUID) | `content_items.id` | Used by iOS for deep linking to detail view |

### iOS Parsing (AppDelegate)

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    if let contentId = userInfo["content_id"] as? String,
       let uuid = UUID(uuidString: contentId) {
        AppState.shared.deepLinkContentId = uuid
    }
    completionHandler()
}
```

---

## 6. Contract 3: Matchday JSONB Storage Format

Matchday content items have extra fields (`if_they_win`, `if_they_lose`, `bold_prediction`, `pre_match_mood`, `rivalry_level`) that don't have dedicated database columns. They are stored in a structured JSONB format inside the `talking_points` column.

### Storage Format

The `talking_points` JSONB column for **matchday** content items has this exact structure:

```json
{
    "regular": [
        "This is THE rivalry. Arsenal and Tottenham are both from North London...",
        "If you want to seem like you're paying attention, ask him...",
        "Fun fact you can casually drop: Arsenal haven't lost to Spurs...",
        "The game kicks off at 17:30. If he goes quiet about an hour before..."
    ],
    "post_match": {
        "if_they_win": "That was massive, right?! You must be buzzing.",
        "if_they_lose": "Unlucky. They'll bounce back though.",
        "bold_prediction": "2-1 Arsenal"
    },
    "metadata": {
        "pre_match_mood": "nervous",
        "rivalry_level": "derby"
    }
}
```

For **news** content items, `talking_points` remains a simple JSON array:

```json
[
    "So Arsenal signed this guy called Viktor Gyokeres...",
    "He cost around £85 million, which is a LOT...",
    "The reason this is big: Arsenal have been struggling...",
    "If his mates are texting about it too..."
]
```

### Who Does What

| Agent | Responsibility |
|-------|---------------|
| **Pipeline Agent** | Designs the prompt to output `if_they_win`, `if_they_lose`, `bold_prediction`, `pre_match_mood`, `rivalry_level` as separate tool output fields |
| **Backend Agent** | In `content-generator`, maps the Claude tool output fields into the JSONB structure above before inserting into `content_items` |
| **iOS Agent** | In `ContentItem.swift`, parses `talking_points` based on `type`: if `matchday`, decode as structured object; if `news`, decode as string array |

### iOS Swift Types

```swift
// ContentItem.swift — add these types

struct MatchdayTalkingPoints: Codable {
    let regular: [String]
    let postMatch: PostMatchCheatSheet
    let metadata: MatchdayMetadata

    enum CodingKeys: String, CodingKey {
        case regular
        case postMatch = "post_match"
        case metadata
    }
}

struct PostMatchCheatSheet: Codable {
    let ifTheyWin: String
    let ifTheyLose: String
    let boldPrediction: String

    enum CodingKeys: String, CodingKey {
        case ifTheyWin = "if_they_win"
        case ifTheyLose = "if_they_lose"
        case boldPrediction = "bold_prediction"
    }
}

struct MatchdayMetadata: Codable {
    let preMatchMood: String    // "confident", "nervous", "excited", "meh"
    let rivalryLevel: String    // "derby", "big_game", "normal", "dead_rubber"

    enum CodingKeys: String, CodingKey {
        case preMatchMood = "pre_match_mood"
        case rivalryLevel = "rivalry_level"
    }
}
```

### ContentItem Parsing

```swift
// In ContentItem.swift — the talkingPoints property decodes differently based on type

var regularTalkingPoints: [String] {
    switch type {
    case .news:
        // talking_points is a simple [String]
        return talkingPoints
    case .matchday:
        // talking_points is a MatchdayTalkingPoints object
        // Decode from the raw JSON and return .regular array
        // (Implementation detail for iOS Agent)
        return matchdayData?.regular ?? talkingPoints
    }
}

var postMatchCheatSheet: PostMatchCheatSheet? {
    guard type == .matchday else { return nil }
    return matchdayData?.postMatch
}
```

> **Note:** The exact Codable implementation for handling the dual format (array vs object) is left to iOS Agent. Options: use a custom decoder, or store `talkingPointsRaw: Data` and decode lazily.

---

## 7. Contract 4: Anti-Spam Business Rules

These rules are defined in [PROMPTS.md Section 6](./PROMPTS.md#6-newsworthy-filter--decision-logic) but must be **enforced by Backend Agent** in the notification-sender Edge Function. The prompt encourages Claude to self-regulate, but the backend is the hard enforcement layer.

### Rules (Backend Agent MUST Enforce)

| Rule | Where Enforced | Implementation |
|------|---------------|----------------|
| Max 2 notifications per day per team | `notification-sender` | Before sending: `SELECT COUNT(*) FROM content_items WHERE team_id = $1 AND status = 'published' AND published_at > NOW() - INTERVAL '24 hours'`. If >= 2, skip. |
| Min 3 hours between notifications for same team | `notification-sender` | Before sending: `SELECT published_at FROM content_items WHERE team_id = $1 AND status = 'published' ORDER BY published_at DESC LIMIT 1`. If < 3 hours ago, delay to next hourly sweep. |
| No notifications between 22:00 and 08:00 GMT | `notification-sender` | Check current UTC hour. If >= 22 or < 8, skip (hourly sweep will catch it tomorrow). |
| No duplicate topics | `content-generator` | Deduplication check before generating (see BUILD_PLAN Step 1.4). |
| Only publish if newsworthiness score >= 6 | `content-generator` | Check the `newsworthiness_score` from Claude's tool output. If < 6, don't insert into content_items. |
| Matchday content always sends (counts toward daily max) | `notification-sender` | Matchday items bypass the 3-hour gap rule but still count toward the 2/day maximum. |

### Backend Implementation: `_shared/anti-spam.ts`

```typescript
interface SpamCheckResult {
    canSend: boolean;
    reason?: string;
}

async function checkAntiSpamRules(
    supabase: SupabaseClient,
    teamId: string,
    contentType: "news" | "matchday"
): Promise<SpamCheckResult> {
    // 1. Quiet hours check
    const hour = new Date().getUTCHours();
    if (hour >= 22 || hour < 8) {
        return { canSend: false, reason: "quiet_hours" };
    }

    // 2. Daily limit check
    const { count } = await supabase
        .from("content_items")
        .select("*", { count: "exact", head: true })
        .eq("team_id", teamId)
        .eq("status", "published")
        .gte("published_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

    if ((count ?? 0) >= 2) {
        return { canSend: false, reason: "daily_limit_reached" };
    }

    // 3. Gap check (skip for matchday)
    if (contentType !== "matchday") {
        const { data } = await supabase
            .from("content_items")
            .select("published_at")
            .eq("team_id", teamId)
            .eq("status", "published")
            .order("published_at", { ascending: false })
            .limit(1);

        if (data?.[0]) {
            const hoursSinceLast = (Date.now() - new Date(data[0].published_at).getTime()) / (1000 * 60 * 60);
            if (hoursSinceLast < 3) {
                return { canSend: false, reason: "gap_too_short" };
            }
        }
    }

    return { canSend: true };
}
```

---

## 8. Contract 5: Supabase REST API Queries

These are the exact HTTP requests iOS Agent makes. Backend Agent must ensure the schema and RLS policies make these work.

### Fetch Feed (Paginated)

```
GET /rest/v1/content_items?team_id=eq.{team_id}&status=eq.published&order=published_at.desc&limit=20&offset={offset}&select=id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at
```

**Headers:**
```
apikey: {SUPABASE_ANON_KEY}
Authorization: Bearer {SUPABASE_ANON_KEY}
```

**Response:** Array of `ContentItem` JSON objects. Empty array `[]` if no results.

**RLS requirement:** `content_items` must have a policy allowing `SELECT` for `anon` role WHERE `status = 'published'`.

### Fetch Single Item (Deep Link)

```
GET /rest/v1/content_items?id=eq.{uuid}&status=eq.published&select=id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at
```

**Response:** Array with 0 or 1 items.

### Register Device Token

```
POST /rest/v1/device_tokens
```

**Headers:**
```
apikey: {SUPABASE_ANON_KEY}
Authorization: Bearer {SUPABASE_ANON_KEY}
Content-Type: application/json
Prefer: resolution=merge-duplicates
```

**Body:**
```json
{
    "team_id": "arsenal",
    "apns_token": "abc123def456..."
}
```

**Note:** The `Prefer: resolution=merge-duplicates` header makes this an upsert — if the token already exists, it updates the team_id. This handles app re-installs and team switches gracefully.

**RLS requirement:** `device_tokens` must allow `INSERT` and `UPDATE` for `anon` role.

### Update Team (Change Team)

```
PATCH /rest/v1/device_tokens?apns_token=eq.{token}
```

**Headers:**
```
apikey: {SUPABASE_ANON_KEY}
Authorization: Bearer {SUPABASE_ANON_KEY}
Content-Type: application/json
```

**Body:**
```json
{
    "team_id": "west_ham",
    "updated_at": "2026-02-08T12:00:00Z"
}
```

---

## 9. Contract 6: Review Bot API Call Format

Pipeline Agent defines the prompts. Backend Agent implements the API calls. This contract ensures they match.

### All 3 Review Bots Use Plain Text Response (NOT tool_use)

The review bots respond with JSON in their message content (not via tool_use). This is simpler and works reliably.

**API Call Format (identical for all 3 bots, only the system prompt differs):**

```json
{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 1000,
    "system": "<system prompt from PROMPTS.md Section 3, 4, or 5>",
    "messages": [
        {
            "role": "user",
            "content": "<input template from PROMPTS.md, filled with content to review>"
        }
    ]
}
```

**Response Parsing:**

The response `content[0].text` will be a JSON string. Parse it:

```typescript
// Backend: content-reviewer/index.ts
const response = await claude.messages.create({ ... });
const reviewText = response.content[0].text;
const review = JSON.parse(reviewText) as ReviewResult;

interface ReviewResult {
    pass: boolean;
    confidence: number;    // 0.0 - 1.0
    notes: string;
    // Additional fields vary by bot — see PROMPTS.md for each
}
```

**Why not tool_use for review bots?**
- Review bots produce simple pass/fail judgments, not complex structured content
- Plain JSON in text is simpler to implement and debug
- tool_use is reserved for the content generator where structured output is critical

---

## 10. Contract 7: Edge Function Project Structure

All Edge Functions follow this structure. Backend Agent creates all of these.

```
backend/supabase/functions/
├── _shared/                        ← Shared utilities (imported by all functions)
│   ├── supabase-client.ts          ← Creates authenticated Supabase client
│   ├── claude-client.ts            ← Creates Anthropic client, handles retries
│   ├── apns-client.ts              ← APNs HTTP/2 connection + JWT auth
│   ├── types.ts                    ← Shared TypeScript interfaces
│   ├── anti-spam.ts                ← Anti-spam rule enforcement (Contract 4)
│   ├── trigger.ts                  ← Inter-function HTTP trigger (Contract 1)
│   └── pipeline-logger.ts          ← Logs to pipeline_health table
├── data-fetcher/
│   └── index.ts                    ← Cron-triggered, fetches RSS + API-Football
├── content-generator/
│   └── index.ts                    ← Triggered by data-fetcher or matchday-scheduler
├── content-reviewer/
│   └── index.ts                    ← Triggered by content-generator
├── notification-sender/
│   └── index.ts                    ← Triggered by content-reviewer + hourly sweep
├── matchday-scheduler/
│   └── index.ts                    ← Daily at 07:00 UTC, schedules matchday content
└── health-check/
    └── index.ts                    ← GET endpoint, returns system health JSON
```

### Shared Types (`_shared/types.ts`)

```typescript
// These types are the source of truth for all Edge Functions

interface ContentItem {
    id: string;
    team_id: string;
    type: "news" | "matchday";
    headline: string;
    body: string;
    talking_points: string[] | MatchdayTalkingPoints;
    kickoff_time: string | null;
    emotional_context: "exciting" | "bad_news" | "drama" | "informational" | "funny" | null;
    status: "draft" | "approved" | "rejected" | "published";
    review_notes: ReviewNote[];
    source_urls: string[];
    match_id: string | null;
    created_at: string;
    published_at: string | null;
}

interface MatchdayTalkingPoints {
    regular: string[];
    post_match: {
        if_they_win: string;
        if_they_lose: string;
        bold_prediction: string;
    };
    metadata: {
        pre_match_mood: "confident" | "nervous" | "excited" | "meh";
        rivalry_level: "derby" | "big_game" | "normal" | "dead_rubber";
    };
}

interface ReviewNote {
    bot: "tone" | "accuracy" | "brevity";
    pass: boolean;
    confidence: number;
    notes: string;
    reviewed_at: string;
}

interface PipelineHealthLog {
    team_id: string;
    stage: "fetch" | "generate" | "review" | "publish";
    status: "success" | "failure" | "skipped";
    duration_ms: number;
    message: string | null;
    content_item_id: string | null;
}

interface TriggerPayload {
    team_id: string;
    trigger: "new_data" | "matchday" | "review_complete" | "approved";
    content_item_id?: string;
    fetch_log_ids?: string[];
    fixture_id?: string;
    kickoff_time?: string;
    opponent?: string;
}
```

### Pipeline Logger (`_shared/pipeline-logger.ts`)

Every function logs its outcome. This is how the health-check endpoint knows what's happening.

```typescript
async function logPipelineEvent(
    supabase: SupabaseClient,
    event: PipelineHealthLog
): Promise<void> {
    await supabase.from("pipeline_health").insert(event);
}
```

---

## 11. Contract 8: ContentDetailView Post-Match Section

For matchday content, the detail view has an extra section below the regular talking points. This is defined in [CONTENT_EXAMPLES.md](./CONTENT_EXAMPLES.md) (Example 2, "Post-Match Cheat Sheet") and must be implemented by iOS Agent.

### When to Show

Only when `content_item.type == .matchday` AND `postMatchCheatSheet` is not nil.

### Layout (below the regular talking points)

```
──────────────────────────────────────     ← Subtle divider

🏁 After the match                         ← Section header (same style as "Things to say")

┌──────────────────────────────────────┐
│  If they WIN:                        │   ← Green-tinted card
│  "That was massive, right?! You      │
│   must be buzzing."                  │
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
```

### Card Styling

| Card | Background Tint | Left Bar Color |
|------|----------------|---------------|
| If they WIN | `Color.green.opacity(0.08)` | `Color.green.opacity(0.5)` |
| If they LOSE | `Color.red.opacity(0.06)` | `Color.red.opacity(0.4)` |
| Bold prediction | `accentSoft.opacity(0.3)` (same as regular talking points) | `accentWarm` |

### Label Styling

- "If they WIN:" / "If they LOSE:" / "Bold prediction:" — `feedBadge` font, uppercase, same as regular labels
- The quote text below — same `talkingPointText` style as regular talking points

---

## 12. Contract 9: Health Check Endpoint

A 6th Edge Function that Backend Agent must build. Defined in [RUNBOOK.md](./RUNBOOK.md) but missing from BUILD_PLAN's project structure.

### Endpoint

```
GET /functions/v1/health-check
Authorization: Bearer {SUPABASE_SERVICE_ROLE_KEY}
```

### Response Format

```json
{
    "status": "healthy",
    "last_check": "2026-02-08T14:30:00Z",
    "teams": {
        "arsenal": {
            "last_fetch": "2026-02-08T14:00:00Z",
            "last_published": "2026-02-08T11:23:00Z",
            "published_today": 1,
            "fetch_errors_24h": 0,
            "review_rejections_24h": 1
        },
        "man_utd": { "..." : "..." },
        "west_ham": { "..." : "..." }
    },
    "external_services": {
        "claude_api": "healthy",
        "api_football": "healthy",
        "apns": "healthy",
        "rss_feeds": {
            "healthy": 10,
            "failing": 2,
            "failing_feeds": ["mirror_rss", "telegraph_rss"]
        }
    }
}
```

### Status Logic

- `"healthy"` — all teams have had a successful fetch in the last 4 hours
- `"degraded"` — one or more teams missing fetches, but content was published in last 24 hours
- `"unhealthy"` — any team has had no published content for 48+ hours during a matchweek

---

## 13. Build Order & Dependencies

Agents can work in parallel **within their scope**, but there are handoff points where one agent's output is needed before another can proceed.

### Phase Diagram

```
Week 1-2:
  Backend Agent: Schema + data-fetcher + content-generator  ←──┐
  Pipeline Agent: All prompts + golden example testing         │
  iOS Agent: Xcode setup + models + theme + onboarding views   │
                                                               │
Week 2-3:                                                      │
  Backend Agent: content-reviewer + notification-sender         │
  iOS Agent: Feed view + detail view + API client              │
             (uses SEED DATA until backend is ready) ──────────┘

Week 3-4:
  Backend Agent: matchday-scheduler + health-check + cron jobs
  iOS Agent: Push notification handling + cache + polish

Week 4:
  INTEGRATION: Connect iOS to live backend
  All agents: Bug fixes from integration testing
```

### Seed Data for iOS Agent

iOS Agent should NOT wait for the backend to be ready. Instead, use the 5 golden examples from [CONTENT_EXAMPLES.md](./CONTENT_EXAMPLES.md) as local mock data:

```swift
// MockData.swift — iOS Agent creates this for development
static let mockFeed: [ContentItem] = [
    // Copy the 5 golden examples from CONTENT_EXAMPLES.md
    // Use these to build and test all UI without a backend
]
```

This mock data file is deleted when the real backend is connected.

### Integration Checklist

When all agents are done, verify these contracts work end-to-end:

- [ ] data-fetcher triggers content-generator via HTTP POST (Contract 1)
- [ ] content-generator stores matchday JSONB correctly (Contract 3)
- [ ] content-reviewer parses review bot JSON responses (Contract 6)
- [ ] notification-sender enforces all anti-spam rules (Contract 4)
- [ ] notification-sender sends correct APNs payload (Contract 2)
- [ ] iOS parses APNs payload and deep-links correctly (Contract 2)
- [ ] iOS fetches feed via REST API successfully (Contract 5)
- [ ] iOS renders Post-Match Cheat Sheet for matchday items (Contract 8)
- [ ] health-check returns correct status (Contract 9)

---

---

## 14. Agent Reporting Protocol

Every agent **must** follow this protocol. It keeps the work tracker honest and prevents two agents from doing the same task.

### Before Starting Work

1. **Read this file first.** Check the [Work Tracker](#15-work-tracker--live-status-board) below.
2. **Claim your task.** Change its status from `open` to `in_progress` and add your agent name and start date.
3. **Commit the claim immediately.** Push a commit that only updates the work tracker row — before you write any code. This is the "lock."
4. **Never claim a task that is already `in_progress` or `done`.** If it's taken, move on.

### While Working

5. **Stay in your lane.** Only touch files you own (see [File Ownership Map](#2-file-ownership-map)). If you need something from another agent's scope, check the contracts above — the answer should be there. If it's genuinely not, add a row to the [Blockers & Questions](#blockers--questions) table below and move to a different task.
6. **One task at a time.** Finish or explicitly pause a task before claiming the next one.

### After Completing a Task

7. **Update the Work Tracker.** Change status to `done`, add your completion date.
8. **Fill in the Outcome column.** One line: what was built, how it went, anything the next agent should know. Be specific — "Done" is not helpful. "Built, all 12 RSS feeds parsing, tested with live data" is.
9. **If a task is blocked or abandoned**, change status to `blocked` and explain in the Outcome column what's needed to unblock it.
10. **Commit the status update** in the same commit as your code, or immediately after.

### Status Values

| Status | Meaning | Who Can Change It |
|--------|---------|-------------------|
| `open` | Not started, available to claim | Any agent |
| `in_progress` | Claimed by an agent, work underway | Only the agent who claimed it |
| `done` | Completed and working | Only the agent who claimed it |
| `blocked` | Cannot proceed, needs input | Only the agent who claimed it |
| `review` | Done but needs integration testing | Only the agent who claimed it |

---

## 15. Work Tracker — Live Status Board

**How to read this:** Each row is a discrete deliverable. The Agent column shows who should do it. Status shows where it stands. Agents update this table as they work.

### Backend Agent Tasks

| # | Task | Status | Agent | Started | Completed | Outcome |
|---|------|--------|-------|---------|-----------|---------|
| B1 | Database schema (`001_initial_schema.sql`) — all tables, indexes, RLS policies, seed data | `done` | Backend | 2026-02-09 | 2026-02-09 | 5 tables (teams, content_items, device_tokens, raw_fetch_logs, pipeline_health), 5 indexes, full RLS policies, seed data for 3 teams (Arsenal=42, Man Utd=33, West Ham=48). |
| B2 | `_shared/` utilities — supabase-client, claude-client, types, trigger, pipeline-logger, anti-spam | `done` | Backend | 2026-02-09 | 2026-02-09 | types.ts (all DB + API interfaces), supabase-client.ts (singleton + logPipelineHealth + triggerFunction), claude-client.ts (Claude API wrapper with tool_use support), anti-spam.ts (daily limit + 3h gap + quiet hours + headline dedup via keyword overlap). |
| B3 | `data-fetcher` — RSS parsing, API-Football integration, raw_fetch_logs storage, deduplication | `done` | Backend | 2026-02-09 | 2026-02-09 | 12 RSS feeds (BBC, Sky, Guardian, Mirror, Mail, Standard, Independent, Telegraph, ESPN, Goal, Football365, TeamTalk) + 6 API-Football endpoints per team. Player name filtering per team (~25 names). URL dedup against last 48h of raw_fetch_logs. Triggers content-generator on new data. |
| B4 | `content-generator` — Claude API integration, newsworthiness check, draft creation, matchday JSONB formatting (Contract 3) | `done` | Backend | 2026-02-09 | 2026-02-09 | Full Claude API integration with news system prompt and tool definition from PROMPTS.md. Anti-spam check before generation. Newsworthiness scoring (publish if 6+). Saves draft to content_items, triggers content-reviewer. |
| B5 | `content-reviewer` — 3 parallel review bots, retry logic, approval/rejection flow | `done` | Backend | 2026-02-09 | 2026-02-09 | 3 parallel Claude API calls (tone, accuracy, brevity) with full prompts from PROMPTS.md Sections 3-5. All 3 must pass. Single-bot failure triggers retry with feedback. Review notes stored in content_items.review_notes. Triggers notification-sender on approval. |
| B6 | `notification-sender` — APNs integration, anti-spam enforcement (Contract 4), payload format (Contract 2) | `done` | Backend | 2026-02-09 | 2026-02-09 | APNs JWT auth (ES256), quiet hours check (08:00-22:00 GMT), token lifecycle (410→deactivate, 429→backoff). Payload: title "Goal Digger", subtitle team short name, body headline, content_id for deep linking. Graceful fallback when APNs not yet configured (Phase 5). |
| B7 | `matchday-scheduler` — Daily 07:00 UTC, fixture detection, one-off pg_cron scheduling | `done` | Backend | 2026-02-09 | 2026-02-09 | Fetches today's PL fixtures, matches against our 3 teams, calculates send time (kickoff - 90min, min 08:00). Creates pg_cron one-off jobs for delayed invocation. Falls back to immediate trigger if scheduling fails or send time already passed. Skips matches already in progress. |
| B8 | `health-check` — GET endpoint, system status JSON (Contract 9) | `done` | Backend | 2026-02-09 | 2026-02-09 | Per-team health: last fetch/generate/review/publish timestamps, 24h error count, published count, active device count. Alert conditions: no fetch in 4h (HIGH), no content in 12h (HIGH), no published in 48h (CRITICAL). Overall status: healthy/warning/critical. |
| B9 | pg_cron jobs — data-fetcher schedule, matchday-scheduler schedule, cleanup crons | `done` | Backend | 2026-02-09 | 2026-02-09 | Defined in 001_initial_schema.sql (commented, ready to activate): data-fetcher every 30min 08:00-23:00, matchday-scheduler daily 07:00, notification sweep hourly, log purge weekly (90 days). |
| B10 | APNs .p8 key setup — JWT auth, sandbox + production config | `blocked` | Backend | — | — | Blocked on Apple Developer account enrollment (Phase 5, $99/year). JWT auth code is written in notification-sender and tested with mock mode. Env vars documented in .env.example. Will switch APNS_ENVIRONMENT from "development" to "production" after approval. |

### iOS Agent Tasks

| # | Task | Status | Agent | Started | Completed | Outcome |
|---|------|--------|-------|---------|-----------|---------|
| I1 | Xcode project setup — bundle ID, capabilities, iOS 17+ target, no dependencies | `open` | iOS | — | — | — |
| I2 | Data models — `Team.swift`, `ContentItem.swift` (with matchday JSONB parsing per Contract 3), `AppState.swift` | `open` | iOS | — | — | — |
| I3 | `Theme.swift` — Design system (colors, fonts, spacing from BUILD_PLAN Phase 3) | `open` | iOS | — | — | — |
| I4 | `APIClient.swift` — All REST endpoints per Contract 5, error handling | `open` | iOS | — | — | — |
| I5 | `CacheService.swift` — SwiftData model, upsert, purge, offline support | `open` | iOS | — | — | — |
| I6 | Onboarding flow — WelcomeView, TeamSelectionView, NotificationPromptView | `open` | iOS | — | — | — |
| I7 | `FeedView.swift` — Content cards, badges, pull-to-refresh, freshness states (5 states from BUILD_PLAN) | `open` | iOS | — | — | — |
| I8 | `ContentDetailView.swift` — Talking points, body, share button, Post-Match Cheat Sheet (Contract 8) | `open` | iOS | — | — | — |
| I9 | Push notification handling — AppDelegate, token registration, deep link to detail view (Contract 2) | `open` | iOS | — | — | — |
| I10 | `SettingsView.swift` — Team switcher, about section, app version | `open` | iOS | — | — | — |
| I11 | MockData.swift — 5 golden examples from CONTENT_EXAMPLES.md for development without backend | `open` | iOS | — | — | — |
| I12 | Visual polish — Animations, loading states, empty states, error states | `open` | iOS | — | — | — |

### Pipeline Agent Tasks

| # | Task | Status | Agent | Started | Completed | Outcome |
|---|------|--------|-------|---------|-----------|---------|
| P1 | News generator prompt — System prompt, user template, tool schema (PROMPTS.md Section 1) | `done` | Pipeline | 2026-02-09 | 2026-02-09 | Refined: added headline-first rule (rule 8), conditional validation note for Backend Agent on tool schema, added emotional_context to decision logic, fixed Variables Reference with 9 missing variables, defined talking_points_formatted format. |
| P2 | Matchday generator prompt — System prompt, user template, tool schema (PROMPTS.md Section 2) | `done` | Pipeline | 2026-02-09 | 2026-02-09 | Refined: added headline rule (rule 7) with good/bad examples, added no-repetition rule, made bold_prediction and emotional_context required in tool schema, added explicit JSONB mapping note referencing Contract 3 for Backend Agent. |
| P3 | Tone review bot prompt — System prompt, input template, pass/fail criteria (PROMPTS.md Section 3) | `done` | Pipeline | 2026-02-09 | 2026-02-09 | Refined: expanded jargon blacklist with 9 additional terms (incl. "final third" from anti-pattern 3), added Contract 6 response format note, specified plain JSON requirement. |
| P4 | Accuracy review bot prompt — System prompt, input template, severity rules (PROMPTS.md Section 4) | `done` | Pipeline | 2026-02-09 | 2026-02-09 | Refined: moved severity rules INTO the system prompt (Claude needs to see them), added Contract 6 plain JSON note, added "no markdown wrapping" instruction. |
| P5 | Brevity review bot prompt — System prompt, input template, length rules (PROMPTS.md Section 5) | `done` | Pipeline | 2026-02-09 | 2026-02-09 | Refined: added Contract 6 plain JSON note, added "no markdown wrapping" instruction. Prompt was otherwise solid — length rules are clear and specific. |
| P6 | Prompt testing — Run all prompts against real data, compare output to golden examples, iterate | `done` | Pipeline | 2026-02-09 | 2026-02-09 | Structural validation: all 5 golden examples pass, 4/6 anti-patterns caught (2 require API review bots). Created test harness at docs/prompts/test-harness/. Full API testing blocked until Backend deploys pipeline — documented 5-step testing procedure in CONTENT_EXAMPLES.md. |
| P7 | Document prompt iterations — Log changes in PROMPTS.md Section 8 | `done` | Pipeline | 2026-02-09 | 2026-02-09 | Logged 12 iteration entries in Section 8 covering all changes from P1-P6. Each entry has date, prompt, change, reason, and result. |

### Integration Tasks (All Agents)

| # | Task | Status | Agent | Started | Completed | Outcome |
|---|------|--------|-------|---------|-----------|---------|
| X1 | Connect iOS to live Supabase backend — swap mock data for real API calls | `open` | iOS | — | — | — |
| X2 | End-to-end pipeline test — data-fetcher → generator → reviewer → notification → iOS | `open` | Backend | — | — | — |
| X3 | Integration checklist — verify all 9 contracts (see Section 13) | `open` | All | — | — | — |
| X4 | TestFlight beta — 5-10 testers, 3-5 days | `open` | iOS | — | — | — |
| X5 | App Store submission — screenshots, description, review | `open` | iOS | — | — | — |

### Blockers & Questions

If an agent encounters something that isn't covered by the contracts and can't proceed, log it here. Another agent (or the project owner) will resolve it.

| # | Raised By | Date | Question / Blocker | Status | Resolution |
|---|-----------|------|--------------------|--------|------------|
| Q1 | Backend | 2026-02-09 | B10 (APNs .p8 key) is blocked — requires Apple Developer enrollment ($99/year, Phase 5). JWT auth code is written and will work once keys are provided. | `blocked` | Awaiting Apple Developer account setup. |

---

### Example: How an Agent Updates This Board

**Before starting B3 (data-fetcher):**
```
| B3 | `data-fetcher` — RSS parsing, API-Football... | `in_progress` | Backend | 2026-02-10 | — | — |
```

**After completing B3:**
```
| B3 | `data-fetcher` — RSS parsing, API-Football... | `done` | Backend | 2026-02-10 | 2026-02-12 | Built with 12 RSS feeds + 6 API-Football endpoints. Deduplication working via URL hash. Tested with live data for all 3 teams. Average fetch cycle: 8 seconds. |
```

**If B6 is blocked:**
```
| B6 | `notification-sender` — APNs integration... | `blocked` | Backend | 2026-02-14 | — | Blocked: need Apple Developer account for .p8 key. Can't test APNs without it. Mock mode built and working. |
```

Then add a row to Blockers & Questions:
```
| Q1 | Backend | 2026-02-14 | Need Apple Developer enrollment to generate APNs .p8 key for B6 and B10 | open | — |
```

---

*This document is the handshake between agents. If something crosses agent boundaries, it must be defined here. No guessing, no assumptions, no "I thought the other agent would handle that."*
