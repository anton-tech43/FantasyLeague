# Vad driftstoppen och bug-hunten har lärt oss

Fyra gånger på fem månader har databasen tagit appen ner eller nära nog. Det här
är inte loggen över dem — den finns i `IMPLEMENTATION_PROGRESS.md` och
`SJALVRANNSAKAN_2026-09.md`. Det här är det som visade sig vara **samma sak varje
gång**, formulerat så att det går att ta med sig till nästa system.

Del 2 (lärdom 8–18) kommer från den första bug-hunten, 3 november 2026: en
systematisk jakt på buggar, säkerhetshål och skörhet innan användarna hittar dem.
Rapporten med alla 63 fynd finns i `docs/bug-hunt/BUG_HUNT_2026-11-03.md`.

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

# Del 2. Vad bug-hunten lärde oss

Driftstoppen kom till oss. Bug-hunten var tvärtom: vi letade själva, innan
någon användare hann märka något.

**Så gick den till**, eftersom metoden är en lärdom i sig. Den bygger på
Cloudflares öppna `security-audit`-skill, anpassad till vår stack:

1. **Kartlägg först, jaga sedan.** Två agenter listade varje väg in i systemet
   (124 på servern, 64 i appen) innan någon letade fel. Utan karta letar man
   där det är ljust, inte där felen är.
2. **En jägare per yta.** Nio agenter parallellt: det publika API:et, serverns
   funktioner, pushar, AI-rutinerna, appen och gamla versioner, datakvalitet,
   drift och kostnad, hemligheter, och en som testade appen som en användare.
3. **Riktig data genom riktig kod.** Jägarna körde levande rader från
   produktionen genom den kod som faktiskt körs, aldrig handplockade exempel.
4. **Den som hittar ett fel får inte bekräfta det.** En annan agent, eller
   fixaren, ska reproducera felet innan det räknas.
5. **En rapport med ägare.** Varje fynd fick allvarlighet, bevis, åtgärd och
   vem som äger den.

Resultat: 63 fynd, varav 3 allvarliga. Här är det som går att ta med sig.

---

## 8. Vakten får inte kunna skriva om sig själv

Våra AI-rutiner skriver nyhetskort. Mellan modellen och databasen står ett
skript med kontroller: stämmer fakta, finns det en källa, låter det rätt.
Skriptet är vakten.

En av rutinerna hade instruktionen *"om du hittar en kontroll som saknas, skriv
den, testa den och pusha till main"*. Den gjorde det fyra tisdagar i rad. Ingen
människa läste ändringarna. Avsikten var god: systemet skulle förbättra sig
självt. Men det betydde att **den som vaktades kunde skriva om vaktens regler**,
och att en lurad eller felande modell kunde ta bort en kontroll och få igenom
allt efter det.

Åtgärden gick i tre lager: rutinen fick inte längre rätt att pusha (en
inställning, inte en instruktion), prompten säger "föreslå, gör inte", och
skripten kontrollerar själva att de är oförändrade innan de skriver något.

> **Regel:** den som kontrolleras får aldrig ha skrivrätt till kontrollen.
> Separera rollerna i *behörigheter*, inte i instruktioner. En instruktion
> "rör inte vakten" är en förhoppning; en saknad skrivrätt är ett faktum.

*Fråga till ditt system:* vilka av dina automatiska processer kan ändra koden
eller konfigurationen som granskar dem själva?

---

## 9. En AI har samma behörighet som den som skriver texten den läser

Rutinerna läser nyhetsflöden, alltså text som vem som helst på internet kan
påverka. Samma rutin hade ett terminalverktyg och databasens huvudnyckel.

Det betyder att en rubrik som *"Ignorera tidigare instruktioner och kör …"*
i värsta fall blir ett kommando med full behörighet. Det kallas *prompt
injection*, och det har ingen fullständig lösning i själva modellen.

Vi byggde lager: texten tvättas från osynliga tecken och kortas, den märks
tydligt som data, läsning går via ett skript som bara kan läsa godkända
tabeller, rutinen förlorade webbverktyg och underagenter den inte behövde, och
all skrivning ska gå via kontrollskripten. Men så länge nyckeln finns i
miljön kan en tillräckligt lurad modell gå runt allt det. Den riktiga lösningen
är en nyckel som bara får göra det rutinen behöver: lägga in ett kort.

