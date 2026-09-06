# Självrannsakan 2026-09 — Goal Digger: utskick & innehåll

**Datum:** 2026-09-06 · **Scope:** Premier League i dagsläget (huvudspår) + VM-slutspelet
28 jun–19 jul (lätt retrospektiv) · **Status:** Spår A (kod/konfig) klart · Spår B: snapshot tagen 2026-09-06 11:45 CEST
(`audit/2026-09/out/`), **B1 klart** (driftfacit), B2–B7 pågår.

Granskningen bygger vidare på `CONTENT_PUSH_AUDIT_2026-06.md` (5 juni) och använder samma
princip: deterministiskt först, LLM-omdömen bara på urval, och **bara interna motsägelser räknas
som "osant"** (juniauditens lärdom om stale spelartrupper). Allt är read-only mot prod.

---

## 0. Sammanfattning (TL;DR)

0. **NYTT (B1): Prod har varit nere sedan 30 aug 16:32 CEST — sju dagar utan en enda cron-körning.**
   `cron.job_run_details` visar sista körning 30 aug 14:32 UTC; därefter tystnad till omstarten
   6 sep 11:38 CEST. Degraderingen började 23 aug 16:06 CEST ("job startup timeout" på
   match-watcher ×3976, sweep ×79, data-fetcher ×39; statement timeouts på Vault-läsning och
   `pipeline_health`-frågor). Dashboarden visade **Disk IO 100 %, Compute 100 %** på `t4g.nano`.
   Sista routine-post 29 aug 11:17 CEST, sista push 29 aug 08:56 CEST. Larmet som skulle ha sagt
   till (`check_pipeline_heartbeat`) kraschar självt på en `FORMAT('%.0f')`-bugg. (A14, A15 — P0)
1. **Routines kör fortfarande säsong 2025-26 för PL.** `fetch_news.sh` hämtar tabellen för
   `season=2025` med förra truppen (Coventry/Hull saknas, West Ham/Wolves/Burnley kvar);
   `MATCHDAY_PROMPT.md` hämtar `season=2025`-tabellen; `PROMPT.md` säger "2025-26 season".
   Edge-sidan (`seasonForLeague`, mig 074) är rätt. → Risk att nyheter/matchday-briefar i
   aug–sep citerar **förra säsongens tabell**; **inga nyheter för Coventry/Hull**. (A1, P0)
2. **PL-följare får ingen matchdags-påminnelse.** `matchday-reminder` är hårdkodad till
   länder; PL skulle "läggas till när ligan återupptas" — gjordes aldrig. Enda förmatch-
   pushen för PL är `morning-push` 08:00 UTC med London-tider. (A2, P0)
3. **VM-läget lever kvar trots att VM är slut.** Onboarding tvingar nya användare att välja
   VM-land först; `gd-news-wc`/`gd-wc-preview`/`gd-wc-factcheck` står som schemalagda;
   `match-watcher` pollar VM-ligan varje minut; `data-fetcher` hämtar 48 länder var 2:e
   timme. iOS-fliken gömmer sig själv sedan 22 jul — resten gör det inte. (A3, P0 → pausa)
4. **B1-svar: den oguardade API-vägen är död.** `matchday-scheduler` finns inte i `cron.job`,
   noll `pipeline_source='edge_function'`-items sedan 19 jul 22:04 UTC (VM-finalens FT-artikel),
   inga `generate`/`review`-stages i `pipeline_health` sedan 1 jun. Kvar: latent risk (gaten
   saknas fortfarande i `content-generator`) → nedgraderad till P2 städning. (A9)
5. **Farlig commit på en gammal branch (3 aug, `b7df6ae`)** duplicerar mig 074 med fel API-id
   för Coventry/Hull och en `UPDATE teams SET league_id=39` som skulle flytta alla 48
   VM-länder till PL. **B1-svar: prod är oskadd** — 48 länder `league_id=1`, Coventry 1346,
   Hull 64, 20 aktiva + 5 inaktiva klubbar. Får fortfarande aldrig mergas. (A6, P0 → process)
6. **Prod ≠ git — B1 bekräftar och förvärrar.** `supabase_migrations.schema_migrations` innehåller
   bara 001–017; 018–077 är körda för hand. Archive-cronen (jobid 2, sedan 22 apr) gör
   `UPDATE … status='archived'` (flip, **ingen historik raderad**: 3 120 arkiverade rader kvar).
   Status-CHECK i prod har `retrying` + `archived` som saknas i alla migrationer. Fem crons ur
   mig 003 (`matchday-scheduler`, `data-fetcher`, `cleanup-*`) är borttagna utanför git.
   (A12/A13, P0-process)
7. **Nattpushar är policy, inte bugg:** `gd-news` fyrar 00:30 UTC (01:30–02:30 svensk tid) och
   servern har inga quiet hours sedan 17 maj (flyttat till iOS DND). Juniauditen kallade
   nattpusharna "lösta"; schemat kvarstår. Mät i B2 och besluta. (A4, P1/policy)
