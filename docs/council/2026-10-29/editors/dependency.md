# Dependency check (council 2026-10-29, SKILL.md §5)

Input: `verdicts/delete_move.csv`, 301 rows (222 Delete, 79 Move). Output: `verdicts/dependency.csv`, one row per id. The `group` column there is the **dependency group** (60 groups; rows in a group share one answer), not the editor group. Builder: `verdicts/tools/build_dependency.py`.

**How each row was checked:**
- **The app:** grep of `ios/GoalDigger` (code, not comments) at HEAD 15101e9.
- **Old builds:** the same files at the 2.2 build commit (`4df087f`, build 12) and the 2.3 build commit (`fd72332`, build 16), read with `git show`/`git grep`. There are no git tags.
- **Backend:** `backend/supabase/functions`, plus SQL against production (SELECT only): `pg_proc` bodies, `cron.job`, row counts on `team_pages`, `content_items`, `saturday_quiz_items`, `team_season_state`, `device_tokens` and `my_turn_content`.
- **Routines:** the routines repo at `~/goaldigger-routines`, origin/main `b5a3f9a`, read-only. That includes the `triggers/*.json` snapshot. The live RemoteTrigger state was **not** checked.

**Old-build share cannot be measured today.** `device_tokens` has no app_version column. `client_errors` holds only backend rows. App versions first arrive with 2.4's analytics (`props.app_version`, Analytics.swift:73), and that build is not uploaded yet. So every "until 2.2/2.3 < X%" below can only be measured after 2.4 ships. The measure: distinct 2.4+ install_ids in `analytics_events` over 14 days, against the 85 active production tokens. Tokens undercount users who denied notifications.

## Downgrades (27 rows, 3 decisions)

| Rows | Was | Becomes | Why |
|---|---|---|---|
| FEED-01-24, FEED-03-00..23 (25) | Move/Delete, "removes the inline quiz **and its routine** gd-saturday-quiz" | The in-app Move/Delete stands. **gd-saturday-quiz stays until 2.2+2.3 < X%.** | Both 2.2 (4df087f) and 2.3 (fd72332) render the inline quiz for tier 3 (30 of 85 active production devices). Stopping the routine does not crash them: the pill hides when there is no data (FEED-03-23). It does take the quiz away from old-build tier-3 users. No row has been written since 17 Oct, so check the live trigger: if it already died in the account migration, Anton can choose not to revive it. |
| TEAM-01-51 | Delete `ones_to_know.talking_point` from the gd-team-page prompt and post script ("never shown") | Keep the producer field until 2.2 < X%. Nothing changes in 2.4. | It is not shown in 2.3 or 2.4, but **2.2 renders it** (4df087f TeamPageView.swift:349). 20 of 73 rows carry it. Removing it makes the line vanish for 2.2 users without crashing anything. The only saving is tokens. |
| MY-04-07 | Remove `why` from quiz.json, the live builders and validate_content.py | Delete in app (already done 2026-10-28). Keep `why` in the published pack until 2.2+2.3 < X%. | quiz.json is published remotely (`my_turn_content`, module quiz) and decoded by every build. `why` is `String?` in all three decoders, so nothing crashes. But **2.2 and 2.3 render it** under every answer (QuizView:268 / :350). It also contradicts the standing content rule "quiz: why + use + useType", which Anton should retire explicitly. |

## PASS with a condition (the verdict holds only if it ships this way)

