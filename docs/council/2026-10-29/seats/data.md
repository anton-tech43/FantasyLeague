# Data seat — app council 2026-10-29

Commit 376d3f2, app 2.4 (18). Yardstick: `DATA_SOURCES.md`. Live rows pulled 2026-10-29 ~15:00 UTC:
`team_pages.content` for arsenal, newcastle, spurs, liverpool, chelsea (all 74 card keys), 39 published
`content_items` from the last 14 days for those clubs plus the 7-day Everyone's-talking set,
`match_status_state` (13 fixtures), `raw_fetch_logs` (standings, fixtures, injuries, predictions),
`players`, `player_cards`, `teams`. Census ids are from `parts/TEAM.csv` and `parts/FEED.csv`; MD and MY
had no census part when this was written, so those rows use provisional ids (`MD-After-*`, `MY-Pre-*`).
Working files: `$S/data-seat/` (tp-*.json, ci.txt, run_matchup.ts).

The seat goal: she is never caught out in front of him. Most of the deterministic layer holds. The
failures are where a model wrote a fact, where a card is frozen for a week, and where a 1-1 decided on
penalties goes through code that only knows goals.

## Findings

**D1 HIGH — Two different men "won the 2026 Ballon d'Or", both in Everyone's talking.** FEED-05-02,
FEED-05-03, FEED-01-28. Live rows: arsenal 10-26 22:41 "Saka has won the 2026 Ballon d'Or" (source:
a Sky *Arsenal gossip* live blog); spurs 10-27 06:49 and 10-28 08:12 "Harry Kane wins the Ballon d'Or,
first English player since 2001" (source includes a Sky video slug `harry-kane-spurs-pay-tribute-to-ex-captain-2026-ballon-dor-win`).
All three have `everyone_talking = true`, so every user's Football feed shows both within 10 hours.
The two cannot both be true ("first Englishman since 2001" the morning after an Englishman won it).
CONFIRMED (contradiction on live rows); which one is false is SUSPECTED (Saka, on sourcing).
Fix: unpublish the Saka row; in `post_news.sh`, an award or trophy claim needs a `record` source, and
a cross-club check rejects a second winner for the same award within 7 days.

**D2 HIGH — A shootout is shown as a draw.** TEAM-03-14, MY "His club, right now" quiz
(`live-last-result`), MY-Pre "How they've been", Lingo after-tags. `recent_results` and
`recent_by_competition` carry goals only (`team-page-generator/index.ts:1401-1424`) and the app derives
the result from them (`ContentItem.swift:843-847`). Live today: Arsenal's Calendar › last games reads
"D · Fleetwood Town · 1-1"; the quiz answer is "Drew 1-1 with Fleetwood (away)" with the line "Was the
draw with Fleetwood fair?" (`LiveClubPack.swift:195-208, 784-794`). Arsenal went out 5-3 on penalties.
Chelsea (lost 6-5 pens) and Liverpool (won) both show "D". This is the 2026-10-27 failure that
match-watcher was fixed for, still alive on a second path. CONFIRMED (rows + code).
Fix: copy `teams.<side>.winner` and `score.penalty` from fixtures_last into each result; outcome =
winner flag; `resultLine` says "Lost 5-3 on penalties to Fleetwood".

**D3 HIGH — Tonight's Pre-game "last time" is a pre-season friendly.** MY-Pre "Get to know Everton"
lesson and quiz. `buildMatchupCard` (`_shared/matchup-card.ts:159-170`) keeps every h2h row with a score.
Run on the live Newcastle payload (deno, `run_matchup.ts`): `h2h[0]` = 2026-08-12 Newcastle 1-3 Everton,
league "Friendlies Clubs" (667). The lesson shows "1 - 3 last time" (`LingoView.swift:1395`), the quiz
asks "The last time Newcastle played Everton, how did it go?" → "They won 3-1 … at ours, in August
2026" and hands her "They beat us last time. Is this the revenge game?" The friendly also makes
`h2h-they-win` fire (3 Everton wins in 5 instead of 2). Arsenal–Liverpool's window holds a 2024-07-31
friendly too (no flip today). CONFIRMED. Fix: drop leagues 667/10 in `buildMatchupCard`, one test.

