# GoalDigger

The companion app that helps girlfriends understand their partner's football team. iOS-first. Premier League today, World Cup support landing June 11, 2026.

---

## 👋 New here? Read in this order

1. **[STATUS.md](./STATUS.md)** — where the project is right now, what's done, what's coming. One page, 2-minute read.
2. **[PRD.md](./PRD.md)** — what the product is, who it's for, voice and tone.
3. **[IMPLEMENTATION_PROGRESS.md](./IMPLEMENTATION_PROGRESS.md)** — phase-by-phase log of what's been built (1800+ lines, scan the table of contents). Phase 24+ is current work.

If you're picking up a specific area of the codebase, jump straight to the relevant phase in `IMPLEMENTATION_PROGRESS.md`. Each phase has a "Where we are at end of day" summary at the bottom.

## 🚨 Before any data backfill or cross-team script: [BACKFILL_RULES.md](./BACKFILL_RULES.md)

Short decision tree (SQL → routine → API-billed Edge Function). Read it before firing anything that touches more than one team. The May 20, 2026 incident that prompted it is logged as Lesson 73 in `IMPLEMENTATION_PROGRESS.md`.

---

## Repo layout

```
.
├── ios/                       iOS app (Swift + SwiftUI, iOS 17+)
│   └── GoalDigger/
│       ├── Models/            domain types (Team, Country, FeedContext, ContentItem, ...)
│       ├── Views/             SwiftUI views (Onboarding/, Feed/, Detail/, Settings/, Team/)
│       ├── Services/          APIClient, NotificationService, CalendarSyncService, ...
│       ├── Design/            Theme.swift + Design/Components/
│       └── App/               AppDelegate, GoalDiggerApp
├── backend/
│   └── supabase/
│       ├── migrations/        SQL schema (numbered 001..032+)
│       └── functions/         Deno Edge Functions
│           ├── data-fetcher/             API-Football + RSS ingestion
│           ├── content-generator/        Daily news (legacy — most content is from Cloud Routines now)
│           ├── team-page-generator/      "His Team" reference page
│           ├── team-season-state-generator/  Season-state primer + next-fixtures
│           ├── match-watcher/            Polls fixtures, fires gd-matchday on FT
│           ├── notification-sender/      APNs push delivery
│           └── ...
└── *.md                       project documentation (this file + 13 others)
```

The Cloud Routines (gd-news, gd-matchday, gd-saturday-quiz, gd-sunday-brief, gd-insider, gd-player-dossier, gd-live-brief, gd-season-state) live in a **separate repo**: [`anton-tech43/goaldigger-routines`](https://github.com/anton-tech43/goaldigger-routines). They produce most user-facing content and write back via Supabase REST.

---

## Documentation map

### Active references
| Doc | What it's for |
|---|---|
| **STATUS.md** | Current state. One page. Updated every phase. |
| **PRD.md** | Product requirements + voice + persona. The "why". |
| **IMPLEMENTATION_PROGRESS.md** | Phase-by-phase log. The "what we did". |
| **AGENT_CONTRACTS.md** | Data contracts between agents/services + security boundaries. |
| **PROMPTS.md** | System prompts for every LLM-driven surface. |
| **RUNBOOK.md** | Ops — pipeline reliability, error recovery, common failures. |
| **IOS_GOTCHAS.md** | Tribal knowledge for iOS — quirks, traps, workarounds. |
| **CONTENT_EXAMPLES.md** | Golden examples of approved content (voice benchmarks). |
| **APP_STORE_STRATEGY.md** | Listing copy, screenshots, ASO. |

### Historical references (still in repo for audit trail)
| Doc | Why it's still here |
|---|---|
| **BUILD_PLAN.md** | Original April 2026 build plan. V1.0 is feature-complete; this is the audit trail of how we got there. |
| **V1.1_FEATURE_BUNDLE.md** | V1.1 task tracker — Insider, Sunday Brief, Saturday Quiz, Player Dossier, Live Brief, Season Primer. All shipped May 12-13. |
| **PRODUCT_BRIEF_INTEGRATION.md** | April 2026 — mapping of the product brief into the existing build plan. |
| **CHANGELOG_SECURITY.md** | Security audit history (key rotations, RLS hardening). |

---

## Setup for a new local dev

1. **Backend access:**
   - `backend/.env` is gitignored. Get a copy from another contributor (it holds `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`, `API_FOOTBALL_KEY`, `SUPABASE_DB_URL`).
   - For DB queries: `psql "$(grep '^SUPABASE_DB_URL=' backend/.env | cut -d= -f2-)" -c "SELECT ..."` (install `libpq` via `brew install libpq`, add to PATH).
   - For Edge Function deploy: `cd backend && supabase functions deploy <name>`.

2. **iOS:**
   - Open `ios/GoalDigger.xcodeproj` in Xcode (requires Xcode 26+).
   - `ios/GoalDigger/Configuration.xcconfig` is gitignored. Copy from `Configuration.xcconfig.example` and fill in your Supabase publishable key.
   - Build for "iPhone 17 Pro" simulator (preferred for parity with the team's test devices).
   - From CLI: `xcodebuild -project ios/GoalDigger.xcodeproj -scheme GoalDigger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

3. **Cloud Routines:**
   - Clone [`goaldigger-routines`](https://github.com/anton-tech43/goaldigger-routines) separately.
   - Routine triggers are configured via `claude.ai/code/routines` (not in either repo).

---

## Conventions worth knowing

- **Voice:** Warm, slightly cheeky best friend who happens to know football. Never journalist, never patronising. See PRD.md §Voice and CONTENT_EXAMPLES.md.
- **No em dashes in generated content** — they read as AI. Post-scripts in the routines repo strip them.
- **`[his name]` and `[her name]` placeholders** — iOS substitutes at display time via `AppState.personalise(_:)`. Routines write the literal placeholder strings.
- **Database access pattern:** Supabase publishable key for iOS reads (RLS-gated public SELECT). Service-role for Edge Functions. Vault-stored secrets for pg_cron (see migration 020).
- **Hot color:** `#E8397D` (rose). Background: `#2D1B2E` (deep mauve). Card surface: `#FAF0F4` (soft blush). Theme.swift is the source of truth.

---

## How to push something live

1. Schema change → write a numbered migration in `backend/supabase/migrations/`. Apply via Supabase Dashboard SQL Editor (preferred for staging) or `supabase db push`.
2. Edge Function change → `cd backend && supabase functions deploy <name>`.
3. Routine prompt change → push to `goaldigger-routines` repo, redeploy via Claude Code routines UI.
4. iOS change → bump build number in Xcode, Archive → Distribute → TestFlight.

App Store submission flow: see APP_STORE_STRATEGY.md. App is currently live at `com.goaldigger.app` v1.0; V2.0 (World Cup) targets June 4 submission for a June 11 launch.
