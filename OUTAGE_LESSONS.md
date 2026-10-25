# Vad databasen har lärt oss

Fyra gånger har backenden tagit GoalDigger ner eller nära nog. Den här sidan
är inte en logg över dem — den finns i `IMPLEMENTATION_PROGRESS.md` och
`SJALVRANNSAKAN_2026-09.md`. Det här är vad som visade sig vara *samma sak*
varje gång, skrivet för att gå att använda i nästa app.

| | Vad | Hur länge | Vad det visade sig vara |
|---|---|---|---|
| 1 jun 2026 | Disk IO-budget-varning | ingen nedtid | Ett index som inte täckte frågan |
| 23 aug – 6 sep | Degradering → helt nere | **7 dygn** | Disk IO 100 %, ingen visste |
| 20–21 sep | Hela instansen trög | 17 h | Återhämtade sig själv, aldrig förklarat |
| 24 okt – | Helt nere | pågår | Omstart bet inte |

---

## 1. Larmet får inte bo i det som kan gå sönder

I sju dygn låg produktionen nere och ingen visste om det. Inte för att vi
saknade övervakning — vi hade `check_pipeline_heartbeat`, en cron var
30:e minut som larmade när pipelinen tystnade.

Den var en rad i databasen. Som var nere.

Varje larm vi hade — pg_cron:s egen heartbeat, `pipeline_health`,
`client_errors` — bodde inuti exakt den sak de skulle vakta. När den dog,
dog de med den, tyst.

Fixen blev `gd-heartbeat`: en check som kör på en **annan maskin på ett annat
nät**, var tredje timme, och ställer den enda fråga som betyder något — *skulle
en användare se något om hon öppnade appen nu?* Den skickar push direkt till
en telefon och rör aldrig databasen för att göra det.

Den 24 oktober larmade den inom tre timmar, och var tredje timme sedan dess.
Den fungerade.

> **Regel:** din övervakning får inte dela felkälla med det den övervakar. Om
> svaret på "hur vet jag att X lever?" går genom X har du ingen övervakning,
> du har en förhoppning.

Och undvik samma fälla i larmvägen: 17 maj-heartbeaten upptäckte problemet
korrekt men skickade sitt larm via samma Vault-nyckel som var trasig. Den såg
allt och kunde inte berätta det.

---

## 2. "Succeeded" mäter nästan alltid fel lager

pg_cron skriver `status='succeeded'` när SQL:en kördes utan fel. SQL:en är
`SELECT net.http_post(...)` — alltså "anropet lades i kön". Den säger
ingenting om att något svarade. I maj gick sex dygn med 401 på varje anrop
och en helt grön cron-logg.

Samma sak ett lager upp: claude.ai-routinerna stämplas `SUCCEEDED` när
sandboxen avslutas snyggt. Den 24–25 oktober är sex routiner stämplade
lyckade utan att ha skrivit en enda rad — de kunde inte nå databasen, de
konstaterade det, och avslutade prydligt.

Det är inte en bugg i pg_cron eller i routines. Båda rapporterar sanningsenligt
om det lager de faktiskt kan se. Problemet är att vi läste deras svar som ett
svar på vår fråga.

> **Regel:** definiera "lyckades" vid det lager användaren känner av, inte vid
> det som är lättast att mäta. För en cron som anropar en funktion är
> kriteriet `status_code = 200` i `net._http_response` — inte att cron körde.
> För en innehållsroutine är det en rad i `content_items` — inte att den
> avslutade.

---

## 3. Den uppenbara misstänkta är nästan alltid fel

Juni, Disk IO-budgeten höll på att ta slut. `raw_fetch_logs` hade 93 727 rader
och 340 MB stor JSONB, aldrig gallrad. Uppenbart, eller hur? Tabellen är för
stor, trimma den.

Fel. `pg_stat_user_tables` visade **32 seq scans mot 25 058 index scans** —
den lästes inte sönder. Det riktiga spåret låg i `idx_tup_fetch`: 1,39
miljoner, alltså ~55 heap-rader per indexsökning.

Frågan var `.eq(team_id).eq(source).order(fetched_at).limit(1)`. Indexet var
`(team_id, fetched_at)`. Postgres hittade laget, och gick sedan igenom ~55
rader och läste varje stor JSONB-rad från disk bara för att filtrera på
`source`. Det var den heap-läsningen, inte radantalet, som åt budgeten.

Fixen var ett index: `(team_id, source, fetched_at DESC)`. Gratis. Trimningen
gjordes också, men den var bisak.

Det här är svårt för att den felaktiga förklaringen är *tillfredsställande*.
Stor tabell, mycket disk — det låter rätt, och man slutar leta.

> **Regel:** "stor tabell" och "IO-problem" är två olika diagnoser. Läs
> statistiken innan du skär. Ett index måste täcka **hela** predikatet i rätt
> ordning — för `eq + eq + order by limit` ska sorteringskolumnen ligga sist.

**Fotnot, för ärlighetens skull:** den 25 oktober sa jag till Anton att
match-watchers 1 440 anrop per dygn tömde budgeten. Septemberrapporten skriver
själv "orsakshypotes, ej bevisad". Jag gjorde om precis det här misstaget,
mitt i dokumentet som varnar för det. Siffran var mätt; slutsatsen var det
inte. Det är lättare att se i efterhand än i stunden, vilket är hela poängen
med att skriva ner det.

---

## 4. Det som växer har ingen commit