**D4 HIGH — "Ones to know" features injured men and contradicts its own dossier on the same slide.**
TEAM-01-49, TEAM-02-18, TEAM-02-07, MY-Pre opponent lesson. Saka is Arsenal's #1 and Liverpool's
"Their ones to watch" #1, one-liner "even while managing a thigh injury"; `/injuries` (trusted) has him
Missing Fixture 10-24, the 10-23 news says eight weeks out, and his dossier (`player_cards`, 10-27)
says "facing around two months on the sidelines". João Pedro, Chelsea #2 "the main scoring threat":
`/injuries` Missing Fixture for Saturday, dossier "out for a few weeks". Rice: "Four assists this season
without scoring himself"; dossier "He struck late to rescue a draw against Bayern"; `players.goals = 1`.
A Liverpool user's opener is built from that line: "B. Saka's got four goals this season. Is he the one
to worry about?" Also stale by a game: Isak "five league goals" (now 6), Barnes "three goals" (now 4) —
the card is written once a week (Sun 03:00). CONFIRMED. Fix: both pickers drop players on the latest
fixture's injury list (deduped per DATA_SOURCES); render the tally from `players` at view time, keep
the prose for the role only.

**D5 HIGH — Feed calls Eddie Howe "Newcastle manager".** FEED-01-28, FEED-05-02. newcastle 10-26 06:47,
`everyone_talking = true`, `source_urls []`. `teams.manager_name` = Matthias Jaissle (started 2026-08-05,
verified 2026-09-23). `post_team_page.sh` rejects a wrong manager; `post_news.sh` has no such check
(grep). CONFIRMED. Fix: repair rule in `post_news.sh` — "(<club> manager)" must equal
`teams.manager_name`, else "former <club> manager".

**D6 MEDIUM — "Saturday" for a Sunday game, pushed twice.** FEED-01-51, FEED-01-28, LOCK. Arsenal at
Liverpool is Sun 1 Nov 16:30 GMT (fixtures, trusted). Sunday Brief 10-25 (pushed: "Liverpool away next
Saturday"), news 10-27 06:44 (pushed), info card 10-27 22:43 all say Saturday. CONFIRMED against the
feed; a TV move after 10-25 cannot be ruled out (the fixture only enters `fixtures_next` on 10-26, already
Sunday). Fix: guard any weekday named beside the next opponent against `fixtures_next` in Europe/London.

**D7 MEDIUM — "After extra time" that did not happen.** FEED-06-22. Both Liverpool and Chelsea matchday
info cards (10-28 22:13) say 1-1 "after extra time". The League Cup goes straight to penalties before the
final (DATA_SOURCES); `finished_at` 22:13 fits 90' + pens; `match_status_state.elapsed = 120` on a PEN
row is the likely source. After card, post_match and FT push are right. CONFIRMED vs rule. Fix: pass
`extra_time` from `score.extratime`, never from elapsed.

**D8 MEDIUM — Spurs "12th, highest since January".** spurs 10-25 22:58. Every standings snapshot from
10-26 06:00 (all 8 played) has them 14th, and the form card says "14th in the Premier League". CONFIRMED.
Fix: repair a followed club's "<n>th" against standings.

**D9 MEDIUM — The matchup card is a stale snapshot and its favourite disagrees with the chip.**
(hidden card; drives Lingo tags and MY-Pre). Spurs' predictions were bought 10-25 10:00, before Palace
lost at home to Newcastle: `their_form` WLDWL (2 wins) vs the preview's "Crystal Palace with one win"
and Palace's own snapshot LDWLL. `favourite` comes from the feed's model (`them` for Arsenal, `us` for
Spurs) while TEAM-01-25 says "Could go either way" for both; the tag selects lines like "We were
supposed to be walking this. Typical." CONFIRMED rows, impact SUSPECTED. Fix: tag favourites/underdog
from `next_fixture.favorite`; refresh the snapshot when the opponent plays after it.

**D10 LOW.** (a) Spurs fun fact "The trophy cabinet is... a work in progress" — they won the Europa League
in May 2025 (TEAM-02-16). `basics` has no `*_verified_at`; I could not verify any `last_season` line
(ARS "Champions, 85 points" … TOT "17th, 41"). (b) House rules: em dashes in all five rivalry texts and
Arsenal's fun fact (TEAM-02-25, TEAM-02-16); en dashes in every `last_match` score and number ("1–0",
"26–3"), while `LiveClubPack` enforces hyphens; "Carabao Cup" alone in four headlines and "EFL Cup fourth
round" vs the page's "League Cup (Carabao Cup), last 16". (c) Truncated: Saka headline ends "…could keep
him out for"; a Spurs push_text ends "shirt when." (not pushed). (d) "His Nth goal" (`last-match.ts:290`)
assumes the stats feed is current at kickoff; Rogers still reads 4 on 10-29 after scoring 10-28, so a
one-day lag undercounts. SUSPECTED. (e) Oct 24 outage: fixtures 1557437 (ARS–EVE) and 1557439 (CHE–TOT)
were reaped to ABD; Arsenal users got the 1-0 goal push and nothing after; no After/article for either.
No club surface reads ABD, and the pages show the correct 2-0s (for the Connection seat).

