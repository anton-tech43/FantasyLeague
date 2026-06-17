# AUDIT FINDINGS — senior-dev skeptical review (2026-06-17)

Whole-codebase review (6 parallel subsystem audits): push pipeline, iOS onboarding +
registration, content pipeline + routines/prompts, iOS feed/team-page/services, DB/RLS/
security, docs-vs-reality. Each finding: **severity · confidence · file:line · problem →
fix**. How the app actually works is in `ARCHITECTURE.md`.

Confidence is the auditor's; treat <0.7 as "verify before acting". Several findings were
cross-checked and confirmed against the code during synthesis.

---

## ✅ Fixed this session

| ID | Area | What | Where |
|---|---|---|---|
| FIX-1 | iOS feed | `affected_team_ids`/`preview_fixture_id` missing from `contentSelectColumns` → the V2.0 crest header **never rendered** from feed/push deep-links. Added them. | `Services/APIClient.swift:107` |
| FIX-2 | iOS multi-team | Foreground resume hard-reset `activeContext` to the FIRST entity, snapping a 2-team user off their 2nd tab. Now only repairs an *invalid* context. | `App/GoalDiggerApp.swift:16` |
| FIX-3 | iOS cleanup | Deleted dead `TeamSelectionView` (V1 picker, unreachable) + its 4 pbxproj refs + stale comment. | (removed) |
| FIX-4 | routines | "World Cup" → "World Championship" leak in app-visible generated copy. Added deterministic substitution to `post_news.sh` + `post_quiz.sh` and a naming rule to `PROMPT.md`. **Needs a push to the routines repo to go live.** | `goaldigger-routines` |
| FIX-5 | iOS multi-team | `UnreadTracker` aggregate now counts every followed entity, not just the primary (committed earlier this session). | `Services/UnreadTracker.swift` |

---

## 🟢 HIGH list — resolution (worked down this session)

