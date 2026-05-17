# GoalDigger — Project Status

**Last updated:** 2026-05-17 (evening — Phase 27 closeout: push pipeline fix + V2.0 cluster B)

A one-page snapshot of where the project is. For the deep history, see [IMPLEMENTATION_PROGRESS.md](./IMPLEMENTATION_PROGRESS.md) (phase-by-phase log) and [V1.1_FEATURE_BUNDLE.md](./V1.1_FEATURE_BUNDLE.md) (task-level tracker for V1.1 surfaces).

---

## TL;DR

GoalDigger is live on TestFlight (V1.3 build). **World Cup 2026 support (V2.0) is feature-complete** — backend + iOS shipped, build green, migration 034 applied. **Push pipeline was completely dead from May 11 → May 17** (Vault had wrong-shape key, gateway 401'd every cron tick); **fixed today, end-to-end verified**. Remaining work for June 11 launch: Cloud Routine WC variants (separate repo, handed off), TestFlight beta, App Store submission by June 4.

---

## What's done

### Platform — V1.0 (April 2026)
- Full PL companion app: feed, immersive cards, team page, settings, glossary, share cards.
- 20 Premier League clubs supported, daily news + matchday + Saturday quiz + Sunday brief + insider items.
- iOS 17+, Plus Jakarta Sans typography, hot-rose / deep-mauve brand.

### V1.1 content surfaces (May 12-13, 2026)
- **A1 Season Primer** — post-onboarding one-shot screen (later disabled in V1.3).
- **C1 Insider** — daily 02:00 UTC, four-type rotation.
- **C2 Sunday Brief** — Sun 09:00 UTC, T2+ push-gated.
- **C3 Saturday Quiz** — Saturday-themed brief.
- **C4 Player Dossier** — Sun 17:00 UTC, all tiers.
- **C5 Match-day Live** — HT + 75' triggers wired.

### V1.2 Onboarding redesign (May 15, 2026)
Value-first restructure. New order: `Welcome → Her name → His name → Team → Notif → Meet team → How it works → Tier → Calendar`. Three new screens: **MeetTeamView** (star player + result mood + table verdict), **HowItWorksView** (3 scenario cards), **CalendarOptInView** (one-tap fixture sync via existing EventKit service).

### V1.3 Polish (May 15-16, 2026)
- Team crests on team picker + Meet team + Meet boss (via API-Football CDN).
- Meet team three-row guarantee (form_summary fallback when post_match missing).
- SeasonPrimer auto-skipped at end of onboarding (was redundant with Meet team).
- All 20 PL clubs regenerated with manager photos + 3 player photos each.

### V2.0 World Cup support — DONE (May 16-17, 2026)

**Backend (DONE):**
- ✓ Migration 032 — `teams.entity_type` (`club` | `country`) + `teams.league_id`. 48 WC 2026 countries seeded alongside 23 PL clubs in the same table.
- ✓ Migration 033 — `device_tokens.country_id` + nullable `team_id`. Push routing supports WC-only, PL-only, or both.
- ✓ `data-fetcher` parameterised — reads `league_id` per team, calls `seasonForLeague()` helper from `_shared/league-helpers.ts`. All 48 countries have full API-Football data.
- ✓ `team-page-generator` country-aware via `{{league_context}}` template. All 48 country pages generated: manager + 3 top players + photos + group position labels.
- ✓ `team-season-state-generator` country-aware. 45/48 countries have `next_fixtures` arrays (3 awaiting WC schedule from API-Football).
- ✓ `match-watcher` parameterised — reads `SELECT DISTINCT league_id FROM teams`, iterates active leagues. Smoke test: `active_leagues: [39, 1]`, `fixtures_seen: 6`.
- ✓ `matchday-scheduler` parameterised same pattern.

**iOS (DONE — build green):**
- ✓ `Country` enum (48 cases, confederation grouping, `crestURL` via API-Football CDN).
- ✓ `FeedContext.country(Country)` + `AppState.selectedCountry` + `AppState.hasSeenWCPrompt`.
- ✓ `activeContext` default prefers country over team (V2.0 puts WC first).
- ✓ `CountrySelectionView` (48 countries, confederation sections, search), `OptionalPLTeamView` (Skip button), `WCMigrationSheetView` (for V1.x users on update).
- ✓ `MeetTeamView` + `MeetManagerView` entity-agnostic (accept `entityId: String` — works for both club + country IDs via the same `team_pages` table).
- ✓ `OnboardingFlow` reordered: Welcome → Her → His → **Country** → **Optional PL** → Tier → Notif → Calendar → Meet team → Meet manager → How it works (11 steps).
- ✓ `APIClient.registerToken` accepts both `teamId` + `countryId`.
- ✓ `FeedView` empty state for country mode (until routines start producing WC content).
- ✓ `TeamPageView` resolves either Team or Country by ID for the "His Team" tab.
- ✓ `URLCache.shared` configured at launch (20MB memory + 100MB disk) to handle 48 flag images cleanly.
- ✓ All exhaustive switches updated. **Build green.**

### V2.0 closeout cluster (May 17, 2026)
- ✓ Skeptical 2-agent review surfaced 1 critical + 5 high + 4 medium + 3 low bugs across the V2.0 changes. All fixed and deployed.
- ✓ **C1** notification-sender now polymorphically routes by `team_id OR country_id`. WC-only subscribers reach their pushes.
- ✓ **H1** `extractNextFixture` away-game bug (pre-V2.0 latent — always treated team as home). Brighton-away venue now correct.
- ✓ **H5** team-page-generator country pages now have 12h TTL before re-firing Claude (was 1,440 calls/day, now ~48).
- ✓ **M1/M3/L3** match-watcher hardened: skip on null league_id, no stack-trace leak, single teams query.
- ✓ **M2/M4** data-fetcher skips on null league_id; `seasonForLeague(39)` now date-aware (auto-bumps in August).
- ✓ **H2/H3** WCMigrationSheetView promotes activeContext to `.country` immediately; sheet binding handles system dismiss.
- ✓ **H4** UnreadTracker signatures extended for country support.
- ✓ **L1/L2** PlayerCardsList nav falls back to country, OnboardingFlow asserts in DEBUG.
- ✓ Migration 034 — `teams.league_id` is now NOT NULL (DB-level guard).

### Push pipeline fix (May 17, 2026 — Phase 27.3)

**User reported:** "City played, no push." Investigation revealed:
- Every push cron tick since **May 11** returned HTTP 401 "Invalid JWT format".
- `cron.job_run_details` reported `status=succeeded` (pg_cron only checks if the SQL ran, not the HTTP response). Phase 48 documented this exact silent-failure pattern.
- Root cause: Vault entry `cron_service_key` contained the new `sb_secret_*` format key. Edge Function gateway requires JWT-shaped Bearer; new format fails the gateway check.
- **Fix:** `vault.update_secret()` to put the legacy service_role JWT back. Edge Function invocation accepts JWT-format bearers fine — the legacy key was only "rotated" out of PostgREST data writes, not function invocation.
- **Verified end-to-end:** post-fix cron tick returned 200 with match-watcher payload; manual `notification-sender` invocation processed 20 backlog items; `push-probe` to user's production device returned APNs 200.
- **Backlog handling:** items >24h old intentionally NOT pushed (sweep filter is correct — no 5-day-old news).
- **Adjacent finding:** FA Cup Final (Chelsea vs Man City, May 16) was never observed by match-watcher because league=45 isn't in `teams.league_id` set. This is a pre-V2.0 architectural limitation; flagged as V2.1 candidate.

**Pending — handed off to Anton:**
- ⏳ Cloud Routine prompt updates (separate repo `goaldigger-routines`). See [WC_ROUTINES_HANDOFF.md](./WC_ROUTINES_HANDOFF.md) for per-routine spec.
- ⏳ App Store submission (manual Xcode + Apple ID). Target: **June 4** for 7-day review buffer before June 11 kickoff.
- ⏳ Marketing assets (App Store screenshots).

---

## What's coming (next 3.5 weeks)

| Week | Focus | Done by |
|---|---|---|
| **Week 2 (May 17-23)** | ✅ DONE ahead of schedule. iOS V2.0 onboarding + backend parameterisation complete. | May 17 |
| **Week 3 (May 24-30)** | Cloud routine prompt updates (gd-news, gd-matchday, gd-saturday-quiz, gd-sunday-brief, gd-insider, gd-player-dossier, gd-live-brief) for WC variants. See [WC_ROUTINES_HANDOFF.md](./WC_ROUTINES_HANDOFF.md). | May 30 |
| **Week 4 (May 31 – Jun 6)** | TestFlight beta, smoke testing, marketing assets, App Store submission by **June 4** (7-day Apple review buffer). | Jun 6 |
| **June 7-10** | Buffer for review fixes / final polish. | Jun 10 |
| **June 11** | World Cup kicks off. App live. | Jun 11 |

---

## Open risks

1. **API-Football WC 2026 squad data** — final 26-player squads are announced ~2 weeks before kickoff. Plan: hourly `data-fetcher` cron during the last 2 weeks.
2. **Anthropic API rate limits** — 48 countries × multiple daily routines is a significant uplift. Pre-generate static fields once, only regenerate dynamic cards daily.
3. **App Store review delay** — 7-day buffer baked in (submit June 4, tournament starts June 11). If rejected, must turn around inside 5 days.
4. **3 countries with no fixtures yet** — Jordan, Paraguay, Qatar have qualified but API-Football hasn't populated their group stage matches. Daily cron picks them up automatically as the schedule is published.

---

## Architecture decisions worth remembering

- **`teams` is polymorphic** via `entity_type` column. Clubs and countries coexist. All downstream tables (`content_items`, `device_tokens`, `raw_fetch_logs`, `match_status_state`, `team_pages`, `team_season_state`) reference `team_id TEXT` and don't care which type.
- **iOS `FeedContext` is the dispatch layer.** `.team(Team)` for PL, `.country(Country)` for WC, `.everyoneTalking` for cross. Adding a third case (`.nation` was the original code comment) is a compile-time-safe enum extension — no `default:` branches anywhere.
- **API signatures are `String`-typed.** `APIClient.fetchFeed(teamId: String, ...)` accepts either a club ID or country ID. No overloads.
- **Routines self-describe their league context** via `{{league_context}}` template in their system prompt. The wrapper looks up `entity_type` from the team row and injects PL-flavoured or WC-flavoured guidance. Same routine code, two voices.

---

## Pointers

- **Live data:** Supabase project `cwgpsmbunrocrofziqad`, region West EU (Ireland). DB access via local `psql` reading `SUPABASE_DB_URL` from `backend/.env` (gitignored).
- **Push:** APNs via single `.p8` key, production endpoint for App Store builds, sandbox for Debug. Entitlement split via `GoalDigger-Release.entitlements` (added in launch-night work, see Phase 21).
- **Routines repo:** [`anton-tech43/goaldigger-routines`](https://github.com/anton-tech43/goaldigger-routines) (separate from this repo). Cloud Routine prompts + post-scripts live there.
- **App Store:** Bundle ID `com.goaldigger.app`, version 1.0 currently live. WC update will ship as 2.0.
