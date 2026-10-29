# UI seat, app council 2026-10-29

Commit 376d3f2, app 2.4 (18), Debug build on my own simulator `GD-council-ui` (iPhone 17 Pro, iOS 26.4, `SIMCTL_CHILD_TZ=Europe/London`, defaults checked empty before each run; deleted at the end). 86 screenshots plus contact sheets: `seats/ui-shots/` (`sheets/sheet*.png` default size, `sheets/ax*.png` AccessibilityXL). Word counts come from Vision OCR of each screenshot (`ui-shots/tools/ui-ocr-counts.tsv`), so they cover the first screenful only.

**States seen.** No live match today. Liverpool and Chelsea were inside the 24-hour After window after their League Cup tie on 28 Oct. Arsenal was in Before (Liverpool away, Sun). Newcastle had a match day today (Everton away, League Cup). I covered tiers 1, 2 and 3, one club and two clubs.

**Not seen, read in code only.** Settings and every sheet in it, the club switcher dropdown, the player card sheet, the glossary sheets, the live box, the Saturday Quiz (it is Thursday), offline. The reason: simctl cannot tap, the harness has no argument for these screens, and simulator-control access was declined. `-gdMatchdaySection after` does nothing, because `onChange(of: lastMatch?.fixtureId)` resets `picked` once the page loads (MatchdayView.swift:61,73). That is a harness bug.

**Light and dark.** The app forces `.preferredColorScheme(.dark)` (GoalDiggerApp.swift:16). The same four screens captured in system light and system dark differ by 0 pixels (PIL diff). So "light mode" does not exist, and nothing is broken by it. The only light-mode artefact is the light system keyboard on the dark onboarding screens.

## Findings

**1. HIGH. On match day the kickoff time is cut off, and Matchday never shows it.** CONFIRMED (team-new-t1.png, crop-new-comingup.png, matchday-new-t1.png).
- **Where:** TEAM-01-23, TEAM-01-24, MD-02-01. TeamPageView.swift:519-535.
- **What she sees:** Newcastle, tier 1, today, at the default text size. The Coming up card reads "Thu 29 Oct at 1…" and "League Cu…". The date row is `lineLimit(1)` and sits beside two chips; it only stacks at accessibility sizes. The Matchday tab opens on "Get to know Everton", with no time and no "tonight" anywhere on the first screen. The time does appear in full on Calendar, two taps away.
- **Fix:** stack the date row whenever a competition chip is present, and drop "Could go either way" to a second line. Add "Tonight, 19:45" as a line on the first Before card.

**2. HIGH. A tier 1 goal push lands on a screen that has no score.** SUSPECTED: code only, no live match to reproduce.
- **Where:** MD-09-00, MD-01-00. AppDelegate.swift:131-140, push-tiers.ts:70, TierGating.swift:20, LingoDeck.swift:194.
- **What happens:** goals go to every tier (`minTier 1`). A goal or kickoff push has a non-UUID `content_id`, so the tap sets `pendingOpenFeed` and she lands on her club's feed. The live box is the only in-app score, and it needs tier 2 or above. During the game Matchday stays on Before, which "keeps a game in progress Before", so the tab called Matchday shows prep cards while the match is on.
- **What she sees:** the buzz says Arsenal scored. She taps it and finds yesterday's story card.
- **Fix:** show the live box to every tier (score and minute only; the tier 2 prose can stay gated), or make Matchday's first card the live score while a game is in progress.

**3. MEDIUM. The Matchday › After line to say sits at the fold, and the verdict fails contrast.** CONFIRMED (matchday-liv.png, ax-matchday-after.png).
- **Where:** MD-07-01, MD-07-03, MD-07-04, MD-07-05. MatchdayView.swift:301-335.
- **Space:** the result card takes 82% of the screen to hold one title and three serif lines; most of it is empty rose. "Say this now" begins at y≈715 of 812 and runs under the floating tab bar. The line she came for is the last thing on the first screenful.
- **Contrast:** the verdict is white 13-pt Cormorant on hot rose, a ratio of 3.95:1. That is below the 4.5:1 AA minimum for small text.
- **At AccessibilityXL:** the score line itself truncates to "Liverpool 1-1 Ch…" (`lineLimit(1)`, `minimumScaleFactor(0.7)`).
- **Fix:** size the card to its content (about 45%) so the line sits above the fold. Use a two-line score at accessibility sizes. Use deep mauve ink, or 15-pt or larger weight, for the verdict.

