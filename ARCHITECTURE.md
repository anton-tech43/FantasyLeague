# ARCHITECTURE — how GoalDigger actually works (2026-06-17)

**This is the authoritative "how it works today" doc.** If it disagrees with
`PRD.md`, `AGENT_CONTRACTS.md`, `PROMPTS.md`, `PRODUCT_BRIEF_INTEGRATION.md`, or
`RUNBOOK.md`, **this doc wins** — those are V1/historical (see the doc-status table
at the end). Current line: **V2.2 (multi-team), mid-World-Championship 2026**.

Facts below cite `file:line` so they stay falsifiable; if you change the code, update
the citation. Findings/known-bugs live in `AUDIT_FINDINGS.md`.

---

## 1. Product framing

A relationship companion: someone follows the football their **partner / parent /
sibling / friend** cares about so they can join the conversation. Football is the
medium, not the point. The followed person is referred to by name; the relationship
noun is a fallback. `AppState.relationshipType` = partner|parent|sibling|friend
(default partner), captured in `HisNameView`. Names (`hisName`/`herName`) are stored
**local-only, never sent to the server** (`Models/AppState.swift:10`). Display-time
substitution + dash stripping happens in `AppState.personalise()`
(`Models/AppState.swift:164`).

Voice = warm, cheeky best-friend. The live voice spec is the routine prompts in the
**separate `goaldigger-routines` repo** (`PROMPT.md`), NOT this repo's `PROMPTS.md`
(which describes the dormant edge generator).

> **⭐ Brand-voice rule (locked).** The app is for **a girl following her boyfriend/
> partner** — that voice is primary and **goes first; we never dilute or "adapt" the
> tone for the parent/sibling/friend options.** The audience is always "her/she"
> (untouched). Inclusivity is *pronouns only*: when the followed person is NOT a
> partner, the *followed person's* pronoun becomes neutral "they/their/them"; for the
> default `.partner` it stays "he/his/him" (byte-for-byte the original voice). This is
> implemented via `AppState.usesHeVoice` + `pSubject/pPossessive/pObject/pIs/pWill`
> (Models/AppState.swift). `[his name]` placeholders render the name for everyone.
> Do NOT neutralize the brand framing/taglines — only the followed-person pronoun.

## 2. Entities & scope

