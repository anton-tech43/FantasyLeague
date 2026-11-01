#!/usr/bin/env python3
"""build_hype.py — writes hype.json from hype_src.py.

Five categories of one-line hype: perfect, strong, mid, rough, streak. The app
picks one at random among the ones it has not shown her yet. `quizOnly`
lists the lines a Lingo or Say This result must skip (optional; builds before
2.4 ignore the key). Then run validate_content.py.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from hype_src import CATEGORIES, QUIZ_ONLY  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "hype.json")
VERSION = "2026-11-01.1"

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "categories": CATEGORIES, "quizOnly": QUIZ_ONLY}, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {OUT}: {sum(len(v) for v in CATEGORIES.values())} lines in {len(CATEGORIES)} categories")
