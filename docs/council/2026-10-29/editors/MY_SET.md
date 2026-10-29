# MY + SET editor: council 2026-10-29

326 rows (MY 207, SET 119), one verdict each in `MY_SET.csv`. The coverage gate passes: 326 census ids, 326 verdicts, no gaps, no extras.

Read every verdict as provisional. `analytics_events` holds 0 rows, and the panel is seven AI personas, not real women, so they can share our blind spots. The `usage_can_settle` column marks the verdicts that usage can decide. The tracking seat says these cannot be settled by usage: the Lingo dictionary, Say This situations, Safe/Bold, Say This practise, and every Settings row except clubs, tier, opening the sheet and delete. They will stay opinion until `my_turn_opened{module, what}` and the wider `settings_row_opened.row` ship.

## Screen-level judgement

**MY-01 My Turn shell.** The screen holds up. The problem is the order. She lands on the Quiz first, and that is the module every persona called homework. She would use Say This and Lingo's search at the pub. The verdict reorders the segments to Say This · Lingo · Quiz and opens on Say This on her first visit. L1 would get through it.

**MY-02 Quiz pack list.** Today the first screenful is wrong at every tier. Light gets eight packs ("This is a school"), and Deep gets "How many points for a win?" behind the big button. Nothing in `Views/MyTurn` reads her tier. With the verdicts applied:
- Tier 1 sees The Basics, His squad and His club right now, plus one "More packs" row.
- Tier 2 starts on His squad.
- Tier 3 starts on His club, the history, the pack H calls "the best section in the app by a mile".

That makes sense, and L1 no longer faces a syllabus.

**MY-03 to MY-06 Quiz round.** The format holds up: the question, then the fact, then one line to say. Four personas liked the popup on its own. The damage is in the live builders' use lines, where H says "she'd get caught":
- a cup exit on penalties called a draw;
- "Have you ever been to the Emirates?" asked of a season-ticket holder;
- "Is he scoring today?" about an injured Saka;
- "Is White going to get a game soon?" about a man with 7 starts;
- "Point at the screen".

All of these are fixed in the producers (LiveClubPack, LiveSquadPack, PlayerHooks), and the questions stay. The review mode (Previous / The one before / Back to question n) and the per-pack scores are deleted. After those changes the screen still makes sense.

**MY-07 to MY-10 Lingo.** The first screenful should be the search field (4 of 6 personas: "look it up under the table"). Today it is a Practise button and 158 words with counts. The verdicts put search first, drop the counts and send Practise to the bottom. The Overheard round stays. The one hard defect is offside: the rules dictionary says "nearer the goal than the last defender", which is wrong. D1 and D2 both caught it, and three Light and Match-fit personas called it the clearest explanation they had seen, so they would repeat it. The say-it lines also need a pass: xG, gaffer, boot room, "top four is the aim" said to the champions, and window lines in October.

**MY-11 to MY-14 Say This.** This is the strongest part of My Turn. Safe/Bold is the only place the app gives her an opinion of her own (M1, M2), and all 6 personas rated it positively. The in-match lines are H's second-best group. What fails is the usage notes under the "When he asks you" lines:
- "He knows already. He wants to be asked."
- "Even if it was a bit in doubt."
- "Ask him to name him and agree."
- "Vague enough to be true."

Those are notes for managing him. They are rewritten to say only when to use the line. "All possession, no penetration" becomes "no end product". The practise drill is deleted: 4 of 5 personas who commented would not miss it, and the list already shows every line. At tier 1 the screen opens on MOMENTS only, so L1 sees five-ish moments first.

**MY-15 Streak card.** Deleted. It contradicts ARCHITECTURE's "no streaks by design", nobody on the panel saw it, and it interrupts a round.

**MY-16 Glossary pack.** The sheet stays, but its 46 definitions move into Lingo, so the app has one dictionary instead of two. Today the two disagree with each other and both get offside wrong. "World Championship" is deleted. "Premier League" stops being underlined at tier 3: three of six personas felt patronised by it.

**SET Settings.** This chapter is mostly the can't-delete list, and the list holds: the gear, his name, club, mode, calendar, notifications, Delete My Data and its alerts, and the privacy link. With the verdicts applied it still makes sense, and its first screenful is notifications and calendar, which is fine. Two can't-delete gaps came up while walking the code:
1. **The country row is hidden from the 10 active devices that still follow a country.** It is gated on `CountryFollowing.isEnabled` (false), so they cannot remove the country. This is the 2026-09-23 `hisCountryRow` mistake again, and the code comment above the gate warns against exactly this. Fix: show a "Stop following {country}" row whenever a country is followed. The 48-country World Championship picker is deleted.
2. **Relationship (Partner / Parent / Sibling / Friend) can only be changed by deleting all data.** It is set only in `HisNameView.swift:101`. The census has no row for it, so it is folded into SET-04-00: the his-name alert becomes a small sheet with the four chips.