| ID | Status | What was done |
|---|---|---|
| SEC-1/2/3 | **Fix built + staged** | `register_device_token`/`register_la_token` SECURITY DEFINER RPCs (mig 071, applied + rollback-tested); iOS migrated to call them; the anon-access **drop** is staged as `072_...PENDING_APP_RELEASE` (non-`.sql`, apply after the RPC build is live — dropping now would break the currently-live app's direct-upsert registration, mig 030). Closing the read also defangs the tamper. |
| PUSH-1 | **Done (deployed)** | Reaper cron `match-status-reaper` (mig 073, applied). Dry-run found exactly 1 stuck row (29-day-old); live match correctly untouched. |
| PUSH-2 | **Done (deployed)** | match-watcher now persists state then fires alerts (collect-then-fire-after-upsert). At-most-once. |
| COST-1 | **Done (deployed) — was a prod no-op** | The flagged weekly cron does NOT exist in `cron.job` (verified; `app.settings` unset) → live spend was $0. Added a code guard refusing `full` + no `team_id`, enforcing the rule permanently. |
| COPY-1 | **Mechanism + functional copy done; brand voice flagged** | Added `personName`/`personPossessive[Cap]` to AppState (relationship-aware, name-first, gender-neutral). Routed the functional offenders (TeamPageView "Ask him"/"THINGS HE…", FeedView, PlayerCardView, MeetTeamView, HowItWorks, onboarding search/skip/squad copy) through them. **Left** the deliberate girlfriend↔boyfriend brand taglines (`WelcomeView` "He has no idea", `SettingsView` "Made for her, not him", "The one he brags about") — fully neutralizing the brand voice (or dropping the relationship picker) is a product decision for the user. |

## 🟢 MEDIUM / LOW — resolution (same session)

**Done (deployed / built):** SEC-6 (delete-my-data clears the LA token; +iOS sends it),
PUSH-3 (`deactivateTokenIfDead` across match-watcher/morning-push/matchday-reminder),
PUSH-8 (morning-push skips WC country fixtures), SCHED-1 (matchday-scheduler skips
countries), PUSH-6 (LA content-state type synced), CONTENT-2 (deleted dead
`post_sunday_briefs.py`), CONTENT-7 (stale dormant-cron header fixed), ONB-3 (token
redrive at completion), ONB-6 (tier restore on appear), ONB-8/ONB-10 (stale comments),
ONB-9 (dead keys dropped + LA token cleared), iOS-4 (dead poll task removed), iOS-6
(switcher crests), iOS-7 (country-picker context repair), iOS-8 (quiz index crash guard),
iOS-9 (WC-only empty-state button). Plus the pre-existing `morning_push` stage-union
type error.

**Not needed:** SEC-4 — the orphaned `on_device_token_insert` trigger/function from
mig 004 **don't exist** in the live DB (verified). SEC-7 — legacy JWTs already rotated/
disabled; just confirm in the dashboard.

**Deferred (rationale):**
- **PUSH-4** (env-mismatch 400 → retry opposite host): rare (env is build-config-driven);
  a larger APNs-client change. Worth doing if 400-deactivations show up in `pipeline_health`.
- **CONTENT-6** (PL roster drift): needs a decision on the canonical season — it's between
  the 2025-26 and 2026-27 rosters, and PL is paused during the WC. Reconcile teams table +
  schema.json + post_news.sh together when the 2026-27 season is set.
- **ONB-5** (footballKnowledge unused) / **ONB-4** (denied-user re-prompt banner): product
  decisions (wire the signal vs drop the step; add a nudge UI).
- **CONTENT-5** (feed floor >24h), **iOS-3** (per-entity unread lists): feature work.
- **CONTENT-4** (content-reviewer retry), **CONTENT-8/9/10**, **PUSH-5/PUSH-9**, **SEC-5**:
  low value and/or dormant paths; safe to leave. **SEC-8** (local xcconfig may hold a legacy
  anon key): user action — verify the publishable key is in `Configuration.xcconfig` and the
  legacy anon key's dashboard state before the next archive.

Remaining detail of each finding below is preserved for reference.

## 🔴 HIGH — open

- **PUSH-1 · 0.8 · `match-watcher/index.ts:1249` (+ mig 007).** No reaper for
  `match_status_state`. A fixture that stops being returned by the API while still
  `1H`/`2H` stays "live" forever → if the feed resumes it can fire a **phantom goal /
  late FT push**, and a stuck `la_started=true,la_ended=false` row means the Live
  Activity is never server-ended. (The in-app live box self-heals via the kickoff_time
  window.) → **Fix:** daily reaper cron flipping non-terminal rows with `kickoff_time <
  now()-interval '4 hours'` to a terminal sentinel + END their Live Activities. Safe/
  additive (4h is well beyond any match incl. ET+pens).
- **PUSH-2 · 0.85 · `match-watcher/index.ts:1136-1232` vs `:1249`.** WC goal/HT/FT
  pushes fire **before** the end-of-tick upsert; the only idempotency guard is that the
  upsert advances score / appends `*_PUSH` markers. If the upsert fails (caught,
  non-fatal), the next tick re-detects and **re-sends** — duplicate goal/FT alerts. →
  **Fix:** claim the marker first (conditional `UPDATE ... WHERE NOT marker` returning
  whether this tick won) then send only if claimed; or treat an upsert failure as
  fatal-for-fixture + alert.
- **COST-1 · 0.9 · `mig 004_seed_all_pl_teams.sql:372-383` + `team-page-generator/index.ts:313`.**
  A weekly `team-page-refresh` cron runs `team-page-generator` in `full` mode with no
  `team_id` → loops `callClaude` across ALL ~70 teams (~$3/week, recurring). This is the
  institutionalized version of the CLAUDE.md hard-rule violation. → **Fix:** narrow the
  cron to `dynamic_only` (deterministic, already runs every 2h) and/or PL clubs only, or
  move the weekly full regen to a claude.ai routine. (Migrating team-page-generator to a
  routine is the only remaining API-billed function — already filed in BACKFILL_RULES.)
- **SEC-1 · 0.95 · `mig 030_device_tokens_anon_select.sql:46`.** Anyone with the shipped
  publishable key can `GET /rest/v1/device_tokens?select=*` and read **every** user's
  APNs token + followed team/country + tier + env — a full device→fandom PII graph +
  user-count/churn signal. (A stolen APNs token cannot push — Apple needs the `.p8` — so
  this is PII disclosure, not push-hijack.) Confirmed readable. → **Fix (Wave-2):** move
  register/update behind a SECURITY DEFINER RPC and **drop anon SELECT/UPDATE/INSERT**.
- **SEC-2 · 0.9 · `mig 001:134-137` + trigger `001:140-159`.** anon UPDATE is
  `USING(true)`; the immutability trigger only protects `apns_token`+`is_active`. With
  SEC-1's token list, an attacker can `PATCH ?apns_token=eq.<victim>` to **repoint any
  user's followed countries/clubs/tier** (targeted tamper/DoS of the core feature),
  unauthenticated beyond the public key. → **Fix:** same Wave-2 RPC (writes keyed only
  on the presented token).
- **COPY-1 · 0.95 · `Models/AppState.swift:188`, `HisNameView.swift:79`, many.** The
  relationship picker (partner/parent/sibling/friend) is collected + persisted but
  effectively **dead**: `personalise()` only uses the noun when `hisName` is empty, which
  never happens (name required). Meanwhile onboarding + team-page + feed copy hardcode
  "he/his/him" (e.g. `TeamPageView.swift:387,486`, `FeedView.swift:616`,
  `PlayerCardView.swift:102`, every onboarding screen). A user following a parent/sibling/
  friend reads wrong copy throughout. → **Fix:** wire `relationshipType` into a
  pronoun/noun helper and route the named offenders through it (or, if partner framing is
  intended, remove the picker so you stop collecting an ignored choice). Mind the
  no-em-dash rule when rewording.

## 🟠 MEDIUM — open

- **SEC-3 · 0.85 · `mig 062:43-57`.** `live_activity_tokens` is anon SELECT/INSERT/UPDATE
  with **no** immutability trigger → an attacker who reads a victim's PTS token can flip
  `is_active=false` (kills their Live Activities) or rewrite `country_ids`. → Fold into
  Wave-2 or at minimum protect `is_active`/`kind`.
- **SEC-4 · 0.75 · `mig 004:392-422`.** Orphaned SECURITY DEFINER trigger
  `on_device_token_insert` / `trigger_team_page_for_new_device()` has **no `SET
  search_path`** (every other definer fn locks it) and reads an `app.settings.*` GUC that
  mig 015 says isn't set (→ raises, could abort anon registration). → **Fix:** DROP it
  (team-page gen is driven elsewhere now), or harden (`search_path=''`, schema-qualify,
  NULL-guard the GUC).
- **SEC-6 · 0.85 · `delete-my-data/index.ts:40`.** GDPR delete removes only
  `device_tokens`; a user's `live_activity_tokens` row (different token, holds
  `country_ids`) persists. → **Fix:** also delete LA tokens (client sends its PTS token,
  or store a shared install_id); document `client_errors` retention.
