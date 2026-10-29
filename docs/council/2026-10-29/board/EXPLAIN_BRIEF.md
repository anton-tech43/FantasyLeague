# Uppdrag: förklara varje verdict så att Anton kan bedöma det

Anton (grundare av GoalDigger, svensktalande, inte utvecklare i vardagen) ska gå igenom en beslutstavla och för varje rad välja Godkänn / Avvisa / Ändra. Han tycker att raderna i dag är för tekniska för att bedöma. Du skriver om förklaringen för dina rader på **enkel svenska**.

Workspace: S=/private/tmp/claude-501/-Users-anton-FantasyLeague/1b5bbdb6-3fbe-4aa9-820e-27c6d9d5fa5f/scratchpad/council-2026-10-29

Källor (läs det som rör dina kapitel):
- Census (vad elementet är, exakt text, var i koden): $S/census-app.csv, $S/census-other.csv
- Verdicts: $S/verdicts/<GRUPP>.csv (id, verdict, how_or_where, why, evidence, confidence, usage_can_settle) och editorns resonemang $S/verdicts/<GRUPP>.md
- Beroendekontroll: $S/verdicts/dependency.csv och dependency.md (vad som läser/producerar saken, gamla appversioner)
- Persona-svaren: $S/panel/*.md. Skärmtext: $S/text/. Skärmbilder: $S/screens/ (INDEX.txt), $S/seats/ui-shots/
Endast läsning. Rör inga filer i repot.

## Skriv $S/board/explain-<GRUPP>.json

```json
{
  "screens": {
    "ONB-04": {
      "title": "Välj hans klubb (onboarding steg 4)",
      "summary": "2–3 meningar: vad skärmen är, när hon möter den, och editorns samlade bedömning av skärmen med verdicten tillämpade.",
      "shot": "screens/first-matchweek/03-onboarding-club-picker.png"
    }
  },
  "rows": {
    "ONB-04-02": {
      "what": "...",
      "proposal": "...",
      "why": "...",
      "if_accept": "..."
    }
  }
}
```

- `screens`: en post per skärm-id (de två första delarna av id:t, t.ex. ONB-04, TEAM-01, LOCK-02) som finns bland dina rader. `shot` är en relativ sökväg under $S till den skärmbild som bäst visar skärmen, eller null om ingen finns (t.ex. systemdialoger, pushar). Titta på bilden innan du väljer den.
- `rows`: EXAKT en post per census-id i dina kapitel. Inga luckor, inga extra.
  - `what` – Vad det är och var hon ser det, i en mening, utan kod-namn. Citera appens egen text på engelska inom citattecken när det hjälper ("Coming up: Liverpool (Away)…"). Säg vilken tier som ser det om det spelar roll.
  - `proposal` – Vad förslaget konkret innebär, i en mening som börjar med verbet: "Ta bort …", "Flytta till …", "Ändra så att …", "Behåll som det är." Konkret nog att Anton ser framför sig hur det blir.
  - `why` – Varför, 1–2 meningar på vanlig svenska. Ge bevisen i klartext: "5 av 6 personas tyckte…", "Datasätet visade att…", "Han (H) skulle rycka till…". Inga interna förkortningar (inga "D2", "S-1", "F3" utan förklaring; skriv "säkerhetsgranskningen", "datagranskningen", "Light-personan som inte kan något om fotboll" osv.).
  - `if_accept` – Vad som händer om Anton godkänner: vad hon slutar se eller ser i stället, vad som försvinner, vad som måste byggas, om det kräver en ny appversion eller bara en backendändring, och eventuella villkor från beroendekontrollen ("rutinen måste fortsätta köra så länge 2.2/2.3 används", "måste släppas i samma version som …"). För Keep: "Inget ändras."
- Håll varje fält kort: `what` och `proposal` högst ~30 ord, `why` och `if_accept` högst ~45 ord.
- För rena strukturrader med verdict Keep (rubriker, tillbaka-knappar, etiketter) räcker korta fält; du får generera dem med ett skript, men varje id ska finnas.
- Skriv aldrig om själva verdicten. Om du tycker att ett verdict är fel, skriv det i `why` med "Obs:" först.
- Validera med ett litet python-skript att alla id:n i dina kapitel finns i rows, att alla skärm-id:n finns i screens och att JSON:en är giltig. Avsluta med en rad: antal rows, antal screens, antal med shot.
