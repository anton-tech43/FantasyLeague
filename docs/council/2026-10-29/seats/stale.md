# Stale-data seat — council 2026-10-29

Mode: `stale-data-audit` report-only. All ten sections run. Nothing fixed, no writes. SQL via `./scripts/sql.sh` (SELECT only); web for current facts. Census: no `census-*.csv` existed when this was written (only `parts/SET|ONB|FEED.csv`, with no TEAM/STO/MY chapters). Rows are therefore keyed by **source** (`table.key` or file:line). Editors: map them to TEAM / STO / MY ids when the census lands.

## Findings

### S1 — HIGH — The App Store description still sells the World Cup app. CONFIRMED
- **What she sees (before install):** "This summer's tournament is about to make a month of this", "a few short updates on his country", "Covers all 48 nations at this summer's World Championship", "Pick his country during setup", "kicks off June 11", "If your relationship has a third person in it called England", and **"No subscription, no ads, no tracking."**
- **Where:** the live listing, 2.3, released 2026-10-12. `curl "https://itunes.apple.com/lookup?id=6766301359&country=gb"` → `.description`.
- **Stale since:** the World Cup final, 19 July 2026. It became false a second time on 2026-09-23, when country following was switched off in code (`CountryFollowing.isEnabled = false`).
- **Correct fact:** see `goaldigger-marketing/account-1-goaldigger/web-brand/copy/product-facts.md`: 20 PL clubs, follow up to two, no countries. "No tracking" is false because the app ships Meta's SDK under ATT, so the line contradicts the privacy label. Source: Apple lookup (above) and product-facts.md, which already lists every one of these lines under "Do not use".
- **Owner:** Anton, in App Store Connect. The skill forbids agents editing the listing. **Gap in the skill:** §9 greps `docs/archive/*`, never the live listing. That is how this survived three audits.

### S2 — MEDIUM — "The season so far" goes stale every matchweek, and the stale part is the bit shown collapsed. CONFIRMED (structural)
- **What she sees:** "After eight games Aston Villa are ninth in the…". `TeamPageView.swift:436` truncates `season.summary` to 50 characters, so the game count and position are the whole collapsed card.
- **Where:** `team_pages.content.cards.season.summary`. All 20 rows were written 2026-10-26 03:04–03:09 UTC by `gd-team-page`, which runs Mondays only. The table matches today (all on 8 played).
- **Stale since:** tonight for Everton and Newcastle (they play at 19:45 on 29 Oct). From Saturday 31 Oct it is stale for all 20 clubs, until Monday 2 Nov 02:30. Every weekend she reads the card next to a live standings card that disagrees with it. A midweek round adds more days.
- **Correct fact:** the standings card on the same page (refreshed every 2 h).
- **Owner:** Anton decides, then code: (a) keep game counts and positions out of the prose and let the standings card carry numbers; or (b) rerun the routine after the last game of the round; or (c) hide the summary when `standings.played` ≠ the N in the prose.

### S3 — MEDIUM — The Brighton manager card says "second season". It is his third. CONFIRMED
- **What she sees:** "Fabian Hürzeler took over in the summer of 2024, so this is his second season at Brighton."
- **Where:** `team_pages[brighton].content.cards.manager.summary`, written by `gd-team-page` on 2026-10-26. The previous version, in `team_page_prose_history`, said "since June 2024" and was fine.
- **Correct fact:** appointed 15 June 2024 (`teams.manager_started_on`). 2024-25, 2025-26 and 2026-27 make this his third season. Source: https://en.wikipedia.org/wiki/Fabian_H%C3%BCrzeler.
- **Owner:** data (next Monday run will likely rewrite it) and code. `post_team_page.sh:51-63` checks only a **year** against `manager_started_on`. An ordinal ("second season", "third year") gets through, so add the ordinal to the same guard. The other 19 ordinals are right (Andrews 2nd, Jakirović 2nd, Le Bris 3rd).

### S4 — MEDIUM — Coventry's rival is wrong. SUSPECTED (fan-opinion sources, but unanimous)
- **What she sees:** "Coventry's fiercest rivalry is with Birmingham City, the Midlands derby…"
- **Where:** `team_pages[coventry].content.cards.rivalry`, `rival = "Birmingham City"`, hand-seeded 2026-09-06.
- **Correct fact:** the rivalry sources name Leicester City (the M69 derby), with Aston Villa as the traditional rival. None calls Birmingham the main one. https://en.wikipedia.org/wiki/M69_derby, https://footballgroundguide.com/news/coventry-city-biggest-rivals.html
- **Why it matters beyond the sentence:** the derby test in `LingoDeck.swift` compares `next_fixture.opponent` with `rivalry.rival`. Coventry v Aston Villa this season will not register as a derby. Birmingham and Leicester are both out of the division, so with the current rival it never fires at all.
- **Owner:** Anton picks Leicester or Villa, then a one-row data fix.

