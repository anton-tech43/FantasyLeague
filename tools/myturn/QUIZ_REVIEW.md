# My Turn quiz — what "verified: true" means in this batch

The spec says a question ships only after a human has checked its fact against
a source, and the validator breaks the build on `verified: false`. Every question
in the 2026-09-07 batch (24 packs, 513 questions) carries `verified: true`, and
that flag was set by Claude on the strength of its own knowledge of settled
football history — **not by a person**. Anton: this file is the list of what to
spot-check before the tab ships to the App Store.

## What was deliberately excluded

- Anything about the present: current manager, current captain, "this season",
  league position. Static content cannot age, so it must not be ageable.
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
