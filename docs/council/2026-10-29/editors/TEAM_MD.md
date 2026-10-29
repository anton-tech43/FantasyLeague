# TEAM + MD editor: council 2026-10-29

272 rows (TEAM 140, MD 132), one verdict each, in `verdicts/TEAM_MD.csv`.
**Keep 155 · Iterate 80 · Move 15 · Delete 22.** TEAM: 77 / 34 / 12 / 17. MD: 78 / 46 / 3 / 5.

Most of the Keeps are structural: labels, back links, progress lines and empty states that a kept card cannot work without. Each one is kept only as long as its parent is. The real content decisions are the Iterates, the Moves and the Deletes.

No usage data exists, so every verdict is provisional. Usage cannot settle anything on the club page yet, because the club page logs nothing (TRACKING: only `tab_viewed club`). The 31 rows marked `usage_can_settle=y` need `club_card_tapped {card}` (TEAM) or `pregame_card_started {card}` (MD) to exist first.

## Checked by me (beyond the seats)

- **Live box home/away (D2's report): CONFIRMED in code, and it is a design flaw, not a data flip.** `buildLiveHeadline` (`live-brief-current/index.ts:301-310`) always puts his club first. The scorer columns are home-left and away-right (`LiveMatchCard.swift:88-92`). For an away game, the opponent's scorer therefore sits under his club's name. Four of seven panellists noticed it (L2, D1, D2, H). After (MD-07-01) is home-first, so the two surfaces disagree.
- **After in a warm app (BUGS #2): CONFIRMED in code**, but not reproduced live. `live.refresh` has two callers: `.task(id: selectedTeam)` (`GoalDiggerApp.swift:418-422`) and `openMatchday(.after)` (`:211`). Nothing runs on `.active`. Matchday reads `live.page` (`MatchdayView.swift:101-105`). The page refresh that His Team does goes to `TeamPageCache`, not to `live.page`.
- **Player ages are wrong (D1 #2/#3, D2 #19/#20): CONFIRMED by SQL.** `players.age` shows Rice 26 (row updated 2026-09-08) and Saka 24. The real ages are 27 and 25. The column is a feed snapshot with no birth date, so the fix is to drop the age (TEAM-06-05).
- **"Gyökeres: his first goal of the season" (doubted by D1 and H): NOT confirmed wrong.** `players.goals = 1` and `league_goals = 0` after Fleetwood. The claim is consistent with our trusted feed, so MD-07-11 stays.

## Screen-level judgement

**TEAM-01 Info tab: Iterate.** The first screenful is right. "Coming up · Liverpool (AWAY) · Sun 1 Nov 16:30 · Could go either way" is the thing she came for: 5 of 6 she-personas valued it, and L2 called it "the most useful thing in the app". It breaks in two places:
- On match day the time is cut off ("Thu 29 Oct at 1…", UI F1 HIGH).
- After a game the After card takes over that top slot. On Liverpool this hid the preview of Sunday's game (M2).

Below the first screen the page is too deep, about 526 words:
- Position is said three times (How they're doing, Season so far, Table). 5 of 6 named Season so far as the first thing to remove.
- The last result is said twice (the After card and Matchday › After).
- Four branches are dead.

With the verdicts applied, the page reads Coming up, The basics, The manager, Ones to know, The rivalry, How they're doing (season sentence folded in), then Things he doesn't know. That still makes sense.

Would L1 get through it? Mostly. Three things still make her feel dumb: the unexplained form dots (6 of 6 she-personas could not read them), "top flight" (4 of 6), and the table's GD column (4 of 6). All three are Iterates.

**TEAM-02 Info cards opened: Iterate.** The opened cards are where she gets caught:
- Saka is "facing around two months on the sidelines", and the opener under it says "Is he scoring today, do you reckon?". L2, D1 and H each called it the worst line in the app.
- "If Tom supports Arsenal" appears on every rivalry card.
- "Drop this: …well-drilled / excellent start / encouraging recent results" was rated dumb by 5 of 6.

The data underneath is sound. Coming up's numbers all reproduce, and the dossiers were the most current text in the app.

The fixes sit in three producers, not in the layout:
- the injury filter and live tallies for ones-to-know and the opener (DATA D4);
- a rule in the gd-team-page prompt for the manager line and the form summary;
- the hand-seeded rivalry and basics text.

**TEAM-03 Calendar: Keep the screen, Iterate two things.** All 6 she-personas found the fixture list useful; D1 said it was "the most useful screen on the club page". The importance dots fail all 6: every league game is 3 dots, derbies included, so "more dots, bigger game" is false. Make the dots mean something, or delete them and the legend. "Show last games" calls a shootout exit "D" (DATA D2 HIGH).

**TEAM-04 Table: Keep, Iterate.** For the D and M personas it is ammunition: D2 called it "the single most useful screen for an argument". It needs three changes:
- open scrolled to his club (Spurs at 14th is off the screen, per M1);
- explain P and GD;
- fix the columns at accessibility text sizes (UI F7).

**TEAM-05 glossary sheet: Keep** as the entry point. The content belongs to FEED-07, and its Champions League line "Top four PL teams qualify" is out of date (D1, D2). FEED editor's call.

**TEAM-06 Player card sheet: Keep, Iterate.** It cannot be reached from the club page: the `.sheet` is declared but nothing ever assigns it. It is reached from the quiz and from articles. Two changes: drop the age, which is a stale feed value, and give the close button a 44 pt target and a VoiceOver label. Delete the dead teaser, the vibe tag and the duplicated form tag.

**MD-01 Matchday tab: Iterate.** The After/Before split reads clearly (4 of 6). It fails at the three moments it exists for:
- **Match day:** the tab opens on "Get to know Everton" with no time and no "tonight" (UI F1).
- **Live:** it stays on prep cards while the game is on (UI F2).
- **After:** in a warm app the After segment may never appear unless she taps the full-time push (BUGS #2, confirmed in code).

**MD-02 Before: Iterate.** The first screenful should be the one thing she came for: the time, and something to say. Today it is one giant card with one sentence; 5 of 6 she-personas called it empty or unfinished. The panel puts the three cards in a clear order:

| Card | Would miss it |
|---|---|
| 7 words | 4 of 6 |
| Get to know | 2 of 6 |
| Sayings slip | 2 of 6 |

So the order becomes: kickoff line, then 7 words, then Get to know, then Sayings, all three visible without scrolling. Get to know and Sayings stay because they are exactly what Match-fit wants ("THIS is what I need", M2). For L1 they are homework, so each is cut down: the lesson to four pages, the quiz to five questions, the slip to three lines.

**MD-03 lesson / MD-04 quiz: Iterate.** Shorten both (above). Fix three things that would catch her out:
- injured ones-to-watch (DATA D4);
- "Is he the one to worry about?" three times in a row (L2, M2, H);
- "They've been flying lately" straight after a 0-3 at City (D1, H).

What works: "Have you ever been to Anfield?" landed with H, and the opponent manager is verified.

**MD-05 seven words: Iterate.** This is the strongest element on the tab. Three fixes:
- deal by tier (L gets no xG, D gets no "box");
- remove the "What was the xG?" reveal line, which is banned by name in the sound-smart rule;
- stack the two options at accessibility sizes.

**MD-06 sayings: Iterate.** Change the offer from seven lines to three, and clean the pool:
- "gaffer" (4 of 6 personas);
- "we" said by her;
- "This is why he stays up";
- "run-in" in October;
- "A point's a point" in a cup tie;
- "Backs to the wall" at half-time when ahead.

Separately, the favourite tag must come from the page's chip (DATA D9).

**MD-07 After: Iterate. It becomes the one home for the last result.** Its first screenful is wrong in four ways:
- 82% of the screen goes to one sentence;
- the verdict fails contrast at 3.95:1;
- the line she came for sits under the tab bar;
- the biggest text says "1-1" for a game decided on penalties (M2: "says we drew. We won").

The talking point is the worst offender in MD. "Their run is over. He might need a minute" is a stage direction about his mood and is used for six clubs; 5 of 6 rated it negatively. "Ask him who he wants to draw" went stale within hours, because the draw had already been made (M1 and M2 both named it their worst moment). With the verdicts applied, After also takes over:
- the club page's After card (a link stays on the club page);
- the "What you called" result of her sayings slip.

That gives the slip its promised payoff.

**MD-08 The full story: Iterate the producer.** All 6 she-personas flagged the leaked editor's note "Worth checking before she says anything about who is through". It is the most-noticed defect in either chapter. The article also needs to stay published while After is live, so the link does not vanish after about two days.

**MD-09 Live box: Move to every tier.** At tier 1 a goal push lands on a feed with no score, which breaks the product rule. The fix is score, minute and scorers for every tier, with the prose kept at tier 2 and above. This box is the live score's one home, and Matchday reuses the same component while the game is live. Three further changes:
- home side first in the headline (4 of 7 panellists; confirmed in code);
- "PENALTIES", not "BREAK", for a held tie (BUGS #1);
- no stage directions in the half-time prose.

## Same fact in several places: the one home

| Fact | Home | Leaves from |
|---|---|---|
| Last result and verdict | Matchday › After | Club page After card (TEAM-01-15..19, 02-10), replaced by a one-line link. Producer stays: 2.2/2.3 and onboarding's MeetTeam read `post_match` |
| Next fixture | Club page › Coming up (Calendar row 1 is the list) | After "Next:" line (MD-07-17), `this_week` (TEAM-01-28..30). Before gets a kickoff line, the one deliberate repeat, because at match time the time is what she needs |
| Position and form | How they're doing (+ Table) | The season so far (TEAM-01-60..62, 02-30) |
| Opponent's ones to watch | Matchday › Get to know | Coming up opened (TEAM-02-06/07) |
| Favourite | The Coming up chip (`next_fixture.favorite`) | The matchup card's feed-model favourite (MD-06-08 tags) |
| Live score | Live box (all tiers) | None. Matchday reuses the component while live |
| Manager paragraph | Club page › The manager | Onboarding repeats it word for word (L1); FIRST editor decides |

## Ten most important verdicts, ranked

1. **MD-08-02 Iterate:** remove the leaked editor's note "Worth checking before she says anything about who is through" (6 of 6), and hold the article until PEN/AET.
2. **TEAM-02-21 / TEAM-01-49 Iterate:** apply the injury filter and live tallies. "Is he scoring today?" about a man out for two months is the textbook way to get caught (L2, D1, H; DATA D4 HIGH).
3. **MD-07-05 Iterate:** the After line becomes something she can say, not a stage direction about him or a future event ("who he wants to draw").
4. **MD-09-00 Move:** live score for tier 1 (UI F2 HIGH; product rule).
5. **MD-01-00 Iterate:** refresh on foreground so After appears, open on the live score while the game is on, and show the kickoff time (BUGS #2, UI F1/F2).
6. **TEAM-03-14 / MD-03-06 / MD-04-06 Iterate:** a shootout is not a draw anywhere (DATA D2 HIGH). The same producer fix also repairs MY's "His club, right now" quiz ("Was the draw with Fleetwood fair?"), where H says she gets caught.
7. **TEAM-01-23 Iterate:** kickoff time never truncated on match day (UI F1 HIGH).
8. **TEAM-01-15 Move:** the After card leaves the club page so Coming up always holds the top slot (M2; DATA byte-identical).
9. **MD-02-00 / MD-02-16 Iterate:** Before shows the kickoff line and 7 words first, with all three cards in the first screen (5 of 6 flagged the empty card; 7 words is missed by 4 of 6).
10. **TEAM-01-60 Move:** the season card merges into How they're doing (5 of 6; STALE S2, stale every weekend).

Next in line:
- MD-09-05 (home-first live score);
- TEAM-01-40 (the "Drop this" manager line, 5 of 6 dumb);
- TEAM-03-02 (dots, 6 of 6);
- MD-07-01 (pens in the After score line).

## Verdicts that may need Anton

- **TEAM-03-02, the importance dots:** make them real (derby 5, top clash 5, late cup round 4) or delete them and the legend. The panel would accept either; it rejects the current flat dots.
- **MD-02-01 / MD-03-00 / MD-04-00, Get to know at tier 1 and tier 3:** I shortened it for everyone rather than hiding it per tier. Light and Deep both called it homework, while Match-fit loved it. Hiding it at tiers 1 and 3 is the stronger cut, and only Anton can trade that against simplicity.
- **MD-07-05 and MD-09-07, the mood lines:** L1 and L2 liked "He might need a minute" and "give him space" as advice. I applied the product rule (a mood line is a defect) over two personas, as the brief directs. Anton should know that the Light tier is the one losing something here.
- **TEAM-01-54, Coventry's rival:** Leicester or Aston Villa is Anton's pick.
- **MD-02-18, the never-shown week subtitle:** I proposed showing it as the Before header line ("Derby week…"), reusing the builder. If he doesn't want that, delete the builder.
- **TEAM-01-28 `this_week`:** the view branch can go now. Stopping the producer needs a check that no 2.2/2.3 install still reads it (dependency check, §5).
- **Deletes resting on "no case made" (low confidence):** MD-01-06 (gold dot), MD-01-11 (streak overlay), MD-05-12 (go again), TEAM-06-09 (vibe tag), TEAM-02-17 (Coventry's basics line). Usage, once logged, should settle them.

## D1's 39 facts: what counts in these chapters

**Confirmed defects (counted):**
- Rice and Saka ages (SQL).
- The rivalry "neighbours since 1887". Arsenal were in Woolwich until 1913.
- "Arteta at Arsenal since 2019". He was there as a player from 2011; it is a phrasing error.
- Barnes and Gakpo shown as "Midfielder" while their dossiers say forward.
- Fleetwood shown as "D".
- "Lost just once all season" (stale season card).
- The Saka and Rice contradictions (DATA D4).
- The leaked note.
- The live box home/away order (by design, but wrong to read).
- "They've been flying lately" after a 0-3 at City.
- The Dowman red-card minute disagreeing between article and full story. The contradiction is confirmed; which version is true is not.

**Not counted (dated knowledge or unverified):**
- Iraola at Liverpool and Jaissle at Newcastle: STALE verified all 20 managers.
- Gyökeres's "first goal of the season": consistent with `players`.
- "26-3 shots on 53%": plausible; the stats source is unverified (DATA), which is handled at MD-07-14.
- "Sabah FA": low-confidence Iterate (TEAM-03-07).

## Cross-chapter notes for the other editors

- **MY:** H's "His club, right now" and "His squad" are built from the same `team_pages` / `players` data. The pens fix (DATA D2) and the injury filter (D4) repair "Was the draw with Fleetwood fair?" and "Is he scoring today?" there too.
- **FEED-07:** the glossary's Champions League "top four" line is out of date.
- **FIRST:** the manager paragraph is duplicated word for word between ONB-07 and TEAM-01-38.

## Summary

1. Keep 155, Iterate 80, Move 15, Delete 22 across 272 rows. The Keeps are mostly structural; the content verdicts are the 117 others.
2. The club page's first screen (Coming up + chip) and the Calendar are the strongest things in either chapter. The opened cards are where she gets caught: an injured Saka's opener, "If Tom supports", "Drop this: well-drilled".
3. Matchday fails at its three moments: no time on match day, prep cards during the game, and an After that may not appear in a warm app. After's line manages his mood instead of handing her something to say.
4. The merges: the last result lives on After, the next fixture on Coming up, form on How they're doing, the opponent's players in Get to know, the live score in the live box (opened to tier 1).
5. Dead branches deleted: mood, `this_week`, freshness, the rivalry meter, three never-filled "Say/Use/Drop this" labels, the live standings and the dossier teaser. Six fixes sit in producers, not views: pens in `recent_results`, the injury filter, `postMatchTalkingPoint`, the gd-matchday note, the gd-team-page manager and form rules, and the insider `is_active` filter.
