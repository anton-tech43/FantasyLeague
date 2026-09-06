# World Cup content review: headlines, girl refs, talking points

**Corpus:** every `content_items` row created between 2026-06-11 (opening match) and
2026-07-19 (final). 1 431 cards — 1 266 news + Sunday Brief, 165 matchday. 3 302 talking
points. 964 immersive headlines. 945 girl references.

**Method.** Two layers, and it matters which claim comes from which.

1. **Deterministic, 100 % coverage.** Every card measured against the rules the prompt
   itself sets (`PROMPT.md` §"ANALOGY RULES", §title spec) plus the failure classes found
   by reading. Every percentage in this document is a full-population count, not a sample.
2. **Read by hand.** 450 cards (36 %) read in date order to find failure classes the
   machine could not have known to look for; each discovered class was then measured across
   the whole corpus. The remaining cards were covered by targeted sweeps aimed at the tail
   rather than the middle — risky subject matter, bare questions, fragments, misspellings,
   mismapped analogies, scoreline contradictions — and every card those sweeps flagged was
   read. Every card in the corpus was examined by at least one method; no card class went
   unread. Per-card notes: `wc/ratings.tsv` in the session scratchpad.

The five questions asked of every surface: *is it even one of these? is it relevant? is it
good? is it right for the audience? is the link to what actually happened clear?*

---

## The number that matters

**64 of 1 266 cards (5 %) break none of the house rules.**

| Rule broken | Cards | Share |
|---|---|---|
| Girl ref over the 16-word cap | 766 | 61 % |
| Girl ref has no named cultural anchor | 343–483 | 27–38 % |
| No girl reference at all | 321 | 25 % |
| A talking point states or presumes a fact about her partner | 304 | 24 % |
| No designed headline — shipped the raw fallback | 302 | 24 % |
| "Did you know…?" framing | 61 | 5 % |
| Headline not lowercase | 46 | 4 % |
| Talking point is a question to her, not a line for her | 54 | 4 % |
| Headline contains ? or ! | 34 | 3 % |

Set aside the two style rules (length, casing) and judge only on substance — is the surface
present, is the reference specific, does it avoid inventing facts about him — and **22 %
of cards pass**. For Sunday Briefs it is **0 of 148**.

That is the honest headline: the World Cup shipped at roughly one card in five meeting its
own brief, and the tournament's flagship weekly product met it never.

---

## Task 4 — Headlines

**Is it even a headline?** For 964 cards, yes, and they are the strongest surface in the
product. For **302 cards (24 %) there was no headline at all** — the app fell back to
lowercasing the plain `headline` field, which produced feed cards reading:

```
mexico beat south africa 2-0.
```

