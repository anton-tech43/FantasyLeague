# My Turn quiz — what "verified: true" means in this batch

The spec says a question ships only after a human has checked its fact against
a source, and the validator breaks the build on `verified: false`. Every question
in the 2026-09-08 batch (24 packs, 490 questions, content version 2026-09-08.2)
carries `verified: true`, and that flag was set by Claude on the strength of its
own knowledge of settled football history — **not by a person**. Anton: this
file is the list of what to spot-check before the tab ships to the App Store.

## What changed on 2026-09-08 (Anton's review of the first batch)

- Every question now carries `why`, `use` and `useType` — see
  `CONTENT_PRINCIPLES.md`. The app shows the why in italics and the use line in
  a labelled box (SAY IT / ASK HIM / TO IMPRESS) under the explanation.
- Superlatives tied to the present are banned by the validator after the "only
  Champions League final was 2006" mistake (they played the 2026 final).
- **"His club, right now"** is built in the app (`LiveClubPack.swift`) from the
  team page: who manages them, "Who is this?" with manager and ones-to-know
  photos, positions, which of these plays for them, last season, last title,
  nickname, ground, rival. Nothing in the static files names a current person.
- 23 questions were cut for having no honest answer to "when does she say this?"
  (513 → 490).

## What was deliberately excluded from the static files

- Anything about the present: current manager, current captain, "this season",
  league position. Static content cannot age, so it must not be ageable. The
  live pack covers it from data.
- Anything after mid-2025 except results that are already final and widely
  reported (see the list below).

## The questions most worth a human eye

Facts from 2024–2025 are the newest in the set and the ones a fan would catch
first if wrong:

| pack | question | fact to check |
|---|---|---|
| club-crystal-palace | 2025 FA Cup | Palace beat Man City 1-0, Eze scored, Henderson saved a penalty |
| club-spurs | 2025 Europa League | Spurs 1-0 Man Utd in Bilbao; Postecoglou sacked shortly after |
| club-newcastle | 2025 League Cup | Newcastle 2-1 Liverpool; Dan Burn scored the first |
| club-liverpool | 2025 title | 20th title; Arne Slot's first season |
| club-leeds | 2025 promotion | Championship champions on 100 points, level with Burnley |
| club-sunderland | 2025 play-off final | 2-1 v Sheffield United, Tom Watson 95th-minute winner; manager Régis Le Bris |
| club-ipswich | 2025 relegation | went down with Leicester and Southampton |
| club-brentford | Thomas Frank to Tottenham (2025); Ivan Toney to Al-Ahli (2024) | |
| club-coventry | Frank Lampard appointed November 2024 | |
| club-everton | David Moyes's second spell from 2025; new stadium at Bramley-Moore Dock opened 2025 | |
| club-man-utd | Ratcliffe stake 2024; 2024 FA Cup final 2-1 v City | |
| club-man-city | four titles in a row 2021–24; Haaland's 36 | |
| club-fulham | Riverside Stand rooftop pool (2024) | |
| club-hull | Acun Ilıcalı bought the club 2022 | |

Older history (founding years, grounds, nicknames, 1960s–2010s trophies) is
low-risk but not zero: a wrong year in a "when was X founded" question is
exactly the kind of thing a partner spots in three seconds.

## How to fix one

Edit the tuple in `tools/myturn/quiz_src/*.py`, then:

```bash
python3 tools/myturn/build_quiz.py
python3 tools/myturn/validate_content.py
# bump contentVersion in build_quiz.py (VERSION) so the app downloads it
set -a && source backend/.env && set +a && bash tools/myturn/publish_content.sh
```

Question ids are `<pack>-<index>`; a user's progress is keyed on them, so edit
questions in place rather than reordering the list.

---

# Three options (2026-09-23)

Anton asked for three options instead of four, and for all 496 questions to be
read rather than trimmed by rule, so the two surviving wrong answers are the two
that actually tempt. Every question was read. The option that went is the one
nobody would pick — the wrong century, the wrong sport, the joke, the thing from
another category — and where all three distractors were live, the two closest to
the answer in kind stayed.

## What the shape of the options was leaking

A solver that reads no football and applies one rule, splitting ties, scored:

| rule | four options (floor 25%) | three, before the writing | three, after |
|---|---|---|---|
| pick the longest option | **34.8%** | 41.5% | **35.8%** |
| pick the one with the most words | 32.6% | 40.7% | 37.4% |
| pick the shortest option | 18.5% | 27.0% | 27.6% |
| skip the option opening a/an/the | 25.5% | 33.5% | 33.5% |
| pick the one with a comma | 25.1% | 33.5% | 33.3% |
| pick the one with a digit | 24.9% | 33.3% | 33.3% |

