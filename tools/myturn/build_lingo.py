#!/usr/bin/env python3
"""build_lingo.py — writes lingo.json from lingo_src.py + lingo_overheard/.

Each term: (category, id, term, meaning, heard, sayIt, seeAlso) from
lingo_src.TERMS, its `level` from lingo_src.LEVELS, and the Overheard game
fields (overheard, speaker, gist, decoy/spare, when, moment) from lingo_overheard.
Of the two authored wrong options only `decoy` ships; `spare` stays in the
source so dropping back to three options stays a one-line change.
`moment` bands how often the sayIt line's moment arrives, so the end-of-round
commitment never offers a line she had no chance to use. An entry's optional
`player` key becomes `playerVariants`, each with its own `overheardTerm`, so a
card can name a real player from the fixture without the app parsing anything.
The file is written in level order, with the Called It lines from lingo_calls.py
alongside it under `calls`. Then run validate_content.py.

A term with no Overheard entry yet is written without the game fields, so
the four category files can be filled in parallel; the validator is what
refuses to ship an incomplete set.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lingo_calls import CALLS  # noqa: E402
from lingo_match import term_match  # noqa: E402
from lingo_overheard import OVERHEARD, SLOTS, WHEN_TAGS  # noqa: E402
from lingo_src import LEVEL_OF, LEVELS, TERMS  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "lingo.json")
VERSION = "2026-09-23.7"

# The optional `player` key: one variant, or a list of at most two whose sides
# differ. It overrides `overheard` and `sayIt` only; speaker, gist, decoy,
# when, moment and basic are inherited and not overridable.
PLAYER_KEYS = {"slot", "overheard", "sayIt"}

ORDER = {tid: i for i, tid in enumerate(t for level in LEVELS for t in level)}
WHEN_ORDER = {w: i for i, w in enumerate(WHEN_TAGS)}

known_ids = {t[1] for t in TERMS}
orphans = sorted(set(OVERHEARD) - known_ids)
assert not orphans, f"lingo_overheard has entries for ids that are not in lingo_src: {orphans}"

terms = []
for category, tid, term, meaning, heard, say_it, see_also in TERMS:
    row = {"id": tid, "category": category, "term": term, "meaning": meaning, "heard": heard,
           "sayIt": say_it, "level": LEVEL_OF[tid]}
    if see_also:
        row["seeAlso"] = list(see_also)
    o = OVERHEARD.get(tid)
    if o:
        row["overheard"] = o["overheard"]
        hit = term_match(term, tid, o.get("aliases", ()), o["overheard"])
        if hit:
            # The exact substring the app bolds, so Swift needs no regex.
            row["overheardTerm"] = hit
        if o.get("aliases"):
            # Source-only in spirit, but the validator reads lingo.json, so it rides along. Swift ignores it.
            row["aliases"] = list(o["aliases"])
        row["speaker"] = o["speaker"]
        row["gist"] = o["gist"]
        # Two wrong options are authored; one ships. `spare` is written and
        # reviewed and never leaves this file, so the revert to three options is
        # a one-line change rather than a writing job. Asserted rather than
        # defaulted: a term that lost its spare has lost the revert.
        assert isinstance(o.get("decoy"), str) and o["decoy"].strip(), f"{tid}: needs a shipping `decoy`"
        assert isinstance(o.get("spare"), str) and o["spare"].strip(), \
            f"{tid}: needs a reviewed `spare`, the decoy that does not ship; without it the revert to three options is a rewrite"
        row["decoy"] = o["decoy"]
        # ponytail: `decoys` is the pair the shipped Swift still reads
        # (LingoDeck.options requires two). It goes when Swift moves to `decoy`.
        row["decoys"] = [o["decoy"], o["spare"]]
        row["when"] = sorted(set(o["when"]), key=lambda w: WHEN_ORDER.get(w, 99))
        row["moment"] = o["moment"]
        player = o.get("player")
        if player:
            variants = [player] if isinstance(player, dict) else list(player)
            assert len(variants) <= 2, f"{tid}: at most two player variants, got {len(variants)}"
            sides = [str(v.get("slot", "")).split(".")[0] for v in variants]
            assert len(set(sides)) == len(sides), f"{tid}: two player variants must be on different sides, got {sides}"
            out = []
            for v in variants:
                assert set(v) == PLAYER_KEYS, \
                    f"{tid}: a player variant carries exactly {sorted(PLAYER_KEYS)}, got {sorted(v)}"
                # A bad slot fails the build, not the app: the phone has no way
                # to fill {ours.winger} and would ship the braces to her.
                assert v["slot"] in SLOTS, f"{tid}: player slot {v['slot']!r} is not one of {', '.join(SLOTS)}"
                # The app substitutes by literal string match. A variant whose
                # bubble carries no token is skipped at runtime and silently
                # wastes one of only two named cards in a round.
                assert "{" + v["slot"] + "}" in v["overheard"], \
                    f"{tid}: overheard does not contain the literal token {{{v['slot']}}}; the app would skip the variant"
                pv = {"slot": v["slot"], "overheard": v["overheard"], "sayIt": v["sayIt"]}
                hit = term_match(term, tid, o.get("aliases", ()), v["overheard"])
                if hit:
                    # Its own bold range: the name changes the string the app searches.
                    pv["overheardTerm"] = hit
                out.append(pv)
            row["playerVariants"] = out
        if o.get("basic"):
            # Guessable from the words themselves. Still in the list and in
            # search; never dealt in a round (LingoWeekendDeck.build).
            row["basic"] = True
    terms.append(row)
terms.sort(key=lambda r: ORDER[r["id"]])

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "terms": terms, "calls": CALLS}, f, indent=2, ensure_ascii=False)
    f.write("\n")
missing = sum(1 for r in terms if "overheard" not in r)
print(f"wrote {OUT}: {len(terms)} terms, {len(terms) - missing} with Overheard, {len(CALLS)} calls" + (f" ({missing} still to write)" if missing else ""))
