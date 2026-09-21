# Databasen, förklarad för den som äger den

Skriven 2026-09-21, dagen då Supabase-panelen sa "database unhealthy" i en
timme medan databasen svarade på varenda fråga vi ställde. Poängen med det
här dokumentet är att du ska kunna avgöra sådant själv.

Allt nedan handlar om GoalDiggers faktiska uppsättning. Inga generella
exempel.

---

## 1. Det finns inte en sak som heter "databasen"

Det är fyra lager, och de går sönder var för sig. Det här är den enskilt
viktigaste bilden i dokumentet:

```
  iPhone-appen
      │  HTTPS, med appens publishable key
      ▼
  PostgREST          ← gör HTTP-anrop till SQL. "REST-lagret".
      │
      ▼
  Postgres           ← själva databasen. Där datan faktiskt ligger.
      ▲
      │
  Supavisor          ← "poolern". En andra dörr in till Postgres,
                       den jag använder från terminalen.
```

Vid sidan om står **Edge Functions** (vår egen kod som körs hos Supabase,
till exempel `match-watcher`) och **pg_cron** (schemaläggaren som bor inuti
Postgres).

Appen pratar **bara** med PostgREST. Den vet ingenting om Postgres.

Det betyder att PostgREST kan ligga nere medan Postgres mår utmärkt, och då
är appen helt död trots att ingen enda rad data är i fara. Det var precis
vad som hände idag. Panelen sa "unhealthy" för att dess hälsokoll går samma
väg som PostgREST, inte för att databasen hade något fel.

**Testet som skiljer dem åt** är hela poängen med `./scripts/db-health.sh`:
avsnitt 1 mäter PostgREST, avsnitt 2 mäter Postgres via poolern. Två olika
vägar in. Om den ena svarar och den andra inte gör det vet du på tio sekunder
vilket lager som är sjukt.

---

## 2. Vad Postgres faktiskt är

En **tabell** är ett kalkylark. `teams` är ett ark där varje **rad** är ett
lag och varje **kolumn** är en egenskap.

```
 id       | display_name | manager_name | entity_type
----------+--------------+--------------+------------
 arsenal  | Arsenal      | Mikel Arteta | club
 sweden   | Sweden       | ...          | country
```

GoalDiggers viktigaste tabeller:

| Tabell | Vad den håller |
|---|---|
| `teams` | 20 aktiva PL-klubbar. Här ligger även 48 VM-länder och 34 gamla klubbar, avstängda med `is_active = false` — raderna finns kvar, de visas bara inte. |
| `players` | spelartrupperna, ~30 rader per klubb |
| `team_pages` | lagsidans färdiga innehåll, ett JSON-block per lag |
| `content_items` | flödet, ett inlägg per rad |
| `pipeline_health` | logg över varje steg vår backend kör |
| `raw_fetch_logs` | råsvaren från API-Football innan vi tolkat dem |

**SQL** är språket man frågar med. Du behöver egentligen bara känna igen tre ord:

```sql
SELECT manager_name FROM teams WHERE id = 'arsenal';
```

`SELECT` = vilka kolumner jag vill se. `FROM` = ur vilken tabell. `WHERE` =
vilka rader. Det är hela grammatiken i nittio procent av det jag kör.

`count(*)` räknar rader. Det är det verktyget svarar på frågan "har Arsenal
fortfarande en trupp?" — `count(*) = 30` betyder ja.

---

## 3. Anslutningar, och varför de tar slut

Varje samtal med Postgres kräver en **connection**. Vår databas tillåter
**60 samtidiga**. Det låter lite, och det är lite — det är för att vi kör
den minsta maskinen Supabase säljer.

Därför finns **poolern** (Supavisor). I stället för att varje klient öppnar
en egen dörr håller poolern ett fåtal dörrar öppna och låter många dela på
dem.

När folk säger "databasen är överbelastad" menar de nästan alltid det här:
alla 60 upptagna, nästa fråga får vänta. Det är det avsnitt 6 mäter. Vi har
legat på 16–20 av 60 varje gång jag tittat, alltså har det aldrig varit
orsaken. Det är värt att mäta ändå, just för att kunna avfärda det direkt
när supporten föreslår det.

---

## 4. Döda rader, vacuum och "bloat"

Det här är det mest kontraintuitiva i Postgres, och det har kostat oss på
riktigt.

När du raderar en rad **försvinner den inte**. Postgres markerar den som död
och låter den ligga kvar. När du uppdaterar en rad skrivs en ny version och
den gamla blir död. Filen på disk växer alltså även om antalet riktiga rader
står stilla.

**VACUUM** är städningen som gör det utrymmet återanvändbart. Normalt sköts
det automatiskt av **autovacuum**.