The bottom three sit on the floor because they apply to almost nothing: the
article rule reaches 19 questions of 496 and the comma rule reaches one, so the
set-wide score hides how sharp they are on the slice where they do apply.

Two findings, both different from the Lingo side's.

**Length, not punctuation.** Lingo leaked through commas (the gist carried the
only one on 90.6% of cards). Quiz options are names, years and short phrases, so
only one question in 496 had a lone comma and the comma rule is worth nothing
here. What Quiz leaked was **length**: the answer was the longest option far more
often than a third of the time, usually because the answer was a long club name
standing next to short ones. Cutting an option cannot fix that — removing a short
wrong answer leaves the long right one still longest — so the cut made it worse
before the writing made it better. Twenty-eight questions were rewritten to stand
the answer beside its own size.

**The article was a lone tell, not a common one.** Nineteen questions offered
exactly one option opening with a/an/the, and it was the answer twice, so "skip
that one" won 17 of 19. That is the same effect Lingo measured at 76%, on a much
smaller slice. The mirror shape — one option *without* the article the other two
carry — sat at 4 of 9, which is chance.

## What now breaks the build

Both live in `validate_content.py`'s quiz block.

- **Per question**: exactly one option opening with a/an/the is an error.
- **Over the set**: `longest_option_solver` scores the blind longest-picker over
  all 496 questions. Outside 28–39% is an error, outside 30–37% a warning. The
  floor is 33.3% and the standard error at n=496 is 2.1 points, so the error band
  is 2.5 SD either side — noise reaches it about once in eighty builds, and a set
  that trips it is handing six points a game to anyone who notices. Two-sided,
  because an answer that is reliably the *short* one reads just as easily; that
  measure sits at 27.6% today and is the one to watch next.

Two older thresholds moved with the arity: the "answer sits in one slot" warning
went from half a pack to 60% (eleven of twenty is inside two SD of noise at three
options, and it was warning on three clean packs), and the idiom check now joins
a question's fields with newlines rather than spaces, because the option "Zero"
next to an explanation opening "Zero." read as the banned "zero-zero" — and
whether it fired at all depended on where the shuffle put the option.

## What the read turned up — Anton, this is the list worth having

Reading all 496 found about a hundred problems that have nothing to do with the
option count. None of them is fixed here; the cut removed the option in the cases
marked *(cut)*, which repairs the symptom, not the question.

### A wrong option that is also right

| question | the problem |
|---|---|
| `club-bournemouth-13` | options 1 and 3 are "Joshua King" and "Josh King" — the same man *(cut)* |
| `badges-grounds-16` | Benfica play at the Estádio da Luz, the Stadium of Light; the explanation admits it |
| `badges-grounds-9` | Exeter City's ground is St James Park |
| `clubs-rivalries-10`, `badges-grounds-12` | Barnet FC are nicknamed the Bees |
| `clubs-rivalries-22` | Celtic sing You'll Never Walk Alone too |
| `club-chelsea-16` | "The Pensioners" is a real Chelsea nickname, per `club-chelsea-3` |
| `club-crystal-palace-2` | "The Glaziers" was Palace's name until 1973, per its own explanation |
| `club-everton-2` | Everton are routinely called the Blues |
| `club-everton-17` | Stanley Park and Priory Road were both Everton homes before Goodison |
| `club-fulham-2` | "The Whites", offered as wrong, is confirmed by the explanation *(cut)* |
| `club-ipswich-2` | "The Blues" is a real Ipswich nickname, per its own explanation *(cut)* |
| `club-hull-11` | the club really was styled "Hull City Tigers" in 2013 *(cut)* |
| `club-spurs-1` | "The Lane" is what fans call the new ground, per its own explanation *(cut)* |
| `club-sunderland-2` | Mackems and Rokerites are both real Sunderland names *(one cut)* |
| `clubs-rivalries-8` | Notts County are the Magpies too *(never offered; watch if edited)* |

### Two defensible answers, or none

- `club-arsenal-19` — Bergkamp has a statue outside the Emirates *and* played in
  the Invincibles side; "he retired in 2006" excludes neither condition.
- `club-ipswich-9` — Alf Ramsey managed Ipswich, then England, and also has a
  statue at Portman Road; the explanation says so. The stem needs a date.
- `club-newcastle-9`, `club-spurs-7` — "before 2025, in which year had they won a
  domestic trophy" has more than one true year. Both want "most recently".
- `club-man-utd-11` — "fiercest rivals" answers Liverpool while the explanation
  concedes City is the local derby.
- `club-coventry-17` — the usual answers are Leicester and Villa; neither is
  offered, and the explanation concedes it.
- `club-crystal-palace-7` — Allardyce also managed Palace in 2017 and is also a
  former England manager.