**4. MEDIUM. At accessibility sizes the notifications banner covers the first card's headline.** CONFIRMED (ax-feed.png).
- **Where:** FEED-01-13, FEED-01-28. FeedView.swift:236-289.
- **What she sees:** the banner grows to about 250 pt and the card underneath does not move down. "arteta." is hidden behind it and only the tops of its letters show.
- **At the default size:** the banner is still 25 of the 89 words and about 18% of her first screen. It shows on day 1 as soon as she taps "I'll do this later". She has then been asked three times (ONB-10, the ONB-11 sheet, this banner) before seeing a single story.
- **Fix:** push the pager below the banner. Hold the banner back for 48 hours, or until the day of his first match.

**5. MEDIUM. Feed cards carry no date, so relative words go stale.** CONFIRMED (feed-new-t1.png, plus the SQL row).
- **Where:** FEED-01-25, FEED-01-28.
- **What she sees:** Newcastle's top card today reads "cup game tomorrow / league on monday". It was posted 28 Oct 08:07, and the game is tonight. Nothing on the immersive card says when it was written. The article view says "Yesterday", but only one tap later.
- **Fix:** put the FEED-06-09..12 timestamp in zone 1, next to the press hint.

**6. MEDIUM. Four of the five persona clubs have upscaled portraits.** CONFIRMED (asset scan, crop-spurs-ones.png).
- **Where:** TEAM-01-45, TEAM-01-37, MY-03-06, MD-07-08, MD-03-13.
- **The numbers:** 405 of 430 bundled portraits are under 420 px tall. At 280 pt on a @3x screen they need 840 px.

| Club | Portraits under 420 px |
|---|---|
| Arsenal | 2 of 22 |
| Newcastle | 21 of 22 |
| Spurs | 21 of 22 |
| Liverpool | 21 of 21 |
| Chelsea | 23 of 23 |

- **What she sees:** Solanke is 201 px tall, drawn about 4× past @3x. He looks soft at the edges, and the 1.45 pt/px cap shrinks him, which leaves about 60 pt of empty card above his head.
- **Fix:** the re-export in `docs/IMAGE_REEXPORT.md`, done club by club in persona order: Newcastle, Spurs, Liverpool, Chelsea.

**7. MEDIUM. At accessibility sizes the Table breaks numbers.** CONFIRMED (ax-team-table.png).
- **Where:** TEAM-04-04, TEAM-04-05.
- **What she sees:** "GD" wraps to "G/D" and "PTS" to "PT/S". Goal difference "+16" breaks across two lines as "+1 / 6". Team names truncate to "Manches…", and "Champions Le…" is cut off as well.
- **Fix:** give the number columns `fixedSize()`, and drop the P column at accessibility sizes.

**8. LOW. Words break mid-word at accessibility sizes.** CONFIRMED (ax-lingo-pr.png).
- **Where:** MY-08-08, MD-05-00.
- **What she sees:** the two side-by-side Overheard options break inside a word ("defend / er"), and the second option runs under the tab bar.
- **Fix:** stack the two options vertically when `isAccessibilitySize`, the same pattern TeamPageView already uses.

**9. LOW. At AccessibilityXL, onboarding hides the explanations below the fold.** CONFIRMED (ax-onb-7.png, ax-onb-8.png).
- **Where:** ONB-10-05, ONB-10-06, ONB-10-08, ONB-09.
- **What she sees:** on step 8 the title fills the screen. The example push, the live score and the Live Activities line are all below the fold, with no cue to scroll. On step 7 only the first tier option is visible, half-hidden behind the pinned button.
- **Fix:** shrink the title at accessibility sizes, using `.dynamicTypeSize(...accessibility1)`.

