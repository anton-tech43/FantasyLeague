---
name: app-council
description: Judge the whole GoalDigger app from eight standing perspectives at once — the women who use it (one persona per knowledge level across the three tiers, plus him), UI, tracking, data, connection, security, bugs and stale data. Each seat is a fresh read-only agent held to an evidence standard; findings are verified before anyone acts on them. Run before every TestFlight or App Store build, after a big delivery, or when Anton asks for "the council".
---

# The app council

One review, eight seats, one ranked report. Each seat is a fresh agent that
knows only its brief, so it judges from that perspective and nothing else.
The orchestrator (you) stages the inputs, launches the seats in parallel,
verifies every CONFIRMED finding yourself, and writes the report.

Related methods this generalises: the red-team pass (memory
`feedback_redteam_pass`) and the blind ad persona panel (memory
`feedback_ad_persona_panel`). Seat 1 is that panel pointed at the app.

## Rules for every seat

- **Read-only.** SELECT-only SQL via `./scripts/sql.sh -c` / `-f`. No commits, no
  deploys, no writes to the main checkout. A seat that needs a simulator creates
  its own (`xcrun simctl create GD-council-<seat> "iPhone 17 Pro"`), uses its own
  `-derivedDataPath`, and deletes the simulator afterwards. Never target `booted`.
- **Never read** `backend/.env*`, `ios/GoalDigger/Configuration.xcconfig`,
  `.claude/worktrees/**`.
- **Evidence or it did not happen.** Every finding gives: severity
  (HIGH / MEDIUM / LOW), file:line or the SQL row, the failure as she would see
  it, how it was checked, the minimal fix, and CONFIRMED (reproduced on live
  data, a real screen or running code) or SUSPECTED (read in code only).
- End with **"What holds up"**: things the seat checked and found sound, so
  the report shows coverage and not only defects.
- Cap at about 1500 words. Write in English.

## 0. Stage the inputs (before any seat runs)

Work in `$S = <scratchpad>/council-<YYYY-MM-DD>/`.

1. **Build** the app for the simulator (CLAUDE.md command) with
   `-derivedDataPath $S/dd`, on a council-owned simulator set to
   `Europe/London`. Check `simctl spawn <udid> defaults read com.goaldigger.app`
   is empty first (memory `project_sim_verification`).
2. **Screens per persona.** For each persona's club and tier, launch with
   `-gdPresetTeam <club> -gdTier <1|2|3> -gdResetMyTurn --terminate-running-process`
   and capture into `$S/screens/<persona>/`: feed (`-gdTab 0`), the first three
   feed cards (`-gdFeedIndex 0..2`), one card's detail (`-gdOpenItem <uuid>`),
   team page plus calendar and table (`-gdTeamTab`), Matchday (Before and After),
   My Turn's three modules (`-gdMyTurnModule quiz|lingo|saythis`), and onboarding
   (`-gdOnboardingStep`). Name the files after the screen, not after the persona.
   The tab numbers move between builds, so read them from the app's root
   `TabView` first.
3. **Her lock screen this week, per persona.** From
   `pipeline_health` (`stage='apns_send'`, last 7 days, `target` names the kind
   and club) joined to `content_items` (`push_title`, `push_text`) for `item:*`
   targets. For `live_*` kinds, write what the push said from the fixture and
   the copy in `_shared/goal-push.ts`. Filter by the persona's tier using the
   §1 table in `PUSH_RULES.md`. Write it as a plain timeline in
   `$S/pushes/<persona>.txt` (day, time in London, title, body). If the club
   had no match that week, say so and use the previous week as well.
4. Record the commit and the build number in `$S/README.txt`.

## 1. Users: the panel

Seven fresh agents, one per persona, launched in parallel. Each gets **only**
its persona, its own screens folder and its own push timeline. Never mention
the other personas, our intent or what we think is good. They have never seen
the app before.

| Id | Tier | Knows | Club (his) | Who she is |
|---|---|---|---|---|
| L1 | Light | nothing | Newcastle | 34. Downloaded it because he laughed at her. Expects to delete it within a week. |
| L2 | Light | nothing | Arsenal | 29. Warm about it. Does not want to watch, just never wants to be the one who didn't know. |
| M1 | Match-fit | a bit | Spurs | 31. Watches the big games with him, follows the story more than the football. |
| M2 | Match-fit | a bit | Liverpool | 26. Six months into the relationship, meeting his mates at the pub on Saturday. |
| D1 | Deep | a lot | Arsenal | 33. Grew up with a football dad. She will catch every wrong fact and every line that talks down to her. |
| D2 | Deep | a lot | Chelsea | 28. Competitive. Wants the score before he looks up, and a line that wins the argument. |
| H | (him) | everything | Arsenal | 32, season ticket. Sees only the lines she would say to him (`Say:` lines, sayings, verdicts, quiz answers). Would this land, or would he wince? Is any fact wrong? |

Keep the club spread close to production (`device_tokens` by `team_id`,
`tier`); Arsenal is most of it.

The persona answers, in this order, without going back:
1. **First look** (feed screen only): what is this app, in one sentence?
2. **Her week** (push timeline): which pushes were worth the buzz, which
   annoyed her, which she would have turned off for. Anything confusing.
