# Tracking plan: activation and behaviour

Status: built 2026-10-29 except step 3 — migration 142 (table, RPC,
retention), `Services/Analytics.swift` and the hooks below, migration 143
(`analytics_events` view), `scripts/tracking-digest.sh` (MAINTENANCE.md A9)
and the Meta `activated` event (`Attribution.logActivatedOnce`). Open: step 3
(privacy label and policy text) before the build is submitted, and switching
the ad set's optimisation goal to `activated` once the build is out. Written 2026-10-07, revised 2026-10-25.
Owner: Anton.

**What the build changed from this plan** (the tables below are updated to it):
- `app_opened` has no `source`. The tap callback lands after the scene goes
  active, so the app cannot know in time; SQL reads a `push_opened` in the same
  few seconds instead.
- `pregame_opened.entry` is `tab` or `link` (a push or "Pre-game ›"), for the
  same reason; which link is the neighbouring `push_opened`.
- `hype_shown` logs the in-round streak card only. The end-of-round card's
  category is a function of the score, which `practice_completed` and
  `overheard_round_finished` already carry.
- `next_fixture_in_hours` is not a common property (`// ponytail:` in
  Analytics.swift). Pre-game events carry `fixture_key` (`b|Opponent|day`)
  and, where known, `fixture_id`.
- Every event carries `env`: `development` from Xcode builds. **Every view and
  digest keeps `env = 'production'` only.**
- `my_turn_module_switched` has no `prep_available`: Pre-game left My Turn for
  the Matchday tab on 2026-10-27, so module values are `quiz`, `lingo`,
  `saythis`.
- `scripts/verify-tracking-plan.sh` checks that the app, the RPC's allow-list
  and the tables below name the same events, and that each is logged somewhere.

---

## Why

Today the only usage signal is Meta's automatic app-open event and
`device_tokens.created_at` for people who allowed notifications. We cannot say
whether anyone opens Pre-game, which cards she reads, whether she comes back for
the next match, or what she changes when she does.

What we can see today, and what it is worth (measured 2026-10-25):

- 72 active devices, 77 ever registered, 5 uninstalled.
- 53 of those 77 registered in October — the base more than doubled in a month.
- 61% have never changed a setting since onboarding.

That last number is the clearest illustration of why this plan exists, because
it is wrong in both directions at once. `device_tokens.updated_at` only moves
when the push token, clubs, tier or timezone change. Someone who reads the feed
every day and never opens Settings is indistinguishable from someone who deleted
the app and left a live token behind — so it **understates** use. And iOS
reissues push tokens on its own, at app updates and restores, so some of the 21
devices that "changed something this week" changed nothing — so it **overstates**
it too. There is no correction factor for an instrument that is wrong in both
directions; there is only a different instrument.

Every question worth asking currently has an answer that is a guess.

---

## Verified against the app, 2026-10-25

The 2026-10-07 version named twelve hooks. All twelve still exist:
`GoalDiggerApp`, `OnboardingFlow`, `completeOnboarding`, `AppDelegate`,
`MainTabView`, `ImmersiveCard`, `MyTurnView`, `MyTurnStore`, `TeamPickerSheet`,
`SettingsView`, `NotificationService`, `deleteData`.

Three details had drifted, and one of them invalidated a decision the plan was
being built to inform:

**1. "Does Pre-game deserve its own tab?" was already answered, in the app, on
2026-09-27.** Pre-game is `MyTurnModule.prep` and it is the **first** of My
Turn's four segments, ahead of Quiz. `MyTurnContent.swift` says why in a comment
dated that day: *"what she needs most is to be ready for the next game, not to
learn football in general."* The plan was proposing to measure its way to a
decision that had been made by hand three weeks before it was written.

The real question is narrower and more interesting: **prep is conditional.**
`segments` filters it out entirely unless `prepAvailable`, so between fixtures
the first tab of My Turn silently becomes Quiz. Nobody knows whether that
teaches people the module does not exist. Decision 1 is rewritten below.

