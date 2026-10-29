# FEED+LOCK editor, app council 2026-10-29

Rows: 231 (FEED 189, LOCK 42). Every row has one verdict in `FEED_LOCK.csv`; the generator (`verdicts/tools/feed_lock.py`) asserts coverage against both census files.

| | Keep | Iterate | Move | Delete |
|---|---|---|---|---|
| FEED | 83 | 27 | 3 | 76 |
| LOCK | 25 | 12 | 2 | 3 |
| **Total** | **108** | **39** | **5** | **79** |

Most of the 79 Deletes are whole dormant or duplicate blocks rather than taste calls:
- the Saturday Quiz, 24 rows, merged into MD-04;
- the country feed, 11 rows;
- dormant article sections, 9 rows (Goals, After the match, favourite verdict, starting XI);
- the share paths, 9 rows;
- the zone-2 label rotation, 10 rows.

**Caveats.** There is no usage data (`analytics_events` = 0 rows), so every verdict is provisional. The tracking seat says feed cards, article internals and Live Activity states can never be settled by the current events: only shares, push opens, the banner and tab views can. The panel is AI personas, so it can share our blind spots.

I checked the persona doubts against live data. "Ezri Konsa scored for Arsenal" is dated knowledge: E. Konsa is in Arsenal's official squad. The held-tie label fix (a1b30fb) is in. The foreground refresh still wipes the shootout note (`LiveMatchSnapshot.swift:59`, `note: nil`).

---

## Screen by screen, with the verdicts applied

**FEED-01 Club feed.** This still makes sense, and it gets better.

What the first screenful holds after the verdicts:
- the club pill with no "9+";
- on day 1, no banner (it moves to the morning of his first match);
- card 1 with a plain headline that names who and what, and its age ("3h ago");
- the analogy at tiers 1-2, or the factual line at tier 3;
- one label, "Your move:", over a line she owns.

That line is the one thing she came for, and it stays at 0 taps.

Today, 5 of 6 personas were caught by a pre-match card sitting under the result ("Chelsea tomorrow", "Palace must-win"). Expiry (FEED-01-55) plus the age on the card (FEED-01-25) remove most of that.

Would L1 get through? Mostly. Her two failures were "howe linked to united" (fixed by the manager-label guard) and "rotate / full strength" in her first line (fixed by the one-sentence-jargon rule in FEED-01-40). The risk that remains is volume: L2 called eight cards a day "not just enough" at Light. Expiry trims it. A tier-1 card cap is not proposed, because there is no evidence beyond one persona.

**FEED-02 Empty, loading, error.** This makes sense. It matters more once stale cards leave, because a quiet week will now be empty. That is why the "Worth knowing" insider fact goes to every tier: it is the worst-week line. The error copy stops blaming her wifi.

**FEED-03 Saturday Quiz.** Gone from the feed and merged into Matchday › Before's opponent quiz (MD-04). Nothing has been written since 17 Oct, it is tier 3 only, and no persona met it.

**FEED-04 Club switcher.** Her club(s) plus Football. No country row, no badges.

**FEED-05 Football.** Kept, because it becomes the home for competition and rival news when the broadcast push stops. M1, M2 and D2 each valued another club's bad night as banter, but not as a 6 am buzz. It gets one label ("Talk about it:"), the same headline rules, and a cross-club contradiction check (two Ballon d'Or winners within 10 hours).

L1 never needs this screen. That is fine, because it sits behind the switcher.

