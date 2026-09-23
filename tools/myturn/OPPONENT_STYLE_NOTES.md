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

## Where they shoot from

A caveat that has to come first: the published table splits **shots**, not goals. Nobody
publishes goals by zone in a form we can read, so a line here may say where a side shoots from
and must not say where they score from.

Both seasons agree on these, which is what makes them usable:

- **Bournemouth and Nottingham Forest** shoot from distance more than anyone, around four in ten
  attempts from outside the box in both seasons. **Newcastle, Aston Villa and Liverpool** are
  close behind. "They'll shoot from anywhere, this lot" is fair about any of them.
- **Arsenal and Brentford** do the opposite and work it into the box. Arsenal also took more
  attempts from inside the six-yard box than anyone last season and are second this season,
  which sits neatly with their set-piece record and is the most coherent story in the whole file.
- **Liverpool** almost never shoot from six yards: the same low figure in both seasons, and the
  steadiest number in the table.

Moved enough to be worth nothing yet: **Fulham** have gone from shooting at distance to working
it into the box, and **Tottenham and Crystal Palace** the other way. Five games. Leave them.

**Hull, Ipswich and Coventry** shoot from distance a lot, but they are newly promoted and that is
usually what being outmatched looks like rather than a style. No baseline, so no claim.

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
