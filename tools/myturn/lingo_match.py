"""lingo_match.py — does an overheard line actually contain its term?

Shared by build_lingo.py (which records the matched substring as
`overheardTerm`, so the app bolds it with a plain range(of:)) and
validate_content.py (which refuses a line that does not use its word).

The rule: strip a leading the/a/an from the term, allow a space or hyphen
between words, allow a common inflection on any word (parked, hoofing,
nutmegged, keeper's), and try the id (hyphens as spaces) and any aliases as
alternative forms. Longest form wins.
"""
from __future__ import annotations

import re

STOP_LEAD = ("the ", "a ", "an ")
INFLECT = r"(?:s|es|ed|d|ing|'s|[a-z]ed|[a-z]ing)?"   # [a-z]ed/[a-z]ing: nutmegged, hoofing


def forms(term: str, tid: str, aliases: list[str] | tuple[str, ...] = ()) -> set[str]:
    out: set[str] = set()
    t = re.sub(r"[^\w\s-]", "", term.lower()).strip()      # "Top, top player" -> "top top player"
    i = tid.replace("-", " ")
    for f in (t, i):
        for lead in STOP_LEAD:
            if f.startswith(lead):
                f = f[len(lead):]
        if f:
            out.add(f)
    out.update(a.lower().strip() for a in aliases if a.strip())
    return out


def pattern(form: str) -> re.Pattern:
    words = re.split(r"[\s-]+", form.strip())
    return re.compile(r"\b" + r"[\s-]?".join(re.escape(w) + INFLECT for w in words) + r"\b", re.I)


def term_match(term: str, tid: str, aliases, text: str) -> str | None:
    """The substring of `text` that carries the term, or None."""
    for f in sorted(forms(term, tid, aliases or ()), key=len, reverse=True):
        m = pattern(f).search(text)
        if m:
            return m.group(0)
    return None


if __name__ == "__main__":
    # The runnable check.
    cases = [
        ("The table", "the-table", (), "Top of the table, lads.", "table"),
        ("Top bins", "top-bins", (), "TOP BINS! Keeper had no chance.", "TOP BINS"),
        ("We go again", "we-go-again", (), "Rubbish. We go again Tuesday.", "We go again"),
        ("Park the bus", "park-the-bus", (), "They've parked the bus since the goal.", "parked the bus"),
        ("Box-to-box", "box-to-box", (), "Proper box to box midfielder, him.", "box to box"),
        ("Nutmeg", "nutmeg", (), "He's nutmegged him!", "nutmegged"),
        ("Hoof", "hoof", (), "Just hoof it!", "hoof"),
        ("xG", "xg", (), "The xG was 2.5 and we lost.", "xG"),
        ("Top, top player", "top-top-player", (), "Top, top player, that.", None),   # comma breaks the form; agents write "top top player"
        ("Top, top player", "top-top-player", ("top, top player",), "Top, top player, that.", "Top, top player"),
        ("See the game out", "see-the-game-out", ("see it out",), "Just see it out now.", "see it out"),
        ("Offside", "offside", (), "Nothing to do with it.", None),
    ]
    for term, tid, aliases, text, want in cases:
        got = term_match(term, tid, aliases, text)
        assert got == want, f"{tid}: got {got!r}, want {want!r}"
    print("lingo_match: OK")
