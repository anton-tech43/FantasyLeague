# GoalDigger: status

What is true on **2026-11-04**. How it works: [ARCHITECTURE.md](./ARCHITECTURE.md). Known issues: [AUDIT_FINDINGS.md](./AUDIT_FINDINGS.md). Rules for anyone working here, agents included: [CLAUDE.md](./CLAUDE.md). Keep this file to one page; history goes to git.

## Live on the App Store: 2.2 (12)

- Released 2026-09-19 (Apple's lookup feed). Free, no in-app purchase. iPhone, iOS 17+.
- Scope: the 20 Premier League clubs, up to two followed per device. Matches covered in the Premier League, Champions League, Europa League, Conference League, League Cup and FA Cup. The World Championship is retired (countries inactive, `CountryFollowing.isEnabled = false`).
- Content comes from claude.ai routines (schedule: the goaldigger-routines README, "Schedules, in one place"). The `gd-maintenance` routine checks the system on Tuesdays and Fridays ([MAINTENANCE.md](./MAINTENANCE.md)).
- **The claude.ai account that runs every routine is closing (noted 2026-10-07).** When it goes, all content and gd-maintenance stop and `match-watcher`'s routine URLs go dead. Every routine's config and the rebuild steps are in goaldigger-routines `REBUILD.md` + `triggers/`.
- Server-side, so 2.2 users already have it:
  - live kickoff, goal, half-time and full-time pushes for followed clubs in all six competitions, gated per tier (`_shared/push-tiers.ts`); half-time and full-time end with a line to say;
  - Live Activities for club matches and cup ties;
  - official squad numbers (migration 127) and fan names (128);
  - the 2026-10-04 backend QA fixes (migration 129: payload caps, registration rate limits, retention sweeps), and the server functions' caller check narrowed to the cron key and the service key (2026-10-07).
- Known in 2.2, fixed in 2.3: changing "Your Mode" in Settings never reaches the server, so push volume does not change.

## In App Store review: 2.3 (16)

Submitted 2026-10-07 (builds 13 to 16 went to TestFlight from 2026-09-30).

- **Pre-game** in My Turn, opened once per new fixture: "Get to know {opponent}" (a two-option quiz), "7 words for the game" (an Overheard round) and "Prepare some sayings for the game" (a slip of up to seven lines, marked "came up" after full time).
- Lingo: Overheard rounds with two options, plus a 158-word dictionary.
- His Team: manager portraits, a ones-to-know carousel, shirt numbers.
- First run lands on the followed club's feed. The paywall and the football-knowledge step are gone from the code.
- 2026-10-04 QA app fixes: privacy manifest (`PrivacyInfo.xcprivacy`), a push token request on every launch, Live Activities only after onboarding and with a stale date, a complete Delete My Data, Dynamic Type and VoiceOver fixes.

## In a PR, not merged: 2.4 (17), Matchday tab

Branch `claude/matchday-tab`. Nothing deployed until the PR is kept.

- Tabs: Feed · Matchday · his club · My Turn. Settings is a gear on Feed and the club page.
- Matchday › After: the game just played, from a `last_match` card match-watcher writes at full time (needs the match-watcher deploy). Matchday › Before: Pre-game, moved out of My Turn.
- The full-time push opens After; the day-before push and "Pre-game ›" open Before.

## 2026-11-01 to 11-04: council decisions, live features, first bug hunt

Server and routine changes are live; app changes ship with 2.4 (18) built from this branch.

- **App council round 2** (113 decisions): Matchday follows the switcher's club and shows the live score; club page trimmed (After card moved to Matchday, injured key players marked "Out", form letters, season inside "How they're doing"); My Turn order Say This · Lingo · Quiz with "More packs"; offside explained one way everywhere; skeletons with shimmer while pages load; "Before the match" stamp on pre-match cards; shootouts count as W/L.
- **Pushes**: goal and full-time copy per side with no lines about him; Light gets only big news; tournaments (not the League Cup) to Match-fit and Deep; nothing before 07:00 London; one push per club per 3 h; the matchday reminder for every cup round; the Monday brief at 08:00 London; "kickoff soon" at T−25 with the lineup line on.
- **Live Activity**: status in words, a dimmed score with "No update since …" when stale, broadcast channels on iOS 18+ (build 16 and later, per side), live takes as a silent note at 30', half-time and 70' (rules tuned on real Champions League matches), a frozen-feed alarm.
- **Portraits**: 111 manager and player portraits re-rendered at 900 px.
- **Bug hunt** (`.claude/skills/bug-hunt/`, first run 2026-11-03): findings were reproduced and fixed the same week; the report is kept outside this public repo. Lessons for others: [OUTAGE_LESSONS.md](./OUTAGE_LESSONS.md) part 2.

## Next TestFlight build: 2.4 (18)

Bumped 2026-10-29. The archive stops at signing until the account holder accepts Apple's
updated Program License Agreement (developer.apple.com); Xcode then registers the new
App Group by itself.

- Usage tracking: 23 events into `app_events` (migrations 142–144), weekly digest
  `scripts/tracking-digest.sh`, Meta `activated` event. Plan and status:
  [docs/TRACKING_PLAN.md](./docs/TRACKING_PLAN.md).
- `push_delivered` from a new Notification Service Extension: shows push-only users
  (active / passive / quiet per week). Verify on a phone: the simulator never runs it.
- Onboarding's notifications step shows an example push and the live score.
- Server side, already live: Live Activity minute-only updates at priority 5.
- Before submitting: App Store Connect privacy answers (Product Interaction: Analytics +
  Third-Party Advertising, tracking yes) and the policy paragraph on carrd (TRACKING_PLAN
  "Step 3").

## On the branch for the next build

- Feed cards end at the bottom of the screen, so "Your move" no longer runs under the iOS 26 tab bar.
- A Feed banner when notifications are off ("Not now" hides it for two weeks).
- Onboarding shows his team, the manager and how it works before asking for the mode, notifications and the calendar.
- One name, "Pre-game", for the section; "Pre-game ›" on His Team opens it.
- My Turn: one "Your lines" list for slip lines and saved Say This lines; "Get to know {opponent}" only in Pre-game; no "X of Y got" counters in Lingo.
- The tracking prompt says "free", not "free to try".

## Paused, and why

- **Lineup line in the kickoff push** (LOCK-02-14): the push moved from T−30 to T−25 on 2026-11-03 (the lineup landed at T−29 in the first three matches that logged one). Behind the `LINEUP_PUSH_ENABLED` secret; Anton approved switching it on after the T−25 deploy. A derby follower always gets the plain body.
- `content-generator` and `content-reviewer` Edge Functions: dormant by design. All live content comes from routines.
- `gd-news-wc` is off and `gd-champions-league` is retired (Europe is `gd-europe`).

## Open

- No full-time articles since 2026-09-20 because no followed club has played since then: the international window runs to the weekend of 10 October. Not a fault.
- `gd-season-state` last wrote `team_season_state` on 2026-09-07 and that table still lists last season's fixtures. The app only reads it for country follows (switched off) and the unreachable season primer; the "season so far" card comes from the team page. Retire the routine or point it at 2026-27.
- The `gd-maintenance` cloud environment cannot reach the database directly, so most of its checks come back blocked.
- My Turn copy says he/him for every relationship type (deferred, NEW-9).
- Privacy policy: new text in [docs/PRIVACY_POLICY_DRAFT.md](./docs/PRIVACY_POLICY_DRAFT.md), not published; Settings opens the site's home page.
- Usage analytics are built but reach nobody until 2.4 (18) is out; the digest is empty until then.

## Next

1. Finish the routines' switch to their own narrow credential (goaldigger-routines REBUILD.md, "Switching to routine-ingest"), then rotate the old keys.
2. Publish the My Turn content (2026-11-04) with `tools/myturn/publish_content.sh`.
3. Publish the privacy policy at its own URL and match the App Store privacy label to the privacy manifest.
4. After 2.4 is released, switch the ad set's goal to `activated`.
5. Decide `gd-season-state`: retire it or move it to 2026-27.

## History

Until 2026-10-07 this file was a running log; read it with `git show 62403dd:STATUS.md`. Do not act on the recovery steps in that version: the cron key rule changed (IOS_GOTCHAS.md §14). Phase log to 2026-06-12: [IMPLEMENTATION_PROGRESS.md](./IMPLEMENTATION_PROGRESS.md). Security history: [CHANGELOG_SECURITY.md](./CHANGELOG_SECURITY.md).
