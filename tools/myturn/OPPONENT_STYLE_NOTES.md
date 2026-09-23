# What we may say about how a club plays

Editorial reference for whoever writes Lingo and Say This lines, and the source the
`club_style` table is seeded from.

## Read this first, because it inverts what the rest of the file looks like

**Nothing here may go into a static line.** Every line in Lingo and Say This is shared across all
twenty possible opponents, so "they're strong from set pieces" is shown against the fifteen clubs
it is false about as well as the five it is true about. These conclusions are usable only in copy
the app builds per club, where it knows which opponent it is talking about: the `club_style` table
and the `matchup` card on the team page.

For static content the file's job is the opposite of a licence. It is the reason the unqualified
form is always wrong, and the reason those lines are now questions.

## Why it exists

"They're strong from set pieces. Watch the corners." was written as an example teaching the
phrase, and then the commitment card began handing it to her as something to say on Saturday. At
that point it stopped being a teaching example and became a claim about a specific opponent, with
nothing behind it. No feed we hold carries style of play: API-Football does not break goals down
by set piece, counter attack or zone.

These are conclusions drawn by reading published league tables, the way anyone writing about
football reads them, not a copy of anyone's dataset. Source: WhoScored team statistics, Premier
League, read 2026-09-23 for both seasons.

## The method, and the two filters that remove most of it

**Last season is the ground.** A completed season is 38 games. This season is five, and five is
noise: the gap between the best and worst set-piece side in the league right now is four goals.
This season can therefore neither confirm nor contradict anything yet, including the sections
below on where sides score from and which flank they attack. Expect that to change at midwinter.

**A manager change voids the baseline.** The manager decides whether a side rehearses corners, so
last season says nothing about a club that has since changed one. The column that answers this is
`teams.manager_started_on`. It is not `manager_verified_at`, which records only when we last
checked the name.

Eleven of the twenty active clubs appointed their manager during 2026. Nine did so after the
baseline season ended: Bournemouth, Chelsea, Crystal Palace, Fulham, Ipswich, Liverpool,
Manchester City, Newcastle and Nottingham Forest. Two more arrived mid-season and so managed only
part of it: Manchester United in January and Tottenham at the end of March. **Nothing is claimable
about any of the eleven.**

That filter removes about half of what the tables suggest, and the half it removes includes the
single most striking number in them: Tottenham took four in ten of last season's goals from set
pieces, the highest share in the league, under a manager who left in March. It is the first thing
to re-seed once De Zerbi has a season of his own.

## What survives both filters

These are what `club_style` carries.

**Set pieces.** Everton, Leeds, Brentford and Brighton were mid to high last season and all kept
the manager who got them there. Arsenal were the league's best by a distance, twenty-three goals,
under a manager in place since 2019, which makes theirs the strongest claim here even though they
have not scored one that way yet this season. Because a flag carries no season, any copy built
from Arsenal's must be dated to last season.

**Counter attacks.** Brentford only. Bournemouth and Manchester City were the others and both
changed manager.

**Goals from range.** Aston Villa. About a quarter of their goals came from outside the box last
season, the highest share in the league, under a manager in place since 2022. The safest claim in
the file.

**Goals from close in.** Brentford, who took the lowest share from outside the box in the league.

**In the air.** Everton, under a manager who is still there. Read the caveat below before using it.

**Attacking side.** Arsenal lean right harder than anyone still in the division with the same
manager. West Ham were more lopsided still, right side, and are relegated, so there is nothing to
seed; it is recorded here only so the next reader does not go hunting for them.

## The one verified negative

Crystal Palace scored zero goals on the counter across the whole of last season, which means
"dangerous on the counter" was flatly false about them. `club_style` stores that as false rather
than null, so the difference between "checked and untrue" and "never checked" survives. They have
since changed manager and have one already this season, which is the clearest argument in the file
for rechecking rather than freezing a verdict.

## Two claims to handle carefully

**Everton in the air.** True of last season and comfortably so, but they have dropped to mid-table
on it this season while Leeds and Brentford have gone past them. A present-tense line would be
wrong today. Use it dated or not at all before midwinter.

**Arsenal from set pieces.** The same shape: the league's best last season, not one yet this
season. Dated only.

## Not claimable at all

The eleven clubs that changed manager. The three promoted clubs, Hull, Ipswich and Coventry, who
have no Premier League baseline. And anything this season is supposed to show, in either
direction, until there are enough games for it to mean something.

## When to recheck

At midwinter, when this season is twenty games old and can carry a claim by itself, and whenever a
club changes manager. The `stale-data-audit` skill has the query that finds a style claim resting
on a season its current manager did not manage. Ask for the read; it is a look at a published
table, not a pipeline, and nothing about it is automated.
