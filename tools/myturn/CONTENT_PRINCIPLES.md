# My Turn — content principles (2026-09-08, after Anton's review of the first batch)

The first batch read like a history exam. These rules are what changed, and the
validator enforces the mechanical half of them.

## 1. A fact is not a question. Every question carries its use.

Each quiz question has four parts and all four are required:

| field | job | cap |
|---|---|---|
| `explanation` | the fact, **with the context a non-fan lacks** — who this person is, why this era matters | 170 |
| `why` | why she would ever need this, in one line | 110 |
| `use` | the line: something to say, something to ask him, or something to impress with | 140 |
| `useType` | `say` / `ask` / `impress` — the app labels the line with it | — |

"Herbert Chapman" alone is a name. "Herbert Chapman, the 1930s manager who
turned Arsenal into a big club" is context. "Ask him if he knows why the Tube
station is called Arsenal" is a use. All three, every time.

If there is no honest answer to *when does she say this, and to whom?* — cut the
question. "Who scored at Anfield in 1989" went for exactly that reason.

## 2. Prefer the useful and fun over the encyclopaedic

Total league titles beats who managed one of them. The origin of a rivalry
beats the year of a cup final. A chant, a nickname's story, why the shirts are
the colour they are — these come up on a sofa. Goalscorers in finals do not,
unless the goal is the story everyone still tells.

## 3. "Settled history" was not settled

The first batch said Arsenal's *only* Champions League final was 2006. They
played the 2026 final. The writer's knowledge has a cut-off and the validator
cannot see the present, so **superlatives tied to now are banned outright**:
*only, last, most, record, latest, newest, all-time, more than any other,
never, still*. Write the dated fact instead: "Arsenal reached the Champions
League final in 2006, in Paris" cannot go stale. `validate_content.py` fails the
build on any of those words in a question, explanation, why or use.

Numbers are allowed when dated ("five substitutions since 2022"). Undated
numbers about the present ("five allowed per game") are not.

## 4. The present comes from data, not from memory

Questions about the manager, the key players and last season's finish are built
in the app from `team_pages` (ones_to_know, manager, basics glance) and the
`teams` table, so they update themselves. See `LiveClubPack` in the app. Static
files never name a current manager or squad member.

## 5. Say This lines are football sayings, not sentences

"Well, that's annoying" is a sentence. "That's a howler" is a saying — the thing
fans actually say, that marks her as someone who watches. Every line should
lean on a real phrase where one exists, and link to its Lingo entry (`lingo`
field) so the meaning is one tap away and the Overheard reveal can point back at
the line, so the phrase is taught, not the paraphrase. The `usage` line says *when* and, where it helps,
*what happens if he asks a follow-up*.

## 6. Lingo explains like a friend, then hands her the line

