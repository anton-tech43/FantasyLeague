# Tracking plan: activation and behaviour

Status: plan, not built. Written 2026-10-07, revised 2026-10-25. Owner: Anton.

## Why

Today the only usage signal is Meta's automatic app-open event and
`device_tokens.created_at` for people who allowed notifications. We cannot say
whether anyone opens Pre-game, which cards she reads, whether she comes back for
the next match, or what she changes when she does.

What we *can* see today, and what it is worth (measured 2026-10-25):

- 72 active devices, 77 ever registered, 5 uninstalled.
- 53 of those 77 registered in October — the base more than doubled in a month.
- 61% have never changed a setting since onboarding. That number is **not** 61%
  inactive: `device_tokens.updated_at` only moves when the token, clubs, tier or
  timezone change. Someone who reads the feed daily and never opens Settings is
  indistinguishable from someone who deleted the app and left the token alive.
  It also moves on its own when iOS reissues a push token, so it overstates in
  the other direction. It is the wrong instrument in both directions at once.

That is the whole case for this plan: every question worth asking currently has
an answer that is a guess.

---

## Three premises that moved since 2026-10-07

**1. Arsenal is 78% of the user base.** 56 of 72 devices follow Arsenal; every
other club has between one and seven. 42 of 53 October installs are Arsenal,
which points straight at the club-targeted ad set.

This is the single biggest threat to "what should we invest in". Any usage
finding will be an Arsenal finding wearing a general costume — and Arsenal is
the club with the richest feed, the most news coverage and the most fixtures in
Europe. A feature that looks unused may simply be unused *by people whose club
generates enough content that they never need it*.

Every metric in this plan is therefore reported **by club group**: Arsenal, and
everyone else. If the two disagree, the answer is "we do not know yet", not the
Arsenal number.

**2. The base is still too small for statistics, and will be for months.** With
72 users, a 10-point difference between two features is four people. Nothing
here produces a statistically meaningful number in 2026. The point is to see
individual paths — *did she get ready for his game?* — and to have the history
in place before growth makes it matter. Treat every percentage as an anecdote
with a denominator.

**3. There is a four-day hole in the data, before the data exists.** The backend
was unreachable 2026-10-21 11:22 UTC to 2026-10-25 09:23 UTC: no content, no
pushes, no reads. Any retention or engagement series crossing that window will
show a collapse that is ours, not hers. The window must be excluded explicitly
in every query from day one, with a comment saying why — otherwise someone
reads it in March as a product failure and acts on it. The same applies to the
seven days from 2026-08-30 and the seventeen hours of 2026-09-20.

> Write the blackout windows into a table (`analytics_blackouts`) rather than
> into each query. A constant copied into nine places is a lie waiting for the
> tenth.

---

## The questions it must answer

1. **Activation:** did she get ready for his first game after installing?
   (A Pre-game card finished before that kickoff.)
2. **Retention, in football time:** does she come back before his next matches?
   Weeks are the wrong clock for a hobby that runs on fixtures.
3. **What she uses:** Pre-game vs Feed vs His Team vs the rest of My Turn; which
   pushes she opens; which lines she saves or shares.
4. **What she changes:** which clubs she adds or drops, whether she turns the
   push volume down, whether she refuses or later grants notifications. *(New
   2026-10-25 — see "What she changes" below.)*
5. **Where she drops:** which onboarding step loses people; which permission she
   refuses.
6. **What to build next:** the parts nobody touches are candidates to cut; the
   parts that bring her back are where to invest. **But see "Deciding from it"
   — unused and undiscovered look identical and must not be confused.**

---

## Definitions

| Metric | Definition |
|---|---|
| Activated | `pregame_card_completed` with `phase = before` for the first fixture of her first club whose kickoff is after `onboarding_completed`. |
| Ready for a match | At least one `pregame_card_completed` (phase before) for that fixture before kickoff. |
| **North star: matches she was ready for** | Count of fixtures per user, per week, where she was ready. |
| Match retention | Of her club's first 3 fixtures after install, how many she was ready for (0 to 3). Report the share with 2 or more. |
| Classic retention | Opened the app in week 1 and in week 4 after install, for comparing with other apps. |
| Push open rate | `push_opened` divided by pushes sent (`pipeline_health` `apns_send`), by push kind. |
| **Push tolerance** | Net tier movement per 100 devices per month. Negative means we are pushing more than she wants. *(New.)* |

---

## Where the events go

**Our own table, through one RPC.** A `public.app_events` table written by a
SECURITY DEFINER RPC `log_events(p_install_id uuid, p_events jsonb)`, same
pattern and caps as the three existing RPCs (migration 129): batch of at most 50
events, at most 8 KB, known event names only, a per-install rate limit,
`REVOKE ... FROM PUBLIC, anon, authenticated` on the table and an explicit grant
on the function. Queried with SQL; joins to `device_tokens` and the fixtures we
already hold.

