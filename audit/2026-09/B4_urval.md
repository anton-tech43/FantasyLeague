# B4 · Kvalitativt urval — PL-innehåll 1–29 aug 2026

**Urval:** 70 items ur `out/08_pl_items.csv`, stratifierat: news × 6 lag med flest följare/volym
(arsenal, man_city, liverpool, chelsea, man_utd, spurs) × 4 veckor (≤2 per cell, slumpfrö 7) = 52 news;
samtliga 10 `type=matchday`; 8 sunday_briefs (samma lag). Reproducera: kör python-blocket i
`B4_urval.md`-commiten (`random.seed(7)`), eller filtrera på id-prefixen nedan.

**Måttstock:** routines `PROMPT.md` (GOLDEN RULE, BATTLE-TESTED VOICE RULES 1–18, TEAM IMPACT-gate,
TRANSFER-gate, HEADLINE CLARITY, ANALOGY RULES + självkritik 4×1–5, TALKING POINTS, IMMERSIVE HEADLINE,
Personal life). Endast **interna motsägelser** räknas som "osant" (HANDOFF §4.5).

**Metod:** varje item lästes i sin helhet (push_title/push_text/headline/immersive_headline/
immersive_context/talking_points/body). Girl ref poängsatt 1–5 på Naturlighet / Relevans /
Målgrupp / Cringe-risk (5 = ingen cringe) — samma skala som PROMPT.md:850. Godkänt ≥16/20 och ingen
dimension ≤2. 15 items bedömdes en andra gång blint (markerade ★) — 13/15 hamnade inom ±1 poäng,
2 avvek med 2 (7625ae96, e5825c07); ingen ändrade godkänt/ej.

## 1. Girl ref (immersive_context) — poäng per item