`meaning` is plain English with an example where the concept needs one
("Brace is two goals by the same player. Three is a hat-trick. There is no word
for four."). `sayIt` is a sentence she can say that uses the term, so a definition
becomes a tool. `heard` stays: where the word turns up.

## 7. Lingo is played as Overheard, not recalled as flashcards (2026-09-21)

The flashcard deck tested whether she could recall a definition, which she never
needs to do. What she needs is the reverse: he says a thing, she knows what it
meant and has a line back. So every term also carries the game:

| field | job | cap |
|---|---|---|
| `overheard` | the line she hears, using the term, not defining it | 120 |
| `speaker` | `him` / `telly` / `chat` / `pundit` | |
| `gist` | the right option, a fragment, no word of the term in it | 60 |
| `decoy` | the wrong option that **ships**: the one a non-fan would genuinely consider | 60 |
| `spare` | the second wrong option, written and reviewed, **never shipped** | 60 |
| `when` | the match contexts the word is dealt in (derby, cup, relegation, after-loss ...) | 1 to 5 tags |
| `moment` | how often the `sayIt` line's moment arrives: `anytime` / `common` / `rare` | one of three |

The content lives in `tools/myturn/lingo_overheard/<category>.py`, one file per
category; the brief with the golden examples and the tag map is
`tools/myturn/LINGO_OVERHEARD_BRIEF.md`. `build_lingo.py` merges it into
`lingo.json` and records `overheardTerm`, the exact substring the app bolds.

**Two wrong options are written; one is played (2026-09-23).** A round shows two
options, so only `decoy` reaches the phone. `spare` stays in the source, held to
the same rules, so going back to three options is a one-line change and not a
writing job — `build_lingo.py` fails on a term that has lost one. Which of the
two survives is **authored**: read both and keep the one a reasonable non-fan,
having read the line, would genuinely consider. Do not pick by length. The
closer one is free when both are equally believable, but a tidy option nobody
would tap is a fifty-fifty with extra steps, which is exactly what §8 is about.
With one wrong option there is no odd one out, so every surface that separates
the two is the whole card: see §8b.

Overheard is speech, so it gets only the dated-fact half of the superlative ban
("their only final", "record", "latest"); "still 1-0" and "never a penalty" are
how people talk. The gist and both wrong options are definitions and get the full ban. Nothing
in any of the five fields names a club or a living person: the app cannot see
the present and a name goes stale the week he is sacked.

`moment` bands the `sayIt` line, not the word. The round ends by handing her one
line to use at the next match and asks once afterwards whether she said it, so a
line waiting for a sending off ("That's a red. He's off.") commits her to a
moment that arrives in about one league match in eight, and then asks about
something that was never possible. `anytime` waits for nothing on the pitch,
`common` arrives in most matches, `rare` needs something that usually does not;
the border sits at about one match in three, which is why a clean sheet is
`common` and an own goal is `rare`. Nothing reads the band at runtime since
Called it replaced that loop, and the field is kept anyway: it is a fact about
the line that is cheap to write while writing it and expensive to reconstruct
later.

The deck itself ("This weekend's words") is built on the phone from the cached
team page: the next fixture, the last result, the table, the rival. Static
content only carries the `when` tags; which tags are live is decided in
`ios/GoalDigger/Services/LingoDeck.swift` from data, never from memory.

**Naming a real player (2026-09-23).** An entry may also carry a `player`
variant: the same card with one `{ours|theirs}.{keeper|defender|midfielder|forward}`
slot, filled on the phone from the fixture's squads, so up to two of the seven
cards in a round name a real man. A runtime-filled slot is the sanctioned form
of §4's escape hatch — the same trick `LiveClubPack.positionUse` already plays
in Quiz — while a literal name typed into the JSON stays banned, and inside a
variant the capitalised-word check is an error rather than a warning, because a
variant is exactly where a writer is tempted to hand-write one to see how it
looks. Slots never go in `gist`, `decoy` or `spare`: a decoy is a *wrong* meaning, so a
templated decoy would assert something false about a named real person. Two
rules govern what a variant may say, and neither is checkable by script: it may
say what he **is**, never what he **did** or that he **will play**; and it may
only say what our data actually holds about him — position, club, squad
membership, shirt number. No form, quality, reputation or fitness, because we
have none of it, not even an injury column. Questions, preferences and position
facts are the three safe shapes. The rules, the eight slots, the rendered-length
arithmetic and five worked examples are in `LINGO_OVERHEARD_BRIEF.md`;
`validate_overheard.py` enforces the mechanical half and `build_lingo.py` fails
on an unknown slot.

## 8. A question she can answer without knowing the word is not a question (2026-09-23)

The first Overheard batch passed every mechanical rule and was still too easy. The test
that found it: blank the phrase out of the `overheard` line and have someone who has
never seen the content pick from the three options. They scored 158 of 158, and on 94
items the reason they gave was that **the sentence restates the definition**.

Two rules came out of it, and both are now how the content is written.

**The line creates the need for the word. It never explains it.** "They've parked the bus
since the goal. Ten men behind the ball." answers itself; the second sentence is the right
option in his words. "They've parked the bus since that goal. Forty minutes of this left."
gives the situation and his mood, and nothing about the shape. If a clause paraphrases the
meaning, cut it.

**Every option must be believable to someone who does not know the word.** The original
brief asked for a literal misreading, and in practice that became a joke nobody would pick
("The team coach is blocking the stadium exit"), which turns three options into two and a
fifty-fifty floor. The real test is not literal against football: it is whether a reasonable
non-fan, having read the line, would genuinely consider the option. A literal reading is
fine when it is the one her ear actually reaches for ("throwing in the towel" for a
throw-in). It is dead weight when nobody would pick it.

Some words cannot be hidden, because the English gives them away (`added-time`,
`own-goal`, `two-legs`, `loan`, `season-ticket`). For those the line stops trying and the
difficulty moves into the options: make both wrong answers equally consistent with the line,
so knowing the phrase is the only thing that separates them.

After the rewrite, "the sentence restates the definition" fell from 94 items to a handful.
Re-run the blind test after any batch of new terms; the raw score is not the number to read,
because a solver who knows football answers from knowledge. The number that matters is how
often the line itself does the work.

That was true at three options and it is doubly true at two: the floor is now 50%, so a raw
score of 80% and a raw score of 60% are the same finding read through different noise. Count
the reasons, never the score.

**`basic`.** A word an English speaker simply decodes from its parts (`kick-off`,
`half-time`, `own-goal`, `starting-eleven`) is vocabulary, not lingo. Those carry
`basic=True`: they stay in the word list and in search, and are never dealt in a round.
Without it the first round on a fresh install asked a grown woman what kick-off means, at
the moment she was deciding whether to keep the app.

## 8b. The options-only test: show the two options and hide the line (2026-09-23)

§8 protects the line. At two options the second half of §8 — "every option must be believable"
— stops being a style note and becomes the game, because there is no third option to hide a
dead decoy behind. So it gets its own test, and it is the one to run on a two-option deck.

**Show a solver the two options with the `overheard` line removed, and ask which is the
football meaning.** Across the set the gist should be chosen 40-60% of the time: at the floor
the card is a coin flip, which is what it should be before she reads the line. Any single card
that three solvers agree on without the line has a dead decoy — either absurd, or so obviously
the odd register that the shape answers it — and that card is rewritten, not re-scored.

`validate_overheard.py` mechanises the part of this a script can see. The band is a floor of
10 characters plus a quarter of the gist's length. Exactly one of the two options opening with
a/an/the is an error. And across the whole set the gist must not be the longer, wordier,
comma-ier or longer-worded option more than 60% of the time (aim 45-55%), counted only over
the cards where the two differ, with ties reported separately. A solver that reads no football
and taps the option with a comma, otherwise avoiding the article, scored 62.7% before that
pass and 50.6% after. Run `python3 tools/myturn/validate_overheard.py` for its self-check.

What a script cannot see is whether the surviving decoy is *believed*, which is why §8b is a
human gate like §8.

## Validation summary

- quiz: `why`, `use`, `useType` required; caps above; superlative ban; every
  option ≤ 40; answer index valid; ids kebab-case and stable
- saythis: `lingo` optional but must point at a real Lingo id
- lingo: `sayIt` required, <= 100; `meaning` <= 170; Overheard fields required
  (see `validate_overheard.py`): caps above, term present in `overheard`, a
  `decoy` that is one non-empty string and a `spare` beside it, decoy length
  band of 10 chars or a quarter of the gist, an error when exactly one of the
  two options opens with a/an/the, no club names, no defining phrasing, `when`
  tags from the enum with at least 5 terms per tag and 60 carrying `any`
- UK idiom banlist unchanged
- lingo player variants: slot from the closed eight; exactly one distinct slot per
  variant, equal to the declared one and present in `overheard`; caps and floors
  measured on the rendered line (22-character name for the caps, 3 for the floor),
  with a tighter 90 on a variant's `overheard`; every plain-`overheard` rule re-run
  against a defanged copy; the term still matched outside the slot; the bubble-leak
  check against the inherited gist; no duplicate of the plain line or `sayIt`; none
  on a `basic` term; at most two per term and their sides must differ; floors of 30
  terms, 3 per slot and 20 carrying `any`
- lingo Overheard: `basic` must be a bool and at most 15 terms may carry it; `moment`
  required and one of `anytime` / `common` / `rare`, with at least 40 dealt terms in each
  of `anytime` and `common` (the `basic` ones do not count, because they are never dealt
  and so can never be offered); set-level skew over the two shipped options held to
  40-60% (warn outside 45-55%) on character length, word count, comma count and
  longest word, counted over the cards where they differ with ties reported apart;
  the blind test (§8) and the options-only test (§8b) are human gates, not scripts.
  `python3 tools/myturn/validate_overheard.py` runs that file's own self-check.