- **PUSH-3 · 0.95 · `match-watcher:291`, `morning-push:200`, `matchday-reminder:203`, LA
  sends.** Only `notification-sender` deactivates dead tokens on 410/400; the four
  direct-APNs senders ignore the result → dead tokens retried on every goal forever; a
  WC-only follower's dead token is never cleaned. → **Fix:** shared deactivation helper
  called from all senders.
- **PUSH-4 · 0.7 · `notification-sender:329-340`.** A sandbox/prod **env mismatch** also
  returns 400 `BadDeviceToken`; treating that as "deactivate forever" can permanently
  silence a valid token. → **Fix:** on 400, retry the opposite APNs host once before
  deactivating; if it accepts, flip `apns_environment`.
- **PUSH-8 · 0.6 · crons 07:00 + 08:00 UTC.** `matchday-reminder` and `morning-push` can
  both alert the same followed country an hour apart (no shared throttle). → **Fix:** gate
  morning-push to clubs, or have it consult `matchday_reminders_sent`.
- **CONTENT-2 · 0.85 · `goaldigger-routines/post_sunday_briefs.py`.** Dead/manual script:
  every hardcoded brief fails its **own** em-dash validator (so it posts nothing), and its
  roster (burnley/leeds/sunderland) FK-mismatches the canonical teams table. Not the live
  path (gd-sunday-brief uses fetch+post_news), but a runnable footgun. → **Fix:** delete,
  or strip dashes before validating + reconcile roster.
