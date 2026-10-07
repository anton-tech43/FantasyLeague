/* model5.js — the decisions that were taken by NOT doing something.
   The most expensive mistake a new engineer makes is not misreading the code.
   It is rebuilding something that was considered, costed and put down, or
   re-litigating a call that already has an answer with a date on it.
   Every row here has a source and, where one exists, the condition that would
   reverse it. */

const M5_COLS = [
  { x: 0,   w: 258, label: "The obvious thing",    hint: "what you would reach for" },
  { x: 318, w: 266, label: "What we did instead",  hint: "" },
  { x: 644, w: 546, label: "Why — and what would change it", hint: "" }
];

const M5_BANDS = [
  { label: "A · Costed, then shelved",    from: 1,  to: 4,  note: "Designed in full, priced, and not built. These have numeric triggers: build when the number moves." },
  { label: "B · Built, then switched off",from: 6,  to: 10, note: "Working code, deliberately unreachable. Deleting it is a decision; so is finishing it." },
  { label: "C · The simpler thing, on purpose", from: 12, to: 18, note: "Where the obvious design was rejected for one that is smaller, cheaper or harder to get wrong." }
];

const D = (n, r, c, k, s, l, sub, p) => ({ id:n, c, r, k, s, l, sub,
  p:{ w:p.w, t:p.t||"—", rd:p.rd||"—", wr:p.wr||"—", f:p.f||[], g:p.g||"—", x:p.x||[] } });

