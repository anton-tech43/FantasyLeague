#!/usr/bin/env python3
"""build_lingo.py — writes lingo.json from lingo_src.py + lingo_overheard/.

Each term: (category, id, term, meaning, heard, sayIt, seeAlso) from
lingo_src.TERMS, its `level` from lingo_src.LEVELS, and the Overheard game
fields (overheard, speaker, gist, decoys, when) from lingo_overheard. The
file is written in level order. Then run validate_content.py.

A term with no Overheard entry yet is written without the game fields, so
the four category files can be filled in parallel; the validator is what
refuses to ship an incomplete set.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lingo_match import term_match  # noqa: E402
from lingo_overheard import OVERHEARD, WHEN_TAGS  # noqa: E402
from lingo_src import LEVEL_OF, LEVELS, TERMS  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "lingo.json")
VERSION = "2026-09-22.1"

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
        row["decoys"] = list(o["decoys"])
        row["when"] = sorted(set(o["when"]), key=lambda w: WHEN_ORDER.get(w, 99))
    terms.append(row)
terms.sort(key=lambda r: ORDER[r["id"]])

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "terms": terms}, f, indent=2, ensure_ascii=False)
    f.write("\n")
missing = sum(1 for r in terms if "overheard" not in r)
print(f"wrote {OUT}: {len(terms)} terms, {len(terms) - missing} with Overheard" + (f" ({missing} still to write)" if missing else ""))
