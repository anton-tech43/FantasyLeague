# GoalDigger

A free iPhone app for the person who lives with a football obsessive: she follows his Premier League club (and its cup and European nights) so she can join the conversation without becoming a fan. Positioning line: the app she opens before matchday. What is live right now: [STATUS.md](./STATUS.md).

---

## 👋 New here? Read in this order

1. **[STATUS.md](./STATUS.md)**: what is live on the App Store, what is in TestFlight, what is paused, what is open. One page.
2. **[ARCHITECTURE.md](./ARCHITECTURE.md)**: how the app, the backend and the routines actually work. It wins over every older doc.
3. **[CLAUDE.md](./CLAUDE.md)**: the working rules (cost, data trust, security, the shared checkout). Written for agents, binding for humans too.

Then, by task:

| You are about to | Read first |
|---|---|
| trust a number from an upstream feed | [DATA_SOURCES.md](./DATA_SOURCES.md) |
| run anything over more than one team | [BACKFILL_RULES.md](./BACKFILL_RULES.md) |
| fix "the app looks broken" | `./scripts/db-health.sh`, then [RUNBOOK.md](./RUNBOOK.md) and [DB_BASICS.md](./DB_BASICS.md) |
| change iOS code | [IOS_GOTCHAS.md](./IOS_GOTCHAS.md) |
| write My Turn content | [tools/myturn/CONTENT_PRINCIPLES.md](./tools/myturn/CONTENT_PRINCIPLES.md) |
| change who gets which push | [TIERS.md](./TIERS.md) |
| check known issues or security history | [AUDIT_FINDINGS.md](./AUDIT_FINDINGS.md), [CHANGELOG_SECURITY.md](./CHANGELOG_SECURITY.md) |

---

## Repo layout

```
.
├── ios/                       iOS app (Swift + SwiftUI, iOS 17+, iPhone only)
│   └── GoalDigger/
│       ├── App/               AppDelegate, GoalDiggerApp (tabs, deep links)
│       ├── Models/            AppState, Team, MyTurnContent, TierGating, ...
│       ├── Views/             Onboarding/, Feed/, Detail/, Team/, MyTurn/, Player/, Matchday/, Settings/
│       ├── Services/          APIClient, NotificationService, MyTurnStore, AttributionService, ...
│       ├── LiveActivity/      Live Activity manager (plus the widget extension target)
│       ├── Resources/MyTurn/  bundled quiz, lingo, saythis, hype JSON
│       └── Design/            Theme.swift + components
├── backend/supabase/
│   ├── migrations/            001..129, applied by hand (see below)
│   └── functions/             20 Deno Edge Functions + _shared/
├── scripts/                   db-health.sh, verify-cron-auth.sh, rotate-cron-key.sh, ...
├── tools/                     myturn/ (content + validator), audit/, portraits, ...
├── docs/, ops/, audit/        privacy policy draft, ops notes, audit snapshots
└── *.md                       documentation (map below)
```

