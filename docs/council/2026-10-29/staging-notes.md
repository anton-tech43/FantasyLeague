# Staging notes — app council 2026-10-29

Build 2.4 (18), commit 376d3f2. Built into `$S/dd`. Simulator GD-council-stage (iPhone 17 Pro, iOS 26.4),
TZ=Europe/London via `SIMCTL_CHILD_TZ`, status bar 9:41. Defaults were empty before every trusted run.
UK time check: the club tab shows "Sun 1 Nov at 16:30" for Arsenal at Liverpool. The row is
`2026-11-01T16:30:00+00:00`, which is 16:30 GMT/London.
183 screenshots are listed in `screens/INDEX.txt`. Every screenshot has its OCR text in `ocr/<same path>.txt`,
which is not a census. It is only what was visible above the fold.

## Persona screens (`screens/<persona>/`)

| dir | club | tier | article used (-gdOpenItem) |
|---|---|---|---|
| L1 | newcastle | 1 | 7b389ade… "Newcastle face Everton in the Carabao Cup…" |
| L2 | arsenal | 1 | c849eb0a… "Arteta under fire…" |
| M1 | spurs | 2 | 8d3172c7… "Former Spurs captain Harry Kane has won the 2026 Ballon d'Or…" |
| M2 | liverpool | 2 | bc0fb1ad… "Liverpool drew Bournemouth in the League Cup quarter-finals…" |
| D1 | arsenal | 3 | 603479cd… "League Two Fleetwood Town knocked Arsenal out…" |
| D2 | chelsea | 3 | 21b2f16f… "Chelsea manager Alonso said Estevao 'could be happier'…" |

Each persona folder has the same shots:
- `01` feed first screen
- `02-05` feed cards 0-3. Card 0 is the first screen, so it is identical by design.
- `06` article detail
- `08` article scrolled to "Things to say" (`-gdOpenItemTalk`)
- `10-12` club Info / Calendar / Table
- `13-16` club cards expanded: basics, manager, rivalry, coming up
- `19` ones-to-know strip open. This is the closest thing to a player card that can be reached.
- `21` Matchday Before, `22` Matchday After where one exists
- `23` My Turn landing, which is identical to `24` Quiz by design
- `25` Lingo, `26` Say This

All screenshots were OCR-checked: the right club is named on each, and no system dialog covers them.

