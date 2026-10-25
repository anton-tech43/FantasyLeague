# Vad driftstoppen har lärt oss

Fyra gånger på fem månader har databasen tagit appen ner eller nära nog. Det här
är inte loggen över dem — den finns i `IMPLEMENTATION_PROGRESS.md` och
`SJALVRANNSAKAN_2026-09.md`. Det här är det som visade sig vara **samma sak varje
gång**, formulerat så att det går att ta med sig till nästa system.

Exemplen är härifrån. Mönstren är det inte.

| | Vad | Hur länge | Vad det visade sig vara |
|---|---|---|---|
| 1 jun 2026 | Varning om disk-IO | ingen nedtid | Ett index som inte täckte frågan |
| 23 aug – 6 sep | Degradering → helt nere | **7 dygn** | Resurserna slut, ingen visste |
| 20–21 sep | Hela instansen trög | 17 h | Reste sig själv, aldrig förklarat |
| 21–25 okt | Degradering → helt nere | **4 dygn** | Schemaläggaren kunde inte starta jobb |

---

## 1. Larmet får inte bo i det som kan gå sönder

I sju dygn låg produktionen nere utan att någon visste. Inte för att övervakning
saknades — det fanns en kontroll som gick var 30:e minut och larmade när
pipelinen tystnade.

Den var en rad i databasen. Som var nere.

Varje larm — schemaläggarens egen heartbeat, hälsotabellen, felloggen — bodde
inuti exakt den sak de skulle vakta. När den dog, dog de med den, tyst.

Fixen blev en kontroll som kör **på en annan maskin på ett annat nät**, var
tredje timme, och ställer den enda fråga som betyder något: *skulle en användare
se något om hon öppnade appen nu?* Den skickar larmet via en väg som inte rör
databasen alls.

> **Regel:** din övervakning får inte dela felkälla med det den övervakar. Om
> svaret på "hur vet jag att X lever?" går genom X har du ingen övervakning, du
> har en förhoppning.

Samma fälla finns i larm*vägen*. En av våra heartbeats upptäckte problemet helt
korrekt — och skickade sitt larm via samma trasiga nyckel. Den såg allt och kunde
inte berätta det. En annan hade en mottagarlista som var tom. Larmet gick. Det
fanns ingen att gå till.

---

## 2. Ett larm som bara mäter symptom missar varje långsamt haveri

Det här är den dyraste lärdomen, och den kom först i oktober.

Den externa kontrollen från lärdom 1 fungerade. Den ställde fyra frågor: svarar
API:et, hur gammalt är innehållet, när hämtades data senast, avvisas något. Alla
fyra är rimliga. Alla fyra är **symptom**.

Och i tre dygn svarade alla fyra ja, medan systemet höll på att dö:

```
20 okt   1326 jobb, 0 fel, 0,1 s snitt    ← helt rent
21 okt   1453 jobb, 87 fel, 1,8 s         ← haveriet börjar 11:22
22 okt   1332 jobb, 201 fel, 7,4 s
23 okt   1029 jobb, 148 fel, 58 s
24 okt    406 jobb, 300 fel, 129 s        ← först nu larmar kontrollen
25 okt      4 jobb, 149 fel, 461 s        ← stillastående
```

Varje tröskel var satt mot ett *stillastående* system: innehåll äldre än 30
timmar, hämtning äldre än 10. Men systemet stannade inte. Det **läckte** — lite
långsammare varje dygn, allt fortfarande inom tröskeln, ända tills det inte var
det. Då var instansen inte längre räddningsbar utan att byta hårdvara.

Det första symptomet fanns hela tiden, från 11:22 den 21:a: schemaläggaren
kunde inte **starta** sina jobb. Inte "jobbet misslyckades" — jobbet kom aldrig
igång. Den siffran är noll på en frisk dag och tvåsiffrig inom en timme när det
börjar. Vi mätte den inte, för vi mätte vad användaren såg, och användaren såg
ingenting förrän på dag fyra.

