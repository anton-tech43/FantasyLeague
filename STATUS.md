# GoalDigger: status

What is true on **2026-10-07**. How it works: [ARCHITECTURE.md](./ARCHITECTURE.md). Known issues: [AUDIT_FINDINGS.md](./AUDIT_FINDINGS.md). Rules for anyone working here, agents included: [CLAUDE.md](./CLAUDE.md). Keep this file to one page; history goes to git.

## Live on the App Store: 2.2 (12)

- Live since about 2026-09-23. Free, no in-app purchase. iPhone, iOS 17+.
- Scope: the 20 Premier League clubs, up to two followed per device. Matches covered in the Premier League, Champions League, Europa League, Conference League, League Cup and FA Cup. The World Championship is retired (countries inactive, `CountryFollowing.isEnabled = false`).
- Content comes from claude.ai routines (schedule: the goaldigger-routines README, "Schedules, in one place"). The `gd-maintenance` routine checks the system on Tuesdays and Fridays ([MAINTENANCE.md](./MAINTENANCE.md)).
- Server-side, so 2.2 users already have it:
  - live kickoff, goal, half-time and full-time pushes for followed clubs in all six competitions, gated per tier (`_shared/push-tiers.ts`); half-time and full-time end with a line to say;
  - Live Activities for club matches and cup ties;
  - official squad numbers (migration 127) and fan names (128);
  - the 2026-10-04 backend QA fixes (migration 129: payload caps, registration rate limits, retention sweeps).
- Known in 2.2, fixed in 2.3: changing "Your Mode" in Settings never reaches the server, so push volume does not change.

## In TestFlight: 2.3 (16)

Builds 13 to 16, 2026-09-30 to 2026-10-05. **Not yet submitted.**

- **Pre-game** in My Turn, opened once per new fixture: "Get to know {opponent}" (a two-option quiz), "7 words for the game" (an Overheard round) and "Prepare some sayings for the game" (a slip of up to seven lines, marked "came up" after full time). After a game the segment reads "This week".
- Lingo: Overheard rounds with two options, plus a 158-word dictionary.
- His Team: manager portraits, a ones-to-know carousel, shirt numbers.
- First run lands on the followed club's feed. The paywall and the football-knowledge step are gone from the code.
- 2026-10-04 QA app fixes: privacy manifest (`PrivacyInfo.xcprivacy`), a push token request on every launch, Live Activities only after onboarding and with a stale date, a complete Delete My Data, Dynamic Type and VoiceOver fixes.

## Paused, and why

- **Day-before push** (migration 125, "{opponent} tomorrow"): paused by migration 126 until 2.3 is live, because only 2.3 opens Pre-game from it. The unpause statement is in 126's header; migration 129 moved its hours to 08:00 and 09:00 UTC.
- `content-generator` and `content-reviewer` Edge Functions: dormant by design. All live content comes from routines.
- `gd-news-wc` is off and `gd-champions-league` is retired (Europe is `gd-europe`).

## Open

- `team_season_state` was last written on 2026-09-07, so the "season so far" card on His Team is a month old. `gd-season-state` needs looking at.
- The last matchday article (`gd-matchday`) is from 2026-09-20.
- The `gd-maintenance` cloud environment cannot reach the database directly, so most of its checks come back blocked.
- Alerts reach nobody: `dev_alert_devices` is empty (74 unalerted `client_errors`).
- My Turn copy says he/him for every relationship type (deferred, NEW-9).
- Privacy policy: new text in [docs/PRIVACY_POLICY_DRAFT.md](./docs/PRIVACY_POLICY_DRAFT.md), not published; Settings opens the site's home page.
- No in-app analytics beyond Meta's automatic app-activation event, so activation and retention cannot be measured yet.

## Next

1. Submit 2.3.
2. Unpause the day-before push once 2.3 is live.
3. Publish the privacy policy at its own URL and match the App Store privacy label to the privacy manifest.
4. Get `gd-season-state` and `gd-matchday` writing again.
5. Register a device in `dev_alert_devices`.

## History

Until 2026-10-07 this file was a running log; read it with `git show 62403dd:STATUS.md`. Do not act on the recovery steps in that version: the cron key rule changed (IOS_GOTCHAS.md §14). Phase log to 2026-06-12: [IMPLEMENTATION_PROGRESS.md](./IMPLEMENTATION_PROGRESS.md). Security history: [CHANGELOG_SECURITY.md](./CHANGELOG_SECURITY.md).