- **CONTENT-6 · 0.85 · `post_news.sh:195` vs `schema.json` vs `mig 004:19-26`.** PL roster
  drift: `post_news.sh` uses the 2026-27 promoted set; teams table + schema.json use
  2025-26. The intl-duty/WC-pause push guards silently don't fire for ipswich/leicester/
  southampton. → **Fix:** reconcile all three to the canonical roster.
- **CONTENT-4 · 0.8 · `content-reviewer:307` → `content-generator`.** (dormant path) A
  single-bot failure re-triggers content-generator with `fetch_log_ids:[]` → regenerates
  a **sourceless duplicate** draft, never revising the original. → **Fix:** pass real
  log ids + bot feedback and UPDATE the existing item, or drop the retry.
- **iOS-3 · 0.8 · `UnreadTracker.swift:58` / `FeedView.swift:314`.** Even after FIX-5, the
  aggregate badge computes an inactive team's unread against the **active** team's items
  (only one item-set is loaded) → meaningless count. → **Fix:** load per-entity item sets
  (the deferred "split the lists"), or pass empty arrays for inactive entities.
- **ONB-3 · 0.8 · `OnboardingFlow.swift:160` / `NotificationService.swift:83`.** If the
  APNs token hasn't arrived by `completeOnboarding`, registration no-ops and the user gets
  **no pushes until next launch**. → **Fix:** if token nil but permission granted at
  completion, re-call `registerForRemoteNotifications()`; `handleTokenRegistration`
  (guard now passes) will POST when it lands.
- **SCHED-1 (PUSH-7) · 0.6 · `matchday-scheduler:96`.** No WC short-circuit (match-watcher
  has one) → schedules content-generator for WC fixtures. Low impact while content-gen is
  dormant, but a latent paid-loop trigger. → **Fix:** `continue` on country entities.

## 🟡 LOW — open

- **iOS-4 · 0.85 · `FeedView.swift:40,176,198`.** `liveBriefPollTask` is declared/
  cancelled but **never assigned** — the scenePhase "explicit cancel" is a no-op; the 60s
  poll relies entirely on SwiftUI `.task` cancellation (OS-version-dependent). → Remove the
  dead var or drive the poll via a real assignable `Task`.
- **iOS-8 · 0.6 · `SaturdayQuizCard.swift:189`.** `["A","B","C"][index]` crashes if a quiz
  ever has >3 options (strict decode, server-contract-only guard). → Guard the index.
- **iOS-9 · 0.7 · `FeedView.swift:92`.** Everyone-empty "Back to {team}" is a dead button
  for WC-only users. → Fall back to country / hide when no club.
- **iOS-6 · 0.95 · `ContextSwitcherView.swift:91`.** Switcher rows show text initials, not
  crests, despite the toolbar pill already rendering real crests. → Use `TeamCrestView`.
- **iOS-7 · 0.7 · `SettingsView.swift:628`.** `CountryPickerSheet` can leave a dangling
  `.country(removed)` active context (TeamPickerSheet already repairs). → Mirror the repair.
- **ONB-4 · 0.7 · `NotificationPromptView`.** Denied users go permanently silent, no
  re-prompt anywhere. → Add a dismissible "notifications off" feed banner → Settings.
- **ONB-5 · 0.97 · `OnboardingFlow.swift:172`.** `footballKnowledgeLevel` is a full
  onboarding step gathering data used **nowhere**. → Wire it (content depth/glossary) or
  drop the step.
- **ONB-6 · 0.6 · `TierSelectionView`.** No back-nav state restore (defaults to 2) → a
  back-navigating tier-3 user can be silently downgraded. → `.onAppear { selected = appState.selectedTier }`.
