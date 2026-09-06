# Självrannsakan 2026-09 — Goal Digger: utskick & innehåll

**Datum:** 2026-09-06 · **Scope:** Premier League i dagsläget (huvudspår) + VM-slutspelet
28 jun–19 jul (lätt retrospektiv) · **Status:** Spår A (kod/konfig) klart · Spår B: snapshot tagen 2026-09-06 11:45 CEST
(`audit/2026-09/out/`), **B1–B7 klara** 2026-09-06. B4-bilaga: `audit/2026-09/B4_urval.md`.

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
0b. **NYTT (B2/B6): match-watcher har varit blind för PL hela säsongen.** API-Football listar 30
   PL-matcher 21 aug–6 sep (28 spelade). `match_status_state` innehåller **1** av dem (Arsenal–Coventry
   21 aug), och den raden uppdaterades aldrig efter NS. Alltså **0 live-pushar (mål/HT/FT), 0
   `gd-matchday`-fires, 0 deterministiska FT-artiklar, 1 morning-push** för PL i augusti.
   Cron-loggen visar att degraderingen började **9 aug** (19 startup-timeouts → 486/dag den 17 aug).
   Efter omstarten i dag ser match-watcher dagens två matcher (`fixtures_seen: 2`). (A17, P0)
0c. **NYTT (B3): `team_season_state` för alla 20 PL-klubbar är förra säsongens slutspurt.**
   Routinen `gd-season-state` skrev om raderna dagligen t.o.m. 24 aug med 2025-26-data: "Arsenal are
   top with 79 points from 36 games, two games left" — i slutet av augusti 2026. Coventry/Hull har
   tomma rader sedan 24 jun. Det är A1 i sin mest synliga form. (A18, P0)
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
7. **Nattpushar, uppmätt (B2):** **112 av 347 PL-pushar (32 %) landade 00:37–01:03 svensk tid**,
   14 av 29 nätter. Fyren är alltså ~00:30 *Stockholm* (22:30 UTC), inte 00:30 UTC som README säger.
   Övriga pushar: 08:37–09:22 (45 %) och 11:1x (söndagsbriefar, 23 %). Körningarna 12:30/18:30 UTC
   ger **noll** pushar. Servern har inga quiet hours sedan 17 maj. Beslut krävs. (A4, P1/policy)
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
11. **VM-timing, uppmätt över hela turneringen (B5-tillägg 6 sep):** **55 % av VM-pusharna
    (327 av 596) gick ut 22:00–06:59 svensk tid**, 202 av dem kl 00:xx — `gd-news-wc`:s
    "00:35 UTC" är i själva verket 00:35 Stockholm. Juniauditens "no night pushes" för VM var
    fel (den mätte före gruppspelet). Live-pushar för USA-nattmatcher (45 av 104 avsparkar
    00–04 svensk tid) landade 02–07 by design. (A25, P1/policy)
12. **Kickoff-pushen misslyckades för 8 av 10 Sverige-följare vid alla tre gruppspelsmatcher**
    (20, 26, 30 jun) med `429 TooManyProviderTokenUpdates` — *efter* mig 064. Mål/HT/FT-pushar
    minuter senare gick 10/10. Single-flight-fixen landade först 10 jul (`45e62a2`). (A26, P0
    historiskt, fixad)
