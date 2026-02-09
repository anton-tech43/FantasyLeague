# Agent Contract — Goal Digger Multi-Agent Coordination

**Purpose:** This file is the single source of truth for agent coordination. Each agent updates this file to declare what they are working on, what they have completed, and what is available for others to pick up. Check this file before starting work to avoid conflicts.

---

## Work Ownership Table

| Area | Status | Agent / Branch | Notes |
|------|--------|----------------|-------|
| **Backend: Project structure & scaffolding** | IN PROGRESS | `claude/review-repo-setup-TCJ11` | Creating directory layout, config files |
| **Backend: SQL schema migration** | IN PROGRESS | `claude/review-repo-setup-TCJ11` | `001_initial_schema.sql` + seed data |
| **Backend: data-fetcher Edge Function** | IN PROGRESS | `claude/review-repo-setup-TCJ11` | API-Football + RSS feed fetching |
| **Backend: content-generator Edge Function** | IN PROGRESS | `claude/review-repo-setup-TCJ11` | Claude API content generation |
| **Backend: content-reviewer Edge Function** | IN PROGRESS | `claude/review-repo-setup-TCJ11` | 3 parallel review bots (tone, accuracy, brevity) |
| **Backend: notification-sender Edge Function** | IN PROGRESS | `claude/review-repo-setup-TCJ11` | APNs integration |
| **iOS: Xcode project setup** | AVAILABLE | — | Not started |
| **iOS: Models (Team, ContentItem, AppState)** | AVAILABLE | — | Not started |
| **iOS: Design system (Theme.swift, Components)** | AVAILABLE | — | Not started |
| **iOS: Onboarding flow** | AVAILABLE | — | Not started |
| **iOS: Feed view** | AVAILABLE | — | Not started |
| **iOS: Detail view** | AVAILABLE | — | Not started |
| **iOS: Settings view** | AVAILABLE | — | Not started |
| **iOS: APIClient / Networking** | AVAILABLE | — | Not started |
| **iOS: NotificationService** | AVAILABLE | — | Not started |
| **iOS: CacheService (SwiftData)** | AVAILABLE | — | Not started |
| **Docs: README.md** | AVAILABLE | — | Not started |

---

## Completed Work Log

| Date | Agent / Branch | What was done |
|------|----------------|---------------|
| 2026-02-09 | `claude/review-repo-setup-TCJ11` | Read all repo docs (PRD, BUILD_PLAN, PROMPTS, CONTENT_EXAMPLES, RUNBOOK, APP_STORE_STRATEGY). Created this contract file. Starting Phase 1 backend implementation. |

---

## Rules

1. **Before starting work:** Check this file. If an area says "IN PROGRESS", do not work on it.
2. **When starting work:** Update the status to "IN PROGRESS" with your branch name, commit & push.
3. **When done:** Move the entry to "COMPLETED" in the log, set status to "DONE", commit & push.
4. **Conflicts:** If two agents accidentally work on the same area, the one who committed first wins. The other agent rebases or discards.
5. **Dependencies:** Backend must be built before iOS networking layer. iOS UI can be built in parallel with backend using mock data.

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
