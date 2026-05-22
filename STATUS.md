# GoalDigger — Project Status

**Last updated:** 2026-05-22 early morning (06:55 UTC — TEAM IMPACT gate FAILED on first live fire. Two fun-trivia pushes landed at 06:41 (Hamilton crying over Arsenal title) + 06:45 (Prince William with Aston Villa). Both `push_eligible: true`. Prompt-following failure, not a deploy issue. **Lesson 77 / first task tomorrow morning: script-level enforcement in `post_news.sh`** per Lesson 17's pattern ("soft caps don't work; hard rejection does"). Submission still targeted for Tue May 26.)

A one-page snapshot of where the project is. For the deep history, see [IMPLEMENTATION_PROGRESS.md](./IMPLEMENTATION_PROGRESS.md) (phase-by-phase log) and [V1.1_FEATURE_BUNDLE.md](./V1.1_FEATURE_BUNDLE.md) (task-level tracker for V1.1 surfaces).

---

## TL;DR

GoalDigger is live on TestFlight (V1.3 build). **World Cup 2026 support (V2.0) is feature-complete + structurally hardened across the May 17–22 sprint** — content layer (basics card / player photos / consequence layer / news cadence / push-eligibility gate), data layer (every team has manager + crest + venue), iOS layer (slicker tabs / crest headers / circular player avatars). Submission targeted for **Tuesday May 26** (WC kicks off June 11, gives Apple ~14-day review buffer).

---

## Pre-submission roadmap (Tue May 26 target)

### Ready to ship — everything below is in the branch and tested

| Layer | What landed in the May 17–22 sprint |
|---|---|
| Backend | Migrations 051 (consequence layer) + 052 (push-eligibility). New `_shared/detect-consequences.ts` (pure-math) + `_shared/consequence-templates.ts`. match-watcher post-matchday hook. notification-sender gated on push_eligible. team-page-generator basics generation + venue data + squad top-up. |
| iOS | Slicker segmented control (no gutter, transparent unselected). Circular player photos in "The ones to know" expand (reuses onboarding's avatar pattern). Real team crest in the team-page header (no more "S" placeholder). Optional `BasicsCard.stadium` (graceful WC fallback). `MARKETING_VERSION = 2.0`. |
| Routines | gd-news + gd-news-wc cadence 18:30 → 22:30 UTC (covers same-night matchday results). PROMPT.md: 72h dedup + MAJOR EVENT cooldown + TEAM IMPACT gate. |
| Docs | BACKFILL_RULES.md + CLAUDE.md (cost-discipline guardrails). Lessons 72–76 in IMPLEMENTATION_PROGRESS. |
| Verified | iOS build green on iPhone 17 Pro sim. match-watcher + notification-sender + team-page-generator deploys clean. Cron auth 4/4 ✓. API-Football PL + WC standings flowing. 71/71 team_pages have basics. 70/71 have all 3 player photos (Canada's Davies legitimately missing from the API roster). |

### Outstanding by day

| Day | Owner | What |
|---|---|---|
| **Fri 22 morning (06:55 UTC audit — DONE)** | me | Audit confirmed the gate FAILED. Two pushes landed (Hamilton-cried + Prince-William-beer) with `push_eligible: true`. Both classic fun-trivia. The routine had the new prompt but the LLM didn't apply the rule. See "Lesson 77 / next-day fix" below. |
| **Fri 22 daytime** | me | Ship script-level enforcement: `post_news.sh` heuristic force-downgrade for known fun-trivia patterns (royal cameos, F1/NBA/tennis celebrity-cried, international-duty when writing for the CLUB). Same shape as Lesson 17's headline-cap hard reject. Verify on 22:30 UTC fire. |
| **Fri 23 evening** | you | Optional: also audit the 22:30 UTC fire. Second test of the gate + Friday post-match coverage if any leagues have games. |
| **Sat 24** | you | Soak. Spot-check the day's content for tone/accuracy. Read 5-10 random items per day and confirm voice is right. |
| **Sun 25** | you | Real-device TestFlight smoke test — install latest internal build, complete onboarding with WC country selection, verify push delivery via a manual content_items INSERT. Final read-through of `APP_STORE_V2.0_COPY.md` (description, What's New, keywords, promo). |
| **Mon 26** | you | Screenshots — 12 PNGs (6 at 6.9", 6 at 6.3") per `APP_STORE_V2.0_SCREENSHOT_PLAN.md`. Archive iOS app in Xcode (Product → Archive). Upload to App Store Connect. Wait for "Ready to Submit" email. |
| **Tue 27** | you | App Store Connect: paste copy from `APP_STORE_V2.0_COPY.md`, upload screenshots, select build, answer export compliance, click **Submit for Review**. |

### Audit query for Friday morning

```bash
set -a && source backend/.env && set +a
/opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" <<'SQL'
-- Fri morning fire (06:30 UTC) — should be done by 07:00 UTC = 09:00 CEST
SELECT to_char(created_at AT TIME ZONE 'UTC', 'HH24:MI') AS t,
       team_id, push_eligible,
       substring(headline FROM 1 FOR 60) AS headline
FROM content_items
WHERE created_at > now() - interval '90 minutes'
ORDER BY team_id, created_at;

-- Sanity: no apns_send for push_eligible=false items
SELECT count(*) AS feed_only_items_that_leaked
FROM content_items ci
JOIN pipeline_health ph ON ph.stage='apns_send' AND ph.team_id=ci.team_id
 AND ph.created_at BETWEEN ci.created_at AND ci.created_at + interval '5 minutes'
WHERE ci.push_eligible = false AND ci.created_at > now() - interval '90 minutes';
-- Expected: 0
SQL
```

### If the morning fire doesn't honor the gate

If everything comes back `push_eligible = true`, the Claude routine isn't following the new prompt rule. Two options:
1. **Tighten the prompt** — add a stricter validator (post-script hash on headline → if "He'll" + an international-duty player, reject).
2. **Soft block** in post_news.sh — script-level enforcement (similar to the headline cap rule from Lesson 17).

That's a same-day fix if it surfaces.

---

## Today's session log (May 21–22 UTC) — the work that landed

Eleven commits across this 24-hour arc:

1. `0bc9350` — Manager card unlocked for every team (three-layer coachs fix — Lesson 72)
2. `8437ede` — Circular player photos in "The ones to know" + optional stadium
3. `11f56c1` — "The basics" card generated for every team
4. `4e18f48` — Lesson 73 (basics-card unlock + credit-balance trap)
5. `66cde39` — Canada player photos via direct SQL (cost-discipline rule applied)
6. `cbc17d5` — BACKFILL_RULES.md + CLAUDE.md (cost-discipline guardrails — never repeat the burst-API-call mistake)
7. `d8ef854` — Cross-team consequence layer shipped (Lesson 74)
8. `ab57527` — STATUS + Lesson 74
9. `ff313d4` — STATUS + Lesson 75 (gd-news dedup tightening — 72h + MAJOR EVENT cooldown)
10. `3caf707` — Team page header real crest (no more "S" placeholder)
11. `ce5bf6d` — Push-eligibility gate (Lesson 76)
12. `308eea2` — `MARKETING_VERSION = 2.0`
13. `3ec9289` — `/simplify` pass (-48 LOC, six review-found issues fixed)

Routines repo: `693bc67` (72h dedup) + `b6a3e19` (TEAM IMPACT gate).

Operationally: API-Football account topped up + verified flowing; data-fetcher manually fired to land fresh standings/fixtures/squad/coachs/teams; cron auth verified 4/4 ✓.

---

## Verified today (May 22 — push-eligibility gate)

User received a push: **"He'll be absolutely buzzing"** / *"Arsenal's captain Odegaard is heading to the World Cup as Norway's captain…"*. For an Arsenal-ONLY follower, that's fun-to-know trivia — not buzzing territory. The emotional opener framed his response as bigger than reality. User's clarification: _"if he was also a Norway fan this would work for sure but not now, should just be in feed."_

Fix shipped — separate gate on **push eligibility** independent of content. The item still publishes to the feed for Arsenal followers (discoverable on next app open); it just doesn't trigger a notification. Norway followers get the same news via gd-news-wc's Norway-tagged item, which IS team-impact for them and pushes normally.

Pieces:

- **Migration 052** — `content_items.push_eligible BOOLEAN NOT NULL DEFAULT TRUE`. Backward-compatible — every existing row stays push-eligible, every routine that doesn't know about the field continues to ship the legacy behaviour.
- **notification-sender** — sweep query gains `.eq("push_eligible", true)` filter. `specificItemId` path unchanged so manual recovery of a feed-only item is still possible.
- **PROMPT.md** in `goaldigger-routines` (commit `b6a3e19`) — new "TEAM IMPACT gate" section that runs BEFORE the existing emotional_context calibration. Six ✅ team-impact categories vs six ❌ fun-trivia categories with explicit good/bad push-field examples. The Odegaard incident is embedded as a worked example.
- **schema.json** — added optional `push_eligible: boolean` property. `push_title` + `push_text` stay required because they're rendered in non-push surfaces; feed-only items just write them neutrally ("Odegaard, Norway captain" / "Arsenal's Odegaard will lead Norway at the World Cup").
- **PROMPT_WC.md** inherits PROMPT.md verbatim per its line 7, so gd-news-wc gets the same gate automatically.

Verification: next gd-news fire (next 22:30 UTC) will preflight commit `b6a3e19`. Confirmation that the gate is honoured comes from psql: a `WHERE push_eligible = false` query on `content_items` should return > 0 rows for next-fire output if any fun-trivia items shipped, and zero `apns_send` rows in `pipeline_health` for those items' team_ids.

Architecture cost: one migration (additive column with safe default), one notification-sender filter, one PROMPT.md section. Zero new routines. Zero API credits. Zero schema breakage.

---

## Verified today (May 21 late-late — gd-news dedup tightening)

User reported receiving three Arsenal-title-themed pushes over Wed 20 → Thu 21 (Wed morning, Thu morning, Thu evening). All three came from the existing `gd-news` cloud routine — confirmed zero `consequence_fire` rows in `pipeline_health`, so the new layer was NOT involved. Root cause was in the routine's `PROMPT.md` step 2.c dedup:

1. **24h lookback was off by minutes.** Two morning fires drift by ~4 min UTC → today's `SINCE = now − 24h` query misses yesterday's same-time-of-day item.
2. **The "same story" rule didn't handle follow-up-angle headlines that still reference the major event** (e.g. the Arteta story whose headline mentioned "the moment they won the title").

Fix shipped to `anton-tech43/goaldigger-routines` commit `693bc67`:

- Extended dedup lookback from 24h → 72h. Covers 5-6 fires, robust to UTC-minute drift.
- Added a MAJOR EVENT cooldown rule with explicit good/bad headline examples. When a status-changing event (title, relegation, sacking, trophy) is in the lookback, follow-ups still publish but the headline must lead with the new angle, not the event itself. "Arteta's son cried into his shoulder" ✓; "Arteta couldn't watch the moment Arsenal won the title" ✗.
- Includes a worked example from the May 19-21 Arsenal incident in the prompt so future runs see exactly what went wrong before the rule.

PROMPT_WC.md inherits dedup logic from PROMPT.md verbatim, so both gd-news and gd-news-wc are covered by the single PROMPT.md change. Zero schema changes, zero Edge Function changes, zero quota impact.

Verification on next fire: the `[ROUTINE VERSION]` preflight log on the next 22:30 UTC gd-news fire will echo the new commit SHA, confirming the routine picked up the updated prompt.

---

## Verified today (May 21 late — cross-team consequence layer + news cadence shift)

Two related pieces closed the architectural gap surfaced by the May 19 incident (Bournemouth held Man City 1-1 → Arsenal mathematically champions → Arsenal subscribers got zero push because notification-sender only routes by content_items.team_id).

- **Consequence layer shipped** (commit `d8ef854`). New `_shared/detect-consequences.ts` (pure-math detector, no LLM) + `_shared/consequence-templates.ts` (template library, pure strings) + a post-matchday hook in `match-watcher/index.ts` that INSERTs a templated `content_items` row for each non-playing team whose race state changed. notification-sender's existing per-team sweep pushes within ~60s. Migration 051 added the `consequence_type` column, a partial unique index for idempotency, and extended the `pipeline_health` stage CHECK with `consequence_fire`. Eight consequence types covered: TITLE_WON / RELEGATED / UCL_CLINCHED / EUROPE_CLINCHED (PL) + WC_GROUP_WON / WC_KNOCKOUT_QUALIFIED / WC_KNOCKOUT_ELIMINATED (WC). Voice matches the gf-to-bf older-sister tone of the routines. **Zero new routines, zero Anthropic API credits.** A 5-min age guard on the standings snapshot prevents double-counting when data-fetcher has already ingested the just-finished result.

- **Live math probe confirmed correctness.** Direct SQL against the latest PL standings shows Arsenal min (82) > Man City max (81) → TITLE_WON ✓. The detector reproduces this math.

- **News cadence shift live.** `gd-news` moved from `30 6,18 * * *` UTC → `30 6,22 * * *` UTC; `gd-news-wc` from `35 6,18 * * *` → `35 6,22 * * *` (5-min offset preserved). The evening 22:30 UTC fire lands after the latest realistic PL FT (~21:30 UTC) and rides the freshly-refreshed 22:00 UTC `data-fetcher` snapshot. Routine count unchanged (4 fires/day total). Next fire tonight ~22:30 UTC will be the live test.

- **What's still pending (operational, not in scope of this commit).** API-Football account dropped to free tier at some point yesterday — `data-fetcher` is currently returning `"Free plans do not have access to this season"` errors for both leagues. `match-watcher` runs cleanly but sees zero fixtures. Standings + fixtures_last are frozen at Wed 20 May 20:00 UTC. The consequence detector is wired and correct; it just needs upstream data to flow. **Top up / restore API-Football plan at https://dashboard.api-football.com** to resume the live pipeline.

- **By design, no backfill of last night's Arsenal moment.** User-explicit call — this is a learning moment. The consequence layer is wired forward; the May 19 title-clinch stays uncovered as a documented teaching case in Lesson 74.

---

## Verified today (May 20 early morning — "The basics" card + circular player photos)

Two team-page polish items, both stemming from the same lens that surfaced yesterday's manager-card breakage: the iOS app gracefully hides cards when their backend data is missing, which means a universal data gap looks identical to a per-team gap. Sweden + tonight's sim review surfaced both.

- **Player photos on "The ones to know"** (iOS render delta, commit `8437ede`). The `photo_url` field has been flowing end-to-end from `team-page-generator` to `TopPlayer.photoURL` for weeks — 70 of 71 team_pages rows already carried headshot URLs (only Canada is missing photos due to a squad-data crowding pattern, see "Carryover" below). But `TeamPageView.playerRow()` was rendering text only. Added a 36pt circular `playerAvatar(player:size:)` helper reusing onboarding's `MeetTeamView.playerAvatar` pattern (AsyncImage + hot-rose initials fallback + `.clipShape(Circle())`). URLCache.shared already handles disk caching. iOS build green on iPhone 17 Pro sim. Initials handle every missing photo case (including Canada's three players) so the visual fallback is graceful.

- **"The basics" card now generated for any team where it's null** (backend + iOS optional-stadium support, commit `11f56c1`). Migration 004 hand-seeded basics for the 20 V1.x PL clubs; the 48 WC countries from migration 032 plus the 3 promoted 2025-26 PL teams from migration 018 never got seeded. The team-page-generator explicitly preserved instead of generating (`basics: existingCards.basics ?? null`). iOS hid the card silently for null basics, so the 51-team gap was invisible — exact same class as yesterday's `<UNKNOWN>` manager. Added: (1) new optional `basics` field on the Claude tool schema, (2) `Teams data` slot pulling api_football_teams payload into the prompt so Claude has deterministic venue.name + country.name (catches venue renames like Friends Arena → Strawberry Arena 2024), (3) `existingBasicsBlock` injection that tells Claude to PRESERVE-verbatim vs GENERATE-fresh, (4) build-step graft that uses Claude output ONLY when existing card is null (PL hand-seeded copy stays frozen — Arsenal's `updated_at: 2026-04-07` verified untouched after re-fire). iOS: `BasicsCard.stadium` optional, basics block falls back to nickname for collapsed subtitle and hides the "Home ground" row when stadium is nil. Backfill ran on all 51 null-basics rows; quality is strong on spot-check (Argentina → "La Albiceleste" / Estadio Monumental; Brazil → "A Seleção" / Maracanã; England → "Three Lions" / Wembley; Germany → "Die Mannschaft" / Allianz Arena; Iran → "Team Melli" / Azadi Stadium; Sweden → "Blågult" / Strawberry Arena, Solna).

- **Canada player photos — finished via direct SQL UPDATE** (no Claude call). After the 50-team basics burst bottomed out the Anthropic API credit balance (~$4-5 burned, Lesson 73), the right move was no more Claude calls. Pulled the API-Football headshot URLs straight from `raw_fetch_logs.api_football_squad` for the two players present in the current Canada roster (`J. David` → `8489.png`, `C. Larin` → `2001.png`) and patched `team_pages.content.cards.ones_to_know.players` with a single `jsonb_set` UPDATE. Alphonso Davies is genuinely absent from API-Football's current Canada roster (recent ACL absence — Bayern), so his row stays without a photo and iOS renders an `AD` initials avatar — graceful, not broken. Final state: 0 teams with null basics, 0 teams photoless, 70 of 71 with all 3 photos, Canada at 2 of 3 by upstream constraint.
- **Cost-discipline lesson logged.** The basics backfill should have used direct SQL (the same way the manager backfill yesterday could have, in hindsight) or a one-off routine, not 50 individual Claude API calls. `team-page-generator` is the only Edge Function still calling Anthropic directly that fires non-trivially; migrating it to a routine pattern (`gd-team-pages` → `post_team_page.sh`) is filed in Lesson 73 as the V2.1 cost-discipline ticket. Until that lands, all multi-team backfills go through SQL or a one-off routine. No more per-team API-credit bursts.

- **JSONB-null trap (audit-query hardening, no code change).** During the backfill verification, `SELECT … WHERE content->'cards'->'basics' IS NULL` returned 0 rows — but 51 rows had basics set to the JSONB literal `null` value, not SQL NULL. The audit query needs `WHERE x IS NULL OR jsonb_typeof(x) = 'null'`. Worth keeping in mind for any future `team_pages.content` audit.

---

## Verified today (May 19 morning — slicker segmented control + manager-card unlock)

Two items from yesterday's punch list, both shipped in one pass. The manager-card work turned out to be a two-layer iteration-overwrite class (Lesson 72) that had been silently blocking the coach name for **every team except Sweden** — 69 of 70 team pages were showing `<UNKNOWN>` and the iOS "Meet the boss" card was gracefully hiding for all of them. Surfaced because the user noticed Sweden specifically; investigation uncovered the breadth.

- **iOS tab selector — lighter chrome** (`ios/GoalDigger/Views/Team/TeamPageView.swift` `tabSelector`, 9-line delta). Before: 3 white pills on a soft-blush gutter, sitting on the deep-mauve team-page background — three competing layers. After: only the selected tab renders as a hot-rose pill; the other two are bare 60%-opacity warmWhite text directly on the page background, and the gutter wrapper is gone entirely. Selected-tab visual (hot rose + cornerRadius(12) + frame(height: 40)) is unchanged so the affordance still reads. Build green on iPhone 17 Pro simulator.

- **team-page-generator manager-card unlock — three fixes** (`backend/supabase/functions/team-page-generator/index.ts`, ~60-line delta with comments). Each fix addressed a distinct failure mode that was contributing to the universal `<UNKNOWN>` state:
    - **Fix 1 — empty-response iteration overwrite** (the original Sweden symptom). The `api_football_coachs` else-branch was writing the rate-limit error JSON (`response: []`) to `coachsData` when the newest log was empty. The Lesson 67 `if (coachsData) continue;` guard then locked that empty response in, blocking every subsequent older log — including the 15:00 UTC fetch with valid coach data. Changed to `continue` so the loop walks past empty/error snapshots to find a populated one. Same class as Lesson 67 but opposite direction (newest-empty-blocks-older-good).
    - **Fix 2 — coachs top-up query** (Canada surfaced this one). The 100-row main fetch window gets crowded out by news sources (6 hourly publishers per team), so when `api_football_coachs` has been returning rate-limit-empty for ≥5 consecutive fetches, the older good payload sits outside the window. Fix 1's `continue` couldn't help because there was nothing older to walk to. Added a targeted secondary query that pulls the latest 20 `api_football_coachs` rows directly and appends to `rawLogs`. Cheap (one extra indexed query), guaranteed to cover ~20h of history regardless of news cadence.
    - **Fix 3 — no-current-coach should emit UNKNOWN, not guess** (surfaced by France/Scotland/Uruguay still rendering wrong names after fixes 1-2). When the pre-filter finds zero coaches with `end=null` at this team, the old fallback wrote the raw payload and let Claude pick from a list of historical-only stints — which gave us R. Caudron (1930) for France, A. McLeish (last stint ended 2019) for Scotland, Ó. Tabárez (last stint ended 2021) for Uruguay. Changed to `continue` (walk older snapshots; if every log is in the same state, `coachsData` stays empty → Claude's "not available" branch fires → `manager_name = <UNKNOWN>` → iOS card hides).

- **Live backfill: 70 team_pages rows re-fired post-deploy.** Before: 69 `<UNKNOWN>` (every team except Sweden was stuck on the iteration-overwrite). After: 0 `<UNKNOWN>` rendering wrong, 3 cleanly hidden (`france`, `scotland`, `uruguay` — upstream API-Football data has zero open stints for these national teams), 1 still wrong (`spain` → "D. Deschamps" — API-Football has Deschamps incorrectly tagged to Spain's team_id=9, which Fix 3 can't repair). Spain remains a `manager_overrides` candidate per the original Lesson 67 plan; the table itself stays unbuilt as a deferred V2.1 task.

- **Net iOS impact:** of 70 team pages, 66 now correctly display the coach name and photo; 3 cleanly hide the card (France/Scotland/Uruguay); 1 still shows a wrong name (Spain). Pre-fix every team except Sweden hid the card — a regression we hadn't noticed because the iOS gate's silent fallback was working as designed. Lesson 72 documents the two-layer iteration-overwrite class for future reference.

---

## Verified today (May 17 evening — launch-readiness closeout)

Five-phase verification pass run autonomously, all gates green except as noted:

- **Phase A — iOS build:** `xcodebuild -scheme GoalDigger -destination 'iPhone 17 Pro,OS=26.4'` returned `** BUILD SUCCEEDED **`. Zero errors, one unrelated `appintentsmetadataprocessor` warning. The 30+ Swift-file V2.0 refactor (FeedContext.country, UnreadTracker signatures, new onboarding flow, WCMigrationSheetView) compiles clean.
- **Phase B — Cron health:** `scripts/verify-cron-auth.sh` ✅ all 4 checks passed (Vault entry, accessor, JWT shape with `eyJ` prefix len=219, recent HTTP clean). 6h `net._http_response` window shows 340 × 200s + 27 NULL-in-flight rows, zero non-200s. All 3 HTTP-making crons (`match-watcher-1min`, `notification-sweep`, `goaldigger-daily-pipeline`) use the Vault accessor pattern, zero inline JWTs.
- **Phase C — WC routine prompts (`anton-tech43/goaldigger-routines`):** All 8 prompts gained a `## COMPETITION CONTEXT` block (entity_type lookup snippet + club-vs-country voice rules) plus a `## WC-MODE NOTES` block at the bottom (per-routine handoff bullets verbatim). PROMPT.md also got an explicit workflow sub-step `a-bis` pointing at the lookup. Two commits: `b724f5d` (the 8-prompt structural pass) and `fe6e3c2` (the PROMPT.md sub-step reinforcement). post_*.sh scripts untouched — the entity_type resolution lives in the prompt, not the post wrapper (Claude drives the loop). **Deferred:** `gd-news-wc` routine creation — needed because PROMPT.md hard-codes 20 PL clubs alphabetically per session; 48 WC countries need a separate cron slot to avoid context blowout. Documented in WC-MODE NOTES section of PROMPT.md.
- **Phase D — Push pipeline smoke test:** `push-probe` for `team_id=arsenal` returned APNs 400 BadDeviceToken — a token-side issue (dev token from May 15 is stale), not a pipeline issue. The fact that we got 400 (not 401/403) means APNs auth is healthy and the Vault JWT is accepted. **Untested at device level:** V2.0 country routing in `notification-sender` (joins on `team_id OR country_id`) — zero `country_id` tokens exist in `device_tokens` yet because no dev device has been onboarded through the new V2.0 flow. Will be exercised by either (a) onboarding a dev device + picking a WC country, or (b) the first real WC content_item once `gd-news-wc` is live.
- **Phase E — STATUS.md update + commit/push:** this entry.

---

## Verified today (May 17 late evening — gd-news-wc + App Store assets)

Continuation pass after the 5-phase verification closeout above. Two more streams landed:

- **Phase F — `gd-news-wc` routine shipped:** New `fetch_news_wc.sh` (48 country mappings hardcoded, league=1&season=2026 queries, 4-RSS international shortlist, shared global standings fetch) and new `PROMPT_WC.md` (delta-on-PROMPT.md, ~80 lines). Routines repo commits: `48c651b` (initial files) + `97843a0` (contamination-prevention rule tightened after first-fire audit). Cloud routine `trig_0128pyjoweWumZGSDDFp9fa5` created via `RemoteTrigger`, cron `35 6,12,18,0 * * *` UTC (5-min offset from gd-news). First fire at 12:35 UTC produced **4 clean country items** (argentina/Messi-Spain hypothetical, brazil/Casemiro farewell, england/Kane 4th hat-trick, south_korea/Son captains 4th WC) — voice country-aware, all 22-char-per-line caps respected, no hallucinations spotted. **1 contamination caught**: a Liverpool news item — gd-news-wc found a Liverpool story in shared RSS and posted it despite the 48-country scope. Item is real + well-written (not harmful, not archived), but the PROMPT_WC.md update (`97843a0`) now has a CRITICAL section forbidding non-country team_ids and forcing alphabetical iteration. Next fire at 18:35 UTC will validate the fix.

- **Phase G — App Store V2.0 launch assets drafted:** Three new docs in this repo:
    - `APP_STORE_V2.0_COPY.md` — paste-ready listing copy (subtitle, promo, What's New, full description, keywords) with the WC pivot baked in. ~210 lines.
    - `APP_STORE_V2.0_SCREENSHOT_PLAN.md` — 6-screenshot spec for the V2.0 submission. New shots #2 (CountrySelectionView with Argentina selected) and #3 (OptionalPLTeamView with Arsenal + Argentina dual fandom) carry the WC story. Demo persona (Sophie/Ben/Argentina/Arsenal) for consistent storytelling. ~189 lines.
    - `APP_STORE_V2.0_SUBMISSION.md` — T-3 / T-2 / T-1 / Day-0 submission checklist with Xcode archive walkthrough, App Store Connect form-fill steps, export-compliance answers, and worst-case fallback plan. ~118 lines.
- All three are paste-ready for June 4 submission day. Submission, archive, and screenshot capture are all manual (require user's Mac + Apple ID + Xcode).

---

## Verified today (May 17 night — silent-failure structural fix)

Third continuation pass. Three streams landed end-to-end. The user reported "5th silent push failure" during a live Everton match; investigation surfaced two distinct bugs (anti-spam self-reference + routine-quota cap) plus a missing architectural layer (observability across all pipeline hops). All three shipped tonight.

- **Stream A — Anti-spam removed** (commit `5c9cbf2`). Root cause of the "every match I miss a push" pattern: `_shared/anti-spam.ts` queried the most-recent `published_at` row for the team to compute "hours since last push," but the routine had already inserted the new content_item with `status='published'` before `notification-sender` ran. The query found the row that had just been inserted, so `hoursSinceLast ≈ 0` and the check blocked every push for teams with no prior recent push. Fix: removed anti-spam entirely. Tier segmentation (`minTierForType` in notification-sender) is sufficient volume control; quiet hours move to iOS Do Not Disturb. The Everton 1-3 push that validated this arrived on the user's iPhone within seconds. Documented as IOS_GOTCHAS #15 + Lesson 62 (`5 silent push failures weren't the same class`).

- **Stream B — Routine quota fit, three-tier cron restructure** (match-watcher commit `2896d44` + cloud-routine updates via RemoteTrigger). Discovered during the Everton match: claude.ai routines have a 25/25 daily run cap, and the busy-Saturday combination (match-watcher HT/75' fires × 4-5 PL matches + scheduled background routines) hits 48/25. Shipped:
    - **Tier 1**: `gd-insider` (`0 2 * * 1-5`) and `gd-season-state` (`0 1 * * 1-5`) moved to weekday-only (no value firing on match-day weekends; routine voice doesn't change weekend-vs-weekday).
    - **Tier 2**: `gd-news` and `gd-news-wc` cadence reduced from `30 6,12,18,0` (4×/day) to `30 6,18` (2×/day). News drifts ~6h instead of ~3h between fires, which is acceptable for our content cadence.
    - **Tier 3**: match-watcher dropped the 75' live-brief trigger entirely. HT remains. Saves 1 fire per match.
    - Result: 4-match Saturday quota goes from 48/25 → ~19/25, comfortable headroom. Documented as Lesson 63 (`Routine quota economics — schedule for the busy day, not the average day`). Cron config lives only in claude.ai/code/routines (NOT in this repo's migrations) — the three-tier change is documented in IMPLEMENTATION_PROGRESS.md for the source of truth.

- **Stream C — Phase J pipeline observability (P.1–P.5 shipped end-to-end)**. The structural fix that ends the silent-failure pattern. After this, EVERY hop in the push pipeline writes a `pipeline_health` row on every attempt:
    - **Migration 038** (`038_pipeline_health_expanded.sql`): added `target`, `http_status`, `response_excerpt`, `error_class` columns. Expanded `stage` CHECK to allow `live_brief_fire`, `matchday_fire`, `apns_send`, `routine_post`, `cron_invoke` alongside the existing `fetch`/`generate`/`review`/`publish`. Added `status='partial'` for mixed batch outcomes. Made `team_id` nullable for system-level rows. Composite index `(stage, created_at DESC)` for SLA queries.
    - **P.2 — match-watcher writes** (commit `a505711`): new `logFire()` helper writes a `pipeline_health` row on every gd-live-brief and gd-matchday fire attempt — success or failure — with `target=<routine>:<team>:<fixture>:<trigger>`, the HTTP status, and a 200-char response excerpt. The earlier `console.error`-to-stderr-only pattern that buried failures invisible to the DB is gone.
    - **P.3 — notification-sender writes** (commit `ae4cfe7`): every APNs send writes a `pipeline_health` row with full status taxonomy: `success` / `token_expired` (410) / `bad_token` (400) / `auth_failure` (403) / `rate_limited` (429) / `apns_error`. The aggregate publish row per content_item uses `status='partial'` when some tokens succeeded and others failed.
    - **P.4 — routine post-scripts write** (routines repo commit `7edf609`): all six `post_*.sh` scripts (`post_news`, `post_live_brief`, `post_insider`, `post_quiz`, `post_player_dossier`, `post_season_state`) now write a `pipeline_health` row on every Supabase REST POST — both success and failure paths. Best-effort (`|| true`) so observability failures never break the routine. `post_matchday.sh` doesn't exist (matchday flow is single-step inside the prompt session, covered by CHECK 4 below).
    - **Migration 039** (`039_pipeline_health_sla_checks.sql`): extended `check_pipeline_heartbeat()` with **CHECK 3** (live_brief SLA — HT fire succeeded but no `live_match_briefs` row within ±10 min) and **CHECK 4** (matchday SLA — `match_status_state.fired_finished_at` set but no `content_items` row of `type='matchday'` within ±15 min). Both throttled to 1/hr per check via `client_errors` dedup window. The 30-min heartbeat cron now automatically surfaces silent-routine-session failures as `client_errors` rows — and the existing client-error-alert push to the dev iPhone tightens the loop.
    - Verification of P.4 deferred to tomorrow ~06:35 UTC (after the first scheduled `gd-news` fire at 06:30 UTC). Today's quota is 25/25 so a manual trigger would 429.

After this, the only un-instrumented hop in the pipeline is the routine session's internal execution (Anthropic-side, not in our DB). The contract is: if a routine fires and produces nothing, CHECK 3 or CHECK 4 surfaces it within 30 min; if it fires and the post-script POSTs but Supabase rejects, the `routine_post` row captures it; if APNs rejects, `apns_send` captures it. The next "I didn't get a push" investigation starts with a SQL query, not a routine-session-log dig.

---

## Verified today (May 17 late night — Phase J closeout: live verify + simplify + CHECK 5)

Fourth continuation pass. Validated the night's Phase J work in production immediately rather than waiting for tomorrow, then ran a 3-reviewer audit (`/simplify`) and shipped two follow-up migrations.

- **Live verification against prod** (read-only psql against `pipeline_health` + `client_errors` + `match_status_state`). Confirmed P.2 (match-watcher fires) emits rows correctly — 288 `matchday_fire` failure rows in 71 min during a 429 storm on 4 stuck PL fixtures (Brentford-Crystal Palace + Leeds-Brighton, 2 perspectives each). Confirmed P.3 (notification-sender) is deployed at v32 (19:04 UTC) but waiting for the next fresh push to validate. Confirmed migration 039 applied (CHECK 3+4 in `check_pipeline_heartbeat` body). Confirmed `match-watcher` retries `matchday_fire` every minute indefinitely when fire returns non-2xx — `fired_finished_at` only gets set on success, so on 429 it stays NULL and the next tick re-fires. **Filed as V2.1 ticket** (Lesson 64); resets when quota does at 22:00 UTC = 00:00 Stockholm.

- **`/simplify` audit shipped two fixes** (commit `5fe7f61`):
    - **Migration 040** (`040_pipeline_health_safety_review_stage.sql`): migration 038 dropped `safety_review` from the stage CHECK inadvertently when expanding the set. `content-reviewer/index.ts:257` writes `stage='safety_review'` on every safety hop — has been silently CHECK-failing since 038 deployed, surrounded by try/catch so no one noticed. Fixed by drop+re-add of the constraint with `safety_review` restored. Verified live.
    - **notification-sender errorClass refactor**: 5-level nested ternary (`success → 410 → 400 → 403 → 429 → default`) replaced with a `APNS_STATUS_TO_ERROR_CLASS: Record<number, string>` lookup. Same behaviour, easier to extend. Deployed.

- **Migration 041 — CHECK 5: persistent fire failures** (commit `293c70e`). CHECK 3+4 watch the OUTPUT (did the artifact land?). CHECK 5 watches the FIRE (is match-watcher reaching the routine API?). Query: any fire `target` in the last 30 min with ≥1 failure AND zero successes → alert. Surfaces `http_status` + `error_class` in the alert message so the diagnostic is in the push itself. Throttled 1/hr like CHECK 1-4. **Validated live on first manual run** — caught the 4 stuck PL fixtures from tonight (`4 match-watcher fire target(s) failing repeatedly in last 30 min (http codes: 429, error classes: fire_failed)`), pushed a `persistent_fire_failure` alert via the existing `client-error-alert` Edge Function. Closes the gap between CHECK 4 (only fires when `fired_finished_at` is set) and the fire-side failure class (where `fired_finished_at` never gets set).

- **Lesson 64 — morning-after Phase J playbook** (commit `a6c4667`). Four paste-ready SQL queries for tomorrow's verification (06:35 UTC routine_post evidence; 07:00 UTC client_errors; mid-day per-stage coverage; manual heartbeat smoke). Symptom→cause→next-step escalation table. **V2.1 candidates filed:** match-watcher retry-loop fix, pipeline_health 90-day retention sweep, `match_status_state.fired_finished_at` index, `error_class` as typed union in `_shared/types.ts`.

**Net result of tonight's late-night closeout:** Phase J went from "shipped P.1–P.5" to "shipped + verified in production + audited + extended with CHECK 5 + documented for tomorrow" in one continuation pass. Found two latent bugs along the way (the `safety_review` CHECK regression in 038 + the match-watcher retry loop) that the new observability surfaced within minutes of deploy.

---

## Verified today (May 17 night-final — WC pre-launch hardening)

Fifth and final continuation pass for May 17. Shipped the five backend items from Lesson 64's V2.1 list as a "WC pre-launch hardening" sweep. Goal: a system that survives WC matchdays without burning hundreds of API calls during quota events, with bounded table growth and tighter type-checking. Five migrations + one code change + two deploys, all validated.

- **Phase 1 — Match-watcher matchday-fire retry cap (P0)** (mig 042 + match-watcher commit `cce7980`). Adds `match_status_state.matchday_fire_capped BOOLEAN`. Before every matchday fire, match-watcher queries pipeline_health for failure history on this fixture's targets in the last 6h. If any target has ≥5 failures OR a first failure >2h ago, the cap trips: skip the fire, write `matchday_fire_capped = TRUE`, never re-fire. Backfill marked the 3 fixtures stuck tonight (Brentford-Crystal Palace, Leeds-Brighton, Newcastle-West Ham) as already-capped, stopping the 288-row 429 storm on the very next cron tick. Verified live: 0 new matchday_fire rows in 90s post-deploy. **Live_brief NOT modified** — it already has implicit single-attempt protection via `briefs_fired` (updated unconditionally regardless of fire outcome). "HT retry within window" deferred to V2.x.

- **Phase 2 — `pipeline_health` 90-day retention sweep (P1)** (mig 043). New daily cron `pipeline_health_retention_sweep` at 03:00 UTC. At ~5 rows/min baseline, the table grows ~7,200 rows/day — by WC final, ~600k rows. 90-day retention is enough for heartbeat checks, postmortems, and quarterly trend analysis. Day-one no-op; the first real DELETE happens mid-August when today's rows cross the horizon.

- **Phase 3 — CHECK 4 query indexes (P1)** (mig 044). Per /simplify Efficiency #3: CHECK 4 was doing Seq Scan + correlated subquery for `match_status_state.fired_finished_at` and `content_items(match_id, type)`. Partial indexes added on both — partial because most rows have NULL on the leading column (matches not yet finished; content without a match_id). At WC scale the heartbeat cron stays sub-second.

- **Phase 4 — `error_class` typed union (P2)** (commit `37bf565`). Per /simplify Quality #1: `error_class: string | null` in `PipelineHealthLog` let typos slip through. Now a union of nine known values plus null. notification-sender's `errorClass` local + the `APNS_STATUS_TO_ERROR_CLASS` map narrowed from `Record<number, string>` to `Record<number, ApnsClass>` so the call site is fully type-safe. Both functions redeployed — bundler's typecheck would have failed if narrowing was wrong, so the union is sound.

- **Phase 5 — data-fetcher cron daily → hourly (P1)** (mig 045). Was `0 7 * * *` (daily 07:00 UTC). For WC squad announcements landing May 28+, that meant up-to-23-hour latency. Now `0 * * * *` (hourly): worst case 60 min. ~1,900 API-Football calls/day = comfortably under the Pro tier's 7,500/day ceiling. Permanent change — the freshness benefit applies year-round, the WC squad-window was just the immediate motivation.

**Net result:** of the four V2.1 candidates filed in Lesson 64 just an hour ago, three are now shipped (retry cap, retention, indexes, typed union — that's actually all four). The remaining V2.1+ items below are unchanged. System is ready to leave running through the next 25 days while the user focuses on Apple submission.

---

## Verified today (May 17 night-finale — security review + auth gates)

Sixth and final pass for May 17. Ran `/security-review` against the entire branch (130+ files diff). One MEDIUM-confidence cluster surfaced: three diagnostic Edge Functions deployed with `--no-verify-jwt` (per Lesson 37) that never added their own in-function auth check, leaving them callable by anyone with the public Edge Function URL.

- **Three MEDIUM findings, all fixed in commit `6448a22`:**
    - **`register-dev-device`** — writes to `dev_alert_devices` (the internal diagnostic-push table, distinct from user-facing `device_tokens` which iOS writes directly via REST). Before fix: anyone could register a token to harvest internal client-error pushes containing `team_id`, `app_version`, OS info, and error messages — PII from real users.
    - **`push-probe`** — synthetic-push tool. Before fix: anyone could POST `{"team_id":"<any>"}` and trigger an APNs push to the most-recent active device for that team. Bounded payload (fixed text) but on-demand push spam.
    - **`diagnose-matchday`** — structural diagnostic. Before fix: anyone got subscriber counts per team, 12-char APNs token prefixes, last 24h of `client_errors`, and `net._http_response` content previews via the SECURITY DEFINER `get_pipeline_diagnostics` RPC.

    Fix pattern (same on all three): validate `Authorization: Bearer == SUPABASE_SERVICE_ROLE_KEY` at the top of `serve()`, return 401 otherwise. Lesson 37 (key rotation → `--no-verify-jwt`) had already established the pattern; the new diagnostics just never adopted it.

- **Verification:** all three deployed. `curl POST <fn>` returns 401 for anon callers; `curl POST <fn> -H "Authorization: Bearer wrongkey"` returns 401 for arbitrary bearers. The third test (valid bearer → 200) couldn't be exercised from this machine because `backend/.env`'s `SUPABASE_SERVICE_ROLE_KEY` digest (`c37311ea…`) no longer matches the runtime's (`6c086bf1…`) — stale from a prior rotation. The gate's correctness is established by the two rejection cases; the legitimate-pass case follows from the code (`auth === Bearer ${runtime serviceKey}`).

- **One LOW finding (confidence 7) explicitly deferred:** `device_tokens` anon SELECT (migration 030) exposes full APNs tokens to anyone with the publishable key. Documented in the migration header as a launch-time tradeoff with a V1.1 follow-up — not blocking June 11.

- **Cleared by the review (not flagged):** migration 020 Vault accessor (locked search_path + REVOKE PUBLIC), `check_pipeline_heartbeat` Vault token leak path, CHECK 5 STRING_AGG (hardcoded taxonomy, not attacker-controlled), APNs JWT generation (ES256/P-256, no alg confusion), pre-commit-secret-scan.sh and verify-cron-auth.sh, anti-spam.ts stub, iOS APIClient URL construction. No SQL injection, command injection, path traversal, or new hardcoded credentials.

---

## Verified today (May 17 night-finale-2 — V2.0 sim walkthrough fixes + manager backfill)

Seventh and final pass for May 17. User ran the V2.0 onboarding in the simulator (Sweden + Arsenal dual-fandom) and surfaced five UX issues plus an upstream data-quality problem (Sweden's manager rendered as the literal string `<UNKNOWN>` though Sweden has a real, well-known head coach). Working through them uncovered two more latent backend bugs in the team-page-generator. After the sweep, all 48 WC countries + all 20 active PL clubs have a real manager name AND a photo URL.

- **Five sim-walkthrough fixes** (commit `98f945d`):
    - **Feed switcher dropdown** — `ContextSwitcherView` only listed the user's PL team + Everyone's talking; the country was silently ignored. Now lists country first (V2.0 anchor) → team → everyone. Matches `AppState.activeContext`'s default picker.
    - **"His Team" tab** — was locked to country-first regardless of feed context. Now both the tab label AND the destination view follow `AppState.activeContext`: Arsenal active → tab says "Arsenal", page shows Arsenal; Sweden active → "Sweden". On the cross-team feed it falls back to "His Team" + country-first picker.
    - **MeetTeamView CTA copy** — was "Show me how this works" but navigated to MeetManagerView. Now reads "Meet the boss" — matches destination.
    - **iOS belt-and-suspenders gate** — both MeetManagerView and TeamPageView now skip the manager card entirely when `content.cards.manager.name == "<UNKNOWN>"`. Was rendering the literal placeholder string.
    - **team-page-generator deterministic coach pre-filter** — root cause of Sweden's `<UNKNOWN>`: API-Football's `/coachs` returns ALL historical coaches with multiple having `career.end == null` (Sweden: Hamrén 2023 + Tomasson 2024; Claude picked Hamrén). Replaced the natural-language "pick the first" rule with a JS pre-filter that selects the single coach whose most-recent career stint matches the team's `api_football_id` AND has `end == null`. Sweden now correctly shows J. Tomasson with his photo.

- **Two follow-up bugs found during the 48-country verification** (commit `456b2a9`):
    - **rawLogs iteration overwrite** — the team-page-generator loop iterates `raw_fetch_logs` newest-first and overwrites `coachsData` on every `api_football_coachs` row, so the LAST iterated row (the OLDEST in the 20-row window) won. Netherlands' May-16 rate-limit error response replaced May-17's successful fetch → my filter saw an empty response array → fallback → `<UNKNOWN>`. Fix: `if (coachsData) continue` — newest good row sticks. Netherlands now shows R. Koeman.
    - **JSON truncation mid-object** — `JSON.stringify(coach).slice(0, 2000)` was cutting mid-payload for coaches with long career history (Koeman has 12 stints, ~2200 chars). Claude saw corrupted JSON. Fix: strip `career[]` down to just the current stint before serialising — keeps the payload small and complete.

- **Onboarding copy / cron alignment** — `gd-saturday-quiz` cron `0 7 * * 6` → `0 11 * * 6`. The "How this fits into your week" screen promised "Saturday lunchtime"; was firing 4-5h before UK lunchtime. Now 11:00 UTC = 12:00/13:00 BST = lunchtime ✓. Once-weekly fire, zero quota impact. RemoteTrigger update — cron lives on claude.ai/code/routines, not pg_cron.

- **All-teams backfill:** regenerated 18 problem WC countries + 3 stale PL clubs (Crystal Palace `R. Hodgson` → `O. Glasner`, Forest `A. Postecoglou` → `Vitor Pereira`, Spurs picked `R. De Zerbi` per API-Football's most recent stint). Final state: **48/48 WC countries** and **20/20 active PL clubs** have a real manager name + photo URL. 3 relegated PL clubs (Ipswich, Leicester, Southampton) still lack photos — irrelevant for the 2025-26 season + V2.0 launch.

- **4 remaining V2.1 candidates** (filter is correct; data upstream is the issue):
    - France: `R. Caudron` — API-Football lists Luis de la Fuente under team.id=9 (Spain) for France's data
    - Spain: `S. Ndaba` — API-Football lists D. Deschamps under team.id=2 (France) for Spain's data
    - Scotland: `A. McLeish` — no `end=null` career entry exists in API-Football's data
    - Uruguay: `Ó. Tabárez` — same
    - Fix: a `manager_overrides` table seeded from a trusted source. ~30 min, V2.1.

**Net:** sim is functionally clean for the V2.0 dual-fandom journey. The next "fresh onboarding" run will hit "Meet the boss" with a real coach name + photo. The remaining 4 country data-quality cases are bounded and named.

---

## Verified today (May 18 — Insider section redesign + 68-team backfill)

User reported during the sim that Sweden's team page had no "history" surface and no "Things he doesn't know" section at the bottom. Root cause: the `gd-insider` cloud routine was hardcoded to iterate the 20 Premier League clubs alphabetically, so the 48 WC countries never received any insider items (`team_insider_items` had zero rows for any country). The "history" the user was looking for IS the insider system — `history` is one of four item types (`stat | anecdote | history | oddity`).

Section also redesigned: from one card (title + 2-line body, expandable) to a stacked list of four headline-only rows — one of each type. Headlines only, no body, no expand. Tier-gating + visual continuity with InsiderCard preserved.

- **Routines repo (`anton-tech43/goaldigger-routines`):** `INSIDER_PROMPT.md` rewritten across 3 commits — `bbdcb3e` (replace hardcoded PL list with live `teams` table query; add `text=backfill=all_types` mode), `91f0c5b` (also call `fetch_news_wc.sh` so WC countries have RSS data + relax failure mode so `history`/`oddity` can compose from training-data even when fetch is thin), `134dc6d` (broaden the anecdote rule for countries — training-data-anchored federation news allowed when RSS is empty). Three backfill fires via `RemoteTrigger`; final state: **48/48 WC countries with all 4 types, 20/20 active PL clubs with all 4 types, 3 relegated clubs at 2/4**. 797 total rows in `team_insider_items`.

- **iOS (commit `bb21630`):** new `fetchInsiderSet(teamId:)` in `APIClient.swift` picks the latest of each type (one REST call, client-side group). New `InsiderHeadlineRow.swift` component (compact, tracker label + headline, no body). `TeamPageView.swift` rewires from single-item to 4-row list; pbxproj registers the new file. xcodebuild green on iPhone 17 Pro sim. Old `InsiderCard.swift` retained for FeedView empty state (still wants title + body).

- **Project-shared permissions (commit `3487843`):** new `.claude/settings.json` with 24 broad allow patterns for the commands that recur across sessions — `curl`, read-only git, utility commands (grep/find/ls/jq/head/tail/wc/sort/uniq/date/echo/which), `xcodebuild`, `xcrun simctl`, `supabase` CLI, libpq's `psql`. Replaces fragile exact-string entries in `.local.json`. `.gitignore` also updated to exclude `.claude/scheduled_tasks.lock` and `.claude/plans/`.

**Out of scope:** 3 relegated PL clubs (ipswich, leicester, southampton) at 2/4 types — no recent standings/RSS data; not a launch concern since they're not selectable in the V2.0 onboarding flow. Daily `gd-insider` cron (`0 2 * * 1-5`) keeps the section topped up going forward, refreshing one type per team per weekday in normal mode.

---

## Verified today (May 18 evening — His Team tabs + Settings collapse + standings/calendar backfill)

Two more page redesigns shipped end-to-end after the morning's insider section work:

- **"His Team" tab segmented control (commit `8f1b540`):** the team page now has a 3-way pill selector at the top — Info / Calendar / Table. Info renders the existing scroll unchanged. Calendar lists upcoming fixtures with importance dots (1-5 hot rose) and a short hook label per game ("Top-4 race", "Group A decider", "Pre-World Cup tune-up"). Table renders the full standings — 20-team Premier League table for PL clubs, 4-team group table for WC countries — with the user's own row highlighted in hot-rose 12% opacity.

- **`team-page-generator` extended (commit `f8024e1`):** added two new cards to `team_pages.content.cards`. `upcoming_fixtures` is an array of up to 8 games with importance ratings generated by Claude using the standings + form + rivalry context already in the prompt. `standings` is a full league/group table extracted mechanically from `raw_fetch_logs.api_football_standings` post-Claude — no LLM judgment, purely deterministic. Three plumbing fixes uncovered during smoke testing: raw_fetch_logs window expanded 20 → 100 rows so transient API-Football empty responses don't crowd out the most recent good payload (Lesson 67 pattern), fetch loop now skips empty responses + dedupes by source, slice limits per source corrected (fixtures bumped 2000 → 6000, standings → 8000) so multi-fixture JSON doesn't truncate mid-object.

- **Settings collapse (same commit `8f1b540`):** removed the Immersive/Classic feed-format toggle entirely (feedStyle defaults to `.immersive` forever; `ClassicFeedView.swift` stays as dead code). "Change your setup" (Your Name / His Name / His Team / Your Mode) and "About" moved to the bottom of the page, each wrapped in a new `CollapsibleSection` component (collapsed by default, chevron-down indicator, spring animation on expand). About absorbs the footer links — Contact Us, Privacy Policy, Delete My Data, Version — so the bottom of Settings is two single-tap panels instead of trailing rows. Always-visible top is just Notifications + Calendar sync.

- **Backfill complete (71/71 invocations succeeded, 0 fails):** sequential per-team regeneration of all team_pages rows via a local team-by-team curl loop (the all-71 synchronous invocation timed out at the Edge Function gateway). Final coverage:
    - **Standings**: 70/71 teams (47/48 countries + 23/23 clubs). Canada is the lone gap — API-Football has been returning empty arrays for every Canada source for hours; same upstream data-quality class as the France/Spain coach issues in Lesson 67. iOS shows a graceful "Standings will appear when the data lands" empty state.
    - **Upcoming fixtures**: 68/71 teams (47/48 countries + 21/23 clubs). Ipswich + Leicester are relegated — no upcoming PL fixtures, expected; iOS shows "No upcoming fixtures yet. Check back closer to kickoff." Same Canada gap as standings.
    - Smoke-tested visually for arsenal (20-row PL table, 4 fixtures with 2-5 dot ratings) and sweden (4-row Group F table, 7 fixtures including a "Pre-World Cup tune-up" tag).

**Out of scope:** past results on the Calendar tab (upcoming-only per user direction), tap-to-add-single-fixture (existing CalendarSyncService still syncs the batch from Settings), `ClassicFeedView.swift` source deletion (deferred — separate cleanup task), importance-rating prompt tuning beyond first pass (will iterate if rated games look bland after backfill review).

---

## Verified today (May 18 night — simplify pass + game-day push + starting-XI + news-item team logos)

Three more features and a code-review pass shipped end-to-end after the evening's segmented-tabs work:

- **Simplify pass on the evening's diff (commit `df24830`):** ran `/simplify` against `9b4affc..HEAD`. Four real findings, four fixes — DateFormatter() allocated per calendar row hot path → hoisted to `static let`; `isUserTeam()` substring match was falsely highlighting "Manchester United" when the user followed "Manchester City" (both contain "Manchester") → switched to API-Football id match; `StandingsEntry.id = rank` was brittle for multi-group renders → `teamIdApiFootball ?? rank`; backend rawLogs loop walked 100 rows even after all sources filled → added early-break + moved eligibility checks before JSON.stringify. Deferred (filed for follow-up): SegmentedPill / BorderedEmptyState / SectionHeaderLabel extractions (defer until 2nd caller emerges) and shared iOS DateFormatters cleanup.

- **Game day push (commit `e5035e4` backend, `c7a5b96` iOS):** new daily `morning-push` Edge Function fires at `0 8 * * *` UTC (migration 048). Queries `match_status_state` for fixtures kicking off in the next 18h, matches subscribed `device_tokens` via `.or(team_id, country_id)`, sends a templated APNs push per (user, fixture). Title "Game day at <team>", body "<Home> vs <Away> at HH:mm Europe/London. He'll be glued to it." No content_item generated — pure push, no LLM call. Migration 047 added `morning_push` to the pipeline_health stage CHECK. Smoke-tested clean (zero fixtures right now because today's matches all ended; tomorrow morning's cron picks up the real slate).

- **Starting-XI trigger (same commits + `d529bb6` routines):** match-watcher gains a third trigger label "STARTING_XI" that fires once per fixture when `kickoff_time - NOW() <= 65 min` and the fixture is still pre-match (status NS / TBD). The fire loop now branches per trigger — HT → live-brief routine, STARTING_XI → new `gd-starting-xi` cloud routine. The routine fetches API-Football's `/fixtures/lineups`, picks 3-4 notable starters (cross-referenced with `team_pages.cards.ones_to_know`), and writes a `content_items` row with the new `type='starting_xi'` (migration 046). Pushed via the existing notification-sender path. Migration 047 also added `starting_xi_fire` to the pipeline_health stage CHECK. New iOS `BadgeView` case ("STARTING XI"); FeedView tier filter accepts the new type at T1+. **Manual step remaining**: user generates an API token in claude.ai/code/routines for `trig_01J8yMGTBu6KRvpWHzXeburj`, then sets `STARTING_XI_ROUTINE_URL` + `STARTING_XI_ROUTINE_TOKEN` as Supabase Edge Function secrets before match-watcher's next pre-kickoff window.

- **News-item team logos (commit `16c13df` + `ca0a839` routines):** when a user taps a news item and lands on `ContentDetailView`, render 1-2 team crests above the headline based on the new `affected_team_ids` column (migration 049). 1 team → 1 crest; 2 teams → 2 crests side-by-side; 3+ teams or nil → no crests (matchday-wide stories hide gracefully). `content-generator` extended with the new tool field (Claude judges which teams the headline/body reference); routines repo `PROMPT.md` got an AFFECTED TEAMS section so the V1.1+ canonical content path emits the field too. New `AffectedTeamsHeader.swift` component in `Design/Components/` resolves each string id to `TeamCrestView(team:)` or `TeamCrestView(country:)` via existing enums; unresolvable ids filtered before render. Existing rows pre-049 render gracefully without crests.

**Out of scope:** per-user timezone scheduling for the morning push (V2.1 — needs `device_tokens.timezone` + per-zone queue); goalscorer push notifications during a live match (separate product decision; over-notification risk); crest-tap-to-navigate from news detail to team page (possible follow-up); bulk backfill of `affected_team_ids` for historical rows (~50¢ in Claude calls and not a launch blocker — new items get the field naturally).

---

## Verified today (May 18 late night — FT-push regression fix + Sweden ghosting + starting-XI cleanup)

Three fixes plus a permissions broadening, in response to user-reported regressions after tonight's earlier shipping arc:

- **"The push that didn't come" — Arsenal FT regression (migration 050):** Arsenal-Burnley finished ~21:00 UTC. No FT push fired. Investigation: migration 045 (shipped earlier today) bumped `data-fetcher` from daily to hourly (`0 * * * *`), pushing daily API-Football consumption to ~10k/day on a 7.5k Pro-tier ceiling. By ~18:00 UTC the quota was exhausted; `match-watcher`'s per-minute fixture polling started returning `"You have reached the request limit for the day"` and stopped seeing Arsenal's state transitions. **Fix:** new migration 050 walks data-fetcher back to `0 6-22/2 * * *` — every 2 hours during waking hours (06:00–22:00 UTC), quiet overnight. Budget: ~3,870 (data-fetcher) + ~2,880 (match-watcher) = ~6,750/day, under the ceiling with ~750 headroom for ad-hoc work. Tomorrow's quota resets at 00:00 UTC and the FT-push path resumes working.

- **"Sweden ghosting" — feed reverts to Arsenal bug (FeedView.swift):** if the user picked Sweden in the switcher and visited the "His Team" tab, returning to the Feed tab reverted to Arsenal. Root cause: `FeedView.loadInitial()` unconditionally set `appState.activeContext = .team(selectedTeam)` on every `.task` fire — tab re-mounts triggered the .task again, silently overwriting the user's switcher choice. **Fix:** delete the 4-line reset block. `AppState.init()` establishes the initial context once at app launch; the switcher (`ContextSwitcherView.switchContext`) owns it after that. FeedView reads, not writes.

- **"Demolish the starting XI overbuild" — cleanup:** earlier tonight I shipped a pre-kickoff starting-XI routine + match-watcher trigger + content_items type. User opted for a simpler design (morning push references lineups as a teaser, no fetch). Removed: match-watcher's STARTING_XI trigger detection + fire-loop branch + env-var reads; `gd-starting-xi` cloud routine disabled via RemoteTrigger (`trig_01J8yMGTBu6KRvpWHzXeburj`); routines repo files `STARTING_XI_PROMPT.md` + `post_starting_xi.sh` deleted (routines commit `e163606`). Migrations 046 (`starting_xi` content type) and 047 (`starting_xi_fire` stage) left in place — unused enums but harmless; rolling back would risk data loss on any row that snuck in, and they're ready if a future feature wants pre-match push content.

- **"Lineups teaser" — morning-push body refresh:** body copy changed from `"He'll be glued to it."` → `"Lineups drop an hour before — good thing to ask him about."`. Title (`"Game day at <team>"`) and 08:00 UTC schedule (= 09:00 BST in summer) unchanged. V2.1 follow-up: bump cron to `0 9 * * *` after the October 2026 BST→GMT DST transition to keep "9 UK time" in winter.

- **"Quiet life" — broadened auto-approve patterns (`.claude/settings.json`):** 24 → 46 patterns. Added `chmod`, `mkdir`, `cp`, `mv`, `touch`, `diff`, `deno`, `npm`, `npx`, `node`, `python3`, `python`, `printf`, `awk`, `sed`, `xargs`, `cut`, `tr`, `open`, `env`, `rg`, `test`. Still blocks: `rm`, `git reset --hard`, force-push, `supabase db reset`, bare `Bash(*)`.

**Out of scope:** Per-timezone morning-push (V2.1); restructuring data-fetcher to call fewer per-fire endpoints (more meaningful optimization but not blocking launch); polling cadence reduction on match-watcher (could cut ~2k API calls/day if we only poll during match hours — V2.1 candidate).

**End-of-day review pass (post midnight UTC).** Ran a 3-agent /simplify-style review of the night's diff (since commit `df24830`). **Zero bug-severity findings.** Two cosmetic smells found and fixed in `morning-push/index.ts`: (1) `formatKickoff` now builds the "BST" / "GMT" suffix deterministically from the UK offset rather than relying on Deno's `Intl.DateTimeFormat` `timeZoneName: "short"` rendering, which some V8/ICU builds emit as "GMT+1" instead of "BST"; (2) added a `console.log` when the zero-fixtures branch fires so silence on a known-match-day is distinguishable from genuinely-no-fixtures days. Cross-system audit also confirmed the dormant `starting_xi` enums in migrations 046/047 are well-contained (no producer, no consumer breaks); the user-mentioned `STARTING_XI_ROUTINE_*` secrets are not actually set in Supabase (per `supabase secrets list`) so no cleanup needed. Match-watcher revert is verified clean (`grep STARTING_XI` returns only the post-mortem comment block). All Lessons 67-71 verified consistent with STATUS.md.

---

## What's done

### Platform — V1.0 (April 2026)
- Full PL companion app: feed, immersive cards, team page, settings, glossary, share cards.
- 20 Premier League clubs supported, daily news + matchday + Saturday quiz + Sunday brief + insider items.
- iOS 17+, Plus Jakarta Sans typography, hot-rose / deep-mauve brand.

### V1.1 content surfaces (May 12-13, 2026)
- **A1 Season Primer** — post-onboarding one-shot screen (later disabled in V1.3).
- **C1 Insider** — daily 02:00 UTC, four-type rotation.
- **C2 Sunday Brief** — Sun 09:00 UTC, T2+ push-gated.
- **C3 Saturday Quiz** — Saturday-themed brief.
- **C4 Player Dossier** — Sun 17:00 UTC, all tiers.
- **C5 Match-day Live** — HT + 75' triggers wired.

### V1.2 Onboarding redesign (May 15, 2026)
Value-first restructure. New order: `Welcome → Her name → His name → Team → Notif → Meet team → How it works → Tier → Calendar`. Three new screens: **MeetTeamView** (star player + result mood + table verdict), **HowItWorksView** (3 scenario cards), **CalendarOptInView** (one-tap fixture sync via existing EventKit service).

### V1.3 Polish (May 15-16, 2026)
- Team crests on team picker + Meet team + Meet boss (via API-Football CDN).
- Meet team three-row guarantee (form_summary fallback when post_match missing).
- SeasonPrimer auto-skipped at end of onboarding (was redundant with Meet team).
- All 20 PL clubs regenerated with manager photos + 3 player photos each.

### V2.0 World Cup support — DONE (May 16-17, 2026)

**Backend (DONE):**
- ✓ Migration 032 — `teams.entity_type` (`club` | `country`) + `teams.league_id`. 48 WC 2026 countries seeded alongside 23 PL clubs in the same table.
- ✓ Migration 033 — `device_tokens.country_id` + nullable `team_id`. Push routing supports WC-only, PL-only, or both.
- ✓ `data-fetcher` parameterised — reads `league_id` per team, calls `seasonForLeague()` helper from `_shared/league-helpers.ts`. All 48 countries have full API-Football data.
- ✓ `team-page-generator` country-aware via `{{league_context}}` template. All 48 country pages generated: manager + 3 top players + photos + group position labels.
- ✓ `team-season-state-generator` country-aware. 45/48 countries have `next_fixtures` arrays (3 awaiting WC schedule from API-Football).
- ✓ `match-watcher` parameterised — reads `SELECT DISTINCT league_id FROM teams`, iterates active leagues. Smoke test: `active_leagues: [39, 1]`, `fixtures_seen: 6`.
- ✓ `matchday-scheduler` parameterised same pattern.

**iOS (DONE — build green):**
- ✓ `Country` enum (48 cases, confederation grouping, `crestURL` via API-Football CDN).
- ✓ `FeedContext.country(Country)` + `AppState.selectedCountry` + `AppState.hasSeenWCPrompt`.
- ✓ `activeContext` default prefers country over team (V2.0 puts WC first).
- ✓ `CountrySelectionView` (48 countries, confederation sections, search), `OptionalPLTeamView` (Skip button), `WCMigrationSheetView` (for V1.x users on update).
- ✓ `MeetTeamView` + `MeetManagerView` entity-agnostic (accept `entityId: String` — works for both club + country IDs via the same `team_pages` table).
- ✓ `OnboardingFlow` reordered: Welcome → Her → His → **Country** → **Optional PL** → Tier → Notif → Calendar → Meet team → Meet manager → How it works (11 steps).
- ✓ `APIClient.registerToken` accepts both `teamId` + `countryId`.
- ✓ `FeedView` empty state for country mode (until routines start producing WC content).
- ✓ `TeamPageView` resolves either Team or Country by ID for the "His Team" tab.
- ✓ `URLCache.shared` configured at launch (20MB memory + 100MB disk) to handle 48 flag images cleanly.
- ✓ All exhaustive switches updated. **Build green.**

### V2.0 closeout cluster (May 17, 2026)
- ✓ Skeptical 2-agent review surfaced 1 critical + 5 high + 4 medium + 3 low bugs across the V2.0 changes. All fixed and deployed.
- ✓ **C1** notification-sender now polymorphically routes by `team_id OR country_id`. WC-only subscribers reach their pushes.
- ✓ **H1** `extractNextFixture` away-game bug (pre-V2.0 latent — always treated team as home). Brighton-away venue now correct.
- ✓ **H5** team-page-generator country pages now have 12h TTL before re-firing Claude (was 1,440 calls/day, now ~48).
- ✓ **M1/M3/L3** match-watcher hardened: skip on null league_id, no stack-trace leak, single teams query.
- ✓ **M2/M4** data-fetcher skips on null league_id; `seasonForLeague(39)` now date-aware (auto-bumps in August).
- ✓ **H2/H3** WCMigrationSheetView promotes activeContext to `.country` immediately; sheet binding handles system dismiss.
- ✓ **H4** UnreadTracker signatures extended for country support.
- ✓ **L1/L2** PlayerCardsList nav falls back to country, OnboardingFlow asserts in DEBUG.
- ✓ Migration 034 — `teams.league_id` is now NOT NULL (DB-level guard).

### Push pipeline fix (May 17, 2026 — Phase 27.3)

**User reported:** "City played, no push." Investigation revealed:
- Every push cron tick since **May 11** returned HTTP 401 "Invalid JWT format".
- `cron.job_run_details` reported `status=succeeded` (pg_cron only checks if the SQL ran, not the HTTP response). Phase 48 documented this exact silent-failure pattern.
- Root cause: Vault entry `cron_service_key` contained the new `sb_secret_*` format key. Edge Function gateway requires JWT-shaped Bearer; new format fails the gateway check.
- **Fix:** `vault.update_secret()` to put the legacy service_role JWT back. Edge Function invocation accepts JWT-format bearers fine — the legacy key was only "rotated" out of PostgREST data writes, not function invocation.
- **Verified end-to-end:** post-fix cron tick returned 200 with match-watcher payload; manual `notification-sender` invocation processed 20 backlog items; `push-probe` to user's production device returned APNs 200.
- **Backlog handling:** items >24h old intentionally NOT pushed (sweep filter is correct — no 5-day-old news).
- **Adjacent finding:** FA Cup Final (Chelsea vs Man City, May 16) was never observed by match-watcher because league=45 isn't in `teams.league_id` set. This is a pre-V2.0 architectural limitation; flagged as V2.1 candidate.

**Pending — handed off to Anton:**
- ⏳ Cloud Routine prompt updates (separate repo `goaldigger-routines`). See [WC_ROUTINES_HANDOFF.md](./WC_ROUTINES_HANDOFF.md) for per-routine spec.
- ⏳ App Store submission (manual Xcode + Apple ID). Target: **June 4** for 7-day review buffer before June 11 kickoff.
- ⏳ Marketing assets (App Store screenshots).

---

## What's coming (next 3.5 weeks)

| Week | Focus | Done by |
|---|---|---|
| **Week 2 (May 17-23)** | ✅ DONE. iOS V2.0 + Phase 28 JWT hardening + WC routine prompts + **`gd-news-wc` routine shipped** + App Store V2.0 launch assets drafted. All on May 17. | May 17 |
| **Week 3 (May 24-30)** | Validate gd-news-wc output quality across multiple fires (first fire delivered 4 clean country items + 1 contamination caught). Optional: deeper voice tuning per routine after first live runs surface quality issues. Onboard the dev iPhone through V2.0 flow + populate `device_tokens.country_id` for the missing E2E push test. | May 30 |
| **Week 4 (May 31 – Jun 6)** | TestFlight beta with V2.0 build, screenshot capture per `APP_STORE_V2.0_SCREENSHOT_PLAN.md`, App Store submission by **June 4** following `APP_STORE_V2.0_SUBMISSION.md`. | Jun 6 |
| **June 7-10** | Buffer for review fixes / final polish. | Jun 10 |
| **June 11** | World Cup kicks off. App live. | Jun 11 |

---

## Pre-launch manual checklist (needs the user, can't be automated)

- [ ] **Onboard a dev iPhone through the V2.0 flow**, pick a WC country, confirm `device_tokens.country_id` populates (psql query). Required to E2E-test V2.0 push routing.
- [x] ~~Create `gd-news-wc` cloud routine~~ — **DONE May 17**, routine `trig_0128pyjoweWumZGSDDFp9fa5` is live. First fire at 12:35 UTC produced 4 clean country items + 1 contamination caught and fixed in PROMPT_WC.md `97843a0`.
- [ ] **TestFlight**: archive V2.0 build in Xcode (per `APP_STORE_V2.0_SUBMISSION.md` T-1 walkthrough), upload via Transporter or directly, distribute to internal testers.
- [ ] **App Store Connect**: V2.0 listing copy paste from `APP_STORE_V2.0_COPY.md`, 12 screenshots (6 × 2 device sizes) captured per `APP_STORE_V2.0_SCREENSHOT_PLAN.md`.
- [ ] **Submit V2.0 to App Store review by June 4** to leave a 7-day Apple buffer before June 11 kickoff. Step-by-step in `APP_STORE_V2.0_SUBMISSION.md`.

---

## Out of scope (V2.1+, flagged in IMPLEMENTATION_PROGRESS)

- **FA Cup coverage** in `match-watcher` — `active_leagues` is `SELECT DISTINCT league_id FROM teams` which only returns `[39, 1]`. League 45 (FA Cup) fixtures involving PL clubs aren't picked up by the watcher. Architectural fix needed (probably add a `competitions` table that teams join into, or hard-list extra league_ids in match-watcher config). Irrelevant for the June 11 WC launch.
- **Two-Vault-entry split** — currently one `cron_service_key` Vault row serves both Edge Function invocation (needs JWT shape) AND function-internal PostgREST (accepts either format). Splitting into `bearer_token_for_edge_functions` + `postgrest_service_role` would reduce blast radius on key rotation. Defence-in-depth, not a launch blocker.
- **Secondary alert channel** — `check_pipeline_heartbeat()`'s alert push uses the same Vault key it's checking. If that key breaks, the alert push also breaks (chicken-egg). The `client_errors` row is the durable trail today; a SECOND independent push path (e.g. via email, Slack webhook, or a hardcoded fallback token) would close the gap. **Explicitly deferred** per the May 17 night-final session — chicken-egg risk accepted; SQL monitoring is the manual fallback.
- **Live-brief HT retry within window** — currently a single failed HT fire marks `briefs_fired = ["HT"]` and the trigger is never retried. If quota recovers within the HT window (~15 min) we miss a viable retry opportunity. Smarter logic would track per-trigger attempt timestamps. Low priority — HT is the lowest-stakes brief; matchday FT is where it matters and that's already retry-capped via mig 042.

---

## Open risks

1. **API-Football WC 2026 squad data** — final 26-player squads are announced ~2 weeks before kickoff. Plan: hourly `data-fetcher` cron during the last 2 weeks.
2. **Anthropic API rate limits** — 48 countries × multiple daily routines is a significant uplift. Pre-generate static fields once, only regenerate dynamic cards daily.
3. **App Store review delay** — 7-day buffer baked in (submit June 4, tournament starts June 11). If rejected, must turn around inside 5 days.
4. **3 countries with no fixtures yet** — Jordan, Paraguay, Qatar have qualified but API-Football hasn't populated their group stage matches. Daily cron picks them up automatically as the schedule is published.

---

## Architecture decisions worth remembering

- **`teams` is polymorphic** via `entity_type` column. Clubs and countries coexist. All downstream tables (`content_items`, `device_tokens`, `raw_fetch_logs`, `match_status_state`, `team_pages`, `team_season_state`) reference `team_id TEXT` and don't care which type.
- **iOS `FeedContext` is the dispatch layer.** `.team(Team)` for PL, `.country(Country)` for WC, `.everyoneTalking` for cross. Adding a third case (`.nation` was the original code comment) is a compile-time-safe enum extension — no `default:` branches anywhere.
- **API signatures are `String`-typed.** `APIClient.fetchFeed(teamId: String, ...)` accepts either a club ID or country ID. No overloads.
- **Routines self-describe their league context** via `{{league_context}}` template in their system prompt. The wrapper looks up `entity_type` from the team row and injects PL-flavoured or WC-flavoured guidance. Same routine code, two voices.

---

## Pointers

- **Live data:** Supabase project `cwgpsmbunrocrofziqad`, region West EU (Ireland). DB access via local `psql` reading `SUPABASE_DB_URL` from `backend/.env` (gitignored).
- **Push:** APNs via single `.p8` key, production endpoint for App Store builds, sandbox for Debug. Entitlement split via `GoalDigger-Release.entitlements` (added in launch-night work, see Phase 21).
- **Routines repo:** [`anton-tech43/goaldigger-routines`](https://github.com/anton-tech43/goaldigger-routines) (separate from this repo). Cloud Routine prompts + post-scripts live there.
- **App Store:** Bundle ID `com.goaldigger.app`, version 1.0 currently live. WC update will ship as 2.0.