| id | lag | typ | ord | N | R | M | C | Σ | OK | Kommentar |
|---|---|---|---|---|---|---|---|---|---|---|
| 37aa25a8 ★ | chelsea | news | 16 | 5 | 4 | 5 | 4 | 18 | ✓ | "Left off the guest list, viral at the door" — snappar |
| e064f0f8 | arsenal | news | 16 | 5 | 5 | 5 | 4 | 19 | ✓ | Ex som "är helt över det" men svarar på varje story — gold |
| 528365f4 ★ | liverpool | news | 18 | 4 | 5 | 5 | 4 | 18 | ✓ | Hinge-superlike → unmatched samma dag |
| 0a084a27 | chelsea | news | 22 | 4 | 5 | 4 | 4 | 17 | ✓ | Ex-ets bästa vän vill bli rumskompis (Henderson) |
| 6bcbe2fc ★ | liverpool | news | 13 | 4 | 4 | 5 | 4 | 17 | ✓ | Halsont före Hinge-dejten = hösnuva |
| 36dab615 | chelsea | news | 29 | 4 | 5 | 4 | 4 | 17 | ✓ | Deadline för ex som passerar — men 29 ord |
| e92dbe07 | arsenal | news | 24 | 4 | 4 | 5 | 4 | 17 | ✓ | Tillbaka på Hinge efter ghosting |
| 43c78f58 | man_city | news | 16 | 4 | 4 | 4 | 4 | 16 | ✓ | Ex på samma husfest (Stones) |
| 828feddb ★ | chelsea | news | 19 | 4 | 4 | 4 | 4 | 16 | ✓ | Radera Hinge samma vecka Bumble-matchen levererar |
| 6e5deec5 | arsenal | matchday | 15 | 4 | 4 | 4 | 4 | 16 | ✓ | Bästa matchen på första svepet |
| 181f70f1 | spurs | news | 20 | 4 | 4 | 4 | 4 | 16 | ✓ | Lämnar gruppchatten, vinner pubquizen |
| 3fd1b3f4 | spurs | news | 26 | 4 | 4 | 4 | 4 | 16 | ✓ | "Sorry I wasn't the easiest" på väg till flyget |
| 70b9ff84 ★ | arsenal | news | 17 | 4 | 4 | 4 | 4 | 16 | ✓ | Flatmate: "I'm renewing" före hyresvärden frågat |
| 49ef6d02 | arsenal | news | 21 | 4 | 4 | 4 | 3 | 15 | ✗ | "done shopping" + fyra påsar — ok men platt |
| 6ee6a8ae | arsenal | news | 22 | 4 | 4 | 4 | 3 | 15 | ✗ | Två housemates cancelar samma vecka |
| c552000e | arsenal | news | 25 | 4 | 3 | 4 | 4 | 15 | ✗ | Story-views-refresh; payoff upprepar setup (regel 6) |
| 0dea5d03 | liverpool | news | 19 | 4 | 3 | 4 | 4 | 15 | ✗ | "One-click-killen köper din pub" — fyndig, parallellen haltar |
| adebe906 | arsenal | news | 23 | 3 | 4 | 4 | 4 | 15 | ✗ | "Out for delivery" — ok, generisk |
| 4865f378 | liverpool | news | 27 | 4 | 4 | 4 | 3 | 15 | ✗ | Hen do om tre veckor, inget bokat — 27 ord |
| 5b9603db | arsenal | news | 31 | 4 | 3 | 4 | 3 | 14 | ✗ | Ex på annans fest — 31 ord, payoff förklarar |
| cf6ee850 | man_city | matchday | 13 | 3 | 3 | 4 | 4 | 14 | ✗ | Olivia Rodrigo-promo — snappar, men "dialled in" är copywriter |
| 54666459 ★ | liverpool | sunday | 17 | 3 | 3 | 4 | 4 | 14 | ✗ | Födelsedagsbrunch där alla dyker upp |
| ca232c7d | man_city | news | 24 | 3 | 3 | 4 | 4 | 14 | ✗ | Viral TikTok från grupp-resan — 24 ord |
| c255bfc9 | man_city | news | 24 | 3 | 3 | 4 | 4 | 14 | ✗ | Screenshottat tre nya flatmates |
| 36103033 | man_city | news | 17 | 3 | 4 | 3 | 4 | 14 | ✗ | LinkedIn-rekryteraren — jobb, inte gossip |
| e561b5b3 | spurs | news | 24 | 3 | 3 | 4 | 4 | 14 | ✗ | Swipar äntligen höger — payoff upprepar |
| 8b641e87 | man_city | news | 20 | 3 | 4 | 4 | 3 | 14 | ✗ | Pålitliga vännen lämnar gruppchatten |
| 44c6d10a | man_city | news | 26 | 3 | 3 | 4 | 3 | 13 | ✗ | Följer nya flatmaten på Instagram — payoff förklarar allt |
| 4f4903fe | man_city | sunday | 19 | 3 | 3 | 4 | 3 | 13 | ✗ | Ex på samma kafé — "rematch" haltar |
| 31441491 ★ | man_utd | news | 21 | 3 | 3 | 3 | 4 | 13 | ✗ | Work nemesis + kollega från mammaledighet |
| 45f2d954 | spurs | matchday | 23 | 3 | 3 | 3 | 4 | 13 | ✗ | "Acing your first day at work" — kliché |
| 71342b97 | man_utd | news | 26 | 3 | 3 | 3 | 4 | 13 | ✗ | Nya på jobbet får alla att skratta — kliché |
| 470c8f09 | chelsea | news | 24 | 3 | 2 | 4 | 4 | 13 | ✗ | Ex-ets nya partner på din födelsedag — mappar inte Wilshere |
| 2667263e | man_utd | news | 29 | 3 | 3 | 3 | 3 | 12 | ✗ | Gap year i Barcelona — 29 ord, "opinions about pressing space" |
| 6319a8fb | liverpool | news | 25 | 3 | 3 | 3 | 3 | 12 | ✗ | Gruppchatt-dramat kommer hem — vag |
| 501127bd ★ | chelsea | news | 24 | 3 | 3 | 3 | 3 | 12 | ✗ | "Situationship era" — bra ord, resten förklaring |
| 32806291 | newcastle | matchday | 24 | 3 | 3 | 3 | 3 | 12 | ✗ | Välkomstpresent + stänger dealen — jobb |
| f67ac759 | chelsea | news | 27 | 3 | 3 | 3 | 3 | 12 | ✗ | Död gruppchatt, en vän stannar — 27 ord |
| aeb9c168 | chelsea | news | 24 | 3 | 3 | 2 | 4 | 12 | ✗ | "Right before the big pitch" — corporate |
| ada2cbfb | liverpool | news | 25 | 3 | 3 | 2 | 4 | 12 | ✗ | All-hands från main stage efter Teams — corporate |
| 25e4c89c | spurs | news | 25 | 3 | 3 | 3 | 3 | 12 | ✗ | Gruppchatten köper från samma ställe |
| d998cca3 | chelsea | news | 25 | 3 | 3 | 2 | 4 | 12 | ✗ | Klientmötet dag två — corporate |
| 966bbd0f ★ | liverpool | matchday | 13 | 3 | 2 | 4 | 3 | 12 | ✗ | Sabrina Carpenter raderar låt — parallell forcerad |
| 8cab0806 | spurs | news | 14 | 3 | 3 | 3 | 3 | 12 | ✗ | Serien förnyad fem säsonger — ok men mid |
| c313273b | spurs | news | 27 | 3 | 3 | 3 | 3 | 12 | ✗ | Deadline + familjenyheter i gruppchatten (se §3 privatliv) |
| 748dcc85 | man_city | matchday | 12 | 3 | 3 | 3 | 3 | 12 | ✗ | Första post-breakup-dejten spårar ur |
| e9d7f9c6 ★ | man_city | news | 18 | 3 | 3 | 2 | 3 | 11 | ✗ | Företag som "shedding its best people" — corporate |
| 8ede50be | liverpool | news | 26 | 3 | 3 | 2 | 3 | 11 | ✗ | Nekad på förstahandsuniversitetet — fel ålder |
| 7625ae96 ★ | liverpool | news | 27 | 3 | 3 | 2 | 3 | 11 | ✗ | Generiskt jobb-scenario, 27 ord, ingen anchor |
| ba4daa60 | man_utd | news | 25 | 3 | 3 | 2 | 3 | 11 | ✗ | "Handing in her notice" — jobb |
| d3ffc7c7 | man_utd | news | 36 | 3 | 3 | 3 | 2 | 11 | ✗ | 36 ord; DM från "someone you kind of forgot" |
| e9c37c90 | man_utd | news | 13 | 2 | 3 | 3 | 3 | 11 | ✗ | Taylor Swift clockar en gitarrist — påklistrat |
| 693d66b1 ★ | wolves | matchday | 23 | 3 | 3 | 2 | 3 | 11 | ✗ | "Return to your old job for one day" — jobb |
| c2eddcda | man_utd | news | 26 | 3 | 3 | 3 | 2 | 11 | ✗ | Glömma sitt namn första dagen — cringe |
| 1c63e207 | spurs | news | 29 | 2 | 3 | 3 | 3 | 11 | ✗ | CV till andra företag — 29 ord |
| e5825c07 ★ | spurs | sunday | 17 | 3 | 2 | 3 | 3 | 11 | ✗ | "Gruppchatten efter familjebråk" — mappar inte |
| cf22c3d3 | chelsea | sunday | 12 | 3 | 2 | 3 | 3 | 11 | ✗ | "Mötet du fasat för" — generiskt |
| 6b6d1401 | spurs | news | 37 | 2 | 3 | 3 | 2 | 10 | ✗ | 37 ord, kollega som stannar — copywriter |
| 60fe15e2 ★ | liverpool | news | 28 | 2 | 3 | 3 | 2 | 10 | ✗ | **"football equivalent of"** (förbjudet, PROMPT.md:836), 28 ord |
| 117d87ba | man_utd | news | 17 | 3 | 3 | 2 | 2 | 10 | ✗ | "Fernandes, peers, done." — ingen analogi |
| ceea626a ★ | man_city | matchday | 31 | 2 | 3 | 3 | 2 | 10 | ✗ | Showrunners/co-leads, 31 ord |
| 9643cf92 | spurs | news | 33 | 2 | 3 | 2 | 2 | 9 | ✗ | Teaterregissör/closing night — kreativ bransch (regel 8), 33 ord |
| a0c261db | wolves | matchday | 16 | 2 | 3 | 2 | 2 | 9 | ✗ | Ingen analogi: "that's a mood" |
| 25633660 ★ | man_city | news | 29 | 2 | 3 | 2 | 2 | 9 | ✗ | Ingen analogi; citerar The Independent |
| ea1da3d1 | arsenal | sunday | 11 | 2 | 3 | 2 | 2 | 9 | ✗ | Faktarad, ingen analogi |
| a42278a9 | man_utd | sunday | 13 | 2 | 3 | 2 | 1 | 8 | ✗ | Faktarad; immersive_headline med versaler + "PSG drawn 1-1" |
| 02b9da5f | spurs | sunday | 11 | 2 | 3 | 2 | 1 | 8 | ✗ | Faktarad; versaler |
| c0dfff54 | man_city | sunday | 0 | – | – | – | – | – | ✗ | **Tomt** immersive_headline + immersive_context (kortet saknar text) |

