---
name: app-council
description: Give every line, element and page of GoalDigger a verdict — Keep, Iterate (how and why), Move (where) or Delete — from onboarding to the last option in Settings, the lock screen and the store page. Skeptical by default; nothing stays without proof. Seven user personas across the three tiers plus him, six expert seats and an editor, all held to an evidence standard and verified before Anton decides. Run before a TestFlight or App Store build, after a big delivery, or when Anton asks for "the council".
---

# The app council

## The goal every verdict serves

She understands the app, is never overwhelmed, is informed, and can sit in a
football setting and feel smart instead of dumb.

Every element in the app is judged against those four, and against one
question: **what moment in her week does this serve?** "It is interesting" is
not a moment (the same bar `PUSH_RULES.md` sets for a push).

**The first session matters most.** That is the store page, onboarding and
the first minutes after it. Before she closes the app the first time, she
must have felt *this was worth it*: she got something she could use, about
his club, this week. Every onboarding step and every permission prompt stands
between her and that moment, so each one has to prove it is worth the delay.
This includes the worst first day, when his club does not play for ten days.
The council measures it as the **worth-it moment** (staging step 7, panel
step 2, and its own editor).

## The verdicts

| Verdict | Means | Must state |
|---|---|---|
| **Keep** | Earns its place as it is | Which goal it serves, which moment, and the evidence (panel count, usage, an expert finding) |
| **Iterate** | Belongs, but not like this | What changes, in a sentence a builder could act on, and why: the persona quote or finding that shows it |
| **Move** | Right thing, wrong place or time | Where it goes (another screen, behind a tap, only on match day, a lower tier) and what that removes from the current place |
| **Delete** | Not worth her attention | What is lost, and the dependency check (§5) showing nothing breaks |

**The default is Delete.** An element that nobody makes a case for is
deleted. Merge counts as Move: when the same fact appears in three places,
two of them are moved into the third.

Some things cannot be deleted, whatever the panel says. Check this list
before writing Delete, and Iterate them instead:
- Apple's rules: delete my data, the privacy policy link, the notification and
  ATT permission strings, a way to restore anything she paid for.
- The only way to change something she set. On 2026-09-23 `hisCountryRow` looked
  dead and was the only way to change a followed country.
- Anything the backend still produces for a living app version. Delete the
  producer in the same change, or Move instead.

## How it runs

```
0 Census ─► 1 Staging ─► 2 Panel (7) ┐
                         3 Experts (6)├─► 4 Editors ─► 5 Dependency check ─► 6 Verify + board
```

Every seat is a fresh agent that knows only its brief. You (the orchestrator)
build the census and staging, launch the seats in parallel, verify, and
publish.

### Rules for every seat

- **Read-only.** SELECT-only SQL via `./scripts/sql.sh -c` / `-f`. No commits,
  deploys or writes to the main checkout. A seat that needs a simulator
  creates its own (`xcrun simctl create GD-council-<seat> "iPhone 17 Pro"`), uses
  its own `-derivedDataPath`, and deletes it afterwards. Never target `booted`.
- **Never read** `backend/.env*`, `ios/GoalDigger/Configuration.xcconfig`,
  `.claude/worktrees/**`.
- **Evidence or it did not happen.** A finding gives: census id(s), severity
  (HIGH / MEDIUM / LOW), file:line or the SQL row, what she would see, how it
  was checked, the minimal fix, and CONFIRMED (reproduced on live data, a real
  screen or running code) or SUSPECTED (read in code only).
- End with **"What holds up"**: what the seat checked and found sound.
- English, about 1500 words. The personas are exempt from the word cap.

## 0. The census: the list of things that get a verdict

Nothing gets a verdict unless it is in the census, and nothing in the census
leaves without one. Build it fresh each run in `$S/census.csv` (`$S` =
`<scratchpad>/council-<YYYY-MM-DD>/`). One row per element:

`id, chapter, screen, element, kind, text, states, tiers, source, producer`

