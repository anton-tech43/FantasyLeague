# Cup coverage plan — League Cup, FA Cup, Europa League, Conference League

**Status: SHIPPED 2026-09-08.** Phases 0-3 are live; see "What shipped" at the
bottom for what was built, what was deliberately not, and what is left. The plan
text below is kept as written so the reasoning survives the diff.

Supersedes `V2.1_DESIGN_FA_CUP.md`, whose stored `competitions` column was the
approach migration 087 deliberately rejected (who is in what changes every
August and every knockout night; derive it from fixtures).

**Goal, in the product's words:** she knows when it is cup time, which cup, how big the
night is, and how to follow his team through it — without knowing what "last 32" means.

---

## 1. What the Champions League gave us, and what it did not

Shipped 7 Sep (`cd68d8c`, `ffb6365`, migration 087, routines `gd-champions-league`):

| piece | where | reusable as-is? |
|---|---|---|
| Tournament entity row (`entity_type='tournament'`, `api_football_id` = league id) | `teams` | yes — one row per cup |
| League-level fetch (standings + next 20 + last 20) into `raw_fetch_logs` | `data-fetcher` tournament branch | yes, but skip `/standings` for knockout-only cups |
| `active_competition_ids()` — which leagues to poll, derived from `fixtures_next` | migration 087 | yes — widen the `IN (2)` list, add a date window |
| Map every known club, register unknown cup opponents as `is_active=false`, skip ties with none of ours | `match-watcher` | yes — already keyed on `COVERED_CUP_LEAGUES` |
| `fixtureImportance()` / `fixtureLabel()` for the Calendar tab | `_shared/league-helpers.ts` | needs cup rounds; today every domestic cup is a flat 2 |
| Tournament routine writing to the shared Football feed | `CHAMPIONS_LEAGUE_PROMPT.md` + `fetch_champions_league.sh` | parametrise, don't copy four times |
| `info_cards` level 3 with a `fixture` object (both crests) | PROMPT.md, iOS `InfoCardView` | yes |
| Lingo entries: the-cups, fa-cup, league-cup, europa-league, giant-killing, magic-of-the-cup | My Turn | yes; add conference-league, two legs, Wembley |

**What the CL work left open, and cups inherit:**

- `content_items` has no competition column. A matchday card cannot say "League Cup" in
  its badge; the feed renders "Sunderland 1-0 Hull" as if it were a league game.
- `next_fixture` on the team page has opponent/date/venue but no competition. "Coming up:
  Hull City, home" tonight, with nothing saying it is the League Cup.
- `gd-matchday`'s payload carries no league. The routine curls `standings?league=39` for
  every match and the prompt's competition section knows only PL and WC.
- `post_news.sh`'s non-PL results guard exempts a sentence only if it contains "cup". "Newcastle
  lost to Millwall" (tonight's tie) is rejected on first attempt; "Arsenal beat Napoli" passes
  only because Napoli is not on the list.
- Live pushes (`sendPlayingTeamPush`) never name the competition.
- iOS Live Activity `side()` resolves only `Team`/`Country` enums: a tie against Lincoln, or
  Napoli, has no name for the widget. **This affects Napoli v Arsenal tomorrow.**
- `matchday-reminder` and `matchday-scheduler` still read `teams.league_id`, not
  `active_competition_ids()`.
- `seasonForLeague()` returns the calendar year for unknown leagues: correct for a cup until
  31 Dec, wrong from January (the 2026-27 FA Cup is season 2026 in API-Football).
- TIERS §6.3 (tier-aware live pushes) is unimplemented, so every follower gets kickoff, goal,
  HT and FT for any polled match. Fine for the CL. Not fine for a League Cup second round.

## 2. Why now — the fixture list as of today

From `raw_fetch_logs` (`api_football_fixtures_next`, our 20 clubs):

