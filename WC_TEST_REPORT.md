# V2.0 World Cup — Test Report for Anton

**Built:** May 17, 2026 (autonomous push)
**Deadline:** June 11, 2026 (World Cup kickoff)
**Status:** ✅ iOS + backend complete, ready for your visual walkthrough + the routines repo work

---

## What's been built

### Backend
- ✅ **Migration 032** applied — `teams` table now polymorphic. 23 PL clubs + 48 WC 2026 countries coexisting.
- ✅ **Migration 033** applied — `device_tokens.country_id` column + nullable `team_id` + partial index. Push routing works for WC-only, PL-only, or both.
- ✅ **`data-fetcher`** deployed (v32+) — picks up `league_id` per team via shared helper. All 48 countries have full squad/fixtures/standings/coaches data.
- ✅ **`team-page-generator`** deployed — all 48 country pages generated. Managers + 3 top players per country, all with photos. Group position labels ("1st in Group D" etc.).
- ✅ **`team-season-state-generator`** deployed — 45/48 countries have `next_fixtures` arrays. 3 awaiting WC schedule from API-Football (Jordan, Paraguay, Qatar).
- ✅ **`match-watcher`** parameterised + deployed — iterates `SELECT DISTINCT league_id FROM teams`, polls both PL (39) and WC (1). Smoke test: `active_leagues: [39, 1]`, `fixtures_seen: 6` (May 17 PL fixtures).
- ✅ **`matchday-scheduler`** parameterised + deployed — same pattern.