> **Regel:** mät orsaken, inte bara symptomet. Varje symptomtröskel antar att
> haveriet är plötsligt. De flesta är det inte — de är gradvisa, och en gradvis
> kurva passerar aldrig en tröskel som är satt för ett stopp. Leta efter det
> mått som är **noll** när allt är friskt. Det har ingen brusnivå att gömma sig i.

---

## 3. "Succeeded" mäter nästan alltid fel lager

Schemaläggaren skriver `status='succeeded'` när dess SQL kördes utan fel.
SQL:en är "lägg anropet i kön". Den säger ingenting om att något svarade. Sex
dygn gick med 401 på varje anrop och en helt grön logg.

Samma sak ett lager upp: våra innehållsjobb stämplas lyckade när processen
avslutas snyggt. Under oktoberhaveriet är sex av dem stämplade lyckade utan att
ha skrivit en enda rad — de kunde inte nå databasen, konstaterade det, och
avslutade prydligt.

Ingen av dem ljuger. Båda rapporterar sanningsenligt om det lager de kan se.
Problemet är att vi läste deras svar som ett svar på *vår* fråga.

> **Regel:** definiera "lyckades" vid det lager användaren känner av. För ett
> jobb som anropar en tjänst är kriteriet svarskoden, inte att jobbet kördes.
> För ett innehållsjobb är det en rad i databasen, inte att processen slutade.

---

## 4. Den uppenbara misstänkta är nästan alltid fel

I juni höll disk-IO:t på att ta slut. En tabell hade vuxit till 93 727 rader och
340 MB, aldrig gallrad. Uppenbart: tabellen är för stor, trimma den.

Fel. Statistiken visade **32 sekventiella scanningar mot 25 058 indexsökningar**
— den lästes inte sönder. Det riktiga spåret var att varje indexsökning hämtade
~55 rader från disk. Frågan filtrerade på tre kolumner; indexet täckte två. Så
databasen slog upp den första, läste sedan 55 stora rader från disk för att
filtrera på den tredje. Den läsningen, inte radantalet, åt budgeten.

Fixen var ett index. Gratis. Trimningen gjordes också, men den var bisak.

Det svåra är att den felaktiga förklaringen är *tillfredsställande*. Stor tabell,
mycket disk — det låter rätt, och man slutar leta.

**Och jag gjorde om det, två gånger, i oktober, i samma vecka som jag skrev den
här sidan.**

Först pekade jag ut vårt minutjobb som orsaken till att budgeten tömdes.
Siffran — 1 440 anrop per dygn — var mätt. Slutsatsen var det inte;
septemberrapporten på min egen skärm skrev "orsakshypotes, ej bevisad".

Sedan byggde jag en teori om att en oanvänd replikeringsslot låste loggfiler.
Den förklarade **allt**: att ingen kod ändrats, att det växte gradvis, ett
oförklarat glapp på 170 MB som mätts en månad tidigare. Jag kallade den det enda
som passade. När databasen svarade igen fanns det noll slots. Inte en liten.
Inga.

> **Regel:** "stor" och "orsak" är olika påståenden, och en hypotes som förklarar
> allting är en varningssignal, inte en bekräftelse. Skriv ner skillnaden mellan
> vad du har mätt och vad du har slutit dig till, varje gång. Det är den enda
> vanan som skyddar mot den här, för känslan av att ha rätt är identisk i båda
> fallen.

---

## 5. Det som växer har ingen commit

De flesta buggar kommer med en deploy. Du kan `git bisect`, läsa diffen, se när
det började.

Oktoberhaveriet kom utan att något ändrats. Senaste ändringen i databasen var
tre veckor gammal. Inga commits på en vecka. Konfigurationen orörd.

Den klassen kommer av sig själv: en tabell som växer lite varje dygn, en logg
ingen gallrar, en cache som aldrig töms. Den korsar en tröskel en natt klockan
tre och är då *plötslig* — men den har byggts upp i månader.

Två som bitit oss:

- Schemaläggarens egen körlogg växte till 177 070 rader och 88 MB. Den gallrar
  inte sig själv. Ingen hade sagt åt den att göra det.
