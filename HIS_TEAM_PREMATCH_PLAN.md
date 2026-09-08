# His Team: pre game talk, live tables, a calendar that survives the season

**Status:** plan, 2026-09-09. Builds as the next task after the My Turn redesign.
Owner's brief (translated): "Under His Team, the upcoming game should be at the top,
and instead of 'Tap for more' it should say 'Pre game talk', with info about the match,
what to expect, who is favourite, useful information before the game. Also review the
routines that keep the PL and CL tables updated so they are always current, and the
calendar, since it will change through the season with all the cups."

Everything below comes from a read-only audit of the code on 2026-09-09. Line numbers
are from that day.

---

## 1. What is true today

### The Coming-up card is a shell
- It is card **9 of 11** on the Info tab (`TeamPageView.swift` L434-438), under mood,
  this-week, basics, manager, ones to know, rivalry, form and season.
- Its footer is the literal `"Tap for more ›"` (`TeamPageCard.swift` L153), not a
  parameter. Expanded, it shows a countdown and a `preview` sentence.
- **For a PL club nothing pre-match is written by anything**: `next_fixture.favorite`,
  `talking_point`, `ones_to_know.opponent`, `this_week`, `recent_results`, a build-up
  feed card, a `preview_fixture_id` card — every one of these exists for World
  Championship countries and none for clubs. The whole "Tonight: / This weekend:" label
  ladder (`comingUpLabel`, L963-977) is dead code because the card only shows it when a
  talking point exists.
- The one club sentence, `next_fixture.preview`, is written by the **Monday** routine
  `gd-team-page` and carried forward verbatim by every two-hourly refresh
  (`team-page-generator/index.ts` L1027). After that fixture is played the card names the
  *next* opponent above a sentence about the *previous* one, for up to six days.
- `CLUB_FAVORITE_GAP` exists in `_shared/matchup-verdict.ts` and is used only by its
  test. `teams.strength_rank` exists for clubs.

### The tables
- Standings move only when `goaldigger-daily-pipeline` fires: **9 times a day, 06:00 to
  22:00 UTC**, nothing overnight. Each run fetches the identical `?league=39` table once
  **per club**, twenty times, ~180 of ~430 calls.
- `match-watcher` knows full time to the minute and does nothing with it for clubs (its
  only `team_pages` write is the WC post-match card).
- Worst cases: Saturday 17:30 kickoff → table stale ~1h40; Tuesday 20:00 Champions League
  → ~1h10; anything finishing after 22:00 UTC → stale until 06:00.
- Club path reads `fixtures_next` with `.limit(1).single()`: one empty payload from
  API-Football's nightly cache refresh and `europe_standings` is deleted for two hours.
  The standings read already walks past empties ("newest good row wins"); fixtures does
  not.
- `europe_standings` is derived from `next=10` (~5 weeks). The gap between the league
  phase and the knockouts is longer, so the table drops off the page mid-competition.

### The calendar
- `upcoming_fixtures` = `next=10` capped at 8 rows (L1850): about four weeks for a club
  in Europe. A January FA Cup tie or the Christmas programme is invisible until then.
- No league filter on the club path, so friendlies and uncovered competitions appear as
  "Fixture".
- `PST`, `CANC`, `ABD`, `SUSP`, `TBD` appear nowhere in the codebase. A postponed match
  keeps its original slot on the Calendar tab and in the user's iOS calendar until the
  slot slides 3h into the past, then vanishes silently.
- `dropFinished` (corroborate against `fixtures_last`) runs on the WC path only.
- `CalendarSyncService` prefers `team_season_state.next_fixtures`, a column nothing has
  written since May; it only falls through to the live team page because every stale row
  is in the past. `CalendarOptInView` (L146-149) reads the same dead column with no date
  filter, so onboarding can list last season's matches.
- EventKit sync is wipe-and-reinsert (L108-116), throttled to 30 min and to the app
  being foregrounded.
- `recent_results` is WC-only (L1291), so the "Show last games" row a PL user sees on
  the Calendar tab has nothing behind it.

---

## 2. Principles

1. **Deterministic first, prose second.** Everything on the pre game talk that can come
   from data (kickoff, competition, venue, positions, points gap, form, favourite,
   opponent's ones to watch) is written by `team-page-generator` in `dynamic_only`
   mode every two hours and at full time, zero Claude. The Monday routine's sentence is
   colour on top and is dropped the moment its fixture is played.
2. **Full time is an event, not a schedule.** The two clubs that just played get their
   page refreshed from the whistle, not from the next cron slot.
3. **Fetch a table once.** One `/standings` call per competition per run, shared across
   clubs; the saved calls pay for the full-time refreshes.
4. **A fixture has a status.** Postponed is a state the calendar shows, not a row that
   disappears.
5. **The dead column dies.** The app stops reading `team_season_state.next_fixtures`.

---

## 3. Build

### A. Pre game talk (backend `team-page-generator` + `_shared/stakes-templates.ts`)

Club `dynamic_only` path writes, every refresh:
- `next_fixture.favorite` via `preMatchVerdict(myRank, oppRank, CLUB_FAVORITE_GAP)` where
  rank = current league position from the standings card (both clubs are in the table);
  for a cup opponent outside the league, fall back to `teams.strength_rank` if present,
  else no verdict.
- `next_fixture.preview` = `renderClubPreMatch(...)`, a deterministic template in the
  league's vocabulary: competition and round, home/away, both positions and the points
  gap ("3rd against 12th, nine points between them"), each side's form string, the
  favourite verdict in words, and for a cup tie the round and what a win means
  (`knockoutOutcome`/`roundLabel` from `league-helpers.ts`). Two to four sentences. Then a
  blank line and the Monday routine's colour sentence **only if its recorded fixture id
  matches** (see routine change below).
- `next_fixture.talking_point` = one line she can say before kickoff, templated from the
  same facts ("Ask him if 3rd against 12th is as easy as it sounds.").
- `ones_to_know.opponent` from the opponent's own `team_pages` row (the WC
  `loadOpponentCardInfo` path, reused), so "Their ones to watch" renders for clubs.
