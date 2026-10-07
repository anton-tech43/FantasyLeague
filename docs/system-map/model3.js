/* model3.js — the timetable and the push rules.
   Same engine, same grid. Two questions this answers that models 1 and 2 do not:
   what runs at what time and WHY at that time, and what is allowed to buzz
   her phone, when, and why that one and not the others. */

const M3_COLS = [
  { x: 0,   w: 182, label: "When",  hint: "UTC · Stockholm is +2 in summer, +1 in winter" },
  { x: 242, w: 806, label: "What runs, and why then", hint: "click for the whole reason" }
];

const M3_BANDS = [
  { label: "A · Always running",      from: 1,  to: 6,  note: "Not a time of day. These never stop." },
  { label: "B · Overnight 01–05 UTC", from: 8,  to: 15, note: "The writing and the cleaning, done while nobody is looking. Deliberately staggered so two heavy jobs never collide on a database with six workers." },
  { label: "C · Early morning 05–07", from: 17, to: 24, note: "Data first, then the writing that depends on it. The order here is load-bearing." },
  { label: "D · Her morning 07–09",   from: 26, to: 30, note: "The only part of the day aimed at a person being awake." },
  { label: "E · Through the day",     from: 32, to: 35, note: "Three jobs that are about her weekend rather than the clock." },
  { label: "F · Not on a clock",      from: 37, to: 40, note: "Started by a match, or by her." }
];

const T = (id, r, when, days, p) => ({ id, c:0, r, k:"code", s:p.s||"live", l:when, sub:days, p:{w:p.w,t:p.t||when+" UTC",rd:"—",wr:"—",f:p.f||[],g:p.g||"—",x:p.x||[]} });
const W = (id, r, name, why, p) => ({ id, c:1, r, k:p.k||"model", s:p.s||"live", l:name, sub:why,
  p:{w:p.w,t:p.t,rd:p.rd||"—",wr:p.wr||"—",f:p.f||[],g:p.g||"—",x:p.x||[]} });