### S5 — MEDIUM — 75% of the insider routine's output goes to entities nobody can follow. CONFIRMED
- **What she sees:** nothing. This is cost and run time, not text on screen.
- **Where:** `goaldigger-routines/INSIDER_PROMPT.md:71` lists `teams?entity_type=in.(club,country)` with no `is_active` filter. In the last 7 days `team_insider_items` received 103 rows for the 20 active clubs, and 314 for inactive ones: 204 for 48 retired countries (Haiti, Belgium… on 29 Oct) and 110 for inactive clubs, among them Wolves, West Ham, Burnley, Leicester and Southampton (all written 29 Oct).
- **Stale since:** country following was retired on 2026-09-23. The relegated clubs date from the 2026-27 rollover.
- **Owner:** code (routines repo): add `&is_active=eq.true`. Check first whether European opponents' rows are read by the matchup card before excluding them. **Gap in the skill:** §7's relegated-content check queries `content_items` only.

### S6 — LOW — The Lingo transfer-window calendar is off by a day for January 2027. CONFIRMED
- **Where:** `ios/GoalDigger/Services/LingoDeck.swift:11-13`: summer `610…831`, winter `101…202`, "Last verified 2026-09-22".
- **Correct fact:** the January 2027 window runs 1 Jan to **1 Feb** 23:00 GMT. Summer 2026 ran 15 Jun to 1 Sep. https://www.premierleague.com/en/news/4664145/when-does-summer-2026-premier-league-transfer-window-open-and-close, https://www.liverpoolfc.com/news/premier-league-confirms-dates-2026-27-transfer-windows
- **What she sees:** on 2 Feb 2027, Lingo still deals "Window's open…" and deadline-day words.
- **Owner:** code plus a build, so it has lead time and needs to be in a build before late January. Summer 2027 is not yet published, so recheck then.

### S7 — LOW — A TikTok quiz answer is wrong for the League Cup. CONFIRMED
- **Where:** `goaldigger-marketing/account-1-goaldigger/render/src/tiktok/quiz.json`, slug `the-cup`: "A cup tie level after 90 minutes: → extra time, then penalties".
- **Correct fact:** League Cup ties before the final go straight to penalties. This is our own `DATA_SOURCES.md:45`, and Fleetwood v Arsenal on 2026-10-27 went that way. It is true only of the FA Cup. https://www.efl.com/competitions/carabao-cup/
- **Owner:** Anton/marketing. Reword to "in the FA Cup" and re-render. The other 59 answers check out.

### S8 — LOW — Product facts leave out the Champions League. CONFIRMED
- **Where:** `goaldigger-marketing/.../web-brand/copy/product-facts.md:31` says cups covered are "League Cup, FA Cup, Europa League, Conference League".
- **Correct fact:** `europe_standings.competition_label` puts Arsenal, City, United, Liverpool and Villa in the Champions League, Brighton in the Conference League, and Bournemouth, Palace and Sunderland in the Europa League. This page is the source every web claim is written from.
- **Owner:** Anton/marketing.

### S9 — LOW — Six "ones to know" picks are outside their club's top 12 by minutes. CONFIRMED
- Manzambi (Villa, rank 15), Awoniyi (Coventry, 14), Clarke (Ipswich, 14), Gallagher (Spurs, 14), Christie (Bournemouth, 13) and Sávio (Spurs, 13). The §4a query expects no rows. Every name is still at its club; the §4 departure check passed for all 60.
- **Owner:** data. Watch the next Monday run before suspecting a picker regression.

### S10 — LOW — `player_cards` keeps rows it should have dropped. CONFIRMED
- 12 rows name players in no current squad: relegated clubs' players (Kudus, Paquetá, Cunha, Ward-Prowse…), plus Xavi Simons under `spurs`, dated 2026-09-06. About 40 more rows are for players no longer on `ones_to_know`.
- She only reaches a dossier from `ones_to_know`, so this is mainly hygiene.
- **Owner:** data cleanup, per §5.

### S11 — LOW — Feed photos: 8 managers have none, and some players get a placeholder. SUSPECTED as a visible defect
- Brentford, Palace, Fulham, Hull, Ipswich, Liverpool, Man Utd and Sunderland have a NULL `teams.manager_photo_url`. The other 12 hashes are not in the placeholder table.
- A random 60 of the active clubs' player photos gave 4 copies of placeholder `430d67…` (~7%), matching what DATA_SOURCES recorded.
- The app bundles `bw-<club>-<surname>` portraits for all 20 managers and about 21 players per club, and every one still matches the current squad. Whether she ever sees a silhouette depends on which surface reads the feed URL.
- The 2.3 release notes promise "Faces for every Premier League player and manager". Verify on a screen before believing that.