- **id**: `<CHAPTER>-<screen#>-<element#>`, e.g. `ONB-04-02`.
- **kind**: screen, section, card, line (one string), control (button, toggle,
  picker, menu, sheet, alert, each option in a picker), image, empty / loading
  / error state, push, Live Activity state, permission prompt.
- **text**: the exact words. For generated content, the template plus 3 real
  instances from live rows.
- **states**: which states show it (see staging).
- **source**: file:line, or the table and key.
- **producer**: what makes it (routine, Edge Function, a json pack, hardcoded).
  A Delete has to remove this too.

Chapters, in the order she meets them. Walk the code for each, never a list
from memory:

| Chapter | Where to look |
|---|---|
| `STO` store page | App Store listing text and screenshots (`goaldigger-marketing`), the privacy label |
| `ONB` onboarding | `Views/Onboarding/` (every step in `OnboardingFlow.Step`), the season primer, the system permission prompts and their `Info.plist` strings |
| `FEED` feed and article | `Views/Feed/`, `Views/Detail/`, every `content_items.type`, every immersive card variant, the club switcher, Everyone's talking |
| `TEAM` club page | `Views/Team/`, every `team_pages.content.cards` key, player cards, `Views/Player/` |
| `MD` matchday | `Views/Matchday/` (Before, live, After), `LiveMatchCard` |
| `MY` My Turn | `Views/MyTurn/`, every pack in `Resources/MyTurn/*.json`, `glossary.json` |
| `LOCK` lock screen | every push kind in `PUSH_RULES.md` §1 with its copy, every Live Activity state (`LiveActivity/`) |
| `SET` settings | `Views/Settings/`: every section, row, sheet, picker option, toggle, alert and the About texts |

Static copy is one row per string. Generated content is one row per template
or card type, not per instance.

**Coverage gate:** at the end, `rows with a verdict == rows in the census`.
List any row without one in the report as a failure of the run.

## 1. Staging

1. **Build** (CLAUDE.md command) with `-derivedDataPath $S/dd` on a
   council-owned simulator set to `Europe/London`. Before trusting it, check that
   `simctl spawn <udid> defaults read com.goaldigger.app` is empty (memory
   `project_sim_verification`).
2. **The state matrix.** The app is a different app on match day. Capture
   every screen in each state you can reach, and write down which ones you
   could not:
   - The week: no match this week, the day before a match, match day before
     kickoff, live, after full time, an international break, a cup tie.
   - Her: day 1 (fresh onboarding, empty history) or week 6.
   - Following: one club, two clubs (`-gdPresetTeam2`), a club plus a
     country.
   - Tier: 1, 2 or 3 (`-gdTier`).

   Use `-gdPresetTeam <club> -gdTier <n> -gdResetMyTurn
   --terminate-running-process` and the screen arguments in
   `project_sim_verification` (`-gdTab`, `-gdFeedIndex`, `-gdOpenItem`,
   `-gdTeamTab`, `-gdMyTurnModule`, `-gdOnboardingStep`, `-gdSeasonPrimer`).
   Read the tab numbers from the root `TabView` first. A state that cannot be
   reached from launch arguments is either added to the harness or listed as
   not seen. Live states come from a real live match or the stored Live
   Activity payloads, never from a mock that looks right.
3. **Below the fold.** simctl cannot scroll. For every screen, also write
   `$S/text/<screen>.txt`: everything on the screen top to bottom, taken from the
   census, with a marker where the first screenful ends. Personas get both
   the image and the text.
4. **Her lock screen, per persona.** Use the last 7 days of
   `pipeline_health` (`stage='apns_send'`), joined to `content_items`
   (`push_title`, `push_text`) for `item:*` targets. For `live_*` kinds, write
   the copy from the fixture and `_shared/goal-push.ts`. Filter by the persona's
   tier using `PUSH_RULES.md` §1. Write a timeline in London time to
   `$S/pushes/<persona>.txt`. If the club had no match that week, add the week
   before.