const M3_NODES = [
T("t.min", 1, "every minute", "* * * * *", { w:"The fastest clock in the product. It never sleeps, including on days with no football.", g:"On a blank day it does nothing and writes nothing, which is indistinguishable from being broken. That is what section 8i of db-health.sh now settles." }),
W("w.min", 1, "match-watcher", "because a goal is only worth telling someone about for the next ninety seconds", {
  k:"code", t:"Every minute of every day.", rd:"The football feed, but only for competitions that have a fixture today.", wr:"The scoreboard, the lock-screen alerts, the live score, and two writing jobs.",
  w:"Checks whether anything has happened in a match and reacts immediately: kickoff, goal, half time, full time.",
  g:"Why a minute and not five: a five-minute poll means an average two-and-a-half minute delay on a goal, by which time she has heard him shout. The cost of the choice is 1,440 wake-ups a day for perhaps six useful ones.", x:["edge.match-watcher"] }),

T("t.30", 2, "every 30 min", "*/30 * * * *", { w:"A check on the scheduler itself." }),
W("w.30", 2, "the scheduler's own health check", "because the thing that runs everything else has to be watched by something", {
  k:"code", t:"Every half hour.", rd:"The logbook.", wr:"A health verdict.",
  w:"Asks whether the scheduled jobs are actually running.",
  g:"It lives inside the database, so it cannot report that the database is down. That is what the three-hourly outside check is for.", x:["cron.hbcheck"] }),

T("t.hour", 3, "every hour", "at :15", { w:"The push sweep." }),
W("w.hour", 3, "notification-sender", "because anything worth interrupting her for should not wait until morning, and nothing should interrupt her twice", {
  k:"code", t:"Hourly at quarter past, plus an immediate call whenever a writing job finishes something urgent.", rd:"The feed, and the list of phones.", wr:"Lock-screen alerts.",
  w:"Picks up anything newly written that deserves a buzz, and sends it.",
  g:"Why :15 and not :00 — the top of the hour is where every other scheduler in the world piles up. The hourly sweep is really a safety net; most pushes go out on demand seconds after the writing finishes.", x:["edge.notifsender"] }),

T("t.2h", 4, "every 2 hours", "06:00–22:00", { w:"The data collection." }),
W("w.2h", 4, "data-fetcher", "because the league table has to be right even on a day nobody writes anything", {
  k:"code", t:"Every two hours between 06:00 and 22:00 UTC. Nothing overnight, because nothing changes overnight.", rd:"Nine news sources and about seven football-data endpoints per club.", wr:"The saved copy everything else reads, and a refresh of the numbers on each club page.",
  w:"Goes out, collects everything, saves it, and refreshes the numbers on every club page without writing a word.",
  g:"This is the job most things quietly depend on. The cup and European writing cannot reach the internet at all — if this stops, they keep writing confidently from a stale copy and nothing says so.", x:["edge.datafetcher"] }),

T("t.3h", 5, "every 3 hours", "17 */3 * * *", { w:"The outside check." }),
W("w.3h", 5, "gd-heartbeat", "because every alarm we had lived inside the thing that broke", {
  t:"Every three hours, from outside the system.", rd:"Four things: is the database answering, is there content newer than 30 hours, a data fetch newer than 10 hours, and fewer than ten failures in a day.", wr:"Nothing at all unless something is wrong.",
  w:"Asks from the outside whether the product is alive, and says nothing when it is.",
  g:"Between 30 August and 5 September 2026 the backend was down for seven days and nobody knew, because every alarm was a row in the database that was down. Silence is the design: a cheerful “all fine” every three hours is how you learn to ignore the one that matters.", x:["r.heartbeat"] }),

T("t.0100", 8, "01:00", "weekdays", { w:"The season line." }),
W("w.0100", 8, "gd-season-state", "first in the night, because everything written later reads better if it knows how the season is going", {
  t:"Weekdays at 01:00 UTC, 03:00 Stockholm.", rd:"The saved league table.", wr:"A line on where the club is, and one on what that will do to his mood.",
  w:"Writes where the club is in its season.",
  g:"On 2026-10-07 this looked a month dead and was not: a freshness rule was keyed to a field the instructions had stopped producing, so the timestamp froze while the writing underneath it stayed correct and current. Fixed the same day — see rt.postrest.", x:["r.season"] }),

T("t.0200", 9, "02:00", "weekdays", { w:"The small-facts card." }),
W("w.0200", 9, "gd-insider", "because the feed needs something to show on a day with no news, and that cannot be written in a hurry at 9am", {
  t:"Weekdays at 02:00 UTC.", rd:"The club's own news sources.", wr:"One small fact per club, added to a pile of nearly six thousand.",
  w:"Writes one thing a day per club that he probably does not know.",
  g:"This is the empty state of the whole product. The news is allowed to write nothing on a quiet day precisely because this card exists.", x:["r.insider"] }),

T("t.0230", 10, "02:30", "Mondays only", { w:"The club page rewrite." }),
W("w.0230", 10, "gd-team-page", "Monday, because the weekend's results are what change the page — and once a week is also the reason it goes stale", {
  t:"Mondays at 02:30 UTC, with a retry at 08:30.", rd:"Everything saved about the club, plus every player's season.", wr:"The words on his club's page, for all twenty clubs. About 45 minutes.",
  w:"Rewrites the words on his club's page.",
  g:"Weekly is a cost decision, not a design one. A reputation-based card will give the same answer every Monday even after a player stops playing, and every job reports green while it happens — which is exactly what went wrong for a month in September. The fix for that is event-driven, and the quota arithmetic saying why it is not built yet is written down.", x:["r.teampage","cron.teampage"] }),

T("t.0300", 11, "03:00", "Tuesdays", { w:"The weekly review." }),
W("w.0300", 11, "gd-content-review", "Tuesday, so it has a full week behind it and the weekend's output is included", {
  t:"Tuesdays at 03:00 UTC.", rd:"Everything published in the last seven days, plus how fresh every table is.", wr:"An honest report with findings and a verdict.",
  w:"Reads back a week of output and writes down whether it was any good.",
  g:"It refuses a report whose numbers did not come from the measuring script, and refuses a verdict shorter than 80 characters — a model asked to mark its own homework will otherwise write “looks good”. Its 2026-10-05 report correctly flagged both freshness problems on this page.", x:["r.review"] }),

T("t.03xx", 12, "03:00–04:00", "staggered", { w:"The cleaning." }),
W("w.03xx", 12, "eight retention and vacuum jobs", "staggered through one hour, because this database has six workers and two heavy deletes at once starve everything else", {
  k:"code", t:"03:00, 03:15, 03:20, 03:25, 03:40, 03:45, 03:55, and a pg_net vacuum every six hours.", rd:"—", wr:"Deletes and compacts the log tables.",
  w:"Throws away old logs and compacts what is left.",
  g:"Not optional and not glamorous. One of these log tables grows forever if left alone, and when it bloats the scheduler starves and reports “job startup timeout” — which looks exactly like every job in the product breaking at the same moment.", x:["cron.sweeps"] }),

T("t.0330", 13, "03:30", "nightly", { w:"The fact-check." }),
W("w.0330", 13, "content-audit", "after the night's writing and before anyone reads it", {
  k:"code", t:"03:30 UTC nightly, over the last seven days.", rd:"What was published, and the real league table.", wr:"Findings in the logbook. It never changes anything and never pushes.",
  w:"Checks published writing against the real table and notes anything that contradicts it.",
  g:"Its findings go somewhere nothing reads them. An audit nobody reads is an audit that does not exist — which is why the content checks were moved into db-health.sh, where a person actually looks.", x:["edge.audit"] }),

T("t.0500", 15, "05:00", "daily", { w:"Stuck matches." }),
W("w.0500", 15, "match-status-reaper", "daily, because an abandoned match otherwise sits on a lock screen until its own timer runs out", {
  k:"code", t:"05:00 UTC.", rd:"The scoreboard.", wr:"Closes any fixture still unfinished four hours after kickoff.",
  w:"Closes matches that never properly ended.",
  g:"Pure database work — no program is called, so it cannot fail for any of the reasons the others can.", x:["cron.reaper"] }),

T("t.0500e", 17, "05:00", "Tue–Fri", { w:"European football." }),
W("w.0500e", 17, "gd-europe", "Tuesday to Friday, because that is the morning after European nights are played", {
  t:"Tue–Fri 05:00 UTC.", rd:"The saved competition data — it cannot reach the football feed at all.", wr:"Items on the shared football feed.",
  w:"Writes about the Champions League, Europa League and Conference League.",
  g:"Its facts come entirely from what data-fetcher saved. If that stops, this keeps writing confidently from an old copy.", x:["r.europe"] }),

T("t.0530", 18, "05:30", "daily", { w:"Squad lists." }),
W("w.0530", 18, "the squad sync", "before anything reads a squad, because a transfer that happened yesterday should not be news to us today", {
  k:"code", t:"05:30 UTC.", rd:"The saved squad data.", wr:"The player list, removing anyone who left and reattaching their cards.",
  w:"Refreshes who is at each club.",
  g:"Pure database work, no cost, no model.", x:["cron.playersync"] }),

T("t.0550", 19, "05:50", "daily", { w:"Shirt numbers." }),
W("w.0550", 19, "official-squads", "right after the squad sync, so the league's own list gets the last word over the feed's", {
  k:"code", t:"05:50 UTC.", rd:"The Premier League's published squad list.", wr:"Overwrites shirt numbers and registration.",
  w:"Corrects shirt numbers from the league's own list.",
  g:"The order matters: run before the sync and the feed's wrong numbers would win. This exists because about thirty of them were wrong.", x:["edge.squads"] }),

T("t.0600c", 20, "06:00", "Tue–Thu, Sat, Sun", { w:"The domestic cups." }),
W("w.0600c", 20, "gd-domestic-cups", "on the mornings after cup rounds and draws, and silent between them", {
  t:"Tue–Thu, Sat and Sun at 06:00 UTC.", rd:"The saved competition data.", wr:"Items on the shared football feed.",
  w:"Writes about the FA Cup and the League Cup.",
  g:"Between rounds it correctly produces nothing, which is easy to mistake for a fault.", x:["r.cups"] }),

T("t.0600a", 21, "06:00", "daily", { w:"Archiving." }),
W("w.0600a", 21, "archive old content", "a week is as long as anything in a football feed stays interesting", {
  k:"code", t:"06:00 UTC daily.", rd:"The feed.", wr:"Marks anything published over a week ago as archived, unless it is about a fixture still to come.",
  w:"Files away last week's feed.",
  g:"This job exists in the live database and in no migration — it was created by hand. It is the proof that the change history is not the schedule.", x:["cron.archive"] }),

T("t.0600m", 22, "06:00", "Tue + Fri", { w:"Maintenance." }),
W("w.0600m", 22, "gd-maintenance", "twice a week, so a problem is never more than three days old, and Friday catches it before the weekend's matches", {
  t:"Tuesday and Friday 06:00 UTC.", rd:"Everything.", wr:"Fixes what is safe to fix, commits a report, and pushes a human only when it needs a decision.",
  w:"Goes through the whole product on its own and either fixes or reports.",
  g:"Two rules bind it: only correct a fact whose truth lives in a source we trust, and never run a paid job across all twenty clubs. Green is silent, so a holiday is not spammed.", x:["r.maint"] }),

T("t.0630", 23, "06:30", "daily", { w:"News, first run." }),
W("w.0630", 23, "gd-news", "early enough for the overnight press, late enough that the morning's stories have landed", {
  t:"06:30 UTC daily — 08:30 Stockholm. The second run is at 22:30.", rd:"The press, the fixtures, the table and every player's season.", wr:"The feed, and a push for anything worth it.",
  w:"Writes the club news feed for all twenty clubs.",
  g:"Two runs a day, settled on 2026-10-07 against production because the repository contradicted itself. On a quiet day it is supposed to write nothing — that is the editorial bar, not a failure.", x:["r.news","cron.gdnews"] }),

T("t.0640", 24, "06:40", "daily", { w:"Player numbers." }),
W("w.0640", 24, "the player stats sync", "ten minutes after the news starts, so the season numbers are the freshest thing the writing has", {
  k:"code", t:"06:40 UTC.", rd:"The saved match data.", wr:"Every player's minutes, starts, goals and assists.",
  w:"Refreshes how much every player has actually played.",
  g:"This ran perfectly every night of the month in which the club page was naming a player who had stopped playing. The numbers were never stale; the weekly rewrite simply never re-read them.", x:["cron.statssync"] }),

T("t.0700", 26, "07:00", "daily", { w:"Match reminder." }),
W("w.0700", 26, "matchday-reminder", "early, because it has to arrive before her day starts, in her time zone and not ours", {
  k:"code", t:"07:00 UTC daily.", rd:"Today's fixtures and each phone's time zone.", wr:"A lock-screen alert.",
  w:"Tells her his club plays today, with the kickoff time in her own time zone.",
  g:"One job, many time zones — the kickoff is rendered per phone, not once centrally. Getting that wrong is how a push arrives in the middle of the night.", x:["edge.reminder"] }),

T("t.0800", 27, "08:00", "daily", { w:"Game day." }),
W("w.0800", 27, "morning-push", "the second cup of coffee, and only on a day his club actually plays", {
  k:"code", t:"08:00 UTC daily, but it sends nothing unless there is a fixture.", rd:"Today's fixtures.", wr:"A lock-screen alert.",
  w:"The “game day” nudge.",
  g:"Entirely templated. No model is involved in any scheduled push in this product.", x:["edge.morning"] }),

T("t.0800p", 28, "08:00 and 09:00", "PAUSED", { s:"paused", w:"The day-before nudge, switched off." }),
W("w.0800p", 28, "prep-reminder", "would open the practice screen the day before a match — switched off until the app that opens it is in the store", {
  s:"paused", k:"guard", t:"Switched off. Verified in the live scheduler on 2026-10-07: not active.", rd:"—", wr:"Nothing.",
  w:"The day-before nudge to practise before the match.",
  g:"The change that would switch it back on exists but is deliberately not named as a change file yet, so it cannot be applied by accident. Switch it on when 2.3 ships.", x:["cron.prep"] }),

T("t.0900", 29, "09:00", "Sundays", { w:"The week ahead." }),
W("w.0900", 29, "gd-sunday-brief", "Sunday mid-morning, when the week's fixtures are known and she has time to read", {
  t:"Sundays at 09:00 UTC, with retries at 13:00 and 17:00.", rd:"The same gathered facts as the news.", wr:"One piece per club.",
  w:"The Sunday round-up and the week ahead.",
  g:"Pushes only to the paid tiers.", x:["r.sunday"] }),

T("t.1100", 32, "11:00", "Saturdays", { w:"The quiz." }),
W("w.1100", 32, "gd-saturday-quiz", "before the Saturday kickoffs, so the questions are about a weekend that has not happened yet", {
  t:"Saturdays at 11:00 UTC, retry at 15:00.", rd:"The gathered facts, plus the club page.", wr:"Three questions per club.",
  w:"The weekend quiz.",
  g:"Served only inside a 36-hour window, so last week's quiz disappears by itself instead of needing to be cleaned up.", x:["r.quiz"] }),

T("t.1700", 33, "17:00", "daily", { w:"Player cards." }),
W("w.1700", 33, "gd-player-dossier", "early evening, after the day's team news and before the evening's reading", {
  t:"17:00 UTC daily. No retry.", rd:"The squad, sorted by minutes played.", wr:"Sixty cards a run — the whole set turns over in about five days.",
  w:"Writes a short card for each player.",
  g:"It drops anyone with no minutes, because there is nothing to say about him that is not invented. That rule was written here first and has since been copied into the news.", x:["r.dossier"] }),

T("t.2230", 34, "22:30", "daily", { w:"News, second run." }),
W("w.2230", 34, "gd-news", "last thing, to catch the evening's matches and team news before she wakes up", {
  t:"22:30 UTC — 00:30 Stockholm.", rd:"The same gathered facts.", wr:"The feed.",
  w:"The second news run of the day.",
  g:"Anything written here that deserves a push is held by quiet hours rather than sent at midnight.", x:["r.news"] }),

T("t.ft", 37, "at full time", "an event, not a time", { w:"The final whistle." }),
W("w.ft", 37, "gd-matchday", "because a match report is worthless an hour late and meaningless before the whistle", {
  t:"Fired by the match-watcher the moment a fixture finishes.", rd:"Its own fresh look at the result and the table.", wr:"The full-time article, feed only.",
  w:"The write-up after the final whistle.",
  g:"It deliberately never pushes: the full-time alert already went out from the match-watcher minutes earlier, and the article is what she opens from it.", x:["r.matchday"] }),

T("t.ht", 38, "half time and 75'", "an event, not a time", { w:"Mid-match." }),
W("w.ht", 38, "gd-live-brief", "twice a match, at the two moments where there is something to say and time to read it", {
  t:"Fired by the match-watcher at half time and around the 75th minute.", rd:"Nothing — the match-watcher hands over the score and the minute.", wr:"A few sentences in the live box.",
  w:"Words about the match while it is still being played.",
  g:"The score, the minute and the scorers are always taken from our own scoreboard. The writing only supplies the sentences.", x:["r.livebrief"] }),

T("t.open", 39, "when she opens it", "many times a day", { w:"Her." }),
W("w.open", 39, "the app asking for things", "because most of the product is a read, and a read should be instant", {
  k:"code", t:"On open, on pull to refresh, and every 60 seconds during a live match.", rd:"Eight tables directly, plus four small programs for the things that need a window of time.", wr:"Almost nothing — three small writes in the whole app.",
  w:"The app fetching what it needs.",
  g:"There is no middle layer: the app reads the database directly with a key that ships inside the app. That is why exactly what that key may touch is checked on every health run.", x:["trig.app","api.postgrest"] })
];