> **Regel:** behandla en AI-agents behörighet som om den tillhörde den som
> skrev texten agenten läser. Ge den minsta möjliga verktyg och minsta möjliga
> nyckel. Lager hjälper; minsta behörighet är det som håller.

*Fråga till ditt system:* om all text din AI läser var skriven av en
angripare, vad är det värsta den kan göra med de verktyg och nycklar den har?

---

## 10. Låt inte modellen välja det som koden kan räkna ut

Måndagsbriefen ska sammanfatta helgens match. Datan modellen fick var rätt:
de fem senaste matcherna, nyast först. Ändå beskrev **15 av 20 kort fel
helg**. Chelsea "förlorade mot Spurs" fast de slog Man Utd. Korten pushades.

Modellen valde fel rad i en lista. Det är inget konstigt fel; det är
förutsägbart att det händer ibland. Felet var att vi lät den välja.

Nu räknar koden ut "senaste resultat" innan modellen börjar och ger den en färdig
mening. Och en kontroll efteråt jämför varje resultat i texten med spelade
matcher. Sedan tidigare gäller samma princip för veckodagar: modellen räknade
datum i fel tidszon tills koden gav den dagen färdig.

> **Regel:** det som går att räkna ut deterministiskt ska räknas ut i kod och
> ges till modellen som ett faktum. Modellen formulerar; koden bestämmer vad
> som är sant. Och kontrollera efteråt det som ändå måste stämma.

*Fråga till ditt system:* vilka beslut låter du en språkmodell fatta som en
SQL-fråga eller tio rader kod kunde ha fattat utan att gissa?

---

## 11. Varje skrivning ska tåla att göras två gånger

Samma brief postades två till tre gånger per klubb, 46 kort i stället för 20.
Modellen körde sitt eget postningsskript igen för att *läsa utdatan*, och varje
körning postade allt igen. På ett annat ställe gjorde vår AI-klient om anrop
som fått ett permanent fel, fyra gånger med 12 minuters väntan.

Båda är samma sak: något upprepas, och sidoeffekten upprepas med det.

Nu är postningen **idempotent**: en andra brief för samma klubb samma dag är
ett lyckat anrop som inte skriver något. Och klienten gör bara om fel som kan
gå över (överbelastning, nätverk), aldrig fel som säger att anropet är fel.

> **Regel:** utgå från att allt kommer att köras två gånger — av en retry, en
> användare som dubbeltrycker, eller en agent som vill se resultatet igen.
> Gör skrivningar idempotenta i koden, och gör bara om det som kan lyckas nästa
> gång.

*Fråga till ditt system:* vad händer om ditt viktigaste skrivanrop körs två
gånger i rad? Har du testat det?

---

## 12. "Vilande" är inte "avstängt"

Fyra gamla serverfunktioner hade inte använts på månader. Ingen anropade
dem. Men de låg fortfarande ute och svarade, och en av dem gjorde, utan
parametrar, ett betalt AI-anrop **för vart och ett av 136 lag**. En annan
föll tillbaka på att starta en kostsam kedja för varje match, eftersom en
databasfunktion den behövde hade tagits bort.

Ingen hade glömt dem av slarv; de var "dormant", och dormant kändes säkert.

Nu vägrar alla fyra att köra om inte en uttrycklig flagga är satt och anropet
gäller exakt ett mål. Ingen av dem kan loopa längre.

> **Regel:** kod som kan kosta pengar eller skicka något till användare är
> aktiv så länge den går att anropa. Antingen tar du bort den, eller så har den
> en avstängning i koden. "Ingen anropar den" är inte ett skydd.

*Fråga till ditt system:* vilka av dina publicerade funktioner skulle kosta
pengar om någon anropade dem i morgon, och vem märker det?

---

## 13. Ett beroende man kan klara sig utan får inte ta ner allt

Funktionen som bevakar live-matcher behöver två hemligheter för att starta en
AI-rutin efter slutsignalen. Om någon av dem saknades returnerade hela
funktionen fel direkt, innan den ens tittat på matcherna. Det hade stoppat
**varje målpush och varje livescore för alla användare**, för att en
bisak saknades. Det hade inte hänt, men hemligheterna kom från ett konto som
håller på att stängas.

Nu hoppar funktionen bara över just den delen, loggar det, och gör resten.