De flesta buggar kommer med en deploy. Du kan `git bisect`, du kan läsa
diffen, du vet när det började.

Den 24 oktober dog databasen utan att någonting hade ändrats. Senaste
migrationen var tre veckor gammal. Inga commits på en vecka. Konfigurationen
var orörd.

Den klassen av fel kommer av sig själv: en tabell som växer lite varje dygn,
en logg ingen gallrar, en WAL-fil som aldrig kastas. Den korsar en tröskel en
natt klockan tre och då är den plötslig — men den har byggts upp i månader.

Två konkreta i det här systemet:

- `cron.job_run_details` växte till **177 070 rader och 88 MB**. pg_cron
  gallrar inte sin egen logg. Ingen hade sagt åt den att göra det.
- `net._http_response` är **UNLOGGED**, vilket betyder att den rapporterar
  noll rader till statistiken. Autovacuum utlöses av statistiken. Alltså
  besökte autovacuum den aldrig, och den växte till 17 MB med noll levande
  rader. Varje utgående anrop fick skanna skräpet: 5,2 sekunder styck, 29 645
  anrop, vilket åt upp den enda bakgrundsarbetare pg_net har — och därmed
  blockerade schemaläggaren, så 18 % av minutjobben aldrig startade.

> **Regel:** allt som växer behöver något som vaktar det, för `git blame`
> hittar det aldrig. Och den farligaste varianten är den som är osynlig för
> den automatik du litar på — en tabell som växer utan att radantalet växer är
> ett varningstecken.

---

## 5. Du betalar för det som är påslaget, inte för det du använder

GoalDigger har **noll** rader Realtime-kod. Inte i iOS, inte i någon Edge
Function. Appen pollar REST.

Den 25 oktober var Realtime **215 av 295 anrop** mot projektet, med 102 fel.

Supabase Realtime läser WAL via en replikeringsslot. Tjänsten är påslagen på
projektnivå, inte för att vår kod ber om den. Och en slot som ingen
konsumerar låser fast varje WAL-segment efter sitt bokmärke — Postgres får
aldrig återanvända dem, så WAL växer obegränsat.

Det är fortfarande en hypotes i skrivande stund. Men september mätte ett
glapp på 170 MB som den inte kunde förklara (dashboard 478 MB mot
`pg_database_size` 308 MB, *"antyder bloat/WAL"*) och ingen följde upp det.

> **Regel:** inventera vad som är påslaget, inte vad du anropar. En funktion
> du aldrig använder kan inte ha en bugg du märker — den kan bara ha en
> kostnad du inte letar efter.

---

## 6. Fixen kan vara det som dödar dig

Juni igen. Tabellen hade 340 MB att återvinna och `VACUUM FULL` hade gett
tillbaka dem. Frestande.

`VACUUM FULL` skriver om hela tabellen. På en instans vars **IO-budget**
redan höll på att ta slut hade den bränt precis den resurs vi försökte rädda —
och tagit ett lås på tabellen under tiden.

Larmet gällde IO, inte diskutrymme. Vanlig `VACUUM` markerar utrymme som
återanvändbart utan att skriva om något och utan lås. Det var rätt verktyg.

> **Regel:** matcha åtgärden mot larmet, inte mot symptomet den råkar dela
> namn med. "Disken är full" och "disken hinner inte med" kräver motsatta
> ingrepp.

---

## 7. Prod driver ifrån repot, tyst

`supabase_migrations.schema_migrations` innehåller bara 001–017. Allt därefter
— ett sjuttiotal migrationer — är kört för hand. Numren 112, 117 och 124 finns
två gånger. Fem cron-jobb som schemaläggs i migration 003 är borttagna utanför
git, och en kommentar i `team-page-generator` är det enda stället det står.

Följden är inte bara att `supabase db push` inte går att använda. Det är att
**repot inte längre beskriver systemet**. När någon — en människa eller en
agent — läser migrationerna för att förstå hur det hänger ihop, läser de en
version av verkligheten som inte finns.

Det är därför `facts.json` genereras från live `cron.job` i stället för att
skrivas för hand, och varför `verify-arch-map.sh` finns. Första gången den
kördes hittade den att kartan fortfarande hänvisade till ett skript som var
raderat.

> **Regel:** om du inte kan återskapa produktionsmiljön ur repot har du inte
> infrastructure-as-code, du har anteckningar. Och anteckningar ruttnar. Det
> du inte kan generera ur sanningen måste ha en check som jämför med den.

---

## Det korta

1. Larmet får inte bo i det som kan gå sönder.
2. "Succeeded" mäter nästan alltid fel lager.
3. Den uppenbara misstänkta är nästan alltid fel — mät först.
4. Det som växer har ingen commit.
5. Du betalar för det som är påslaget, inte för det du använder.
6. Fixen kan vara det som dödar dig.
7. Prod driver ifrån repot, tyst.

Och den som binder ihop dem: **varje gång har det tagit längre tid att tro på
mätningen än att göra den.** Juni hade svaret i `pg_stat_user_tables` hela
tiden. September hade 401:orna i `net._http_response` i sex dygn. Oktober hade
170 MB oförklarad WAL sedan september. Datan fanns. Någon hade bestämt sig
först.

---

*Relaterat: `DB_BASICS.md` (hur delarna hänger ihop, för en icke-DBA) ·
`RUNBOOK.md` (vad man gör när det brinner) · `scripts/db-health.sh` (kör den
först) · `artifacts/supabase-ticket-2026-09-21.md` (mall för supportärende).*