- `club-crystal-palace-5` — Palace claim descent from an 1861 club.
- `badges-grounds-18` — Dean Court (~11,300) and Kenilworth Road (~11,500) both
  fit "about 11,000".
- `club-bournemouth-6` — 1997 is a real Bournemouth administration as well *(cut)*.
- `club-brentford-6` — Solbakken is Norwegian in a question asking for the Dane.
- `club-hull-8` — the stem asks "at which ground" and the answer is a club name.

### Probably wrong

- `club-man-city-2` — the explanation calls the 1934 Maine Road 84,000 "the
  biggest crowd ever for a league match". That was an FA Cup tie; the league
  record is Man Utd v Arsenal, 1948.
- `club-newcastle-13` — the question calls Bobby Robson a Geordie, the
  explanation says County Durham.
- `club-brighton-20` — asserts De Zerbi was later appointed at Tottenham, which
  the explanation never supports and `club-brentford-19` sits awkwardly beside.
- `badges-grounds-22` — "Sherwood Rangers" is a yeomanry regiment, not a club.
- `the-basics-14` — "The National League" and "The Conference" are the same
  competition under two names.
- `club-coventry-15` — shipped with 2027 as an option.

### One question answering another in the same pack

`club-arsenal-2`→`-3`, `club-aston-villa-1`→`-19`, `club-bournemouth-7`→`-10`,
`club-bournemouth-5`→`-15`, `club-brentford-1`→`-20`, `club-brighton-11`→`-13`,
`club-crystal-palace-9`→`-20`, `club-everton-2`→`-15`, `club-everton-1`→`-16`,
`club-hull-1`→`-20`, `club-hull-2`↔`-12`, `club-hull-16`↔`-17`,
`club-ipswich-19`↔`-20`, `club-leeds-2`→`-13`, `club-man-utd-7`↔`-8`,
`club-man-utd-4`+`-13`→`-16`, `club-newcastle-16`→`-8`, `club-newcastle-9`↔`-11`,
`club-nottm-forest-6`↔`-8`, `club-spurs-8`→`-12`, `club-sunderland-1`↔`-5`,
`club-chelsea-1`↔`-12`.

Near-duplicate pairs across the general packs: Gunners/cannon, Cottagers/Craven
Cottage, Eagles/eagle badge, Bees/bee badge.

### §3 superlatives and §4 present tense that shipped anyway

The validator reads question, explanation, why and use, so these are all shapes
it does not catch or wordings that slipped past the regex:

`legends-7`, `legends-1`, `legends-6`, `badges-grounds-7`, `badges-grounds-15`,
`clubs-rivalries-7`, `clubs-rivalries-18`, `club-arsenal-7`, `club-arsenal-8`,
`club-arsenal-10`, `club-bournemouth-1`, `club-chelsea-7`, `club-chelsea-18`,
`club-coventry-10`, `club-coventry-19`, `club-everton-6`, `club-everton-13`,
`club-everton-14`, `club-hull-9`, `club-ipswich-5`, `club-leeds-6`,
`club-leeds-17`, `club-liverpool-4`, `club-liverpool-8`, `club-liverpool-11`,
`club-man-city-12`, `club-man-utd-10`, `club-man-utd-13`, `club-man-utd-19`,
`club-newcastle-5`, `club-nottm-forest-3`, `club-spurs-8`.

Two of them also name a living player in a static file, against §4:
`club-liverpool-8` (Salah) and `club-man-city-15` (Rodri). Both options were cut.

### Answerable without knowing any football (§8)

`club-fulham-10` (the Thames is the only London river she can name),
`club-fulham-16`, `club-fulham-14`, `club-man-city-11`, `club-man-city-18`,
`club-ipswich-16`, `club-ipswich-20`, `club-nottm-forest-20`.

And one that is a lottery rather than a question: `club-sunderland-9`, four 1973
squad names a non-fan cannot separate, with no line to use afterwards.

### Where cutting to three genuinely hurt

About fifty questions had three live distractors and the cut was decided on shape
rather than content. The ones that lost the most: `club-newcastle-19` (four real
European trophies of the era), `club-sunderland-9` (four 1973 squad names),
`club-man-utd-6` (three plausible United pairs of 1999), `club-nottm-forest-6`
and `-8` (the two European Cup finals use each other's answer as the best
distractor), `legends-19` (all four really managed Leicester), `legends-17` and
`legends-4` (all four in that City squad), `clubs-rivalries-4` (all four pairs are
real rivalries), `club-chelsea-4` (four Russian oligarchs),
`club-crystal-palace-16` (three genuine Arsenal captains), `club-hull-6`,
`club-leeds-11`, `club-liverpool-5`, `club-man-city-7`.
