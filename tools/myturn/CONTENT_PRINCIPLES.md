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
| `decoys` | two wrong options: the literal misreading and a neighbouring real idea, same length band | 2 x 60 |
| `when` | the match contexts the word is dealt in (derby, cup, relegation, after-loss ...) | 1 to 5 tags |

The content lives in `tools/myturn/lingo_overheard/<category>.py`, one file per
category; the brief with the golden examples and the tag map is
`tools/myturn/LINGO_OVERHEARD_BRIEF.md`. `build_lingo.py` merges it into
`lingo.json` and records `overheardTerm`, the exact substring the app bolds.

Overheard is speech, so it gets only the dated-fact half of the superlative ban
("their only final", "record", "latest"); "still 1-0" and "never a penalty" are
how people talk. Gist and decoys are definitions and get the full ban. Nothing
in any of the five fields names a club or a living person: the app cannot see
the present and a name goes stale the week he is sacked.

The deck itself ("This weekend's words") is built on the phone from the cached
team page: the next fixture, the last result, the table, the rival. Static
content only carries the `when` tags; which tags are live is decided in
`ios/GoalDigger/Services/LingoDeck.swift` from data, never from memory.

## Validation summary

- quiz: `why`, `use`, `useType` required; caps above; superlative ban; every
  option ≤ 40; answer index valid; ids kebab-case and stable
- saythis: `lingo` optional but must point at a real Lingo id
- lingo: `sayIt` required, <= 100; `meaning` <= 170; Overheard fields required
  (see `validate_overheard.py`): caps above, term present in `overheard`, decoy
  length band 20, no club names, no defining phrasing, `when` tags from the enum
  with at least 5 terms per tag and 60 carrying `any`
- UK idiom banlist unchanged
