# Lingo: Overheard. The writing brief

Lingo used to test whether she could recall a definition. She never needs that. What she
needs is the reverse: he, the telly, the group chat or a pundit says something, and she has to
know what it meant, then have a line back. **Overheard** is that moment as a game: a chat
bubble with the line she hears, three options for what it means, then the friend's
explanation and the line she can say.

She is not a fan. She is being **briefed by a friend, not taught by a tutor**. If a line could
sit in a textbook, rewrite it.

## Where the words live

- `tools/myturn/lingo_src.py` holds every term (id, meaning, heard, sayIt, level). **Do not
  edit it.**
- `tools/myturn/lingo_overheard/<category>.py` holds the game fields, one `OVERHEARD` dict
  keyed by term id, **in the order the ids appear in `lingo_src.py`**. Every id in your
  category must appear. Touch no other file, and do not bump `VERSION` in `build_lingo.py`.

## Entry shape

```python
"offside": dict(
    overheard="Flag's up. He was offside by a mile, look at the replay.",
    speaker="him",
    gist="He was beyond the final defender for the pass",
    decoys=["He'd stepped off the side of the pitch", "He handled the ball before he shot"],
    when=["any"],
    moment="anytime",
    # aliases=["see it out"]   # optional, max 3, only when the natural phrasing is not the term text
),
```

## Register

British English, contractions, short sentences. No em dashes (use a full stop or a comma).
No exclamation pile-ups, no emoji. **They / we / this lot / the other lot, never a club
name.** No living player or manager, ever: the validator cannot see the present and a
current name goes stale the week he is sacked. Dry, observational, on her side. Never
sycophantic. Read `meaning`, `heard` and `sayIt` for each term first: `overheard` must sit
beside them, not repeat them.

## The fields

