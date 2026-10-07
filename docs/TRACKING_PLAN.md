# Tracking plan: activation and behaviour

Status: plan, not built (2026-10-07). Owner: Anton.

## Why

Today the only usage signal is Meta's automatic app-open event and `device_tokens.created_at` for people who allowed notifications. We cannot say whether anyone opens Pre-game, which cards she reads, or whether she comes back for the next match. With about 20 real users, numbers will not be statistically meaningful for months; the point now is to see each person's path (did she get ready for his game?) and to have the history in place before growth makes it matter.

## The questions it must answer

1. **Activation:** did she get ready for his first game after installing? (A Pre-game card finished before that kickoff.)
2. **Retention, in football time:** does she come back before his next matches? Weeks are the wrong clock for a hobby that runs on fixtures.
3. **What she uses:** Pre-game vs Feed vs His Team vs the rest of My Turn; which pushes she opens; which lines she saves or shares.
4. **Where she drops:** which onboarding step loses people; which permission she refuses.
5. **What to build next:** the parts nobody touches are candidates to cut; the parts that bring her back are where to invest.

## Definitions

| Metric | Definition |
|---|---|
| Activated | `pregame_card_completed` with `phase = before` for the first fixture of her first club whose kickoff is after `onboarding_completed`. |
| Ready for a match | At least one `pregame_card_completed` (phase before) for that fixture before kickoff. |
| **North star: matches she was ready for** | Count of fixtures per user, per week, where she was ready. |
| Match retention | Of her club's first 3 fixtures after install, how many she was ready for (0 to 3). Report the share with 2 or more. |
| Classic retention | Opened the app in week 1 and in week 4 after install, for comparing with other apps. |
| Push open rate | `push_opened` divided by pushes sent (`pipeline_health` `apns_send`), by push kind. |

## Where the events go

**Our own table, through one RPC.** A `public.app_events` table written by a SECURITY DEFINER RPC `log_events(p_install_id uuid, p_events jsonb)`, same pattern and caps as the three existing RPCs (migration 129): batch of at most 50 events, at most 8 KB, known event names only, a per-install rate limit, `REVOKE ... FROM PUBLIC, anon, authenticated` on the table and an explicit grant on the function. Queried with SQL; joins to `device_tokens` and the fixtures we already hold.

- No new SDK, no third party, nothing sent outside Supabase.
- **Meta gets one event only:** `activated` (as a custom app event through the FacebookCore SDK already in the app), so the Arsenal ad set can optimise for women who get ready for a match rather than for installs.

Rejected: sending everything to Meta (behaviour data with an ad company, hard to query); a product-analytics SDK such as PostHog or TelemetryDeck (a new dependency and a new processor for about 20 users; reconsider past a few thousand).

## Identity and privacy

- `install_id`: a random UUID created on first launch, stored on the phone, never derived from the APNs token or the advertising ID. Delete My Data deletes every event for it and creates a new one.
- Never in an event: her name, his name, free text, the APNs token, location.
- Common properties on every event: `app_version`, `build`, `club` (slug), `tier`, `relationship`, `days_since_install`, `next_fixture_in_hours` (negative after kickoff).
- Keep events 13 months, then aggregate. The 90-day purge of inactive device tokens (migration 129) then no longer erases retention history, because cohorts come from `app_events`.
- Before the build ships: add "product interaction, not linked to you, not used for tracking" to the App Store privacy label, and add a usage-data paragraph to the privacy policy. No ATT prompt is needed for first-party analytics that are not shared.

## Events (version 1)

Twelve events. Each is logged at one point in the code; the hook is named so whoever builds it does not have to search.

| Event | Properties | Hook |
|---|---|---|
| `app_opened` | `source` (icon, push, link) | `GoalDiggerApp` scene becomes active |
| `onboarding_step_viewed` | `step` | `OnboardingFlow`, on `step` change |
| `onboarding_completed` | `seconds`, `notifications` (granted, denied, later), `calendar` (on, off) | `OnboardingFlow.completeOnboarding()` |
| `push_opened` | `kind` (kickoff, goal, ht, ft, news, prep, sunday_brief), `content_id` | `AppDelegate.userNotificationCenter(_:didReceive:)` |
| `tab_viewed` | `tab` (feed, matchday, club, my_turn) | `MainTabView` selection change. Settings is a sheet from 2.4: `settings_opened` |
| `feed_card_opened` | `position`, `content_type`, `zone` (story, things_to_say) | `ImmersiveCard` zone taps |
| `line_shared` | `surface` (feed, article, say_this) | the `ShareLink`s and copy buttons |
| `pregame_opened` | `entry` (tab, push, club_page), `phase` | `MatchdayView` when Before appears (My Turn's prep segment before 2.4) |
| `matchday_after_opened` | `entry` (tab, ft_push), `hours_since_ft`, `fixture_id` | `MatchdayView` when After appears |
| `pregame_card_completed` | `card` (opponent_quiz, seven_words, sayings), `score`, `of`, `phase`, `fixture_id` | the round-finished paths in `MyTurnStore` |
| `line_saved` | `source` (slip, say_this) | slip "Save for the game", Say This save |
| `practice_completed` | `module` (quiz, lingo, say_this), `pack`, `score`, `of` | the existing end-of-round screens |
| `notifications_banner` | `action` (shown, turn_on, not_now) | the Feed banner |

Send in batches: queue on the phone, flush on background and every 30 events, drop the queue after 7 days offline. One check left behind: a unit test that every event name the app can send is in the RPC's allow-list.

## What we look at

- **A weekly SQL digest**, added to the `gd-maintenance` report: new installs, activated, ready-for-a-match by fixture, match retention by install week, push open rate by kind, onboarding funnel.
- **A small private dashboard page** (an Artifact reading the same views) once there are more than a handful of users.
- **The first decision it should inform:** whether Matchday (2.4, Pre-game's own tab) earns its place, from `pregame_opened` by `entry` and the share of matches she was ready for.

## Build order

1. Migration: `app_events`, `log_events` RPC, grants and caps; the db-health §7 allow-list gains `log_events`.
2. iOS: an `Analytics` service (queue, batch, flush) and the twelve hooks, in the next build after 2.3.
3. Privacy label and policy text, before that build is submitted.
4. SQL views and the weekly digest.
5. The Meta `activated` event and the ad set's optimisation goal.