The claude.ai routines that write the content live in a **separate repo**, [`anton-tech43/goaldigger-routines`](https://github.com/anton-tech43/goaldigger-routines); its README section "Schedules, in one place" lists them. `gd-matchday` and `gd-live-brief` are fired by `match-watcher` rather than a schedule.

---

## Documentation map

### Current
| Doc | What it's for |
|---|---|
| **STATUS.md** | What is true now. One page. |
| **ARCHITECTURE.md** | How it works. The source of truth. |
| **CLAUDE.md** | Working rules and operational notes. |
| **DATA_SOURCES.md** | Which feed fields we trust, field by field. |
| **BACKFILL_RULES.md** | SQL, then routine, then (never in a loop) a paid Edge call. |
| **RUNBOOK.md** | Recovery. The push SOP at the end is current; the V1 scenarios above it are kept for their reasoning. |
| **DB_BASICS.md** | How the database pieces fit, for a non-DBA (Swedish). |
| **MAINTENANCE.md** | The `gd-maintenance` routine's checklist. |
| **IOS_GOTCHAS.md** | iOS and infrastructure traps. |
| **TIERS.md** | Tier and push-volume design, and what is still unbuilt. |
| **AUDIT_FINDINGS.md** | Known issues and the status of earlier findings. |
| **CHANGELOG_SECURITY.md** | Security changes, newest at the bottom. |
| **tools/myturn/*.md**, **tools/audit/README.md** | My Turn editorial rules and the content audit. |
| **docs/PRIVACY_POLICY_DRAFT.md** | The privacy policy text waiting to be published. |

### Shipped designs (still accurate as design records)
CUP_COVERAGE_PLAN.md, HIS_TEAM_PREMATCH_PLAN.md, SCALING_50K.md. EVENT_DRIVEN_TEAM_PAGE.md is designed but deliberately not built.

### Dated reports (true on their date)
BUG_AUDIT_2026-09-23.md, QA_FIX_PLAN_2026-10-04.md, SECURITY_PROBE_2026-10-07.md, SJALVRANNSAKAN_2026-09.md, CONTENT_PUSH_AUDIT_2026-06.md, WC_DATA_AUDIT_2026-06-11.md, and IMPLEMENTATION_PROGRESS.md (the phase log, frozen 2026-06-12).

### Historical (marked at the top of each file)
PRD.md, AGENT_CONTRACTS.md, PROMPTS.md, CONTENT_EXAMPLES.md, APP_STORE_STRATEGY.md, PRODUCT_BRIEF_INTEGRATION.md, BUILD_PLAN.md, V1.1_FEATURE_BUNDLE.md, APP_STORE_V2.0_*.md, V2.1_DESIGN_*.md, V2.2_DESIGN_MULTI_TEAM.md, WHATS_NEW_2.0.3.md, WC_*.md. Read them for intent, never for facts.

---

## Setup for a new local dev

1. **Backend access:**
   - `backend/.env` is gitignored and must exist exactly once, in the root checkout. Get a copy from another contributor (it holds `SUPABASE_URL`, the cron key as `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`, `API_FOOTBALL_KEY`, `SUPABASE_DB_URL`).
   - DB: `set -a && source backend/.env && set +a && /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL"` (`brew install libpq`).
   - Edge Function deploy: `cd backend && supabase functions deploy <name> --project-ref cwgpsmbunrocrofziqad --no-verify-jwt`.

2. **iOS:**
   - Open `ios/GoalDigger.xcodeproj` in Xcode (26+).
   - `ios/GoalDigger/Configuration.xcconfig` is gitignored. Copy from `Configuration.xcconfig.example` and fill in the Supabase publishable key (`sb_publishable_...`).
   - From CLI: `xcodebuild -project ios/GoalDigger.xcodeproj -scheme GoalDigger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`. DEBUG launch arguments (`-gdPresetTeam arsenal`, `-gdTab N`, ...) reach most screens without tapping.

3. **Routines:**
   - Clone [`goaldigger-routines`](https://github.com/anton-tech43/goaldigger-routines) separately.
   - Triggers are configured at `claude.ai/code/routines` (not in either repo).

---

## Conventions worth knowing

- **Voice:** warm, slightly cheeky best friend who happens to know football; never a journalist, never patronising. The live spec is the routines' `PROMPT.md`; the locked brand-voice rule is in ARCHITECTURE.md §1.
- **No em dashes in generated content**: they read as AI. Post-scripts in the routines repo strip them.
- **`[his name]` and `[her name]` placeholders**: iOS substitutes at display time via `AppState.personalise(_:)`. Names never leave the phone.
- **Database access:** the app's publishable key can read published content and call three RPCs; Edge Functions use the service role; pg_cron reads its key from Vault (IOS_GOTCHAS.md §14).
- **Colours:** rose `#E8397D`, deep mauve `#2D1B2E`, soft blush `#FAF0F4`. `Theme.swift` is the source of truth; the brand book lives in the marketing repo.

---

## How to push something live

1. Schema change: write a numbered migration in `backend/supabase/migrations/` and apply it with psql. `supabase db push` does not work here (duplicate numbers, history recorded only to 017). Every new function needs `REVOKE ... FROM PUBLIC, anon, authenticated` (CLAUDE.md).
2. Edge Function change: deploy with `--project-ref cwgpsmbunrocrofziqad --no-verify-jwt`.
3. Routine change: push to `goaldigger-routines`; schedules live at claude.ai.
4. iOS change: bump the build number, Archive, Distribute to TestFlight. What is live and what is waiting: STATUS.md.