- En systemtabell var **UNLOGGED**, vilket betyder att den rapporterar noll
  rader till statistiken. Den automatiska städningen utlöses av statistiken.
  Alltså besöktes den aldrig, och växte till 17 MB med noll levande rader.
  Varje utgående anrop fick skanna skräpet: 5,2 sekunder styck, 29 645 anrop.
  Det åt upp den enda bakgrundsarbetare tjänsten hade, vilket blockerade
  schemaläggaren, vilket gjorde att 18 % av minutjobben aldrig startade.

> **Regel:** allt som växer behöver något som vaktar det, för `git blame` hittar
> det aldrig. Och den farligaste varianten är osynlig för den automatik du litar
> på — en tabell som växer utan att radantalet växer är ett varningstecken.

---

## 6. Fixen kan vara det som dödar dig

Juni igen. Tabellen hade 340 MB att återvinna, och den tunga städningen hade
gett tillbaka dem. Frestande.

Den sortens städning skriver om hela tabellen. På en instans vars **IO-budget**
redan höll på att ta slut hade den bränt precis den resurs vi försökte rädda, och
låst tabellen under tiden. Larmet gällde IO, inte diskutrymme. Den lätta
städningen märker utrymme som återanvändbart utan att skriva om något. Rätt
verktyg.

Vi lärde oss det och schemalade ändå den tunga varianten en gång i veckan. I
oktober körde den i 32 minuter och misslyckades, mitt under haveriet.

> **Regel:** matcha åtgärden mot larmet, inte mot symptomet den råkar dela namn
> med. "Disken är full" och "disken hinner inte med" kräver motsatta ingrepp. Och
> en lärdom som bara skrivits ner är inte implementerad — gå tillbaka och kolla
> att den faktiskt gäller i systemet.

---

## 7. Prod driver ifrån repot, tyst

Vår migrationstabell innehåller bara de sjutton första. Resten — ett sjuttiotal —
är körda för hand. Tre nummer finns två gånger. Fem schemalagda jobb är
borttagna utanför versionshanteringen, och en kommentar i en källfil är enda
stället det står.

Följden är inte bara att verktygen slutar fungera. Det är att **repot inte längre
beskriver systemet**. Den som läser det för att förstå hur något hänger ihop
läser en version av verkligheten som inte finns.

Därför genereras vår systemkarta ur den levande databasen i stället för att
skrivas för hand, och därför finns en kontroll som jämför dem. Första gången den
kördes hittade den att kartan hänvisade till ett skript som var raderat.

> **Regel:** om du inte kan återskapa produktionsmiljön ur repot har du inte
> infrastructure-as-code, du har anteckningar. Och anteckningar ruttnar. Det du
> inte kan generera ur sanningen måste ha en kontroll som jämför med den.

---

## Det korta

1. Larmet får inte bo i det som kan gå sönder.
2. Ett larm som bara mäter symptom missar varje långsamt haveri.
3. "Succeeded" mäter nästan alltid fel lager.
4. Den uppenbara misstänkta är nästan alltid fel — och en hypotes som förklarar allt är en varningssignal.
5. Det som växer har ingen commit.
6. Fixen kan vara det som dödar dig.
7. Prod driver ifrån repot, tyst.

Och den som binder ihop dem: **varje gång har det tagit längre tid att tro på
mätningen än att göra den.** Juni hade svaret i statistiktabellen hela tiden.
September hade felkoderna liggande i sex dygn. Oktober hade kurvan i
körloggen från den 21:a, fyra dygn innan någon tittade. Datan fanns. Någon hade
bestämt sig först.

---

*Relaterat: `DB_BASICS.md` (hur delarna hänger ihop, för en icke-DBA) ·
`RUNBOOK.md` (vad man gör när det brinner) · `scripts/db-health.sh` (kör den
först) · `scripts/io-attribution.sh` (mät innan du skär) ·
`scripts/post-restore.sh` (de första sextio sekunderna efteråt).*