Så här bet det oss: tabellen `net._http_response` är **UNLOGGED**, en
speciell sorts tabell som rapporterar noll rader till statistiken. Autovacuum
utlöses av statistiken. Alltså besökte autovacuum den aldrig, och den växte
till 17 MB med noll levande rader i sig. Varje anrop ut från databasen fick
då skanna igenom skräpet: 5,2 sekunder per anrop, 29 645 anrop. Det åt upp
den enda bakgrundsarbetare pg_net har, vilket i sin tur blockerade
schemaläggaren, vilket gjorde att 18 % av minutjobben aldrig startade.

En manuell `VACUUM (FULL, ANALYZE)` tog den från 17 MB till 336 kB.
Migration 104 lade in städningen som schemalagda jobb. Avsnitt 4 i skriptet
är hur du ser att de fortfarande går.

**Det du behöver minnas:** en tabell som växer utan att antalet rader växer
är ett varningstecken, och lösningen heter vacuum.

---

## 5. Schemalagda jobb bor inuti databasen

**pg_cron** är ett schema som lever i Postgres själv. Vi har 17 jobb. Det
viktigaste är `match-watcher-1min`, som går **varje minut** och letar efter
mål, avspark och slutsignal.

Du ser dem så här:

```sql
SELECT jobname, schedule, active FROM cron.job ORDER BY jobname;
```

Och historiken i `cron.job_run_details`. Felmeddelandet `job startup timeout`
betyder **inte** att jobbet kraschade — det betyder att det aldrig kom igång.
Det är en helt annan sak och leder åt ett annat håll: något hindrar
schemaläggaren från att starta, inte något fel i jobbets kod.

En minut som inte kördes är ett mål ingen fick pushnotis om. Ingen användare
rapporterar det. Det är därför avsnitt 3 finns.

---

## 6. Migrationer

Varje ändring av databasens struktur ligger som en numrerad fil i
`backend/supabase/migrations/`. De körs i ordning, en gång var, och är hur
databasen ser likadan ut överallt. Vi är uppe i 105.

Man ändrar aldrig en migration som redan körts. Man skriver en ny.

---

## 7. Vad som är speciellt med just vår uppsättning

Fyra saker som förklarar återkommande begränsningar:

**Vi kör den minsta maskinen.** `max_worker_processes = 6`,
`shared_buffers` 224 MB, 60 anslutningar. Databasen är bara 119 MB, så
storleken är inte problemet — men det finns lite marginal när något går fel.

**Vi är inte superuser.** Vi ansluter som `postgres`, vilket här varken är
superuser eller medlem i `supabase_admin`. Tabellerna `cron.job_run_details`
och `net._http_response` ägs av `supabase_admin` och vi har bara `MAINTAIN`
på dem. Praktiskt: **VACUUM och ANALYZE funkar, `ALTER TABLE … SET
(autovacuum_…)` gör det inte.** Därför är schemalagd vacuum vår enda väg.

**REST-nycklarna i `backend/.env` är döda sedan 11 maj 2026.** De ger 401.
Bara `SUPABASE_DB_URL` fungerar lokalt. Appens egen nyckel i
`ios/GoalDigger/Configuration.xcconfig` fungerar däremot — och det är den
skriptet använder, så avsnitt 1 mäter exakt vad en telefon får.

**Den direkta endpointen är IPv6-only.** `db.<ref>.supabase.co` har ingen
A-record alls. Från en vanlig uppkoppling utan IPv6 går den inte att nå.
Använd alltid poolern (`aws-1-eu-west-1.pooler.supabase.com`). Det är också
förklaringen till varför Supabase egen lint sa `CONNECT_TIMEOUT` samtidigt
som jag pratade obehindrat med databasen: vi testade olika vägar.

---

## 8. De tre kommandona som räcker

**Hälsokoll, börja alltid här:**

```bash
cd /Users/anton/FantasyLeague && ./scripts/db-health.sh
```

**Öppna databasen och ställ egna frågor:**

```bash
cd /Users/anton/FantasyLeague && set -a && source backend/.env && set +a && /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL"
```

Väl inne: `\dt` listar tabeller, `\d teams` visar en tabells kolumner, `\q`
avslutar. Allt du skriver måste sluta med semikolon.

**Affärssiffror, inte hälsa:**

```bash
cd /Users/anton/FantasyLeague && ./scripts/insights.sh
```

---

## 9. Reflexen att bygga

När appen ser trasig ut: **kör hälsokollen innan du rör kod.** Den svarar på
den enda fråga som avgör vad du ska göra härnäst — är det vår kod, vår data,
eller deras infrastruktur. Alla tre ser likadana ut från soffan, och idag
kostade den skillnaden en timme.

Se även: `.claude/skills/db-health-check/SKILL.md` för hur varje rad ska
tolkas, `/DATA_SOURCES.md` för vilka fält vi litar på från API-Football, och
`RUNBOOK.md` för återställning.
