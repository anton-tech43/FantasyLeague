# Connection seat: from the feed to her lock screen

Commit 376d3f2, 2026-10-29 ~15:30 UTC. All read-only: `db-health.sh` (all clear, 1 WARN on content),
`verify-push-rules.sh` (18/18 OK), `verify-push-eligible.sh` 3 h and 7 days (PASS, 47 items),
`verify-cron-auth.sh` (OK). None of the four writes anything. I also ran SELECTs via `scripts/sql.sh`
and `supabase functions list`, which only reads. Census ids come from `$S/parts/*.csv`. LOCK and MD have no
census part yet, so I name those elements in words.

**What limits the 7-day view.** `cron.job_run_details` keeps only **2 days**
(`cron_job_run_details_retention_sweep`, `end_time < now() - 2 days`) and `net._http_response`
keeps about 6 hours. For 10-22 to 10-26 I rebuilt the picture from `pipeline_health` (30 days),
`match_status_state`, `client_errors` and `live_activity_tokens`.
Edge Function logs were not read; I had no access to them.

## The week in one paragraph

The 21–25 October outage (OUTAGE_LESSONS.md, 4 days) is the week's main event. On
10-24 `pipeline_health` has 27 fetch rows and 4 posts. On a normal day it has about 200 of each.
Match-watcher was alive 13:24–14:42 UTC and then went dark. Here is what that meant on her phone:
- **Arsenal v Everton**: 63 Arsenal devices got the kickoff push and the 1-0 goal, then nothing.
  No second goal, no half time, no full time. The next word was the Sunday brief, 23 hours later:
  "Arsenal beat Everton 2-0 Saturday".
- **Chelsea v Spurs**: got nothing at all. No push and no Live Activity (`briefs_fired = []`, `la_started = f`).
- **Coventry v Fulham** went the same way as Arsenal v Everton.
- No 07:00 kickoff reminder on Saturday. Sunday's went out at 09:41 instead of 07:00.

Since 10-25 10:00 the path has been clean.

## Findings

**C1. MEDIUM. The live card keeps a dead score and a clock that runs forever when the backend is unreachable.**
FEED-01-19, FEED-02-09. `FeedView.swift:309-314` keeps the last brief on any poll error.
`LiveMatchCard.swift:163-174` (`RunningMinute`) adds wall-clock minutes from an anchor and has no ceiling.
- What she sees during an outage like 10-24: "LIVE · 42' / 90", then 67', then 140', still 1-0, with
  the dot pulsing. A frozen live score is the worst way this app can look broken, because it looks
  right until he says the real score.
- Checked by reading the code against 10-24's real timeline (Arsenal frozen at 1-0, 42').
- Fix: record the time of the last successful poll. After 3 minutes without one, stop the clock and
  show "Score paused, reconnecting". After 10 minutes, hide the card.
- **SUSPECTED** (code; no outage could be replayed).

**C2. MEDIUM. Live Activities and the 07:00 reminder send without leaving a record.**
LOCK (Live Activity start/update/end; the kickoff-time push).
- `match-watcher` `sendAll` (index.ts ~2097-2178) writes no `pipeline_health` row for the start,
  any update or the end.
- `matchday-reminder/index.ts` has 0 references to `pipeline_health`. Its result lives only in
  `net._http_response`, which is gone after about 6 hours.
- So I **cannot measure** what I was asked to measure: priority-10 sends per match, whether a Live
  Activity started, whether it ended, and whether the reminder was delivered.
- This also means the panel's push timelines (staging step 4) are missing every 07:00 reminder.
- The only proxy is update tokens registered per push-to-start audience. For Fleetwood v Arsenal
  that is 24 update tokens against 73 Arsenal push-to-start tokens (33%). Liverpool v Chelsea:
  6 of 13. Liverpool v Brighton: 2 of 8. Whether the rest were refused by iOS, turned off by her,
  or stale tokens is unknowable today.
