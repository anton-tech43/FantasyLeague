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
    overheard="That's never offside. I don't care what the replay says.",
    speaker="him",
    gist="He was beyond the final defender for the pass",
    decoy="He got in the keeper's way at the near post",        # the one that ships
    spare="The ball had already gone out for a goal kick",      # written, reviewed, never shipped
    when=["any"],
    moment="common",
    # aliases=["see it out"]   # optional, max 3, only when the natural phrasing is not the term text
    # player=dict(...)         # optional, see "Naming a real player" below
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

**`decoy`** and **`spare`** (both 12 to 60 chars). Write two wrong meanings a non-fan would
genuinely consider. **One is the literal misreading** ("a match worth six points", "the team
coach blocking the exit"). **The other is a real football idea that is not this one** ("added
time", "a screamer"). Nothing absurd, so a wrong tap still teaches something. Same formatting
as the gist. Neither may be the gist of a synonym listed in the term's `seeAlso`.

Then choose, by hand, which of the two goes in `decoy`: a round shows **two** options and only
`decoy` reaches the phone. Keep the one a reasonable non-fan, *having read the line*, would
genuinely consider. The other stays as `spare`, held to the same rules, so a round can go back
to three options without a writing pass — `build_lingo.py` fails on a term that lost its spare.
Never choose by length.

With one wrong option there is no odd one out, so anything that separates the two *shapes*
answers the card:

- **`decoy` must sit within 10 characters of the gist, or a quarter of its length, whichever is
  larger.** 23-character and 52-character gists cannot share one absolute band.
- **Either both options open with a/an/the, or neither does.** An article against a number or a
  gerund is answerable at word one, and it was right 76% of the time before this rule existed.
- **Commas are the one to watch.** A gist is often a two-part truth ("Three for a win, one for a
  draw") and a decoy a flat assertion, which put the only comma in the gist on 90.6% of the cards
  where they differed. Either give the decoy the same two-part shape or write the gist as one
  clause. Across the set the gist may carry the extra comma on no more than 60% of the cards where
  the two differ, and the same holds for length, word count and longest word.

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
    overheard="That's never offside. I don't care what the replay says.", speaker="him",
    gist="He was beyond the final defender for the pass",
    decoy="He got in the keeper's way at the near post",
    spare="The ball had already gone out for a goal kick",
    when=["any"]),
"var": dict(
    overheard="VAR has been the story of this season, for better or worse.", speaker="telly",
    gist="The video referee is looking at the replay",
    decoy="A panel that reviews decisions after the match",
    spare="The screen in the ground showing the decision",
    when=["any"]),
"squeaky-bum-time": dict(
    overheard="Squeaky bum time now. Don't talk to me.", speaker="him",
    gist="The jitters as the clock winds down",
    decoy="The bit where players start time-wasting",
    spare="The nervous wait while a goal is checked",
    when=["derby", "title", "relegation", "run-in", "after-win"]),
"park-the-bus": dict(
    overheard="They've parked the bus since that goal. Forty minutes of this left.", speaker="pundit",
    gist="Everyone back defending, nobody trying to attack",
    decoy="Wasting time at every throw-in and free kick",
    spare="Bringing defenders on to hang on to a lead",
    when=["any", "after-draw", "after-clean-sheet", "opp-clean-sheets", "favourites"]),
"howler": dict(
    overheard="Absolute howler from the keeper. Have you seen it?", speaker="chat",
    gist="A glaring, embarrassing mistake",
    decoy="A save so good the crowd roared",
    spare="A furious shout at his own defenders",
    when=["any", "after-loss", "after-heavy-loss", "h2h-they-win"]),
"six-pointer": dict(
    overheard="Six-pointer on Saturday. Don't be planning anything.", speaker="him",
    gist="A match between two sides chasing the same place",
    decoy="A match where a win is worth six points",
    spare="A game worth double because it is a derby",
    when=["title", "relegation", "run-in", "h2h-we-win"]),
"we-go-again": dict(
    overheard="We go again Tuesday. Kick-off's at eight, apparently.", speaker="chat",
    gist="Bad result forgotten and on to the next game",
    decoy="Back for a replay, the first one was drawn",
    spare="Fans are heading off to another away trip",
    when=["bad-run", "after-loss", "after-draw", "after-heavy-loss", "opp-bad-form"]),
"deadline-day": dict(
    overheard="Deadline day, and we're outside the ground with nothing to tell you.", speaker="telly",
    gist="The final day for doing deals",
    decoy="The final day to buy season tickets",
    spare="Cut-off for naming the squad for a cup",
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

## Naming a real player: the `player` variant

Up to two of the seven cards in a round can name a real player from the actual fixture. You
write a **template**; the phone fills the name from live squad data at the moment the round is
dealt. This is the sanctioned form of `CONTENT_PRINCIPLES.md` §4's escape hatch. A literal name
typed into one of these files is still banned, and the validator now treats it as an error
rather than a warning inside a variant.

### The rule that matters most, and the one no script can check

> **A templated line may only say what our data actually says about him: his position, his
> club, that he is in the squad, and his shirt number. Nothing else.**
>
> **And it may say what he *is*, never what he *did* or that he *will play*.**

The second rule is necessary and not sufficient. Look at the plain line for `set-piece`:

> "They're strong from set pieces. Watch the corners."

It reads perfectly. It is also completely groundless. Nothing in any feed we hold carries
style-of-play data: API-Football has no set-piece, pressing or counter-attacking numbers at all,
`teams/statistics` has not been fetched since April and would not carry it anyway, and the site
that does have it forbids reuse without a licence. Written about a team it is harmless colour.
Written about a **named man** it is the app inventing a fact about a real person, and the moment
she repeats it back to him it collapses.

So these are all wrong, even though every one of them is dispositional rather than eventive:

- "{theirs.defender} wins every header." — no aerial data.
- "{ours.forward} is due a goal." — no form data.
- "{theirs.midfielder} is the best they've got." — no quality data.
- "{ours.keeper} is fit again." — there is no injury or suspension column anywhere.
- "{ours.midfielder} is getting hooked here." — reports something that did not happen.
- "{theirs.forward} will run us ragged today." — predicts he plays.

There is no injury or suspension data, and `minutes > 0` only proves he played at some point, so
**every line must also survive the man sitting on the bench.** Naming a suspended, injured or
sold player is unavoidable; that is precisely why nothing may depend on him being on the pitch.

Neither the validator nor the app can see any of this. It is a human gate, exactly like the
blind test in §8.

**Three shapes are always safe.** Prefer them in this order:

1. **A question.** It cannot be wrong, and it is on voice for both of them. "Is {ours.defender}
   a centre-back, or does he play out wide?"
2. **A preference or a hypothetical.** It is a claim about the speaker, not the player. "I'd
   play {ours.defender} at centre-back and worry about the rest later."
3. **A position or squad fact.** It is what the data says. "Champions League football is back,
   and {theirs.forward} is up front for them."

Aim for the player being the **occasion** for the word rather than the **subject** of a claim.

### The eight slots

```
{ours.keeper}   {ours.defender}   {ours.midfielder}   {ours.forward}
{theirs.keeper} {theirs.defender} {theirs.midfielder} {theirs.forward}
```

A closed enum; anything else fails the build. **There is no `winger` slot, and that is
deliberate.** The only trustworthy position vocabulary has four buckets, so a `forward` line
must be true of a winger and a striker alike. Write "I'm not sure what {theirs.forward} is",
not "{theirs.forward} is their target man" — the second is false the week the slot resolves to a
5'7" wide player. Where the distinction matters, put it in the question: "Does {theirs.forward}
play as a winger, or through the middle?"

The token is substituted by literal string match, so write it **character for character in
lowercase, with no space inside the braces**. `{Ours.Forward}` and `{ ours.forward }` are not
slots, and a variant whose `overheard` carries no token at all fails the build, because the app
would skip it and silently waste one of only two named cards in the round. Note also that a
curated player only resolves through a closed position table (goalkeeper/keeper;
defender/centre-back/center-back/full-back/fullback/wing-back/wingback;
midfielder/midfield; attacker/forward/striker/winger) — anything outside it makes that player
unusable, which is another reason the line must read fine when no name arrives.

### Entry shape

```python
"target-man": dict(
    overheard="You need a target man in this league. They've not got one.",
    speaker="pundit", gist="A big forward the ball gets launched at",
    decoy="A defender told to follow one player about",
    spare="A forward who chases everything down",
    when=["any"], moment="anytime",
    player=dict(
        slot="theirs.forward",
        overheard="Every side needs a target man. I'm not sure what {theirs.forward} is.",
        sayIt='"Is {theirs.forward} a target man, or is he one of the quick ones?"',
    ),
),
```

`slot`, `overheard`, `sayIt` and nothing else. `speaker`, `gist`, `decoy`, `spare`, `when`, `moment`
and `basic` are **inherited and never overridable**, so the variant must sound like the same
person saying the same kind of thing. At most two variants per term, and if there are two their
sides must differ (pass a list). A variant on a `basic` term is an error, because those are
never dealt.

### Slots go in `overheard` and `sayIt` only, never in `gist`, `decoy` or `spare`

Three reasons, in order of severity. A decoy is a **wrong** meaning, so a templated decoy asserts
something false about a named real person. A single option carrying a proper noun when the other
does not is a one-tap giveaway that no existing check can see. And the options are
length-banded and uniqueness-checked at build time, which cannot be done on text the validator
never sees. The upshot is that the options stay answerable by someone who has never heard
of the player.

### Length

Caps are measured on the **rendered** line with a 22-character name, which is the longest the
resolver will print, and the floor is measured with a 3-character one so a fat placeholder cannot
hide a line that is too short. A variant's `overheard` gets a tighter **90** (the plain cap is
120) so a long name cannot push the bubble to four lines on a small phone. `sayIt` keeps its 100.
In practice: keep the template under about 75 characters.

### Five worked examples

```python
# 1. A position fact and nothing else. True whether he starts, is benched or was sold.
"champions-league": player=dict(
    slot="theirs.forward",
    overheard="Champions League football is back, and {theirs.forward} is up front for them.",
    sayIt='"Champions League, and {theirs.forward} up front. Should I be worried?"'),

# 2. A question. It cannot be wrong, and it hands her the thing she actually wants to ask.
"centre-back": player=dict(
    slot="ours.defender",
    overheard="I'd play {ours.defender} at centre-back and worry about the rest later.",
    sayIt='"Is {ours.defender} a centre-back, or does he play out wide?"'),

# 3. The uncertainty is the joke. This is how a forward line survives the winger/striker gap.
"target-man": player=dict(
    slot="theirs.forward",
    overheard="Every side needs a target man. I'm not sure what {theirs.forward} is.",
    sayIt='"Is {theirs.forward} a target man, or is he one of the quick ones?"'),

# 4. He is the occasion, not the subject. Nothing at all is claimed about him.
"the-gaffer": player=dict(
    slot="ours.keeper",
    overheard="You'd have to ask the gaffer about {ours.keeper}. I've got no idea.",
    sayIt='"What\'s the gaffer like with {ours.keeper}? Do you ever hear?"'),

# 5. A rule consequence inside a conditional. The rule is data; the conditional survives the bench.
"yellow-card": player=dict(
    slot="theirs.defender",
    overheard="If {theirs.defender} picks up a yellow card early, he's in bother all afternoon.",
    sayIt='"If {theirs.defender} gets a yellow card, does he have to be careful after?"'),
```

### Re-run the blind test

A named line is unusually prone to answering itself, because a name invites the writer to explain
what the man does: "he's their target man, everything comes through him" is the gist in his
words. Substitute a plausible name, blank the phrase, and check the options are still
separable. Four lines in the first batch failed this and were rewritten.

## The options-only test, before you call a card done

The blind test hides the term and keeps the line. The options-only test hides the **line** and
keeps the two options, and it is the one a two-option round needs: read `gist` and `decoy` with
no context and ask which is the football meaning. If the answer is obvious, the decoy is dead
and the card is a coin flip dressed up — rewrite it, do not re-score it. Across a batch the gist
should win 40-60% of the time. `CONTENT_PRINCIPLES.md` §8b is the long version.

## Run before you return

```bash
python3 tools/myturn/build_lingo.py && python3 tools/myturn/validate_content.py --lingo-category <your category>
python3 tools/myturn/validate_overheard.py   # the rules' own self-check
```

Zero errors for your category. Every error names the term id and the rule; fix it in your
file, not in the validator. Warnings are worth a look but do not block. Return: the file,
the term count, and any ids where you needed an alias and why.
