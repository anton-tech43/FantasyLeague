# Making Lingo a game

Written 2026-09-23, after Anton played the Overheard round and said it still is not fun:
"man får bara ett ord, och sen får man tre olika alternativ."

He is right, and the diagnosis matters more than the ten ideas underneath it.

## Why it does not feel like a game

The round is a well-written quiz. Seven cards, three options each, no clock, no cost, no arc.
Five things are missing, and they are the five things every game on the list below has.

**Nothing is at stake.** She cannot lose. A wrong tap costs nothing, so a right tap is worth
nothing either. Stakes do not have to mean punishment — Wordle's stake is six guesses — but
something has to be spendable.

**She only ever recognises.** Choosing one of three is the weakest form of knowing and the first
to decay. She never has to produce a word, so she never finds out whether she could.

**The seven cards are the same card.** No escalation, no shape, no last card that differs from the
first. A session has no ending, it just runs out.

**Being wrong teaches nothing.** The decoys are thrown away at the reveal. The single most
informative moment in the whole round — she thought it meant *that* — is the one we discard.

**Growth is invisible.** She cannot see that she understands more of what he says than she did a
month ago, which is the only reward this app can honestly offer.

## Ten apps, and the one thing each is worth stealing

1. **Wordle** — one puzzle a day, the same one for everybody, six guesses, and then it is over.
   Scarcity is the engine and the shareable grid is the distribution.
2. **NYT Connections** — grouping instead of choosing, four lives, and "one away" as feedback.
   Sorting is a harder and more interesting act than picking.
3. **Duolingo** — five exercise types inside one lesson, and the word bank: production with
   training wheels, so producing is possible before it is easy.
4. **Drops** — a hard five-minute cap, swipes rather than taps, and never more than a handful of
   words on screen. The limit is sold as a kindness.
5. **Elevate / Peak** — a different sixty-second game per skill, each with your own best to beat.
   Variety, not length.
6. **Anki** — what you got wrong comes back exactly when you are about to forget it.
7. **Sporcle** — name as many as you can before the clock stops, against a grid of blanks that
   shows you the shape of what you do not know.
8. **Kahoot** — the score is right *and* fast. The clock is half the point.
9. **Contexto / Semantle** — graded wrongness. Close is a result, not a failure.
10. **Fantasy Premier League** — you commit before kick-off and the real world scores you. No
    content team resolves it. The weekend does.

## Ten things we could build

### 1. Ninety seconds — from Kahoot and Sporcle

One clock for the whole round instead of none. A right answer adds three seconds, a wrong one
costs five, and the round ends when the clock does, not when the cards do. Score is how many
lines she cleared.

Identical content, completely different object. Best effort-to-effect ratio in this file: it is a
view change and a number, no new writing at all.

### 2. Warm, warmer — from Contexto

Every decoy gets marked near or far. Tap a far one and it says so. Tap a near one and it answers
back: *close — that is what it means when a keeper does it.* The wrong answers stop being padding
and become the second half of the lesson.

One field per decoy in the content pipeline, one branch at the reveal.

### 3. Praise or slaughter — from Connections

Eight phrases, two columns, four mistakes and you are out. Is he praising him or burying him?
That is the only question that actually matters in a living room, and the current format never
asks it. It also sidesteps the problem §8 keeps catching, because there is no sentence left to
restate the definition.

### 4. Finish his sentence — from Duolingo's word bank

The line appears with the last three words missing and six words underneath to tap in order. The
same content read backwards. This is where production enters, and it is the first mode that would
be genuinely hard.

### 5. Two seconds — from Kahoot

He says the line, the replies appear, a bar drains. A slow right answer still counts but is marked
*you had to think about it*. This models the real constraint better than anything else here: a
reply that lands ten seconds late is the wrong reply.

### 6. The commentary run — from Elevate

Sixty seconds of commentary scrolling past. Tap the jargon as it goes by. Three misses ends it.
Repeatable, scored against yourself, and the only mode that trains speed of noticing rather than
depth of knowing.

### 7. Called it — from Fantasy Premier League

**The strongest idea in the file, and the only one no other app could build.**

Before kick-off she picks three lines she thinks will be earned this weekend. After the whistle
the app checks the match and marks them: there was a goal from a corner, there was a red, there
was a VAR check, they did keep a clean sheet.

We already have the feed. `match-watcher` polls `/fixtures/events` every minute during a match and
currently throws away everything that is not a Goal — cards, VAR and substitutions arrive in the
same payload and are dropped on the floor. Resolving this costs no extra API call.

This is the consequence loop the council said was missing, rebuilt so it survives Anton's
objection to the first version. That one could hand her *"that's a red, he's off"* for a match
where nobody was sent off. This one cannot: she chooses, the fixture resolves it, and a line that
never came up simply does not score.

### 8. The ones that got away — from Anki

The store already keeps three buckets. Re-deal a missed word after three rounds and again after
ten. No new content, no new screen, and it is what would finally make "learning" a state rather
than a label.

### 9. Saturday's line — from Wordle

One line a day, the same for everyone, taken from a real match. One shot at it. The result is a
small card worth sending — and the person she sends it to is him. That is the app's whole
emotional engine and nothing in My Turn currently touches it.

Needs a daily supply, which is a routine, which is why it is not first.

### 10. Who said that — from Drops

The same sentence from three mouths: the co-commentator, the bloke behind you at the ground, the
manager at the press conference. Swipe to the one who would say it. Register is what separates
someone who sounds like she belongs from someone who sounds like she has read a glossary.

## What I would build, in order

**1, 2 and 7.** One costs nothing and changes the feel of every card that already exists. Two
turns the most informative moment in the round into teaching. Seven is the one that makes Lingo
matter on Saturday, and the feed it needs is already being polled and discarded.

Then **8**, because it is nearly free, and **4**, because at some point she has to produce a word
rather than recognise one.

**3, 6, 9 and 10 need content we do not have** — tone labels, a scrolling feed, a daily supply,
speaker variants. They are good, and they are second.

## What I would refuse

Daily streaks, hearts that lock her out, leaderboards, push reminders. The store's own header says
it: *no streaks, no daily goals, no reminders — the user did not choose this hobby, and obligation
mechanics get the app deleted.*

Every mode above scores a session. None of them punishes an absence. That is the line, and it is
not the same line as "no scoring" — `PackProgress.best` has existed since the first quiz.