const M3_EDGES = M3_NODES.filter(n => n.c === 0)
  .map(n => ({ from: n.id, to: "w" + n.id.slice(1), label: "", kind: "flow" }));

/* ---------- MODEL 4 — what sends a push, when, and why ---------- */

const M4_COLS = [
  { x: 0,   w: 236, label: "The moment",  hint: "what just happened" },
  { x: 296, w: 270, label: "What decides", hint: "and who it reaches" },
  { x: 626, w: 422, label: "Why this one is allowed to interrupt her", hint: "" }
];

const M4_BANDS = [
  { label: "Pushes that come from a match",        from: 1,  to: 4,  note: "All four are sent by the same program, within seconds, with no model anywhere in the path. Copy is picked from 40 written-by-hand variants." },
  { label: "Pushes that come from writing",        from: 6,  to: 8,  note: "The only route from the AI to a lock screen, and the narrowest. Most of what gets written never pushes." },
  { label: "Pushes that come from a calendar",     from: 10, to: 12, note: "Templated, scheduled, and sent whether or not anything was written." },
  { label: "Things that deliberately never push",  from: 14, to: 17, note: "The interesting half of the design. Each line here is a decision that silence is better." },
  { label: "Pushes that are not for her",          from: 19, to: 20, note: "Two alarms that go to a developer's phone." }
];