**2. The module names were wrong.** `MyTurnModule` rawValues are
`prep`, `quiz`, `lingo`, `saythis` — not the `(quiz, lingo, say_this)` the old
table said. Event property values must be the rawValues, so a query joins
without a translation table that will itself drift.

**3. There are two phases, not an open set.** `LingoDeck.Phase` is exactly
`before(opponent:kickoff:)` and `after(opponent:outcome:teamScore:oppScore:)`.
`phase` is a two-value property.

Two surfaces exist that the old plan never mentioned at all:

- **Overheard** (`LingoOverheardView`) — described in its own first line as
  *"the round, and the reason Lingo exists"*. The plan's only Lingo event was
  `practice_completed(module: lingo)`, which cannot tell a dictionary lookup
  from the game the module was built around.
- **The hype streak** (`HypeOverlay`) — `HypeStreakOverlay` sits above every
  module and fires on `packFinished` and `streak`, with categories `perfect`,
  `strong`, `mid`, `rough`, `streak`, and a `streakTick` counter. It is a
  retention mechanic with no measurement at all. Whether a streak brings anyone
  back is exactly the kind of thing this plan is for.

---

## Three premises that moved since 2026-10-07

### 1. Arsenal is 78% of the user base

56 of 72 devices follow Arsenal; every other club has between one and seven.
42 of 53 October installs are Arsenal, which points straight at the
club-targeted ad set.

This is the biggest threat to "what should we invest in". Any usage finding will
be an Arsenal finding wearing a general costume — and Arsenal is the club with
the richest feed, the most news coverage and the most fixtures in Europe. A
feature that looks unused may be unused *by people whose club generates enough
content that they never need it*.

Every metric here is reported **by club group**: Arsenal, and everyone else. If
the two disagree, the answer is "we do not know yet", not the Arsenal number.

### 2. The base is too small for statistics and will be for months

With 72 users, a 10-point gap between two features is four people. Nothing in
this plan produces a statistically meaningful number in 2026. The point is to
see individual paths — *did she get ready for his game?* — and to have the
history in place before growth makes it matter. Treat every percentage as an
anecdote with a denominator.

### 3. There is a four-day hole in the record, before the record exists

The backend was unreachable 2026-10-21 11:22 UTC to 2026-10-25 09:23 UTC: no
content, no pushes, no reads. Any retention or engagement series crossing that
window shows a collapse that is ours, not hers. The same applies to the seven
days from 2026-08-30 and the seventeen hours of 2026-09-20.

Put the windows in a table — `analytics_blackouts (started_at, ended_at,
reason)` — and join every query against it. A constant copied into nine queries
is a lie waiting for the tenth, and the person who reads an uncorrected chart in
March will not know to ask.

---

## The questions it must answer

1. **Activation** — did she get ready for his first game after installing?
2. **Retention, in football time** — does she come back before his next matches?
   Weeks are the wrong clock for a hobby that runs on fixtures.
3. **What she uses** — Pre-game vs Feed vs His Team vs the rest of My Turn;
   which pushes she opens; which lines she saves or shares.
4. **What she changes** — which clubs she adds or drops, whether she turns the
   push volume down, whether she refuses or later grants notifications.
5. **Where she drops** — which onboarding step loses people; which permission
   she refuses; where she leaves.
6. **What to build next** — but see "Three denominators" and "Deciding from it".
   Unused, undiscovered and ineligible look identical in the data and are three
   different findings.

---

## Three denominators

The single most likely way to misread this data is to divide by the wrong
number. Six features are tier-gated (`TierGating.swift`):

| Feature | Needs tier | Devices eligible today |
|---|---|---|
| `sundayBrief`, `insiderCard`, `matchDayLive` | 2 | 70 of 72 |
| `saturdayQuiz`, `groupChatPrep` | 3 | **28 of 72** |
| `playerDossier` | none | 72 of 72 |

