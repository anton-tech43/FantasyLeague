# HANDOFF — Självrannsakan 2026-09, Spår B (körs på Antons Mac)

> **Till agenten som tar över:** du sitter på Antons Mac med åtkomst till `backend/.env`
> (`SUPABASE_DB_URL`) och `/opt/homebrew/opt/libpq/bin/psql`. Den föregående agenten satt i en
> molncontainer utan DB-åtkomst och gjorde Spår A (kod/konfig). Din uppgift är **Spår B**:
> köra query-paketet mot produktions-DB, analysera resultatet och fylla i rapporten.
> Läs den här filen helt innan du gör något. Allt du behöver finns i repot på den här branchen.

---

## 1. Läs först (10 min)

1. `SJALVRANNSAKAN_2026-09.md` — rapporten. §0 sammanfattning, §2 åtgärdslista, §3 Spår A-fynd
   (A1–A13), §4 "pausa VM"-checklista, **§5 = det du ska fylla i**, §6 tom (feedback), §7 tidslinje.
2. `audit/2026-09/queries.sql` — ~40 read-only SQL-block, ett per CSV. Kommentarerna förklarar
   vad varje fil svarar på.
3. `CLAUDE.md` (repo-roten) — särskilt **hårdregeln om betalda API-loopar** och DB-access-mönstret.
4. `ARCHITECTURE.md` — hur appen faktiskt fungerar (auktoritativ; `PRD.md`/`PROMPTS.md` är stale).
5. `CONTENT_PUSH_AUDIT_2026-06.md` — föregående audit (5 juni). Kopiera metoden, upprepa inte
   misstagen (se §4 nedan).

**Repon:** app-repot = det här (`anton-tech43/FantasyLeague`). Routines-repot =
`anton-tech43/goaldigger-routines`, lokalt troligen `/Users/anton/goaldigger-routines`
(verifiera). Den levande röst-specen är **routines `PROMPT.md`**, inte app-repots `PROMPTS.md`.

**Branch:** `claude/feature-planning-1q4m3p` — baserad på produktions-trunken
`origin/claude/intelligent-thompson` (senaste commit 2026-07-10). `origin/main` är död sedan
26 apr — använd den inte. **Branchen `claude/create-markdown-file-hIdbj` / commit `b7df6ae`
får aldrig mergas eller köras** (se A6 i rapporten: skulle flytta 48 VM-länder till PL).

---

## 2. Steg 1 — kör query-paketet (2 min, read-only)

```bash
cd <repo-rot>
git fetch origin && git checkout claude/feature-planning-1q4m3p && git pull
./audit/2026-09/run_audit.sh
ls -la audit/2026-09/out/
```

Förväntat: ~40 filer. Vissa kan vara tomma eller saknas om en tabell/vy inte finns i prod
(`ON_ERROR_STOP=0` — skriptet fortsätter). Notera vilka som saknas: det är i sig ett fynd
(schema-drift).

**Kontrollera direkt att dessa finns och har innehåll — de är retention-snapshoten:**
- `out/06b_pipeline_health_dump.csv` (gallras efter 90 d; VM-gruppspelets logg försvinner ≈ 13 sep)
- `out/07_match_status_state.csv`

Om `run_audit.sh` fallerar helt: `set -a && source backend/.env && set +a &&
/opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=0 -f
audit/2026-09/queries.sql` från `audit/2026-09/`.

**Commit:a snapshoten tidigt** (även innan analys): `git add audit/2026-09/out && git commit -m
"audit 2026-09: prod snapshot <datum>" && git push`. Filerna innehåller inga device tokens
eller per-användar-rader (verifiera med en snabb `grep -il token audit/2026-09/out/*` — ska
vara tomt bortsett från kolumnnamn som `token_expired`).

---

## 3. Steg 2 — analysera (Spår B), i denna ordning

Använd mappningen i rapportens §5. Arbeta **deterministiskt först**, sedan kvalitativt på urval.
Skriv resultaten in i rapporten (§5 → fyll tabellen; §0/§2 → uppdatera prio om data ändrar bilden).

### B1 · Driftfacit (gör först — allt annat tolkas mot det)
- `01_cron_jobs.csv`: lista alla crons. Svara på: finns `matchday-scheduler` och är den `active`?
  (→ A9). Finns `goaldigger-archive-old-content` och vad gör dess `command` — `UPDATE status`
  eller `DELETE`? (→ A12, avgör om historik försvunnit). Finns crons som inte motsvaras av någon
  migration? Lista dem.