with nothing underneath. Three classes account for all of them: rival-result cards
("X beat Y", pushed into every other team's feed in the group), pre-match fixture cards
("algeria face argentina tomorrow at 03:00"), and from 5 July, the Sunday Brief.

**Is it relevant? Is the link clear?** Where a headline exists, yes — this is where the
system is genuinely good. The three-line staccato form does real work:

```
haiti's kit.        williams.              partey.
war scene.          playing for marvin.    denied at the border.
fifa said no.                              misses game one.
```

Each names the event, the person, and the consequence. A reader knows what happened before
she taps. **Zero headlines broke the 22-character-per-line render cap** — the validator
added for that works, and it is the one guard in the pipeline with a perfect record.

**Is it good?** Mostly. The failures are narrow:

- **46 Title Case headlines**, all Sunday Briefs ("League champions. Final heartbreak."),
  inconsistent with the lowercase convention every other card follows.
- **34 with ? or !**, against a house rule that the voice states rather than shouts.
  "south korea. no win since 2010. time for thursday?" is the type.
- **A handful of thin pegs.** "england. starting to click." is a manager's quote, not an
  event. "spain. betting favourites. world cup 2026." is a bookmaker's price with a dead
  third line.

**Is it for the audience?** Yes, and this is the surface to protect. The headline voice is
the clearest expression of the brand in the whole product.

**Grade: the best surface. Fix the 24 % that never got written, and the casing.**

---

## Task 3 — Girl references

This is the surface the product is named for, and it is the one that failed.

**Is it even a girl reference?** For 945 of 1 266 cards there is a line. For **321 there
is nothing.** And of the 148 Sunday Briefs, **0 carry a cultural reference** — the field
contains a statistics line instead:

```
G: 85 points and a title. Then a penalty shootout loss in Budapest.
G: 53 points, no drama. Pre-season in August.
G: 20 points. Bottom of the table. Going down with West Ham and Burnley.
```

That is `immersive_context_fallback` content sitting in the analogy slot. The Sunday Brief
prompt was never taught what the field is for. Nobody noticed for six weeks.

**Is it good?** Against the prompt's own hard rules, mostly not.

- **766 of 945 (81 %) exceed the 16-word cap.** Median is 23 words, longest 55. The spec
  says "1–2 sentences, tighter is better. If you can say it in one sentence, do."
- **Between 36 % and 51 % of the girl refs present have no named cultural anchor**, which
  the prompt does not merely discourage — it says *"Generic = boring = forbidden."* The
  range is honest about the measurement: "named anchor" is a judgement, not a regex. A
  strict allowlist of brands, apps and named people gives 51 %; widening it to include
  every anchor I saw while reading — weddings, marathons, bridesmaids, flatmates — gives
  36 %. The truth sits between, and closer to the strict end, because the prompt explicitly
  names "your friend" and "your flatmate" as failures. What shipped instead:
  "your flatmate", "a job interview", "the first exam of the semester", "hosting a party at
  your own place", "your company away-day", "your boss offering a pay rise but writing your
  KPIs into the contract". The spec lists workplace analogies as second choice at best;
  they became the default.
- **One card used the explicitly banned "football equivalent of" construction.**
- **670 (71 %) open with "It's like" or "Like".** The gold-standard examples in the prompt
  do too, so this is not a rule break — but seven cards in ten starting with the same two
  words is a monotony the reader will feel by day three.

When the anchor rule was followed, the results are the best writing in the product:

> **Charli XCX dropping her new album and the first single immediately breaking Spotify's
> all-time weekly record.** — Mbappé becoming France's record scorer, first game.

> **The girls splitting the Uber because someone is short this month.** — Germany's squad
> paying for 600 fans to travel.

> **The Spotify applicant who got rejected and immediately joined Apple Music to prove a
> point.** — Marsch, passed over by the USA, managing Canada.

> **The moment a show finally casts someone who looks like you in the lead role.** —
> Zidane Iqbal, first player of Pakistani heritage at a men's World Cup.

Fourteen words, named anchor, emotional parallel that actually maps. The system can do it.
It did it 64 times in 1 266.

**Is the link to what happened clear?** Usually, and often that is the problem in reverse:
many analogies restate the football fact inside the analogy sentence, spending words the
16-word cap does not have. "It's like finally getting into Glastonbury, spending all
weekend there, and immediately going home to check next year's line-up. Rice won the PL and
couldn't sit still." The second sentence is the card's job, not the analogy's.

**Three that broke:**

- **"The mate who swore off Hinge in 2022, still the most active on there. Kanté's her."**
  — the analogy genders a male player as a woman.
- **"Like booking the nail tech your group chat has been recommending for ages. Leicester
  stopped waiting and called her in."** — same error, about Russell Martin.
- **"Like buying the vintage piece from someone had in a box for three years"** — shipped
  ungrammatical.

**Grade: the weakest surface, and the one carrying the brand.**

---

## Task 2 — Talking points

3 302 points across 1 266 cards. Three per card is the norm; the blank cards get one.

**Is it even a talking point?** 61 % open with something she can actually do — *Tell him,
Ask him, Mention, Drop, Pour his drink*. The rest are observations, predictions, or
context. The slot degrades as it goes: T1 is usually the fact, T2 usually a question, and
**T3 is where the writing gives up.** 17 % of third talking points assert something about
her partner as fact.

**Is it relevant?** Two structural failures.

**1. Template collapse on matchday.** Of 158 World Cup matchday cards, **111 carry the
identical talking point**: *"Ask him what they need from their next game."* Twelve distinct
strings cover all 158. The most-watched content type in the tournament, on the day of the
match, said the same sentence to almost everyone.

**2. Opener monotony in news.** The ten most common five-word openings account for 361 of
3 302 points:

| | |
|---|---|
| ×107 | "Ask him: does he think…" |
| ×49 | "Ask him if he thinks…" |
| ×46 | "Ask him what that result…" |
| ×29 | "Worth asking him how that…" |
| ×16 | "Text him 'big one coming up?' and let him run with it." |

And 34 % of all cards use the same three-beat shape: Tell → Ask → a sentence about him.

**Is it for the audience?** This is where the review gets uncomfortable, because the
failure is not craft, it is stance.

**304 cards (24 %) tell her something about her own partner as though it were a fact:**

> "He's been tracking every England squad update."
> "He's had Panama pegged as underdogs."
> "He's been building his own expected lineup for weeks."
> "He's been sleeping on the small nations."
> "He's been underestimating Japan."

The app does not know any of this. If he has not been following Panama, the line is simply
false, and she is the one who finds out — mid-conversation, having repeated it. The product
promises to make her better informed; here it hands her a guess about the person she is
talking to.

**58 lines go further and position him as someone to be endured:**

> "He might go on about Ratcliffe's ownership. **Let him.**"
> "He'll run through the whole lineup anyway. **Let him. Just be ready for a long one.**"
> "He'll probably want to look up Arbeloa's coaching record. **Watch him disappear down a
> rabbit hole.**"
> "Mention you saw Gvardiol stayed, and **watch him act like he had no doubts** about it
> all along."
> "He's probably already rehearsing the whole rivalry history. **Just nod and let him.**"

The brand rule is that the voice is warm about him — she is interested, not tolerant. A
steady drip of eye-rolling turns a product about joining in into a product about managing a
bore. It is the single clearest voice drift in the corpus.

**61 points use "Did you know…?"**, which frames her as the one being quizzed, and one
crosses the explicit line the prompt draws — *never address her relationship with
football*:

> "Did you know the USA are co-hosting this World Cup?"

Asked of someone using a World Cup app, during the World Cup.

**The voice inverts on 54 cards.** A recurring drift, worst on 6 July (12 of 26 cards
that day), turns the talking point from something she can say into a question she is
asked:

> "How painful do you think it was for Mexico to go out at their own Azteca?"
> "What do you make of Aguirre saying he felt proud but hurt after the game?"
> "Do you think Morocco can pull off an upset against France in the quarter-final?"
> "Brighton keep making smart moves — does it make you nervous about where the clubs are
> heading?"

Fifteen cards have **no talking point that is not a bare question**, and **34 of the 54
were pushed**. On the worst days the whole card changes shape with it: headlines lose the
three-line structure and become a single lowercase phrase ("the azteca heartbreak", "trump
made the call", "three months, goodbye"), and the girl reference disappears. The product
stops arming her for the conversation and starts quizzing her about football, which is the
one thing the brand rules say never to do.

**Three cards put Trump in the couple's evening.** The Balogun ban story was covered by
routing a politically charged subject into a conversation prompt. One of them asks her
directly: *"What do you think about Trump getting involved with FIFA over Balogun's ban?"*
The Belgium version of the same story keeps it on the football decision and is fine. The
USA version is not a football question, and the app should not be handing a couple a
political opinion to disagree about.

**Is the link clear?** Yes, and on the one thing I could test mechanically the corpus is
sound. I cross-checked all 150 cards carrying a scoreline in both the card and its body:
**none contradicted itself.** The seven flagged pairs were false positives on inspection —
a talking point referencing a different match, or the score at a different moment. That is
a narrower claim than "the facts were right": it means the app did not disagree with its
own source text. Claims it could not check against itself — the Almirón red card below —
are a separate matter.

**When the talking points are good, they are very good** — and they cluster around emotion,
not information:

> "He'll need a moment. Then a hug. Then he'll want to go through every minute of it with
> you." — Argentina losing the final.
> "He might be quiet about this one. Just make sure there is food." — Tunisia 1-5 Sweden.
> "He needs this summer to reset, not relitigate." — Burnley relegated.
> "Ecuador held on for 89 minutes. Then the 90th minute happened. Tell [his name]."

Every one of those does the job the tier system is supposed to sell: it tells her what to
*do*, not what to know.

**Grade: strong at the top, templated in the middle, presumptuous at the bottom.**

---

## Cross-cutting failures

**1. The Sunday Brief broke on 5 July and nobody noticed.**

| Date | Briefs with no headline and no girl ref |
|---|---|
| 14 Jun | 0 / 20 |
| 21 Jun | 0 / 20 |
| 28 Jun | 0 / 48 |
| **5 Jul** | **20 / 20** |
| **12 Jul** | **20 / 20** |
| **19 Jul** | **15 / 20** |

Fifty-five consecutive Sunday Briefs shipped as bare lowercase sentences. This is a
regression with a date, and it ran for three weeks during the knockout stage.

**2. The blank-card rate peaked when the audience did.** 35–36 % of all cards in weeks 25
and 26 — the group stage, the busiest fortnight of the tournament — had neither a headline
nor a girl reference. **150 of those 302 blank cards were pushed.** A notification, then a
card with a scoreline and one templated question.

**3. The Sunday Brief fires whether or not anything happened.** Six consecutive weeks of
briefs, 20 clubs each, through an off-season in which the Premier League played no games.
The 14 June and 21 June Arsenal briefs are differently worded accounts of the same closed
season. The App Store copy promises "Quiet day? No notification."

**4. Content for clubs the app was not tracking.** 45 PL items went to clubs outside the
Premier League: Leicester (5), Southampton (2) and Ipswich (4) were Championship clubs that
season — Ipswich went on to be promoted for 2026-27, the other two did not — and West Ham
(17), Wolves (12) and Burnley (5) had just been relegated. The Championship clubs are the
clear waste; content for the three just-relegated clubs is defensible for a few weeks and
then is not.

**5. Serious subjects still get jokey analogies.** The prompt reserves factual, no-analogy
treatment for health and grief and does not extend it to anything else. So a story about a
Dutch pundit's racial slur about Japanese players got *"like someone in a group chat saying
something they absolutely shouldn't, then sending a voice note apology at midnight"*, and an
Ivorian manager alleging racism got *"like a colleague saying your presentation was 'very
energetic'"*. Twenty-three cards on serious subjects carried an analogy; most were handled
well — the goalkeeper playing for his late brother, "your late parent's watch on your
wrist", is genuinely good — but racism is not a group-chat gaffe and the rule needs
widening.

**6. One shipped typo, and one claim I could not stand up.** `augusr 21` rendered on an
Arsenal card (20 June); it is the only misspelling in 1 266 cards, which says the writing
is otherwise clean. Separately, two cards state that Miguel Almirón was sent off "for
covering his mouth when talking to a Turkey player… apparently a brand new rule". The
hedge plus the implausibility is the pattern `DATA_SOURCES.md` warns about — worth
checking, because if it is wrong it went to two feeds.

**7. The same name spelled two ways.** Mbappé 10 cards / Mbappe 22. Türkiye 15 / Turkey 14.
Curaçao 13 / Curacao 7. Within one tournament, in the same feed.

**8. Three dropped possessives shipped.** "Vozinha mum", "the other person ex", "the friend
dad". Small, but they are on the card, in a slot with fewer than twenty words.

---

## What was actually good

Worth stating plainly, because the percentages above are harsh and the product is not bad.

- **The headline form works.** Three lines, each with a job, under 22 characters. It is
  distinctive, it is readable at a glance, and the render validator has a perfect record.
- **The facts held.** Not one card contradicted its own source text on a scoreline.
- **The emotional register is right when it engages the moment** rather than the
  information. The relegation and elimination cards are the best writing in the corpus, and
  they are the ones that treat her as a person in a relationship rather than a football
  reader.
- **The rival-result and pre-match templates improved during the tournament** — the single
  "Ask him what that result does to X's group" line diversified into six variants by
  17 June. Someone was iterating.

---

## Fixes, in priority order

**P0 — restore the missing surfaces.** 24 % of cards ship with no headline and no girl
reference, and half of those get pushed. Rival-result and pre-match cards need a headline
and an analogy or they should not be pushed at all; feed-only is the honest setting for a
card with one templated line. Fix the Sunday Brief regression that started 5 July, and
teach that prompt what `immersive_context` is for.

**P1 — put the hard rules in the validator, not just the prompt.** `post_news.sh` already
rejects a non-PL club in a results clause and a bad placeholder. It should also reject:
a girl ref over 16 words; a girl ref with no named anchor from an allowlist; a declarative
sentence asserting a habit of the partner; "Did you know"; "football equivalent of"; a
headline that is not lowercase. Every one of these is mechanically checkable, and the
prompt alone has now had six weeks to prove it is not enough.

**P2 — kill the partner-assumption pattern at the source.** The prompt should forbid any
declarative sentence about him that the app cannot know. He can be *offered* a reaction
("he might have a view on…"), never *assigned* a history. Same change removes the
"Let him. / Just nod / be ready for a long one" register.

**P2b — the talking point must be a line, not a question to her.** 54 cards inverted the
voice, 34 of them pushed. `post_news.sh` can reject any talking point that ends in "?"
without an imperative opener ("Ask him…", "Tell him…"), and any point containing "do you
think" / "what do you make of". Ten lines of bash for a failure that reached the feed
eighteen separate days.

**P3 — matchday talking points need real inputs.** One sentence covering 111 of 158 cards
is not a writing problem, it is a data problem: the matchday prompt had nothing
team-specific to say. It has `team_season_state`, the opponent's own `ones_to_know`, and
the fixture stakes available and used none of them.

**P4 — don't publish a Sunday Brief with no week behind it.** If there were no fixtures,
send nothing. This is one condition in the routine.

---

## What this means for the tier plan

`TIERS.md` proposes that Deep sends 25–40 pushes a week. This review is the argument for
why that is only safe alongside the P1 validator work.

At 5 % full compliance and 22 % substantive compliance, raising volume raises the count of
weak cards proportionally. The Deep tier's promise — *she has the thing he hasn't thought
of* — is precisely the promise a templated "Ask him what they need from their next game"
breaks. **The quality gate has to land before the volume does.**

The review also sharpens what the tiers should carry. The best content in this corpus was
not information, it was *what to do with the moment*: the hug, the food, the minute he
needs. That is the Deep tier's real differentiator and the thing "group chat prep"
(§6.6 of `TIERS.md`) should be built around — not more facts, better delivery.