Gated features are **absent from the UI** below their tier — no padlock, no
hint. So "only 9 people used the Saturday quiz" is not 12% of users; it is 32%
of the 28 who could see it at all. And Pre-game has a fourth state again: it is
not tier-gated, but `prepAvailable` hides it between fixtures.

Every usage number is therefore reported against three denominators, and a
finding that does not name which one it used is not a finding:

- **All** — every active device. For reach and for the push surface.
- **Eligible** — devices whose tier and state could reach the feature. For
  anything about whether a feature is wanted.
- **Exposed** — devices that actually reached the entry point (`tab_viewed`,
  `settings_row_opened`, the module switch). For whether it is any good.

The gap between *eligible* and *exposed* is a discoverability problem. The gap
between *exposed* and *completed* is a quality problem. They have opposite
fixes, and only the second is ever a reason to cut something.

---

## Definitions

| Metric | Definition |
|---|---|
| Activated | `pregame_card_completed` with `phase = before` for the first fixture of her first club whose kickoff is after `onboarding_completed`. |
| Ready for a match | At least one `pregame_card_completed` (phase `before`) for that fixture before kickoff. |
| **North star: matches she was ready for** | Count of fixtures per user, per week, where she was ready. Denominator: fixtures her clubs actually played, not calendar weeks. |
| Match retention | Of her club's first 3 fixtures after install, how many she was ready for (0–3). Report the share with 2 or more. |
| Classic retention | Opened the app in week 1 and in week 4 after install, for comparing with other apps. |
| Push open rate | `push_opened` ÷ pushes sent (`pipeline_health` stage `apns_send`), by push kind. |
| **Push tolerance** | Net tier movement per 100 devices per month. Negative means we push more than she wants. |
| **Prep reach** | Of fixtures where `prepAvailable` was true, the share where she opened prep at all. Separates "did not want it" from "it was not there when she looked". |

---

## Where the events go

**Our own table, through one RPC.** `public.app_events`, written by a SECURITY
DEFINER RPC `log_events(p_install_id uuid, p_events jsonb)`, same pattern and
caps as the three existing RPCs (migration 129): at most 50 events per batch, at
most 8 KB, known event names only, a per-install rate limit,
`REVOKE ... FROM PUBLIC, anon, authenticated` on the table and an explicit grant
on the function. Queried with SQL; joins to `device_tokens` and the fixtures we
already hold.

- No new SDK, no third party, nothing sent outside Supabase.
- **Meta gets one event only:** `activated`, as a custom app event through the
  FacebookCore SDK already in the app, so the Arsenal ad set can optimise for
  women who get ready for a match rather than for installs.

Rejected: sending everything to Meta (behaviour data with an ad company, hard to
query); a product-analytics SDK such as PostHog or TelemetryDeck (a new
dependency and a new processor for 72 users; reconsider past a few thousand).

### This table must not become the next outage

On 2026-10-21 the database stopped being able to start its scheduled jobs and
took four days and a compute upgrade to recover. `raw_fetch_logs` was 87 MB of a
129 MB database. This is the first table proposed here whose row count scales
with **users** rather than with clubs, and it is being specified three days
after that. Budget it before building it:

- **Volume, said out loud.** 72 devices × ~30 events/day ≈ 2 000 rows/day, under
  1 MB a week with the properties below. At 1 000 users, 30 000 rows a day.
  Neither is frightening. What is frightening is shipping it without having
  written the number down, which is how every previous one got away.
- **Retention in the same migration**, not a later one. 13 months raw, then roll
  up to daily aggregates and delete. `cron.job_run_details` reached 177 070 rows
  by "we will add retention later"; `raw_fetch_logs` reached 93 727.
- **Both indexes in the same migration, and checked with EXPLAIN.** Lesson 84:
  the June IO alert was an index of `(team_id, fetched_at)` against a query
  filtering `(team_id, source, fetched_at)`, which read ~55 heap rows per
  lookup. The two dominant reads here are `(install_id, created_at DESC)` for
  one person's path and `(name, created_at)` for a funnel. Seed a few hundred
  thousand rows and read the plan; do not assume.
