/* model6.js — what has actually gone wrong here, in order.
   Faster than any architecture diagram for working out where the danger is.
   Every row is dated and sourced. The colour is the point: orange means NOTHING
   CAUGHT IT — it ran wrong until a person happened to look. */

const M6_COLS = [
  { x: 0,   w: 168, label: "When", hint: "start → noticed" },
  { x: 228, w: 362, label: "What broke", hint: "and who found it" },
  { x: 650, w: 496, label: "What it produced", hint: "the rule that outlived it" }
];

const M6_BANDS = [
  { label: "May 2026 · the credential and the silence", from: 1,  to: 6,  note: "Six weeks in which the push pipeline was dead twice, and both times the scheduler reported success." },
  { label: "June–July · the World Cup",                 from: 8,  to: 12, note: "The tournament ran at a scale the checks had never seen. Three defects survived weeks because the thing that would have caught them did not exist." },
  { label: "August–September · the quiet month",        from: 14, to: 19, note: "The worst stretch. A database starved, a whole league went unwatched for 17 days, and the alarm for silent failure crashed in the moment it was needed." },
  { label: "October · content that was true and wrong", from: 21, to: 26, note: "Nothing broke in the infrastructure. The defects moved into the writing, and into the checks themselves." }
];

const I = (id, r, c, k, s, l, sub, p) => ({ id, c, r, k, s, l, sub,
  p:{ w:p.w, t:p.t||"—", rd:p.rd||"—", wr:p.wr||"—", f:p.f||[], g:p.g||"—", x:p.x||[] } });