## Surfaces holding hand-kept or rotting data that the skill does not cover yet

1. **The live App Store description and release notes.** Add `curl itunes.apple.com/lookup?id=6766301359` to §9 and read `.description` and `.releaseNotes` (S1).
2. **`team_insider_items` going to inactive entities.** Extend §7's inactive check to every routine-written table: `team_insider_items`, `team_season_state` (old rows for leicester, burnley, west_ham, wolves), `player_cards` (S5, S10).
3. **`teams.fan_name` / `fan_name_verified_at`** (migration 128). DATA_SOURCES documents it as human-verified, but no skill section re-verifies it. 6 of 20 are set.
4. **Ordinal tenure in prose.** §8 lists the year guard; add ordinals (S3).
5. **The bundled My Turn quiz** (`ios/GoalDigger/Resources/MyTurn/quiz.json`, 24 packs, ~230 dated or "by 2025" facts). §6 audits the generated live pack only. A read-through today found nothing false: dated phrasing such as "by the end of 2025-26" holds up. It still needs a dated human pass at each rollover, like `basics.fun_fact`.
6. **Competition-format rules in code** (`isSingleLegTie`; League Cup straight to penalties; FA Cup extra time "under consultation"). These change at the EFL/FA AGM each summer. Nothing re-checks them, and the TikTok quiz (S7) shows the cost.
7. **`team_news_sources`** (migration 102) has `verify_feeds.sh` but no line in the skill.
8. **`product-facts.md` / `approved-lines.md`**, the web copy's source of truth (S8).
9. **Example strings in prompts that rot.** `QUIZ_PROMPT.md:176` ("Arsenal won it last season, 2025-26") is false from July 2027. `PROMPT.md:436` (Southampton) and `LIVE_BRIEF_PROMPT.md:98` (Wolves) use clubs no longer in the division as illustrations.
10. **The skill itself is stale:** §10 greps for `WCSeason.hideAfter`, which no longer exists. Replace it with `CountryFollowing.isEnabled` and the `LingoCalendar` constants.

## What holds up

- **Clubs (§1):** 20 active rows are exactly the 2026-27 division, with West Ham, Burnley and Wolves inactive (https://en.wikipedia.org/wiki/2025%E2%80%9326_Premier_League). The iOS `Team` enum diff is empty. The only `api_football_id` collisions are the four known ones.
- **Managers (§2):** all 20 `teams.manager_name` match the PL's 2026-27 list and a second source (https://www.premierleague.com/en/news/4325264/list-of-202627-premier-league-club-managers, https://khelnow.com/football/premier-league-2026-27-all-managers-202608). No sacking found up to 29 Oct; Carrick, Sage and Le Bris are under pressure, so recheck weekly. `club_style` has no claim older than a manager's appointment, and the 10 new managers carry nothing.
- **Squads (§3):** 26–38 players per club, all with photos, synced 2026-10-29 (Villa 10-26, Coventry 10-21). Official-squad check ran today for every club. Zero HTML-escaped names. Every bundled portrait matches a current player or manager.
- **Team pages (§4):** all 20 `basics.last_season` match the 2025-26 final tables, PL and Championship (https://en.wikipedia.org/wiki/2025%E2%80%9326_EFL_Championship). All 20 fun facts were read; none is false, and the five fixed on 10-02 stay fixed. Calendar: the first fixture is in the future for all 20, 25 rows each. `next_fixture` agrees. The `ones_to_know` departure check is clean. Season-prose positions and points match today's table.
- **Season state (§6):** all 20 are `mid_season`, generated today.
- **Labels (§7):** no hardcoded 2025 season or last season's roster in any live code path. `non_pl` includes the relegated three. No `content_items` went to inactive clubs.
- **TikTok quiz (§9a):** 59 of 60 answers correct under current Laws (five subs, no away goals, 20 teams, 38 games).

## Summary
1. HIGH: the live App Store description is still the World Cup pitch ("48 nations", "pick his country", "June 11", "no tracking"). Anton must rewrite it in App Store Connect; the skill never checked the live listing.
2. MEDIUM: the collapsed "season so far" card says "After eight games… ninth" and rots every weekend until Monday's routine run. Anton decides between number-free prose, a post-round rerun, or hiding the card on mismatch.
3. MEDIUM: Brighton's manager card says "second season" (it is his third; the year-only guard misses ordinals). Coventry's rival is Birmingham when it is Leicester or Villa, which also breaks derby detection.
4. MEDIUM: 75% of insider items this week (314/417) went to retired countries and relegated clubs, because `INSIDER_PROMPT.md:71` has no `is_active` filter.
5. Holds up: clubs, all 20 managers, squads, last-season lines, fun facts, calendars and season state are current. Ten uncovered surfaces are listed for the skill.
