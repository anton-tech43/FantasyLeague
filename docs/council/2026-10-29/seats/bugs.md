# Bugs seat, app council 2026-10-29

Scope: the 64 commits since 2026-10-08 on `claude/feature-planning-1q4m3p` (HEAD 376d3f2). Read-only throughout.

**Suites.** `deno test -A` in `backend/supabase/functions`: **301 passed, 0 failed**. `deno check` on match-watcher, matchday-reminder, morning-push, notification-sender, live-match-current, live-brief-current, team-page-generator and data-fetcher: clean. iOS build (`generic/platform=iOS Simulator`, own derived data `dd-bugs`): **BUILD SUCCEEDED**, two benign "explicit return disables result builder" warnings (TeamPageView.swift:675, CountrySelectionView.swift:183).

**Method.** I exported live rows (`match_status_state` for the last 21 days, and the API-Football `fixtures_last` payloads, real round strings included) and ran them through the shipped functions in scratchpad scripts (`bugs/probe1.ts`, `bugs/probe2.ts`). I also compiled the shipped `LiveMatchSnapshot.swift` on macOS (`bugs/swift/`) and fed it the shape `live-match-current` returns for a held tie.

---

## Findings

### 1. MEDIUM · CONFIRMED · The app's own live surfaces undo the held-tie and shootout fix
Census: LOCK-03-09, LOCK-03-10, LOCK-03-11, LOCK-03-16, LOCK-03-18, FEED-01-19.
- **Where:** `ios/GoalDigger/LiveActivity/LiveMatchSnapshot.swift:50` (`case "ET", "BT": return "Extra time"`, and `note: nil` at :59). `LiveActivityManager.swift:207-213`: `startOrUpdate` **overwrites a running activity** with that state on every foreground (at most once a minute). `live-brief-current/index.ts:382,405`: BT returns "BREAK" with the line "Break before extra time." The source is `match-watcher/index.ts:1170`, which stores a held level FT as `BT`.
- **What she sees:** a level League Cup tie that the feed calls "FT" (the Fleetwood v Arsenal case). The server's lock screen correctly reads "Penalties". She opens the app, and her lock screen switches to **"Extra time"**, the false claim a60a474 was written to remove. The in-app live box says "Break before extra time." In a shootout, opening the app wipes the "Shootout: 4-3" note until the next kick changes the server signature.
- **How verified:** the shipped Swift, decoding `{"status":"BT",...}` for fixture 1640386, prints `label: Extra time ... note: nil`. Status `P` prints `note: nil`. The live-brief strings were read in code.
- **Minimal fix:** (a) let `live-match-current` return the label and note match-watcher computed, and have the app use them; or (b) at least do not `update` an existing activity from the snapshot, only start a missing one. In live-brief-current, map a held BT in a single-leg tie to "PENALTIES" or "AFTER 90" with the same `straightToPenalties` rule.

### 2. MEDIUM · SUSPECTED · Matchday › After does not appear in a warm app unless she taps the full-time push
Census: the MD After screen (no MD census rows yet) and FEED-01-58.
- **Where:** `App/GoalDiggerApp.swift:418-422`. `LiveClubPackService.refresh` runs only from `.task(id: selectedTeam)`, which fires once per launch or club change, and from `openMatchday(.after)` at :209-212 (the FT push tap). The scenePhase `.active` handler (:56-70) does not refresh it. `refresh` also skips the fetch when the page was already `fetchedThisLaunch`.
- **What she sees:** she opened the app on Saturday morning and iOS kept it suspended. After the match she opens it from the icon, or reads the FT push on the lock screen and swipes it away. Matchday still holds the morning page with no `last_match` for today, so there is no "After {opponent}" segment and no gold dot. That lasts until iOS kills the app. Visiting His Team refreshes only `TeamPageCache`, not `live.page`.
- **How verified:** code only. Every caller of `live.refresh` was grepped, and there are three. Not reproduced, because that needs a live full time.
- **Minimal fix:** on `.active`, call `live.refresh(team:)` when the cached page is older than about 10 minutes, or always within six hours of the club's last kickoff.

