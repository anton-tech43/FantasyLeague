# ARCHITECTURE: how GoalDigger actually works

**This is the authoritative "how it works" doc** for the code on this branch. If it
disagrees with `PRD.md`, `AGENT_CONTRACTS.md`, `PROMPTS.md`, `PRODUCT_BRIEF_INTEGRATION.md`
or the V1 parts of `RUNBOOK.md`, **this doc wins**; those are historical. What is live on
the App Store, what is only in TestFlight and what is paused: `STATUS.md`. Known bugs:
`AUDIT_FINDINGS.md`.

References name a file and a symbol rather than a line number, because line numbers drift.
If you change the mechanism, change the sentence. Section numbers are referenced from code
and other docs; do not renumber.

---

## 1. Product framing

A relationship companion: someone follows the football their **partner / parent /
sibling / friend** cares about so they can join the conversation. Football is the
medium, not the point. The followed person is referred to by name; the relationship
noun is a fallback. `AppState.relationshipType` = partner|parent|sibling|friend
(default partner), captured in `HisNameView` and not editable after onboarding. Names
(`hisName`/`herName`) are stored **local-only, never sent to the server**
(`Models/AppState.swift`). Display-time substitution and dash stripping happen in
`AppState.personalise()`.

Voice = warm, cheeky best friend. The live voice spec is the routine prompts in the
**separate `goaldigger-routines` repo** (`PROMPT.md`), NOT this repo's `PROMPTS.md`
(which describes the dormant Edge generator).

> **⭐ Brand-voice rule (locked).** The app is for **a girl following her boyfriend/
> partner** — that voice is primary and **goes first; we never dilute or "adapt" the
> tone for the parent/sibling/friend options.** The audience is always "her/she"
> (untouched). Inclusivity is *pronouns only*: when the followed person is NOT a
> partner, the *followed person's* pronoun becomes neutral "they/their/them"; for the
> default `.partner` it stays "he/his/him" (byte-for-byte the original voice). This is
> implemented via `AppState.usesHeVoice` + `pSubject/pPossessive/pObject/pIs/pWill`
> (Models/AppState.swift). `[his name]` placeholders render the name for everyone.
> Do NOT neutralize the brand framing/taglines — only the followed-person pronoun.
> (Bundled My Turn content does not apply this yet; see AUDIT_FINDINGS NEW-9.)

## 2. Entities & scope

- **20 Premier League clubs** (`Models/Team.swift`). A device follows one or two.
- One polymorphic `teams` table: `entity_type` ∈ {club, country, tournament},
  `league_id` (39 = Premier League). `team_id` everywhere is a lowercase slug
  (`^[a-z_]{2,32}$`) and is the FK to `teams(id)`: a club, a country or a competition.
- **Six competitions** (`CUP_COVERAGE_PLAN.md`): Premier League (39), Champions League
  (2), Europa League (3), Conference League (848), League Cup (48), FA Cup (45). Each
  non-league competition has a `tournament` row holding its own table and fixture feed,
  and its slug is the `team_id` for shared-feed cards. **Which of our clubs is in which
  competition is never stored**; it is derived from the fixture feed by `poll_leagues()`
  (migrations 094, 098), because it changes every August and on every knockout night.
  Cup opponents outside the 20 live in `teams` as `is_active=false`, registered on first
  sighting.
- **World Championship: retired.** The 48 country rows are inactive (migration 079), the
  WC screens are deleted, and `CountryFollowing.isEnabled = false` (`Models/Country.swift`)
  hides every country surface. The tournament maths in `_shared/` stays for the next one.
- **House copy rule:** app-visible text says **"World Championship"**, never "World Cup"
  (the App Store *listing* may say "World Cup"), and **"League Cup (Carabao Cup)"** on
  first mention, "League Cup" after, never "Carabao Cup" alone. **No em/en dashes** in
  generated or campaign copy. Cross-team LLM work must be a claude.ai routine, never a
  paid API loop (see §10).

## 3. Follow model

A device follows **up to 2 clubs** (and up to 2 countries while `CountryFollowing` is on).
Original design: `V2.2_DESIGN_MULTI_TEAM.md` (historical).