8. **Blandade tidszoner i kopian:** morning-push skriver BST/GMT, matchday-reminder Stockholm,
   iOS enhetslokalt. (A5, P1)
9. **Retention:** snapshoten är tagen och committad (`audit/2026-09/out/`, 50+ filer, 11 MB
   `06b`). Paradoxalt har driftstoppet räddat loggen: gallringssweepen har inte körts sedan
   30 aug. **Nytt:** `cron.job_run_details` (177 070 rader, 88 MB) har ingen gallring alls och
   är näst största tabellen; `raw_fetch_logs` är 169 MB på disk men bär ~16 MB levande data
   (bloat). (A11, A16)
10. VM-slutspelet: koden hanterar förlängning/straffar och knockout-rundor korrekt; men
    automatiska matchförhandsvisningar landade först 10 juli (R32 + R16 utan), och 28 juni
    postades 48 sunday_briefs manuellt i bulk. (A10, P2)

---

## 1. Metod, källor och avgränsningar

**Källor (sanningen i fallande ordning):** produktions-DB (Spår B, väntar) → app-trunken
`origin/claude/intelligent-thompson` (ARCHITECTURE.md är auktoritativ) → routines-repot
`anton-tech43/goaldigger-routines` `main` (den levande röst-specen `PROMPT.md`) →
`CONTENT_PUSH_AUDIT_2026-06.md`, `AUDIT_FINDINGS.md`, `IMPLEMENTATION_PROGRESS.md`
(lärdomar 63–102). **Inte** använt som måttstock: app-repots `PROMPTS.md` (stale V1).

**Måttstock för innehåll:** routines `PROMPT.md` (GOLDEN RULE, GROUNDING, TEAM IMPACT-gate,
TRANSFER-gate, HEADLINE CLARITY, SAGA/REPEAT, opener-rotation, bannad register, TP-regler,
IMMERSIVE HEADLINE ≤22/rad, ANALOGY RULES + självkritik, ≤16 ord) och segmentprompterna;
hårda gates i `post_news.sh`.

**Måttstock för timing:** routine-scheman (`gd-news` 06:30/12:30/18:30/00:30 UTC; `gd-news-wc`
+5 min; insider 02:00; season-state 06:30; quiz lör 07:00; sunday brief sön 09:00; dossier
sön 17:00); crons (match-watcher varje minut, morning-push 08:00 UTC, matchday-reminder 07:00
UTC, notification-sweep :15, content-audit 03:30, data-fetcher `0 6-22/2`); live-push-regler
(mål vid poängändring, HT/FT/PREKICK bara på observerad övergång); notification-sender
(`push_eligible`, 5-min-throttle per lag, sweep 5 min grace/24 h tak, tier-gate).

**Avgränsningar (sägs öppet):** iOS-rendering på enhet kan inte granskas härifrån; APNs
rapporterar inte öppningar; routines run-loggar syns inte från CLI; live-pushar (mål/HT/FT)
lämnar **ingen textlogg** — bara `briefs_fired`-markörer och aggregerade `apns_send`-rader
sedan 15 jun, så där granskas mallar + markörer, inte exakt levererad text.

**Kör Spår B så här (Anton, ~2 min, read-only):**
```bash
./audit/2026-09/run_audit.sh        # läser backend/.env, skriver audit/2026-09/out/*.csv
cd audit/2026-09 && zip -r audit_out_$(date +%Y%m%d).zip out/
```
Filerna `06b_pipeline_health_dump.csv` och `07_match_status_state.csv` är retention-snapshoten
— ta dem även om resten får vänta.

---

## 2. Prioriterad åtgärdslista