| competition | league id | ours in it | when |
|---|---|---|---|
| League Cup, last 32 | 48 | 19 of 20 | **tonight 8 Sep → 17 Sep**. Sunderland v Hull tonight, Chelsea v Leeds tomorrow, Liverpool v Spurs 15 Sep, Man Utd v Brighton and Coventry v Villa 16 Sep — five all-PL ties |
| Champions League, league phase | 2 | 5 | 8 Sep → (covered) |
| Europa League, league phase | 3 | Bournemouth, Crystal Palace, Sunderland | 16 Sep → Jan; knockouts Feb–May, final late May |
| Conference League, league phase | 848 | Brighton | 15 Oct → Dec; knockouts Feb–May |
| FA Cup | 45 | all 20 from the third round | early Jan 2027 → final at Wembley, May |

Tonight, without any change: the Calendar tab says "League Cup" with two dots, and that is
the whole coverage. No morning push (no `match_status_state` row exists because league 48
is not polled), no kickoff/goal/FT push, no Live Activity, no post-match card, and the feed
is silent for both sets of followers of an all-PL tie.

## 3. Principles

1. **Extend the CL shape, do not fork it.** One competition registry drives polling, labels,
   importance, push copy and routine scheduling. Four cups must not mean four copies of
   anything.
2. **Competition is data on every surface.** `league_id` travels with the fixture from
   API-Football into `match_status_state` (already), `content_items` (new), the team page
   (new field), the push copy and the trigger payload. Nothing infers the cup from text.
3. **Derived, never stored, for "who is in what".** Migration 087's rule stands. A club
   going out on penalties stops its polling on the next fetch.
4. **A cup night is sized by round, not by name.** League Cup last 32 is a two-dot Tuesday;
   the League Cup final is Wembley and a five. The same function must say both.
5. **Budget before breadth.** API-Football Pro is 7 500 calls/day and `match-watcher` polls
   each active league every minute (1 440/day per league). Two leagues today; six is over
   the cap. Polling has to become "leagues with a fixture today", not "leagues someone is in".