**10. LOW. Tap targets under 44 pt.** CONFIRMED in code.

| Census id | Element | Size | Location |
|---|---|---|---|
| ONB-03-05..08 | Relationship chips | about 32 pt tall | HisNameView.swift:107 |
| TEAM-06-01 | Player card close | 28×28, no VoiceOver label | PlayerCardView.swift:112 |
| MY-12-04 | Safe/Bold explainer dismiss | 28×28 | SayThisView.swift:216 |
| FEED-06-27 | Talking-point copy | 32×32 | ShareableCardRenderer.swift:30 |
| FEED-06-28 | Talking-point share | 32×32 | ContentDetailView.swift:521 |
| MD-07-12 | Scorer chevrons | 28×40 | MatchdayView.swift:516 |
| MD-03-02 | Lesson close | 36×36 | LingoView.swift:1482 |

Every other icon-only button I found has a VoiceOver label: gear, share card, listen, star, clear search, close, scorer pager.
- **Fix:** add `.frame(minWidth:44, minHeight:44).contentShape(Rectangle())` to each, and `accessibilityLabel("Close")` to the player card close button.

**11. LOW. The club page error copy lowercases his name.** CONFIRMED in code (the output is deterministic).
- **Where:** TEAM-01-06. TeamPageView.swift:1600 and 1634.
- **What she sees:** `hisNameOrHis.lowercased()` renders "Couldn't load tom's team right now." and "We're getting tom's team ready".
- **Fix:** use `appState.namePossessive` and do not lowercase it.

**12. LOW. Noise on day 1.** CONFIRMED (feed-ars-t2.png).
- **Unread badge (FEED-01-12):** reads "9+" on the very first launch, because everything is unread. A count of things she has never seen tells her nothing.
- **Scroll hint (FEED-01-42):** the ⌄⌄ is drawn under the floating tab bar, and shows between "Matchday" and "Arsenal".
- **Rotating label (FEED-01-31 and FEED-01-33):** zone 2 is labelled "Your move:" on card 1 and "Say this:" on card 2, two names for the same thing.
- **Footer name (TEAM-01-26):** "Pre game talk ›", with no hyphen, opens an in-place preview, while Matchday's section is called "Pre-game". ARCHITECTURE.md §6 still says "Pre-game ›" opens Matchday. That is stale.

**13. MEDIUM. Three system prompts stand in the first session.** CONFIRMED in code. App Tracking Transparency (ATT) is the permission prompt for ad tracking.
- **Where:** ONB-12, ONB-14, ONB-17. GoalDiggerApp.swift:433.
- **What she sees:** the notifications prompt, then the calendar prompt, then ATT. ATT appears 1.5 s after the tabs first show, so it lands on top of the first card, the worth-it moment.
- **Fix:** ask ATT at the start of the second session, or after she has used her first line.

### Taps from launch to the first line she could say

| Path | Taps to the first usable line | What she gets there |
|---|---|---|
| Day 1, fresh install | 5 taps and 2 typed names | ONB-06 "Meet his lot": three facts about his club. These are facts, not a line to say. |
| Day 1, to the first "Ask him: …" line | 11 to 14 taps and 2 typed names | The 10 onboarding steps, plus up to 3 system prompts. The line is on Feed card 1's zone 2 with no further tap. |
| Returning user | 0 taps | Feed card 1, when notifications are on |
| After a match | 1 tap to the Matchday tab | The line is under the tab bar (finding 3) |
| Full-time push tap | 0 taps to After | Same position as above |

### Elements and words per screen (first screenful)

Interactive counts exclude the 4-tab bar. Words come from OCR.