### 3. LOW-MEDIUM · CONFIRMED in code · During a shootout the Live Activity shows a clock running past 120
Census: LOCK-03-04, LOCK-03-10.
- **Where:** `match-watcher/index.ts:2043`. `liveMinute` excludes only HT and BT, so status `P` gets `elapsed` (120 in every live PEN row: 1640388, 1640575) and a `clockStart`. `MatchMinute` (`MatchLiveActivity.swift:156-162`) shows the running timer whenever a clockStart is present, so "Penalties" never shows. The timer counts 120:00, 121:… up to 150.
- **What she sees:** a clock ticking on through the shootout, as if play were still going, above the "Shootout: 4-3" note.
- **Minimal fix:** `liveMinute` only for `1H`, `2H` and `ET`.

### 4. LOW · CONFIRMED (data) · The lineup dry run has recorded nothing
Census: LOCK-02-14.
- **Where:** `match-watcher/index.ts:2214-2226` and `lineupDryRun` at 762-822.
- **Evidence:** `fixture_lineups` has **0 rows** and `pipeline_health` has **0 `starting_xi_fire` rows**. Six fixtures since the deploy fell in the T−75 to T−30 window: Fleetwood v Arsenal on 10-27, and the five League Cup ties on 10-28, which kept league 48 polled from 18:55 UTC (`watch` rows: `fixtures_seen: 5`). Grants, columns and the CHECK constraint are fine. The cause is not known: either the lineups were not out, or something threw. Every exit is silent: "not out yet" returns without a row, and throws only `console.warn`.
- **Why it matters:** IMPLEMENTATION_PLAN_2026-10-27 says Anton will review these lines after the first weekend. As it stands, that review can find nothing and cannot tell "not published" from "broken".
- **Minimal fix:** write a `skipped` row with the reason (lineups not out, or the error) on the last tick before T−30.

### 5. LOW · CONFIRMED · En dashes in the After card
Census: MD After ("Goal scorers", "Three numbers").
- **Where:** `_shared/last-match.ts:203,208,214,241,311,325`. Live data: Liverpool's and Chelsea's `last_match` goal rows read `"1–0 Chelsea"`, and there is "Made it 2–1."
- This is the same class of problem as QA NEW-15 (quiz scorelines), which was fixed. The house rule is no em or en dashes in generated copy.
- **Minimal fix:** use `-`.

### 6. LOW · CONFIRMED in code · The end sweep labels a held tie "Extra time"
- **Where:** `match-watcher/index.ts:694`, `wcStatusLabel(st.status)`. When the six-hour give-up ends a held `BT` activity, the last frame says "Extra time" with the 90-minute score, for 60 s.
- **Minimal fix:** the same label rule as finding 1.

### 7. LOW · CONFIRMED in code · A two-club device in a derby gets the home side's push
- **Where:** `match-watcher/index.ts:505` ("prefer home") together with `AppDelegate.swift:133`. Take a device following `{arsenal, liverpool}` (one live device) for Liverpool v Arsenal. She gets Liverpool's perspective copy ("Won…" when Arsenal lost), and the tap opens Liverpool's feed instead of Arsenal's Matchday › After.
- **Minimal fix:** prefer the device's first followed club, `team_ids[0]`.

### 8. LOW · CONFIRMED in code · `et_trace` rows for fixtures that have already finished
- **Where:** `match-watcher/index.ts:1354-1358`. Raw `AET` and `PEN` qualify, so every finished shootout game is traced again on each tick while another fixture keeps that league and date polled. This adds noise to the table meant to answer "does `score.penalty` move live?".
- **Minimal fix:** drop AET and PEN from the raw list, or require that the prior status is not finished.

