# Agent Contract — Goal Digger Multi-Agent Coordination

**Purpose:** This file is the single source of truth for agent coordination. Each agent updates this file to declare what they are working on, what they have completed, and what is available for others to pick up. Check this file before starting work to avoid conflicts.

---

## Work Ownership Table

| Area | Status | Agent / Branch | Notes |
|------|--------|----------------|-------|
| **Backend: Project structure & scaffolding** | DONE | `claude/review-repo-setup-TCJ11` | Full directory tree created |
| **Backend: SQL schema migration** | DONE | `claude/review-repo-setup-TCJ11` | `001_initial_schema.sql` + RLS + indexes + cron jobs |
| **Backend: Seed data** | DONE | `claude/review-repo-setup-TCJ11` | `seed_teams.sql` (Arsenal, Man Utd, West Ham) |
| **Backend: data-fetcher Edge Function** | DONE | `claude/review-repo-setup-TCJ11` | API-Football (6 endpoints) + 12 RSS feeds + dedup |
| **Backend: content-generator Edge Function** | DONE | `claude/review-repo-setup-TCJ11` | Claude API news generation + anti-spam rules |
| **Backend: content-reviewer Edge Function** | DONE | `claude/review-repo-setup-TCJ11` | 3 parallel review bots + retry logic |
| **Backend: notification-sender Edge Function** | DONE | `claude/review-repo-setup-TCJ11` | APNs JWT auth + token management + quiet hours |
| **Backend: health endpoint** | DONE | `claude/review-repo-setup-TCJ11` | Pipeline monitoring + alert conditions |
| **Backend: matchday-scheduler Edge Function** | DONE | `claude/review-repo-setup-TCJ11` | Daily 07:00 UTC, fixture detection, delayed triggering |
| **Backend: _shared/ utilities** | DONE | `claude/review-repo-setup-TCJ11` | types.ts, supabase-client.ts, claude-client.ts, anti-spam.ts |
| **Backend: .env.example** | DONE | `claude/review-repo-setup-TCJ11` | All env vars documented |
| **iOS: Xcode project setup** | AVAILABLE | — | Not started |
| **iOS: Models (Team, ContentItem, AppState)** | AVAILABLE | — | Not started |
| **iOS: Design system (Theme.swift, Components)** | AVAILABLE | — | Not started |
| **iOS: Onboarding flow** | AVAILABLE | — | Not started |
| **iOS: Feed view** | AVAILABLE | — | Not started |
| **iOS: Detail view** | AVAILABLE | — | Not started |
| **iOS: Settings view** | AVAILABLE | — | Not started |
| **iOS: APIClient / Networking** | AVAILABLE | — | Not started (depends on backend) |
| **iOS: NotificationService** | AVAILABLE | — | Not started |
| **iOS: CacheService (SwiftData)** | AVAILABLE | — | Not started |
| **Docs: README.md** | AVAILABLE | — | Not started |

---

## Completed Work Log

| Date | Agent / Branch | What was done |
|------|----------------|---------------|
| 2026-02-09 | `claude/review-repo-setup-TCJ11` | Read all repo docs (PRD, BUILD_PLAN, PROMPTS, CONTENT_EXAMPLES, RUNBOOK, APP_STORE_STRATEGY). Created this contract file. |
| 2026-02-09 | `claude/review-repo-setup-TCJ11` | **Phase 1 Backend — COMPLETE.** Built full project directory structure, SQL migration with RLS policies + indexes + scheduled cron jobs, seed data, and all 5 Supabase Edge Functions: data-fetcher (API-Football 6 endpoints + 12 RSS feeds + dedup + player filtering), content-generator (Claude API news generation with full prompt templates + anti-spam rules), content-reviewer (3 parallel review bots: tone/accuracy/brevity + retry logic), notification-sender (APNs JWT auth + token lifecycle + quiet hours), health endpoint (per-team monitoring + alert conditions). |
| 2026-02-09 | `claude/review-repo-setup-TCJ11` | **Phase 1 Backend — Extended.** Added matchday-scheduler (daily 07:00 UTC, detects today's fixtures, schedules content 90min before kickoff with pg_cron one-off jobs, handles edge cases). Added shared utilities (_shared/): types.ts (all DB + API types), supabase-client.ts (singleton + pipeline logger + function trigger helper), claude-client.ts (Claude API wrapper), anti-spam.ts (daily limit + gap check + quiet hours + headline dedup). Added .env.example documenting all required secrets. Removed iOS directory (iOS is Agent 2's scope). |

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
