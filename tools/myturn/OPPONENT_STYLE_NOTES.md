# What we may say about how a club plays

Editorial reference for whoever writes Lingo and Say This lines. Read it before writing any
line that claims something about a team rather than asking about them.

## Why this file exists

A line like "They're strong from set pieces. Watch the corners." was written as an example
teaching the phrase, and then the commitment card started handing it to her as something to say
on Saturday. At that point it stops being a teaching example and becomes a claim about the
actual opponent, and we had nothing behind it. No feed we hold carries any style-of-play data.
API-Football does not break goals down by set piece, counter attack or anything else.

So these are conclusions drawn by reading published league tables, the way anyone writing about
football reads them. They are not a copy of anyone's dataset and no figures are stored here
beyond what a conclusion needs. Source: WhoScored team statistics, Premier League, read
2026-09-23 for both seasons.

## The method

**Last season is the ground, this season is the check.** A completed season is 38 games and
means something. Five games is noise: the gap between the best and worst set-piece side in the
league right now is four goals. So a full season's pattern stands unless this season contradicts
it hard and for long enough to matter, which will not be before midwinter.

**Date every claim in the copy.** "They scored more set-piece goals than anyone last season" is
true, checkable and cannot go stale. "They're strong from set pieces" can be wrong by Saturday.
This is the rule `CONTENT_PRINCIPLES.md` §3 already applies to everything else.

## Set pieces

Safe to claim, last season's pattern and this season agreeing:

- **Everton, Leeds, Newcastle, Brentford, Brighton, Chelsea.** All were mid-to-high last season
  and all have scored this way already this season. Brighton and Chelsea are the strongest: both
  are near the top of the league on set-piece goals after five games.

Safe on last season alone, not yet seen this season:

- **Arsenal, Manchester United, Tottenham.** The three biggest set-piece sides in the league last
  season, Tottenham most strikingly: four in ten of their goals came that way. None of them has
  scored from one yet this season. Five games cannot overturn a full season, so the claim stands,
  but say it about last season and not about now.

Do not claim: everyone else, and especially not **Hull, Ipswich or Coventry**, who have no
Premier League season behind them at all.

## Counter attacks

- **Brentford and Bournemouth** were the league's best counter-attacking sides last season and
  both have scored on the break again this season. Safest claim in this section.
- **Chelsea and Newcastle** have jumped: both are at the top of the counter-attack list already
  this season having been mid last season. Worth watching, too early to state.
- **Manchester City** were joint-best last season and have none this season. Claim only about
  last season.
- **Crystal Palace** scored zero on the counter all last season, so "dangerous on the counter"
  was a straightforwardly false line about them. They have one this season, which is the whole
  argument for rechecking rather than freezing a verdict.

## In the air

**Everton** won more aerial duels than any side last season, comfortably. This season they have
dropped to mid-table on it and **Leeds and Brentford** are now the top two. Do not write "they
win everything in the air" about anyone right now. If we want an aerial line, Everton's is the
only one with a season behind it, and it has to be dated.

## Where they score from

Goals by zone, not shots. It sits under the Detailed tab rather than the Shot Zones one, which
is where I first looked and got the wrong table.

Both seasons agree on three, which is what makes them sayable:

- **Aston Villa score from range.** About a quarter of their goals came from outside the box
  last season, the highest share in the league, and they are at the same share this season.
  The safest claim in this file. "They'll have a go from anywhere" is fair about Villa.
- **Brentford score from close in.** The lowest share from outside the box last season by some
  way, and the same this season. Whatever they do, it ends in the six-yard box.
- **Manchester City score from inside the box** despite having the most of the ball. Worth
  knowing because "they dominate possession" and "they shoot from distance" sound like they go
  together and for City they do not.

Changed enough to leave alone: **Manchester United** have gone from almost never scoring from
distance to doing it often, and **Arsenal**'s goals have moved out of the six-yard box this
season, which fits their set-piece drought above. Both are five games. Note them, do not write
them.

**Fulham** were second for goals from distance last season and have none this season, off five
goals in total. Baseline stands.

## Sides of the pitch

Stable enough to use, and last season and this season broadly agree:

- **West Ham** are the most one-sided attack in the league, right side. **Arsenal** are close
  behind, also right.
- **Fulham, Bournemouth and Everton** lean as hard the other way, down the left.
- **Crystal Palace** go through the middle more than anyone.

## What invalidates all of it

A manager change. The manager decides whether a side rehearses corners, so a club that changes
one has no usable history until the new one has a season. Check `teams.manager_name` and its
verification date before leaning on anything above.

Promotion. Hull, Ipswich and Coventry have no Premier League baseline.

Time. Recheck around midwinter, when this season is twenty games old and can carry a claim on
its own. Ask for it; it is a read of a published table, not a pipeline, and nothing here is
automated.