| Prio | ID | Åtgärd | Var |
|---|---|---|---|
| **P0** | A1 | Sätt PL-säsong och trupp 2026-27 i routines: `fetch_news.sh` (`SEASON`, `TEAMS` → läs `teams` där `league_id=39 AND is_active`), `MATCHDAY_PROMPT.md:57,61`, `PROMPT.md:20`, `SUNDAY_BRIEF`/`QUIZ`/`INSIDER` om de nämner 2025-26. Verifiera att Coventry/Hull får items. | routines |
| **P0** | A2 | Aktivera matchdags-påminnelse för PL-klubbar (`matchday-reminder`: ta bort `entity_type='country'`-filtret, token-matcha på `team_id/team_ids`, Stockholm-tid). | app |
| **P0** | A3 | **Pausa VM-läget** enligt checklistan i §4 (onboarding PL-först, stäng VM-routines, stoppa liga-1-pollning och landshämtning). | båda |
| **P0** | A14 | **Driftstopp 23 aug → 6 sep.** Omstart gjord 6 sep 11:38 CEST (match-watcher grön från 11:50). Kvar: hitta och ta bort IO-drivaren innan det händer igen — (a) `teams.is_active=false` för 48 länder (70 % av data-fetcher-jobbet, A3), (b) gallra `cron.job_run_details` (A16), (c) `VACUUM (FULL)`/repack av `raw_fetch_logs` (169 MB → ~20 MB) i ett servicefönster, (d) överväg Micro-compute om (a)–(c) inte räcker. Skriv in "DB Unhealthy"-runbook. | prod/Anton |
| **P0** | A15 | **Larmet kraschar.** `check_pipeline_heartbeat` CHECK 2 använder `FORMAT('… %.0f%% …')` — Postgres `format()` stöder inte `%.0f` → `unrecognized format() type specifier "."` (13 ggr 25–30 aug). Byt till `round(…)::text` med `%s`. Utan detta finns ingen signal när crons dör. | app (mig 037/039/041:109-116) |
| **P1** | A16 | `cron.job_run_details` saknar gallring (177 k rader / 88 MB, 1 440 rader/dag från match-watcher). Lägg cron `DELETE … WHERE end_time < now() - interval '7 days'` (Supabase-rekommendation). | app (ny migration) |
| **P2** | A9 | **Död väg, bekräftat i B1.** Städa: ta bort `matchday-scheduler`-funktionen + lägg `CONTENT_GENERATOR_ENABLED`-gate i `content-generator` så den inte kan väckas av misstag. | app |
| **P0→process** | A6 | Merga/kör **aldrig** `b7df6ae`/branchen `claude/create-markdown-file-hIdbj`. **Verifierat oskadd i prod 6 sep** (`03_teams.csv`). Ta bort branchen på origin. | process |
| **P0** | A12 | Dokumentera prod-driften: `01_cron_jobs.csv` är facit. Skriv migrationer för archive-cronen (`UPDATE … 'archived' … published_at < now()-7d AND preview_fixture_id IS NULL`, 06:00 UTC), status-CHECK (`retrying`,`archived`), unschedule av `matchday-scheduler`/`data-fetcher`/`cleanup-*`. Bestäm om `schema_migrations` ska backfyllas 018–077 eller om `supabase db push` överges formellt. | app |
| ~~P0~~ ✔ | A11 | Retention-snapshot tagen 6 sep 11:45 CEST och committad (`a4c5650`). | — |
| **P1** | A4 | Besluta nattpush-policy: flytta `gd-news` 00:30 UTC → t.ex. 05:30 UTC, och/eller återinför server-quiet-hours 22–07 Stockholm i `notification-sender` (håll live-pushar undantagna). | routines/app |
| **P1** | A5 | En tidszon i all kopia: Europe/Stockholm (morning-push `formatKickoff`, content-generator `kickoff_day`). | app |
| **P1** | A7 | Nollställ förra säsongens `consequence_type`-rader för PL så TITLE_WON/RELEGATED/UCL kan fira 2026-27 (mig 051-instruktion). | prod (SQL) |
| **P1** | A13 | Branch-hygien: gör trunken till `main` (eller döp om), pusha lokala commits, re-basa arbetsbranches. | process |
| **P2** | A8 | Bekräfta tier-gates mot produktavsikt (sunday_brief T2+, quiz T3+). | policy |
| **P2** | A10 | VM-retro-lärdomar → nästa turnering (previews i tid, ingen manuell bulk-postning). | docs |
| **P2** | — | Uppdatera routines `README.md` (säger "6 lag var 6:e timme"). | routines |

**Policyfrågor att ta ställning till (inte buggar):** nattfire 00:30 UTC; quiet hours på server
eller enhet; tier-gates; push-volym (~19 push-berättigade items/dag i juni — mät igen i B2).

---

## 3. Spår A — fynd i detalj

Alla rader citerar trunken (`origin/claude/intelligent-thompson`) respektive routines `main`
per 2026-07-10.