**FEED-06 Article.** This gets much shorter and still makes sense. What stays:
- back, the age and the type badge;
- the headline (the panel's favourite plain sentence);
- Good to know, with "To impress" inline instead of behind a teasing button;
- Things to say, with a 44 pt copy button.

What goes:
- Listen (5 of 6 did not know what it was);
- share;
- the NEWS badge and the crests;
- Who's who;
- Goals and After the match (both dormant);
- Ones to watch (random rows: the query has no ORDER BY);
- The Backstory (0 of 5 would miss it; "repeats the top").

The first screenful becomes the headline plus the first facts. L1 gets through: the underlined glossary words are what carried her, and they stay.

**FEED-07 Glossary.** Kept whole. It is the L-tier lifeline (L2: "Thank you!").

**FEED-08 Share sheet.** Deleted, along with every share button. Copy stays. **This needs Anton** (see below).

**LOCK-01 Permissions.** All three are kept. They are iOS or Apple's, and their timing is the FIRST editor's call.

**LOCK-02 Pushes.** After the verdicts, the lock-screen week is:

| Push | Who gets it | Change |
|---|---|---|
| 07:00 "play today" | every tier, now including early cup rounds | none |
| Live Activity start | everyone with Live Activities on | silent |
| Goal | every tier | copy fixed |
| Half time | tier 2+ | none |
| Extra time | every tier | none |
| Full time | every tier | copy fixed |
| Club news | tier 1 big only; tier 2+ significant | never before 07:00 London, one per club per 3 h, title states the fact |
| Sunday brief | tier 2+ | before 11:00 London or feed-only |

What goes:
- The T-30 "Kickoff soon" is deleted. Its slot is kept for the tier-3 lineup line.
- Competition broadcasts, consequence cards and the 08:00 fallback stop buzzing.
- The paused day-before code is removed.

L1's actual week was 10 buzzes; under these rules it would have been about 5 (two reminders, two goals, full time; the kickoff alert is silent). Four of her 10 were not about Newcastle. Light's promise is 3-5. A match week with two goals still lands at about 5-6, so usage should settle whether Light keeps goals. The panel says yes: L1 and L2 found every goal push worth the buzz.

**LOCK-03/04 Live Activity.** The panel's favourite feature: 4 of 4 who saw the shootout called it worth it, and D2 said "That's the product". Kept, with four fixes:
- The stale state no longer shows a wrong score all evening (L2 and D1 would turn notifications off over it).
- The foreground refresh no longer overwrites the server's state or wipes the shootout note.
- Raw codes ("INT", "SUSP") become words.
- The compact island shows her club's code, not "MAN" or the opponent's.

L1 gets through: every label she sees is a plain word.

---

## The 10 most important verdicts in this group

1. **LOCK-02-07 Competition broadcast → feed-only (Move).** It reaches every device whatever club she follows, at 06:0x.
   - 5 of 6 personas found it annoying or a reason to turn notifications off.
   - For Arsenal followers it repeated the full-time push the next morning.
   - The path is not in PUSH_RULES §1, so add it there and to `verify-push-rules.sh` in the same change.
2. **FEED-01-55 + FEED-01-25 + FEED-01-28: stale cards (Iterate).**
   - Pre-match cards leave the feed 2 h after kickoff.
   - Every card shows its age.
   - Headlines carry no "tomorrow" or "tonight".
   - 5 of 6 were sent in a day late, which is the exact failure she downloaded the app to avoid.
3. **LOCK-03-15 + FEED-01-19: frozen score (Iterate).**
   - The Live Activity stale state and the in-app live card both kept a dead 1-0 (connection C1; L2 and D1 would turn notifications off).
   - The live score goes to every tier, because a tier-1 goal tap otherwise lands on a feed with no score (UI F2).
4. **FEED-01-40 / FEED-06-26 / FEED-05-10: the lines to say (Iterate the producer).**
   - No "Tell him [news about his club]".
   - No stage directions about his mood ("He'll need a moment", "He'll have a view").
   - One line per card is her own opinion.
   - No jargon she could not explain.
   - Sources: H §3 and §5, the she-wants-to-sound-smart rule, and M1 and D2 on the "he'll have a view" catchphrase.
5. **LOCK-02-06 News push (Iterate).**
   - Quiet hours end at 07:00 Europe/London, not 05:59 UTC (5 of 6 objected to the 6 am pushes).
   - Light gets big news only (L1 got 10 pushes and L2 12, against a promise of 3-5).
   - Titles state the fact, not his mood.
   - A tighter teaser guard and a 3 h per-club gap.
6. **FEED-01-50 News producer fact guards (Iterate).** Five wrong facts reached cards in 14 days:
   - two Ballon d'Or winners;
   - Howe still called Newcastle manager;
   - "Saturday" for a Sunday game, pushed twice;
   - 12th for 14th;
   - and three cards for one Kane story.
7. **FEED-01-13 Notifications banner → one card on his first match morning (Move).** 6 of 6 personas were negative. It covers the headline at accessibility sizes, and it is the third notification ask in a row. Settings keeps a notifications row.
8. **LOCK-02-01 / LOCK-02-05 Goal and full-time copy (Iterate).** Both pushes are worth the buzz for 6 of 6. The copy problems:
   - "1-1 to Liverpool" on an equaliser;
   - away leads read home-first;
   - lines that claim what he said;
   - "5-3" then "3-5" in the same push;
   - "Easy in the end" for a win settled at 96'.
9. **FEED-01-29 Analogy split by tier (Iterate).**
   - L1, L2, M1 and M2 each named an analogy as their best line.
   - D1 and D2 would remove it first.
   - Tier 3 gets the factual fallback, which is already stored.
10. **LOCK-02-02 Delete the T-30 kickoff, and LOCK-02-09 send the 07:00 reminder for early cup rounds.**
    - 0 of 3 found the T-30 worth it.
    - 3 of 3 who got the reminder valued it.
    - Three personas (L1, M2, D2) missed it for a cup tie and wanted it.

---

## Verdicts I am not sure about, which need Anton

- **Every share path deleted (FEED-08-*, 01-41, 06-03, 06-28).**
  - The panel says sharing outs her: "via GoalDigger" and "From GoalDigger", with no link attached.
  - Sharing is also the only organic word-of-mouth path in the app.
  - `line_shared` is tracked, so three weeks of 2.4 data could settle it instead.
  - Alternative: keep sharing but drop the GoalDigger attribution from the text.
- **Saturday Quiz merged into MD-04.** TIERS §5 still promises a Saturday quiz (in the app for Light and Match-fit, pushed for Deep), and the routine has been silent since 17 Oct. Anton should decide whether it is retired or broken.
- **07:00 reminder for early cup rounds.** This reverses part of the 2026-10-27 rule ("not in early cup rounds"). The kickoff and half-time pushes stay gated.
- **Quiet hours on London time to 07:00.**
  - The morning news routine fires around 06:00 UTC.
  - Under the downgrade-not-queue rule, those items would never push.
  - The routine's morning run needs moving to about 07:30 London (a routine schedule change, which costs nothing per CLAUDE.md).
- **"Big news only" for Light.** It needs a weight on each item, and the producer has none (TIERS §6.1, "unranked"). Either the routine writes one, or Light gets no news pushes until it does.
- **Goals at Light.** TIERS.md §5 says goals are app-only for Light and Match-fit. PUSH_RULES and the panel (L1, L2) say push them. One of the two documents is wrong.
- **T-30 deleted.** A Match-fit user with Live Activities off then gets no "it's started" signal. I accept that; Anton may not.
- **The Backstory deleted.** `body` may feed other readers. The dependency check must clear it before the routine stops writing it.
- **Who's who chips deleted.** This removes one of only two entries to the player card, which the club page cannot open today (census note). It should be decided together with TEAM.

## Summary

1. FEED+LOCK: 231 rows, all with verdicts. Keep 108, Iterate 39, Move 5, Delete 79. Most Deletes are dormant or duplicate blocks: the Saturday Quiz, the country feed, empty article sections, the share paths and the label rotation.
2. The feed's biggest failure is time. Pre-match cards outlive their match and carry "tomorrow" or "tonight" with no date (5 of 6 personas were caught). Expire them, date every card, and ban relative day words.
3. The lines to say must stop being "Tell him [news]" and mood stage directions (H and the she-wants-to-sound-smart rule). Five wrong facts in 14 days need producer guards in `post_news.sh`.
4. On the lock screen:
   - Goals, half time, full time, the 07:00 reminder and the Live Activity earn their buzz.
   - Competition broadcasts go feed-only.
   - The T-30 kickoff is deleted.
   - News stops before 07:00 London and is big-only for Light.
   - The frozen-score states are fixed.
5. No usage data exists, so all verdicts are provisional. Only shares, push opens, the banner and tab views can be settled by the current events.
