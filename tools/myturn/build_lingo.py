#!/usr/bin/env python3
"""build_lingo.py — writes lingo.json from lingo_src.py.

Each term: (category, id, term, meaning, heard, sayIt, seeAlso). The order in
the source is the order in the app, and the rule is that no meaning relies on
a term she has not reached yet. Then run validate_content.py.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lingo_src import TERMS  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "lingo.json")
VERSION = "2026-09-08.1"

terms = []
for category, tid, term, meaning, heard, say_it, see_also in TERMS:
    row = {"id": tid, "category": category, "term": term, "meaning": meaning, "heard": heard, "sayIt": say_it}
    if see_also:
        row["seeAlso"] = list(see_also)
    terms.append(row)

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "terms": terms}, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {OUT}: {len(terms)} terms")