Observation for the Connection seat, not a code defect from this window: on 2026-10-24 the scheduler outage stopped observation at 14:08. Arsenal v Everton (1557437, 1-0 at 42') and two other fixtures were reaped to `ABD` at 05:00 on 10-26. Past branch B's six hours nothing re-polls, so those games never got an FT push or an After card.

---

## Open items re-checked

| Item | State today |
|---|---|
| PUSH-4 (no opposite-host retry on a 400) | **Still open** (`apns-client.ts` picks the host from the token's environment only) |
| NEW-9 (he/him in My Turn) | **Still deferred** for the bundled packs. The server HT/FT copy is now clean: 0 he/him in any situation line across 20,400 HT bodies and every FT body rendered from live rows |
| ONB-4 (nudge after declining notifications) | **Fixed on the branch, not shipped**: the Feed banner with "Turn them on" / "Not now" (`FeedView.swift:241-273`) |
| TIERS-6.1/6.2 (significance unread) | **Still unbuilt** (notification-sender never reads `significance`) |
| OPS-1 (`gd-season-state`) | **Writing again**: `team_season_state.generated_at` = 2026-10-29 02:17. I did not check whether its content is 2026-27 |
| OPS-2 (alerts reach nobody) | **Fixed 2026-10-25**: one `dev_alert_devices` row, and the smoke test and the 10-25 16:00 alert were delivered. A same-event twin row at 16:00:00 stayed unalerted (two producers); the 10-23 and 10-24 cron-failure alerts predate the fix |
| PRIV-1 (privacy policy) | **Still open**: `SettingsView.swift:427` opens the carrd home page |
| QA deferred: Meta auto-logging before ATT | **Still as decided** (`AppDelegate.swift:16-17`) |
| QA H6/H7/H8, QA-11, QA-18, the fallbacks | **Hold**: `fetchAllRows` everywhere on the push paths, per-fixture try/catch, `isTokenDead` narrowed, derby dedupe in matchday-reminder (`remindedByFixture`) |
| Prep cron hours (QA medium) | **Hold**: `0 8,9`, still paused (`active=f`) |
| BUG_AUDIT_2026-09-23 B1-B6 | Closed. Not re-tested on a simulator this run |
| Hand-off "left" items | **Still open**: the widget "/ 90" is decided at the last push (`MatchLiveActivity.swift:175`), mononym `known_as`, the pre-match verdict uses May's table |

## What holds up

- **Held-tie logic (3880ce0, a60a474, mig 145).** It is applied in production: `poll_leagues` has branch D, the reaper spares BT rows under 14 h, and anon cannot execute `poll_leagues`. The cron gate `match_watcher_tick()` reads `poll_leagues`, so branch D does wake the watcher. On live data, Liverpool v Chelsea (PEN 6-5) and Man City v Brighton (PEN 4-3) were held and then pushed correctly at 22:13.
- **`straightToPenalties` and `isSingleLegTie`** are correct for every live round string ("Round of 16/32/64/128", "Quarter-finals", "League Stage - n", "Regular Season - n"). The feed's `elapsed: 120` with `extratime: null` on straight-to-pens ties does not leak "after extra time" into the FT copy: PEN wins over `extraTime`.
- **FT copy on all 22 live finished rows × 40 seeds:** no dashes, no placeholders, no "drew" after a shootout, no he/him before "Say:". The HT copy across 20,400 renders: none over the 178-character budget.
- **`shootoutNote`, `renderExtraTimePush` and `resultStillNews`** behave on real kickoffs: 22:13 is news, 23:31 is not, and five hours after kickoff is not.
- **The ET push** fires only on the feed's own ET, on two ticks, at most 100 minutes in, in single-leg ties, and is marker-claimed.
- **Priority 5 for minute-only Live Activity updates:** the `minuteOnly` test survives notes that contain hyphens, because the minute is always the last segment.
- **Push tap routing:** `live-ft-` goes to After, `myturn-prep` goes to Before, and both fall back to the club feed for her second club. `pushKind` covers `live-et-`.
- **matchday-reminder:** early cup rounds are skipped by the same tier rule, kickoff is rendered in the device's zone, and a device in a derby gets one push. Missing reminders on 10-27 and 10-28 are the early-round rule; on other days they are clubs nobody follows.
- **`poll_leagues()` is quiet right now** (0 rows), and no active club has a stale fixture feed (branch C is empty).

## Summary
1. Suites are green (301 Deno tests, the iOS build, `deno check` on 8 functions). Live strings through the shipped push copy found no copy defects.
2. MEDIUM, confirmed: the app's Live Activity foreground sync and the feed live box still say "Extra time" / "Break before extra time" for a held tie, and wipe the shootout note. This undoes part of a60a474.
3. MEDIUM, suspected: Matchday › After only refreshes on launch, club change or an FT push tap, so in a warm app the After card may never appear.
4. LOW: a running clock during shootouts; a lineup dry run with 0 rows and silent failures; en dashes in the After card; the derby perspective for two-club devices; trace noise.
5. Open items: PUSH-4, PRIV-1, TIERS-6 and NEW-9 (packs) are still open. ONB-4 is fixed on the branch. OPS-2 was fixed on 10-25, and OPS-1's routine is writing again.
