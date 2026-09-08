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
field) so the meaning is one tap away and the Drills Lines deck teaches the
phrase, not the paraphrase. The `usage` line says *when* and, where it helps,
*what happens if he asks a follow-up*.

## 6. Lingo explains like a friend, then hands her the line

`meaning` is plain English with an example where the concept needs one
("Brace is two goals by the same player. Three is a hat-trick. There is no word
for four."). `sayIt` (new, required) is a sentence she can say that uses the
term, so a definition becomes a tool. `heard` stays: where the word turns up.

## Validation summary

- quiz: `why`, `use`, `useType` required; caps above; superlative ban; every
  option ≤ 40; answer index valid; ids kebab-case and stable
- saythis: `lingo` optional but must point at a real Lingo id
- lingo: `sayIt` required, ≤ 100; `meaning` ≤ 170
- UK idiom banlist unchanged