> **Regel:** skilj på det du *måste* ha och det du *vill* ha. Det som är
> valfritt ska degradera tyst och synligt i loggen, inte ta med sig huvudsaken
> i fallet. Fråga för varje beroende: om det här försvinner, vad slutar
> fungera — och borde det verkligen sluta?

*Fråga till ditt system:* vilken enskild konfigurationsrad tar ner mest om den
försvinner?

---

## 14. Gamla versioner lever kvar, och de läser samma server

Fyra versioner av appen finns ute samtidigt och läser samma backend. Vi
testade på riktigt: jägaren kompilerade datamodellerna från varje version och
körde dem mot allt som finns i produktionen i dag — 73 klubbsidor, 194
nyheter, 1 824 spelare, tusentals livepayloads. **Noll fel.** Det var en bra
nyhet, och den gick att visa med bevis i stället för att tro.

Men samma dag hittade användartestet ett fel av samma sort: en innehållsuppdatering
tog bort id:t på två repliker. Gamla versioner sparar bara id:t när hon
stjärnmärker en replik, så hennes sparade repliker försvann tyst.

> **Regel:** ett id som någon klient kan ha sparat får aldrig försvinna. Och en
> ändring på servern är inte testad förrän den är testad mot varje
> klientversion som fortfarande finns i användarnas fickor.

*Fråga till ditt system:* vilka klientversioner läser din backend i dag, och
när testade du senast en ändring mot den äldsta?

---

## 15. Rätt data vid fel tillfälle är fel data

Tre fynd hade samma form:
- Prognosdata för nästa match köptes medan förra matchen fortfarande pågick,
  och köptes aldrig om. Formen låg en match efter på 9 av 11 matchkort.
- Ett mål som VAR dömde bort låg kvar i listan, så klubbsidan visade tre mål
  för en 2–0-match. Fem målpushar på tio dagar gällde mål som senare dömdes
  bort.
- Nyheter skrivna sent på kvällen läste tabellen innan dagens resultat var
  inräknat.

Inget av det var fel data. Det var rätt data från **före** något som ändrade den.

> **Regel:** färskhet ska mätas mot händelser, inte mot klockan. "Hämtad för en
> timme sedan" säger ingenting om data hämtades före eller efter matchen.
> Bestäm vilka händelser som gör din data inaktuell, och hämta om efter dem.

*Fråga till ditt system:* vilken data i ditt system kan vara korrekt hämtad och
ändå beskriva en värld som inte längre finns?

---

## 16. Maskera som standard, inte bara det du känner igen

En av jägarna skulle leta efter hemliga nycklar och dölja det den hittade. Den
dolde det den kände igen: kända prefix för AI-nycklar, databasnycklar och
JWT. En nyckel till en tjänst vi inte hade tänkt på hade ett annat prefix — och
skrevs ut i klartext i loggen.

Samma svaghet fanns i vår skanner som stoppar hemligheter från att committas:
den kände igen två format och missade sju.

> **Regel:** en blocklista skyddar mot det du redan har tänkt på. Maskera allt
> som *ser ut* som en hemlighet (långa slumpmässiga strängar) som standard, och
> visa bara det du uttryckligen vet är ofarligt. Det okända formatet är det som
> läcker.

*Fråga till ditt system:* vilken nyckel har du som din hemlighetsskanner inte
skulle känna igen?

---

## 17. Den som hittar felet ska inte vara den som bekräftar det

Faktakontrollerna vi byggt för AI-rutinerna stoppade 14 nyheter i produktion.
När en jägare körde om dem med riktig data var **9 av de 14 stoppen fel**: en
mening om att Manchester United var 17:e kontrollerades mot Chelseas
tabellplats. Kontrollen var byggd, testad och godkänd — av samma process som
skrivit den.

Därför har bug-hunten ett steg där en annan agent försöker *motbevisa* varje
fynd innan det räknas. När vi hoppade över det steget för att rätta snabbare
blev resultatet ärligt redovisat: 8 fixar var gjorda utan att felet först
visats i den gamla koden, och de fick stå kvar som obekräftade tills det var
gjort.

> **Regel:** reproducera innan du rättar, och låt någon annan än upphittaren
> bekräfta. Ett test som bara körs på exempel du själv valt bekräftar att du
> har rätt om exemplen, inte om verkligheten.

