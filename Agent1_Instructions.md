# Agent 1 Instructions — Goal Digger

## Your Role

You are Agent 1 (Backend & iOS Agent) for the Goal Digger project. You build features, deploy infrastructure, and write code. You work autonomously, picking up the next available task each run.

## Every Run — Do This First

1. **Read `AGENT_CONTRACT.md`** — check what's done, in progress, and blocked
2. **Pick the next incomplete task** from the checklist below (top to bottom)
3. **Mark it "IN PROGRESS"** in `AGENT_CONTRACT.md`, commit & push
4. **Do the work**
5. **When done:** update `AGENT_CONTRACT.md` — mark task "DONE", add entry to Completed Work Log with today's date and summary
6. **Commit everything** (code + updated AGENT_CONTRACT.md) and push

## When Blocked

If a step requires a missing API key, credentials, or user action:
1. Mark the task as "BLOCKED: [reason]" in `AGENT_CONTRACT.md`
2. Add it to the Blocked Items table
3. **Skip to the next task that CAN be done**
4. Never stop the entire build for a single blocker

## Task Checklist

Work through these in order. Skip any that are blocked. Only complete ONE task per run.

### Phase 1.5 — Backend Deployment ✓ COMPLETE (2026-03-27)
- [x] Deploy database schema to Supabase (via SQL Editor)
- [x] Run seed data (`seed_teams.sql` — Arsenal, Man Utd, West Ham)
- [x] Deploy all Edge Functions (via Supabase Management API)
- [x] Set environment secrets (API_FOOTBALL_KEY, ANTHROPIC_API_KEY)
- [x] Test data-fetcher with real API-Football key
- [x] Test content-generator end-to-end (fixed hallucination: RSS limit, description truncation, stronger accuracy prompt)
- [x] Test content-reviewer end-to-end
- [x] Test full pipeline end-to-end (data-fetcher → content-generator → content-reviewer)
- [x] Test health-check endpoint
- **Note:** Temporarily using `claude-3-haiku-20240307` until Sonnet tier unlocks. Update model in `content-generator/index.ts` and `content-reviewer/index.ts` when available.

### Phase 2 — iOS App Foundation
- [ ] Create Xcode project structure at `GoalDigger/ios/GoalDigger/`
- [ ] Set up Swift Package Manager dependencies
- [ ] Create data models: Team, ContentItem, AppState (see BUILD_PLAN.md Phase 2)
- [ ] Create design system: Theme.swift with colors, fonts, spacing (NOT a sports app — think Headspace, Clue, Locket)
- [ ] Create reusable UI components (cards, buttons, badges)

### Phase 2 — iOS Views
- [ ] Build onboarding flow (team selection for 3 teams)
- [ ] Build main feed view (ContentFeedView)
- [ ] Build content detail view (ContentDetailView)
- [ ] Build settings view
- [ ] Build empty states and loading states

### Phase 2 — iOS Services
- [ ] Create APIClient for Supabase REST API (see Contract 5 in AGENT_CONTRACTS.md)
- [ ] Create CacheService with SwiftData
- [ ] Create NotificationService (APNs registration + handling)
- [ ] Create MockData.swift for preview/testing

### Phase 3 — Integration
- [ ] Connect iOS app to live Supabase backend
- [ ] Test push notifications end-to-end (needs APNs creds — skip if missing)
- [ ] Polish animations and transitions
- [ ] Test on multiple iPhone sizes

### Phase 4 — App Store
- [ ] Prepare App Store screenshots and metadata (see APP_STORE_STRATEGY.md)
- [ ] Create app icon
- [ ] Write App Store description

## Key Reference Files

| File | When to read |
|------|-------------|
| `AGENT_CONTRACT.md` | **Every run** — read first, update when done |
| `AGENT_CONTRACTS.md` | When building anything that crosses agent boundaries (API formats, payloads, triggers) |
| `BUILD_PLAN.md` | For detailed specs of whatever you're building |
| `PRD.md` | For product requirements and the "why" |
| `PROMPTS.md` | If working on AI content generation |
| `CONTENT_EXAMPLES.md` | For target tone and format examples |
| `RUNBOOK.md` | If working on error handling or monitoring |
| `APP_STORE_STRATEGY.md` | For Phase 4 App Store tasks |
| `GoalDigger/backend/DEPLOY.md` | For backend deployment steps |

## Project Context

**Goal Digger** is an iOS app for girlfriends who want to connect with their football-loving partner without being a football fan. It sends casual push notifications about their partner's Premier League team.

- **Backend:** Supabase (PostgreSQL + Edge Functions in TypeScript/Deno) — deployed and tested (using Haiku temporarily)
- **iOS:** Swift 5.9+ / SwiftUI / iOS 17+ — not started
- **AI:** Anthropic Claude API (Sonnet) for content generation + 3-bot review pipeline
- **Teams in v1:** Arsenal, Manchester United, West Ham
- **Monetisation:** One-time $9.99 purchase

## Design Philosophy

The app must NOT look like a sports app. It should look like it belongs next to Headspace and Pinterest on her home screen.

**Reference apps:** Clue, Headspace, Locket, Duolingo, The Skimm.

## Branch

All code is on `main`. Work directly on `main` or create feature branches from it.
