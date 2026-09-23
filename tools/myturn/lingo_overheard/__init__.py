"""lingo_overheard — the Overheard game's content, one file per category.

Each file holds OVERHEARD: dict[term id -> dict(overheard, speaker, gist,
decoys, when, aliases?, basic?)]. `basic=True` marks a word an English
speaker works out from the words themselves ("kick-off", "own goal"): it
stays in the word list and in search, and is never dealt in a round.

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

OVERHEARD: dict[str, dict] = {}
for _mod in (rules, tactics, match_situations, culture):
    _dupes = set(OVERHEARD) & set(_mod.OVERHEARD)
    assert not _dupes, f"{_mod.__name__}: ids already defined elsewhere: {sorted(_dupes)}"
    OVERHEARD.update(_mod.OVERHEARD)