**Missing value shown as 0:** none on a fact surface. Swift `?? 0` hits are sort keys
(`PlayerSlots`, `LiveSquadPack`); `live-match-current` defaults goals only for live statuses, where
null means 0-0 at kickoff.

## The same fact in more than one place (Move candidates)

| Fact | Where she sees it | Proposal |
|---|---|---|
| Last result + verdict | TEAM-01-17 post-match card (`post_match.text`), MD-After result card (`last_match.verdict`, byte-identical for LIV/CHE today), FT push, matchday article, TEAM-03-14, MY quiz, form summary | Keep After as the home; team page shows one line "After Chelsea ›"; 2.2/2.3 still need `post_match` |
| Goal scorers | MD-After "Goal scorers", FEED-06-18/19 article Goals, live card, goal pushes | Keep After + live; article links to After |
| Next fixture | TEAM-01-20..26 Coming up, TEAM-03 row 1, MD Before header, MD-After "Next:" line, TEAM-01-30 this_week (hidden), news/brief prose | Delete the After "Next:" line and this_week |
| League position / points gap | TEAM-01-57, Table, preview "2nd against 4th", TEAM-01-61 season, MY quiz, MY-Pre ranks, ONB-06 | Merge season into "How they're doing" |
| Last-five form | TEAM-01-58 dots (league), preview counts, matchup (hidden), TEAM-03-14 (all comps), MY-Pre How they've been (per comp) | One source: per-competition results with pens |
| Favourite | TEAM-01-25 chip, preview sentence, matchup.favourite (Lingo), FEED-06-15 preview verdict | One deterministic source |
| Key players | TEAM-01-47..49, TEAM-02-07 opponent side, MY-Pre lesson, MD OnesToWatch, FEED-06-34, ONB-06 first player, TEAM-02-18 dossier | One-liner from dossier + `players`, not a weekly prose card |
| Manager | TEAM-01-36..40, ONB-07, MY quiz, news labels | Keep; news must read `teams.manager_name` |

## Proposed verdicts (data-bearing elements)

