"""lingo_overheard — the Overheard game's content, one file per category.

Each file holds OVERHEARD: dict[term id -> dict(overheard, speaker, gist,
decoys, when, moment, aliases?, basic?, player?)]. `moment` says how often the line's
moment arrives in one match (anytime, common, rare): the end-of-round
commitment only ever offers a line she could actually get to say.

`basic=True` marks a word an English speaker works out from the words
themselves ("kick-off", "own goal"): it stays in the word list and in search,
and is never dealt in a round.

Split by category so four people can write in parallel without touching the
same file. lingo_src.py stays the source for
term/meaning/heard/sayIt/level; this package adds the game on top.

Rules and golden examples: tools/myturn/LINGO_OVERHEARD_BRIEF.md.
"""
from . import culture, match_situations, rules, tactics

WHEN_TAGS = (
    "any", "derby", "cup", "europe", "title", "top-four", "relegation",
    "good-run", "bad-run", "new-manager", "window", "early-season", "run-in",
    "after-win", "after-loss", "after-draw", "after-big-win", "after-heavy-loss", "after-clean-sheet",
)
SPEAKERS = ("him", "telly", "chat", "pundit")
MOMENTS = ("anytime", "common", "rare")

# The optional `player` key on an entry: a variant of `overheard` and `sayIt`
# carrying one slot, filled on the phone with a real name from the fixture.
# Four archetypes, not five, because players.position has four values and
# nothing else about a position is trustworthy: a `forward` line must be true of
# a winger and a striker alike. A templated line may say what a player *is*; it
# may never report what he did or predict that he will play.
SIDES = ("ours", "theirs")
ARCHETYPES = ("keeper", "defender", "midfielder", "forward")
SLOTS = tuple(f"{side}.{arch}" for side in SIDES for arch in ARCHETYPES)

OVERHEARD: dict[str, dict] = {}
for _mod in (rules, tactics, match_situations, culture):
    _dupes = set(OVERHEARD) & set(_mod.OVERHEARD)
    assert not _dupes, f"{_mod.__name__}: ids already defined elsewhere: {sorted(_dupes)}"
    OVERHEARD.update(_mod.OVERHEARD)
