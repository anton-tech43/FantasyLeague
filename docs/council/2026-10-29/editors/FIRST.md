# FIRST editor: store page, onboarding, first session (council 2026-10-29)

Rows: STO 35 + ONB 173 = 208, one verdict each in `verdicts/FIRST.csv` (coverage checked by `verdicts/build/first_verdicts.py`).
Evidence: 6 women (L1 L2 M1 M2 D1 D2) + H, the seven seats, `first-session.txt`, staging, and code/SQL I re-checked myself.
Caveat: the panel is AI personas. **0 of 6 closed the app at any setup step**, which a real funnel would not show. Drop-off per step is the first thing usage must settle (`onboarding_step_viewed`, once tracking F4's flush fix ships).

---

## 1. The first session: today vs proposed

**The worth-it moment** is when she has something she can use, about his club, this week. Today that moment does not come at the end of setup. **6/6 answered "not yet"** at the first feed screen. What came closest:
- **Meet the boss**: the first "oh, that's useful" for 4/6 (L1, L2, M1, M2).
- **The club tab**: named the most useful screen by 4/6 (L1, L2, M2, D2). It already carries the same facts as setup; L1 found the text "word for word" the same.

So the proposal is mostly a **removal**. Setup asks only for his club, then hands her the page that worked.

### Match week (staged: Newcastle, kickoff tonight 19:45, away at Everton, League Cup)

| # | Today | words | taps | Proposed | words | taps |
|---|---|---|---|---|---|---|
| 1 | Welcome | 13 | 1 | Welcome (no dots, no glyph) | 13 | 1 |
| 2 | Her name | 8 | type + 1 | — deleted | | |
| 3 | His name + Partner/Parent/Sibling/Friend | 12 | type + 1 | — moved to club-tab header / Settings | | |
| 4 | Club picker | 33 | 2 | "Which Premier League club does he support?" (no underline, no second-club card) | ~30 | 2 |
| 5 | Meet his lot | 84 | 1 | — moved: the landing shows it | | |
| 6 | Meet the boss | 61 | 1 | — moved: the landing shows it | | |
| 7 | How it works | 94 | 1 | — deleted | | |
| 8 | Tier | 46 | 1–2 | — moved to Settings, default 2 | | |
| 9 | Notification ask (+ "One more thing" sheet ~40 w, or the iOS dialog) | 47 (+40) | 2 | — moved to the landing, about tonight's game | | |
| 10 | Calendar ask (+ iOS dialog if yes) | 27 | 1–2 | — moved to the club Calendar tab | | |
| 11 | Feed card 1: "cup game tomorrow" (wrong on match day) + notifications-off banner | 79 | — | **Landing: club tab.** Coming up "Tonight 19:45 · at Everton · League Cup · could go either way", one line to say, The manager (with "the person he either loves or wants fired"), The basics. Inside Coming up: "Want the score on your lock screen tonight? Yes / Not now" | ~65 | 0 |
| 12 | ATT sheet over the feed | ~35 | 1 | — moved to her second session | | |
| 13 | Club tab (the first screen 4/6 said delivered) | 39 | 1 | (already there at step 11) | | |
| | **To the worth-it moment** | **≈620** | **13–15 + 2 typed names; up to 3 system dialogs** | | **≈110** | **3; 0 typed; 0 dialogs before it** (1 optional on it) |

Rough time (200 wpm, 1.5 s a tap): about **3.5 min today** (M2: "about two minutes" for setup alone), against **about 40 s** proposed.

### Worst week: no match for 10+ days, or an international break (NOT staged; reasoned from code and data)

Staging could not reach this state: every club plays between 29 Oct and 1 Nov. The real case is the international break after 7–8 Nov (Arsenal: Hull 7 Nov, then Newcastle 21 Nov). What she would meet today, from code and data:
- **Setup** is unchanged: about 404–425 words and 11–13 taps.
- **Feed card 1 is probably days old.** In a quiet week a club gets 0–1 new items a day; Newcastle had 2 items in the 7 days 3–9 Oct (SQL). Cards carry no date (UI F5), and staging found five stale time words in one day.
- **Matchday** opens on Before, "Get to know Newcastle", for a game 14 days away. `MatchdaySection.opening` (MatchdayView.swift:178) has no distance limit, and L2 and D1 called this homework.
- **The club tab is the only surface that is evergreen and verified.** The stale seat checked all 20 managers, the last-season lines, the fun facts and the calendars as current. That makes it the right landing in the worst week too.

| | Today | Proposed |
|---|---|---|
| Screens to worth-it | 10 setup + up to 3 dialogs + feed + 1 tap | Welcome → club → **club tab** |
| What the landing says | A feed card from days ago, with no date | Coming up "Next: Sat 21 Nov v Newcastle. No Arsenal for two weeks: it's the international break". That is a line she can use. Then The basics ("Last season: Champions, 85 points", which L2 called "the single biggest fact about his team… should have been told on screen one"), The manager, The rivalry (L1's and L2's close-second best moment) |
| Permission prompts on day 1 | Notifications, calendar, ATT | **None.** The notification ask appears on Coming up from 48 h before his next kickoff |
| Words / taps to worth-it | ≈600 / 13–15 + 2 typed | ≈110 / 3 |

Risk in the worst week: if she does not open the app in the 48 h before the game, she is never asked. Two mitigations:
- **The lock-screen score still arrives.** Live Activities do not need the notification answer: the push-to-start token is registered at setup by `LiveActivityManager.start()`, and iOS asks about Live Activities at the first kickoff. I read this in code and did not reproduce it.
- **Option for Anton: request `.provisional` notification authorisation at the end of setup.** No dialog appears; the 48 h "Arsenal play on Saturday" reaches Notification Center quietly; the full ask happens on her next open. `AppDelegate.swift:71` and `NotificationService.swift:104` already treat `.provisional` as registered.

### Every permission prompt: now, or when it pays off

| Prompt | Today | Decision | Evidence |
|---|---|---|---|
| Notifications (ONB-10/11/12) | Step 9 of 10. A fake fixture ("face Chelsea today at 15:00"), a guilt headline, a second-chance sheet, then a feed banner | **At the moment it pays off.** On the landing when he plays within 48 h (match week: the same screen); otherwise on Coming up from 48 h before kickoff. Built from the real fixture. No second sheet | 5/6 found the headline needy; H called the fake fixture "a dead giveaway"; UI F4: asked 3 times before one story |
| Calendar (ONB-13/14) | Step 10 | **When she is looking at his fixtures**: top of the club Calendar tab, with "one switch in Settings takes them out" | 6/6 said "Not now"; 6/6 noticed 15 vs 25; L2 would have said yes if told she could remove them |
| ATT (ONB-17) | 1.5 s after the first feed, on top of it | **Second session.** Add `permission_answered` first | 6/6 asked not to be tracked and named a trust dent tied to the store's "no tracking" |
| Live Activities (ONB-18) | iOS asks at the first kickoff | **Keep as is.** That is already the moment. Move the "say yes" line into the notification ask, in plain words | 2/2 Light personas did not know the term |

### What the landing needs from other editors (not my rows)
- **TEAM+MD:**
  - Coming up must show the time without truncation; today it reads "Thu 29 Oct at 1…" (UI F1 HIGH).
  - It must use a time-aware label. `comingUpLabel` already returns "Tonight:"/"This weekend:" (TeamPageView.swift:1183, wired at :504).
  - It needs an international-break line. None exists: there is no "international break" string anywhere in `ios/`.
  - One line to say must sit above the fold. Today "Drop this:" is below the fold under the manager.
  - The manager card takes the ONB-07-03 line.
  - Ones to know needs the data D4 fixes.
- **FEED+LOCK:** no notifications-off banner on day 1 before the just-in-time ask has had its chance (UI F4), and nothing that buzzes about a "Saturday" that is a Sunday (data D6).
- **MY+SET:**
  - SET-03 (her name) loses its reason to exist.
  - Settings needs a **relationship** picker under His Name. None exists today, and the onboarding chips are the only place it is set.
  - SET-07 should fix tier 3 "She knows…" to "You know…" and add the one-time "More, less, or about right?" card after her first match weekend.

---

## 2. The store page (STO) as the first thing she reads

Each element below is judged as her first contact with the app. Counts come from the 6 women.

| Element | Read as | Verdict | Copy direction (Anton edits in App Store Connect; agents may not) |
|---|---|---|---|
| Name, icon, price, category, age, size, compatibility, copyright | Fine | Keep | — |
| Subtitle "Football for partners" | 3/6 positive, 0 against | Keep | — |
| Header assets "Football, finally in plain English." / "Keep up. Or wind him up." | Hooks for the Light (2/6) and Match-fit/Deep (3/6) tiers | Keep; verify they are uploaded | Lead with "Keep up. Or wind him up."; the plain-English line second |
| Promotional text | Empty | Iterate | One evergreen line about the moment she is in (his next match, said plainly). It can change without review, so it is the place for freshness, never the description |
| Ratings: 0 | 5/6 named it | Iterate | Apple's native review prompt once, after her first worth-it moment |
| Description ¶1, 2, 4 | Opener and "No men explaining offside to you" liked by 3/6 | Iterate | His club, not his country. Keep "something natural to say back". Drop the mood-reading half of ¶4 (product rule) |
| ¶3 (England v Croatia → "order pizza") | Tournament example; mood punchline | Iterate | Keep the before/after device with no real club or country. The "after" is a sharp line she could say, not a forecast of his mood |
| ¶5 (48 nations, pick his country, **"no tracking"**) | **6/6 caught the contradiction with the label; 6/6 carried it into the ATT sheet** | Iterate | State what is true: 20 Premier League clubs plus the cups, follow up to two, free. Never "no tracking" |
| ¶6 (June 11, England) | 6/6: "nobody has touched this since June" | Delete | — |
| ¶7 / privacy label link `getgoaldigger.com/privacy` | **Dead today** (curl: no response; carrd 200) | Iterate (cannot delete) | Point both at the carrd page the app already uses, or fix the domain |
| ¶8 support address | Differs from the app's | Iterate | One address |
| Screenshots | No captions; 2 of 6 sell setup steps | S1 Delete, S2/S3/S5 Iterate, S4/S6 Delete | Order: 1) club tab landing (Coming up, basics, manager); 2) a feed card with an undated line to say; 3) the lock screen (Live Activity score or shootout + an FT push with "Say:"). One plain caption each, saying what she gets. Drop the T3 weekend quiz (reaches 33 of 92 devices) and the calendar ask (6/6 declined; "15" contradicts the app's 25) |
| What's New | Sells a T3 feature | Iterate | What changes in her week |
| Keywords | World Cup set (unverified live) | Iterate | Remove world cup/fifa/national team; add her search words |
| Privacy label | The half of the page the panel believed | Iterate | Re-declare against 2.4's privacy manifest before submitting 2.4 (security seat) |

The lesson: the store page lost trust **twice**. First on the page itself (6/6), and again 1.5 s into the app when the ATT sheet proved the page wrong (6/6). Fixing ¶5 and moving ATT are one fix seen from two sides.

---

## 3. Screen-level judgement (with the verdicts applied)

| Screen | Still makes sense? | First screenful = what she came for? | L1 gets through without feeling stupid? |
|---|---|---|---|
| ONB-01 Welcome | Yes: one line, one button; dots and glyph gone | Yes, the promise (5/6 smiled) | Yes |
| ONB-02 Her name | Deleted | — | — |
| ONB-03 His name + relationship | Moved out of first run. Relationship needs a new Settings home first (can't-delete) | — | — |
| ONB-04 His club | Yes, and now the last question. Plain question, search, 20 rows; the second club goes to Settings | Yes | Yes. "Toon" and "Magpies" already find Newcastle in search |
| ONB-05 Glossary "Premier League" | Entry point deleted; the sheet stays app-wide | — | Removing it removes the one thing 4/6 read as talking down |
| ONB-06 Meet his lot | Moved to the landing. Mood rows and table verdicts deleted (product rule; 2/2 Light could not decode "Pushing for Europe") | — | — |
| ONB-07 Meet the boss | Moved to the landing. The best line survives on the manager card | — | — |
| ONB-08 How it works | Deleted; card 2's sentence goes into the notification ask | — | — |
| ONB-09 Tier | Moved to Settings, default 2 (54 of 92 devices sit on it), check-in after the first match weekend | — | — |
| ONB-10/11/12 Notifications | Moved: one honest ask with the real fixture, at the match. Sheet deleted | On match day, yes: "the score on your lock screen tonight" is the thing | Yes, with "Live Activities" said in plain words |
| ONB-13/14 Calendar | Moved to the Calendar tab, with how to undo it | — | — |
| ONB-15 Calendar events | Yes; write home side first | — | — |
| ONB-16 Season primer | Deleted with its producer | — | — |
| ONB-17 ATT | Moved to the second session | — | — |
| ONB-18 Live Activities | Unchanged: already at the right moment | Yes: the lock-screen score was the best moment for D2 (and close second for D1) | Yes |
| **Landing (club tab, first run only)** | Yes, if TEAM fixes the Coming up truncation and adds a line to say above the fold | Yes: when, where, who's in charge, one thing to say | Mostly. "League Cup" is still unexplained there (L2 thought Carabao Cup and League Cup were two competitions) |

---

## 4. The ten verdicts that matter most (ranked)

1. **STO-03-05 (+ 03-01, 03-02, 03-06) Iterate/Delete.** The store sells the World Cup and promises "no tracking". 6/6 caught both, and it is the first thing she reads.
2. **STO-06-04 / STO-03-07 Iterate.** The privacy policy link does not resolve. Apple requires it.
3. **ONB-13-13 Iterate.** Setup lands once on the club tab, not on the feed. 6/6 said "not yet" at the feed; 4/6 said the club tab delivered.
4. **ONB-10-00 Move.** The notification ask moves to the match, with the real fixture: no fake "Chelsea at 15:00", no guilt line.
5. **ONB-17-00 Move.** ATT moves to the second session. 6/6 lost trust when it landed on the first screen.
6. **ONB-09-00 Move.** Tier moves to Settings. It changes 0 of 21 day-1 screens, and 4/6 could not say what it does.
7. **ONB-06-00 / ONB-07-00 Move.** Meet his lot and Meet the boss become the landing: the same facts, one screen, no extra taps. Mood rows are deleted.
8. **ONB-02-00 Delete.** Her name changes nothing she can see.
9. **ONB-08-00 Delete.** "How it works" is the wordiest step (94 words), and 5/6 skimmed or objected.
10. **ONB-13-00 Move + STO-02-06 Delete.** The calendar ask goes to where the fixtures are; 6/6 declined it on day 1, and the screenshot's "15" contradicts the app.

Also: **ONB-16 Delete** (unreachable primer and its daily producer), **ONB-11 Delete** (second ask), **STO-02-04 Delete** (T3-only screenshot).

## 5. Verdicts that need Anton

- **His name and relationship out of first run (ONB-03, Move).** Taste call: "Tom" gives warmth, and the most-laughed setup line uses it, but it costs a keyboard step before any value. Relationship must gain a Settings picker first.
  - Option B: keep one optional "Who's he?" screen (his name + Partner/Parent/Sibling/Friend). That is +1 screen and +1 typed field.
  - Usage settles it: the `relationship` common prop shows the non-partner share. If that share is material, keep the chips in setup.
- **ATT to the second session (ONB-17-00).** This trades IDFA match rate for trust. `activated` and SKAN still reach Meta. Add `permission_answered` first.
- **`.provisional` notifications at the end of setup.** This covers the worst week without a dialog. It is quieter than today, but it registers a token she never consented to with a dialog.
- **Landing on the club tab instead of the feed** for the first run only. This changes the product's front door on day 1.
- **The store listing is Anton's to edit.** The label must be reconciled before 2.4 is submitted. The description, keywords and screenshots can go now.
- Usage should settle:
  - step drop-off (all ONB step rows);
  - notification yes-rate, just-in-time vs today (needs `permission_answered`);
  - calendar opt-in (`onboarding_completed.calendar`, then the Calendar tab);
  - tier changes after the check-in card;
  - store copy (App Store Connect conversion; product page optimisation tests).

## Summary

1. 208 rows (STO 35, ONB 173): **Keep 61, Iterate 23, Move 53, Delete 71**. STO: Keep 12, Iterate 19, Delete 4. ONB: Keep 49, Iterate 4, Move 53, Delete 67.
2. Setup shrinks from 10 screens to 2 (Welcome, his club). It ends on the club tab, the page 4/6 said delivered, where the boss and the club facts already live.
3. To the worth-it moment: from about 620 words, 13–15 taps, 2 typed names and up to 3 system dialogs, down to about 110 words, 3 taps and none. That holds in both the match week and the worst week.
4. Every prompt moves to its payoff: notifications to the match (real fixture), calendar to the Calendar tab, ATT to the second session. Live Activities stay at kickoff.
5. The store page must stop selling the World Cup and "no tracking", and must fix the dead privacy link. 6/6 caught the contradiction, and it is the same trust loss the ATT sheet repeats.