- **Her name** (ONB-02-*, SET-02-15/16, SET-03-*). This is a can't-delete item, because names are something she set. `personalise()` still substitutes `[her name]` (AppState.swift:255-268), and post_news.sh/repair_payload.py still accept the token. 0 rows use it today. In the same change, make `[her name]` always render "you" and stop reading `herName`. Otherwise a stored name could surface with no way to edit it.
- **Relationship** (ONB-03-04..09). Settings has **no** relationship row today, so onboarding is the only place to set it. The new Settings picker must ship in the same build.
- **His name** (ONB-03-00..03, -10). Every reader already falls back when the name is empty ("your partner", His/Their). The optional prompt on the club-tab header still has to be built.
- **Country** (SET-06-01..10, FEED country rows, FEED-04-04). The country UI is already hidden on 2.4 and 2.3 (`CountryFollowing.isEnabled=false`). 10 active devices still carry a country, and 1 of them follows only a country (netherlands, team_ids {}). SET-06-00 ("Stop following") must ship in the same build, and SET-02-19 must show whenever `selectedCountries` is non-empty. 2.2 has no flag and keeps its own sheet.
- **Notification ask** (ONB-10/11/12, FEED-01-13). The just-in-time ask must ship in the same build that removes the onboarding prompt and moves the banner, or a new install is never asked. Nothing on the backend depends on onboarding:
  - AppDelegate.swift:69-73 registers the APNs token whenever she is authorised.
  - Live Activity push-to-start tokens go to their own table.
- **Season primer** (ONB-16-*). The producer can go. The primer is unreachable in HEAD, 2.3 and 2.2 alike. The other old reader is 2.2's country feed, which reads country rows the routine stopped writing on 2026-06-24. The same change must edit `review_content.py:257`, the gd-maintenance prompt, `scripts/db-health.sh:114` and `scripts/arch-facts.sh`, or maintenance will flag the table as stale. Keep the `team_season_state` table while 2.2/2.3 live.
- **Kickoff T-30 push** (LOCK-02-02). Delete only the send (match-watcher:2228-2250). **Keep `'kickoff'` in push-tiers.ts:** `matchday-reminder:327` and `morning-push:122` use it as the gate for whether a fixture is covered, and cup-coverage.test.ts asserts it. verify-push-rules.sh keeps checking it.
- **Backstory body** (FEED-06-35/36). The in-app delete passes, but the producer must keep writing `body`:
  - `body` is NOT NULL in the database.
  - It is a required decode in HEAD, 2.3 and 2.2 (ContentItem.swift:142).
  - InsiderCard displays it.
- **Saturday Quiz destination.** MD-04 exists for every tier. It builds its questions from team pages, so nothing has to be built.
- **Opponent ones to watch** (TEAM-02-06/07). Matchday reads the **same** Coming-up data (LiveClubPack.swift:381/524/575), so the producer must stay.

## Corrections to editor evidence (the verdict still passes)

- **TEAM-02-17:** `basics.talking_point` renders for **4** active clubs, not 1: coventry, hull, leeds and sunderland. On leeds and sunderland the text starts with "Say this:", so the card reads "Say this: Say this: …", a live defect that this delete removes on 2.4. post_team_page.sh:152 *requires* the field when a page is created.
- **FEED-06-16:** the player card *can* be opened from the club page (TeamPageView.swift:183), and from QuizView.
- **TEAM-06-13:** confirmed dead. `.playerDossier` is available at every tier (TierGating.swift:22-26).
- **MY-16-03:** 7 World Championship rows from July are still `status=published` in the Football feed. Rows with `preview_fixture_id` are exempt from the 7-day archive cron, which also keeps 2 club news rows (man_utd, arsenal) published. They have league_id NULL, so no competition strap looks up the term. Archive them in the same change.

## Producer removals and what they save

| Producer | Removable now? | Saving |
|---|---|---|
| gd-season-state routine (`0 1 * * 1-5`, sonnet-4-6) | **Yes** (ONB-16) | 5 routine runs a week, about 260 a year (subscription quota) |
| gd-morning-push cron + Edge morning-push | Yes, **after** the matchday-reminder catch-up is built. Unschedule the cron in the same migration that deletes the function. | 1 deterministic Edge call a day; no API money |
| goaldigger-prep-reminder cron (inactive) + `?mode=prep` + migration 130 file | Yes | 0 runs (already paused). Update STATUS.md:64/80, which still says "apply 130". |
| T-30 send in match-watcher; consequence push; competition broadcast push | Yes (backend-only, every build) | Pushes, not money. PUSH_RULES.md and verify-push-rules.sh change in the same change. |
| gd-starting-xi trigger | Yes | 0 (already disabled) |
| AudioPlayerService, UnreadTracker, fetchPreviewItems, OnesToWatch/Who's who fetches | Yes (client) | 1 REST call per club page load and up to 3 per article open |
| gd-saturday-quiz routine | **No:** 2.2/2.3 render it | 2 runs a week, later |
| `ones_to_know_talking_point`, player_cards `form`/`vibe` in prompts; quiz `why` | **No:** 2.2 (and 2.3 for why/form/vibe) render them | Tokens only, later |
| team-page-generator `this_week`; match-watcher `writeTeamPostMatch` | **No:** 2.2/2.3 render them. After this change, 2.4+ reads post_match nowhere. | Deterministic, no API money |
| `content_items.body`, `everyone_talking_body` | **Never** while any build decodes body as required | none |