### iOS
- ✅ **`Country` enum** — 48 cases with `displayName`, `shortName`, `apiFootballId`, `crestURL`, `confederation` grouping, `searchableText` (with common alt-spellings).
- ✅ **`CountrySelectionView`** — 48 countries grouped by confederation (UEFA/CONMEBOL/CONCACAF/AFC/CAF/OFC), search filter, crests via API-Football CDN.
- ✅ **`OptionalPLTeamView`** — Premier League picker with explicit "Skip — World Cup only" button. Stores `selectedTeam` or sets it to `nil`.
- ✅ **`WCMigrationSheetView`** — modal sheet for V1.x users on app update. Asks "World Cup is coming, who is he backing?" with Skip option.
- ✅ **`MeetTeamView` + `MeetManagerView`** — refactored to accept `entityId: String`. Same view shows either a club or country team page transparently (both come from the `team_pages` table).
- ✅ **`OnboardingFlow`** — reordered to 11 steps. Welcome → Her → His → **Country** → **Optional PL** → Tier → Notif → Calendar → Meet team → Meet manager → How it works.
- ✅ **`AppState`** — `selectedCountry: Country?` + `hasSeenWCPrompt: Bool` + `activeContext` defaults to country (V2.0 puts WC first).
- ✅ **`FeedContext.country(Country)`** case + all exhaustive switches updated.
- ✅ **`APIClient.registerToken`** — accepts both `teamId: String?` and `countryId: String?`. Body only includes set fields (so re-registrations don't accidentally blank existing values).
- ✅ **`FeedView`** — country empty state ("We're warming up his {country} coverage. Check back tomorrow morning.") for the pre-routines-running window.
- ✅ **`TeamPageView`** — handles either club or country IDs via Team/Country lookup.
- ✅ **`URLCache.shared`** — 20MB memory + 100MB disk, configured at launch. Handles 48 flag images on the country picker without network thrash.
- ✅ **Build green.** Welcome screen renders correctly (screenshot captured at `/tmp/wc-screenshots/01-welcome.png`).

### Docs
- ✅ [STATUS.md](./STATUS.md) — updated, marked V2.0 iOS+backend DONE.
- ✅ [IMPLEMENTATION_PROGRESS.md](./IMPLEMENTATION_PROGRESS.md) — Phase 26 closeout appended (lessons #53-#55).
- ✅ [WC_ROUTINES_HANDOFF.md](./WC_ROUTINES_HANDOFF.md) — per-routine spec for what you need to update in the routines repo.
- ✅ This file.

---

## What I need you to test

Run through the onboarding on the simulator and tell me if anything looks off. The build is currently installed on **iPhone 17 Pro simulator** (boot it via `xcrun simctl boot "iPhone 17 Pro"` + `open -a Simulator` if it's shut down).

### Test 1 — Fresh install, WC-only path (the most common new user)

1. Wipe sim: `xcrun simctl erase "iPhone 17 Pro"` (DESTRUCTIVE — only do this on the dev sim)
2. Boot: `xcrun simctl boot "iPhone 17 Pro" && open -a Simulator`
3. Install: `xcrun simctl install booted /tmp/gd-build/Build/Products/Debug-iphonesimulator/GoalDigger.app`
4. Launch: `xcrun simctl launch booted com.goaldigger.app`
5. Walk through:
   - **Welcome** → tap "Let's go"
   - **Her name** → "Emma" → Continue
   - **His name** → "Tom" → Continue
   - **Country selection** ← NEW — confederation sections visible, search works, tap **England** → Continue
   - **Optional PL** ← NEW — should subhead say "Skip if not. We'll focus on his England squad." Tap **"Skip — World Cup only"**
   - **Tier** → pick tier 2 → "Let's do this"
   - **Notifications** → "Yes, keep me posted" (sim may silently deny APNs — fine, doesn't block)
   - **Calendar** → "Yes, add them" → grant permission. Should sync ~3 England fixtures (Burnley/Tunisia/wherever Group C is).
   - **Meet team** ← entity-agnostic — should show England crest, Bellingham/Saka/Foden (whichever 3 the routine picked) with photos, last result mood (or form summary fallback), group position
   - **Meet the boss** ← entity-agnostic — should show Tuchel + summary + photo
   - **How it works** → "Sounds useful" → land on feed
   - **Feed** ← should show "We're warming up his England coverage. Check back tomorrow morning." (because the WC routines aren't producing content yet — that's your routines-repo work)
   - **His Team tab** ← should show England's team page

### Test 2 — Fresh install, BOTH country + PL team

Same as Test 1 but at step "Optional PL" tap **Arsenal** → "Add team". Verify:
- After completion, activeContext defaults to England (country preferred)
- Feed shows country empty state for England
- His Team tab shows England (country preferred over team)
- Switching context (if there's a context switcher visible) shows both available

### Test 3 — V1.x user migration prompt

Easiest way: don't erase the sim — just run on top of an existing V1.x install where `hasCompletedOnboarding=true` and no `selectedCountry`. On launch you should see the **WCMigrationSheetView** sheet — "World Cup is coming. Who is Tom backing?" with an embedded country picker + "Maybe later" button in the top right.

Skip → app proceeds to feed, sheet doesn't reappear next launch.
Pick England → app proceeds, England country is set, sheet doesn't reappear.

### Test 4 — Settings Delete My Data

Verify `clearAllData()` wipes `selectedCountry` and `hasSeenWCPrompt` so the user can re-onboard cleanly with the WC flow.

---

## Known limitations (V2.1 backlog)

- **Empty WC feed until routines run.** The iOS shows the right empty state. Anton's routines-repo work fixes this (see [WC_ROUTINES_HANDOFF.md](./WC_ROUTINES_HANDOFF.md)).
- **3 countries without next_fixtures** — Jordan, Paraguay, Qatar. API-Football hasn't published their WC schedule yet. The daily cron picks them up automatically when API-Football updates.
- **Settings doesn't have a "Change country" UI.** Workaround: Delete My Data → re-onboard. V2.1 will add proper Settings UI.
- **No "show both Meet Club AND Meet Country"** during onboarding. Single Meet pair (country preferred). Acceptable for V2.0.
- **Match-watcher's first invocation logged "Internal Server Error"** for one deploy cycle (now fixed). Lesson #53 in IMPLEMENTATION_PROGRESS.md.
- **App Store review buffer:** submit by **June 4** for a 7-day cushion before June 11 kickoff.

---

## Critical next actions for you

| Action | Owner | Deadline |
|---|---|---|
| Visual walkthrough of all 11 onboarding steps + WC migration sheet — confirm UX | Anton | This week |
| Update Cloud Routine prompts per WC_ROUTINES_HANDOFF.md | Anton (routines repo) | May 30 |
| TestFlight upload of V2.0 build | Anton | June 1 |
| App Store submission | Anton | **June 4** |
| Marketing assets — screenshots of the new WC onboarding | Anton | June 4 |

---

## Diff summary (this push)

```
backend/supabase/migrations/033_device_tokens_country_id.sql  (new)
backend/supabase/functions/_shared/league-helpers.ts         (new)
backend/supabase/functions/data-fetcher/index.ts             (import shared helper)
backend/supabase/functions/match-watcher/index.ts            (parameterised + try/catch)
backend/supabase/functions/matchday-scheduler/index.ts       (parameterised)

ios/GoalDigger/Models/Country.swift                          (confederation grouping added)
ios/GoalDigger/Models/AppState.swift                         (hasSeenWCPrompt + activeContext prefers country)
ios/GoalDigger/App/AppDelegate.swift                         (URLCache.shared config)
ios/GoalDigger/App/GoalDiggerApp.swift                       (RootView WC sheet + His Team country fallback)
ios/GoalDigger/Design/Components/TeamCrestView.swift         (URL + Country init overloads)
ios/GoalDigger/Views/Onboarding/CountrySelectionView.swift   (new — 48 countries by confederation)
ios/GoalDigger/Views/Onboarding/OptionalPLTeamView.swift     (new — picker with Skip)
ios/GoalDigger/Views/Onboarding/WCMigrationSheetView.swift   (new — V1.x users)
ios/GoalDigger/Views/Onboarding/OnboardingFlow.swift         (11-step reorder + entityId passing)
ios/GoalDigger/Views/Onboarding/MeetTeamView.swift           (entityId param)
ios/GoalDigger/Views/Onboarding/MeetManagerView.swift        (entityId param)
ios/GoalDigger/Views/Feed/FeedView.swift                     (country empty state)
ios/GoalDigger/Views/Team/TeamPageView.swift                 (Team/Country lookup)
ios/GoalDigger/Services/APIClient.swift                      (registerToken accepts countryId)
ios/GoalDigger/Services/NotificationService.swift            (passes both IDs)
ios/GoalDigger.xcodeproj/project.pbxproj                     (3 new view files + 1 helper)

STATUS.md                                                    (V2.0 marked DONE)
IMPLEMENTATION_PROGRESS.md                                   (Phase 26 closeout + lessons #53-#55)
WC_ROUTINES_HANDOFF.md                                       (new — your spec)
WC_TEST_REPORT.md                                            (new — this file)
```

Nothing committed yet. Run `git status` and pick a commit strategy when you're ready.