- `this_week` for clubs via the existing `renderThisWeek`, given league vocabulary.
- `recent_results` for clubs from `fixtures_last` (so "Show last games" has data).
- Bugs fixed on the way: `fixturesLog` becomes newest-good-wins like standings;
  `europe_standings` stays while the club has played in that competition within 60 days
  (from `fixtures_last`), not only while a fixture is in the next ten.

Routine (`goaldigger-routines/TEAM_PAGE_PROMPT.md`, `post_team_page.sh`): the Monday
`next_fixture_preview` is written together with `next_fixture_preview_fixture_id` so the
deterministic path can drop it once that fixture is played.

### B. Freshness (backend `data-fetcher`, `match-watcher`)

- `data-fetcher` accepts `{ team_ids: [...] }` and fetches only those; and fetches each
  competition's `/standings` once per run, sharing the payload across clubs while still
  writing every club's `raw_fetch_logs` row so no consumer changes.
- `match-watcher`, on observing FT for a fixture with one of our clubs: call
  `data-fetcher` for the playing clubs, then `team-page-generator dynamic_only` for
  each. ~14 API calls per match; covered many times over by the dedupe.
- Result: the table, form, coming-up and Europe table agree with the score within
  ~2 minutes of the whistle, at any hour.

### C. Calendar (backend `buildUpcomingFixtures`, iOS)

- `next=20` from data-fetcher, cap 15 on the page; filter to covered competitions
  (39, 2, 3, 848, 48, 45); apply `dropFinished` against `fixtures_last` on the club path.
- Status carried per fixture: `PST` renders as "Postponed" with one dot and no time;
  `CANC`/`ABD`/`WO` are dropped; `TBD` shows the date with "Time TBC".
- iOS `CalendarSyncService`: team page first, season state never; postponed fixtures are
  not written to EventKit; the competition survives whichever source. `CalendarOptInView`
  reads the team page's `upcoming_fixtures` too.
- iOS Calendar tab: "Show last games" now has club data.

### D. iOS (`TeamPageView`, `TeamPageCard`)

- Coming up becomes the **first** card on the Info tab, above mood and this-week.
- `TeamPageCard` gets a `footerLabel` parameter; the coming-up card passes
  "Pre game talk ›". Expanded layout, top to bottom: kickoff line with competition and
  venue; favourite chip; the deterministic preview; "Their ones to watch"; the talking
  point in zone 2 under the existing "Tonight:/This weekend:" label, which finally has
  something to label.
- Post-match still replaces it after the whistle, as today.

---

## 4. Agents

Three Opus agents, disjoint files, worktrees, reviewed and cherry-picked:
- **Pre-match backend**: A + the routine change. Files: `team-page-generator/index.ts`,
  `_shared/stakes-templates.ts`, `_shared/matchup-verdict.ts`, tests;
  `goaldigger-routines/TEAM_PAGE_PROMPT.md`, `post_team_page.sh`, `whitelist.sh`.
- **Freshness backend**: B. Files: `data-fetcher/index.ts`, `match-watcher/index.ts`,
  tests. Must not touch `team-page-generator`.
- **iOS**: C (client half) + D. Files: `TeamPageView.swift`, `TeamPageCard.swift`,
  `CalendarSyncService.swift`, `CalendarOptInView.swift`, `ContentItem.swift`
  (`UpcomingFixture.status`, `NextFixtureCard` unchanged).

The server-side of C (`buildUpcomingFixtures`) lives in `team-page-generator`, so it
belongs to the pre-match backend agent.

## 5. Verification

- Deno tests: `renderClubPreMatch` for a league game (both in table), a cup tie against a
  lower-league club (no rank), a European night; `preMatchVerdict` with league
  positions; the standings dedupe writes one row per club from one fetch; the FT trigger
  fires once per fixture and only for our clubs; `buildUpcomingFixtures` keeps PST, drops
  CANC, filters friendlies, caps at 15.
- Replay: `match-watcher?date=2026-09-08` should trigger refreshes for the six clubs that
  played; `team_pages.updated_at` moves for them and no one else.
- Screens via the harness: Info tab with Coming up first and "Pre game talk ›"; expanded
  pre game talk for a league game and for a cup tie; Calendar tab with a postponed row
  and 15 rows; onboarding calendar opt-in with current fixtures.
- Budget: API calls per day before and after the dedupe from `pipeline_health`.