- No new SDK, no third party, nothing sent outside Supabase.
- **Meta gets one event only:** `activated` (as a custom app event through the
  FacebookCore SDK already in the app), so the Arsenal ad set can optimise for
  women who get ready for a match rather than for installs.

Rejected: sending everything to Meta (behaviour data with an ad company, hard to
query); a product-analytics SDK such as PostHog or TelemetryDeck (a new
dependency and a new processor for 72 users; reconsider past a few thousand).

### This table must not become the next outage *(New 2026-10-25)*

On 2026-10-21 the database stopped being able to start its scheduled jobs and
took four days and a compute upgrade to recover. `raw_fetch_logs` was 87 MB of a
129 MB database at the time. We are now proposing the first table in this system
whose row count scales with *users* rather than with clubs.

Budget it before building it, not after:

- **Expected volume.** 72 devices × ~30 events a day ≈ 2 000 rows/day, call it
  1 MB a week with the properties below. At 1 000 users that is 30 000 rows a
  day. Neither is frightening; what is frightening is shipping it without
  having said the number out loud, which is how every previous one got away.
- **Retention from day one, in the same migration.** 13 months of raw events,
  then roll up to daily aggregates and delete. Not "add retention later" —
  `cron.job_run_details` reached 177 070 rows that way, and `raw_fetch_logs`
  reached 93 727.
- **The index must cover the whole predicate.** Lesson 84: the June IO alert was
  an index of `(team_id, fetched_at)` against a query filtering on
  `(team_id, source, fetched_at)`, which read ~55 heap rows per lookup. The
  dominant read here is `(install_id, name, created_at DESC)` for a user's path
  and `(name, created_at)` for a funnel. Write both, and check with EXPLAIN
  against seeded data rather than assuming.
- **Append-only, never updated.** No dead tuples, so autovacuum stays cheap.
- **Batched writes only.** One RPC call per flush, never one per event. Fifty
  events in one insert is one page dirtied; fifty inserts is fifty.

---

## Identity and privacy

- `install_id`: a random UUID created on first launch, stored on the phone,
  never derived from the APNs token or the advertising ID. Delete My Data
  deletes every event for it and creates a new one.
- Never in an event: her name, his name, free text, the APNs token, location.
- Common properties on every event: `app_version`, `build`, `club` (slug),
  `tier`, `relationship`, `days_since_install`, `next_fixture_in_hours`
  (negative after kickoff).
- Keep events 13 months, then aggregate. The 90-day purge of inactive device
  tokens (migration 129) then no longer erases retention history, because
  cohorts come from `app_events`.
- Before the build ships: add "product interaction, not linked to you, not used
  for tracking" to the App Store privacy label, and add a usage-data paragraph
  to the privacy policy. The current policy says we collect no email, phone,
  location or payment details — all still true, and the new paragraph must not
  quietly weaken that sentence. No ATT prompt is needed for first-party
  analytics that are not shared.

---

## Events (version 1)

Seventeen events. Each is logged at one point in the code; the hook is named so
whoever builds it does not have to search.

| Event | Properties | Hook |
|---|---|---|
| `app_opened` | `source` (icon, push, link) | `GoalDiggerApp` scene becomes active |
| `onboarding_step_viewed` | `step` | `OnboardingFlow`, on `step` change |
| `onboarding_completed` | `seconds`, `notifications` (granted, denied, later), `calendar` (on, off) | `OnboardingFlow.completeOnboarding()` |
| `push_opened` | `kind` (kickoff, goal, ht, ft, news, prep, sunday_brief), `content_id` | `AppDelegate.userNotificationCenter(_:didReceive:)` |
| `tab_viewed` | `tab` (feed, club, my_turn, settings) | `MainTabView` selection change |
| `feed_card_opened` | `position`, `content_type`, `zone` (story, things_to_say) | `ImmersiveCard` zone taps |
| `line_shared` | `surface` (feed, article, say_this) | the `ShareLink`s and copy buttons |
| `pregame_opened` | `entry` (tab, push, club_page), `phase` | `MyTurnView` when the prep segment appears |
| `pregame_card_completed` | `card` (opponent_quiz, seven_words, sayings), `score`, `of`, `phase`, `fixture_id` | the round-finished paths in `MyTurnStore` |
| `line_saved` | `source` (slip, say_this) | slip "Save for the game", Say This save |
| `practice_completed` | `module` (quiz, lingo, say_this), `pack`, `score`, `of` | the existing end-of-round screens |
| `notifications_banner` | `action` (shown, turn_on, not_now) | the Feed banner |

### What she changes *(New 2026-10-25 — events 13–17)*

The twelve events above measure what she *consumes*. Nothing measures what she
*decides*, and that is the half with the clearest product signal in it: a person
changing a setting has formed an opinion and acted on it. 39% of devices have
changed something since onboarding and we have no idea what.