- `02_cron_runs_14d.csv`: vilka crons kör faktiskt, vilka fallerar.
- `03_teams.csv`/`03b`: **A6-kontroll** — 48 rader `entity_type=country, league_id=1`? Coventry
  `api_football_id=1346`, Hull `64`? Om inte → A6 har körts mot prod → **P0, rapportera direkt**.
- `04*`: `content_items.status`-CHECK — tillåter prod `archived`? Vilka triggers finns
  (`suppress_wc_result_recap_push` m.fl.)?
- `05_migrations_applied.csv`: jämför med `backend/supabase/migrations/` — vad saknas åt vartdera hållet?

### B2 · Tidslinje PL (1 aug → nu)
- `08_pl_items.csv` är huvuddatasetet (alla kolumner inkl. body). Alla tider finns både UTC och
  Stockholm — **använd `_sthlm`-kolumnerna** när du resonerar om "när på dagen".
- `09`/`10`: timprofil + nattpushar 22–07 Stockholm. Hypotes A4: topp ≈ 02:30 (00:30 UTC-fire).
  Räkna antal nattpushar och andel av alla pushar.
- `11`: samma lag inom 5 min (throttlen ska ge 0; >0 = fynd). `23`/`24`: opener-repetition och
  rubrik-dubbletter inom 72 h.
- `12`: push-berättigat men aldrig pushat. `13`/`14`: leveransfel per dag; `17`/`17b`: tysta
  dagar (dagar utan `cron_invoke`/`routine_post` = avbrott).
- `15`: PL-matchday-kedjan — fyrar `gd-matchday` (`matchday_fire` success) och blir det items?
  Latens från kickoff. `16`: PL-reminders förväntas vara 0 (A2) — bekräfta; finns morning-push-rader?

### B3 · Innehåll PL, deterministiskt (hela populationen)
- `18`: Coventry/Hull förväntat 0 items (A1); inaktiva lag med items = slöseri.
- `19`: content-audit-träffar (tabellpåståenden som motsäger tabellen). `20`: "2025-26"/"last
  season"-glidningar i text. Läs varje träff — är det förra säsongens tabell som citeras?
- `21`/`22`/`25`/`26`: längdtak, bannad register, "Ask him" >1, analogi-andel. Träffar här är
  intressanta främst om `pipeline_source='routine'` (post_news.sh ska ha stoppat dem → gate-läcka)
  eller `edge_function` (→ A9-vägen lever).
- `27`/`28a–d`: kadens — sunday_brief varje söndag för varje aktivt lag? quiz varje lördag?
  insider varje dag? `team_season_state.phase` för PL ska vara `mid_season` efter 9 aug
  (`SEASON_STATE_PROMPT.md:181-187`); `pre_season`/`off_season` i september = fel.
- `29`/`30`: delad feed; konsekvensrader (A7 — finns 2025-26-rader som blockerar?).
- `08`: filtrera `pipeline_source='edge_function'` sedan 1 aug — **varje sådan rad bekräftar A9**
  (betald, oguardad väg lever).

### B4 · Innehåll PL, kvalitativt (urval)
- Dra ett **stratifierat urval** ur `08_pl_items.csv`: per typ (news/matchday/sunday_brief) ×
  vecka × 5–6 lag med flest följare (`36_pl_followers.csv`). Sikta på ~60–100 items.
- Bedöm mot måttstocken (rapportens §1 + routines `PROMPT.md`: GOLDEN RULE, TEAM IMPACT,
  TRANSFER-gate, HEADLINE CLARITY, TP1-regler, ANALOGY RULES/≤16 ord, bannad register).
- **Poängsätt "girl ref"** (`immersive_context`): naturlig / relevant / passar målgruppen /
  cringe-risk, 1–5 vardera (samma skala som `content-generator`s kritiker).
- Dubbelbedöm ~15 items i en andra pass; be Anton spot-checka ~10.

### B5 · VM-slutspel (lätt)
- `31`: per knockout-match — `prekick_pushed/ht_pushed/ft_pushed`, status AET/PEN, FT-latens
  (`fired_min_after_kickoff` ≈ 110–130 vid 90 min, ≈ 150+ vid förlängning/straffar). Matcher
  utan `FT_PUSH` = missad push. `32`: items per land/dag; `33`: 28 jun-bursten (minutkluster,
  hur många pushades); `34`: hur mycket leveranslogg som finns kvar.

### B6 · Oberoende facit
- Hämta avsparkstider från API-Football (`fixtures?league=39&season=2026`, `league=1&season=2026`)
  med `API_FOOTBALL_KEY` ur `backend/.env` — **läs-anrop, räkna kvoten** (gratis-tier 100/dag).
  Jämför mot `kickoff_time` i `07`/`15`/`31` innan du dömer FT-latens. Beakta API:ets ~30–60 s lag.