13. **Inga matchdagspåminnelser alls i slutspelet.** `matchday-reminder` läser
    `team_season_state.next_fixtures`, som routinen skrev **en gång** för länder (24 jun 03:32)
    med enbart gruppspelsmatcher. 6 påminnelser totalt under VM, sista 27 jun. (A27, P0
    historiskt → gäller PL i dag via A2/A18)

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
| **P0** | A2 | Aktivera matchdags-påminnelse för PL-klubbar. **Patch skriven 6 sep (ej deployad):** `matchday-reminder` går på alla `is_active`-entiteter, token-matchar på `team_id/team_ids/country_id/country_ids`, Stockholm-tid i kopian; `morning-push` hoppar över fixtures som redan påmints (ingen dubbelpush). Build-up-feeditemet behålls för länder, inte klubbar. **Deployad 6 sep 13:16, dry-run OK.** | app |
| **P0** | A3 | **Pausa VM-läget** enligt checklistan i §4. **DB-spaken dragen 6 sep 12:3x:** mig 079 körd, 48 länder `is_active=false` (data-fetcher, content-audit, team-page-generator hoppar över dem). **Routines 6 sep 18:06:** gd-news-wc/gd-wc-preview/gd-wc-factcheck avstängda; övriga läser klubblistan ur `teams` (`c23b182`). **iOS 6 sep:** VM-steget borttaget ur onboarding, landsväljaren bakom `WCSeason.isVisible` (ej i build ännu). Kvar: `world_championship`-raden, server-styrd `WCSeason`. | båda |
| **P0** | A17 | **PL-live-kedjan blind sedan säsongsstart.** Felsökt 6 sep (§3 A17). **Härdning skriven, ej deployad:** mig 080 (match-watcher-cron med `timeout_milliseconds 30000` + stage `watch`), mig 081 (CHECK 6: live fixture med `last_checked` >5 min → `client_errors` `match_watcher_stalled`), patch `match-watcher/index.ts` (prior-fel ≠ första observation, `is_active`-filter på lag, aggregerad `watch`-rad per anomali/timme, `deno check`+lint+121 tester gröna). **080+081 körda 6 sep 12:5x** (verifierat: cron jobid 26 med 30 s timeout, första körning 12:55 OK; stage `watch` tillåten; CHECK 6 i prod, `%.0f` borta; inget falsklarm). **match-watcher v66 deployad av Anton 6 sep 12:54 CEST** (verifierat: svaret har `prior_errors`/`skipped_fixtures`, `active_leagues:[39]` — liga 1 pollas inte längre, första `watch`-rad 13:00). Kvällens A17-test körs alltså på patchad kod; ett fel i kväll pekar på miljön, inte på gamla kodvägar. | prod/app |
| **P0** | A18 | **`gd-season-state` skriver 2025-26-text på team-sidorna.** Samma rotorsak som A1 (`SEASON_STATE_PROMPT.md` + `fetch_*` med `season=2025`). Åtgärd ingår i A1; verifiera efteråt att `28d` ger `phase=mid_season` med 2026-27-summary och att Coventry/Hull får rader. | routines |
| **P0** | A14 | **Driftstopp 23 aug → 6 sep.** Omstart gjord 6 sep 11:38 CEST (match-watcher grön från 11:50). Kvar: hitta och ta bort IO-drivaren innan det händer igen — (a) `teams.is_active=false` för 48 länder (70 % av data-fetcher-jobbet, A3), (b) gallra `cron.job_run_details` (A16), (c) `VACUUM (FULL)`/repack av `raw_fetch_logs` (169 MB → ~20 MB) i ett servicefönster, (d) överväg Micro-compute om (a)–(c) inte räcker. Skriv in "DB Unhealthy"-runbook. | prod/Anton |
| **P0** | A15 | **Larmet kraschar.** CHECK 2 `FORMAT('%.0f')` → Postgres stöder bara `%s %I %L`. **Fix skriven: mig 081** (bygger på prod-definitionen, inte 041) — ROUND()::text + `%s`, plus nytt CHECK 6 (A17). **Körd i prod 6 sep 12:5x, `SELECT check_pipeline_heartbeat()` utan fel.** | app (mig 081) |
| **P1** | A16 | `cron.job_run_details` saknar gallring (177 k rader / 88 MB, 1 440 rader/dag från match-watcher). Lägg cron `DELETE … WHERE end_time < now() - interval '7 days'` (Supabase-rekommendation). | app (ny migration) |
| **P2** | A9 | **Död väg, bekräftat i B1.** Städa: ta bort `matchday-scheduler`-funktionen + lägg `CONTENT_GENERATOR_ENABLED`-gate i `content-generator` så den inte kan väckas av misstag. | app |
| **P0→process** | A6 | Merga/kör **aldrig** `b7df6ae`/branchen `claude/create-markdown-file-hIdbj`. **Verifierat oskadd i prod 6 sep** (`03_teams.csv`). Ta bort branchen på origin. | process |
| **P0** | A12 | Dokumentera prod-driften: `01_cron_jobs.csv` är facit. Skriv migrationer för archive-cronen (`UPDATE … 'archived' … published_at < now()-7d AND preview_fixture_id IS NULL`, 06:00 UTC), status-CHECK (`retrying`,`archived`), unschedule av `matchday-scheduler`/`data-fetcher`/`cleanup-*`. Bestäm om `schema_migrations` ska backfyllas 018–077 eller om `supabase db push` överges formellt. | app |
| ~~P0~~ ✔ | A11 | Retention-snapshot tagen 6 sep 11:45 CEST och committad (`a4c5650`). | — |
| **P1** | A4 | Besluta nattpush-policy. Mätt: 32 % av pusharna 00:37–01:03 Stockholm. Alternativ: flytta nattkörningen till 05:30 Stockholm (feed-only på natten), och/eller server-quiet-hours 22–07 Stockholm i `notification-sender` (live-pushar undantagna). Fixa README (schemat är Stockholm-tid, inte UTC). | routines/app |
| **P1** | A5 | En tidszon i all kopia. Mätt: 25 items med klockslag, 5 anger zon; alla UK-tid → svensk läsare 1 h fel. **Push-sidan löst 6 sep (skriven, ej deployad): mig 082** `device_tokens.timezone` + `register_device_token(p_timezone)`; iOS skickar `TimeZone.current.identifier`; `matchday-reminder` och `morning-push` renderar avspark per läsarens zon (en payload per zon). **Default/fallback = Europe/London** (Antons beslut 6 sep: appen marknadsförs och betalas i UK; de ~20 befintliga svenska enheterna får London-tid tills iOS-builden som skickar zon är ute). Fler marknader senare → per-enhet-zon i stället för fast zon. **Körd/deployad 6 sep 13:41 CEST:** mig 082 i prod (`timezone` = London för 20 befintliga tokens, RPC 6-arg med PUBLIC återkallat), matchday-reminder v10, morning-push v12. iOS 2.1.1 (build 9) arkiverad + IPA exporterad 6 sep 13:46 (`~/Desktop/GoalDigger-2.1.1-build9/`), Anton laddar upp och skickar in i kväll. **Routine-sidan kvarstår:** regel i PROMPT/SUNDAY_BRIEF att skriva tid med zon eller relativt ("tonight"). | app/routines |
| **P1** | A19 | **Röst-tokens som läcker:** `[him]` substitueras inte av iOS (8 items renderar "[him]"), "your partner"/"your guy" (12 items), "If [his name] follows X" (15 items). Lägg hard-reject i `post_news.sh` för `\[him\]`, `your (partner|guy|man)`, `if \[his name\] (follows|supports)`. | routines |
| **P1** | A20 | **Sunday-brief-korten:** 19/80 saknar `immersive_headline`+`immersive_context`, 41/80 har versaler. Kör sunday_brief genom samma validering som news (lowercase, ≤22/rad, fält obligatoriska eller fallback). | routines |
| **P1** | A21 | **8 dubbelpushar <3 min till samma lag** (`11`): routinen postar två items för samma lag i följd och båda pushar direkt (latens 0,0 min → 5-min-throttlen i `notification-sender` gäller inte direkt-post-vägen). Lägg throttlen i `post_news.sh` eller i den specifika-item-vägen. | app/routines |
| ~~P1~~ ✔ | A7 | **Ej aktuell:** `30` visar 0 PL-`consequence_type`-rader (bara 144 `WC_RIVAL_RESULT`, jun). Inget blockerar 2026-27. | — |
| **P1** | A13 | Branch-hygien: gör trunken till `main` (eller döp om), pusha lokala commits, re-basa arbetsbranches. | process |
| **P2** | A8 | Bekräfta tier-gates mot produktavsikt (sunday_brief T2+, quiz T3+). Publik: 9 T2, 4 T3, 0 T1. | policy |
| **P2** | A22 | **Girl ref-kvalitet (B4):** 13/69 godkända, median 12/20; 87 % över 16 ord, 69 % "It's like"-öppning, jobb-zon dominerar; 1 privatlivsbrott (`c313273b`, spelarens barn, pushad). Skärp `post_news.sh`: ordräkning ≤16 → reject, `^(it'?s like|like|imagine)` → varning, `football equivalent` → reject; lägg familje-ord i content-safety-regexen. | routines |
| **P2** | A23 | `content-audit` ger falskt larm vid säsongsstart: "spurs finished 20/20 → RELEGATED" mot en 2026-27-tabell med 0 spelade (`19`). Kräv `played ≥ 1` innan rank-påståenden lintas. | app |
| **P2** | A24 | 49 items (45 pushade) i augusti till fem inaktiva klubbar med 0 följare (west_ham 18, wolves 12, southampton 8, leicester 6, burnley 5) — routinekvot i onödan. Följer av A1. | routines |
| **P2** | A10 | VM-retro-lärdomar → nästa turnering (previews i tid, ingen manuell bulk-postning). | docs |
| **P1** | A25 | **VM-nattpushar 55 %.** Samma beslut som A4 men större: routine-schemat är Stockholm-tid, inte UTC; live-pushar för nattmatcher kräver ett medvetet val (opt-in "väck mig" eller quiet hours med undantag bara för mål/FT). | routines/app/policy |
| ✔ hist. | A26 | Kickoff-push 429 efter mig 064 (3 Sverige-matcher, 23/40 misslyckade). Fixad 10 jul (`45e62a2` single-flight + retry). Lärdom: verifiera fixar mot `apns_send`-raderna nästa match, inte mot koden. | — |
| **P0** | A27 | **Påminnelser bygger på routine-skriven `next_fixtures`** → 0 i slutspelet. **Fix skriven 6 sep (ej deployad):** `matchday-reminder` hämtar fixtures från API-Football per aktiv liga (1 anrop/liga/dag, `from`/`to` = 24 h) med `match_status_state` som fallback; `next_fixtures` läses inte alls. **Deployad 6 sep 13:16 CEST (v9, morning-push v11).** Dry-run 13:2x: 4 kandidater från `api_football`, svensk tid i kopian ("Arsenal face Chelsea today at 17:30"), Arsenal `would_push: true`, övriga tre ej följda. Första skarpa körning: nästa PL-matchdag 09:00. | app |
| **P0** | A28 | **Routines delar 5-timmarskvot med interaktiva Claude Code-sessioner.** 6 sep föll både HT-brief och FT-artikel för Everton–Man Utd på "session limit" trots att match-watcher fungerade; fire loggas som `success`, ingen retry. Beslut: egen kvot för routines och/eller fire-utan-artikel = fail (§3 A28). | routines/app |
| **P0** | A29 | **Alla livepushar och Live Activity var hårdkodade till VM-ligan.** `match-watcher` skickade avspark-, mål-, HT- och FT-push samt Live Activity bara när `league_id = 1`; en PL-följare fick ingenting mellan morgonpåminnelsen och FT-artikeln. **Åtgärdat 6 sep 18:45 (v67 + mig 083):** gaten borttagen, klubbar hämtar namn ur `teams.short_name`, `device_tokens.team_ids` matchas, `live_activity_tokens.team_ids` tillagd. Live Activity för klubbar kräver ny app-build (§3 A29). | app/server |
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
- **B3-bevis (6 sep):** `18`: Coventry 0 / Hull 0 items; `35` `empty_feeds` = coventry, hull.
  `28a`/`28b`: sunday_brief och quiz går varje vecka till exakt 2025-26-listan (inkl. burnley,
  west_ham, wolves; utan ipswich, coventry, hull). `28d`: se A18. `20`: de 84 "last season"-träffarna
  är legitima förssäsongsreferenser — förra säsongens tabell citeras **inte** som nuvarande i
  aug-texterna (routinen har haft få tabellpåståenden att göra före omgång 1).

