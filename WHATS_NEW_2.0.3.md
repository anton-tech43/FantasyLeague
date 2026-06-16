# What's new — 2.0.3 + mid-WC backend (June 2026)

A single session's worth of World Cup improvements and live-fix work. Two halves:
backend changes that are **already live in production** (they reach the installed app
with no update), and an **iOS 2.0.3 build** that ships when archived + submitted.

Branch: `claude/intelligent-thompson` · commits `7f3c349..4026d6f` (12).

---

## App Store "What's New" (for the 2.0.3 submission)

> Live match minute: the lock-screen Live Activity and the in-app live card now show
> the current minute out of 90, so you always know where the game is.
>
> Your feed always knows what's next. Every country leads with a "Coming up" card and a
> live countdown to the next World Cup match, plus a build-up the day before, so the
> feed is never empty in the run-up.
>
> Make it yours: follow a partner, parent, sibling or friend (their name, used
> throughout), and tell us how much football you already know.
>
> Goals as they happen: alerts now name the scorer and the minute. And a quick read on
> every match, likely win, could go either way, or likely loss, with an "as expected /
> upset / surprise" line on the result.
>
> Friendlier onboarding: tap Premier League or World Cup to see what they mean, a
> clearer how-it-works walk-through, and a better notifications nudge.
>
> Calendar: see your last result, and a game you're watching stays put while it's live.
> Plus faster country switching, with your notifications following the switch.

(No em-dashes per the campaign rule; listing may say "World Cup".)

---

## Live now (backend, no app update needed)

- **Live match minute** plumbed end to end: `match_status_state.elapsed` (migration 066),
  populated by match-watcher, pushed to the Live Activity and returned by
  `live-brief-current`. (`7f3c349`)
- **Goalscorer + minute** woven into WC goal alerts: match-watcher fetches
  `/fixtures/events` on a detected goal and appends "⚽ Scorer 47'". (`4cd9b20`)
- **FIFA world rankings** seeded into `teams.strength_rank` for all 48 WC countries
  (migration 067, applied). (`10a2254`)
- **Match framing from rankings**: post-FT result body now reads "as expected / upset /
  dropped points / surprise". Pre-game favorite verdict on the team-page Coming-up card.
  Shared helper `_shared/matchup-verdict.ts` (12-place FIFA gap / 5 league positions).
  (`e3db759`)
- **Feed is never empty** (the big one): WC news is newsworthiness-gated, so ~36 of 48
  countries got zero items. `matchday-reminder` now writes a deterministic build-up
  `content_item` ~24h before kickoff for every country with a fixture in window (not just
  followed ones), feed-only, idempotent. (`eb0ae0d`)
- **Content-quality guards** in `content-generator`: talking points must be conversational,
  body must add value beyond the headline (+ a dedup guard). (`31b9a30`)

## On a branch / built, pending your action

- **iOS 2.0.3** (build 7, green) — archive + submit when ready:
  - Live minute "63' / 90" on the Live Activity + feed card. (`e6d1cc3`)
  - News feed always leads with a "Coming up" next-match card + live countdown; countdown
    empty-state fallback. (`4026d6f`, `c0f9285`)
  - Configurable relationship (partner / parent / sibling / friend) + name-based copy;
    "how much do you know about football?" question. (`8e8a142`)
  - Tappable Premier League / World Championship glossary terms; how-it-works explainer
    replaces the stale weekly-rhythm card; stronger notification opt-in; favorite tag on
    the Coming-up card. (`af252db`)
  - Calendar: collapsible "last games" with results; a live game stays put instead of
    rolling to the next fixture. (`469d6f6`)
  - Faster country switch (no stale-team flash) + push token re-registers on a country
    change. (`c0f9285`)
- **`goaldigger-routines` branch `feat/content-quality-prompts`** — merge to go live, then
  test-run gd-news-wc:
  - Adversarial sub-agent self-review before posting; gd-news-wc enriches the FT result
    row in place; conversational-talking-points + headline≠body + insider topic-diversity
    rules. (Agent tool enabled on the three routines.)

## Notes
- "World Championship" in app-visible copy; "World Cup" only in the App Store listing.
- The routine self-review needs a post-merge `gd-news-wc` test run to confirm the
  sub-agent spawns in the routine runtime (fallback: same-session second pass).