- **Append-only, never updated.** No dead tuples, so autovacuum stays cheap.
- **Batched writes only.** Fifty events in one insert dirties one page; fifty
  inserts dirty fifty.
- **Properties as `jsonb`, but the event name as `text`.** The name is what every
  query filters on and what the allow-list checks; it does not belong inside a
  document.

---

## Identity and privacy

- `install_id`: a random UUID created on first launch, stored on the phone,
  never derived from the APNs token or the advertising ID. Delete My Data
  deletes every event for it and creates a new one.
- **Never in an event:** her name, his name, free text, the APNs token,
  location, or any content she wrote.
- **Common properties on every event:** `app_version`, `build`, `club` (slug),
  `tier`, `relationship`, `days_since_install`, `next_fixture_in_hours`
  (negative after kickoff).
- Keep events 13 months, then aggregate. The 90-day purge of inactive device
  tokens (migration 129) then no longer erases retention history, because
  cohorts come from `app_events`.
- Before the build ships: add "product interaction, not linked to you, not used
  for tracking" to the App Store privacy label, and add a usage-data paragraph
  to the privacy policy. The current policy says we collect no email, phone,
  location or payment details — all of that stays true, and the new paragraph
  must not quietly weaken that sentence. No ATT prompt is needed for
  first-party analytics that are not shared.
- **`relationship` is the one property to look at twice.** It is low-cardinality
  and not identifying on its own, but combined with `club` and
  `days_since_install` it narrows a small base fast. Keep it; revisit if the
  base stays small and the slices get used for anything but aggregates.

---

## Events (version 1)

Twenty events, in four groups. Each is logged at one point in the code; the hook
is named so whoever builds it does not have to search. Property values are the
app's own rawValues wherever one exists.

### A. Arrival and shape of a session

| Event | Properties | Hook |
|---|---|---|
| `app_opened` | — (source: see "What the build changed") | `GoalDiggerApp` scene becomes active, after onboarding |
| `onboarding_step_viewed` | `step` | `OnboardingFlow`, on `step` change |
| `onboarding_completed` | `seconds`, `notifications` (granted, denied, later), `calendar` (on, off) | `OnboardingFlow.completeOnboarding()` |
| `push_opened` | `kind` (`AppDelegate.pushKind`: goal, ht, ft, … from `live-<kind>-`, prep, matchday, fixture, article), `club` | `AppDelegate.userNotificationCenter(_:didReceive:)` |
| `tab_viewed` | `tab` (feed, matchday, club, my_turn) | `MainTabView` selection change (`AppTab.analyticsName`) |
| `settings_opened` | — | `SettingsView` appears (a sheet since 2.4, so not a tab) |

### B. What she reads

| Event | Properties | Hook |
|---|---|---|
| `feed_card_opened` | `position`, `content_type`, `zone` (story, things_to_say) | `ImmersiveCard` zone taps |
| `line_shared` | `surface` (feed, article, talking_point, quiz, copy) | the `ShareLink`s and `CopyButton` |
| `line_saved` | `source` (slip, say_this) | slip "Save for the game", Say This star |

### C. My Turn, corrected to the app

| Event | Properties | Hook |
|---|---|---|
| `my_turn_module_switched` | `from`, `to` (quiz, lingo, saythis) | `MyTurnView` segmented control |
| `pregame_opened` | `entry` (tab, link), `phase` (before), `fixture_id` | `MatchdayView` when Before shows |
| `matchday_after_opened` | `entry` (tab, link), `hours_since_ft`, `fixture_id` | `MatchdayView` when After shows |
| `pregame_card_completed` | `card` (opponent_quiz, seven_words, slip), `score`, `of`, `phase`, `fixture_key`, `fixture_id` (slip) | `MyTurnStore.nextQuestion` / `nextDrillCard` finish, `LingoCallsView.answer` past the last line |
| `practice_completed` | `module` (quiz), `pack`, `score`, `of` | `MyTurnStore.nextQuestion` finish without a fixture |
| `overheard_round_finished` | `score`, `of`, `deck`, `origin` | `MyTurnStore.nextDrillCard` finish |
| `hype_shown` | `category` (streak), `streak_tick` | `HypeStreakOverlay` shows the card |