- **20 Premier League clubs** (`Models/Team.swift`) + **48 World Cup 2026 countries**
  (`Models/Country.swift`). Not "3 teams" (that's stale PRD).
- One polymorphic `teams` table: `entity_type` ∈ {club, country}, `league_id` 39=PL /
  1=WC (migration 032). `team_id` everywhere is a lowercase slug (`^[a-z_]{2,32}$`) and
  is the FK to `teams(id)` — it can be a club slug OR a country slug.
- ~71 `team_pages` rows (20 clubs + 48 countries + promoted carryover).
- **House copy rule:** app-visible text says **"World Championship"**, never "World
  Cup" (the App Store *listing* may say "World Cup"). **No em/en dashes** in generated
  or campaign copy. Cross-team LLM work must be a claude.ai routine, never a paid API
  loop (see §10).

## 3. Multi-team follow model (V2.2 — the newest subsystem)

A device can follow **up to 2 WC countries + 2 PL clubs, all equal**. Design detail:
`V2.2_DESIGN_MULTI_TEAM.md`.

- **Data model = ARRAY columns on the existing one-row-per-device tables**, NOT a row
  per entity. `device_tokens.country_ids TEXT[]` + `team_ids TEXT[]` (migration 069);
  `live_activity_tokens.country_ids TEXT[]` (migration 070). `UNIQUE(apns_token)` and
  `UNIQUE(token)` are **deliberately preserved** — one row per device.
- **Why arrays, not row-per-entity:** iOS registers via a direct PostgREST
  `merge-duplicates` upsert keyed on `UNIQUE(apns_token)` (`APIClient.registerToken`,
  `Services/APIClient.swift:207`). Dropping that unique would break every shipped app.
  One row per device also makes double-push structurally impossible (even when a device
  follows both teams in one fixture), and keeps token-expiry/GDPR-delete (keyed on
  `apns_token`) simple.
- **Scalar back-compat:** the legacy scalar `country_id`/`team_id` are mirrored to
  `array[0]` by the new app (NULLed when empty), and old apps write only scalars. Every
  push read matches **scalar OR array** (`.or(country_id.in.(…),country_ids.ov.{…})`),
  so old and new clients both resolve with no trigger and no divergence. GIN indexes
  back the `&&`/`@>` filters (migrations 069/070).
- **iOS source of truth:** `AppState.selectedCountries: [Country]` /
  `selectedTeams: [Team]` (≤2). `selectedCountry`/`selectedTeam` are **`.first`
  accessors** (`Models/AppState.swift:46-59`) so legacy single-entity call sites
  compile unchanged; their setters REPLACE the whole array (lossy for multi-follow —
  multi-select call sites assign the arrays directly). Legacy single UserDefaults keys
  migrate into the arrays on first launch (`AppState.swift:138-149`).
- **Onboarding:** an opt-in "I want to add my own country/club too" box on both the WC
  and PL steps reveals a 2nd picker (`CountrySelectionView`, `OptionalPLTeamView`).
  Settings pickers are multi-select.

## 4. Content pipeline — THE big correction

**Live content is produced by claude.ai ROUTINES (subscription-billed), not the Edge
`content-generator`.**

- The Edge `content-generator` + `content-reviewer` are **DORMANT**: `data-fetcher`
  only triggers content-generator when `CONTENT_GENERATOR_ENABLED === "true"`, a secret
  that is off by default (`data-fetcher/index.ts:~360`). They remain as a fallback.
- Live content rows carry `pipeline_source='routine'`. The routines live in
  `anton-tech43/goaldigger-routines` (locally `/Users/anton/goaldigger-routines`):
  `gd-news` (PROMPT.md), `gd-news-wc` (PROMPT_WC.md), `gd-insider`, `gd-matchday`,
  `gd-live-brief`, `gd-quiz`, `gd-player-dossier`, `gd-season-state`, `gd-sunday-brief`.
  Each is `PROMPT*.md` + `fetch_*.sh` + `post_*.sh`, scheduled via RemoteTrigger. The
  `post_*.sh` scripts do deterministic guards (em-dash strip, length caps, voice
  rejects, and now the "World Cup"→"World Championship" substitution) then POST to
  Supabase REST and ping `notification-sender`.
- **`data-fetcher`** still runs (~every 2h waking hours, migration 050): pulls RSS +
  API-Football per team into `raw_fetch_logs`, computes PL pressure flags into
  `team_context`, and triggers `team-page-generator` in **`dynamic_only`** mode (no
  Claude) to refresh deterministic team-page cards.
- **Live-game leading fixture (team-page-generator):** the "coming up / this week" cards
  are built from API-Football's `fixtures_next`, which drops a match the instant it kicks
  off — so a naive build rolls forward to the next not-started game and (with standings
  `played` still 0) mislabels it the group opener. The generator therefore reads the
  team's kicked-off-but-unrecorded WC game from `match_status_state` and leads with it
  (`phase: "live" | "just_finished"` → `in_progress`/`just_finished` stakes copy) until
  the result posts to `fixtures_last`. It also derives `openerPlayed` from
  `match_status_state` (any FINISHED WC game) and passes it to `annotateFixtures` so the
  group-opener label is suppressed once a game has been played — even while the standings
  feed still lags at `played: 0` (otherwise "First game…" reappears in the FT-to-standings
  gap). See `stakes-engine.ts::annotateFixtures` + `stakes-templates.ts`.
- **Content type → origin → consumer:** see the table in the push-pipeline audit;
  the key ones: news/sunday_brief → routine → feed+push; matchday reminder + build-up →
  deterministic Edge → feed/push; insider → routine → `team_insider_items` (His Team
  tab, T2+); quiz → routine → `saturday_quiz_items` (`quiz-current`, T3+); live brief →
  routine body + deterministic live score → `live_match_briefs` (`live-brief-current`).
- **Newsworthiness:** the routine editorial bar (PROMPT.md GOLDEN RULE) produces 0 items
  on quiet days; the dormant edge gate is `is_newsworthy && score>=6`
  (`content-generator/index.ts:~825`). To stop low-RSS WC countries having empty feeds,
  `matchday-reminder` writes a deterministic **build-up** feed item for every country
  with a fixture in the next 24h (`matchday-reminder/index.ts:113-148`), and `match-watcher`
  writes a deterministic FT **result** article per playing country. (Gap: quiet days
  >24h from a fixture still have no floor — `AUDIT_FINDINGS.md` F-FEEDFLOOR.)

## 5. Push & live-match pipeline (deterministic Edge + pg_cron)

There is **no** content→review→send chain in production for pushes. The live paths:

- **`match-watcher`** — pg_cron `* * * * *` (every minute, migration 017). Polls
  API-Football `/fixtures` for today (UTC) + a yesterday "hangover" pass; upserts
  `match_status_state` keyed on `fixture_id`. Drives, WC-only and deterministically:
  goal/HT/FT/kickoff-soon alerts (`sendWcPlayingTeamPush`, `match-watcher/index.ts:232`),
  goal-scorer enrichment from `/fixtures/events` stored in `match_status_state.goal_events`
  (migration 068), and Live Activity START/UPDATE/END. For PL it fires the `gd-matchday`
  routine on the live→FT transition (with a retry cap). Idempotency = `briefs_fired`
  JSONB markers + score advancement in the end-of-tick upsert.
- **`notification-sender`** — pg_cron hourly :15 sweep + an on-demand specific-item path
  from `post_*.sh`. The single APNs gate for `content_items`. Requires
  `push_eligible=true`; per-team 5-min throttle; tier filter (`minTierForType`);
  matches tokens across `team_id`/`country_id`/`team_ids`/`country_ids`; handles
  410/400 → `is_active=false`.
- **`morning-push`** — pg_cron 08:00 UTC (migration 048): "Game day at <team>" for any
  followed team/country with a fixture today.
- **`matchday-reminder`** — pg_cron 07:00 UTC (migration 063): the build-up feed floor
  (all countries) + a reminder push (followed countries only), idempotent via
  `matchday_reminders_sent`.
- **APNs**: environment is **per-token** (`apns_environment` dev/prod, set from the iOS
  build's `#if DEBUG`). One ES256 provider JWT is cached ~50 min in `apns_jwt_cache` +
  in-memory (migration 064, fixes a 429 burst). Alert vs Live Activity use different
  `apns-push-type`/topics (`_shared/apns-client.ts`).
- **Fan-out is bounded-concurrency, not sequential** (`_shared/concurrency.ts::mapWithConcurrency`,
  `PUSH_CONCURRENCY=100`). All four senders + the LA `sendAll` send up to 100 pushes in
  flight; per-recipient side effects are batched after the loop — dead tokens via one
  `deactivateTokens` UPDATE (`_shared/supabase-client.ts`), and one aggregate `pipeline_health`
  row per item/fixture (not per recipient). Sequential `for…await` blew the 400s Edge
  wall-clock ceiling at ~2-4k recipients; see `SCALING_50K.md`.
- **Deterministic WC math layer (pure, tested, $0):** `_shared/stakes-engine.ts`,
  `group-scenarios.ts`, `best-third.ts`, `stakes-templates.ts`, `consequence-templates.ts`,
  `matchup-verdict.ts`, `goal-push.ts`, `detect-consequences.ts`. These feed
  qualification/stakes framing into existing cards + pushes.
- **Live Activity (V2.1):** `ios/GoalDigger/LiveActivity/*` + a Widget Extension target.
  One push-to-start token per device (carries `country_ids`), per-activity update
  tokens by `fixture_id`. WC-only; shows score/period/minute. `live-match-current` /
  `live-brief-current` serve the in-app live box (minute X/90 + group standings +
  scorers). Headline/minute/scorers are ALWAYS deterministic from `match_status_state`
  (never stale); the routine brief supplies the prose BODY, but `live-brief-current` drops
  that body to a neutral period line once goals postdate the brief's minute (e.g. an HT
  "level first half" brief while it's now 4-2 in the 2H) — score/scorers carry the truth,
  no Claude re-fire.

**Cron auth:** every cron `net.http_post` sends `Bearer get_cron_service_key()` (a
SECURITY DEFINER accessor reading Postgres Vault; migrations 019/020). Functions
re-check the caller with `_shared/require-service-auth.ts` and deploy `--no-verify-jwt`.

## 6. iOS app structure

- **`AppState`** (`@Observable`, `Models/AppState.swift`): the central store
  (follows, names, tier, flags, `activeContext`). `persistNow()` force-flushes
  UserDefaults at load-bearing moments (async-write loss guard).
- **Feed** (`Views/Feed/FeedView.swift`): keys ALL content off `appState.activeContext`
  (a `FeedContext`: `.country` / `.team` / `.everyoneTalking`), resolved to
  `activeEntityId`; `selectedCountry`/`selectedTeam` are only `.everyoneTalking`
  fallbacks. Immersive (default) vs classic style. Prepends the live box →
  "Coming up" card → quiz card. `ContextSwitcherView` lists every followed entity as a
  tab.
- **Team page** (`Views/Team/TeamPageView.swift`): cache-first from `team_pages.content`
  JSONB; three tabs (Info cards, Calendar, Table). Cards = mood/thisWeek/basics/manager/
  onesToKnow/rivalry/form/season/comingUp/postMatch/insider(T2+)/freshness.
- **Caching:** `CacheService` (SwiftData, feed items, 30-day/50-row, schema-versioned) +
  `TeamPageCache` (UserDefaults JSON, 24h) + shared `URLCache` for crests.
- **Tiers** (`Models/TierGating.swift`): T2+ = Sunday Brief, Insider, MatchDayLive; T3+ =
  Quiz, GroupChatPrep; Dossier ungated. Gated features are simply absent (no padlocks).

## 7. Onboarding flow (current order)

`welcome → herName → hisName(+relationship) → country(allowsSecond) → optional PL
team(allowsSecond) → footballKnowledge → tier → notifications → calendar → meetTeam →
meetManager → howItWorks` (`Views/Onboarding/OnboardingFlow.swift`). `completeOnboarding()`
sets `hasCompletedOnboarding=true` then calls `NotificationService.reregisterForFollowChange()`
(the single canonical registration path). Existing V1 users without a country see
`WCMigrationSheetView` once.

- `footballKnowledgeLevel` is collected but **not yet wired to anything**
  (`AUDIT_FINDINGS.md` F-KNOWLEDGE).
- New users do **not** see `SeasonPrimerView` (completeOnboarding pre-sets its flag);
  it's only reachable after a data wipe.

## 8. Tiers & monetization (correct the record)

App is **free** on the App Store with a StoreKit unlock IAP `com.goaldigger.unlock`
(`Services/PurchaseManager.swift`) + `PaywallView` (currently parked). The PRD's "$10
paid, no IAP" is **fiction** relative to the code. Tier gating is feature-visibility
only.

## 9. Data layer

Migrations 001–070 (027 skipped). Key tables: `content_items`, `device_tokens`,
`live_activity_tokens`, `team_pages`, `team_season_state`, `team_insider_items`,
`saturday_quiz_items`, `live_match_briefs`, `match_status_state`, `raw_fetch_logs`,
`pipeline_health`, `matchday_reminders_sent`, `apns_jwt_cache`.

**RLS posture (verified):**
- `device_tokens` + `live_activity_tokens`: anon can **SELECT all rows** (migrations
  030/062) and INSERT/UPDATE (gated only by a trigger that protects `apns_token` +
  `is_active` on device_tokens; LA tokens have no such trigger). This is a **PII +
  cross-device-tamper exposure** (`AUDIT_FINDINGS.md` SEC-1/2/3) — the documented
  "Wave-2" RPC migration is still open.
- `content_items`: anon reads only `status='published'`. `teams`/`team_pages`/season/
  insider/quiz/brief tables: public read. `match_status_state`, `raw_fetch_logs`,
  `pipeline_health`, etc.: service-role only.
- Secrets: Vault for the cron key; APNs `.p8` + API keys in the Edge runtime env. iOS
  ships a publishable key (`sb_publishable_*`) — but the local `Configuration.xcconfig`
  may still carry a legacy anon JWT (`AUDIT_FINDINGS.md` SEC-8). JSONB-null trap: `WHERE
  x IS NULL` misses a JSONB literal `null` (use `jsonb_typeof(x)='null'`).

## 10. Cost discipline

Hard rule (CLAUDE.md / BACKFILL_RULES.md): never loop a paid Anthropic API call across
teams. The only Edge function still billing the API balance is **`team-page-generator`**
(it imports `_shared/claude-client.ts`'s `callClaude`). A weekly `team-page-refresh`
cron runs it in `full` mode across ALL teams — a recurring spend and the institutionalized
version of the exact anti-pattern (`AUDIT_FINDINGS.md` COST-1). Migrating it to a routine
is filed but open.

## 11. Ops / deploy

- iOS: `xcodebuild -project ios/GoalDigger.xcodeproj -scheme GoalDigger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Edge deploy: `cd backend && supabase functions deploy <name> --project-ref cwgpsmbunrocrofziqad --no-verify-jwt`
- DB: `set -a && source backend/.env && set +a && /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL"`
- Routines: edit in `goaldigger-routines`, push to GitHub; they run on RemoteTrigger schedules (claude.ai subscription).
- Recovery: `RUNBOOK.md` (note: partially routines-era, partially V1 — read with care).

## 12. Doc status map (which docs to trust)

| Doc | Verdict | Trust for |
|---|---|---|
| `ARCHITECTURE.md` (this) | CURRENT | how it works today |
| `AUDIT_FINDINGS.md` | CURRENT | known bugs/security/staleness |
| `V2.2_DESIGN_MULTI_TEAM.md` | CURRENT | the arrays/follow model |
| `WHATS_NEW_2.0.3.md` | CURRENT | recent shipped features |
| `BACKFILL_RULES.md`, `CLAUDE.md`, `IOS_GOTCHAS.md` | ACCURATE | cost rule, ops, iOS traps |
| `STATUS.md` | ACCURATE body, STALE TL;DR | history (ignore the top TL;DR) |
| `IMPLEMENTATION_PROGRESS.md` | ACCURATE body, STALE header | phase history |
| `WC_GROUP_STAGE_DESIGN.md` | content OK, STALE status (it shipped) | the stakes math design |
| `README.md` | PARTIALLY STALE | repo map (lists 7 of 22 fns) |
| `RUNBOOK.md` | HYBRID | recovery (mix of routine-era + V1) |
| `PRD.md`, `AGENT_CONTRACTS.md`, `PROMPTS.md`, `PRODUCT_BRIEF_INTEGRATION.md`, `CONTENT_EXAMPLES.md`, `APP_STORE_STRATEGY.md` | STALE / V1 | voice/vision only; facts are wrong (3 teams, $10, content-generator-as-live, girlfriend-only framing) |