5. **Usage.** `./scripts/tracking-digest.sh 28`, plus `analytics_events` per
   screen and element. Until build 2.4 (18) has run for about three weeks this
   is empty (0 rows on 2026-10-29). Say so, and treat every verdict as
   provisional until a later run confirms it against usage.
6. Record the commit and build number in `$S/README.txt`.

   Traps found on 2026-10-29:
   - **Tracking prompt.** One launch without a preset raises it, and it then survives relaunch, reboot and reinstall. Only `simctl erase` clears it. OCR each shot and retry; the scripts are in `docs/council/2026-10-29/staging-notes.md`.
   - **Preset values persist in stored settings.** A country-only run needs an erased simulator.
   - **`-gdMatchdaySection` does nothing,** because `MatchdayView.swift:61` resets it. Use `-gdNow` instead. `-gdNow` moves only Matchday and My Turn, never the feed or the club page, so it cannot stage the worst week.
   - **The onboarding preset sets Sophie, Tom and tier 2.** Do not judge "pre-selected" from those captures.
7. **The first session, end to end.** On a fresh simulator, uninstalled and
   with defaults empty, capture every step from launch to the first screen
   after onboarding, then the first three screens she is most likely to tap.
   Do this twice: once in a week when his club plays within 3 days, and once
   in the worst week (no match for 10 days or more, or an international
   break). Count, into `$S/first-session.txt`:
   - the steps, taps, words read and permission prompts before the first
     thing she can use;
   - what that first thing is;
   - which onboarding answers (names, club, tier) visibly change what she sees
     straight after. An answer that changes nothing is a question we did not
     need to ask.

## 2. The panel

Seven fresh agents, one per persona, launched in parallel. Each one gets
**only** her persona, the staged screens and text for her club, tier and
states, and her push timeline. Never mention the other personas, our intent,
or what we think is good. She has never seen the app before.

| Id | Tier | Knows | His club | Who she is |
|---|---|---|---|---|
| L1 | Light | nothing | Newcastle | 34. Downloaded it because he laughed at her. Expects to delete it within a week. |
| L2 | Light | nothing | Arsenal | 29. Warm about it. Doesn't want to watch, just never wants to be the one who didn't know. |
| M1 | Match-fit | a bit | Spurs | 31. Watches the big games with him and follows the story more than the football. |
| M2 | Match-fit | a bit | Liverpool | 26. Six months in; meeting his mates at the pub on Saturday. |
| D1 | Deep | a lot | Arsenal | 33. Grew up with a football dad. She catches every wrong fact and every line that talks down to her. |
| D2 | Deep | a lot | Chelsea | 28. Competitive. Wants the score before he looks up, and a line that wins the argument. |
| H | (him) | everything | Arsenal | 32, season ticket. Sees only what she would say to him: `Say:` lines, sayings, verdicts, quiz answers, Lingo. Would it land, or would he wince? Is any fact wrong? |