### D. What she changes

The twelve events of the 2026-10-07 plan measure what she **consumes**. Nothing
measured what she **decides**, and that is the half with the clearest product
signal in it: a person changing a setting has formed an opinion and acted on it.
39% of devices have changed something since onboarding and we do not know what.

| Event | Properties | Hook | Why it earns its place |
|---|---|---|---|
| `follow_changed` | `action` (added, removed), `club`, `count_after` | `TeamPickerSheet` on Done, one event per change | Which clubs people reach for, and whether the two-club feature is used at all. 5 of 72 follow two clubs today. |
| `tier_changed` | `from`, `to` (1–3) | the tier control in `SettingsView` | **The only honest "too many pushes" signal we will ever have.** Every entry in `PUSH_RULES.md` §3 shipped first and was walked back after someone complained. A complaint is a user who bothered; a user who silently turns the dial down holds the same opinion, uncounted. It is also the one event that moves the *eligible* denominator, so it has to be logged for the rest of the data to be readable. |
| `notification_permission_changed` | `from`, `to` (granted, denied) | `NotificationService.checkNotificationStatus`, against the last status seen | Separates "never asked properly" from "asked and refused". A refusal weeks later, after a bad push run, is a different fact from one at onboarding. |
| `notifications_banner` | `action` (shown, turn_on, not_now) | the Feed banner | The banner is the recovery path for the biggest single failure mode we have seen — a user with notifications off who assumes the app is broken. |
| `settings_row_opened` | `row` (clubs, countries, tier) | `SettingsView` picker sheets opening | The *exposed* denominator for everything in Settings. Distinguishes a setting nobody wants from one nobody can find. |
| `data_deleted` | `clubs` (+ the common `tier`, `days_since_install`) | `Analytics.forgetInstall`, from `SettingsView.deleteData()` **before** the wipe | The clearest exit in the app, and today it leaves nothing behind at all: the row vanishes and so does the reason. |

`data_deleted` must be sent and flushed **before** the local wipe, and it
survives on the server by design — the `install_id` is deleted with everything
else, so the event is anonymous by the time anyone reads it. That is the one
place where "delete everything" and "learn from the exit" have to be reconciled
deliberately rather than by accident, and it should be called out in the privacy
paragraph rather than discovered later.

### Transport

Queue on the phone, flush on background and every 30 events, drop the queue
after 7 days offline. Never a network call per event.

**One check left behind:** a unit test asserting that every event name the app
can emit is in the RPC's allow-list, and that every property value for an
enum-backed property is one of that enum's rawValues. That test is what stops
this list and the app drifting the way the module names already did once.

---

## Deciding from it

The failure mode this section exists to prevent: reading a number off a
dashboard, believing it, and cutting something real. Three of four outages were
caused by acting on the most satisfying explanation rather than the measured one
(`OUTAGE_LESSONS.md`, lesson 4). Pointed at product data, the same instinct
costs features instead of uptime, and features do not page you at 06:17.

**Decide the threshold before you look.** For every question, write down in
advance what result would change the decision. Written afterwards, any number
supports whatever you already wanted.

**Name the denominator.** See "Three denominators". A finding that does not say
whether it used *all*, *eligible* or *exposed* is not a finding.

**Unused, undiscovered and ineligible are three different results.** No
completions and no entries means it was never found. Entries and no completions
means it was found and rejected. Below the required tier means it was never
offered. Only the middle one is ever a reason to cut.

**Nothing gets cut on one club's behaviour.** See premise 1.

**Nothing gets cut on fewer than 30 people or one month, whichever is longer.**
With this base, almost everything will fail that bar through 2026. That is the
correct outcome: the first year of this data is for watching individual paths
and building history, not for making cuts.