3. **Using it** (all screens): what she would tap first, where she got lost,
   what she did not understand, what made her feel stupid, what made her feel
   clever.
4. **The test**: on Saturday, could she say one thing from the app at the pub,
   or to him? Quote it. Would she keep the app: yes / maybe / no, and why.
5. Best and worst moment, each one screen or one push.

The panel is AI personas, not real women, and can share our blind spots. Say
so in the report. Weight physical findings (unreadable, cut off, a dead end)
above opinions, and count the opinions (5 of 7 found X) instead of quoting
one.

## 2.–8. The expert seats

Each one gets the rules above, the commit hash and its own brief. Every brief
starts with the same instruction: read `ARCHITECTURE.md` and `STATUS.md` first.

**2. UI.** Builds its own simulator. Covers every screen in §0.2 at the
default size and at Dynamic Type AccessibilityXL (the exact constant from
`project_sim_verification`), in light and in dark mode. Look for text that is
cut off or overlaps, images upscaled past @3x (`docs/IMAGE_REEXPORT.md` lists the known ones),
text over photos, tap targets under 44 pt,
VoiceOver labels on icon-only buttons, dead ends (a screen you cannot leave),
empty states and loading states, and where a push tap lands (`AppDelegate`).

**3. Tracking.** Reads `docs/TRACKING_PLAN.md`, runs
`./scripts/verify-tracking-plan.sh` and `./scripts/tracking-digest.sh 14`.
Checks that every event in the plan fires from the code path it claims, that
none fires twice (onAppear in reused views), and that `push_opened.kind`
matches what the senders send. Compares the Meta app events
(`AttributionService`) against our own `analytics_events`. Production is kept
apart from debug and simulator traffic. Looks for consent and ATT handling
that contradicts `docs/PRIVACY_POLICY_DRAFT.md`.

**4. Data.** Reads `DATA_SOURCES.md` and holds every fact she can see to it.
Pulls today's live rows: `team_pages.content` for the persona clubs,
`content_items` from the last 7 days, `match_status_state`. Finds any number or
name that rests on a feed marked NOT trusted, any missing value shown as 0
(`?? 0`), any season or competition label that is wrong, and any two surfaces
that disagree about the same match (push against card against After).

**5. Connection.** The path from the feed to her lock screen. Runs
`./scripts/db-health.sh`, `./scripts/verify-push-rules.sh`,
`./scripts/verify-push-eligible.sh` and `./scripts/verify-cron-auth.sh`. Checks
`cron.job_run_details` for failures and gaps over 7 days, `apns_send` failures
and invalid tokens, the Live Activity sends per match (priority-10 count), the
API-Football calls against the daily cap, pg_net `_http_response` bloat (memory
`project_db_maintenance`), and what the app does offline or with a slow
network (cached feed, spinners that never end).

**6. Security.** Runs `db-health.sh` section 7 and checks
`has_function_privilege('anon', …)` and `has_table_privilege` for every public
function and table outside the app's three RPCs. Covers RLS on every table
the anon key can reach, Edge Functions deployed `--no-verify-jwt` that do not
check the cron key themselves, secrets in the iOS bundle or in git history
(`scripts/pre-commit-secret-scan.sh`), leftover worktrees holding `.env`
copies, and input to any public endpoint used unvalidated. Reads
`SECURITY_PROBE_2026-10-07.md` and `CHANGELOG_SECURITY.md` first and does not
re-report what they list as fixed unless it has regressed.

**7. Bugs.** Correctness of everything shipped since the last council
(`git log` since the date of the previous `docs/council/` report, or 21 days).
Runs `deno test -A backend/supabase/functions/` and the iOS build. Feeds real
strings from live rows through the shipped functions, because hand-picked test
fixtures are how the 2026-09-09 defects got past the suites. Re-checks open
items in `AUDIT_FINDINGS.md` and the newest `QA_*` and `BUG_AUDIT_*` reports.

**8. Stale data.** Runs the `stale-data-audit` skill in **report-only mode**:
every section, nothing fixed. Lists what is stale, since when, and who has to
decide it.

## 9. Verify, then report

1. Read every seat's findings. Merge duplicates across seats; the same defect
   seen from two perspectives counts once, with both views noted.
2. **Verify each CONFIRMED finding yourself** before it goes in the report as
   confirmed. Seats have been wrong (2026-09-09: two of five "confirmed"
   findings did not hold). Downgrade what you cannot reproduce to SUSPECTED.
3. Write `docs/council/COUNCIL_<YYYY-MM-DD>.md`:
   - Header: commit, build, date, what each seat looked at.
   - **Verdict per seat**, one line each.
   - **The panel**: keep or delete per persona, the lines they would have
     said, and counted themes.
   - **Findings**, ranked HIGH to LOW, each tagged with its seat(s).
   - **What holds up.**
   - **Decisions for Anton**: anything that is taste, a trade-off or a cost.
4. Publish the same content as an Artifact and send Anton the link with a
   summary of a few sentences, in Swedish if that is what he is writing.
5. Fixing is a separate step that Anton approves. Fixers follow the red-team
   pattern (own worktree from the feature branch, one commit each, cherry-picked
   after review).
