# Självrannsakan 2026-09 — Goal Digger: utskick & innehåll

**Datum:** 2026-09-06 · **Scope:** Premier League i dagsläget (huvudspår) + VM-slutspelet
28 jun–19 jul (lätt retrospektiv) · **Status:** Spår A (kod/konfig) klart · Spår B (produktions-
data) väntar på att `audit/2026-09/run_audit.sh` körs.

Granskningen bygger vidare på `CONTENT_PUSH_AUDIT_2026-06.md` (5 juni) och använder samma
princip: deterministiskt först, LLM-omdömen bara på urval, och **bara interna motsägelser räknas
som "osant"** (juniauditens lärdom om stale spelartrupper). Allt är read-only mot prod.

---

## 0. Sammanfattning (TL;DR)

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
4. **En oguardad, API-fakturerad innehållsväg kan vara igång på PL-matchdagar.**
   `matchday-scheduler` triggar `content-generator` direkt vid kickoff−90, och
   `content-generator` saknar egen `CONTENT_GENERATOR_ENABLED`-gate. Antingen kör den (kostnad +
   dubbla/off-voice matchday-items) eller är cronen död sedan nyckelrotationen. Avgörs av
   B1. (A9, P0-verifiera)
5. **Farlig commit på en gammal branch (3 aug, `b7df6ae`)** duplicerar mig 074 med fel API-id
   för Coventry/Hull och en `UPDATE teams SET league_id=39` som skulle flytta alla 48
   VM-länder till PL. Får aldrig mergas; DB-läget verifieras i B1. (A6, P0)
6. **Prod ≠ git.** Båda repon slutar 10 juli; en archive-cron och `status='archived'` finns i
   prod men inte i migrationerna; `main` är död sedan april och trunken är en `claude/*`-
   branch. Facit för granskningen är prod-läget, inte koden. (A12/A13, P0-process)
7. **Nattpushar är policy, inte bugg:** `gd-news` fyrar 00:30 UTC (01:30–02:30 svensk tid) och
   servern har inga quiet hours sedan 17 maj (flyttat till iOS DND). Juniauditen kallade
   nattpusharna "lösta"; schemat kvarstår. Mät i B2 och besluta. (A4, P1/policy)
8. **Blandade tidszoner i kopian:** morning-push skriver BST/GMT, matchday-reminder Stockholm,
   iOS enhetslokalt. (A5, P1)
9. **Retention äter loggen:** `pipeline_health` gallras efter 90 d → VM-gruppspelets
   leveranslogg börjar försvinna ≈ 13 sep. **Kör snapshoten nu.** (A11)
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
| **P0** | A9 | Verifiera `matchday-scheduler`-cronen i `cron.job` (B1) och `pipeline_health stage='generate'` sedan 1 aug. Om levande: stäng av (den fakturerar API och kringgår routines-guards). Om död: ta bort cronen så den inte vaknar av misstag. | prod/app |
| **P0** | A6 | Merga/kör **aldrig** `b7df6ae`/branchen `claude/create-markdown-file-hIdbj`. Verifiera i `03_teams.csv` att `league_id=1` fortfarande gäller för 48 länder och att Coventry/Hull har api-id 1346/64. | process |
| **P0** | A12 | Dokumentera prod-driften: dumpa `cron.job` (B1) och lägg archive-cronen + `status`-CHECK som migration, så koden speglar prod. | app |
| **P0** | A11 | Kör retention-snapshoten **nu**. | Anton |
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

### A13 · Branch-hygien — **P1**
- `origin/main` senast 26 apr; trunk = `origin/claude/intelligent-thompson` (10 jul); båda repon
  orörda sedan 10 jul trots drift i augusti/september; min tilldelade branch var baserad på
  den gamla linjen och raderad på origin. Arbetsbranchen är nu omsatt på trunken.

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
| Vilka crons finns egentligen? Archive-cron? matchday-scheduler? | `01`, `02`, `04*`, `05` | A9, A12 |
| Är teams-tabellen oskadd (A6)? | `03`, `03b` | 48 × `league_id=1`, Coventry 1346, Hull 64 |
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