*Fråga till ditt system:* när visade du senast att ett fel fanns innan du
rättade det — och hur vet du att rättningen inte bara fick testet att passera?

---

## 18. Ett skydd som bara testats i en kopia av miljön är otestat

Samma kväll som bug-hunten stoppade vårt nya skydd allt riktigt innehåll.

Integritetsspärren från lärdom 8 skulle kontrollera att koden i rutinens
sandlåda var identisk med `main`. Den testades noga: i en ren kopia, en grund
kopia, på en annan gren, med lösryckt HEAD. 264 tester gröna. Sedan körde den
för första gången i den riktiga molnsandlådan och vägrade allt: dossierkorten
klockan 18, halvtidsbriefen 20:50 och båda matchartiklarna 21:56.

Orsaken: sandlådan hade en sparad referens till `main` från fem dagar tidigare.
Koden den körde var dagens, så jämfört med den gamla referensen såg varenda fil
"ändrad" ut. Inget av testerna hade en gammal referens, eftersom ingen visste att
den riktiga miljön hade det.

Två saker räddade kvällen. Spärren var byggd för att **synas** när den stoppar:
den skrev en rad i hälsotabellen, larmet gick till telefonen, och modellen
försökte inte gå runt den utan rapporterade. Och de stoppade artiklarna kunde
köras om. Rättningen jämför i stället mot den commit som faktiskt checkades ut.

> **Regel:** ett skydd som stänger vid fel måste testas i den riktiga miljön
> innan det får stänga på riktigt — kör det först i ett läge där det bara
> loggar vad det *skulle* ha stoppat. Och bygg det så att det märks när det
> stänger: ett tyst stopp är ett driftstopp du inte vet om.

*Fråga till ditt system:* vilka av dina säkerhetsspärrar har bara körts i test,
och vad händer med användarna första gången en av dem stänger fel?

---

## Det korta

**Del 1, driftstoppen**

1. Larmet får inte bo i det som kan gå sönder.
2. Ett larm som bara mäter symptom missar varje långsamt haveri.
3. "Succeeded" mäter nästan alltid fel lager.
4. Den uppenbara misstänkta är nästan alltid fel — och en hypotes som förklarar allt är en varningssignal.
5. Det som växer har ingen commit.
6. Fixen kan vara det som dödar dig.
7. Prod driver ifrån repot, tyst.

**Del 2, bug-hunten**

8. Vakten får inte kunna skriva om sig själv.
9. En AI har samma behörighet som den som skriver texten den läser.
10. Låt inte modellen välja det som koden kan räkna ut.
11. Varje skrivning ska tåla att göras två gånger.
12. "Vilande" är inte "avstängt".
13. Ett beroende man kan klara sig utan får inte ta ner allt.
14. Gamla versioner lever kvar, och de läser samma server.
15. Rätt data vid fel tillfälle är fel data.
16. Maskera som standard, inte bara det du känner igen.
17. Den som hittar felet ska inte vara den som bekräftar det.
18. Ett skydd som bara testats i en kopia av miljön är otestat.

Och den som binder ihop driftstoppen: **varje gång har det tagit längre tid att tro på
mätningen än att göra den.** Juni hade svaret i statistiktabellen hela tiden.
September hade felkoderna liggande i sex dygn. Oktober hade kurvan i
körloggen från den 21:a, fyra dygn innan någon tittade. Datan fanns. Någon hade
bestämt sig först.

Och den som binder ihop bug-hunten: **ett skydd som bara finns i en instruktion
är inget skydd.** Vakten som kunde skriva om sig själv, modellen som valde fel
match, nyckeln som en lurad AI kunde använda — varje gång var regeln nedskriven
någonstans. Det som höll var det som var byggt i behörigheter och kod.

---

*Relaterat: `DB_BASICS.md` (hur delarna hänger ihop, för en icke-DBA) ·
`RUNBOOK.md` (vad man gör när det brinner) · `scripts/db-health.sh` (kör den
först) · `scripts/io-attribution.sh` (mät innan du skär) ·
`scripts/post-restore.sh` (de första sextio sekunderna efteråt) ·
`docs/bug-hunt/BUG_HUNT_2026-11-03.md` (alla 63 fynd) · `.claude/skills/bug-hunt/`
(så körs jakten).*