**Utfall:** 13/69 godkända (19 %). Medianpoäng 12/20. Ordlängd median 23 (regel: ≤16; 304/350 över
i hela populationen, `26`). I hela populationen börjar 283/411 med "It's like/Like/Imagine" (regel 2:
verb först); 3 använder "football equivalent". Zonfördelning i urvalet: jobb/kontor ~40 %,
dating/ex ~30 %, gruppchatt/vänner ~20 %, kultur ~10 % — regeln säger gossip först, jobb bara om
"razor-sharp".

## 2. Övriga gate-/regelkontroller i urvalet

**TEAM IMPACT / GOLDEN RULE (push_eligible):**
- ✓ TRANSFER-gaten hålls väl: alla rykten i urvalet är feed-only (Vinicius, Yildiz, Alvarez, Martinelli,
  Rodri→Barca, Allan, Baleba, Rashford→Fener, Page, Romero-samtal, van de Ven "close").
- ✗ Pushade items utan team-impact: `7625ae96` (Slot tackar nej till Nederländerna — ex-tränare,
  "fun trivia"), `ca232c7d` (Guardiola-dokumentär), `501127bd` (BBC-förhandsartikel "Chelsea finished
  10th" — ingen händelse alls, pushad 14 aug 09:22), `c313273b` (Maddison-skada + tvillingar).
- ✗ `c313273b` bryter dessutom **Personal life**-regeln ("Family — never", PROMPT.md:440): items om
  spelarens barn, pushad. Enda träffen i populationen (1/433).

**HEADLINE CLARITY:** hålls i 68/70 — push_text anger händelsen. Undantag: `501127bd` (ingen händelse),
`c2eddcda` (push_title "Hull. Newly promoted Hull." bär inte nyheten själv, men push_text gör det — OK).

**Röst-tokens (brand voice-brott):**
- "your partner" / "your guy" i TP/body: 12 items i populationen (t.ex. `7625ae96` "Does your partner
  think…", `31441491` "how your guy processes"). Rösten är tjej→pojkvän ("he/him"); "your partner" är
  ett AI-neutraliserat register som specen inte tillåter.
- `[him]` som placeholder: 8 items (`c552000e` "Tell [him]", `c255bfc9` "Tell [his name]"). iOS
  substituerar bara `[his name]` (`AppState.swift:196`) → **"[him]" renderas bokstavligt** på kortet.
- "If [his name] follows Liverpool, expect…": 15 items. Hon följer laget *för att* han gör det;
  villkorssatsen är ett generatorhedge som läses som cringe (`8ede50be`, `c2eddcda`).

**Talking points:** "Ask him" max 1 hålls (0 brott, `25`). TP1 aldrig "Did you know" (0). 4 items har
4 TP i stället för 3 (`8cab0806` m.fl.). Match-result-TP1 med målskytt (Round-4-mönstret) används i
`6e5deec5` ("Pre-pour his drink") — bra — men saknas i `ceea626a`, `c2eddcda`.

**Immersive headline:** news/matchday 0/353 med versaler, 0 rader >22 tecken — `post_news.sh`-gaten
fungerar. **sunday_brief: 41/80 med versaler, 19/80 helt tomma** (`immersive_headline` och
`immersive_context` NULL) → kortet renderar utan text. Sunday-brief-routinen går inte genom samma gate.

**Tider i kopian (A5):** 25 items har klockslag i push/headline; 5 anger zon. Alla är UK-tid utan
etikett ("Bournemouth at home at 2pm"). Svensk läsare är en timme fel. Intern motsägelse:
`4f4903fe` (16 aug) "Bournemouth … next Sunday at 2pm" vs `c0dfff54` (23 aug) "host Bournemouth today
at 1pm" — API-Football: 23 aug 14:00 UK. Söndagsbriefen samma dag hade fel tid.

**Interna motsägelser ("osant" enligt regel 5):**
- `60fe15e2` (8 aug): "adds real defensive depth to **Arne Slot's** squad" — Slot avgick i maj
  (`7625ae96` 13 aug: "won the title then got sacked"); Iraola är tränare i alla andra
  Liverpool-items från 2 aug (`4865f378`, `6bcbe2fc`). Enda "Slot's squad" i populationen.
- `966bbd0f` (10 aug): "Iraola's first home game in charge" (Monaco, vänskapsmatch) vs `ada2cbfb`
  (29 aug): "his first home game at Anfield today". Två "första hemmamatcher".
- `c0dfff54` vs `4f4903fe`: 1pm vs 2pm (ovan).
- Namn: "Savio" (4 items) vs "Savinho" (6 items) för samma City→Spurs-spelare
  (`e561b5b3` "Savinho", `25e4c89c`/`45f2d954` "Savio") — inte fel, men bryter
  NAME EXPLANATIONS-konsekvensen på ett kort tidsspann.
- Inga tabellpåståenden från förra säsongen presenterade som nuvarande i urvalet. De 84 träffarna i
  `20_stale_season_text.csv` är legitima "last season"-referenser i förssäsongskontext
  (t.ex. "Chelsea finished 10th last season"). A1-symptomet syns i stället i `28d`
  (season-state-texter, se rapporten A18) och i lagurvalet (`28a`/`28b`).

**Opener-rotation:** "He might have opinions" 3/70 (+5 repetitioner inom 72 h i `23`); "T-shirt
material" 2/70 (två lag); "Crisis averted" 2/70. Push-title-variation svag men inom tolerans.

## 3. Slutsats per segment

| Segment | Dom | Motivering |
|---|---|---|
| news (52) | **Godkänd fakta/gates, underkänd girl ref** | TRANSFER-gaten och HEADLINE CLARITY hålls; 4 pushar utan team-impact; analogierna är för långa (median 23 ord), 70 % "It's like"-öppning, jobb-zon dominerar. 1 privatlivsbrott. |
| matchday (10) | **Fel innehållstyp** | Samtliga 10 är routine-skrivna referat av försäsongs-/cupmatcher (Wolves–Port Vale, City–Atletico, Everton–Preston …). Ingen är den deterministiska FT-artikeln för en PL-match — den kedjan har inte fyrat en enda gång (A17). 2 av 10 till inaktiva Wolves (0 följare). |
| sunday_brief (8 av 80) | **Underkänd kortrendering** | 19/80 saknar immersive-fält, 41/80 har versaler, tidsfel i "today"-brief, girl ref mestadels faktarader. Fakta i sig konsekvent. |

**Spot-check för Anton (10 items):** `e064f0f8` (bäst), `60fe15e2` (Slot + "football equivalent"),
`c313273b` (tvillingar), `c0dfff54` (tomt kort, fel tid), `7625ae96` ("your partner"), `c552000e`
("[him]"), `501127bd` (push utan händelse), `9643cf92` (teaterregissör), `a42278a9` (versaler),
`6e5deec5` (bra TP1).