6. **She should never meet a football word first.** Every new label on a surface ("last
   32", "aggregate", "second leg") has a Lingo entry and a glossary underline.

## 4. The competition registry (the one new abstraction)

`_shared/competitions.ts` (TypeScript constant, mirrored in a SQL table only if a routine
needs it — the routines already read `teams`):

```ts
export const COMPETITIONS = {
  39:  { slug: "premier_league",    name: "Premier League",    kind: "league",          standings: true,  tournamentFeed: false },
  2:   { slug: "champions_league",  name: "Champions League",  kind: "league_phase",    standings: true,  tournamentFeed: true  },
  3:   { slug: "europa_league",     name: "Europa League",     kind: "league_phase",    standings: true,  tournamentFeed: true  },
  848: { slug: "conference_league", name: "Conference League", kind: "league_phase",    standings: true,  tournamentFeed: true  },
  48:  { slug: "league_cup",        name: "League Cup",        kind: "knockout",        standings: false, tournamentFeed: true  },
  45:  { slug: "fa_cup",            name: "FA Cup",            kind: "knockout",        standings: false, tournamentFeed: true  },
  1:   { slug: "world_championship",name: "World Championship",kind: "tournament",      standings: true,  tournamentFeed: true  },
};
export const COVERED_CUP_LEAGUES = [2, 3, 848, 48, 45];
```

Per entry the code derives: the season rule (all club competitions use the July cutoff),
`fixtureImportance` by round, `fixtureLabel`, the FT push shape (one leg / aggregate /
penalties), which routine owns the tournament view, and the push tier floor (section 8).
House copy: "League Cup" not "Carabao Cup" (API-Football already says "League Cup"; the
Lingo entry explains the sponsor name). iOS gets a `Competition` enum with the same ids
for badges and labels; the id is the contract, never the string.

## 5. Workstreams

### A. Data and polling (backend, Edge Functions + one migration)

**A1 Season mapping.** `seasonForLeague`: 3, 848, 48, 45 join 39 and 2 in the July-cutoff
branch. Without it every cup fetch breaks on 1 January.

**A2 What to poll.** `active_competition_ids()` widens `IN (2)` to the covered list **and**
only returns a cup league when one of our clubs has a fixture in it dated within
[yesterday, today]. PL stays always-on (the hangover logic already handles a late kickoff).
Budget arithmetic: PL 1 440 + data-fetcher ≈ 1 300 + cups on their days (League Cup and
CL/EL/ECL nights rarely coincide; worst case Tue–Thu ≈ 3 extra leagues = 4 320) ≈ 7 000 on
the busiest day, under 7 500 but with no margin — so also **A2b:** match-watcher skips the
per-minute poll for a league whose fixtures for the day are all terminal or more than two
hours from kickoff. That halves PL's own cost and makes the cap comfortable. Measure from
`pipeline_health` before and after; if still tight, the cheap lever is polling every two
minutes outside a live window.

**A3 Tournament entities.** Migration 093: `teams` rows `europa_league` (3),
`conference_league` (848), `league_cup` (48), `fa_cup` (45), `entity_type='tournament'`,
`is_active=true`. `data-fetcher` tournament branch reads `standings` from the registry and
skips it for knockout cups (no table exists; today it would log an empty response every
two hours). `fixtures_next=20` is too few for a League Cup round (16 ties in a day) → `next=40`
for knockout cups, and add `fixtures?league=X&season=Y&date=today` on round days so the
routine sees the whole round, not the first 20.

**A4 Cup opponents and names.** match-watcher's registration of unknown opponents is
already generic. Add a `short_name` fix: today it truncates the API name to 14 chars
("Manchester Uni"); use the API's own short form where the payload has it, else the last
word. `liveMeta` resolves via `shortNameById` (all rows) so server-side Live Activity is
fine; the iOS gap is C4.

**A5 Extra time, penalties, two legs.** Cups finish AET and PEN (already in
`FINISHED_STATUSES`). The FT push and the deterministic result line need three shapes:
"won 2-1", "drew 1-1, won 4-3 on penalties", and for two-legged European knockouts "lost
1-0, through 3-2 on aggregate" — the aggregate needs the first leg from `fixtures_last`
(same tie = same two clubs, same round, 7–8 days apart). New deterministic consequence
types in `consequence-templates.ts`: `CUP_THROUGH`, `CUP_OUT`, `CUP_FINAL_REACHED`,
`CUP_WON`, each with a round-aware line ("Through to the FA Cup quarter-finals"), run
through `buildContentItem()` and unit-tested for the 35-char push-title cap — the exact
bug that silently killed every `UCL_CLINCHED` card.

**A6 Morning and pre-match.** `morning-push` reads `match_status_state`, so cup ties appear
there for free once polled (rows exist from the first tick after midnight UTC). `matchday-
reminder` and `matchday-scheduler` switch from `teams.league_id` to
`active_competition_ids()` so the 07:00 heads-up covers cup days. Copy gains the
competition: "Game day at Sunderland — League Cup, last 32, Hull at home, 19:45."

**A7 Live push copy names the competition.** `GoalPushCopy` builder takes the registry
entry and round: kickoff "League Cup: Sunderland v Hull, kicked off", FT "Sunderland 2-0
Hull. Through to the last 16." A two-dot tie should read like one; the FT is still the most
read text the app sends.

### B. Content (routines repo)

**B1 gd-matchday knows the competition.** Trigger payload gains `league_id`, `competition`,
`round`, and for two-legged ties `aggregate`. `MATCHDAY_PROMPT.md` competition section
grows from {PL, WC} to the registry: for a cup, the story is the round and who is next,
not the table; League Cup early rounds get the "rested half the team" framing only when
the lineup data supports it; Europa Thursday gets the Sunday-fatigue angle. The
`standings?league=39` curl stays as league context; EL/ECL league-phase tables come from
`raw_fetch_logs` (tournament entity), never live. `post_news.sh`: the non-PL results guard
is bypassed when the payload's `league_id` is a covered cup, and `content_items.league_id`
is written (C1). The matchday article stays feed-only for clubs (match-watcher pushed FT).

**B2 One tournament routine, parametrised.** `fetch_champions_league.sh` →
`fetch_competition.sh <slug>` producing the same JSON shape (`our_clubs_in_it`, table where
one exists, results since yesterday, next seven days, rounds ahead). `CHAMPIONS_LEAGUE_
PROMPT.md` → `COMPETITION_PROMPT.md` with a per-competition block: which clubs count as
heavyweights (EL: Roma, Porto, Lyon, Milan, Sevilla, Ajax… ; ECL: judge by our club only),
what "big" means (a Premier League club losing to a League Two side is a card; a League
Cup last-32 win over a Championship side is not), and the significance floor. Schedules:
`gd-europe` Tue–Fri 07:00 Stockholm covering CL/EL/ECL (Thursday nights land Friday);
`gd-domestic-cups` fires the morning after a round and the morning after a draw. Routine
fires are a separate quota (Lesson 63) — one combined European run costs the same as
today's CL run.

**B3 "It's cup time" cards — the awareness layer.** Three deterministic-when-possible card
shapes, owned by the tournament routine, all into the Football feed with `info_cards` and a
`fixture` object, and mirrored as one club-feed card for a followed club's own tie:

- *Round-start*, the day before: "League Cup week. 19 of the 20 play, five of them against
  each other." Level 3 to impress: the one tie worth watching.
- *Draw*: "Arsenal drawn at Ipswich in the last 32." Draws are the moment he checks his
  phone; the routine reads the new `fixtures_next` the morning after the draw.
- *Stage change*: league phase over, who is through, when the knockouts start.

**B4 The prompts that pretend cups do not exist.** `SEASON_STATE_PROMPT.md` says "league=39
only, don't mention cups" → feed it the club's cup fixtures from the same raw log and let
it say "League Cup last 16 on Wednesday". `TEAM_PAGE_PROMPT.md` season card names the cup
run when there is one ("still in three competitions"). `SUNDAY_BRIEF_PROMPT.md` already
handles rounds correctly; `fetch_news.sh` `next=3` is enough.

**B5 My Turn.** Lingo: add conference-league, two-legs/aggregate cross-links, Wembley,
third-round, replay (abolished from 2024-25 — a dated fact, so it can be stated), giant-
killing already there. Say This: a *Cup night* situation ("It's only the League Cup",
"Cup run!", "Anyone from the lower leagues left in?"). Live quiz pack: "Which cup are
they in this week?" built from `upcoming_fixtures`. All through the validator.

### C. App (iOS — one build)

**C1 Competition on the card.** `content_items.league_id integer null` (migration 093).
Feed card and detail header get a badge from the registry: "LEAGUE CUP · FULL TIME",
"EUROPA LEAGUE · PREVIEW". Routines and match-watcher write it; old rows render as today.

**C2 Coming up says which competition.** `next_fixture` gains `competition` and `round`
(team-page-generator writes them from the fixture's league). iOS `NextFixtureCard` shows
"League Cup, last 32" under the opponent. `upcoming_fixtures` already carry a label; the
Calendar tab only needs C3's importance.

**C3 Importance by round, for all five.** `fixtureImportance()`:

| | final | semi | quarter | last 16 | earlier / league phase |
|---|---|---|---|---|---|
| Champions League | 5 | 5 | 5 | 4 | 4 |
| Europa League | 5 | 4 | 4 | 3 | 3 |
| Conference League | 4 | 3 | 3 | 2 | 2 |
| FA Cup | 5 (Wembley) | 5 (Wembley) | 4 | 3 | 3 if the opponent is a PL club, else 2 |
| League Cup | 5 | 4 | 3 | 2 | 2 |

`fixtureLabel()` adds "second leg" and "first leg" for two-legged rounds, and "at Wembley"
for FA Cup semis and both finals. Both functions get a Deno test table.

**C4 Live Activity for a cup opponent.** `side()` falls back to the names carried in the
push attributes (the backend already sends full attributes), so "Sunderland v Hull" and
"Napoli v Arsenal" render. Check tomorrow's CL tie first; it is the same bug.

**C5 Table tab: a Europe table.** `team_pages.cards.europe_standings` (36-row league-phase
table for a club in CL/EL/ECL, from the tournament entity's standings) and a Premier League
/ Europe toggle above the table. Nil for clubs not in Europe; the toggle hides.

**C6 Glossary.** `glossary.json` has Champions League, Europa League, FA Cup. Add League
Cup, Conference League, aggregate, second leg, penalties (shoot-out), Wembley. These are the
words the new labels will introduce, so they must underline from day one.

**C7 Calendar sync.** EventKit titles gain the competition: "Sunderland vs Hull City (H) ·
League Cup". The alarm lead time stays.

### D. Push volume (needs Anton — see §8)

TIERS §6.3 has the design (kickoff ≥ 2, goal ≥ 3, HT ≥ 2, FT ≥ 1 on tier) and no code. Cups
make it urgent: without it, a Light follower gets four pushes for a League Cup second-round
tie against Lincoln. Proposal: the registry carries a per-competition-per-round *floor* that
is added to the tier threshold, so early League Cup rounds are FT-only for everyone,
knockout rounds behave like the PL, finals are ungated.

## 6. Sequencing

**Phase 0 — before 18:45 UTC tonight if wanted (30–45 min, backend only).**
Add 48, 3, 848, 45 to `COVERED_CUP_LEAGUES` and the migration's `IN` list; A1 season
mapping; deploy match-watcher. Result tonight: kickoff/goal/HT/FT pushes, Live Activity
(server side), gd-matchday fires for Sunderland v Hull, Bournemouth v Lincoln, Palace v
Middlesbrough, Millwall v Newcastle; `match_status_state` rows exist so tomorrow's morning
push covers Chelsea v Leeds. Known rough edges accepted for one round: pushes do not name
the competition, the matchday article may need the guard's second attempt, the widget shows
no name for Lincoln/Millwall, and everyone gets every push. Budget tonight: 4 leagues
polled ≈ 5 760 + fetcher ≈ 7 000 — inside the cap for one evening, not for a week, which is
why A2's date window ships in Phase 1 at the latest. **Decision: ship Phase 0 or wait?**

**Phase 1 — this week (Europa League starts 16 Sep).** Registry (§4), A2 + A2b polling
budget, A3 tournament entities + data-fetcher, A6 reminder/scheduler, A7 push copy,
migration 093 (`content_items.league_id` + entities), B1 matchday payload + prompt + guard
bypass, C3 importance/labels (server-side; the Calendar tab picks them up on refresh).

**Phase 2 — the next iOS build.** C1 badge, C2 Coming up competition, C4 Live Activity
names, C5 Europe table, C6 glossary, C7 calendar titles. Screenshot via the launch-arg
harness (`-gdTeamTab calendar`, `-gdTeamExpand comingUp`, `-gdOpenItem`).

**Phase 3 — before the League Cup last 16 (late Oct) and the FA Cup third round (Jan).**
B2 parametrised tournament routine and schedules, B3 round-start/draw/stage cards, A5 cup
consequence templates and aggregate handling, B4 prompt updates, B5 My Turn cup content,
D tier floors once §8 is decided.

## 7. Verification

- **Replay, not hope.** match-watcher with `?date=2026-09-08` against league 48: expect
  Sunderland v Hull and the four other ties tracked, Lincoln/Middlesbrough/Millwall
  registered `is_active=false`, ties with none of ours skipped. Same for league 3 on 16 Sep.
- **Deno tests**: `seasonForLeague` for all six ids on 1 Aug, 31 Dec, 1 Feb;
  `fixtureImportance`/`fixtureLabel` table above; every cup consequence template under
  the 35/90 caps for the longest club names ("Wolverhampton Wanderers", "Brighton & Hove
  Albion") and the AET/PEN/aggregate shapes; `active_competition_ids()` returns a cup only
  inside its date window.
- **Budget**: count API calls per day from `pipeline_health` before Phase 1 and after; the
  busiest day must stay under 6 000 to leave room for a busy WC-style night.
- **Guards both ways**: "Newcastle lost to Millwall" with `league_id=48` passes; the same
  sentence with `league_id=39` is still rejected.
- **Screens**: Calendar tab with a League Cup tie, a CL night and a PL Saturday on one
  screen; Coming up with competition; a feed card with the badge; Europe table toggle.
- **Live**: one full cup night end-to-end (kickoff → FT → article) on 15 Sep, Liverpool v
  Spurs, where both sets of followers exist.

## 8. Decisions for Anton

1. **Phase 0 tonight, or wait for Phase 1?** Tonight gives four ties real coverage with
   the rough edges listed; waiting means the League Cup last 32 passes uncovered for 19 clubs.
2. **Push floors per round** (§5 D). Proposal: League Cup rounds before the quarter-finals
   and FA Cup rounds before the fifth round are FT-only for every tier; quarter-finals
   onwards behave like the Premier League; semis and finals ungated.
3. **Conference League depth.** Only Brighton. Club-night coverage (pushes, article,
   calendar) comes free from the registry; the tournament-view routine costs a daily run
   for one club's competition. Proposal: club-night only until a PL club reaches a
   quarter-final.
4. **Giant-killings in the Football feed.** A non-league side beating a PL club is the
   FA Cup story he will tell; a card about it belongs in the shared feed even when it is
   not his club. Proposal: yes, from the third round, significance 2.
5. **House name**: "League Cup" (API, plain) vs "Carabao Cup" (what he says). Proposal:
   "League Cup" on every surface; the Lingo entry carries the sponsor name.
6. **Retire `V2.1_DESIGN_FA_CUP.md`** — delete or keep with a superseded header.

## 9. Cost

- API-Football: neutral to negative after A2b (PL stops polling on non-match days).
- Claude API credit: zero. Every LLM call here is a claude.ai routine (subscription), per
  CLAUDE.md's hard rule; the deterministic templates cost nothing.
- Routine quota: one combined `gd-europe` run replaces `gd-champions-league`;
  `gd-domestic-cups` adds roughly ten runs a season. gd-matchday fires grow by the number
  of cup ties our clubs play — 19 tonight and tomorrow, which is a normal PL weekend.


---

# What shipped, 2026-09-08

Anton's decisions on the plan: build everything now; push floors per round as
proposed; Conference League gets club-night coverage only; giant-killings reach
the Football feed when the match is big; house copy is "League Cup (Carabao
Cup)" in prose and "LEAGUE CUP" in a badge.

## Live

**Polling** — `poll_leagues()` (migration 094) replaced "which competitions is
somebody in" with "what is kicking off or still being played". Six always-on
leagues would have been 8,640 API calls a day against a 7,500 cap; the busiest
realistic day is now about 1,000 and a quiet morning is zero, because the
Premier League stopped polling on days it has no game. It also owns the poll
date, which subsumed match-watcher's hangover query. Migration 093 was the
30-minute version that covered the same evening while 094 was written.

**Competition as data** — `content_items.league_id` (both Edge insert paths plus
the routines), the gd-matchday trigger payload, `next_fixture`, the three live
push bodies, the 07:00 reminder, the morning push, the Live Activity strap.

**Live Activity** — `live-match-current` returns team names, so the app's local
fallback no longer abandons an activity for a club outside its compiled enums.
That had silently killed the widget for every cup tie.

**Tier floors** — TIERS.md §6.3, implemented: kickoff 2, goal 3, half-time 2,
result 1, with early League Cup and FA Cup rounds cut to the result for every
tier and semi-finals and finals open to all.

**Surfaces** — calendar dots and labels by competition and round; the Table tab
gained a Premier League / Europe switcher fed by `europe_standings` (nine clubs
have one today); the feed and detail badge a cup card by competition; calendar
sync titles carry it; seven glossary terms.

**Content** — `fetch_competition.sh <slug>` and `COMPETITION_PROMPT.md` replace
the Champions-League-only pair, with the round-start, draw and stage-change
cards and the giant-killing rule. `gd-champions-league` became `gd-europe`
(Tue-Fri); `gd-domestic-cups` is new. `SEASON_STATE_PROMPT.md` and
`TEAM_PAGE_PROMPT.md` stopped pretending cups do not exist. My Turn gained four
Lingo terms, a "cup night" Say This situation and six quiz questions.

**Tests** — 23 Deno cases on rounds, seasons across the January boundary, the
importance table, the poll plan, push clauses and tiers; `test_guards.sh` at 75.

## Deliberately not built

- **Cup consequence templates** (`CUP_THROUGH`, `CUP_OUT`, …). The deterministic
  post-match block is World-Championship-only, so nothing would have fired them,
  and a card there would duplicate the gd-matchday article. The cup outcome is
  delivered by the full-time push body and the matchday card instead.
- **Aggregate in the trigger payload.** No two-legged tie exists until the
  European knockouts in February. `MATCHDAY_PROMPT.md` tells the routine to add
  the first leg up from `match_form.json` instead of promising a field that is
  not there.

## Review, 2026-09-09 (adversarial pass)

Found the morning after the first League Cup night, fixed the same day:

- **"Out of the Champions League" after a first leg.** The FT push decided a tie was
  settled when the round string did not contain "leg". API-Football's round strings never
  do ("Play-offs", "Semi-finals", checked over three days of raw logs), so a first-leg
  defeat would have read as elimination. `isSingleLegTie` is an allowlist of rounds known
  to be one match: every FA Cup round; every League Cup round except the semi-finals; the
  European finals. Anything else names the competition and claims nothing.
- **Round of 128 parsed to stage 0**, so the League Cup first round was pushed like a
  league phase, the loudest tier of the season for the smallest tie. Mapped to stage 64,
  label "first round", "Through to the second round". An unparsed domestic-cup round is
  now treated as early, not as a league phase.
- **FA Cup rounds by number.** "5th Round" is the last 16; it parsed as a generic numbered
  round and was gated as early while "Round of 16" was not. `parseRound` takes the league
  id and maps 3rd/4th/5th to last 64/32/16. `knockoutOutcome` says "the fourth round", not
  "the last 32", for the FA Cup.
- **`poll_leagues()` read the Champions League tournament row's fixture feed** (league_id 2
  on that row defeated the `IS NOT NULL` exclusion), so it polled at 16:30 for Barcelona v
  Feyenoord. Migration 098 excludes tournaments by `entity_type` and drops the dead
  `active_competition_ids()`. A rolled-back SQL check lives in
  `backend/supabase/tests/poll_leagues_check.sql`.
- **The RPC fallback** now excludes the tournament row's league and writes a
  `pipeline_health` failure row instead of a `console.warn`.
- **Replay season.** `?date=2026-01-10` fetched season 2026; `seasonForLeague` takes the
  date being polled.
- **Live Activity strap** says the competition only, on both the push-to-start path and
  `live-match-current`, which has no round column; the two used to differ for one match.
- **Cup opponents' short names** were cut at 14 characters ("Atletico Madri"); the whole
  name is kept up to 20, and the three existing rows were repaired.
- **`opponentIsTopFlight`** was tested and never passed; `buildUpcomingFixtures` now passes
  it from the league table on the page, so an FA Cup third-round tie against a Premier
  League club gets its third dot.
- **A failed `device_tokens` query** inside a live push is now a `pipeline_health` failure
  row rather than a silent zero.
- **Tests:** 214 Deno cases, 77 guard cases, `poll_leagues_check.sql`.

Not changed: goal pushes to everyone on every round (Anton's decision); a 5-3 tie is eight
goal pushes and a full-time push. No per-match cap exists and nothing measures the volume.

## Still open

- The season-state source for calendar sync carries no competition, so an event
  title gets one only when the team page is the source. Worth fixing when
  `team_season_state.next_fixtures` next changes shape.
- A cup card's feed badge has not been seen on a real row yet: the first cup
  `content_items` land after tonight's full-time whistles.
- `significance` is still not read by `notification-sender`'s tier gate
  (TIERS.md §6.2) — unchanged by this work, still Anton's call.
