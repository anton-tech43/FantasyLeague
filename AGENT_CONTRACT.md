# Agent Contract — Goal Digger Multi-Agent Coordination

**Purpose:** This file is the single source of truth for agent coordination. Every agent MUST read this file at the start of each run and update it when completing work. Check this file before starting work to avoid conflicts.

**Branch:** All code is on `main`.

---

## Work Ownership Table

| Area | Status | Agent | Notes |
|------|--------|-------|-------|
| **Backend: Project structure & scaffolding** | DONE | Agent 1 | Full directory tree created |
| **Backend: SQL schema migration** | DONE | Agent 1 | `001_initial_schema.sql` + RLS + indexes + cron jobs |
| **Backend: Seed data** | DONE | Agent 1 | `seed_teams.sql` (Arsenal, Man Utd, West Ham) |
| **Backend: data-fetcher Edge Function** | DONE | Agent 1 | API-Football (6 endpoints) + 12 RSS feeds + dedup |
| **Backend: content-generator Edge Function** | DONE | Agent 1 | Claude API news generation + anti-spam rules |
| **Backend: content-reviewer Edge Function** | DONE | Agent 1 | 3 parallel review bots + retry logic |
| **Backend: notification-sender Edge Function** | DONE | Agent 1 | APNs JWT auth + token management + quiet hours |
| **Backend: health-check endpoint** | DONE | Agent 1 | Pipeline monitoring + alert conditions |
| **Backend: matchday-scheduler Edge Function** | DONE | Agent 1 | Daily 07:00 UTC, fixture detection, delayed triggering |
| **Backend: _shared/ utilities** | DONE | Agent 1 | types.ts, supabase-client.ts, claude-client.ts, anti-spam.ts |
| **Backend: .env.example** | DONE | Agent 1 | All env vars documented |
| **Backend: Deploy to Supabase** | AVAILABLE | — | Link project, push schema, deploy functions, set secrets |
| **Backend: End-to-end pipeline test** | AVAILABLE | — | Test full pipeline with real API keys |
| **iOS: Xcode project setup (I1)** | DONE | Agent 2 | GoalDiggerApp.swift + AppDelegate.swift |
| **iOS: Models (I2)** | DONE | Agent 2 | Team.swift, ContentItem.swift (dual-format decoder), AppState.swift |
| **iOS: Design system (I3)** | DONE | Agent 2 | Theme.swift — colors, fonts, spacing, CardStyle modifier |
| **iOS: Mock data (I11)** | DONE | Agent 2 | MockData.swift — all 5 golden examples |
| **iOS: Onboarding flow (I6)** | DONE | Agent 2 | WelcomeView, TeamSelectionView, NotificationPromptView |
| **iOS: Feed view (I7)** | DONE | Agent 2 | FeedView + FeedViewModel + freshness states + skeleton loading |
| **iOS: Detail view (I8)** | DONE | Agent 2 | ContentDetailView + TalkingPointCard + PostMatchCard (Contract 8) |
| **iOS: Settings view (I10)** | DONE | Agent 2 | SettingsView + AboutView + team switch + notification status |
| **iOS: Shared components (I12)** | DONE | Agent 2 | ContentCard, BadgeView, TeamPickerCard, EmptyStateView |
| **iOS: APIClient (I4)** | DONE | Agent 2 | Supabase REST — 4 endpoints per Contract 5 |
| **iOS: CacheService (I5)** | DONE | Agent 2 | SwiftData CachedContentItem + cache/load/purge/clear |
| **iOS: NotificationService (I9)** | DONE | Agent 2 | Permission request + token registration + status check |
| **Pipeline: News generator prompt (P1)** | AVAILABLE | — | PROMPTS.md Section 1 |
| **Pipeline: Matchday generator prompt (P2)** | AVAILABLE | — | PROMPTS.md Section 2 |
| **Pipeline: Tone review bot prompt (P3)** | AVAILABLE | — | PROMPTS.md Section 3 |
| **Pipeline: Accuracy review bot prompt (P4)** | AVAILABLE | — | PROMPTS.md Section 4 |
| **Pipeline: Brevity review bot prompt (P5)** | AVAILABLE | — | PROMPTS.md Section 5 |
| **Pipeline: Prompt testing (P6)** | AVAILABLE | — | Needs ANTHROPIC_API_KEY for live testing |
| **Pipeline: Document iterations (P7)** | AVAILABLE | — | PROMPTS.md Section 8 |
| **Docs: README.md** | AVAILABLE | — | Not started |

---

## Blocked Items

| Area | Blocked By | Date Logged |
|------|-----------|-------------|
| Content-generator + content-reviewer testing | Missing `ANTHROPIC_API_KEY` | 2026-03-25 |
| Notification-sender testing | Missing APNs credentials (Phase 5) | 2026-03-25 |

---

## Completed Work Log

| Date | Agent | What was done |
|------|-------|---------------|
| 2026-02-09 | Agent 1 | **Phase 1 Backend — COMPLETE.** SQL migration with RLS + indexes + cron jobs, seed data, all 6 Edge Functions (data-fetcher, content-generator, content-reviewer, notification-sender, matchday-scheduler, health-check), shared utilities (types.ts, supabase-client.ts, claude-client.ts, anti-spam.ts), .env.example. ~3,300 lines across 12 files. |
| 2026-03-25 | — | Merged all code from `claude/review-repo-setup-TCJ11` into `main`. All work now on `main` branch. |
| 2026-03-25 | Agent 2 | **Phase 2–3 iOS — COMPLETE.** App entry point (GoalDiggerApp + AppDelegate with APNs deep link), 3 models (Team, ContentItem with Contract 3 dual-format decoder, AppState), design system (Theme.swift with full color/font/spacing), MockData (5 golden examples), 3 onboarding views, FeedView with cache-first loading + pagination + freshness cards + skeleton loading, ContentDetailView with talking points + Contract 8 post-match cheat sheet + ShareLink, SettingsView with team switch + notification status + AboutView, 4 shared components (ContentCard, BadgeView, TeamPickerCard, EmptyStateView), APIClient (4 Supabase REST endpoints per Contract 5), CacheService (SwiftData), NotificationService. 20 Swift files, ~1,400 lines. |

---

## Rules

1. **Before starting work:** Read this file. If an area says "IN PROGRESS", do not work on it.
2. **When starting work:** Update the status to "IN PROGRESS" with your agent name, commit & push.
3. **When done:** Set status to "DONE", add entry to Completed Work Log with date and summary, commit & push.
4. **When blocked:** Mark the task as "BLOCKED: [reason]" in the table, add to Blocked Items section, and move on to the next available task. Never stop the entire build for a single blocker.
5. **Conflicts:** If two agents accidentally work on the same area, the one who committed first wins. The other agent rebases or discards.
6. **Dependencies:** Backend must be deployed before iOS networking layer can be tested. iOS UI can be built in parallel using mock data.

---

## Architecture Quick Reference

- **Backend:** Supabase Edge Functions (TypeScript/Deno)
- **iOS:** Swift 5.9+ / SwiftUI / iOS 17+
- **AI:** Anthropic Claude API (Sonnet)
- **Data:** API-Football (RapidAPI) + RSS feeds
- **DB:** PostgreSQL via Supabase
- **Notifications:** APNs
- **Analytics:** TelemetryDeck

See `BUILD_PLAN.md` for full specifications.
See `AGENT_CONTRACTS.md` for detailed inter-agent contracts and data formats.