const M5_NODES = [
/* A — costed, then shelved */
D("x.evt",  1, 0, "surface","dormant","Fire a rewrite when a result lands","event-driven team pages",{ w:"One routine fire per club the moment a result, manager change or squad change arrives — instead of a blanket Monday rewrite.", t:"Designed in full. Not built.", f:["EVENT_DRIVEN_TEAM_PAGE.md"] }),
D("x.evtb", 1, 1, "code","live","The Monday rewrite, plus measurement","team_page_prose_history + db-health §8",{ w:"The weekly rewrite stays. What shipped instead was the instrument: a history table and a check that notices when a page goes stale between Mondays.", t:"Shipped 2026-10.", f:["backend/supabase/migrations/123_team_page_prose_history.sql"], x:["mig.prose","r.teampage"] }),
D("x.evtw", 1, 2, "guard","live","Two quota ceilings kill the naive version","build it if the measurement says it is worth it",{ w:"25 remote routine runs a day, and an undocumented ~30 fires per rolling hour found as 429s in production. A four-match Saturday already budgets about 19 of the 25. Final day is ten fixtures at 15:00 — twenty club pages in fifteen minutes.", t:"—", g:"The reversal condition is written down and dated: after a fortnight of history data, build it only if db-health §8 trips between Mondays with non-trivial frequency. “If that is near zero, do not build this — the cost of getting it wrong is silence on a matchday, which is strictly worse than prose that is six days old.” CAVEAT: those quota numbers were measured on a claude.ai account that has since been shut down. Re-measure before citing the arithmetic as settled.", f:["EVENT_DRIVEN_TEAM_PAGE.md"] }),

D("x.comp",  2, 0, "surface","dormant","Store which cups each club is in","a column, or a join table",{ w:"Two complete designs, costed at about an hour each: a JSONB column on teams, or a team_competitions table.", t:"Designed, rejected.", f:["V2.1_DESIGN_FA_CUP.md"] }),
D("x.compb", 2, 1, "code","live","Derive it from the fixture feed","poll_leagues()",{ w:"Nothing stores participation. The leagues to poll are computed from the fixtures each club actually has.", t:"Migrations 087, 094, 098.", x:["edge.match-watcher"] }),
D("x.compw", 2, 2, "guard","live","A stored answer is wrong within weeks","nothing — this is a standing principle",{ w:"“Both options store which competitions a club is in, and that answer is wrong within weeks — a club's European participation changes every August and again the moment they are knocked out.”", t:"—", g:"Generalised in CUP_COVERAGE_PLAN.md as: derived, never stored, for who-is-in-what. The design file is marked “Do not build from this file.”", f:["V2.1_DESIGN_FA_CUP.md","CUP_COVERAGE_PLAN.md"] }),

D("x.queue",  3, 0, "surface","dormant","A worker queue for push fan-out","pgmq, batched dispatchers",{ w:"A real queue with worker batches, and a native HTTP/2 APNs client.", t:"Designed in SCALING_50K.md, deferred.", f:["SCALING_50K.md"] }),
D("x.queueb", 3, 1, "code","live","Bounded concurrency, 100 at a time","mapWithConcurrency",{ w:"A concurrency limiter over ordinary HTTP/1.1, with one aggregated health row per item.", t:"Live.", f:["backend/supabase/functions/_shared/concurrency.ts"], x:["edge.notifsender"] }),
D("x.queuew", 3, 2, "guard","live","The arithmetic does not justify it yet","a single team past ~10–20k followers",{ w:"50,000 recipients ÷ 100 parallel × ~100ms ≈ 50 seconds, against a 400-second ceiling. The thing that actually needed fixing was the sequential loop, which broke worse the more successful a campaign was — recipients past the cutoff silently got nothing.", t:"—", g:"Both reversal conditions are numeric and written down: a dispatcher if any single team passes ~10–20k followers, HTTP/2 when volume warrants it.", f:["SCALING_50K.md"] }),

D("x.keychain", 4, 0, "surface","dormant","Move tokens into the Keychain","KEY-1",{ w:"The APNs token and the two names live in UserDefaults.", t:"Open, MEDIUM.", f:["AUDIT_FINDINGS.md"] }),
D("x.keychainb",4, 1, "code","live","Left in UserDefaults for now","deliberately deferred",{ w:"Unchanged.", t:"—" }),
D("x.keychainw",4, 2, "guard","live","It wants its own test round","do it as its own change, not inside another pass",{ w:"“Deliberately left out of the 2026-09-23 pass: it changes how the app stores tokens and wants its own test round.”", t:"—", g:"Still open. There are no credentials in this app — no accounts, no login — so the blast radius is a device token and two first names.", f:["AUDIT_FINDINGS.md"] }),

/* B — built, then switched off */
D("x.cg",  6, 0, "surface","dormant","Finish the Edge content pipeline","content-generator + content-reviewer",{ w:"A complete generate → four-review-bots → send chain, fully written.", t:"Gated off.", x:["edge.contentgen"] }),
D("x.cgb", 6, 1, "model","live","claude.ai routines, publishing direct","post_*.sh guards instead of review bots",{ w:"The routines write and deterministic guards check. Same job, no per-token bill, and testable offline.", t:"Live.", x:["g.postnews"] }),
D("x.cgw", 6, 2, "guard","live","Two wallets, and the bots cost money to test","only with a routine-migration plan",{ w:"Edge calls bill the API credit balance per token; routines bill the flat subscription. Four review bots meant four paid calls per card, and no way to test a prompt change without paying for it.", t:"—", g:"“Don't re-enable without a routine migration plan.” Nothing in the docs anticipates doing so. This is also the single most misleading thing in the repository — PRD.md, AGENT_CONTRACTS.md and PROMPTS.md all describe it as how the product works.", f:["BACKFILL_RULES.md"] }),

D("x.spam",  7, 0, "surface","dormant","A minimum gap between pushes","anti-spam.ts, 3-hour floor",{ w:"A check that refused a push if the same team had pushed within three hours.", t:"Deleted 2026-05-17.", f:["IOS_GOTCHAS.md"] }),
D("x.spamb", 7, 1, "code","live","Tier filtering and quiet hours","in notification-sender and post_news.sh",{ w:"Volume is controlled by who gets what, and by not sending at night at all.", t:"Live.", x:["g.pushgate"] }),
D("x.spamw", 7, 2, "guard","unheard","It blocked every push it was asked about","nothing — the lesson outlived the code",{ w:"The post script inserts the row as published BEFORE the check runs, so “most recent published item for this team” always returned the row it was about to judge. The gap was always zero. The check always blocked.", t:"—", g:"The general rule is worth more than the feature: never trust ORDER BY ts DESC LIMIT 1 to find anything but the row you just touched. Query before the insert, exclude the candidate's own id, or filter on a different column.", f:["IOS_GOTCHAS.md"] }),

D("x.elim",  8, 0, "surface","dormant","Push “you're out” on elimination","WC_KNOCKOUT_ELIMINATED",{ w:"Written, then commented out at the call site.", t:"Disabled.", f:["backend/supabase/functions/_shared/detect-consequences.ts"] }),
D("x.elimb", 8, 1, "code","live","Let the team's own match report say it","and assert only on points",{ w:"Group exit is conveyed by the brief. The maths only asserts where separation is strict.", t:"—", f:["backend/supabase/functions/_shared/best-third.ts"] }),
D("x.elimw", 8, 2, "guard","live","A false “you're out” cannot be walked back","the comparator now exists — check before finishing it",{ w:"“Firing 'you're out' when a team is actually still alive is the worst possible push, and unlike a false 'you're through' it can't be walked back.” Tiebreakers on goal difference, conduct and FIFA ranking cannot be computed here, so anything resting on them stays soft and is never asserted.", t:"—", g:"UNCERTAIN: the comment says it needs a cross-group comparator “in V1.1”, and best-third.ts now is that comparator. Either the blocker is stale or there is a second reason nobody wrote down. The World Championship is retired anyway, which may make it moot.", f:["backend/supabase/functions/_shared/detect-consequences.ts"] }),

D("x.capped", 9, 0, "surface","dormant","Give up after N failed retries","migration 042's permanent cap",{ w:"After five failures or two hours, stop trying forever.", t:"Policy replaced.", f:["backend/supabase/functions/_shared/matchday-retry.ts"] }),
D("x.cappedb",9, 1, "code","live","Spaced backoff and a 12-hour deadline","the cap is now just a terminal marker",{ w:"Long enough to cross a full quota-reset cycle.", t:"Live." }),
D("x.cappedw",9, 2, "guard","live","A permanent give-up needs a human, and there is one","nothing stated",{ w:"The cap did kill the every-minute 429 storm — and it also meant a match whose fire failed never produced content again without a manual re-fire. “For a one-person team that won't do anything manually, a permanent give-up is the wrong trade-off.”", t:"—", f:["backend/supabase/functions/_shared/matchday-retry.ts"] }),

D("x.prep",  10, 0, "surface","paused","Ship the day-before push","prep-reminder",{ w:"Built, scheduled, and switched off at the scheduler.", t:"Paused.", x:["cron.prep"] }),
D("x.prepb", 10, 1, "guard","paused","Nothing, until the app catches up","130_*.sql.PENDING_APP_RELEASE",{ w:"The migration that would unpause it is deliberately not named as a migration, so it cannot be applied by accident.", t:"—" }),
D("x.prepw", 10, 2, "guard","live","A push must land somewhere that exists","un-pause when 2.3 is in the store",{ w:"It opens a screen that only exists in an app version not yet released. A push that opens nothing is the worst possible first impression of a feature.", t:"—", f:["PUSH_RULES.md"] }),

/* C — the simpler thing, on purpose */
D("x.llm",  12, 0, "surface","dormant","Let the model pick the key players","a prompt and a squad list",{ w:"Hand Claude the squad and ask who matters.", t:"Removed 2026-09-30.", f:["backend/supabase/functions/_shared/featured-players.ts"] }),
D("x.llmb", 12, 1, "code","live","Rank on minutes, then let it write","hand Claude the answer, not the question",{ w:"The pick is arithmetic. The model supplies only the sentence.", t:"Live, on both write paths.", x:["sh.featured","r.teampage"] }),
D("x.llmw", 12, 2, "guard","live","Asked a form question with no form data, it answered from reputation","nothing — this is now the house pattern",{ w:"The squad payload carries names, ages, shirt numbers and photos and no statistics. Across 20 clubs that put 20 of 60 picks outside their own squad's top fifteen by minutes, one of them a goalkeeper with zero minutes all season.", t:"—", g:"The general form: if a judgement can be computed, compute it and let the model do the voice. A scheduled rewrite is not a correction mechanism — it asks the same question with the same missing information and gets the same answer forever.", f:["backend/supabase/functions/_shared/featured-players.ts"] }),

D("x.tier",  13, 0, "surface","dormant","Renumber the tiers to match the brief","1 = deepest",{ w:"Anton ranked them top-down in conversation; the database ranks them bottom-up.", t:"Rejected.", f:["TIERS.md"] }),
D("x.tierb", 13, 1, "code","live","Keep the integer, name the levels","Light · Match-fit · Deep",{ w:"The names carry the ranking so the number never has to.", t:"Live.", x:["g.pushgate"] }),
D("x.tierw", 13, 2, "guard","live","Flipping it would silently demote every live device","nothing, while production rows exist",{ w:"Ten of the twenty devices in production are on tier 3. Reversing the meaning of the integer would move all of them to the lightest level with no migration and no signal.", t:"—", f:["TIERS.md"] }),

D("x.gate",  14, 0, "surface","dormant","Use the tier as a paywall in the app","hide content from lower tiers",{ w:"Gate what she can see by what she pays.", t:"Rejected.", f:["TIERS.md"] }),
D("x.gateb", 14, 1, "code","live","Tiers gate notifications only","she always sees everything in the app",{ w:"If she opens GoalDigger she sees everything we have for her club.", t:"Live.", x:["sf.feed"] }),
D("x.gatew", 14, 2, "guard","live","It punishes the person who already chose us","nothing — this is a product promise",{ w:"“Gating in-app content is a punishment for someone who already chose us and told us she wants less noise. Gating pushes is a service.”", t:"—", g:"One carve-out: actions — the quiz and the group-chat prep — are surfaced by default at Deep and available on demand to everyone.", f:["TIERS.md"] }),

D("x.qh",  15, 0, "surface","dormant","Queue night-time pushes for the morning","a delay instead of a drop",{ w:"Hold anything written between 21:00 and 06:00 and send it later.", t:"Rejected.", f:["PUSH_RULES.md"] }),
D("x.qhb", 15, 1, "guard","live","Drop the push, keep the card","push_eligible = false",{ w:"It publishes to the feed and never pushes. The morning run carries the day's notifications.", t:"Live.", x:["g.pushgate"] }),
D("x.qhw", 15, 2, "guard","live","A delayed push arrives detached from what caused it","nothing stated",{ w:"The 00:30 run produced 32% of August's Premier League pushes between 23:37 and 00:03 London, against a store listing that promises we don't send at 3am.", t:"—", f:["PUSH_RULES.md"] }),

D("x.rows",  16, 0, "surface","dormant","One row per followed club","a device_follows join table",{ w:"The normalised shape.", t:"Rejected.", f:["ARCHITECTURE.md"] }),
D("x.rowsb", 16, 1, "store","live","Arrays on one row per device","UNIQUE(apns_token) preserved",{ w:"Up to two clubs and two countries as array columns, with the scalar team_id kept as array[0] for compatibility.", t:"Live.", x:["store.tokens"] }),
D("x.rowsw", 16, 2, "guard","live","One row per device makes a double push structurally impossible","nothing stated",{ w:"Even when a device follows both sides of a fixture. It also keeps token expiry and Delete My Data to a single row.", t:"—", g:"Never drop UNIQUE(apns_token) — the direct upsert depends on it.", f:["ARCHITECTURE.md"] }),

D("x.feed",  17, 0, "surface","dormant","Show the feed's own predictions","percentages and advice",{ w:"API-Football returns prediction percentages and an advice string.", t:"Rejected.", f:["backend/supabase/functions/_shared/matchup-card.ts"] }),
D("x.feedb", 17, 1, "code","live","Use the verdict to pick a tone","never show a number",{ w:"The card reads as confidence, not as odds.", t:"Live." }),
D("x.feedw", 17, 2, "guard","live","The advice string is literally betting copy","nothing",{ w:"“Double chance : draw or Sunderland”, and the percentages are the feed's own model. The app uses the verdict to pick a tone. It does not show a number.", t:"—", g:"The same boundary governs /coachs: do not improve a heuristic against a feed that has already been shown to omit the answer entirely. A feed that proves itself wrong about a field loses that field permanently.", f:["DATA_SOURCES.md"] }),

D("x.photo",  18, 0, "surface","dormant","Null the placeholder player photos","the 55 grey silhouettes",{ w:"Clear photo_url where the image is the shared placeholder.", t:"Rejected.", f:["DATA_SOURCES.md"] }),
D("x.photob", 18, 1, "code","live","Count them and leave them","do not claim every player has a face",{ w:"8.9% of players show a silhouette. It is counted and documented.", t:"—", x:["store.players"] }),
D("x.photow", 18, 2, "guard","live","The nightly sync would write it straight back","a change to the sync, or a rendering that no longer reads as an avatar",{ w:"players.photo_url is rewritten every night from the squad payload, so nulling it would not survive until morning. And unlike the manager placeholders it reads as a deliberate avatar rather than a broken image.", t:"—", f:["DATA_SOURCES.md"] })
];

const M5_EDGES = [];
for (const n of M5_NODES.filter(x => x.c === 0)) {
  const mid = M5_NODES.find(x => x.c === 1 && x.r === n.r);
  const why = M5_NODES.find(x => x.c === 2 && x.r === n.r);
  if (mid) M5_EDGES.push({ from:n.id, to:mid.id, label:"", kind:"dead" });
  if (mid && why) M5_EDGES.push({ from:mid.id, to:why.id, label:"", kind:"flow" });
}

MODELS.m5 = { title:"Deliberately not built", cols:M5_COLS, bands:M5_BANDS, nodes:M5_NODES, edges:M5_EDGES, rowH:104, dir:"lr" };