| Element (ids) | Verdict | How / where / why |
|---|---|---|
| Coming up (TEAM-01-20..26, 02-01..05) | Keep | Every number reproduced: positions, gaps (6, 1, 2, 11), win counts (bar Palace via D9). The reason she opens the page |
| Favourite chip (TEAM-01-25, 02-03) | Iterate | Make it the only favourite source (D9) |
| Post-match card (TEAM-01-15..19, 02-10) | Move | To MD-After on 2.4+; one link line in its place. Producer stays for 2.2/2.3 |
| this_week (TEAM-01-28..30) | Delete | Never renders while `next_fixture` exists (`TeamPageView.swift:296`); text = preview's first two sentences. Check 2.2 before removing the producer |
| mood, freshness, rivalry meter (TEAM-01-27, 01-70, 02-26) | Delete | No producer writes them on any of the five pages |
| The basics (TEAM-01-31..34, 02-11..17) | Iterate | Add `basics_verified_at` to stale-data-audit; fix Spurs fun fact; strip em dash |
| The manager (TEAM-01-35..41) | Keep | All five match `teams.manager_name`; tenure prose matches `manager_started_on` |
| Ones to know (TEAM-01-42..51, 02-06/07, 02-18..24) | Iterate | D4: injury filter, live tally, one source with the dossier |
| Player card (TEAM-06-*) | Keep | Dossiers (10-27) were the most current text in the app |
| The rivalry (TEAM-01-52..55, 02-25..27) | Keep | Facts hold; remove em dashes and "If [his name] supports Arsenal" |
| How they're doing (TEAM-01-56..59, 02-28/29) | Keep | Position and dots match standings on all five |
| The season so far (TEAM-01-60..62, 02-30/31) | Move | Into "How they're doing"; restates position, points, W/L; frozen weekly |
| Calendar rows (TEAM-03-01..12) | Keep | Dates, venues, comps all match fixtures_next |
| Last games (TEAM-03-13/14) | Iterate | D2 |
| Table + Europe (TEAM-04-*) | Keep | Consistent with every card |
| matchup (no id; Lingo/MY-Pre) | Iterate | D3, D9 |
| MD-After result card, Say this now | Keep | Pens verdicts right for LIV/CHE |
| MD-After Goal scorers | Keep | Iterate en dashes, D10(d) |
| MD-After Three numbers | Iterate | `/fixtures/statistics` is still unverified (DATA_SOURCES): compare one matchweek, or drop |
| MD-After "Next:" line | Delete | Before tab is the next game |
| MY-Pre Get to know / How they've been | Iterate | D3, D4, D2 |
| News card (FEED-01-50, 05-02..10) | Iterate | D1, D5, D6, D8: five wrong facts in 14 days on five clubs |
| Sunday Brief (FEED-01-51) | Iterate | D6 |
| Matchday article (FEED-01-53, 06-18..24) | Keep | Iterate D7; Goals → link to After |
| Everyone's talking (FEED-05-*) | Iterate | Cross-club contradiction check (D1) |
| Live card (FEED-01-19) | Keep | Standings removed, period label fixed (`live-brief-current:178-191`) |
| Insider rows (TEAM-01-63..69) | — | Not checked by this seat |

## What holds up

- Managers: five of five match the human-verified column, and the prose dates agree with it.
- Standings, form dots and league-position labels agree on all five pages and with the raw table;
  Arsenal and Man City on 21, Spurs 14th, Palace 17th, Chelsea 5th.
- Deterministic previews: "2nd against 4th, six points", "8th against 11th, a point", the last-five
  win counts — all reproduced.
- The held-tie fix works: Liverpool v Chelsea's FT push (22:13, after PEN), `last_match` and `post_match`
  on both pages all say 6-5 on penalties, through/out the right way round.
- Shirt numbers on the featured players match `official_number`; every featured player is
  `in_official_squad`. Ones-to-know tallies matched `players` on the day they were written (bar Rice).
- `next_fixture` and `upcoming_fixtures` carry no friendlies; `europe_standings` is null for Chelsea and
  present for Arsenal/Liverpool, as it should be.
- The feed model's percentages and betting advice never reach a card (only the collapsed winner).
- No missing value renders as 0. The live box no longer shows the league table.

Usage data: none (0 rows in `analytics_events`), so every verdict above is provisional.