| Screen | Interactive | Text blocks | Words |
|---|---|---|---|
| ONB-01 Welcome | 1 | 4 | 13 |
| ONB-03 His name | 7 | 8 | 40 |
| ONB-04 Club | 22 | 10 | 31 |
| ONB-06 Meet his lot | 2 | 18 | 83 |
| ONB-07 Boss | 2 | 10 | 56 |
| ONB-08 How it works | 2 | 18 | **93** |
| ONB-09 Tier | 4 | 12 | 46 |
| ONB-10 Notifications | 3 | 13 | 45 |
| ONB-13 Calendar | 3 | 6 | 27 |
| FEED-01 Feed, banner on | 7 | 19 | **89** |
| FEED-06 Article | 7 | 20 | 87 |
| FEED-06 Things to say | 9 | 16 | 91 |
| TEAM-01 Info | 7 | 15 | 39 (≈526 down the page) |
| TEAM-02 Ones to know open | 4 | 19 | 87 |
| TEAM-04 Table | 3 | 55 | 61 |
| MD-07 After | 3 | 9 | 48 |
| MD-02 Before | 3 | 5 | 30 |
| MY-02 Quiz packs | 10 | 21 | 69 |
| MY-07 Lingo | 8 | 16 | 31 |
| MY-11 Say This | 8 | 19 | 55 |
| MY-12 Say This revealed | 8 | 25 | 88 |

Nothing exceeds about 95 words in a screenful. The overload is depth, not density: the club Info tab runs 10 or more cards, about 526 words in the staging text.

## Verdict proposals (UI evidence only; content verdicts are for other seats)

| id | Verdict | How / where, and why |
|---|---|---|
| ONB-01-00 | Keep | 13 words, 1 tap, and it states the promise. |
| ONB-02-00 | Move | Into ONB-03 as one "you and him" screen. That removes a step and a keyboard round before any value. |
| ONB-03-00 | Iterate | Chips to 44 pt (F10). |
| ONB-04-00 | Keep | The only required answer, and it visibly changes everything after it. |
| ONB-05-00 | Keep | Opt-in, opens on the underlined word. |
| ONB-06-00 | Keep | The first worth-it moment, at tap 5. |
| ONB-07-00 | Move | Into ONB-06 as its fourth card. 56 words, a whole tap, and no line to say. |
| ONB-08-00 | Delete | The wordiest step (93 words) explains features she is about to see. The push part is already shown by ONB-10. |
| ONB-09-00 | Move | Into Settings, with tier 2 by default (SET-07 stays the way to change it). At AX the options are hidden (F9). |
| ONB-10-00 | Iterate | Keep the honest preview. Fix it at AX (F9). |
| ONB-11-00 | Delete | A second ask right after "later", with the feed banner on top of it (F4). |
| ONB-12-00 | Keep | Apple's prompt. Cannot be deleted. |
| ONB-13-00 / ONB-14-00 | Move | To the Calendar tab on the club page, or the day before his first match. |
| ONB-15-00 | Keep | Outside the app UI. |
| ONB-16-00 | Delete | Unreachable without the harness. Delete the producer `gd-season-state` with it (dependency check). |
| ONB-17-00 | Move | To the second session (F13). The ATT string cannot be deleted while Meta runs. |
| ONB-18-00 | Keep | System prompt. |
| FEED-01-00 | Iterate | F4, F5, F12. |
| FEED-01-12 | Delete | A "9+" on day 1 carries no information. |
| FEED-01-13 | Iterate | Push the pager down, delay to 48 h or his first match day (F4). |
| FEED-01-31 / FEED-01-33 | Iterate | One label on every card. |
| FEED-01-42 | Delete | Drawn under the tab bar. The pager is self-evident. |
| FEED-02-00 | Keep | Error, empty and loading states are all copy plus a retry. Nothing dead-ends. |
| FEED-03-00 | Keep (provisional) | Not seen live. |
| FEED-04-00 | Keep | 48 pt rows, dismiss on outside tap (code). The only way to switch clubs on Feed. |
| FEED-05-00 | Keep (UI) | Not seen. Content seat decides. |
| FEED-06-00 | Iterate | Copy and share buttons to 44 pt. |
| FEED-07-00 / FEED-08-00 | Keep | |
| TEAM-01-00 | Iterate | F1 truncation, F11 copy. Too deep; the content seat decides which cards go. |
| TEAM-01-26 | Iterate | Rename to "The preview ›" (F12). |
| TEAM-01-45 / TEAM-01-37 | Iterate | Re-export (F6). |
| TEAM-02-00 | Iterate | "Tap to close" sits under the tab bar (team-ones-open.png). Add bottom padding. |
| TEAM-03-00 | Keep | Full times, a clear legend. |
| TEAM-04-00 | Iterate | AX columns (F7). |
| TEAM-05-00 | Keep | |
| TEAM-06-00 | Iterate | Close button 44 pt plus label (F10). |
| MD-01-00 | Iterate | A live state, and kickoff time on Before (F1, F2). |
| MD-02-00 | Iterate | Time on the first card. The cards are 90% of the screen for 30 words; shrink them. |
| MD-03-00 / MD-04-00 / MD-06-00 / MD-08-00 | Keep | No physical defect seen. |
| MD-05-00 | Iterate | Stack the options at AX (F8). |
| MD-07-00 | Iterate | Card to about 45%, line above the fold, contrast (F3). |
| MD-07-12 | Iterate | Chevrons to 44 pt. |
| MD-09-00 | Move | Score and minute to every tier (F2). |
| MY-01..07, MY-09..11, MY-13, MY-14, MY-16 | Keep | Labelled, 44 pt or larger, scales at AX ("Say This" becomes "Lines", which is fine). |
| MY-08-00 | Iterate | F8. |
| MY-12-00 | Iterate | Dismiss to 44 pt. |
| MY-15-00 | No UI verdict | Not reached. It contradicts "no streaks by design" (ARCHITECTURE §6). Editor's call. |
| SET-01-00 | Keep | Labelled "Settings". The only way into Settings, so it cannot be deleted. |
| SET-02-00, SET-03..05, SET-07 | Keep | The only way to change name, club and mode. Cannot be deleted. Not seen live. |
| SET-06-00 | Keep | The only way to change a followed country (the `hisCountryRow` lesson). Cannot be deleted while country follows exist. |
| SET-08..12 | Keep | Data-safety confirmations. SET-10 and SET-11 are Apple-required. |