**`overheard`** (20 to 120 chars, aim under 100). The thing he, the telly, the chat or a
pundit actually says, using the term or its natural inflection ("parked the bus", "nutmegged
him" are fine). It must *not* define the term, and it must not be `sayIt` copied over:
`sayIt` is her line back, `overheard` is the line that made her need one. No wrapping quotes,
the bubble draws them. Ends with . ! ? or …, at most one `!`. Write the term the way the
`term` field spells it, minus a leading "the", or the validator will not find it ("top top
player", not "top, top player", or add an alias).

**`speaker`**: `him` | `telly` | `chat` | `pundit`. Aim for roughly 40% `him`, the rest
spread. `telly` is a commentator mid-match, `pundit` is the studio afterwards, `chat` is his
group chat or a mate's text.

**`gist`** (12 to 60 chars). The correct meaning as a fragment: capital first letter, no
full stop. It must not reuse any word of the term (the term is bolded in the bubble, so the
match would give it away). Write "final", not "last"; the validator bans *the last, only,
most, still, never, record, latest* in options because they go stale.

**`decoys`** (exactly 2, each 12 to 60 chars and within 20 characters of the gist's
length). Wrong meanings a non-fan would genuinely consider. **One is the literal misreading**
("a match worth six points", "the team coach blocking the exit"). **The other is a real
football idea that is not this one** ("added time", "a screamer"). Nothing absurd, so a
wrong tap still teaches something. Same formatting as the gist. Not the gist of a synonym
listed in the term's `seeAlso`. If both decoys start with the same word, the gist must too.

**`when`** (1 to 5 tags). When the word gets dealt. Start from the tag map below; you may
add a tag if the word truly belongs there, never remove one. `any` marks a word heard at any
match. Tags:

| tag | dealt when |
|---|---|
| `any` | every match; the fill pool |
| `derby` | his team's next game is against their rival |
| `cup` | next game is FA Cup or League Cup |
| `europe` | next game is Champions / Europa / Conference League |
| `title` | his team is top three |
| `top-four` | 4th to 7th |
| `relegation` | 16th or lower |
| `good-run` | three wins on the bounce |
| `bad-run` | no win in five |
| `new-manager` | the manager changed in the last week or so |
| `window` | the transfer window is open (summer, January) |
| `early-season` | August, September |
| `run-in` | April, May |
| `after-win` `after-loss` `after-draw` | within 36 hours of the result |
| `after-big-win` `after-heavy-loss` | margin of three or more |
| `after-clean-sheet` | nothing let in |

**`moment`**: `anytime` | `common` | `rare`. How often the moment for this word's `sayIt`
line actually arrives in the one match she watches with him. `anytime` waits for nothing on
the pitch (the squad, the table, the fixture list, the window, a player's reputation);
`common` arrives in most matches; `rare` needs something that usually does not happen (a
sending off, a shootout, a hat-trick, a cup round that comes once a year). **Judge the
`sayIt` line, not the term.** "Penalty! Who takes them for us?" is `rare` even though
penalties are an everyday word, because the line needs one to be given.

It exists because the round ends by handing her one line to use at the next match, and asks
once afterwards whether she said it. A line whose moment never came makes that a question
about something that was never possible. The app offers only `anytime` and `common` lines
(`LingoWeekendDeck.offer`); `rare` words are still dealt, still learnt, just never committed
to. Rule of thumb for the border: below about one match in three is `rare`, which is why a
clean sheet is `common` and an own goal is not.

## Golden examples

```python
"offside": dict(
    overheard="Flag's up. He was offside by a mile, look at the replay.", speaker="him",
    gist="He was beyond the final defender for the pass",
    decoys=["He'd stepped off the side of the pitch", "He handled the ball before he shot"],
    when=["any"]),
"var": dict(
    overheard="VAR is checking for a possible offside. Bear with us.", speaker="telly",
    gist="The video referee is looking at the replay",
    decoys=["The ref is checking his watch for added time", "The goal has already been ruled out"],
    when=["any"]),
"squeaky-bum-time": dict(
    overheard="Ten minutes left, we're 1-0 up. Squeaky bum time.", speaker="him",
    gist="Nervous final minutes protecting a narrow lead",
    decoys=["The bit where players start time-wasting", "Players sitting down because they're exhausted"],
    when=["run-in", "title", "relegation", "derby", "after-win"]),
"park-the-bus": dict(
    overheard="They've parked the bus since the goal. Ten men behind the ball.", speaker="pundit",
    gist="Everyone back defending, nobody trying to attack",
    decoys=["The team coach is blocking the stadium exit", "Substituting all your attackers at once"],
    when=["any", "after-draw", "after-clean-sheet"]),
"howler": dict(
    overheard="Absolute howler from the keeper. Straight through his hands.", speaker="chat",
    gist="A glaring, embarrassing mistake",
    decoys=["A save so good the crowd roared", "A shot hit so hard it screamed in"],
    when=["any", "after-loss", "after-heavy-loss"]),
"six-pointer": dict(
    overheard="Both of us down there. This is a proper six-pointer on Saturday.", speaker="him",
    gist="A match between two sides chasing the same place",
    decoys=["A match where a win is worth six points", "A game decided by six goals or more"],
    when=["title", "relegation", "run-in"]),
"we-go-again": dict(
    overheard="Rubbish today. Nothing to say. We go again Tuesday.", speaker="chat",
    gist="Bad result, forget it, on to the next match",
    decoys=["The match is being replayed after a draw", "Fans are heading off to another away trip"],
    when=["after-loss", "after-heavy-loss", "bad-run", "after-draw"]),
"deadline-day": dict(
    overheard="It's deadline day and the window shuts at eleven tonight. Stay with us.", speaker="telly",
    gist="The final day clubs can buy or sell players",
    decoys=["The final day to buy tickets for the season", "Cut-off for naming the squad for a cup"],
    when=["window"]),
```

## Tag map (starting point; add, never remove)

Every id also carries `any` unless marked *(no any)*.

**Rules.** premier-league early-season · points run-in, after-win, after-draw · the-table
run-in, title, top-four, relegation · goal-difference *(no any)* run-in, title, top-four,
relegation, after-big-win · relegation *(no any)* relegation, run-in · promotion *(no any)*
early-season, run-in · championship *(no any)* early-season, relegation · play-offs *(no
any)* early-season, run-in · offside, var, clear-and-obvious, foul, handball, penalty,
the-box, free-kick, corner, throw-in, yellow-card, red-card, added-time, substitution: any
only · ten-men after-loss · extra-time, penalty-shootout *(no any)* cup · two-legs, aggregate
*(no any)* europe, cup · the-bench cup · starting-eleven early-season · clean-sheet *(no
any)* after-clean-sheet, after-win, good-run · own-goal after-loss · brace, hat-trick *(no
any)* after-win, after-big-win · assist after-win · fixtures early-season · derby *(no any)*
derby · the-cups, fa-cup, league-cup *(no any)* cup · champions-league *(no any)* europe,
top-four, title · europa-league, conference-league *(no any)* europe, top-four ·
transfer-window *(no any)* window, early-season · deadline-day *(no any)* window · loan *(no
any)* window, early-season · sacked *(no any)* bad-run, new-manager, after-heavy-loss

**Tactics.** formation new-manager · back-four, centre-back after-clean-sheet · full-back,
holding-midfielder, box-to-box, number-ten, playmaker, winger, target-man, false-nine,
man-marking, overlap, through-ball, cutback, inverted-full-back, half-space: any only ·
wing-back new-manager · striker window · pressing, high-press good-run · low-block
after-clean-sheet · park-the-bus after-draw, after-clean-sheet · counter-attack europe ·
possession after-draw, after-loss · tiki-taka europe · long-ball relegation · zonal-marking
after-loss · set-piece derby, cup · xg after-draw, after-loss · game-management *(no any)*
after-win, after-clean-sheet, europe, derby · dark-arts *(no any)* derby, europe, after-loss ·
rotation *(no any)* cup, europe

**Match situations.** kick-off, half-time, full-time: any only · nil-nil *(no any)*
after-draw, after-clean-sheet · see-the-game-out *(no any)* after-win, after-clean-sheet,
derby, run-in · squeaky-bum-time *(no any)* run-in, title, relegation, derby, after-win ·
six-pointer *(no any)* title, relegation, run-in · top-four *(no any)* top-four, run-in ·
title-race *(no any)* title, run-in · relegation-battle *(no any)* relegation, run-in ·
sitter after-loss, after-draw · clinical-finish *(no any)* after-win, after-big-win, good-run
· screamer, top-bins after-win, after-big-win · worldie *(no any)* after-win, after-big-win ·
hit-the-woodwork after-draw, after-loss · row-z after-draw · howler, hospital-ball after-loss,
after-heavy-loss · hoof relegation · dive derby · early-bath derby, after-loss · handbags,
in-the-book derby · hooked *(no any)* after-loss, after-heavy-loss, bad-run · nutmeg, done-him
after-win, after-big-win · caught-napping after-loss, after-draw, after-heavy-loss ·
against-the-run-of-play *(no any)* after-win, after-loss, after-draw · smash-and-grab *(no
any)* after-win, after-loss, derby · game-of-two-halves *(no any)* after-win, after-loss,
after-draw · backs-to-the-wall *(no any)* after-clean-sheet, after-win, europe, derby ·
in-the-mixer after-draw, relegation · route-one relegation · on-the-break europe ·
dead-rubber *(no any)* run-in, europe · giant-killing *(no any)* cup · hairdryer *(no any)*
bad-run, new-manager, after-loss, after-heavy-loss · man-of-the-match after-win · top-drawer
after-win, after-big-win · second-ball cup, derby · unlucky after-loss, after-draw

**Culture.** fergie-time after-loss, title · the-gaffer new-manager, bad-run,
after-heavy-loss · the-boss new-manager · hard-man derby · class-act *(no any)* good-run,
after-win · top-top-player *(no any)* good-run, after-win, after-big-win, window ·
match-of-the-day after-win, after-loss · pundit after-loss · the-lads after-win, good-run ·
bottle-it *(no any)* title, run-in, bad-run, after-loss · banter derby, after-win · group-chat
derby, after-win, after-loss · season-ticket early-season · away-day cup, europe · the-away-end
cup, europe, derby · kop, the-lino, magic-sponge, wags: any only · terraces derby · chant
derby, cup · half-and-half-scarf *(no any)* derby, cup · plastic-fan derby, good-run ·
glory-hunter good-run, title · the-boot-room new-manager · the-invincibles *(no any)* title,
good-run · sack-race *(no any)* bad-run, new-manager, after-heavy-loss · new-manager-bounce
*(no any)* new-manager, good-run · silly-season *(no any)* window, early-season · here-we-go
*(no any)* window · football-twitter window, after-loss · fantasy-football early-season ·
we-go-again *(no any)* after-loss, after-heavy-loss, bad-run, after-draw · goal-of-the-month
after-win, after-big-win · the-magic-of-the-cup, the-third-round *(no any)* cup · wembley *(no
any)* cup, run-in

## Run before you return

```bash
python3 tools/myturn/build_lingo.py && python3 tools/myturn/validate_content.py --lingo-category <your category>
```

Zero errors for your category. Every error names the term id and the rule; fix it in your
file, not in the validator. Warnings are worth a look but do not block. Return: the file,
the term count, and any ids where you needed an alias and why.