Delete My Data, its alert texts and the privacy row are Iterate, not Delete:
- S-2 / F3: an offline or rate-limited delete orphans the analytics and rotates the id.
- S-8: keys are left on the phone.
- S-3: the exit-row props say more than the policy promises.
- PRIV-1: the privacy row opens the carrd home page.

All four must land before 2.4 is submitted.

## The 10 most important verdicts, ranked

1. **MY-03-12 / MY-02-08 Iterate.** A shootout is shown as a draw ("Was the draw with Fleetwood fair?"). Fix it in team-page-generator `recent_results`, using the winner flag and `score.penalty`. Data seat D2, HIGH, CONFIRMED.
2. **MY-02-00 / MY-02-01 / MY-02-19 Iterate.** My Turn should follow her tier. Today the pack list is the same for everyone. 6 of 6 personas said it was too much, and 4 of 6 found The Basics patronising as the first thing they meet.
3. **MY-07-12 / MY-08-08 / MY-16-02 Iterate + Move.** Correct the offside definition in both dictionaries, then merge them into one.
4. **MY-12-07 (+ MY-11-29/30/33/34/35) Iterate.** Delete every usage note that coaches her on his mood. These are memory rule 1 and H §3.
5. **SET-02-19 / SET-06-00 Iterate.** Give the 10 country followers a way to stop following the country (can't-delete list).
6. **SET-02-31 / SET-10-02 / SET-12-02 Iterate.** Make Delete My Data true under 2.4 (S-2, S-8, F3). Pre-submit gate.
7. **SET-02-30 Iterate.** The privacy row should open a privacy policy, not the home page (PRIV-1, S-3). Pre-submit gate.
8. **MY-02-07 / MY-03-22/23/26/27 Iterate.** In His squad, keep the faces and cut the lines that expose her: injured players, the nationality hook for regular starters, and "point at the screen".
9. **MY-01-00 / MY-07-00 Iterate.** Lead with Say This and with Lingo search: what she uses comes first.
10. **MY-04-06 / MY-07-14 / MY-09-05 Iterate.** The line pass:
    - 128 doubled "Ask him:" prefixes;
    - the Toffees cause and effect;
    - xG, gaffer and "penetration";
    - lines that don't fit the week ("top four" to the champions, the window in October, relegation for Liverpool);
    - the bracketed "(forward, Liverpool)" inside spoken lines.

## Needs Anton

- **The Say This practise delete (MY-11-01, MY-13-*, MY-14-*, 20 rows).** This rests on persona opinion of a button, and usage cannot settle it until a practise event exists. The alternative is to keep it and add the event.
- **The Lingo fold counts (MY-07-06..09).** ARCHITECTURE kept the counts deliberately ("word counts, no progress counters"). Four personas read them as an exam.
- **Her name (SET-02-15/16, SET-03-*).** Delete only if the FIRST editor deletes the onboarding name question. Nothing outside Settings reads her name.
- **Tier-driven My Turn (MY-02-00, MY-12-00, MY-11-00).** This gives tiers a visible meaning for the first time. It is a product decision as much as a fix. SET-07-04..06 rewrite the mode descriptions to match.
- **Review mode and pack scores (MY-03-04, MY-04-09/12, MY-02-14/15, MY-06-11).** These are low-confidence deletes with no evidence either way.
- **`why` and `heard` (MY-04-07, MY-07-16).** Before dropping `why` from the remote `my_turn_content` body, confirm the 2.3 decoder treats it as optional. `heard` is non-optional today, so it cannot be dropped from lingo.json until a build makes it optional and old installs age out.

## Summary
- **Counts:** MY 207 = Keep 126, Iterate 44, Move 6, Delete 31. SET 119 = Keep 87, Iterate 13, Move 0, Delete 19. Total 326 = Keep 213, Iterate 57, Move 6, Delete 50.
- **My Turn:**
  - The content that lands is the club history quiz (H ~70%), Say This with Safe/Bold (6 of 6 positive) and Lingo search (4 of 6).
  - What fails is the order she meets it in, with no tier awareness, and the live squad and club-now lines that expose her.
- **Hard defects:** shootout-as-draw (Data D2), the offside definition (wrong twice), the backwards Toffees line, 128 doubled "Ask him:", and mood-managing usage notes.
- **Settings:** the can't-delete list holds. Two new gaps: country followers cannot remove a country, and relationship cannot be changed.
- **Pre-2.4 gates in SET:** S-2/F3, S-3, S-8 and PRIV-1 on Delete My Data and the privacy link. All verdicts are provisional: usage is 0 rows and the panel is AI personas.
