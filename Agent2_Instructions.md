# Agent 2 Instructions — iOS Agent

## Your Role

You are **Agent 2 (iOS Agent)** for the **Goal Digger** project. You build the SwiftUI iOS app. You work in parallel with other agents (Backend and Pipeline) who you never communicate with directly — `AGENT_CONTRACT.md` and `AGENT_CONTRACTS.md` are your only interface.

**Branch:** All code is on `main`.

## Project Summary

Goal Digger is a $10 iOS app for girlfriends (or anyone) who want to connect with their football-loving partner. It delivers push notifications with Premier League news and match-day talking points written in a warm, conversational tone — "like your best friend who happens to know about football."

The user picks one of 3 teams (Arsenal, Man United, West Ham). A backend pipeline fetches football news, runs it through Claude to generate girlfriend-friendly content, reviews it with 3 AI bots, then pushes it to users. The iOS app displays a feed of these content items, each with a headline, body, and "things to say" talking points.

## Your Scope

**You ONLY touch files inside `GoalDigger/ios/GoalDigger/`.** Never create or modify anything in `GoalDigger/backend/` or root-level docs.

You do NOT call the Claude API. All AI processing is server-side. You only call Supabase REST endpoints as defined in Contract 5 of AGENT_CONTRACTS.md.

## Every Run — Do This First

1. **Read `AGENT_CONTRACT.md`** — check what's done, in progress, and blocked
2. **Pick the next incomplete task** from the checklist below (top to bottom)
3. **Mark it "IN PROGRESS"** in `AGENT_CONTRACT.md` with your agent name, commit & push
4. **Do the work**
5. **When done:** update `AGENT_CONTRACT.md` — mark task "DONE", add entry to Completed Work Log with today's date and summary
6. **Commit everything** (code + updated AGENT_CONTRACT.md) and push

## When Blocked

If a step requires something missing (backend not deployed, missing credentials, depends on another agent's work):
1. Mark the task as "BLOCKED: [reason]" in `AGENT_CONTRACT.md`
2. Add it to the Blocked Items table in `AGENT_CONTRACT.md`
3. **Skip to the next task that CAN be done**
4. Never stop the entire build for a single blocker

## Required Reading (in this order)

1. **AGENT_CONTRACTS.md** — Defines every contract between you and the backend. Focus on:
   - Contract 2: Push notification APNs payload format
   - Contract 3: Matchday JSONB storage (dual-format talking_points decoder)
   - Contract 5: Supabase REST API endpoints your APIClient calls
   - Contract 8: Post-Match Cheat Sheet UI styling
   - Contract 9: Health Check Endpoint

2. **BUILD_PLAN.md** — Your full spec with exact colors, fonts, spacing, and layouts:
   - Phase 2 (Steps 2.1–2.6): Architecture — models, APIClient, cache, push handling, navigation
   - Phase 3 (Steps 3.1–3.9): UI — design system, onboarding, feed, detail view, settings
   - Phase 4 (Steps 4.1–4.4): Integration testing checklist

3. **CONTENT_EXAMPLES.md** — The 5 golden examples. Use these as mock data so you can build and test the full UI without waiting for the backend.

4. **PRD.md** — Product overview if you need broader context on the "why."

## Task Checklist

Work through these in order. Skip any that are blocked. Only complete ONE task per run.

### Phase 2 — iOS Foundation
- [ ] I1: Xcode project structure, directory tree, iOS 17+ target at `GoalDigger/ios/GoalDigger/`
- [ ] I2: Models — `Team.swift`, `ContentItem.swift` (with Contract 3 dual-format decoder), `AppState.swift`
- [ ] I3: Design system — `Theme.swift` (exact colors, SF Rounded fonts, layout constants, CardStyle modifier)
- [ ] I11: Mock data — all 5 golden examples from CONTENT_EXAMPLES.md as `MockData.swift`

### Phase 3 — iOS Views
- [ ] I6: Onboarding flow (Welcome, TeamSelection, NotificationPrompt)
- [ ] I7: FeedView (main content feed)
- [ ] I8: ContentDetailView (full content with talking points)
- [ ] I10: SettingsView
- [ ] I12: Shared components — ContentCard, BadgeView, TeamPickerCard, EmptyStateView, GoalDiggerApp entry point

### Phase 2 — iOS Services
- [ ] I4: APIClient (Supabase REST per Contract 5 — skip if backend not deployed, use mock data)
- [ ] I5: CacheService (SwiftData)
- [ ] I9: Push notification handling (AppDelegate + NotificationService)

### Phase 4 — Polish & Integration
- [ ] I13: Bug fixes, code review, spec compliance
- [ ] Connect to live Supabase backend (depends on backend deployment)
- [ ] Test push notifications end-to-end (needs APNs creds — skip if missing)
- [ ] Polish animations and transitions
- [ ] Test on multiple iPhone sizes

## Key Technical Decisions

- **iOS 17+ minimum** — enables @Observable, NavigationStack(path:), SwiftData, .sensoryFeedback
- **Zero third-party dependencies** in v1 — no SPM packages, no CocoaPods
- **SwiftData** for local cache (not Core Data, not SQLite)
- **@Observable** for state management (not ObservableObject/Combine)
- **NavigationStack with NavigationPath** for programmatic deep link navigation
- **UserDefaults** for simple preferences (selected team, onboarding status)
- **SF Rounded** font throughout — never use a blocky or condensed font
- **Warm color palette** — if it looks like ESPN, it's wrong. If it looks like Headspace, it's right.

## Design System

### Colors
| Token | Hex | Usage |
|-------|-----|-------|
| appBackground | #FAF8F5 | Warm off-white, main background |
| cardBackground | white | Card surfaces |
| feedDivider | #F0ECE6 | Subtle warm gray dividers |
| textPrimary | #1A1A1A | Near-black body text |
| textSecondary | #8A8480 | Warm gray labels |
| textTertiary | #B8B2AA | Timestamps, hints |
| accentWarm | #D4956A | Terracotta — primary accent, CTAs, badges |
| accentSoft | #E8CEB8 | Lighter warm — news badge background |
| accentGreen | #7DB07E | Sage green — matchday badge |
| cardShadow | black 4% | Subtle card shadow |
| shimmer | #F5F0EA | Skeleton loading placeholder |

### Typography (all SF Rounded)
| Token | Style |
|-------|-------|
| onboardingTitle | .largeTitle, bold |
| onboardingBody | .body, regular |
| feedHeadline | .body, semibold |
| feedTimestamp | .caption, medium |
| feedBadge | .caption2, bold |
| detailTitle | .title2, bold |
| detailBody | .body, regular |
| talkingPointText | .callout, medium |
| settingsItem | .body, regular |

### Spacing
| Constant | Value | Usage |
|----------|-------|-------|
| screenPadding | 20pt | Horizontal screen edges |
| cardPadding | 16pt | Inner card padding |
| cardSpacing | 12pt | Between cards in feed |
| cardCornerRadius | 16pt | All card corners |
| cardShadowRadius | 8pt | Shadow blur |
| cardShadowY | 4pt | Shadow offset down |
| sectionSpacing | 24pt | Between major sections |
| elementSpacing | 8pt | Between small elements |

## Design Philosophy

The app must NOT look like a sports app. It should look like it belongs next to Headspace and Pinterest on her home screen.

**Reference apps:** Clue, Headspace, Locket, Duolingo, The Skimm.