const M = (id, r, c, k, s, l, sub, p) => ({ id, c, r, k, s, l, sub,
  p:{ w:p.w, t:p.t||"—", rd:p.rd||"—", wr:p.wr||"—", f:p.f||[], g:p.g||"—", x:p.x||[] } });

const M4_NODES = [
M("m.goal",   1, 0, "surface","live","A goal goes in","either team, any competition",{ w:"The single most time-critical thing the product does.", t:"Within seconds of the feed reporting it.", x:["edge.match-watcher"] }),
M("m.goald",  1, 1, "code","live","match-watcher","every tier, every competition",{ w:"Detected on the minute tick and sent immediately, with copy chosen from 40 hand-written variants seeded so the same line does not come round twice.", t:"Immediately.", f:["backend/supabase/functions/_shared/goal-push-copy.ts"], g:"Claimed before sending, so two overlapping ticks cannot double-push.", x:["sh.goal"] }),
M("m.goalw",  1, 2, "guard","live","no tier gate at all","a goal is the whole point",{ w:"This is the one push nobody is gated out of. Every other alert is filtered by what she has paid for; a goal reaches everyone, in every competition, including the earliest cup rounds.", t:"—", g:"If you are deciding whether a new alert should be gated, the question to ask is whether it is as time-critical and as unambiguous as a goal. Almost nothing is." }),

M("m.ko",     2, 0, "surface","live","Kickoff","his club is playing now",{ w:"The match has started.", t:"At kickoff.", x:["edge.match-watcher"] }),
M("m.kod",    2, 1, "code","live","match-watcher","tier 2 and up · not in early cup rounds",{ w:"Sent at kickoff, but only to paying tiers, and suppressed entirely for the early rounds of the FA Cup and League Cup.", t:"At kickoff.", f:["backend/supabase/functions/_shared/push-tiers.ts"], g:"Semi-finals and finals go to everyone, regardless of tier." }),
M("m.kow",    2, 2, "guard","live","she can see he is watching","a second-round cup tie is not an event",{ w:"Kickoff tells her something she could work out by looking at him, so it is worth less than a goal and is priced accordingly. The cup exception exists because a Tuesday night second-round tie is not an occasion and a push that says it is teaches her to ignore the next one.", t:"—", g:"The rounds are decided in code, not by the model." }),

M("m.ht",     3, 0, "surface","live","Half time","with a line to say",{ w:"Fifteen minutes when he is in the room and talking.", t:"At the interval.", x:["edge.match-watcher"] }),
M("m.htd",    3, 1, "code","live","match-watcher","tier 2 and up",{ w:"The score, plus one line she can actually use.", t:"At half time.", g:"Half-time and full-time pushes end with something to say. That is the product in one line." }),
M("m.htw",    3, 2, "guard","live","the only moment she can join in","and it lasts fifteen minutes",{ w:"This is the push with the clearest purpose in the whole product. During play he is not listening; after the match the moment has gone. Half time is the window, and it closes.", t:"—" }),

M("m.ft",     4, 0, "surface","live","Full time","the result, and a line",{ w:"The final whistle.", t:"At full time.", x:["edge.match-watcher"] }),
M("m.ftd",    4, 1, "code","live","match-watcher","every tier",{ w:"The result and one line to say about it.", t:"Within seconds of the whistle.", g:"Tapping it opens the full-time article, which is written separately a few minutes later and never pushes on its own." }),
M("m.ftw",    4, 2, "guard","live","the result changes his evening","and she will be in it either way",{ w:"How the match ended is the single fact that most determines the next few hours in her house. It is worth an interruption to everyone, paid or not.", t:"—" }),

M("m.news",   6, 0, "surface","live","A news card is written","twice a day, 20 clubs",{ w:"The AI has written something about his club.", t:"06:30 and 22:30 UTC.", x:["r.news"] }),
M("m.newsd",  6, 1, "guard","live","~60 guards, then one gate","tier depends on the card",{ w:"The card passes about sixty checks, and only then is it marked as worth a buzz. The sending program claims it, throttles it to one per club per five minutes, and filters by tier.", t:"Within seconds if it qualifies, otherwise on the next hourly sweep.", f:["/Users/anton/goaldigger-routines/post_news.sh"], g:"Most cards do not qualify. Push-eligibility is a separate decision from whether the card is good.", x:["g.postnews","edge.notifsender"] }),
M("m.newsw",  6, 2, "guard","live","only if she would want to be told now","seven reasons it stays in the feed instead",{ w:"The default is silence. A card is downgraded to feed-only for a non-football celebrity angle, international duty written for a club feed, quiet hours between 21:00 and 06:00 UTC, an unconfirmed rumour, a teaser headline that hides what it is about, or a full-time article whose push already went.", t:"—", g:"These encode product judgement, not correctness. The card is fine; it is just not worth a buzz.", x:["g.pushgate"] }),

M("m.sun",    7, 0, "surface","live","The Sunday brief","once a week",{ w:"The week ahead.", t:"Sundays.", x:["r.sunday"] }),
M("m.sund",   7, 1, "guard","live","the same path as the news","tier 2 and up",{ w:"Travels the same guards and the same gate as a news card.", t:"Sunday late morning.", g:"Tier 2 and up only." }),
M("m.sunw",   7, 2, "guard","live","it is the one that sets up her week","and Sunday is when there is time",{ w:"Unlike the news, this is not reacting to anything — it is the piece that tells her what is coming and why it matters, at the one time in the week she might read something longer.", t:"—" }),

M("m.verify", 8, 0, "guard","live","The feed-only contract","checked after every run",{ w:"Anything marked feed-only must never, under any circumstances, have buzzed her phone.", t:"After every news run.", f:["scripts/verify-push-eligible.sh"], g:"A card marked feed-only with a send against it is a violation and the script says so.", x:["sc.push"] }),
M("m.verifyd",8, 1, "code","live","verify-push-eligible.sh","run by hand, and in maintenance",{ w:"Looks for any card that was marked feed-only and nonetheless shows a send.", t:"On demand.", g:"This is the regression test for the rule above it. Rules without a test drift." }),
M("m.verifyw",8, 2, "guard","live","because a quiet card that buzzes is worse than a loud one","it breaks the promise rather than the product",{ w:"If feed-only can buzz, then every downgrade in the list above means nothing, and the only way to find out is from a person who stopped trusting the notifications.", t:"—" }),

M("m.gameday",10, 0, "surface","live","Game day","08:00, if there is a fixture",{ w:"His club plays today.", t:"08:00 UTC.", x:["edge.morning"] }),
M("m.gamedayd",10,1, "code","live","morning-push","every tier with a fixture today",{ w:"One templated line. No model, no writing job, no cost.", t:"08:00 UTC.", g:"It sends nothing at all on a day with no fixture." }),
M("m.gamedayw",10,2, "guard","live","so the day is not a surprise","and she can plan around it",{ w:"The cheapest useful push in the product: it needs no writing, no checking and no AI, and it changes how she plans her day.", t:"—" }),

M("m.remind", 11, 0, "surface","live","Kickoff time","07:00, in her time zone",{ w:"When the match actually starts, where she is.", t:"07:00 UTC.", x:["edge.reminder"] }),
M("m.remindd",11, 1, "code","live","matchday-reminder","every tier",{ w:"The kickoff is rendered per phone from that phone's own time zone, not once centrally.", t:"07:00 UTC.", g:"Rendering it centrally is how a push arrives in the middle of somebody's night." }),
M("m.remindw",11, 2, "guard","live","“what time?” is the question she actually asks","and the answer is time-zone shaped",{ w:"The useful fact is not that there is a match, it is when. That is only meaningful in her own time zone, which is why it is stored per phone.", t:"—" }),

M("m.prep",   12, 0, "surface","paused","The day before","switched off",{ w:"A nudge to practise before the match.", t:"Not running.", x:["cron.prep"] }),
M("m.prepd",  12, 1, "guard","paused","prep-reminder","nobody — it is paused",{ w:"The job exists in the scheduler and is switched off.", t:"Verified not active on 2026-10-07.", g:"Switch it on when the app version that opens the practice screen is in the store, and not before — otherwise the push lands on a screen that does not exist." }),
M("m.prepw",  12, 2, "guard","paused","a push must land somewhere that exists","which is why it is off and not merely unfinished",{ w:"The alert opens a specific screen in a specific app version. Sending it to phones running the older version would open nothing, which is the worst possible first impression of a new feature.", t:"—" }),

M("m.article",14, 0, "surface","live","The full-time article","feed only, never pushes",{ w:"The write-up after the whistle.", t:"Minutes after full time.", x:["r.matchday"] }),
M("m.articled",14,1, "guard","live","gd-matchday, deliberately silent","nobody is pushed",{ w:"Written, published, and never announced.", t:"—", g:"This is a rule in the writing instructions, not an accident." }),
M("m.articlew",14,2, "guard","live","the push already went out","two alerts for one event is how people turn them off",{ w:"The match-watcher pushed the result seconds after the whistle. The article is what she opens from that push — not a second interruption about the same thing.", t:"—" }),

M("m.insider",15, 0, "surface","live","Small facts, quiz, player cards","never push",{ w:"Three content types that are published and never announced.", t:"Daily and weekly.", x:["r.insider"] }),
M("m.insiderd",15,1, "guard","live","no push path exists at all","they are not gated, they are unplugged",{ w:"These writing jobs have no route to the lock screen. It is not a setting that could be flipped by accident.", t:"—", g:"The strongest possible form of “this must not push”: not a rule, an absence of wiring." }),
M("m.insiderw",15,2, "guard","live","they are there for when she opens the app","not for getting her to",{ w:"This content exists to make the app worth opening on a quiet day. Pushing it would turn a nice surprise into a daily demand on her attention, and the whole product depends on her not resenting it.", t:"—" }),

M("m.teampage",16,0, "surface","live","The club page","rewritten weekly, silently",{ w:"The words on his club's page.", t:"Mondays.", x:["r.teampage"] }),
M("m.teampaged",16,1,"guard","live","no push path","nobody is told",{ w:"Published straight into the page.", t:"—" }),
M("m.teampagew",16,2,"guard","live","nobody wants to be told a page was edited","it is reference, not news",{ w:"She looks at it when she wants it. An alert saying the page changed would be an alert about our own maintenance.", t:"—" }),

M("m.quiet",  17, 0, "surface","live","Quiet hours","21:00–06:00 UTC",{ w:"Anything that would otherwise buzz overnight.", t:"Nightly." }),
M("m.quietd", 17, 1, "guard","live","a downgrade, not a delay","nobody — it goes to the feed",{ w:"A card written in quiet hours is published feed-only rather than queued for the morning.", t:"—", g:"Deliberately not a queue. A delayed push arrives detached from the thing that caused it, which is worse than no push." }),
M("m.quietw", 17, 2, "guard","live","nothing in football is worth waking someone","and the feed will still be there",{ w:"The second news run is at 00:30 Stockholm. Everything it writes is worth reading and none of it is worth a buzz at that hour.", t:"—" }),

M("m.broken", 19, 0, "surface","live","Something is down","to Anton's phone, not hers",{ w:"The product has stopped working.", t:"Within three hours.", x:["r.heartbeat"] }),
M("m.brokend",19, 1, "code","live","gd-heartbeat","one developer phone",{ w:"Four checks, from outside the system, every three hours. Silent unless one fails.", t:"Every three hours.", g:"It must run outside, because for seven days in September every alarm was a row in the database that was down.", x:["r.heartbeat"] }),
M("m.brokenw",19, 2, "guard","live","silence is the signal","an “all fine” every three hours trains you to ignore it",{ w:"The only message this is allowed to send is a problem. That is what makes the message mean something when it arrives.", t:"—" }),

M("m.decide", 20, 0, "surface","live","Something needs a decision","twice a week at most",{ w:"The maintenance round found something it must not fix by itself.", t:"Tuesday and Friday.", x:["r.maint"] }),
M("m.decided",20, 1, "model","live","gd-maintenance","one developer phone, and only when red",{ w:"It fixes what is safe and reversible on its own, and interrupts a human only for a decision, a cost ceiling, or an unreachable database.", t:"Tuesdays and Fridays.", g:"Green is silent on purpose, so a holiday is not spammed.", x:["r.maint"] }),
M("m.decidew",20, 2, "guard","live","a human is only worth interrupting for a judgement","everything else it should have done itself",{ w:"The test for whether it should push: is there a correct answer it could have copied from a source we trust? If yes, it should have fixed it. If no, that is exactly what a person is for.", t:"—" })
];

const M4_EDGES = [];
for (const n of M4_NODES.filter(x => x.c === 0)) {
  const row = n.r;
  const mid = M4_NODES.find(x => x.c === 1 && x.r === row);
  const why = M4_NODES.find(x => x.c === 2 && x.r === row);
  if (mid) M4_EDGES.push({ from: n.id, to: mid.id, label: "", kind: "flow" });
  if (mid && why) M4_EDGES.push({ from: mid.id, to: why.id, label: "", kind: "flow" });
}

MODELS.m3 = { title:"The timetable", cols:M3_COLS, bands:M3_BANDS, nodes:M3_NODES, edges:M3_EDGES, rowH:80, dir:"lr" };
MODELS.m4 = { title:"What sends a push", cols:M4_COLS, bands:M4_BANDS, nodes:M4_NODES, edges:M4_EDGES, rowH:92, dir:"lr" };