LLM-backed work saved now: one routine (gd-season-state). Every other removable producer is deterministic.

## Old-build constraints (measure after 2.4 ships)

1. Keep **gd-saturday-quiz** until 2.2+2.3 < X% (or decide to accept the loss now).
2. Keep **`ones_to_know_talking_point`** in gd-team-page until 2.2 < X%.
3. Keep **`why`** in quiz.json until 2.2+2.3 < X%.
4. Keep hype.json's **`streak`** array: both old builds would otherwise show an empty overlay.
5. Keep these producers and fields while old builds read them:
   - player_cards `form`/`vibe`;
   - `this_week`;
   - `post_match`;
   - `team_season_state` (the table, not the routine);
   - `basics.talking_point` seeds;
   - `worth_knowing`.
6. Remote packs (`my_turn_content`: quiz, lingo, hype, saythis) reach every build. Any republish must keep the old shape. Lingo ids must stay stable for the planned glossary-to-lingo map (MY-16-02).

## Must ship in this order

1. **Backend first, app later:**
   - LOCK-02-07 (competition broadcast feed-only), then FEED-05-18 (drop the Football push route).
   - The matchday-reminder catch-up, then LOCK-02-10 (unschedule gd-morning-push and delete the function together).
2. **Same build, or not at all:**
   - Relationship picker in Settings with ONB-03-04..09.
   - Just-in-time notification ask with ONB-10/11 + FEED-01-13.
   - SET-06-00 + visible SET-02-19 with SET-06-01..10.
   - `personalise()` her-name change with ONB-02 + SET-02-15/16 + SET-03.
   - Calendar-tab opt-in with ONB-13/14.
   - Store screenshot STO-02-06 in the same submission as ONB-13.
3. **Harness:** removing onboarding steps shifts `OnboardingStep` raw values. Update `-gdOnboardingStep` in app-council SKILL.md:132, tools/audit/dump.sh and the staging `onboarding.sh`. Also remove:
   - `-gdSeasonPrimer`;
   - the `-gdSay*` args;
   - `-gdShowImpress`;
   - `-gdTeamExpand season`.
4. **Analytics:** update TRACKING_PLAN.md in the same change:
   - drop the `hype_shown` case;
   - `line_shared` keeps only surface=copy;
   - `onboarding_completed.calendar` goes constant.
5. **Ordering advice (not a dependency):** 2.4 (18) is the first build with tracking. Cutting onboarding in that same build leaves no baseline for step drop-off, which the FIRST editor said usage must settle. Measuring one release before cutting would settle it.

## Summary

1. 301 rows checked: **PASS 274, DOWNGRADE 27**. 0 rows moved to Keep or Iterate. Every downgrade is a "producer stays until old builds age out".
2. The downgrades are 3 decisions: gd-saturday-quiz (25 rows), `ones_to_know_talking_point` (TEAM-01-51) and quiz `why` (MY-04-07). Old builds render all three; none would crash.
3. 6 groups pass only if they ship in the same build as their replacement: relationship picker, notification ask, country stop-following, her-name rendering, calendar opt-in, morning-push catch-up.
4. Removable producers now: gd-season-state (about 260 routine runs a year), morning-push (after its catch-up), the paused prep cron, the T-30/consequence/competition push paths, gd-starting-xi. Only gd-season-state is LLM-backed.
5. The old-build share cannot be measured until 2.4's analytics ship: `device_tokens` has no app_version.