### A1 · Säsong 2025-26 ligger kvar i routines — **P0**
- **Bevis:** `goaldigger-routines/fetch_news.sh:21-52` (kommentar "2025-26 Premier League
  roster", `burnley`, `west_ham`, `wolves` med; `coventry`/`hull` saknas), `:71` `SEASON="2025"`,
  `:104` `standings?league=39&season=2025`. `MATCHDAY_PROMPT.md:57`
  (`standings?league=39&season=2025`), `:61` ("2025-26 PL clubs are the 20 not marked
  [relegated]"). `PROMPT.md:20` ("`club` — Premier League 2025-26 season").
  Kontrast: `post_news.sh:207` `pl_clubs` = 2026-27 (coventry, hull, ipswich; ej west_ham/
  wolves/burnley) — commit `16b3f6b` 17 jun uppdaterade **bara** post-gaten och `schema.json`.
  Edge-sidan är rätt: `_shared/league-helpers.ts:24-31` (`seasonForLeague(39)` = 2026 från
  juli), `migrations/074_pl_roster_2026_27.sql`, `data-fetcher/index.ts:296-303` (`is_active`).
- **Symptom:** gd-news matar modellen med 2025-26-tabell/fixtures → tabellpåståenden
  ("ligger 4:a") kan vara förra säsongens; `content-audit` (som läser rätt tabell ur
  `raw_fetch_logs`) bör fånga en del — kolla `19_content_audit_findings.csv`. Coventry/Hull:
  0 nyhetsitems (kolla `18_items_per_team.csv`). Nedflyttade lag: fortsatt hämtning + möjliga
  items till 0 följare.
- **Åtgärd:** Läs laglistan ur `teams` (som Edge gör) och säsongen datumstyrt (kopiera
  `seasonForLeague`-logiken till bash); rensa "2025-26" ur prompterna → `{{season}}`.

### A2 · Ingen matchdags-påminnelse för PL — **P0**
- **Bevis:** `matchday-reminder/index.ts:48-52` (`.eq("entity_type","country")` med kommentar
  "PL clubs are off-season during the WC; their reminders … can be added when the league
  resumes"); `migrations/063_matchday_reminder.sql:1-12`. `AUDIT_FINDINGS.md` PUSH-8/SCHED-1
  bekräftar att PL medvetet uteslöts i juni.
- **Symptom:** PL-följare får ingen "han spelar i dag" 09:00; bara `morning-push` 08:00 UTC
  (`morning-push/index.ts:83-90`, 18 h-fönster) — som dessutom skriver London-tid (A5).
- **Åtgärd:** öppna för klubbar; källa `team_season_state.next_fixtures` finns redan för PL.

### A3 · VM-läget lever kvar — **P0 (pausa)**
- **Bevis:** iOS onboarding `Views/Onboarding/OnboardingFlow.swift:9-12,17,47-48,107-109`
  ("country is mandatory at step 3", `HisNameView { step = .countrySelection }`). VM-fliken
  självgömd: `Models/FeedContext.swift:71-77` (`hideAfter 2026-07-22`). Routines:
  `PROMPT_WC.md:101` (`gd-news-wc` `35 6,12,18,0 * * *`), `WC_PREVIEW_PROMPT.md:3,27`,
  `WC_FACTCHECK_PROMPT.md:3`, `SEASON_STATE_PROMPT.md:3` (alla lag inkl. länder). Edge:
  `match-watcher/index.ts:498-513` (itererar alla `league_id`, ingen `is_active`),
  `league-helpers.ts:30` (`case 1: return 2026` för alltid), `data-fetcher/index.ts:296-316`
  (länder hämtas var 2:e timme; `is_active` default true), `team-page-generator` dynamic
  refresh för länder.
- **Symptom:** nya användare i september tvingas välja VM-land; kvot/API bränns på 48 länder
  utan matcher; risk för stale VM-innehåll i länders feeds.
- **Åtgärd:** §4.

### A4 · Nattpushar som policy — **P1 / policy**
- **Bevis:** routines `README.md:56` + `PROMPT_WC.md:101` (00:30/00:35 UTC = 01:30–02:30
  Stockholm). `notification-sender/index.ts:1-22` ("Quiet hours are handled by iOS Do Not
  Disturb… Server no longer applies quiet-hours"); `_shared/anti-spam.ts` borttagen 17 maj
  (commit `5c9cbf2`). Juniauditen: "47 news pushes 00:38–00:54 UTC … since-resolved
  schedule artifact" — men schemat innehåller fortfarande 00:30.
- **Symptom:** nyheter som klarar gaten vid 00:30-fire pushas mitt i natten om användaren inte
  har DND. Mät: `09_pushes_by_hour_sthlm.csv`, `10_night_pushes.csv`.
- **Åtgärd:** flytta 00:30-fire eller lägg 22–07-fönster i `notification-sender` (låt
  `match-watcher`-live-pushar vara).

### A5 · Blandade tidszoner i kopian — **P1**
- **Bevis:** `morning-push/index.ts:48-75` (`Europe/London`, suffix BST/GMT, motivering "most
  users are UK/EU"); `_shared/matchday-reminder-copy.ts:9-22` (`Europe/Stockholm`);
  `content-generator/index.ts:715` (`toLocaleDateString` utan `timeZone` → UTC-veckodag);
  iOS `ImmersiveCard`/`MatchDayCard` enhetslokalt. Publiken är svensk
  (`063_matchday_reminder.sql:6-7`).
- **Åtgärd:** en TZ-konstant (Stockholm) för all serverkopia.

### A6 · Farlig commit på gammal branch — **P0 (process)**
- **Bevis:** `b7df6ae` (3 aug) på `origin/claude/create-markdown-file-hIdbj`, merge-base med
  trunken = 14 apr. Dess `074_season_2026_coventry_hull.sql` innehåller
  `UPDATE teams SET league_id = 39 WHERE league_id IS DISTINCT FROM 39`, Coventry/Hull med
  api-id **1343/332** (trunkens verifierade: **1346/64**, `074_pl_roster_2026_27.sql:27-30`),
  och hårdkodad `season=2026` i `data-fetcher` (trunken har `seasonForLeague`).
  Commit-texten listar själv "BLOCKERS: CLAUDE.md/ARCHITECTURE.md/BACKFILL_RULES.md missing".
- **Åtgärd:** aldrig merga; verifiera i `03_teams.csv`/`03b_teams_by_league.csv`; ta bort
  branchen när det bekräftats.
- **B1-svar (6 sep):** **oskadd.** `03b`: `country/1/active=48`, `club/39/active=20`,
  `club/39/inactive=5` (burnley, leicester, southampton, west_ham, wolves), `tournament/NULL=1`.
  `03`: coventry `api_football_id=1346`, hull `64`, sunderland `746`. Inga länder utanför liga 1.
  Branchen kan raderas.

### A7 · Konsekvenslagrets säsongsgräns — **P1**
- **Bevis:** `migrations/051_consequence_layer.sql:19-23` ("At PL season boundary, run a one-
  line UPDATE to NULL prior-season rows so next season's clinches can fire (RUNBOOK)").
  Unikt index `(team_id, consequence_type)` per lag.
- **Symptom:** lag som fick TITLE_WON/RELEGATED/UCL_CLINCHED 2025-26 kan inte få samma
  konsekvens 2026-27. Kolla `30_consequence_rows.csv`.

### A8 · Tier-gates — **P2 / policy**
- `notification-sender/index.ts:274` (`sunday_brief` kräver tier ≥2); quiz T3+ (`quiz-current`).

### A9 · `matchday-scheduler` → `content-generator` utan gate — **P0 (verifiera)**
- **Bevis:** `matchday-scheduler/index.ts:13` (kickoff−90), `:105-110` (hoppar länder → kör
  för PL), `:145,159,171` (`triggerFunction("content-generator", …)`).
  `CONTENT_GENERATOR_ENABLED` kontrolleras **bara** i `data-fetcher/index.ts:364` — inte i
  `content-generator`. Cron `matchday-scheduler` 07:00 UTC från `003_pg_cron_jobs.sql:28-39`
  med inline-JWT; inte omskriven i 019/020 (som bara tog match-watcher, sweep, heartbeat).
- **Symptom (två möjliga):** (a) cronen fungerar → varje PL-matchdag genereras en
  `edge_function`-matchday-item med gammal röst utan `post_news.sh`-guards, som
  `notification-sender`-sweepen pushar (`:58-59`), och Claude-API faktureras
  (CLAUDE.md-hårdregel); (b) cronen är död sedan nyckelrotationen 11 maj → tyst.
- **Åtgärd:** `01_cron_jobs.csv` + `13_pipeline_health_daily.csv` (stage `generate`/`review`)
  + `08_pl_items.csv` (`pipeline_source='edge_function'`). Därefter: avschemalägg.
- **B1-svar (6 sep): utfall (b), vägen är död.** `01_cron_jobs.csv` har 11 jobb — inget
  `matchday-scheduler` (och inget `data-fetcher`/`cleanup-*` ur mig 003 heller; borttagna
  utanför git). `08_pl_items.csv`: 433 PL-items sedan 1 aug, **0** med
  `pipeline_source='edge_function'`; sista edge-item i hela tabellen 19 jul 22:04 UTC (`06`).
  `06b`: inga `generate`/`review`-stages sedan 1 jun. Nedgraderas till P2 (städa död kod +
  lägg gaten så den inte kan väckas).

### A10 · VM-slutspelet (retro, lätt) — **P2**
- **Rätt i koden:** AET/PEN och knockout-runda hanteras (`match-watcher/index.ts:47,946-1026`),
  FT/HT/PREKICK fyrar bara på observerad övergång (Lesson 100), eliminering pushas aldrig
  (design), UTC-datum för US-nattmatcher fixat i juni (`:491-497`).
- **Brister:** `gd-wc-preview`/`gd-wc-factcheck` landade **10 jul** (`9b3ba79`) → R32 (28 jun–
  3 jul) och R16 (4–7 jul) utan automatiska förhandsvisningar; **48 sunday_briefs postades
  manuellt 28 jun** (`post_wc_briefs_2026_06_28*.py`) → burst + T2-gate; dubbel-FT-suppress
  bygger på rubrik-scoreline-matchning (mig 065, heuristik); `gd-matchday` avstängd för VM →
  deterministisk FT-artikel. Data: `31_wc_knockout_matches.csv`, `32_wc_items.csv`,
  `33_jun28_burst.csv`, `34_wc_apns_send_daily.csv`.

### A11 · Retention — **P0 (kör nu)**
- `003_pg_cron_jobs.sql:67-71` + `043_pipeline_health_retention_sweep.sql` (90 d),
  `057_raw_fetch_logs_retention.sql` (7 d), rejected 14 d. `apns_send`-loggning från 15 jun
  (`6a17033`) → första VM-rader gallras ≈ 13 sep.

### A12 · Schema- och cron-drift mellan prod och migrationer — **P0 (process)**
- **Bevis:** `content_items.status` CHECK i migrationer = draft/approved/rejected/published
  (`001_initial_schema.sql:32`; ingen senare ALTER), men routines `README.md:88`,
  `PROMPT.md` och STATUS Lesson 93/96 använder `status='archived'` och en daglig cron
  `goaldigger-archive-old-content` som **inte finns i någon migration**. Alltså ändrat direkt
  i prod. Dessutom nämner STATUS "app-repo commits are local (14 ahead, unpushed)".
- **Åtgärd:** B1 (`01_cron_jobs.csv`, `04_content_items_constraints.csv`,
  `05_migrations_applied.csv`) → skriv ikapp migrationer.
- **B1-svar (6 sep):**
  - **Archive-cronen är en flip, inte delete:** jobid 2 `goaldigger-archive-old-content`,
    `0 6 * * *`, `UPDATE content_items SET status='archived' WHERE status='published' AND
    published_at < NOW() - INTERVAL '7 days' AND preview_fixture_id IS NULL`. Aktiv sedan
    22 apr (131 körningar). Historiken finns: 3 120 `archived`-rader, äldsta 20 apr. Bara
    `preview_fixture_id`-items (VM-previews) undantas — inte matchday-items.
  - **Status-CHECK i prod:** `draft, approved, rejected, published, retrying, archived`.
    `retrying` (13 rader, apr) och `archived` finns i ingen migration. `push_text`-CHECK är
    ≤100 i prod (post_news.sh säger ≤90 — gaten är strängare än DB:n, OK).
  - **`schema_migrations` = 001–017.** Allt från 018 (maj) och framåt är kört via SQL Editor.
    Dashboarden visar "No migrations". `05` kan inte användas som facit; `01`+`04` är facit.
  - **Crons i prod (11):** match-watcher-1min `* * * * *`, notification-sweep `15 * * * *`,
    goaldigger-cron-heartbeat-check `*/30`, goaldigger-daily-pipeline `0 6-22/2`,
    gd-morning-push `0 8`, goaldigger-matchday-reminder `0 7`, content-audit-nightly `30 3`,
    pipeline_health_retention_sweep `0 3`, raw_fetch_logs_retention_sweep `15 3`,
    match-status-reaper `0 5`, goaldigger-archive-old-content `0 6`. Alla `active=t`.
  - **I git men inte i prod:** `matchday-scheduler`, `data-fetcher` (003-namnet),
    `cleanup-raw-logs`, `cleanup-health-logs`, `cleanup-rejected-content` (003),
    `team-season-state-daily`. Bara den sista har en `unschedule` i en migration.
  - **Triggers:** `trg_suppress_wc_result_recap_push` (mig 065) och `trg_la_tokens_touch` — båda
    förväntade.

### A13 · Branch-hygien — **P1**
- `origin/main` senast 26 apr; trunk = `origin/claude/intelligent-thompson` (10 jul); båda repon
  orörda sedan 10 jul trots drift i augusti/september; min tilldelade branch var baserad på
  den gamla linjen och raderad på origin. Arbetsbranchen är nu omsatt på trunken.

### A14 · Driftstopp: DB överbelastad 23 aug → nere 30 aug → omstart 6 sep — **P0 (nytt, B1)**
- **Bevis:** `38_cron_last_run_ever.csv`: alla 11 jobb har `last_run` 30 aug 03:00–14:32 UTC
  utom match-watcher (som återupptogs 6 sep 09:46 UTC efter omstarten). `38b`: från 23 aug
  16:06 CEST `job startup timeout` (match-watcher 3 976, sweep 79, data-fetcher 39,
  heartbeat 155) och `canceling statement due to statement timeout` på `vault.decrypted_secrets`,
  `net.http_request_queue`-insert och `pipeline_health`-aggregat. `02`: match-watcher 5 877 ok /
  3 997 fel i 14-dagarsfönstret. Dashboard 6 sep: Status Unhealthy, **Disk IO 100 %, Compute
  100 %**, Memory 46 %, `t4g.nano`; poolern: `CONNECT_TIMEOUT` → `auth_query secret check timed
  out` → `ECIRCUITBREAKER`. `37f`: `pg_postmaster_start_time` 11:38:46 CEST; `pg_stat_*`
  nollställt (ostädad nedstängning). `41`: match-watcher grön 0,3–0,5 s från 11:50 CEST.
- **Konsekvens för användare:** sista routine-post 29 aug 11:17 CEST (`17b`), sista push 29 aug
  08:56 CEST (`08`), sista data-fetch 29 aug 12:01 CEST (`06`). PL-omgången 29–31 aug och all
  vecka 36 gick helt utan innehåll, pushar, morning-push och matchday-reminder. `content_items`
  publicerade >7 d har inte arkiverats (sweep död) → feeden visar gammalt.
- **Orsakshypotes (ej bevisad, stats nollställda):** konstant skrivtryck på nano-IO-budget:
  match-watcher 1 440 anrop/dygn oavsett om matcher finns (varje anrop = Vault-läsning +
  pg_net-kö + `cron.job_run_details`-rad), data-fetcher på 68 entiteter var 2:e timme varav 48
  VM-länder utan matcher (`39`: 10 217 av 16 475 `raw_fetch_logs`-rader är länder), och två
  stora ostädade tabeller (`37`: `raw_fetch_logs` 169 MB varav ~16 MB levande, `job_run_details`
  88 MB). Dashboard-siffran 478 MB vs `pg_database_size` 308 MB antyder bloat/WAL.
- **Åtgärd:** se §2 A14. Runbook: "Unhealthy + CONNECT_TIMEOUT ⇒ Settings → General → Fast
  database reboot; kontrollera `select max(start_time) from cron.job_run_details`".

### A15 · Heartbeat-larmet kraschar på `FORMAT('%.0f')` — **P0 (nytt, B1)**
- **Bevis:** `38b`: `goaldigger-cron-heartbeat-check` → `ERROR: unrecognized format() type
  specifier "."` ×13 (25–30 aug), i `INSERT INTO client_errors`. Källa:
  `039_pipeline_health_sla_checks.sql:109` (och 037:116, 041:113): `'… (%.0f%% failure).'` —
  Postgres `format()` stöder bara `%s %I %L`. Exakt den check (CHECK 2, "pg_cron HTTP health
  degraded") som ska larma när crons fallerar dör alltså i larmögonblicket. Dessutom
  `statement timeout` i CHECK 1/5-frågorna mot `pipeline_health` under lasten.
- **Åtgärd:** `format('… (%s%% failure)', round(pct)::text)`; lägg `SET statement_timeout` lokalt
  i funktionen eller indexera bättre; testa att en fejkad 50 %-failure skriver en
  `client_errors`-rad.

### A16 · `cron.job_run_details` växer obegränsat — **P1 (nytt, B1)**
- **Bevis:** `38c`: 177 070 rader, 21 apr → nu, 88 MB (`37`: näst största relationen, 84 MB
  heap). pg_cron gallrar inte själv; Supabase rekommenderar en daglig `DELETE … end_time <
  now() - interval '7 days'`. Mig 003 hade `cleanup-*`-jobb men inget för pg_cron:s egen logg.
- **Åtgärd:** ny migration med gallrings-cron (behåll 14 d); engångs-`DELETE` + `VACUUM` efter att
  snapshoten (`38*`) är säkrad — den är det nu.

---

## 4. Checklista — "Pausa VM-läget"

**iOS (kräver build)**
- [ ] Onboarding: PL-klubb som obligatoriskt primärsteg, land valfritt/dolt
      (`OnboardingFlow.swift:107-109`, `CountrySelectionView`, `OptionalPLTeamView`).
- [ ] Settings: dölj/inaktivera landsväljaren (`SettingsView` country picker, commit `c428879`).
- [ ] Verifiera att `WCSeason.isVisible` (`FeedContext.swift:74-77`) faktiskt döljer fliken
      på enhet; gör gränsen server-styrd i stället för hårdkodad inför VM 2030.

**Routines (dashboard claude.ai/code/routines)**
- [ ] Inaktivera `gd-news-wc`, `gd-wc-preview`, `gd-wc-factcheck`.
- [ ] `gd-season-state`, `gd-insider`, `gd-player-dossier`, `gd-saturday-quiz`,
      `gd-sunday-brief`: begränsa iterationen till `entity_type='club'` (eller `is_active`).
- [ ] `PROMPT.md` COMPETITION CONTEXT: ta bort VM-fallet eller gör det inaktivt.

**Edge/DB (server, ingen build)**
- [ ] Bestäm en lever: `teams.is_active=false` för 48 länder **och** låt `match-watcher`,
      `team-page-generator`, `team-season-state-generator` filtrera på `is_active`
      (i dag gör bara `data-fetcher`/`content-audit` det). Alternativ: `league_id=NULL`
      för länder (skippas då överallt) — men bryter `FeedContext`-antaganden; välj medvetet.
- [ ] `match-watcher`: stoppa pollning av liga 1 (följer av ovan).
- [ ] Avsluta ev. öppna Live Activities / `live_activity_tokens` (mig 062, 070).
- [ ] `matchday-reminder`: byt från länder till PL-klubbar (A2).
- [ ] `world_championship`-entiteten (mig 076): lämna raden (FK), men se till att inga
      routines skriver till den.

**Verifiera efteråt:** `insights.sh 7` visar 0 nya VM-items; `cron.job`/`pipeline_health`
visar inga `matchday_fire`/`live_brief_fire` för liga 1; API-Football-kvot sjunker.

---

## 5. Spår B — väntar på data (fylls i när CSV:erna finns)

| Fråga | Fil(er) | Förväntan / hypotes |
|---|---|---|
| Vilka crons finns egentligen? Archive-cron? matchday-scheduler? | `01`, `02`, `04*`, `05`, `38*` | **Svar:** 11 crons, alla aktiva men **inga körningar 30 aug 14:32 UTC → 6 sep 09:46 UTC** (A14). Archive = `UPDATE status='archived'` (flip, historik kvar). `matchday-scheduler` finns inte (A9 död). `schema_migrations` = 001–017 (A12). Heartbeat kraschar på `FORMAT` (A15). `job_run_details` 88 MB ogallrat (A16). |
| Är teams-tabellen oskadd (A6)? | `03`, `03b` | **Svar: ja.** 48 × `league_id=1`, 20 aktiva + 5 inaktiva klubbar, Coventry 1346, Hull 64. |
| Infra: vad tar plats, vad skriver mest? | `37*`, `39`, `40` | **Svar:** DB 308 MB (`pg_database_size`) / 478 MB (dashboard). `raw_fetch_logs` 169 MB (≈16 MB levande → bloat), `cron.job_run_details` 88 MB, `pipeline_health` 27 MB, `content_items` 6,5 MB. 62 % av `raw_fetch_logs`-raderna är VM-länder. pg_net-köer tomma. |
| Publik (proportion) | `35`, `36` | **Svar:** 13 aktiva enheter (T2 9, T3 4), 12 följer PL-lag: arsenal 8, liverpool 2, leeds 1; 11 följer land (sweden 8). `empty_feeds`: coventry, hull (A1 bekräftat). |
| Nattpushar och timprofil | `09`, `10` | topp vid 02:30 Stockholm om 00:30-fire pushar |
| Dubbletter/burst per lag | `11`, `23`, `24` | throttle 5 min bör hålla; opener-repetition? |
| Aldrig skickat | `12`, `13`, `14` | sweep-fel, APNs-fel |
| PL-matchday-kedjan | `15` | fyrar `gd-matchday` för PL 2026-27? latens? |
| Förmatch-pushar PL | `16` | 0 reminders (A2); morning-push-rader finns? |
| Tysta dagar | `17`, `17b` | luckor i `cron_invoke`/`routine_post` |
| Coventry/Hull, inaktiva lag | `18` | 0 resp. >0 (A1) |
| Tabellpåståenden | `19`, `20` | content-audit-träffar; "2025-26"-glidningar |
| Formregler | `21`, `22`, `25`, `26` | längdtak, register, "Ask him", analogi-andel |
| Kadens | `27`, `28a-d` | sunday_brief varje söndag/lag? quiz varje lördag? season-state `mid_season` |
| Delad feed, konsekvenser | `29`, `30` | A7 |
| VM-slutspel | `31`–`34` | markörer per match, 28 jun-burst, kvarvarande logg |
| Publik | `35`, `36` | vem påverkas av A1/A2 |

**B4 (kvalitativt urval)** dras ur `08_pl_items.csv`: stratifierat per segment × vecka × lag,
läses mot §1-måttstocken, dubbelbedöms, och du spot-checkar ett delurval.

---

## 6. Koppling till användarfeedback

*(Fylls i tillsammans: lista feedbacken och mappa varje punkt mot A-fynd/B-mönster.)*

---

## 7. Bilaga — tidslinje (kod) juni–september 2026

| Datum | Händelse |
|---|---|
| 9 jun | PL-pushar feed-only under VM-fönstret (`post_news.sh`, datumgräns 9 jun–20 jul) |
| 11 jun | VM-start; Live Activity; ingen push till spelande lag på premiären → Lesson 100 |
| 12–17 jun | VM-live-pushar (mål/HT/FT), 40 varianter/pool, matchday-reminder, multi-team, arkitektur-audit |
| 17 jun | CONTENT-6: PL-trupp 2026-27 i Edge (mig 074) + `post_news.sh`/`schema.json` — **inte** `fetch_news.sh`/prompter |
| 28 jun | R32 startar; 48 sunday_briefs postas manuellt |
| 10 jul | Sista commits i båda repon: `gd-wc-preview`/`factcheck`, turneringsfeed, scorer-photos |
| 19–20 jul | VM-final; PL-push-pausen släpper 21 jul |
| 22 jul | iOS VM-flik gömmer sig själv |
| 3 aug | `b7df6ae` på gammal branch (A6) |
| ~15 aug | PL 2026-27 startar — routines på 2025-26-konfig (A1), ingen PL-reminder (A2) |
| 6 sep | Denna granskning |