### B7 · Korsa mot Spår A
För varje empiriskt mönster: peka på rotorsaken (fil:rad i A1–A13) eller markera "ny rotorsak"
och lägg till som A14+ med bevis.

---

## 4. Hårda regler (bryt inte)

1. **Read-only mot prod.** Inga `UPDATE/DELETE/INSERT`, inga migrationer, ingen `supabase functions
   deploy`. Fynd → rapport → Anton beslutar. (Enda undantaget: ingen.)
2. **Inga betalda API-loopar** (CLAUDE.md-hårdregeln). Analys = SQL + in-session-läsning. Loopa
   aldrig `team-page-generator`/`content-generator` eller något som anropar `callClaude()`.
3. **Merga/kör aldrig `b7df6ae`** eller branchen `claude/create-markdown-file-hIdbj`.
4. **Tidszon:** DB lagrar UTC. Publiken är Europe/Stockholm (CEST hela fönstret). Använd
   `_sthlm`-kolumnerna. Skriv aldrig "kl 00:38" utan att säga vilken zon.
5. **LLM-faktakoll:** lita **inte** på din egen kunskap om vilken klubb en spelare tillhör, vem
   som är tränare, eller tabelläget — din träning är äldre än appens data (juniauditen "fixade"
   Semenyo→City felaktigt och fick backa). **Endast interna motsägelser** (två items som säger
   olika saker, eller item vs `content_audit`-lintern) räknas som "osant".
6. **Bugg ≠ policy.** Nattfire 00:30 UTC, inga server-quiet-hours, tier-gates = medvetna
   beslut; rapportera under "policyfrågor", inte som buggar.
7. **Allvarlighet:** P0 = fel/skadligt/aldrig skickat/dubbelt · P1 = fel tid/dag · P2 = röst/kvalitet.
8. **Ingen PII i repot:** commit:a aldrig device tokens, e-post, eller per-användar-rader.
   Query-paketet väljer inte ut sådant — håll det så om du lägger till queries.
9. **Scope:** PL nu = huvudspår. VM = lätt retro + "pausa" (Anton: "VM är slut så den ska vara
   pausad … inte relevant i dagsläget"). Bygg inget nytt för VM.
10. **Reproducerbarhet:** nya queries → `queries.sql`; varje flagga i rapporten bär `id`/`fixture_id`.

---

## 5. Vad "klart" betyder

- [ ] `audit/2026-09/out/` commit:ad (snapshot säkrad).
- [ ] B1 besvarat: A6 (teams oskadd?), A9 (matchday-scheduler levande/död?), A12 (archive-cron:
      flip eller delete? saknade migrationer?) — skrivet in i rapportens §3 under respektive A-punkt.
- [ ] Rapportens §5-tabell fylld med siffror + länk till CSV; §0 och §2 uppdaterade om prion ändras.
- [ ] B4-urval dokumenterat (vilka items, poäng, slutsats per segment) — som bilaga
      `audit/2026-09/B4_urval.md`.
- [ ] Nya rotorsaker som A14+ med fil:rad.
- [ ] Commit + push på `claude/feature-planning-1q4m3p`. **Ingen PR** om Anton inte ber om det.
- [ ] Kort sammanfattning till Anton: 5–8 punkter, vad som ändrats mot Spår A, och de 3 besluten
      han behöver ta (nattpush-policy, pausa-VM-lever, A9-åtgärd).

---

## 6. Kända fällor

- `run_audit.sh` antar `/opt/homebrew/opt/libpq/bin/psql`; faller tillbaka på `psql` i PATH.
- `cron.job_run_details` kan saknas (äldre pg_cron) → `02` tom, inget fel.
- `supabase_migrations.schema_migrations` kan sakna rader om migrationer körts manuellt via
  SQL Editor → `05` speglar då inte verkligheten; korsa med `01` och `04`.
- `08_pl_items.csv` innehåller `body` → stor fil; öppna med `csvkit`/pandas, inte Excel.
- JSONB-null-fällan: `WHERE x IS NULL` matchar inte JSONB-literal `null`
  (`jsonb_typeof(x)='null'`) — relevant om du skriver egna queries på `talking_points`.
- Routines run-loggar syns inte från CLI; om `17b_routine_posts_daily.csv` visar tysta dagar,
  fråga Anton att titta i claude.ai/code/routines-historiken för den dagen.