- Fix: one aggregate row per fixture and event, `stage='apns_send'`, target
  `la_start:/la_upd10:/la_upd5:/la_end:<fixture>`, holding sent/failed. Also one row per reminder run,
  `target='reminder:<team>:<kickoff>'`.
- **CONFIRMED** (grep, plus zero such rows in 7 days).

**C3. MEDIUM. A shootout can go past the priority-10 target at the worst moment.**
LOCK (Live Activity during penalties).
- `index.ts:2071`: "each shootout kick is a full update" at priority 10.
- My estimate per match is start + HT + 2H + goals + end, which is 4 plus the goals. That is well under
  15 for a normal game. City v Brighton (4 goals, then pens) would be about 8 before the shootout.
  If `score.penalty` moves live, a shootout adds 10–14 more, all inside about 10 minutes.
- Whether it moves live is exactly what the new `et_trace` rows are meant to find out.
- What she would see: a throttled activity freezes the shootout score and the result arrives late.
- Fix: send the kicks at priority 5 and keep the final shootout result at 10.
- **SUSPECTED** (code plus arithmetic). Tonight settles it if Everton v Newcastle goes to penalties.

**C4. MEDIUM, watch tonight. The match-watcher change has never seen a live match, and the minute on
App Store phones now depends on priority 5.**
- `supabase functions list`: match-watcher **v105 was deployed 2026-10-29 12:59 UTC**, so today, not
  last night. It includes the held-tie logic, the extra-time push, shootout notes, and minute-only
  updates at priority 5 (df4fe23).
- Every production phone runs 2.2. Its widget shows a fixed `elapsed`, so its minute now moves only
  when iOS chooses to deliver a priority-5 update.
- Tonight's tie is a small test (Round of 16, so the quiet tier applies):
  - 2 devices: one Newcastle at tier 1, one Arsenal+Newcastle at tier 2;
  - 4 push-to-start tokens;
  - `poll_leagues('19:15')` returns league 48 as expected.
- After full time, check three things: `et_trace:1640385` in pipeline_health; that `briefs_fired`
  holds no FT_PUSH before PEN/AET; and, on a 2.2 phone if one is at hand, whether the minute kept
  pace.
- **SUSPECTED** (deploy time CONFIRMED).

**C5. LOW. The error copy blames her connection when the fault is ours.**
- FEED-02-04: "Probably your connection. Give it another go."
- FEED-06-39 hedges with "or your connection dropped", which is acceptable.
- In the last 5 months there were 4 outages, the longest 7 days. Each time this told her to check her wifi.
- Fix: "We couldn't load this just now. Give it another go."
- **CONFIRMED** (copy, plus the outage table in OUTAGE_LESSONS.md).

**C6. LOW. When the backend hangs rather than refuses, a tier 2+ feed can spend ~20 seconds on the skeleton.**
FEED-02-01.
- The feed fetch times out at 10 s. Then, because `teamItems.isEmpty`, the insider fetch
  (`FeedView.swift:870`) waits another 10 s before `isLoading = false`.
- This only bites with an empty cache and a backend that accepts TCP but never answers, which was
  the exact signature on 10-24.
- Fix: skip the insider fetch when the feed fetch threw.
- **SUSPECTED** (code).

**C7. LOW. A cached club page keeps a past fixture as the next one.**
TEAM-02-01, TEAM-01-23.
- `TeamPageCache` never expires for display; `isStale` only triggers a refetch.
- `comingUpLabel` (`TeamPageView.swift:1192`) gives a negative `daysUntil` "This week:".
- So when she opens the page offline, or during an outage, after kickoff and before a fresh page
  arrives, a played match is introduced as coming up.
- Fix: if the kickoff is more than 3 h past, label it "Last game:" or hide the card until the
  refresh lands.
- **SUSPECTED** (code).

