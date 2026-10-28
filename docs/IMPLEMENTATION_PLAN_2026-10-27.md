# What's left, run in one go — 2026-10-27

Anton's answers (27 Oct) are written into each item. Order: smallest and most
visible first; the new push surface comes last before the bug hunt. **Every
step ends in a commit naming its paths** (no `git add -A`, no stash), a
simulator build, and, for backend changes, a deploy plus `verify-push-rules.sh`.

Already done and committed: A1–A5, B1, B2, B4, B6, the Matchday merge
(`e20f6ae`, pushes verified in the simulator).

---

## 1. B5 — scorers per side in the live card (app only)

`LiveMatchBrief.Scorer` already carries `side` ("home"/"away"), so the
backend does not change.
- `Design/Components/LiveMatchCard.swift`: replace the single scorer list
  with two columns under the score: home left-aligned, away right-aligned,
  each in minute order. A penalty gets "(pen)" and an own goal stays on the side
  that benefited, as the backend already sends it.
- No goals: no block (as today).
- Check: sim with the demo live brief, a 2–1 with a penalty and an own goal.

## 2. B7 — what is this competition? (app only)

The text comes from `glossary.json`, which already has Champions League,
Europa League, Conference League, FA Cup, League Cup and Premier League.

- **Feed (Anton: "the pink text above the news").** In
  `ImmersiveCard.swift` the pink `competitionLabel` (e.g. EUROPA LEAGUE)
  becomes its own button. A tap opens the same glossary sheet that
  `GlossaryText` uses. A tap on the rest of the card still opens the article,
  because the inner button takes the tap first.
- **Inside the article.** The badge at the top of `ContentDetailView` (`:142`,
  `cupBadgeLabel`) is tappable the same way. The headline and the
  "Good to know" cards are rendered with `GlossaryText` instead of `Text`,
  so "Europa League" in the text is underlined and tappable like the body
  already is (`:381`).
- **His Team, under each table.** One line under the table from the
  glossary entry for the tab shown (Premier League | Europa League |
  Champions League…), e.g. "Europe's second club competition… ›", which opens
  the same sheet.
- Missing glossary entries (if any tab has none): add them to `glossary.json`,
  written in the same voice as the existing ones.
- Check: sim, a Europa League post in the feed, tap the pink text, then the
  article, then the Palace table.

## 3. B8 — Europa League table and dates

The "still in Europe" check is already fixed (`EUROPE_TABLE_GRACE_DAYS = 60`,
`team-page-generator/index.ts:330`), and the European table is rebuilt in the
dynamic path (`:1137`). What remains:
- Calendar: the backend writes at most 15 `upcoming_fixtures` and the app shows
  `prefix(15)` (`TeamPageView.swift:671`). Raise both to 30 (≈ the rest of the
  autumn including European nights). No Claude call: the dynamic path builds
  the list from fixtures.
- Verify with SQL that Palace, Bournemouth, Sunderland, Villa and Forest have
  `europe_standings` and European dates in `upcoming_fixtures`; if a club is
  missing, find out why before changing anything.
- **Cost check:** fixtures refresh through the existing cron. No team loop
  through `team-page-generator` (CLAUDE.md hard rule). If old rows need
  rewriting, do it with SQL from `raw_fetch_logs`.

## 4. B3 — Gabriel and players in articles (Anton: only her clubs' players)

- **Migration 136:** `players.known_as text` plus `known_as_verified_at`.
  The source is the Premier League's own list, which `official-squads` already
  reads: `p.name.display` ("Gabriel", "Rodri", "Casemiro"). `official-squads`
  writes `known_as` when it pairs a player, and is run once by hand. That
  follows the DATA_SOURCES rule: a human-visible name comes from the
  official list, not from API-Football.
- **App:** `LiveSquadPack` selects `known_as` as well. A new matcher in the
  same file (no new file): for each squad player, try `known_as`, the full
  name, then the surname (≥ 4 letters), on word boundaries, ignoring case and
  diacritics, longest first, so "Gabriel Jesus" does not also count as
  "Gabriel". Searched: headline, Good to know, body.
- **ContentDetailView:** a "Who's who" row under the headline with up to
  four players named in the article (portrait + name). A tap opens the
  existing `PlayerCardModal`, using the same lookup as the team page.
- Existing matchers that key on surname (`PlayerPortrait.surname`,
  shirt number, dossier) try `known_as` first.
- Check: an assert-based self-check (same pattern as
  `TeamPageCard.swift:320`) with Gabriel / Gabriel Jesus / Ødegaard /
  "Saka's"; sim of a Saka article showing Saka in Who's who.

## 5. D — lineup talking point (Anton: flag stays off until he has looked)

Design per the approved plan (`~/.claude/plans/parsed-chasing-ladybug.md` §5),
in short:
- **Migration 137:** `fixture_lineups` (fixture_id, team_api_id, formation,
  xi jsonb, bench jsonb, fetched_at; PK fixture+team) plus `'lineup'` in
  `pipeline_health_stage_check`. RLS on, no anon grant, REVOKE on
  `PUBLIC, anon, authenticated`.
- **`_shared/lineup-notable.ts`** (pure, no model): a regular starter of
  substance is missing, an outsider starts in a substance role, or ≥ 5
  changes from the previous league XI. Full-backs and wing-backs are read
  from `grid`, and those players do not count. Thresholds are constants at
  the top. Deno tests for the four cases in the plan.
