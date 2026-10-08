# GoalDigger: status

What is true on **2026-10-07**. How it works: [ARCHITECTURE.md](./ARCHITECTURE.md). Known issues: [AUDIT_FINDINGS.md](./AUDIT_FINDINGS.md). Rules for anyone working here, agents included: [CLAUDE.md](./CLAUDE.md). Keep this file to one page; history goes to git.

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

## On the branch for the next build

- Feed cards end at the bottom of the screen, so "Your move" no longer runs under the iOS 26 tab bar.
- A Feed banner when notifications are off ("Not now" hides it for two weeks).
- Onboarding shows his team, the manager and how it works before asking for the mode, notifications and the calendar.
- One name, "Pre-game", for the section; "Pre-game ›" on His Team opens it.
- My Turn: one "Your lines" list for slip lines and saved Say This lines; "Get to know {opponent}" only in Pre-game; no "X of Y got" counters in Lingo.
- The tracking prompt says "free", not "free to try".

## Paused, and why

- **Day-before push** (migration 125, "{opponent} tomorrow"): paused by migration 126 until 2.3 is live, because only 2.3 opens Pre-game from it. `130_unpause_prep_reminder.sql.PENDING_APP_RELEASE` turns it back on; apply it when Apple releases 2.3.
- `content-generator` and `content-reviewer` Edge Functions: dormant by design. All live content comes from routines.
- `gd-news-wc` is off and `gd-champions-league` is retired (Europe is `gd-europe`).

## Open

- No full-time articles since 2026-09-20 because no followed club has played since then: the international window runs to the weekend of 10 October. Not a fault.
- `gd-season-state` last wrote `team_season_state` on 2026-09-07 and that table still lists last season's fixtures. The app only reads it for country follows (switched off) and the unreachable season primer; the "season so far" card comes from the team page. Retire the routine or point it at 2026-27.
- The `gd-maintenance` cloud environment cannot reach the database directly, so most of its checks come back blocked.
- Alerts reach nobody: `dev_alert_devices` is empty (74 unalerted `client_errors`).
- My Turn copy says he/him for every relationship type (deferred, NEW-9).
- Privacy policy: new text in [docs/PRIVACY_POLICY_DRAFT.md](./docs/PRIVACY_POLICY_DRAFT.md), not published; Settings opens the site's home page.
- No in-app analytics beyond Meta's automatic app-activation event. Plan: [docs/TRACKING_PLAN.md](./docs/TRACKING_PLAN.md).

## Next

1. When Apple releases 2.3: apply migration 130.
2. Publish the privacy policy at its own URL and match the App Store privacy label to the privacy manifest.
3. Build the tracking plan's first phase into the next build.
4. Register a device in `dev_alert_devices`.
5. Decide `gd-season-state`: retire it or move it to 2026-27.

## History

Until 2026-10-07 this file was a running log; read it with `git show 62403dd:STATUS.md`. Do not act on the recovery steps in that version: the cron key rule changed (IOS_GOTCHAS.md §14). Phase log to 2026-06-12: [IMPLEMENTATION_PROGRESS.md](./IMPLEMENTATION_PROGRESS.md). Security history: [CHANGELOG_SECURITY.md](./CHANGELOG_SECURITY.md).