Give each persona a folder of COPIES (store text, first-session shots, her club's screens, the screen text, her push week) and forbid every other path. Paths into the shared workspace let her read the seats' intent.

Keep the club and tier spread close to production (`device_tokens` grouped
by `team_id`, `tier`). Most of it is Arsenal.

She walks the app **in the order of the census chapters**, the way she would
meet it, and does not go back.

1. **First look** (the store page, then the first feed screen): in one
   sentence, what is this app?
2. **The first session**, in the staged first-session order, with both the
   match week and the worst week. After every onboarding step: would she
   carry on, or is this where she closes the app? At the first screen after
   onboarding, before seeing anything else:
   - "Was that worth it?" yes, not yet, or no.
   - What did she get?
   - Which onboarding step did she not understand the point of?
   - The moment she first thought "oh, that's useful", or that it never came.
3. **Screen by screen.** For every element, a line: `id | understood? (y/n) |
   would I miss it if it were gone? (y/n) | felt smart / neutral / dumb |
   note`. At the end of each screen: too much / about right / too little, and
   the one thing she would remove first.
4. **Words she did not know**: every football term she met, and whether the
   app explained it where she met it.
5. **Her week** (the push timeline): which pushes were worth the buzz, which
   annoyed her, which would have made her turn notifications off.
6. **The test.** Could she say one thing from the app at the pub on Saturday,
   or to him, without feeling dumb? Quote it. Then keep the app: yes / maybe /
   no, and why.
7. Her best moment and her worst, one element each.

The panel is AI personas, not real women, and can share our blind spots. Say
so in the report. Count, don't quote: "5 of 7 would not miss it" is evidence,
one persona's taste is not. Physical findings (unreadable, cut off, dead end)
outweigh opinions.

## 3. The expert seats

Each seat gets the rules, the commit, the census and its brief. Each starts by
reading `ARCHITECTURE.md` and `STATUS.md`. Besides findings, each seat **proposes
a verdict for every census row in its field**, and names any row that cannot be
deleted from where it sits, and why.

**UI.** Owns its own simulator. Covers every staged screen at the default
size and at Dynamic Type AccessibilityXL (the exact constant is in
`project_sim_verification`), in light and in dark mode. Checks:
- text that is cut off or overlaps;
- images upscaled past @3x (`docs/IMAGE_REEXPORT.md`) and text over photos;
- tap targets under 44 pt, and icon-only buttons without a VoiceOver label;
- dead ends and where every push tap lands (`AppDelegate`);
- empty, loading, error and offline states;
- elements per screen and words per screen, so "overwhelming" has a number;
- taps from opening the app to the first line she could say.

**Tracking.** Reads `docs/TRACKING_PLAN.md` and runs
`./scripts/verify-tracking-plan.sh` and `./scripts/tracking-digest.sh 28`.
Checks:
- that every event fires from the code path it claims, and never twice;
- that `push_opened.kind` matches what the senders send;
- the Meta events (`AttributionService`) against our own `analytics_events`;
- that production stays apart from debug traffic;
- consent and ATT handling against `docs/PRIVACY_POLICY_DRAFT.md`.

It also lists the census rows that **no event can tell us about**. That list
is how we know which verdicts usage can never settle.

**Data.** Holds every fact she can see to `DATA_SOURCES.md`, using live rows:
`team_pages.content` for the persona clubs, `content_items` from the last 14
days, and `match_status_state`. Finds:
- a fact resting on a feed marked NOT trusted;
- a missing value shown as 0;
- a wrong season or competition label;
- two surfaces that disagree about the same match (push, card, After);
- the same fact shown in more than one place, which is a Move candidate.

**Connection.** The path from the feed to her lock screen. Runs
`./scripts/db-health.sh`, `./scripts/verify-push-rules.sh`,
`./scripts/verify-push-eligible.sh` and `./scripts/verify-cron-auth.sh`. Checks:
- `cron.job_run_details` for failures and gaps over 7 days;
- `apns_send` failures and invalid tokens;
- Live Activity priority-10 sends per match;
- API-Football calls against the daily cap;
- pg_net `_http_response` bloat (`project_db_maintenance`);
- what the app shows offline and on a slow network.

**Security.** Runs `db-health.sh` section 7 plus `has_function_privilege` and
`has_table_privilege` for anon on every public function and table outside the
app's four RPCs (`register_device_token`, `register_la_token`, `save_match_calls`, `log_events`). Checks:
- RLS on every table the anon key can reach;
- Edge Functions deployed `--no-verify-jwt` that do not check the cron key;
- secrets in the bundle or in git history (`scripts/pre-commit-secret-scan.sh`);
- leftover worktrees;
- public endpoints that take input without validating it.

It reads `SECURITY_PROBE_2026-10-07.md` and `CHANGELOG_SECURITY.md` first, and
re-reports nothing they list as fixed unless it has regressed.

**Bugs.** Correctness of everything since the last council (the date of the
newest `docs/council/` report, or 21 days). Runs
`deno test -A backend/supabase/functions/` and the iOS build. Feeds real strings
from live rows through the shipped functions, because hand-picked fixtures are
how the 2026-09-09 defects got past the suites. Re-checks open items in
`AUDIT_FINDINGS.md` and the newest `QA_*` and `BUG_AUDIT_*` reports.

**Stale data.** Runs the `stale-data-audit` skill in **report-only mode**:
every section, nothing fixed. Gives census ids for every stale surface.

## 4. The editors

One editor per group of chapters, so each editor can hold its rows in mind:
`FIRST` (STO, ONB, and the first-session screens from staging step 7),
`FEED+LOCK`, `TEAM+MD`, `MY+SET`. Each editor gets its census rows, the
seven panel transcripts and the six expert reports, and nothing else.

The editor is the skeptic. For every row it writes one verdict, following the
table at the top, with the evidence. It starts from Delete and moves off it
only when the evidence makes the case. It also judges at screen level:
- Does the screen still make sense with these verdicts applied?
- Is the first screenful the one thing she came for?
- Would L1, who knows nothing, get through it without feeling stupid?

The `FIRST` editor is the strictest. It goes in assuming onboarding should
be as short as the app can survive, and it decides:
- every step: Keep, Delete, or Move (asked later, when it is needed, or
  inferred);
- every permission prompt: asked now, or asked at the moment it pays off (the
  notification prompt just before her first match, for example);
- what the first screen after onboarding should be in the match week and in
  the worst week, so it lands on the worth-it moment.

It returns a proposed first session as an ordered list of screens, with the
step count and the time to the worth-it moment before and after.

Output: `$S/verdicts-<chapters>.csv` with
`id, verdict, how (Iterate) / where (Move), why, evidence, confidence`.

## 5. The dependency check

One agent takes every Delete and Move and proves nothing breaks. For each
row it checks, with the evidence:
- what reads it: grep the repo, `pg_proc`, `cron.job`, the routines repo
  (`anton-tech43/goaldigger-routines`), and old app versions still in use;
- what produces it: a Delete removes the producer as well, and routine runs
  saved count as a benefit;
- whether it is on the can't-delete list above.

A row that fails this check becomes Iterate or Move, with the reason.

## 6. Verify, then hand it to Anton

1. **Verify every CONFIRMED finding yourself** before it counts as
   confirmed. Seats have been wrong (2026-09-09: two of the confirmed findings
   did not hold). Downgrade what you cannot reproduce to SUSPECTED.
2. Check the coverage gate.
3. Write `docs/council/COUNCIL_<YYYY-MM-DD>.md`:
   - Header: commit, build, date, the states seen and not seen, and the usage
     data available.
   - **The first session**: what she meets today against what the verdicts
     propose, the steps and time to the worth-it moment, and the panel's
     worth-it votes, in both the match week and the worst week. This section
     comes first.
   - **The app in one page**: the screens as they would look after the
     verdicts, chapter by chapter, and what she meets on day 1.
   - **Verdicts**: one table per chapter, sorted Delete, Move, Iterate, Keep.
   - **The panel**: keep, maybe or delete per persona, the lines they would
     say, the words they did not know, counted themes.
   - **Findings** from the experts, ranked HIGH to LOW.
   - **What holds up.**
   - **Decisions for Anton**: taste, trade-offs and cost.
4. Publish a **decision board** (the 2026-10-29 build script and template are in that run's scratchpad `board/`; the board itself is at https://claude.ai/artifact/Mz1QxUvht2wDBkQUiK2KQi) as an Artifact with a database (load
   `artifact-capabilities`): one row per verdict, where Anton marks accept,
   reject or change, with a comment. The carousel feedback board is the
   precedent. Send him the link and a summary of a few sentences, in his
   language.
5. Fixing is a separate step, and it builds only verdicts Anton accepted on
   the board. Batch them by screen, so one screen changes once. Fixers follow
   the red-team pattern: their own worktree from the feature branch, one commit
   each, cherry-picked after review. After the batch ships, rerun the panel on
   the changed chapters only and compare it with this run.