**C8. LOW. The reaper writes "abandoned" for matches that finished.**
- The `match-status-reaper` cron sets `status='ABD'` on anything unfinished four hours after kickoff.
- 1557437 (Arsenal v Everton, "ABD 1-0 at 42'"), 1557440 and 1557439 are stored as abandoned.
- The Sunday brief (verify-push-eligible output) says Arsenal won 2-0.
- No surface I found shows the status today (Arsenal's `last_match` is Fleetwood), but any future
  reader of `match_status_state` will believe it.
- Fix: write `'UNK'` (not observed) instead of `'ABD'`. Data seat, for the fact itself.
- **CONFIRMED** (SQL).

**C9. LOW. More push-to-start tokens than devices.**
- There are 123 active production push-to-start tokens and 85 active devices; Arsenal has 73 against 63.
- `live_activity_tokens` has no link to a device, so a rotated token stays active until it fails at
  APNs or reaches 90 days.
- If iOS still honours an old token, one phone starts two activities.
- Fix: send `device_tokens.id` (or the APNs token) with `register_la_token`, and deactivate the
  previous push-to-start token for that device.
- **SUSPECTED**.

**C10. LOW. Small monitoring problems.**
- Three `cron.job_run_details` rows have been stuck in `connecting` since about 10-25
  (runids 197507, 247156, 247157). They have `end_time NULL`, so the retention sweep never removes them.
- The `routine_post` failure excerpt is cut at 200 characters, before the name of the violated
  constraint. 30 posts were rejected with 23514 in 30 days. All were retried, and every club got its
  full-time article.
- STATUS.md says `dev_alert_devices` is empty. It holds 1 row since 10-25.
- `gd-heartbeat`, the only monitor that runs outside the database, is a claude.ai routine on the
  account that is closing. When that account closes, Anton loses the outage alarm along with the
  content. The REBUILD.md order should rebuild it first.
- **CONFIRMED**.

**Context, already fixed. On 10-27 the full-time push called Fleetwood v Arsenal a draw.**
- The push went at 21:59 to 62 devices, while `last_match` read "Honours even".
- The tie went to penalties and Arsenal went out.
- The After card has since been corrected by hand ("Out of the League Cup on penalties…").
- `match_status_state` still says `FT 1-1`.
- v105 holds level single-leg ties until PEN/AET, which is the fix. Tonight is its first test.

## Proposed verdicts (connection-facing)

| id | Verdict | How / why |
|---|---|---|
| FEED-02-01 loading skeleton | Keep | Shows only on a cold load with no cache; 10 s ceiling per request since the 09-21 outage. Iterate the second 10 s per C6. |
| FEED-02-02 cached feed | Keep | The one reason the app did not look dead to existing users during 10-24: SwiftData cache, 30 days. |
| FEED-02-03 "That didn't load." | Keep | Short and true. |
| FEED-02-04 "Probably your connection…" | Iterate | C5: never blame her; "We couldn't load this just now. Give it another go." |
| FEED-02-05 / FEED-06-40 / TEAM-01-07 Try again | Keep | The only way out of an error state. |
| FEED-01-48 pull to refresh | Keep | The feed also refreshes on return from background, so it is a backup, but a cheap and expected one. |
| FEED-01-19 live match card | Iterate | C1: stop the clock and say so after 3 min without a poll; hide after 10. Keep the 60 s near / 10 min far polling. |
| FEED-02-07/08 "Quiet on his end." | Keep | Correct on a no-news day; the live card is no longer hidden behind it (FEED-02-09). |
| FEED-06-37..39 article loading / error | Keep | The "or" in the copy keeps it honest. |
| TEAM-01-05 skeleton / TEAM-01-06 error | Keep | Cache-first, one quiet retry; worst case about 21 s, then the error. |
| TEAM-01-08 warm placeholder | Keep | Never rendered (all 20 clubs have a row), but without it a 200 with no row is a blank screen. |
| TEAM-02-01 when-label | Iterate | C7: a kickoff in the past is never "This week:". |
| FEED-01-13..18 notifications-off banner | Keep (provisional) | Pushes are the product; 85 active tokens, no count of denied users until 2.4 tracking. |
| ONB-10-08 "If your iPhone asks about Live Activities, say yes." | Keep | Only 33–75% of push-to-start audiences produced a running activity (C2 proxy); the only lever the app has. |
| ONB-13-07 calendar fetch failed | Keep | Degrades into a promise rather than a dead end. |
| SET-11-01/02 Couldn't Delete | Keep (can't delete) | Apple's rule; honest copy. |
| LOCK: Live Activity start alert "It's kicked off." | Keep | The single alert that lights up the activity she switched on. |
| LOCK: Live Activity minute (2.4 running clock, "LAST UPDATE" when stale) | Keep | Removes about 90 priority-10 sends a match; stale state is honest after 90 min. |
| LOCK: Live Activity shootout notes | Iterate | C3: kicks at priority 5, the final result at 10. |
| LOCK: Live Activity end, 30 min dismissal + la-end-sweep | Keep | 0 active update tokens now; 10-24 leftovers cleared 10-26 23:37. |
| LOCK: 07:00 kickoff-time push | Keep, Iterate logging | Earns its place (PUSH_RULES); C2: write a record of every run. |