- **ONB-8 · 0.85 · `OnboardingFlow.swift:151`.** New users never see `SeasonPrimerView`
  (its flag is pre-set); the view's own doc claims otherwise. → Reconcile intent/comment.
- **ONB-9 · 0.9 · `AppState.swift:257`.** `clearAllData` removes UserDefaults keys
  (`hasAutoExpandedFirstItem`, `hasSeenImmersiveBanner`) that are never written; Paywall/
  PurchaseManager are parked. → Drop the dead key lines.
- **ONB-10 · 0.7 · `WCMigrationSheetView.swift:13`.** Comment says "no Settings option (V2.1
  will add)" but the Settings country picker exists; comments say "World Cup". → Update.
- **CONTENT-5 · 0.75 · `matchday-reminder:100`.** The deterministic feed floor only fires
  within 24h of a fixture → low-RSS WC countries can have empty feeds on quiet days. →
  Widen the window or add an evergreen "your group / next opponent" card.
- **CONTENT-7 · 0.95 · `team-season-state-generator/index.ts:9`.** Stale header claims a
  cron that mig 022 dropped → a reader could re-invoke it (all-teams paid loop). → Update
  to "DORMANT — use gd-season-state routine".
- **CONTENT-8 · 0.8 · `schema.json` vs `content-generator:233`.** `emotional_context` enum
  diverges between routine and edge → A/B analysis on it is unreliable. → Unify the enum.
- **CONTENT-9 · 0.7 · `data-fetcher:30`.** `TEAM_PLAYERS` RSS filter covers only 3 teams
  and is stale (departed players). → Drop it (rely on name match) or populate from squad data.
- **PUSH-5 · 0.55 · `require-service-auth.ts:50`.** Secret compare via `Array.includes`
  (non-constant-time); cron key accepted everywhere widens blast radius; push-probe uses a
  narrower gate keyed to the disabled legacy JWT. → constant-time compare; standardize gates.
- **PUSH-6 · 0.8 · `apns-client.ts:190`.** `LiveActivityContentState` TS type is stale
  (declares `note`, omits `elapsed`) vs what's actually sent → refactor landmine. → Sync
  the type.
- **SEC-5 · 0.7 · `diagnose-matchday:33`, `push-probe:22`, `register-dev-device:28`.** Gate
  on the disabled-legacy `SUPABASE_SERVICE_ROLE_KEY` only, not `requireServiceAuth`. →
  Standardize on `requireServiceAuth`.
- **SEC-8 · 0.8 · `ios/GoalDigger/Configuration.xcconfig`.** Local working-copy may still
  hold a legacy anon JWT instead of the `sb_publishable_*` key → an archive from this state
  ships the wrong/retired credential. → Update before the next archive; confirm legacy
  anon key status in the dashboard.
- **CONTENT-10 · 0.6 · all `PROMPT*.md`.** Em/en dashes pervade prompt PROSE (not the SHIP
  example strings). Low real risk (post_news.sh strips output). → Optional: dash the prose
  or scope the rule to generated copy.
- **PUSH-9 · 0.5 · `match-watcher:1285`.** `firstSeen` metric can double-count under
  overlapping ticks (no push impact). → Advisory lock per fixture if tightened.
- **SEC-7 · 0.9 (mitigated).** Legacy service_role/anon JWTs are in git history; already
  rotated/disabled 2026-05-11 + pre-commit hook added. → Confirm both legacy keys disabled
  in the dashboard; history rewrite only if policy demands.

---

## Suggested order of attack
1. **SEC-1 + SEC-2 + SEC-3 together** (Wave-2 register RPC + drop anon SELECT/UPDATE) — one
   migration closes the PII leak and the cross-device tamper. Highest real blast radius.
2. **PUSH-1 + PUSH-2** — the two that produce user-visible wrong/duplicate/missing pushes.
3. **COST-1** — stop the recurring weekly API spend.
4. **COPY-1** — the product-correctness gap the relationship picker promises but doesn't deliver.
5. **PUSH-3/PUSH-4** — deliverability decay over time.
6. The MEDIUM/LOW cleanups as capacity allows.
