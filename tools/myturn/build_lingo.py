#!/usr/bin/env python3
"""build_lingo.py — writes lingo.json from lingo_src.py.

Each term: (category, id, term, meaning, heard, sayIt, seeAlso), plus the
`level` it sits at (lingo_src.LEVELS). The file is written in level order,
which is the order in the app: level 1 is the first ten words, and no meaning
relies on a term she has not reached yet. Then run validate_content.py.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lingo_src import LEVEL_OF, LEVELS, TERMS  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "lingo.json")
VERSION = "2026-09-09.1"

ORDER = {tid: i for i, tid in enumerate(t for level in LEVELS for t in level)}

terms = []
for category, tid, term, meaning, heard, say_it, see_also in TERMS:
    row = {"id": tid, "category": category, "term": term, "meaning": meaning, "heard": heard,
           "sayIt": say_it, "level": LEVEL_OF[tid]}
    if see_also:
        row["seeAlso"] = list(see_also)
    terms.append(row)
terms.sort(key=lambda r: ORDER[r["id"]])

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "terms": terms}, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {OUT}: {len(terms)} terms")