### Three decisions it is being built to inform

1. **Is Pre-game findable?** *(Rewritten twice. On 2026-10-27 Pre-game moved
   out of My Turn into its own Matchday tab (Before / After), merged from
   `claude/matchday-tab`, so the "conditional first segment" question below is
   history.)* The question now: does the tab earn its slot? From
   `pregame_opened.entry` and **prep reach** — of fixtures with a Before, how
   often was it opened, and from where (tab, push, club page)? If nearly all
   opens come from the pre-game push, the tab is a landing page, not a
   destination, and could fold back. If she opens the tab unprompted, it stays.
2. **Is the push volume right?** From push open rate by kind, crossed with net
   `tier_changed` movement. A push kind with a low open rate **and** tier
   downgrades following it is the first candidate for `PUSH_RULES.md` §3 — and
   that is a far better instrument than the complaint that currently has to
   arrive before anything moves.
3. **Is the two-club feature worth its complexity?** From `follow_changed`. It
   has cost real engineering — the arrays model, recipient matching on both a
   scalar and an array, and a debug flag before it could be tested at all — and
   5 of 72 people use it. The question is whether anyone *adds* a second club
   after install, or whether all five chose two during onboarding and the
   feature has no pull of its own.

---

## What we look at

- **A weekly SQL digest**, added to the `gd-maintenance` report: new installs,
  activated, ready-for-a-match by fixture, match retention by install week, push
  open rate by kind, onboarding funnel, net tier movement, follows added and
  removed, prep reach. Split Arsenal / everyone else throughout, blackout
  windows excluded, denominator named on every line.
- **A small private dashboard page** (an Artifact reading the same views) once
  there are more than a handful of users.
- **The digest is the product, not the dashboard.** A number that only exists on
  a page someone has to remember to open is a number nobody reads. This is the
  same reason `gd-heartbeat` pushes rather than publishes.

---

## Build order

1. **Migration:** `app_events`, `log_events` RPC, grants and caps, **both
   indexes**, the 13-month retention cron, and `analytics_blackouts` seeded with
   the three known windows. `db-health.sh` §7's allow-list gains `log_events`.
   Retention and indexes ship here, not later.
2. **iOS:** an `Analytics` service (queue, batch, flush) plus the twenty hooks,
   in the next build after 2.3. The allow-list unit test ships with it.
3. **Privacy label and policy text**, before that build is submitted.
4. **SQL views and the weekly digest**, with the blackout exclusion, the club
   split and the three denominators built into the first query rather than added
   after someone misreads a chart.
5. **The Meta `activated` event** and the ad set's optimisation goal.

Steps 1 and 4 are worth doing even if 2 slips: the blackout table and the
club-split views make the data we **already** have honest, and `get_insights()`
can move onto them immediately.

---

## Keeping this plan true

This document names twenty hooks in a codebase that changes weekly. The
2026-10-07 version was three weeks old and had already drifted on module names,
phases and one of its own headline decisions. Eighteen documents in this repo
were archived in October for exactly this.

So: when this is built, `scripts/verify-tracking-plan.sh` should fail if any
hook named here no longer exists in the iOS tree, if any enum-backed property
value is not a rawValue of its enum, or if the app can emit an event name this
file does not list. The same shape as `verify-arch-map.sh` and
`verify-push-rules.sh`, for the same reason.

Until then, re-read this against the app before acting on it.

---

## What this plan deliberately does not do

- **No third-party analytics.** Reconsider past a few thousand users.
- **No session recording, no heatmaps, no free text.** Nothing that could carry
  her name, his name, or anything she wrote.
- **No per-event network call.** Batched or not at all.
- **No metric that only exists in a dashboard.** If it matters, it is in the
  weekly digest, in SQL, in the repo.
- **No event on content she reads in the feed beyond the card open.** Dwell
  time, scroll depth and read-completion are the start of a different product,
  and the promise on the privacy page is the reason not to.
