# My Turn "does it make sense" review: brief

You are reviewing what a girlfriend sees in the GoalDigger app before her boyfriend's
team plays. She knows almost nothing about football. Every line is read by HER, about
HIM and his club ("his club" = the club in the dump's `team` field).

For each club you are given, read its dump: `dumps/myturn-audit-<club>-now.json`.
The dump holds:
- `context`: the fixture.
- `opponentPack`: "Get to know <opponent>", 2 options each.
- `words`: the 7-word round. Each has `overheard`, the line shown; `gist`/`decoy`, the right and wrong meanings; `sayIt`, the line she says back; and `named`, a real player filled in.
- `slip`: the 7 sayings she can save. They are NOT pushed; she reads them in the app.
- `clubPack`, `squadPack`, `leaguePack`: the quiz packs.

Also read that club's static pack in `ios/GoalDigger/Resources/MyTurn/quiz.json`. Its pack id is `club-<club>`, with `_` replaced by `-`.

Grade EVERY item. Flag one if any rule below fails, with a short quote and which rule.
These rules come from the product owner's own criticism of earlier rounds:

1. **Asks what the card just said.** For example, the card says "four assists this season" and the line asks "Is he the one making their goals?". The line must show she knows the fact, then ask the NEXT thing.
2. **Not about this game.** Before a game, the 7 words and sayings must fit THIS fixture or any game. Calendar words like promotion or the transfer window, or "a goal in Europe" in a league game, are flags.
3. **Names a player with no reason.** A named opponent player on a generic rule ("If X gets a yellow card…") is a flag, unless a real fact about him backs it.
4. **Unclear idiom.** "Jury's out", "no time for it". She won't know what these mean.
5. **Vague or useless fact.** "14th, 47 points" with no meaning attached.
6. **Impossible to guess and teaches nothing.** For example, three managers she has never heard of.
7. **Not true for this club.** A "relegation scrap" line for a top-four side; "we're through to the next round" in a league game; a line about a derby when it isn't one.
8. **Wrong voice.** She says the lines TO him, in her own words. The narration is about him. A line that sounds like he is talking to her, or that talks down to her, is a flag.
9. **The answer is given away, or a wrong answer is also right.** A goalkeeper photo with "Goalkeeper" as an option; two options both true.
10. **The grammar or the name is broken**: an abbreviated name ("B. Saka") where a full name belongs, a doubled word, or a sentence that doesn't read.

Do NOT check numbers against the internet; a separate fact checker does that. Do flag anything that
reads as factually suspicious ("Liverpool's manager is X" if X seems implausible), marked SUSPICIOUS.

Output per club: a table of flagged items only, with the columns
`section | id | quote | rule # | why | severity (wrong / weak)`.
Then one line: how many items you checked and how many passed.
Be strict, but quote exactly. A flag without a quote does not count.