- **Data model = ARRAY columns on one row per device**, not a row per entity:
  `device_tokens.team_ids` / `country_ids` (migration 069), `live_activity_tokens`
  (070). `UNIQUE(apns_token)` and `UNIQUE(token)` are **deliberately preserved**.
- **Registration** goes through SECURITY DEFINER RPCs keyed on the token:
  `rpc/register_device_token` and `rpc/register_la_token` (migration 071; payload caps
  and rate limits in 129), called from `Services/APIClient.swift`. One row per device
  makes a double push structurally impossible, even when a device follows both sides of
  a fixture, and keeps token expiry and Delete My Data simple.
- **Scalar back-compat:** the legacy scalar `team_id`/`country_id` mirror `array[0]`.
  Every push read matches **scalar OR array**, so old and new clients both resolve. GIN
  indexes back the `&&`/`@>` filters.
- **iOS source of truth:** `AppState.selectedTeams: [Team]` (≤2). `selectedTeam` is a
  `.first` accessor whose setter REPLACES the array; multi-select call sites assign the
  array. The Feed's club switcher (`ContextSwitcherView`) only switches between followed
  clubs; adding or removing a club happens in onboarding or Settings.

## 4. Content pipeline

**Live content is produced by claude.ai ROUTINES (subscription-billed), not the Edge
`content-generator`.**

- The Edge `content-generator` + `content-reviewer` are **dormant**: `data-fetcher` only
  triggers them when the `CONTENT_GENERATOR_ENABLED` secret is `"true"`, which it is not.
- Routines live in `anton-tech43/goaldigger-routines` (locally
  `/Users/anton/goaldigger-routines`); its README section "Schedules, in one place" is
  the schedule. Each is `PROMPT*.md` + `fetch_*.sh` + `post_*.sh`. The `post_*.sh`
  scripts apply deterministic guards (dash strip, length caps, voice rejects, house copy
  substitutions, `push_eligible`) before posting to Supabase. Current routines:
  `gd-news`, `gd-insider`, `gd-season-state`, `gd-content-review`, `gd-europe`,
  `gd-domestic-cups`, `gd-team-page`, `gd-saturday-quiz`, `gd-sunday-brief`,
  `gd-player-dossier`, `gd-heartbeat`. **`gd-matchday`** (full time) and
  **`gd-live-brief`** (in play) are fired by `match-watcher`, not a schedule.
  `gd-maintenance` runs from `MAINTENANCE.md`.
- **`data-fetcher`** (`goaldigger-daily-pipeline`, every 2 h, 06:00 to 22:00 UTC) pulls
  RSS + API-Football per active club into `raw_fetch_logs`, computes pressure flags into
  `team_context`, and triggers `team-page-generator` in **`dynamic_only`** mode (no
  Claude) to refresh the deterministic team-page cards. Friendlies are filtered out of
  "next up" and form.
- **Players:** `goaldigger-players-sync` and `goaldigger-player-stats-sync` (daily) fill
  `players`; `official-squads` (daily, migration 127) overrides shirt numbers and squad
  membership from the Premier League's own list.
- **Content type → origin → consumer:**

  | Type | Origin | Where she sees it | Push |
  |---|---|---|---|
  | news, sunday_brief | routine | Feed | yes when `push_eligible` (T2+ for Sunday Brief) |
  | matchday (full-time article) | `gd-matchday`, fired by match-watcher | Feed | **no**: the FT push already went out |
  | live brief | `gd-live-brief` + deterministic score | live box on the club feed (T2+) | no |
  | insider | `gd-insider` → `team_insider_items` | His Team (T2+) | no |
  | Saturday quiz | `gd-saturday-quiz` → `saturday_quiz_items` | Feed card (T3) | no |
  | team page prose | `gd-team-page`, `gd-season-state` | His Team | no |

- **Newsworthiness:** the routine editorial bar (PROMPT.md GOLDEN RULE) produces 0 items on
  quiet days; the club feed then shows its empty state ("Quiet on his end", or an insider
  card at T2+). `matchday-reminder`'s deterministic build-up feed item exists for
  countries only, so it is dormant while countries are inactive.

## 5. Push & live-match pipeline (deterministic Edge + pg_cron)

There is **no** content → review → send chain in production for pushes. The live paths:

- **`match-watcher`** (`match-watcher-1min`, every minute). A tick lease (migration 103)
  stops overlapping ticks. It polls API-Football for the leagues `poll_leagues()` says are
  playing today (plus a yesterday "hangover" pass), upserts `match_status_state` keyed on
  `fixture_id`, and handles each fixture in isolation so one bad fixture cannot abort the
  tick. It sends **kickoff, goal, half-time and full-time pushes** to the followers of
  both clubs (`sendPlayingTeamPush`), each gated by `_shared/push-tiers.ts`: a goal
  reaches every tier in every competition; kickoff and half-time need tier 2; early
  League Cup and FA Cup rounds get no kickoff or half-time push; semi-finals and finals
  go to everyone. Half-time and full-time pushes end with a line to say. It also fills
  goal scorers (`goal_events`), drives Live Activity start/update/end, and fires
  `gd-matchday` / `gd-live-brief`. Idempotency = `briefs_fired` markers, claimed before
  sending, plus score advancement in the end-of-tick upsert. Every send writes an
  `apns_send` row to `pipeline_health`.
- **`notification-sender`** (`notification-sweep`, hourly at :15, plus an on-demand path
  from `post_*.sh`): the single APNs gate for `content_items`. Requires
  `push_eligible=true`; claims the item before sending; per-team 5-minute throttle; tier
  filter; matches tokens across scalar and array follows; pages past 1,000 rows.
- **`morning-push`** (`gd-morning-push`, 08:00 UTC): "game day" for followed clubs with a
  fixture today.
- **`matchday-reminder`** (`goaldigger-matchday-reminder`, 07:00 UTC): the pre-match
  reminder for every active club, kickoff rendered in the device's timezone
  (`device_tokens.timezone`, migration 082). Its `?mode=prep` path is the **day-before
  push** that opens My Turn on Pre-game (`goaldigger-prep-reminder`, 08:00 and 09:00 UTC,
  migration 125). That job is paused until the app version that opens Pre-game is live
  (migration 126).
- **Dead tokens:** every sender uses `isTokenDead` (`_shared/supabase-client.ts`): only
  410, `Unregistered`, `BadDeviceToken` and `DeviceTokenNotForTopic` deactivate a token;
  other 400s are payload problems and leave tokens alone. Deactivation is batched.
- **APNs**: environment is **per token** (`apns_environment`, set from the build's
  `#if DEBUG`). One ES256 provider JWT is cached in `apns_jwt_cache` (migration 064).
  Alert and Live Activity pushes use different `apns-push-type`/topics
  (`_shared/apns-client.ts`).
- **Fan-out is bounded concurrency** (`_shared/concurrency.ts::mapWithConcurrency`,
  `PUSH_CONCURRENCY=100`), with one aggregate `pipeline_health` row per item or fixture.
  See `SCALING_50K.md`.
- **Live Activities:** `ios/GoalDigger/LiveActivity/*` + a Widget Extension target, for
  followed clubs' matches in all six competitions (migration 083). One push-to-start
  token per device, per-activity update tokens by `fixture_id`. Registered only after
  onboarding (`LiveActivityManager`), with a 150-minute stale date and a local end.
  `live-match-current` / `live-brief-current` serve the in-app live box; score, minute and
  scorers are always deterministic from `match_status_state`, and the routine only
  supplies prose.
- **Cron auth:** every cron `net.http_post` sends `Bearer get_cron_service_key()` (a
  SECURITY DEFINER accessor reading Vault `cron_service_key`; migrations 019/020).
  Functions deploy `--no-verify-jwt` and check the caller in code with
  `_shared/require-service-auth.ts` (constant-time comparison against the Edge secret
  `CRON_AUTH_KEY`). The key is a random secret, never a JWT: `IOS_GOTCHAS.md` §14,
  `scripts/verify-cron-auth.sh`, `scripts/rotate-cron-key.sh`. Never add the `net` schema
  to PostgREST's exposed schemas.

## 6. iOS app structure