Extra folders:
- `two-clubs/`: arsenal + liverpool.
- `club-plus-country/`: arsenal + england.
- `country-only/`: england, no club. This device lands on the "Football" (Everyone's talking) feed with two tabs.
  It is the only route to that feed from launch arguments.
- `states/`: clock-pinned and real match-day shots (see the matrix).
- `first-matchweek/`, `first-worstweek/`: see `first-session.txt`.

## State matrix

| State | Captured? | Where / how | Notes |
|---|---|---|---|
| No match this week | NOT SEEN | — | Every PL club plays between 29 Oct and 1 Nov. The furthest next match is 3 days away (Arsenal/Liverpool, Sun 16:30). |
| Day before a match | PARTLY | `states/arsenal-day-before-clock-2026-10-31T17:00:00Z-*` (Matchday, Quiz, Lingo) | `-gdNow` moves only Matchday and My Turn. The feed and club page show today's server rows. Above the fold, the result is identical to today's screens, 3 days out. |
| Match day, before kickoff | YES, real | Newcastle (19:45 tonight, League Cup at Everton): all of `L1/`, `states/newcastle-match-day-real-*`, `first-matchweek/` | Also clock-pinned for Arsenal (`states/arsenal-match-day-before-kickoff-clock-2026-11-01T12:00:00Z-*`), with the same result as the day before. |
| Live | NOT SEEN | — | No live match during staging. Newcastle v Everton kicks off at 19:45 London, after this run. `-gdDemoLiveActivity` is a hard-coded Arsenal 2-1 Leeds mock, so it was not used (skill rule). No harness renders a stored `live_match_briefs` payload. |
| After full time | YES, real | Liverpool and Chelsea (League Cup, Wed night, 1-1, Liverpool won 6-5 on pens): `M2/22`, `D2/22`, `first-worstweek/14` | Matchday opens on After by itself within 24 h. Arsenal's After (Fleetwood, 27 Oct) is past 24 h, so it was captured with `-gdNow 2026-10-28T00:00:00Z` in `L2/22-*clock*` and `D1/22-*clock*` (real stored card, clock pinned). |
| International break | NOT SEEN | — | The next break comes after 7-8 Nov. It cannot be faked: the feed is live server rows. |
| Cup tie | YES | Newcastle today (before), Liverpool/Chelsea/Arsenal League Cup (after) | See the rows above. |
| Day 1 | YES | `first-matchweek/`, `first-worstweek/` (erased simulator) | |
| Week 6 | NOT SEEN | — | No harness argument seeds history: My Turn progress, saved lines, read state. `-gdResetMyTurn` only clears. |
| One club | YES | all persona folders | |
| Two clubs | YES, closed | `two-clubs/` | The switcher is a menu and needs a tap, so the open switcher was NOT SEEN. With the switcher closed, the screen is indistinguishable from one club (first screen is Arsenal; Liverpool is only in the menu). |
| Club + country | YES | `club-plus-country/` | Identical to club only, because `CountryFollowing.isEnabled = false`. The country is invisible. |
| Country only | YES | `country-only/` | Opens the "Football" feed (Everyone's talking): Feed + My Turn, no Matchday or club tab. |
| Tier 1 / 2 / 3 | YES | L = 1, M = 2, D = 3; Newcastle real match-day feed at T3 in `states/` | Arsenal T1 vs T3 pixel diff: 18 of 21 identical. The only tier difference seen is "Things he doesn't know" (T2+) under the rivalry card (`D1/15`). Saturday quiz (T3) NOT SEEN: the server only serves it in the weekend window. Live card (T2+) NOT SEEN: no live match. |

### Screens not reachable from launch arguments (not seen)

- **Settings.** It is a sheet behind the gear and has no argument, so no section was seen.
- **Open club switcher.**
- **Player card / dossier** (`PlayerCardModal`, `Views/Player/`). The ones-to-know strip open (`19`) is the nearest.
- **"To impress" card.** `-gdShowImpress` opens it inline but below the fold.
- **Season and form cards on the club page.** `-gdTeamExpand season` and `-gdTeamScrollTo form` do not scroll:
  only comingUp, manager, onesToKnow and rivalry have `.id()` anchors (TeamPageView.swift:284/352/377/405).
- **Calendar and Table below the first 11 rows.**
- **Notification second-chance sheet.**
- **The three iOS permission dialogs** (notifications, calendar, Live Activities).
- **Lock screen and Live Activity.**
- **Saturday quiz card.**
- **The `-gdMatchdaySection before|after` argument does not work.** It is set in `.onAppear`, then
  `.onChange(of: lastMatch?.fixtureId) { picked = nil }` (MatchdayView.swift:61) resets it when the page loads. So
  `M2/21-matchday-opens-after-despite-before-arg.png` and its D2 twin show After. The Before for those two clubs
  was captured with `-gdNow 2026-10-30T12:00:00Z` instead.

## Harness traps hit this run (for whoever stages next)

1. **The ATT system sheet is sticky.** One launch without `-gdPresetTeam`/`-gdSkipATT` (`-gdPresetCountry` on its
   own) raised the ATT sheet. From then on the sheet survived relaunch, `simctl shutdown/boot` and
   uninstall/reinstall. While it was up, later launches screenshotted the previous club, even though `ps` showed
   the right arguments. Only `simctl erase` cleared it. The sheet also came back mid-batch after a plain reboot, and
   the cause was not found. The fix used here: OCR every screenshot (`tools/ocr`, Vision) and erase/retry on
   "to track your" or a missing club name (`run.sh`).
2. **Preset values persist.** After a `-gdPresetTeam` launch, the container plist holds that club
   (`selectedTeams = (arsenal, liverpool)` was read back after a two-club launch), so the Observable `didSet` does
   fire for the preset. A later `-gdPresetCountry` launch WITHOUT a team then shows the previous club, not the
   country-only state. Country-only must run on an erased simulator, as `country-only/` was.
3. **Do not run `simctl terminate` before launch.** An explicit terminate + 1 s before `launch
   --terminate-running-process` coincided with every stale-club batch. Without it, about 130 launches were clean.
4. **Fresh-simulator system UI.** The keyboard swipe-typing tip covers the her-name step, and a "Ready for Apple
   Intelligence" banner appeared once (that shot was retaken). Neither is app UI.

## Things that looked broken (observations, not a review)

- **Coming-up card truncates on a cup tie.** "Thu 29 Oct at 1…" and "League Cu…": the kickoff time is cut off
  when the competition chip shows (`L1/10`, `first-matchweek/15`; Newcastle). The expanded card shows "19:45" (`L1/16`).
- **Time words go stale.**
  - Newcastle's top card on match day says "cup game tomorrow / league on monday", and its article says
    "tomorrow night".
  - Arsenal card 2 still reads "cup football tonight. fleetwood v arsenal" two days after the match.
  - Liverpool card 1 and Chelsea card 1 carry a yellow "Tonight:" label on last night's game.
  - Liverpool card 3 reads "wirtz fitness update. chelsea tomorrow. anfield, 8pm" after that match was played.
  - Newcastle card 3 says "Palace away on Saturday is a must-win", while card 2 already reports the 2-0 win at Palace.
- **Two different 2026 Ballon d'Or winners.** The Arsenal feed and article f1d92386 (26 Oct) say Saka won. The Spurs
  feed (3 of its first 4 cards) and the Everyone's talking feed say Harry Kane won (27-28 Oct). One of them is false.
- **Newcastle manager.** The club page and onboarding say Matthias Jaissle, "appointed in August 2026". Feed item
  5ae465bd (26 Oct) calls "Eddie Howe (Newcastle manager)" a front-runner for United, and card 1 in `L1/03` is that story.
- **Arsenal article 603479cd** says "the match finishing 1-1 at Highbury". The game was away at Fleetwood, and Arsenal
  left Highbury in 2006. It also says "Liverpool away on Saturday", but the fixture is Sunday 1 Nov 16:30.
- **Spurs feed is repetitive.** Cards 0, 1 and 2 are all the Kane Ballon d'Or story (`M1/02-04`).
- **Liverpool has no manager photo in onboarding.** "Meet the boss" shows a placeholder person icon
  (`first-worstweek/05`), while the club tab shows a portrait. Newcastle's onboarding has a photo.
- **The season primer says "your boyfriend"** even though his name is known. It is only reachable with
  `-gdSeasonPrimer`.
- **Notification-ask preview.** It shows "<club> face Chelsea today at 15:00" with a made-up 1-0 (deliberate,
  NotificationPromptView.swift:126). On a real match day it contradicts the actual fixture: Newcastle play Everton
  at 19:45 tonight.
- **"Notifications are off" banner** sits on top of every feed screen when notifications are off. It covers about a
  quarter of the first screen. On the country-only device it says "before his next game" when no club is followed.
- **Matchday Before does not change as the game approaches.** Above the fold it shows the same "Get to know
  <opponent>" card 3 days out, the day before (clock-pinned) and on real match day (Newcastle).
- **Name inconsistency.** The switcher says "Newcastle" / "Spurs", but the tab says "Newcastle United" /
  "Tottenham Hotspur".
- **Two-club state shows no sign of the second club** until she opens the switcher menu.

## Not done by this agent

Steps 3-6 of §1 (below-the-fold text, pushes, usage, README) belong to the orchestrator. The `ocr/` text is only what
was on screen, not a census.
