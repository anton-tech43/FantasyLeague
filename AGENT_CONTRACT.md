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
| **iOS: Xcode project setup (I1)** | AVAILABLE | — | Not started |
| **iOS: Models (I2)** | AVAILABLE | — | Team, ContentItem, AppState |
| **iOS: Design system (I3)** | AVAILABLE | — | Theme.swift — colors, fonts, spacing |
| **iOS: Mock data (I11)** | AVAILABLE | — | Golden examples from CONTENT_EXAMPLES.md |
| **iOS: Onboarding flow (I6)** | AVAILABLE | — | Welcome, TeamSelection, NotificationPrompt |
| **iOS: Feed view (I7)** | AVAILABLE | — | Main content feed |
| **iOS: Detail view (I8)** | AVAILABLE | — | Full content + talking points |
| **iOS: Settings view (I10)** | AVAILABLE | — | Not started |
| **iOS: Shared components (I12)** | AVAILABLE | — | ContentCard, BadgeView, TeamPickerCard, EmptyStateView |
| **iOS: APIClient (I4)** | AVAILABLE | — | Supabase REST (depends on backend deploy for testing) |
| **iOS: CacheService (I5)** | AVAILABLE | — | SwiftData |
| **iOS: NotificationService (I9)** | AVAILABLE | — | AppDelegate + push handling |
| **Pipeline: News generator prompt (P1)** | DONE | Agent 3 | PROMPTS.md Section 1 — verified prompt, tool schema, and backend embedding match all contracts |
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
| 2026-03-25 | Agent 3 | **P1 — News generator prompt: VERIFIED.** System prompt (8 writing rules), user message template (with dedup), tool schema (is_newsworthy, newsworthiness_score 1-10, headline ≤200 chars, 3-5 talking points, emotional_context enum, source_summary). Backend embedding in content-generator/index.ts matches PROMPTS.md Section 1 verbatim. Contract 4 compliance confirmed (newsworthiness_score present, ≥6 threshold enforced by backend). |

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