- **Fetch:** match-watcher gets its own gate, T−75 → T−30, with one
  `/fixtures/lineups` call per covered fixture every 5 min until a lineup
  exists. `poll_leagues()` is not widened.
- **Delivery behind `LINEUP_PUSH_ENABLED` (default off):** with the flag off,
  only the dry run runs. `pipeline_health` stage `lineup` logs the line that
  would have replaced the T−30 push body, plus the feed card. With the flag
  on, PREKICK_PUSH swaps its body and a `starting_xi` card goes to the feed.
  PUSH_RULES.md §1 gets the row now, marked "dry run", and
  `verify-push-rules.sh` is updated in the same change.
- After the first weekend: I give Anton the dry-run lines; he decides.
- Afterwards: `db-health.sh` and `get_io_attribution()`, because this adds a
  table and API calls.

## 6. Bug hunt (Anton: fix everything, deploy and migrate myself)

Same method as the red-team pass on 2026-09-09: **five parallel read-only
reviewers**, each with its own area and an evidence requirement
(file:line, concrete failure scenario, what the user sees). Speculation does
not count.
1. iOS state and navigation: AppState, GoalDiggerApp, AppDelegate, the
   Matchday merge, push routing, onboarding, Delete My Data.
2. iOS data and network: APIClient, the LivePacks, caches, Codable decoding
   against real rows, errors that are swallowed.
3. iOS views: Feed, Detail, Team, MyTurn, Live Activity widget, layout on
   small screens, empty and error states.
4. Edge Functions on the push path: match-watcher, notification-sender,
   matchday-reminder, morning-push, apns-client. Checked against
   PUSH_RULES.md.
5. Data and backend: team-page-generator, live-brief-current, cron/migrations,
   RLS/grants (`db-health.sh` §7), the routines repo's guards.

Then: I verify each finding myself before fixing (a reviewer's "certainly"
is not evidence) → fix → tests (Deno, `test_guards.sh`, xcodebuild) →
deploy/migration → sim check of what the user sees → one commit per fix.
Anything that touches a push goes through PUSH_RULES.md first. Any cross-team
fix is done with SQL, never with an API loop.

**Report at the end:** found / fixed / not fixed (and why), plus what needs
a new app build.

---

## Before I start: one permission

Read-only `psql` queries against the database were stopped by the auto-mode
classifier today (earlier in the session they went through). B8, B3 and the
bug hunt need them, and memory says migrations are mine to run. To keep the
run from stopping, add an allow rule in `.claude/settings.local.json`, e.g.
`"Bash(/opt/homebrew/opt/libpq/bin/psql:*)"`. Otherwise I continue with
everything else and save the SQL steps for the end.

---

## Where it stopped (2026-10-27, evening)

**Done and committed:** B5, B7, B8 (deployed), B3 (app), D dry run
(deployed), TRACKING_PLAN decision 1, bug hunt batches app 1, app 2 and
backend (deployed: match-watcher, notification-sender, morning-push,
matchday-reminder, team-page-generator, data-fetcher, live-match-current,
live-brief-current). Simulator-verified: Matchday pushes, B7 glossary,
Who's who.

**DB steps, done 2026-10-28** (via `./scripts/sql.sh`, allowed in
settings.local.json): migrations 136–139 applied and checked (anon has no
access); official-squads deployed and run, `known_as` filled for 574 players.
The Premier League list has no mononyms ("Gabriel Magalhães"), so 139 adds
`known_as_verified_at`: "Gabriel" is set by hand and official-squads never
overwrites a verified name. Other mononyms (Casemiro, Rodri, João Pedro …)
need the same hand-set row once someone checks the current squads. B8
verified: every club in Europe has its table, and Bournemouth's calendar runs
to the end of the league phase. db-health all clear.

**Bug hunt, 2026-10-28: the rest fixed** (commits adabe37…9706813): push-to-
start registration only on change, foreground sync once a minute, paging by
rows, sturdy Slice decode, no cache from a cancelled photo check, club tab
not refetched within 5 min, live poll every 10 min away from a match;
briefs_fired merged not overwritten (mig 140), LA start after the save,
morning-push claims first, throttle tie-break; API errors not stored (one
West Ham predictions row deleted), RSS on request, squad/coachs daily;
team pages written card by card (mig 141); routines: no friendlies; Data
Deleted alert, Settings gear outside `.id`, quiz "Played N", push tap closes
Settings.

**Found on the way, fixed:** API-Football called Fleetwood v Arsenal (League
Cup) "Match Finished" 1-1 with no shootout; the FT push and both cards said
"drew". match-watcher now holds a level FT in a single-leg tie; Arsenal's
cards corrected by hand; DATA_SOURCES.md has the case.

**Left (low, or not until next season):**
- Feed card zone 1 may clip at accessibility text sizes on an SE (plausible).
- Widget "/ 90" and timer width are fixed at the last push (plausible).
- Pre-match verdict uses May's table in July/August — needs a season check
  before August 2027.
- Other mononyms (Rodri, Casemiro, João Pedro …) need a hand-verified
  `known_as` like Gabriel's.

**Then:** a new app build carries everything under "App" above plus B3/B5/B7
and the Matchday merge; after it is out, switch the Live Activity sig to
15-minute buckets (match-watcher ponytail note). Lineup dry-run lines to
review after the first weekend: `pipeline_health` stage `starting_xi_fire`,
target `lineup:%`.