- **Tabs** (`App/GoalDiggerApp.swift`): Feed · {active club's name, or "His Team"} ·
  My Turn · Settings. The club tab is hidden when there is no entity to show. ATT is asked
  once, 1.5 s after the tabs first appear. A push whose `content_id` starts `myturn-prep`
  opens My Turn on Pre-game; article pushes open the detail view on the Feed tab.
- **`AppState`** (`@Observable`, `Models/AppState.swift`): the central store (follows,
  names, tier, flags, `activeContext`). `persistNow()` force-flushes UserDefaults at
  load-bearing moments.
- **Feed** (`Views/Feed/FeedView.swift`): immersive full-screen cards only (the classic
  list was removed). Keys everything off `appState.activeContext` (`.team` or
  `.everyoneTalking`, the cross-club "Football" feed); a first run lands on the first
  followed club. Above the cards: the live box (T2+, club feed only, polled every 60 s)
  and the Saturday Quiz card (T3, weekend window). Each card's rose half carries a line to
  say; the detail view (`Views/Detail/ContentDetailView.swift`) has "Good to know", "Things
  to say", the backstory and, for matchday articles, "After the match" and "Ones to watch".
- **Team page** (`Views/Team/TeamPageView.swift`, keyed with `.id(teamId)`): cache-first
  from `team_pages.content`; three tabs (Info, Calendar, Table with a League/Europe
  switcher). Info cards: coming up or post-match (its "Pre game talk" footer expands the
  card in place), mood, this week, the basics, the manager (portrait), ones to know,
  rivalry, form, season so far, insider (T2+), freshness.
- **Caching:** `CacheService` (SwiftData, feed items) + `TeamPageCache` (UserDefaults
  JSON, 24 h) + a shared `URLCache` for crests.
- **My Turn** (`Views/MyTurn/`): four segments (`MyTurnModule`): **prep**, Quiz, Lingo,
  Say This. Bundled content is four versioned JSON files under `Resources/MyTurn/`
  (quiz, lingo, saythis, hype), refreshed from `my_turn_content` when a newer
  `contentVersion` exists (`MyTurnContentService`). All of her state is one
  tolerant-decoded JSON blob in `MyTurnStore`.
  - **Prep** needs a followed club and always uses the first one, whatever the Feed
    switcher shows. It is labelled "Pre-game" before a fixture and "This week" otherwise,
    and opens itself once per new fixture (`MyTurnStore.prepShownFor`). Before a game it
    stacks three full-screen cards, each shrinking to a small row once done: **"Get to
    know {opponent}"** (a two-option quiz built on the phone by `LiveClubPack`, only for
    the 20 Premier League clubs), **"7 words for the game"** (an Overheard round dealt by
    `LingoDeck` from the fixture's context) and **"Prepare some sayings for the game"**
    (`LingoCalls.offer`: up to seven lines, saved with `rpc/save_match_calls` into
    `device_tokens.match_calls`, never pushed, marked "came up" on the phone after full
    time). After a game the segment shows "After {opponent}" and "What you called".
  - **Quiz:** three options per question; bundled packs plus "His club, right now", "His
    squad" and the opponent pack, built on the phone from the cached team page.
  - **Lingo:** a 158-term dictionary in four groups plus a seven-word Overheard practice
    round (two options).
  - **Say This:** situations with Safe/Bold lines, starred lines and a practice mode.
  - Rules and the validator: `tools/myturn/CONTENT_PRINCIPLES.md`,
    `tools/myturn/validate_content.py`. No streaks and no dailies by design: she did not
    choose this hobby. The one reminder is the day-before push (§5).
- **Tiers** (`Models/TierGating.swift`), chosen by her in onboarding and Settings ("Your
  Mode"): T2+ adds the live box, insider and Sunday Brief items; T3 adds only the
  Saturday Quiz card. Gated features are simply absent (no padlocks). Push volume per
  tier: §5.
- **Attribution:** Meta `FacebookCore` (app events + SKAdNetwork, no Login) auto-logs app
  activation from launch (`App/AppDelegate.swift`); `Services/AttributionService.swift`
  asks ATT. `PrivacyInfo.xcprivacy` declares tracking. There are no in-app analytics
  events of our own.

## 7. Onboarding flow (current order)

`welcome → herName → hisName (+ relationship) → plTeamOptional (required club, up to 2)
→ tierSelection → notificationPrompt → calendar → meetTeam → meetManager → howItWorks`
(`OnboardingFlow.OnboardingStep`, ten steps, none skipped). `completeOnboarding()` sets
`hasCompletedOnboarding=true`, points the feed at the first club, marks the season primer
as seen and calls `NotificationService.reregisterForFollowChange()` (the single
canonical registration path). `SeasonPrimerView` is therefore unreachable.

## 8. Tiers & monetization

The app is **free**, with no StoreKit code: `PurchaseManager` and `PaywallView` were
deleted. Tiers are self-chosen and control feature visibility (§6) and live-push volume
(§5). Design and what is still unbuilt: `TIERS.md`.

## 9. Data layer

Migrations 001 to 129, **applied by hand** with psql. `schema_migrations` records only
001 to 017; numbers 027, 072, 089, 107 and 119 are unused and 112, 117 and 124 are each
used twice, so `supabase db push` cannot be used.

Key tables: `teams`, `team_pages`, `team_season_state`, `team_context`,
`team_insider_items`, `team_news_sources`, `team_page_prose_history`, `club_style`,
`players`, `player_cards`, `content_items`, `content_reviews`, `saturday_quiz_items`,
`live_match_briefs`, `my_turn_content`, `device_tokens`, `live_activity_tokens`,
`match_status_state`, `match_watcher_ticks`, `matchday_reminders_sent`,
`prep_reminders_sent`, `raw_fetch_logs`, `pipeline_health`, `client_errors`,
`dev_alert_devices`, `apns_jwt_cache`. Human-verified facts live in our own columns
(`teams.manager_name`, migration 085; `teams.fan_name`, 128), per `DATA_SOURCES.md`.

**Access posture:**
- The app's publishable key can call exactly three RPCs: `register_device_token`,
  `register_la_token`, `save_match_calls`. It has no access to the token tables
  (migrations 106, 120) and reads published content only. `./scripts/db-health.sh` §7
  fails on any other anon-executable function.
- Every new function needs its own `REVOKE ... FROM PUBLIC, anon, authenticated`
  (CLAUDE.md). Retention sweeps run nightly (`*_retention_sweep` cron jobs; migration 129
  adds inactive tokens and stale Live Activity rows after 90 days).
- Secrets: Vault for the cron key; APNs `.p8` and API keys in the Edge runtime env.
- JSONB-null trap: `WHERE x IS NULL` misses a JSONB literal `null` (use
  `jsonb_typeof(x)='null'`).

## 10. Cost discipline

Hard rule (CLAUDE.md / BACKFILL_RULES.md): never loop a paid Anthropic API call across
teams. No scheduled job spends the API balance. The only Edge function that can is
**`team-page-generator`** in `full` mode, which requires a single `team_id`; the weekly
prose comes from the `gd-team-page` routine instead.

## 11. Ops / deploy

- When the app looks broken: `./scripts/db-health.sh` first (the `db-health-check` skill
  explains the output), then `RUNBOOK.md`'s push SOP.
- iOS: `xcodebuild -project ios/GoalDigger.xcodeproj -scheme GoalDigger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Edge deploy: `cd backend && supabase functions deploy <name> --project-ref cwgpsmbunrocrofziqad --no-verify-jwt`
- DB: `set -a && source backend/.env && set +a && /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL"`
- Routines: edit in `goaldigger-routines`, push to GitHub; they run on RemoteTrigger
  schedules (claude.ai subscription).
- Cron key: `scripts/verify-cron-auth.sh`, `scripts/rotate-cron-key.sh` (§5).

## 12. Deeper references

| Doc | For |
|---|---|
| `STATUS.md` | what is live, in TestFlight, paused, open |
| `DATA_SOURCES.md` | which feed fields we trust |
| `TIERS.md` | tier and push-volume design |
| `CUP_COVERAGE_PLAN.md` | how the five cups were added |
| `tools/myturn/CONTENT_PRINCIPLES.md`, `LINGO_OVERHEARD_BRIEF.md` | My Turn editorial rules |
| `IOS_GOTCHAS.md` | iOS and infrastructure traps |
| `RUNBOOK.md`, `DB_BASICS.md`, `MAINTENANCE.md` | recovery, database basics, routine upkeep |
| `AUDIT_FINDINGS.md`, `CHANGELOG_SECURITY.md` | known issues, security history |

Full doc map: `README.md`.
