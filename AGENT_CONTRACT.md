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
| **Pipeline: News generator prompt (P1)** | DONE | Agent 3 | PROMPTS.md Section 1 — v1.1 |
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
| 2026-03-27 | Agent 3 | **P1: News generator prompt v1.1.** Reviewed v1.0 prompt against golden examples and contracts. Expanded writing rules from 8 to 11: split LENGTH into HEADLINE RULES (explicit "never start with team name"), TALKING POINT RULES (ordering: reaction → banter → context → power move), BODY RULES (mandatory partner mood prediction ending, required analogy), and PARTNER CONNECTION rule. All patterns were present in golden examples but not enforced in the prompt. Logged change in PROMPTS.md Section 8. |

---

## Review Notes

### 2026-03-26 — Daily Review (Reviewer & Planner)

**Commits reviewed:** 5 commits from 2026-03-25 (setup day)
- `74af4df` — Added .env.example, .gitignore, BUILD_PLAN.md.backup, DEVELOPMENT_NOTES.md
- `c05cfe0` — Created Agent1_Instructions.md, updated AGENT_CONTRACT.md for main branch
- `3ccd80b` — Created Agent2_Instructions.md, added iOS task IDs (I1-I12)
- `5ecad4f` — Created Agent3_Instructions.md, added Pipeline task IDs (P1-P7)
- `0637396` — Updated model from `sonnet-4-5` to `sonnet-4-6` across 7 files

**Findings:**
- No bugs or spec violations. All changes were documentation and configuration.
- Model version update (`sonnet-4-6`) is consistent across all active files. Only `BUILD_PLAN.md.backup` retains old reference — acceptable.
- No conflicts between agents — no agents have started work yet.
- All agent instruction checklists match the ownership table accurately.
- Blocked items (ANTHROPIC_API_KEY, APNs creds) remain valid — no resolution yet.

**Status:** All Phase 1 backend code is complete but undeployed. iOS and Pipeline work not started. Next priority tasks:
- Agent 1: Deploy database schema to Supabase (Phase 1.5)
- Agent 2: I1 — Xcode project setup
- Agent 3: P1 — News generator prompt

### 2026-03-27 — Daily Review (Reviewer & Planner)

**Commits reviewed:** 1 commit from 2026-03-26
- `fe0a3f6` — Added daily review notes for 2026-03-26 (documentation only)

**Findings:**
- No code changes in the last 24 hours. No bugs, spec violations, or agent conflicts.
- All agent instruction checklists remain accurate and unchanged.
- Blocked items (ANTHROPIC_API_KEY, APNs creds) still unresolved.
- No agents have started work yet — all tasks remain in AVAILABLE/unchecked state.

**Status:** Unchanged from yesterday. All Phase 1 backend code complete but undeployed. iOS and Pipeline work not started. Same priority tasks apply:
- Agent 1: Deploy database schema to Supabase (Phase 1.5)
- Agent 2: I1 — Xcode project setup
- Agent 3: P1 — News generator prompt

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