const M6_NODES = [
/* May */
I("i.jwt",  1, 0, "code","live","7–11 May","noticed after 4 days",{ w:"The service-role key sat in a public repository." }),
I("i.jwtb", 1, 1, "guard","live","A key that bypasses every row-level rule, committed in plain text","found by an automated security review",{ w:"Migrations 015–017 embedded the bearer token inline in cron bodies instead of reading it from the vault. Nothing user-visible; a compromise audit over the window found no exploitation.", t:"7–11 May 2026.", g:"It came back. In October a QA pass found the same key still authenticated every server-only function — the May rotation had closed its database path and not its gateway path. Read incidents 1 and 26 as one story.", f:["IMPLEMENTATION_PROGRESS.md"] }),
I("i.jwtw", 1, 2, "code","live","get_cron_service_key(), and a review before every merge","later: a random 80-character key, rotated in both stores at once",{ w:"The vault accessor pattern, and the habit of running a security review before merging to main.", t:"—", f:["scripts/rotate-cron-key.sh"], x:["cron.mw"] }),

I("i.mw",  2, 0, "code","unheard","11 May","match-watcher had NEVER worked",{ w:"Not a regression. It had never once produced content." }),
I("i.mwb", 2, 1, "guard","unheard","No matchday cards, no full-time push, ever — and the table was empty for weeks","found by a throwaway diagnostic written to look",{ w:"The API-Football URL omitted the required season parameter, and `fixturesJson.response ?? []` swallowed the empty response. Behind that, the teams table was missing the three promoted clubs, so every fixture was skipped anyway.", t:"Discovered 2026-05-11.", g:"Two silent-failure patterns in one bug: a default that hides an error, and a lookup that quietly matches nothing. Both now fail loudly.", f:["IMPLEMENTATION_PROGRESS.md"] }),
I("i.mww", 2, 2, "code","live","A loud 500 on the wrong response shape, and diagnose-matchday","plus “BUMP THIS EACH AUGUST” on the season constant",{ w:"The diagnostic that found it was kept. It is still the thing to run when the live pipeline looks wrong.", t:"—", x:["edge.diagnose"] }),

I("i.dead",  3, 0, "code","unheard","11–17 May","6 days of total push outage",{ w:"Zero pushes of any kind." }),
I("i.deadb", 3, 1, "guard","unheard","Every push failed, and the scheduler reported success all week","found because a user said “City played today, no push”",{ w:"The vault held a key in the new secret format; the gateway demanded the JWT shape and returned 401 to every tick. `cron.job_run_details` said succeeded — because the SQL that makes the HTTP call did run fine. The call inside it did not.", t:"11–17 May 2026. The second outage of this class in six days.", g:"The standing rule from this: a scheduled job's success is two tables, not one. Check cron.job_run_details AND net._http_response. A job can succeed at launching a request that fails.", f:["IOS_GOTCHAS.md"] }),
I("i.deadw", 3, 2, "code","live","verify-cron-auth.sh, and later rotate-cron-key.sh","which writes both stores back to back and compares digests",{ w:"Two scripts, because the failure was a mismatch between two places that had to agree.", t:"—", f:["scripts/verify-cron-auth.sh","scripts/rotate-cron-key.sh"] }),

I("i.spam",  4, 0, "code","live","17 May","blocked everything it judged",{ w:"Scattered “I never get a push for X” with no pattern." }),
I("i.spamb", 4, 1, "guard","live","The anti-spam check compared each item against itself","found by a human during a live match",{ w:"The post script inserts the row as published before the check runs, so the query for “most recent published item for this team” returned the row it was about to judge. The gap was always zero. It always blocked.", t:"2026-05-17.", g:"Never trust ORDER BY ts DESC LIMIT 1 to find anything but the row you just touched.", f:["IOS_GOTCHAS.md"], x:["x.spam"] }),
I("i.spamw", 4, 2, "code","live","Anti-spam deleted entirely","tier filtering was enough",{ w:"The feature went; the rule stayed.", t:"—", x:["x.spamb"] }),

I("i.cost",  5, 0, "model","live","20 May","$4–5 in minutes",{ w:"The API balance hit zero." }),
I("i.costb", 5, 1, "guard","live","A 50-team backfill looped a paid model call per club","for work that was already pure SQL",{ w:"The data was sitting in the fetch cache the whole time.", t:"2026-05-20.", g:"The failure mode is misleading: a depleted balance surfaces as IDLE_TIMEOUT with no health row, which reads as a broken function rather than an empty wallet.", f:["BACKFILL_RULES.md"], x:["edge.tpg"] }),
I("i.costw", 5, 2, "code","live","BACKFILL_RULES.md and its decision tree","SQL → routine → Edge, plus a code guard refusing bulk without a team_id",{ w:"One of the two hard rules in CLAUDE.md.", t:"—", x:["d.backfill"] }),

I("i.triv",  6, 0, "model","live","22 May","first live fire",{ w:"Celebrity trivia on lock screens." }),
I("i.trivb", 6, 1, "guard","live","The model read a rule in the prompt and ignored it","subscribers got Hamilton crying at Arsenal, and Prince William drinking with Villa players",{ w:"The gate existed — in the prompt, where nothing enforced it.", t:"2026-05-22 06:30 UTC, the first live run after the rule was written.", g:"This produced the house pattern: a soft rule in the prompt, hard enforcement at the boundary. Every one of the seven downgrades in PUSH_RULES.md exists because of this shape.", f:["/Users/anton/goaldigger-routines/post_news.sh"], x:["g.postnews"] }),
I("i.trivw", 6, 2, "code","live","The first deterministic force-downgrade","audited against the prior 18 hours for false positives",{ w:"And the convention of auditing a new guard against real recent content before shipping it.", t:"—", x:["d.push"] }),

/* June–July */
I("i.imm",  8, 0, "model","unheard","11 June – late July","unnoticed for six weeks",{ w:"412 half-rendered cards, 150 of them pushed." }),
I("i.immb", 8, 1, "guard","unheard","Every Edge-generated card shipped with its headline and context missing","a notification, then half a card",{ w:"A lowercased grey sentence with nothing underneath it.", t:"2026-06-11 to late July.", g:"Stated plainly in the test file that now exists: nothing on the Edge side validated anything.", f:["backend/supabase/functions/_shared/consequence-templates.test.ts"] }),
I("i.immw", 8, 2, "code","live","Deno tests over every consequence type","the validation IS the test file",{ w:"There was no validator to fix, so the tests became one.", t:"—" }),

I("i.429",  9, 0, "code","live","15 June – 10 July","hidden by small audiences",{ w:"8 of 10 kickoff pushes lost." }),
I("i.429b", 9, 1, "guard","live","Parallel sends each minted their own APNs token while the cache was cold","countries with one or two followers were unaffected, which hid it",{ w:"Sweden delivered 2 of 10, then 2 of 8, then 3 of 7, all 429 TooManyProviderTokenUpdates. Goals and full-time on the same matches went 10 of 10.", t:"2026-06-15 to 2026-07-10.", g:"Verify a push fix against the next match's send rows, not against the code. The code looked right both times.", f:["SJALVRANNSAKAN_2026-09.md"], x:["sf.push"] }),
I("i.429w", 9, 2, "code","live","Single-flight token minting with retry","and a rule about how to verify a push fix",{ w:"One token minted at a time instead of one per parallel send, with a retry behind it. The lasting part is the verification rule: a push fix is proved by the next match’s send rows, not by reading the code — the code looked right both times it was wrong.", t:"—" }),

I("i.wcrem",  10, 0, "code","unheard","24 June – 19 July","the whole knockout stage",{ w:"No matchday reminders at all." }),
I("i.wcremb", 10, 1, "guard","unheard","A reminder read a field that was written once and never again","six reminder rows in total, all in June",{ w:"team_season_state.next_fixtures held only the group games. France–Sweden on 30 June got nothing.", t:"2026-06-24 to 2026-07-19.", g:"Routine-written state must not be a reminder's only source. A deterministic one already existed — the fixture cache, refreshed every two hours. The same mechanism was later found live for Premier League clubs.", f:["SJALVRANNSAKAN_2026-09.md"], x:["store.seasonstate"] }),
I("i.wcremw",10, 2, "code","live","Read the fixture cache, not a routine's snapshot","the deterministic source was always there",{ w:"The reminder now reads the fixture cache, which is refreshed every two hours by a job that does nothing else. The rule: a reminder must not depend on a snapshot some other routine happened to write once.", t:"—", x:["store.rawlogs"] }),

I("i.sb",  11, 0, "model","unheard","5–19 July","three weeks, found by replay",{ w:"55 consecutive Sunday Briefs with no voice." }),
I("i.sbb", 11, 1, "guard","unheard","The app's whole voice missing — bare lowercase sentences, no headline","nobody noticed until a retrospective replay in September",{ w:"Through the entire knockout stage.", t:"2026-07-05 to 2026-07-19, found 2026-09.", g:"A rule that lives only in the prompt is not a rule. Every PROMPT.md rule with nothing enforcing it now hard-fails in the post script — including “a news card is never published without its own girl reference”.", f:["/Users/anton/goaldigger-routines/post_news.sh"] }),
I("i.sbw", 11, 2, "code","live","The September guard set","written by replaying 1,266 cards",{ w:"A corpus replay is now how a guard gets calibrated before it ships.", t:"—", x:["rt.tests"] }),

I("i.pii",  12, 0, "guard","live","17 June","found by a review, not a report",{ w:"The shipped key could read every device row." }),
I("i.piib", 12, 1, "guard","live","A device-to-fandom graph, readable with the key inside the App Store binary","and writable: a PATCH could repoint someone's clubs",{ w:"Migration 030 granted anon SELECT and the update policy was USING(true). Nothing observed, but the data was one request away.", t:"Live from 2026-06-17.", g:"Nobody granted it on purpose. Supabase's default privileges hand anon the full set on every new object in public.", f:["AUDIT_FINDINGS.md"] }),
I("i.piiw", 12, 2, "code","live","Two SECURITY DEFINER RPCs, and anon reads closed","the app writes through three functions and nothing else",{ w:"Reads closed, writes funnelled through three SECURITY DEFINER functions. The app can now call exactly three things and read thirteen tables, and nothing else — which is why a new database function without its own explicit revoke is treated as a live finding here, not a tidiness issue.", t:"—", x:["api.postgrest"] }),

/* Aug–Sep */
I("i.db",  14, 0, "code","unheard","9 Aug – 6 Sep","a week of total silence",{ w:"The database starved, then stopped." }),
I("i.dbb", 14, 1, "guard","unheard","No content, no pushes, no reminders for a week — and the feed kept showing old items","a human rebooted it on 6 September",{ w:"Last routine post 29 August 11:17. Last cron run 30 August 16:32. The archive sweep died too, so nothing even looked empty.", t:"Degrading from 2026-08-09, silent from 2026-08-30.", g:"Probable cause, not proven — the statistics were zeroed by the unclean shutdown. Constant write pressure on the smallest instance: match-watcher firing 1,440 times a day regardless of fixtures, the fetcher polling 48 dormant countries every two hours, and two unswept tables at 169 MB and 88 MB.", f:["SJALVRANNSAKAN_2026-09.md"], x:["cron.sweeps"] }),
I("i.dbw", 14, 2, "code","live","Retention crons on every log table","and a runbook entry for the exact symptom",{ w:"Unhealthy plus connect timeout means a fast reboot, then check the last cron start time.", t:"—", x:["cron.sweeps"] }),

I("i.pl",  15, 0, "code","unheard","21 Aug – 6 Sep","17 days, found by audit",{ w:"The Premier League went unwatched." }),
I("i.plb", 15, 1, "guard","unheard","28 fixtures played, one row recorded — and that one abandoned by the reaper","12 devices got no goal, half-time or full-time pushes all August",{ w:"Database latency exceeded the 5-second default on the HTTP call, which no cron command overrode. Then two code sites failed silently: a database error on the prior-state lookup was treated as “first observation”, and an abort left no trace.", t:"2026-08-21 to 2026-09-06.", g:"The deepest lesson here: match-watcher wrote a health row for events, never for its own run. So 27 days of doing nothing looked exactly like 27 days of nothing to do. A job must log that it ran, not only what it did.", f:["SJALVRANNSAKAN_2026-09.md"], x:["edge.match-watcher"] }),
I("i.plw", 15, 2, "code","live","A 30-second timeout, and one aggregated row per run","so silence becomes visible",{ w:"A 30-second timeout on the scheduled call, the prior-state lookup error treated as an error instead of as “first observation”, and one aggregated health row per run. That last one is the real fix: before it, a job doing nothing and a job with nothing to do were the same shape in the log.", t:"—", x:["store.health"] }),

I("i.alarm",  16, 0, "guard","unheard","25–30 Aug","the alarm for silence, silent",{ w:"The check that would have caught the outage crashed." }),
I("i.alarmb", 16, 1, "guard","unheard","“pg_cron HTTP health degraded” — the one check that mattered — errored 13 times","on a format string",{ w:"Postgres `format()` supports only %s, %I and %L. The check used %.0f%%.", t:"2026-08-25 to 2026-08-30.", g:"The second time an alarm suffered the exact bug it was built to catch. The first was a 2026-05 heartbeat using the same broken setting-lookup that had already broken match-watcher, returning NULL silently forever.", f:["SJALVRANNSAKAN_2026-09.md"] }),
I("i.alarmw",16, 2, "code","live","Test an alarm by faking the failure it watches for","not by reading it",{ w:"The format string fixed, a statement timeout added — and the requirement that an alarm is tested by faking the failure it watches for. Reading an alarm’s code is not testing it; this is the second alarm here that proved that.", t:"—", x:["cron.hbcheck"] }),

I("i.wconly",  17, 0, "code","unheard","6 Sep","found by Anton, during a match",{ w:"Live pushes existed only for national teams." }),
I("i.wconlyb", 17, 1, "guard","unheard","During Arsenal–Chelsea, Arsenal's nine followers got nothing at all","not at kickoff, not at 1-0, not at 1-1, not at half time",{ w:"The entire live block was wrapped in a check for the World Cup league id, names came from a World Cup table, and the recipient query matched on country only. The store listing promised half-time and full-time briefs, and it had been true for Sweden in June and for no club ever.", t:"2026-09-06.", g:"A feature built for one entity type does not generalise by itself, and the promise in the store listing is the spec.", f:["SJALVRANNSAKAN_2026-09.md"] }),
I("i.wconlyw",17, 2, "code","live","Fixed the same evening, verified at full time","9 of 9 sent",{ w:"And Premier League matchday articles made feed-only, so they do not push twice.", t:"—", x:["g.pushgate"] }),

I("i.luton",  18, 0, "model","live","6 Sep","found by Anton reading a card",{ w:"A result naming a club not in the division." }),
I("i.lutonb", 18, 1, "guard","live","A Chelsea article claimed wins over a team that had been relegated","the model reached for last season's memory",{ w:"“Brighton, Luton, and Fulham”. Luton were not in the Premier League.", t:"2026-09-06.", g:"Refined twice since. The cup exemption is keyed to the league id recorded in our own match state, not to the model writing the word “cup” — because a hallucinated league id would otherwise switch the guard off for exactly the card it exists for.", f:["/Users/anton/goaldigger-routines/post_news.sh"], x:["g.postnews"] }),
I("i.lutonw",18, 2, "code","live","A hard reject on results naming a non-league club","grounded in the roster, not the prose",{ w:"A hard reject when a club’s text claims a result against a club that is not in the division, grounded in the roster we hold rather than in the prose. It is the first guard that checks a claim against our own data instead of against a pattern.", t:"—" }),

I("i.frozen",  19, 0, "model","unheard","7–23 Sep","16 days",{ w:"Every club's prose frozen." }),
I("i.frozenb", 19, 1, "guard","unheard","Chelsea's key players still named a player who had left three weeks earlier","for £125m, to Manchester City",{ w:"The routine's “already done this week?” check keyed on a column that another writer rewrites every two hours. At every slot after 06:00 it answered “all 20 already done”.", t:"2026-09-07 to 2026-09-23, found by the stale-data audit.", g:"A done-marker must not be a column another writer touches.", f:["AUDIT_FINDINGS.md"], x:["r.teampage"] }),
I("i.frozenw",19, 2, "code","live","A marker nobody else writes","and the retry slot became a real retry",{ w:"A done-marker the routine owns and nobody else writes, so a second writer touching the same row cannot make the first one think it has already finished. The retry slot became a real retry on the same change.", t:"—" }),

/* October */
I("i.grant",  21, 0, "guard","live","23 Sep","found by a review pass",{ w:"The shipped key could stop every push." }),
I("i.grantb", 21, 1, "guard","live","One anon call a minute to a tick-claim function would have silently stopped the live pipeline","while match-watcher logged its ordinary “tick already claimed”",{ w:"It could also write 23 tables — row-level rules held, but the function grants did not.", t:"2026-09-23.", g:"Four migrations had each written REVOKE EXECUTE FROM PUBLIC and read as though they had locked the function. None had: Supabase gives anon an EXPLICIT grant, and FROM PUBLIC does not touch it. Write FROM PUBLIC, anon, authenticated — and then check has_function_privilege rather than trusting the statement.", f:["CHANGELOG_SECURITY.md"], x:["mig.grants"] }),
I("i.grantw",21, 2, "code","live","Detection replacing prevention","db-health section 7 lists everything anon can reach",{ w:"The default-privilege hedge was found not to work either, so the answer became a check that fails the next morning.", t:"—", x:["sc.health"] }),

I("i.fix",  22, 0, "guard","live","23–24 Sep","three fixes that did not fix",{ w:"Found one day later by a five-reviewer pass." }),
I("i.fixb", 22, 1, "guard","live","A layout fix moved the defect onto more important text; a content fix never shipped; a name fix destroyed data","“Nottingha / m Forest”, a stale version number, and E. Martínez resolving to Lautaro",{ w:"The third is the worst: the foreign key's trigger is a DELETE, so a wrong match is a destroyed dossier rather than a mislabel.", t:"2026-09-23 to 2026-09-24.", g:"A content fix that does not move the version number reaches nobody who already refreshed. And a matcher that cannot be sure must refuse, not guess.", f:["AUDIT_FINDINGS.md"] }),
I("i.fixw", 22, 2, "code","live","The adversarial review pass became a practice","plus a nightly repair after the prune",{ w:"Five read-only reviewers over the previous day’s work, which is now a standing practice after any batch of fixes. Plus a nightly repair pass that re-resolves player links rather than trusting a stored id.", t:"—" }),

I("i.ones",  23, 0, "model","unheard","30 Sep","a month, every job green",{ w:"Players who were not playing." }),
I("i.onesb", 23, 1, "guard","unheard","Onboarding led with a striker with two starts and no goals; one club's card led on a goalkeeper with zero minutes","found by Anton on the onboarding screen",{ w:"20 of 60 picks outside their own squad's top fifteen by minutes.", t:"Roughly a month to 2026-09-30.", g:"The most important line in this whole timeline: every existing check tested whether the content was TRUE. None tested whether it was RELEVANT. Every scheduled job had reported success throughout, and each one had genuinely done its job.", f:["AUDIT_FINDINGS.md"], x:["sh.featured"] }),
I("i.onesw", 23, 2, "code","live","A deterministic picker, on both write paths","and §4a of the stale-data audit",{ w:"Applied to the Edge function and the Monday routine — the second would otherwise have been missed, as it was twice.", t:"—", x:["x.llmb"] }),

I("i.basics",  24, 0, "model","unheard","2 Oct","since the data was seeded",{ w:"Eight wrong facts nothing had read." }),
I("i.basicsb", 24, 1, "guard","unheard","One club's card said a rival was not in the league while the rival's own card said it was","found by Anton reading one card",{ w:"Also: an unbeaten “49-game Premier League season” (seasons are 38), a false title-drought claim, and a stadium five miles inland described as by the sea.", t:"Seeded in migration 004, found 2026-10-02.", g:"Hand-seeded data that every later writer is built to PRESERVE is data no check will ever look at. Three of the eight were self-contradictions inside our own tables, needing no outside lookup at all.", f:["AUDIT_FINDINGS.md"] }),
I("i.basicsw",24, 2, "code","live","Four checks in db-health section 8","only for the parts that genuinely drift",{ w:"Section 8 is deliberately WARN-only until its trip rate is known — an alarm calibrated before you know its frequency is one you learn to ignore.", t:"—", x:["sc.health"] }),

I("i.q",  25, 0, "model","unheard","6 Oct","a question asserts nothing",{ w:"A card got past every guard by asking." }),
I("i.qb", 25, 1, "guard","unheard","“Is Gyökeres already the most important player in Arsenal?” — he was 16th by minutes, with no league starts","every validator on the page checks assertions",{ w:"A question exposes the reader harder than a statement: the answer she gets back is “he hasn't started a league game.”", t:"2026-10-06.", g:"Made mandatory the day after shipping, because it was found to be optional and therefore decorative.", f:["/Users/anton/goaldigger-routines/post_news.sh"], x:["g.postnews"] }),
I("i.qw", 25, 2, "code","live","The card must declare the numbers it leaned on","checked against the players table, as a hard fail",{ w:"The model states its evidence and the script verifies it. Cheaper than extracting claims from prose.", t:"—", x:["store.players"] }),

I("i.frz",  26, 0, "guard","unheard","8 Oct","a month, via a false alarm",{ w:"A freshness guard became the bug." }),
I("i.frzb", 26, 1, "guard","unheard","A timestamp froze while the writing underneath it stayed correct and nightly","440 successful posts logged over the period",{ w:"The guard only stamps freshness when the payload carries prose — and it tested for a field the prompt had been redesigned in the same week to stop producing.", t:"2026-09-07 to 2026-10-08.", g:"A freshness rule has to name the fields the prompt emits TODAY. The weekly review read the frozen column and reported a healthy table as a month dead.", f:["/Users/anton/goaldigger-routines/post_season_state.sh"], x:["r.season"] }),
I("i.frzw", 26, 2, "code","live","Accept either shape, and a test behind it","so the next prompt redesign fails loudly",{ w:"The stamp now accepts either prose shape and still refuses a fixtures-only write, with nine offline assertions behind it — including one that fails if the script stops naming both current fields.", t:"—", x:["rt.checks"] })
];

const M6_EDGES = [];
for (const n of M6_NODES.filter(x => x.c === 0)) {
  const mid = M6_NODES.find(x => x.c === 1 && x.r === n.r);
  const out = M6_NODES.find(x => x.c === 2 && x.r === n.r);
  if (mid) M6_EDGES.push({ from:n.id, to:mid.id, label:"", kind:"flow" });
  if (mid && out) M6_EDGES.push({ from:mid.id, to:out.id, label:"", kind:"flow" });
}

MODELS.m6 = { title:"What has gone wrong", cols:M6_COLS, bands:M6_BANDS, nodes:M6_NODES, edges:M6_EDGES, rowH:108, dir:"lr" };