| Event | Properties | Hook | Why it earns its place |
|---|---|---|---|
| `follow_changed` | `action` (added, removed), `club`, `count_after` | `TeamPickerSheet` on Done, one event per change | Which clubs people reach for, and whether the two-club feature is used. Only 5 of 72 follow two clubs today — if nobody adds a second after install, the feature is a cost, not a draw. |
| `tier_changed` | `from`, `to` | the tier control in `SettingsView` | **The only honest "too many pushes" signal we will ever have.** `PUSH_RULES.md` says every entry in its §3 shipped first and was walked back after a complaint — a complaint is a user who bothered. A user who silently turns the dial down is the same opinion, uncounted. |
| `notification_permission_changed` | `to` (granted, denied), `via` (banner, settings, os) | `NotificationService` authorization callback | Separates "never asked properly" from "asked and refused". A refusal that happens later, after a bad push week, is a different event from one at onboarding. |
| `settings_row_opened` | `row` | `SettingsView` row taps | Distinguishes a setting nobody wants from one nobody can find. |
| `data_deleted` | `days_since_install`, `last_tier` | `SettingsView.deleteData()`, sent **before** the wipe | The clearest exit signal in the app, and today it leaves nothing behind at all. The row vanishes and so does the reason. |

`data_deleted` must be sent and flushed before the local wipe, and the event
survives the wipe on the server by design — the install_id is deleted, so the
event is anonymous by the time anyone reads it. That is the one place where
"delete everything" and "learn from the exit" have to be reconciled deliberately
rather than by accident.

Send in batches: queue on the phone, flush on background and every 30 events,
drop the queue after 7 days offline. One check left behind: a unit test that
every event name the app can send is in the RPC's allow-list.

---

## Deciding from it *(New 2026-10-25)*

The failure mode this section exists to prevent: reading a number off a
dashboard, believing it, and cutting something real. Three of our four outages
were caused by acting on the most satisfying explanation rather than the
measured one (`OUTAGE_LESSONS.md`, lesson 4). The same instinct applied to
product data costs features instead of uptime.

**Decide the threshold before you look.** For every question, write down what
result would change the decision, in advance. "Does Pre-game deserve its own
tab?" becomes: *if fewer than a third of weekly actives open Pre-game in a month
where their club played twice, it does not.* Written after the fact, any number
supports whatever you already wanted.

**Unused and undiscovered are different findings.** A feature with no
`*_completed` events and no `tab_viewed`/`settings_row_opened` for its entry
point was never found. A feature with entries and no completions was found and
rejected. Only the second is a candidate to cut; the first is a navigation bug.
This distinction is the main reason `settings_row_opened` is on the list.

**Nothing gets cut on one club's behaviour.** See premise 1. If Arsenal and
everyone-else disagree, the finding is "unknown".

**Nothing gets cut on fewer than 30 people or one month, whichever is longer.**
With this base, almost everything will fail that bar through 2026. That is the
correct outcome: the first year of this data is for watching individual paths
and building history, not for making cuts.

**Three decisions it is explicitly being built to inform**, in order:

1. **Does Pre-game deserve its own tab?** From `pregame_opened` by `entry`, and
   the share of matches she was ready for.
2. **Is the push volume right?** From `push_open_rate` by kind, crossed with
   `tier_changed` net movement. A push kind with a low open rate *and* tier
   downgrades following it is the first candidate for `PUSH_RULES.md` §3.
3. **Is the two-club feature worth its complexity?** From `follow_changed`. It
   has cost real engineering (the arrays model, recipient matching on scalar and
   array, a debug flag to make it testable at all) and 5 of 72 people use it.

---

## What we look at

- **A weekly SQL digest**, added to the `gd-maintenance` report: new installs,
  activated, ready-for-a-match by fixture, match retention by install week, push
  open rate by kind, onboarding funnel, net tier movement, follows added and
  removed. Split Arsenal / everyone else throughout.
- **A small private dashboard page** (an Artifact reading the same views) once
  there are more than a handful of users.
- The digest is the product, not the dashboard. A number that only exists on a
  page someone has to remember to open is a number nobody reads.

---

## Build order

1. **Migration:** `app_events`, `log_events` RPC, grants and caps, both indexes,
   the 13-month retention cron, and `analytics_blackouts` seeded with the three
   known windows. The db-health §7 allow-list gains `log_events`. Retention and
   indexes ship in this migration, not a later one.
2. **iOS:** an `Analytics` service (queue, batch, flush) and the seventeen hooks,
   in the next build after 2.3.
3. **Privacy label and policy text**, before that build is submitted.
4. **SQL views and the weekly digest**, with the blackout exclusion and the
   club split built in from the first query.
5. **The Meta `activated` event** and the ad set's optimisation goal.

Steps 1 and 4 are worth doing even if 2 slips: the blackout table and the
club-split views make the data we *already* have honest, and `get_insights()`
can move onto them immediately.

---

## What this plan deliberately does not do

- **No third-party analytics.** Reconsider past a few thousand users.
- **No session recording, no heatmaps, no free text.** Nothing that could carry
  her name, his name, or anything she wrote.
- **No per-event network call.** Batched or not at all.
- **No metric that only exists in a dashboard.** If it matters, it is in the
  weekly digest, in SQL, in the repo.