### A2 · Ingen matchdags-påminnelse för PL — **P0**
- **Bevis:** `matchday-reminder/index.ts:48-52` (`.eq("entity_type","country")` med kommentar
  "PL clubs are off-season during the WC; their reminders … can be added when the league
  resumes"); `migrations/063_matchday_reminder.sql:1-12`. `AUDIT_FINDINGS.md` PUSH-8/SCHED-1
  bekräftar att PL medvetet uteslöts i juni.
- **Symptom:** PL-följare får ingen "han spelar i dag" 09:00; bara `morning-push` 08:00 UTC
  (`morning-push/index.ts:83-90`, 18 h-fönster) — som dessutom skriver London-tid (A5).
- **Åtgärd:** öppna för klubbar; källa `team_season_state.next_fixtures` finns redan för PL.
- **B2-bevis (6 sep):** `16`: 0 rader i `matchday_reminders_sent` sedan 1 aug (senaste 27 jun, VM).
  `morning-push` loggade **1** sändning i augusti (21 aug "arsenal v coventry: 10 sent") — den läser
  `match_status_state`, som var tom för PL (A17), så även "Game day"-pushen var i praktiken död.
  Leeds 22 aug och Liverpool 23 aug fick inget. OBS: `team_season_state.next_fixtures` är
  routine-skrivet och stod på 2025-26 (A18) — använd `match_status_state`/API direkt.

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
- **B2-mätning (6 sep):** `09`: pushar per timme Stockholm 00: 96 · 01: 16 · 08: 139 · 09: 16 ·
  11: 80 (inga andra timmar). `10`: 112 nattpushar (108 news, 4 matchday), 14 nätter, topp
  00:37–01:03. `06b` routine_post-timmar: post_news 00/01/08/09/11, post_insider 04, post_season_state
  03, post_quiz 13, post_player_dossier 19 — **README:s UTC-schema stämmer inte**; nattkörningen
  fyrar ~00:30 svensk tid och 12:30/18:30-körningarna ger inga pushar alls.

### A5 · Blandade tidszoner i kopian — **P1**
- **Bevis:** `morning-push/index.ts:48-75` (`Europe/London`, suffix BST/GMT, motivering "most
  users are UK/EU"); `_shared/matchday-reminder-copy.ts:9-22` (`Europe/Stockholm`);
  `content-generator/index.ts:715` (`toLocaleDateString` utan `timeZone` → UTC-veckodag);
  iOS `ImmersiveCard`/`MatchDayCard` enhetslokalt. Publiken är svensk
  (`063_matchday_reminder.sql:6-7`).
- **Åtgärd:** en TZ-konstant (Stockholm) för all serverkopia.
- **B4-bevis (6 sep):** 25 items med klockslag i push/headline, 5 nämner zon; alla är UK-tid
  ("Newcastle away next Sunday 4:30", API: 17:30 svensk). `c0dfff54` säger 1pm, `4f4903fe` 2pm för
  samma avspark (API: 14:00 UK). Se `B4_urval.md` §2.

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
- **B5-utfall (6 sep): slutspelet levererade.** 34 knockout-matcher (25 FT, 5 AET, 4 PEN):
  **34/34 HT_PUSH, 34/34 FT_PUSH, 31/34 PREKICK_PUSH**. FT-latens från avspark: median 122 min (FT),
  167 (AET), 174 (PEN) — konsistent med 90+15+stopp resp. förlängning/straffar; ingen missad FT.
  `32`: 388 VM-items i fönstret (311 news, 48 sunday_brief, 29 matchday), 274 pushade, 37
  `edge_function` (FT-artiklar). `33`: 28 jun-bursten = 48 briefar 11:27–11:30 svensk tid, alla
  pushade inom 4 minuter. `34`: leveransloggen fanns kvar och är nu snapshotad.
- **Hela turneringen (`44*`, 6 sep):** 1 056 VM-items 11 jun–20 jul (843 news, 165 matchday, 48
  sunday_brief), 596 pushade. Gruppspel: 70 matcher, HT 70/70, FT_PUSH 70/70, PREKICK 55/70
  (funktionen landade 12–17 jun). FT-fire-latens median 121 min. Inga färdigspelade matcher utan
  `fired_finished_at`. Se A25–A27 för det som inte fungerade.

### A25 · VM-nattpushar — **P1 / policy (nytt, B5-tillägg)**
- **Bevis:** `44`: pushar per timme Stockholm: 00→202, 23→24, 01→21, 02→20, 05→18, 06→16, 03→14,
  04→12 (= 327 nattpushar, 55 % av 596); dagtid 08→159, 09→27, 11→48. Routine-news skapas kl 00
  (264) och 08 (253) — två körningar/dygn, inte fyra, och nattkörningen är 00:3x *Stockholm*.
  `44b`: live-pushar (mål/HT/FT/kickoff) per timme: 00→47, 22→11, 03→9, 23→8, 02→5, 04→6 …
  `07`: 45 av 104 VM-matcher startade 00–04 svensk tid. Sverige-exempel (8 följare): Japan–Sverige
  26 jun 01:00: kickoff-push 00:30, HT 01:51, mål 02:17 och 02:23, FT 02:59, FT-artikel 03:15.
- **Juniauditen** (`CONTENT_PUSH_AUDIT_2026-06.md:44,50`) kallade 00:38–00:54-klustret "resolved"
  och VM "no night pushes" — den mätte 5 jun, före gruppspelet.
- **Åtgärd:** A4-beslutet, plus en explicit produktregel för live-pushar nattetid.

### A26 · Kickoff-push 429 efter JWT-cache-fixen — **historiskt, fixat 10 jul**
- **Bevis:** `06b` `apns_send` `wc_kickoff:sweden`: 20 jun 18:30 "2 sent, 8 failed of 10", 26 jun
  00:30 "2/8", 30 jun 22:30 "3/7", alla `429 TooManyProviderTokenUpdates`; mål/HT/FT samma matcher
  10/10. Länder med 1–2 följare påverkades inte (inget burst). FT-artikel-pushar 21 jun 08:15 och
  26 jun 03:15: "3 sent, 7 failed (429:7)"; 10 jul 13:25 `world_championship` "3/12 (429:12)".
  Mig 064 (15 jun, `c3d869a`) cachade token i DB men lät N parallella sändningar minta var sin
  när cachen var kall; single-flight + retry kom 10 jul (`45e62a2`), deploy 10 jul.
- **Lärdom:** verifiera en push-fix mot nästa matchs `apns_send`-rader (`44b`-frågan), inte mot
  koden.

### A27 · Påminnelser: `next_fixtures` skrevs en gång för länder — **P0 (nytt, B5-tillägg)**
- **Bevis:** `44c`: 6 rader totalt (south_africa ×2, sweden ×2, england ×2), 18–27 jun, alla
  09:00 svensk tid. Prod `team_season_state` för sweden/england/france/south_africa:
  `generated_at` 2026-06-24 03:32–03:33, `next_fixtures` = enbart de tre gruppspelsmatcherna.
  `06b`: `post_season_state:<land>` exakt 1 rad per land (24 jun); PL-klubbar 20/dag.
  `matchday-reminder/index.ts:11-14,84-101` läser bara `next_fixtures` inom 24 h → R32–final
  (28 jun–19 jul) gav 0 påminnelser, inkl. Frankrike–Sverige 30 jun.
- **Koppling:** samma mekanism gäller PL i dag: reminder är avstängd för klubbar (A2) och
  `next_fixtures` för klubbar skrivs av en routine på 2025-26-data (A18). Deterministisk källa
  finns redan: `raw_fetch_logs` `api_football_fixtures_next` var 2:e timme, eller API direkt.

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

### A17 · match-watcher blind för PL 21 aug → 6 sep — **P0 (nytt, B2/B6)**
- **Bevis:** `43_api_football_pl_fixtures_aug.json` (B6, Pro-plan, 537/7 500 anrop förbrukade):
  30 PL-fixtures 21 aug–6 sep, 28 med status FT. `07`/`15`: `match_status_state` har **en** PL-rad
  sedan 1 aug — 1557367 Arsenal–Coventry 21 aug 21:00 CEST, status ABD (reapern), `home_goals` NULL,
  `briefs_fired []`, `last_checked` = reaperns 05:00 UTC. Övriga 27 spelade matcher saknas helt.
  `06b`: 0 `matchday_fire`/`live_brief_fire`/live-`apns_send` för PL i aug. `42`: match-watcher
  pg_cron-fel 0/dag t.o.m. 8 aug → 19 (9 aug) → 124 (10 aug) → 380 (13 aug) → 486 (17 aug) → ~500–600
  (18–30 aug), typ `job startup timeout` + `statement timeout`. pg_cron:s "succeeded" betyder bara
  att `net.http_post` köades; inga `timeout_milliseconds` sätts i något av de 11 cron-kommandona
  (`01`), så pg_net-defaulten gäller. `net._http_response` (6 h retention) visar efter omstarten
  `{"fixtures_seen":2,"state_updates":2,"active_leagues":[39,1]}` varje minut → koden fungerar när
  DB:n svarar.
- **Konsekvens:** PL-följare (12 enheter, Arsenal 8) fick i augusti inga mål-/HT-/FT-pushar, ingen
  deterministisk FT-artikel och en (1) morning-push. De 10 `type=matchday`-items som finns är
  routine-skrivna referat av cup-/försäsongsmatcher (se `B4_urval.md` §3).
- **Orsak (sannolik):** A14 — under IO-svälten tog match-watcher-anropen längre än pg_net-timeouten
  eller misslyckades i Edge, utan spår i `pipeline_health` (funktionen loggar inte egna körningar).
  Första sikt av 1557367 skedde nattetid (låg last), uppdateringarna dagtid föll bort.
- **Felsökning 6 sep 12:50 (B6 + kodläsning):**
  1. **API:et är friskt för exakt match-watchers fråga.** `fixtures?league=39&season=2026&date=D`
     ger i dag 1 (21 aug), 5 (22 aug), 3 (23 aug), 2 (6 sep) fixtures — samma URL-form som
     `index.ts:551`. Datan fanns; funktionen skrev den inte.
  2. **pg_net-timeouten är 5 000 ms** (`net.http_post(... timeout_milliseconds DEFAULT 5000)`,
     pg_net 0.20.0) och inget cron-kommando sätter något annat. PostgREST-rollen `authenticator`
     har `statement_timeout=8s`. match-watcher gör 4–6 sekventiella PostgREST-anrop per körning
     (teams, hangover, prior per fixture, upsert per fixture) + 1–2 API-Football-anrop. Under
     IO-svälten (pg_cron själv fick `statement timeout` på Vault-läsningen) räckte **ett** långsamt
     anrop för att spräcka 5 s. I dag svarar funktionen inom samma sekund som cronen fyrar.
  3. **Två kodställen gör fel tyst:** (a) `index.ts:603` ignorerar `error` från prior-uppslaget —
     ett DB-fel blir `prior = null` = "första observation", som per design **aldrig fyrar**
     (ingen FT-push, inget `gd-matchday`) även om upserten lyckas. (b) `index.ts:505-512`: fel på
     `teams`-frågan → 500 och körningen avbryts utan spår; funktionen skriver ingen
     `pipeline_health`-rad för sin egen körning (bara `apns_send`/`matchday_fire`/
     `live_brief_fire`/`consequence_fire` vid händelser), så 27 dagars tystnad var osynlig.
  4. **Inget heartbeat-CHECK bevakar själva pollningen** (mig 039/041 tittar på briefs/matchday
     *efter* FT); CHECK 2 (non-200 i pg_net) var det enda som kunde ha larmat — och det kraschade
     (A15).
  5. Edge-loggarna för augusti är borta (free-tier retention 1 dag), så exakt felrad kan inte
     bevisas. Sannolikhetsbedömning: DB-latens → pg_net-timeout/PostgREST-timeout → (b) eller
     tyst fel i loopen. Koden i sig är oförändrad sedan 10 jul och fungerar nu.
- **Åtgärd (ett steg före i kväll):** (1) läsvakt igång på 1557390/1557387 — förväntat: `status`
  1H→HT→2H→FT, `briefs_fired` får `HT`/`FT_PUSH`, `matchday_fire`-rader för arsenal/chelsea, FT-push
  till 8 Arsenal-följare ~19:25–19:35 svensk tid; (2) ny migration: `timeout_milliseconds => 30000`
  i match-watcher-cronen; (3) `index.ts:603` behandla `error` som fel (hoppa över fixturen, logga),
  inte som `null`; (4) match-watcher skriver en aggregerad `pipeline_health`-rad per körning
  (stage `watch`: fixtures_seen/state_updates/upsert_errors) så tystnad syns; (5) heartbeat-CHECK 6:
  "rad i `match_status_state` med `kickoff_time` i dag och `status` icke-terminal men `last_checked`
  äldre än 5 min mellan kickoff−15 och kickoff+150" → `client_errors`.

- **Verifiering 6 sep kväll (Everton–Man Utd 15:00, Arsenal–Chelsea 17:30 CEST):** match-watcher v66
  följde 1557390 live: 1H → 2H, `briefs_fired ["HT"]`, FT 2–2 kl 17:0x, `watch`-rad varje hel timme,
  `live_brief_fire` 15:50 (everton, man_utd) och `matchday_fire` 17:01 (båda) med status `success`.
  **Kedjan bröts i nästa led:** både `gd-live-brief` (13:50 UTC) och `gd-matchday` (15:01 UTC)
  avbröts efter 0 s med *"You've hit your session limit · resets 3:30pm (UTC)"*. Se A28. Ingen följer
  Everton/Man Utd (0 följare) så ingen kund drabbades; Arsenal (9 följare) avgörs efter kvotåterställningen.

### A18 · `team_season_state` = förra säsongens slutspurt — **P0 (nytt, B3)**
- **Bevis:** `28d`: 20 klubbar `phase=mid_season`, genererade 21–24 aug 03:1x CEST av routinen
  (`post_season_state`), med summaries som "Arsenal are top of the Premier League with 79 points
  from 36 games", "Villa are in the run-in with two massive games left", "Wolves are deep in the
  relegation fight with just two games left". Coventry/Hull `pre_season` med tom summary sedan
  24 jun; Leicester `run_in` sedan 15 maj; ipswich `pre_season` "back in the Championship".
  `next_fixture` var dock rätt (22–23 aug-matcher) — routinen blandar 2026-fixtures med
  2025-tabell.
- **Rotorsak:** A1 (`SEASON_STATE_PROMPT.md`/fetch med `season=2025`, laglista 2025-26).
- **Symptom:** team-sidans säsongsstrip och feed-kontext visar en säsong som är slut; alla
  `[his name]`-samtalsöppnare bygger på fel tabell.

### A19 · Röst-tokens som läcker till kortet — **P1 (nytt, B4)**
- **Bevis:** `08`: `[him]` i 8 items (iOS substituerar bara `[his name]`, `AppState.swift:196` →
  renderas bokstavligt), "your partner"/"your guy" i 12 items (`7625ae96`, `31441491` …), "If [his
  name] follows X" i 15 items. `post_news.sh` har regex för fan-slang/ALL-CAPS/em-dash men inte för
  dessa.

### A20 · Sunday-brief-korten saknar text / bryter lowercase — **P1 (nytt, B3/B4)**
- **Bevis:** `08` filtrerat `type=sunday_brief` (80): 19 med `immersive_headline` **och**
  `immersive_context` NULL (t.ex. `c0dfff54` 23 aug man_city), 41 med versaler
  ("PSG drawn 1-1. / Hull City opener"). News/matchday: 0/353 — gaten i `post_news.sh` fungerar,
  men briefarna postas via en väg som inte validerar.

### A21 · Dubbelpushar till samma lag inom 3 minuter — **P1 (nytt, B2)**
- **Bevis:** `11`: 8 par (man_city ×3, arsenal ×2, nottm_forest, aston_villa, chelsea), gap
  0,2–2,8 min, alla pushade. `08`: push-latens median 0,0 min → `post_news.sh` triggar
  `notification-sender` för det specifika itemet direkt; 5-min-throttlen ligger bara i sweepen.

### A22 · Girl ref-kvalitet — **P2 (nytt, B4)**
- Se `audit/2026-09/B4_urval.md`: 13/69 godkända (≥16/20), median 12; 304/350 över 16 ord (`26`);
  283/411 "It's like"-öppning; 3 "football equivalent"; jobb-zon ~40 % av urvalet. 1 privatlivsbrott
  (`c313273b`, Maddisons tvillingar, pushad 22 aug). Interna motsägelser: `60fe15e2` "Arne Slot's
  squad" 8 aug (Slot avgick i maj), "första hemmamatchen" två gånger (`966bbd0f`/`ada2cbfb`),
  Savio/Savinho.

### A23 · `content-audit` falskt larm vid säsongsstart — **P2 (nytt, B3)**
- **Bevis:** `19`: 2 träffar, båda `1ec9c18b` (spurs): "Claims survival but spurs finished 20/20 →
  RELEGATED". Tabellen 1–2 aug är 2026-27 med 0 spelade; rank 20 är alfabetisk/utgångsläge.

### A24 · Items till inaktiva klubbar — **P2 (nytt, B3)**
- **Bevis:** `18`: west_ham 18, wolves 12, southampton 8, leicester 6, burnley 5 items (45 pushade)
  sedan 1 aug; `36`: 0 följare. Sunday_brief/quiz till burnley/west_ham/wolves varje vecka (`28a`,
  `28b`). Följer av A1:s laglista.

---

### A28 · Routines delar claude.ai-kvot med interaktiva sessioner; "fire OK" ≠ artikel — **P0 (nytt, kvällens verifiering)**
- **Bevis:** RemoteTrigger-loggar `cse_01N2Cvwk3FPTbiY3VYHUynfZ` (gd-live-brief, HT) och
  `cse_01Qnv3pCFK8gk4egAUpk9FpV` (gd-matchday, FT): `rate_limit: rejected (five_hour)
  resets_at=1788708600` (15:30 UTC), `result: success is_error=true turns=1 duration=0s`. Samma
  dag kördes en lång Claude Code-session (denna granskning) på samma konto. `pipeline_health` visar
  ändå `matchday_fire success` eftersom match-watcher bara ser HTTP 200 från fire-endpointen;
  `matchday-retry.ts` backar bara vid *misslyckad* fire, så artikeln återskapas aldrig automatiskt.
  Heartbeat CHECK 4 (matchday-SLA) är enda skyddsnätet och larmar till Anton, inte till kunden.
- **Vad kunden ser:** matchdag utan FT-artikel och utan HT-brief trots att allt "lyckades" i loggen.
  Under VM (A10) höll kvoten eftersom ingen interaktiv session konkurrerade under matcherna.
- **Åtgärd (Antons beslut):** (a) separat konto/kvot för routines, eller en regel att inte köra
  tunga agentsessioner under PL-matchdagar; (b) i `match-watcher` betrakta en fire som misslyckad
  om ingen `matchday`-item finns 20 min senare, så `matchday-retry` tar över (S, `match-watcher/index.ts`);
  (c) deterministisk FT-fallbackpush för PL (finns redan för länder) så kunden får resultatet även när
  rutinen faller.

### A29 · Livepushar och Live Activity fanns bara för landslag — **P0 (åtgärdat 6 sep)**
- **Bevis:** `match-watcher/index.ts` (v66) omgav Live Activity-blocket och kickoff/mål/HT/FT-
  pusharna med `if (fixtureLeagueId === WC_LEAGUE_ID)`; namn och flagga hämtades ur `WC_COUNTRY_META`
  (48 länder) och mottagarfrågan matchade bara `country_id`/`country_ids`. `live_activity_tokens`
  hade enbart landskolumner. Arsenal–Chelsea 6 sep: Arsenals nio följare fick ingen push vid avspark
  (17:00 CEST), 1-0, 1-1 eller HT (18:24); HT-briefen skrevs till feeden utan push (by design i
  `post_live_brief.sh`). Det enda PL-följaren någonsin fått är morgonpåminnelsen och FT-artikeln.
- **Vad kunden ser:** App Store-löftet "match-day briefs at half-time and full-time" höll för Sverige
  i juni och för ingen PL-klubb i augusti–september.
- **Åtgärd (gjord):** match-watcher v67: gaten borttagen; `liveMeta()` ger länder flagga + namn ur
  `WC_COUNTRY_META` och klubbar `teams.short_name` utan flagga (`interpolate()` tar bort tomt
  `{flag}`); `sendPlayingTeamPush` matchar `team_id`/`team_ids` också; knockout-broadcast av Live
  Activity gäller bara liga 1 (annars hade "Regular Season - 3" startat aktiviteter på alla
  enheter). Mig 083: `live_activity_tokens.team_ids` + `register_la_token(..., p_team_ids)`. iOS:
  `LiveActivityManager` registrerar klubbar och kan starta aktiviteten i förgrunden för en klubb
  (namn utan flagga, tre bokstäver i Dynamic Island). `post_news.sh` (`965760a`): PL-`matchday`-
  artiklar blir feed-only eftersom FT-pushen nu går deterministiskt vid slutsignalen.
- **Kvar:** ny app-build för Live Activity på klubbar (befintliga 2.1.1(9) skickar inga `team_ids`;
  pusharna fungerar utan ny build). Sena avsparkar (20:00 UK) ger FT-push ~22:00 UK — medvetet
  undantag från quiet hours, Antons beslut om det ska gälla. `goal-push-copy.ts` säger fortfarande
  "he" (240 strängar) och når nu även PL-följare med relation ≠ partner.

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
| Nattpushar och timprofil | `09`, `10` | **Svar:** 433 items, 347 pushade (80 %), 86 feed-only. Timmar (Sthlm): 00→96, 01→16, 08→139, 09→16, 11→80. **112 nattpushar (32 %)**, 14 nätter, 00:37–01:03. Fyren är ~00:30 Stockholm, ej UTC (A4). |
| Dubbletter/burst per lag | `11`, `23`, `24` | **Svar:** 8 par <3 min, alla pushade (A21). 5 opener-repetitioner 72 h ("He might have opinions", "He'll be a bit gutted"). 34 rubrik-nära-dubbletter, 26 båda pushade (uppföljningar av samma story). |
| Aldrig skickat | `12`, `13`, `14` | **Svar:** 0 aldrig-pushade. Push-latens median 0,0 min (direktväg). APNs-fel: liverpool 4 aug ×2 "0 sent, 2 failed (other)", arsenal 28 aug 1×410. Leverans annars 100 %. |
| PL-matchday-kedjan | `15`, `07`, `43` | **Svar: kedjan har inte fyrat en gång.** 1/30 fixtures i `match_status_state`, aldrig förbi NS (A17). 0 `matchday_fire` sedan 11 jun. |
| Förmatch-pushar PL | `16` | **Svar:** 0 reminders (A2 bekräftat); **1** morning-push i aug (21 aug arsenal, 10 sent) — övriga dagar tom `match_status_state`. |
| Tysta dagar | `17`, `17b` | **Svar:** `cron_invoke`-stage används inte (0 rader). `routine_post` varje dag 1–29 aug (18–124/dag, 1–5 HTTP 400/dag), **tyst 30 aug → 6 sep** (A14). |
| Coventry/Hull, inaktiva lag | `18` | **Svar:** Coventry 0, Hull 0. Inaktiva: 49 items / 45 pushade till 0 följare (A24). |
| Tabellpåståenden | `19`, `20` | **Svar:** 2 content-audit-träffar, båda falskt larm (A23). 84 "last season"-träffar = legitima förssäsongsreferenser. Stale-säsongen syns i `28d` (A18), inte i news-texterna. |
| Formregler | `21`, `22`, `25`, `26` | **Svar:** längdtak 0, bannad register 0, TP-regler 0 (gaten fungerar). Analogi: 350/353 har girl ref, **304 över 16 ord** (median 23), 283/411 "It's like"-öppning (A22). |
| Kadens | `27`, `28a-d` | **Svar:** sunday_brief 20/söndag (2, 9, 16, 23 aug; **30 aug saknas**), quiz 20/lördag (1–29 aug) — båda på 2025-26-listan. Insider 16–25/dag, 4 dagar/vecka (inkl. 5 inaktiva + coventry/hull). Season-state: 20 `mid_season` men 2025-26-text (A18). |
| Delad feed, konsekvenser | `29`, `30` | **Svar:** 111/433 items (26 %) `everyone_talking`. `30`: 0 PL-konsekvensrader → A7 ej aktuell. |
| VM-slutspel | `31`–`34` | **Svar:** 34/34 HT+FT-push, 31/34 prekick, FT-latens median 122/167/174 min (FT/AET/PEN). 28 jun: 48 briefar på 4 min. Godkänt (A10). |
| VM hela turneringen: timing | `44`, `44b`, `44c`, `07` | **Svar:** 55 % nattpushar (A25); kickoff-push 429 för Sverige ×3 efter mig 064 (A26, fixat 10 jul); 6 påminnelser totalt, 0 i slutspelet (A27); gruppspel HT/FT 70/70, PREKICK 55/70. |
| Publik | `35`, `36` | **Svar:** 13 aktiva (T2 9, T3 4), 12 följer PL-lag (arsenal 8, liverpool 2, leeds 1), 11 följer land. Registreringar: 1 (16 aug). Churn: 1 (28 aug). |
| Oberoende facit (B6) | `43` | **Svar:** API-Football Pro (7 500/dag, 537 använda 6 sep). 30 PL-fixtures 21 aug–6 sep; avsparkstider i `07`/`28d` stämmer med API där rader finns. |

**B4 (kvalitativt urval):** 70 items (52 news × 6 lag × 4 veckor, 10 matchday, 8 sunday_brief),
poängsatta i `audit/2026-09/B4_urval.md`. Girl ref: 13/69 godkända, median 12/20. Gates: TRANSFER
och HEADLINE CLARITY hålls; 4 pushar utan team-impact; 1 privatlivsbrott; röst-tokens läcker (A19);
sunday-brief-kort tomma/versaler (A20); 3 interna motsägelser. Spot-check-lista för Anton i bilagan §3.

**Genomförda åtgärder 6 sep (Anton körde, agenten read-only):** `raw_fetch_logs` 169 MB → 4,5 MB
(retention-DELETE + `VACUUM FULL`), `cron.job_run_details` 88 MB → 4,6 MB (>14 d raderade + `VACUUM
FULL`), databas 308 MB → **61 MB**. Del 2 körd 12:3x CEST: gallrings-cron `cron_job_run_details_retention_sweep`
(jobid 25, 03:20 UTC, mig 078) skapad; `UPDATE 48` → alla länder `is_active=false` (mig 079).
Verifierat read-only: `country | f | 48`, match-watcher grön varje minut, dagens PL-matcher spårade. 12:4x: `world_championship` inaktiv (`tournament | f | 1`, mig 079 uppdaterad).

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
| 9 aug | Första pg_cron `job startup timeout` (19 st); 13 aug 380/dag; 17 aug 486/dag (A14) |
| 21 aug | PL 2026-27 startar (Arsenal–Coventry 21:00 CEST) — routines på 2025-26-konfig (A1), ingen PL-reminder (A2), match-watcher ser matchen men uppdaterar den aldrig (A17) |
| 22–29 aug | 19 PL-matcher utan en enda rad i `match_status_state`; routines postar men 30 aug-briefen uteblir |
| 29 aug 11:17 | Sista routine-post; 08:56 sista push |
| 30 aug 16:32 | Sista cron-körning — prod tyst (A14) |
| 6 sep 11:38 | Fast database reboot (Anton); 11:45 snapshot; 12:0x städning (308 → 61 MB); match-watcher ser dagens matcher |
| 6 sep 15:50–17:01 | match-watcher v66 följer Everton–Man Utd live (HT-fire, FT-fire) — båda rutinkörningarna avvisas av claude.ai-kvoten (A28) |
| 6 sep 17:00–18:24 | Arsenal–Chelsea: match-watcher följer matchen, HT-briefer skrivs för båda, men noll pushar till Arsenals nio följare — allt live var VM-gatat (A29) |
| 6 sep 18:45 | match-watcher v67 + mig 083: kickoff/mål/HT/FT-push och Live Activity för PL-klubbar (A29) |
| 6 sep | Denna granskning (Spår A + B) + kundgranskning (plan `parsed-chasing-ladybug`): onboarding utan VM-steg, routines på `teams`-tabellen och innevarande säsong, quiet hours, validatorer |