Census rows not named here: I found no UI defect, and their verdict rests on content. I did not check every one of the 960 rows on screen.

## What holds up

- **No dead ends.** Every loading state has a skeleton. Feed, article and club page each have an error state with "Try again". The empty feed falls back to an insider card at tier 2 and above, and the live box still shows over an empty feed.
- **Push routing.** Article pushes open the detail view. `myturn-prep` opens Before and `live-ft-` opens After, for the first club. A push about the second club opens that club's feed, never Football. Settings closes on a push tap (`pushTapTick`).
- **VoiceOver.** Every icon-only control I found is labelled, except the player card close button.
- **Accessibility layouts.** My Turn, Say This, Lingo search and the club cards adapt properly at AccessibilityXL. The immersive card caps itself at xxxLarge on purpose.
- **Default size.** Nothing overlaps at the default size apart from F1. No text sits over a photo: portraits and stickers always have their own space.
- **Onboarding step 8** shows the real push copy, in her club's name, against a made-up opponent (Chelsea, or Arsenal for Chelsea fans).

## Summary
1. The two HIGH findings both concern the match itself. On match day the kickoff time is cut off ("Thu 29 Oct at 1…"), and Matchday never shows it. A tier 1 goal push opens a screen with no score.
2. Matchday › After spends 82% of the screen on one sentence, and pushes the line she came for under the tab bar. Its verdict text fails contrast (3.95:1).
3. AccessibilityXL breaks the feed (the banner covers the headline), the After score, the Table numbers, the Overheard options and the onboarding previews.
4. 405 of 430 portraits are upscaled. Only Arsenal is sharp.
5. The first line to say arrives after 11 to 14 taps and 3 system prompts. Merging the name steps, Meet the boss and How it works, moving the tier, calendar and ATT asks, and deleting the second notification ask would cut that to about 7.