## What holds up

- **Infrastructure.** Postgres and PostgREST are healthy (0.3–0.75 s). match-watcher's cron ran
  1440 of 1440 minutes over the last 24 h, and 3589 of 3589 over 2.5 days, with zero failures.
  `net._http_response` is 0 MB with 9 rows, vacuumed every 6 h. `cron.job_run_details` is 4 MB.
  15 of 60 connections are in use, with no lock waits.
- **Locks.** anon can reach only the app's RPCs. The cron key is a random 80-character secret, and the
  200s in the last 15 minutes come from the hourly sweep.
- **APNs, 7 days.**
  - 63 aggregate rows and 792 sends, of which 1 failed: a development token on 10-27 06:44, flagged
    `BadDeviceToken` and deactivated in the same second.
  - No feed-only item pushed. Tier floors match PUSH_RULES. Tonight's Round-of-16 tie correctly gets
    no kickoff, half-time or reminder push.
- **Goal latency.** The push arrives about 1 minute after the feed's minute wherever the clock maps
  cleanly (Liverpool 17' → +1, City v Brighton 30' and 40' → +1 and +0, Liverpool v Chelsea 40' and
  43' → +1, Fleetwood 21' → +1).
- **Full time and the After card.** `last_match` is written in the same tick as the full-time push
  (identical timestamps in all 11 rows). The tap forces a page refresh, so the push lands on After,
  not on Before.
- **Quota.** API-Football: about 1,200 data-fetcher rows a day plus the watcher's poll-only-near-kickoff
  calls, comfortably under the 7,500 Pro cap. No `errors` objects in four days. Rate-limited empty
  200s are excluded from `poll_leagues()`.
- **The app on a bad network.**
  - 10 s timeouts everywhere, 8 s on the live polls.
  - Feed, club page and Matchday all read their caches first. Matchday falls back to Before (bundled
    content) and never shows a spinner.
  - A poll error never blanks a visible card.

## Summary

1. The path from feed to lock screen is healthy now. db-health, push rules, push-eligible (7 days) and cron auth all pass, and 791 of 792 APNs sends succeeded; the one failure was a dead token, removed at once.
2. The week's real failure was the 21–25 Oct Supabase outage: on 10-24 Arsenal (63 devices) lost every push after 1-0, Chelsea v Spurs got nothing, and the reaper now stores those finished games as "abandoned".
3. In the app, the worst way it can look broken is a frozen live score with a clock that keeps running past 100' (C1); the error copy also blames her connection for our outages (C5).
4. Live Activity and 07:00 reminder sends leave no record, so priority-10 counts and how many activities started cannot be measured (proxy: 33% for Fleetwood v Arsenal). One aggregate row per fixture fixes that.
5. match-watcher v105 went live at 12:59 UTC today and has never run against a live match. Tonight's Everton v Newcastle (2 devices) is its first test: check `et_trace:1640385`, that no full-time push goes before PEN/AET, and how many priority-10 sends a shootout takes.
