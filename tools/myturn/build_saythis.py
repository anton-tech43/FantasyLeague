#!/usr/bin/env python3
"""build_saythis.py — writes saythis.json from saythis_src.py. Then validate."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from saythis_src import SITUATIONS  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "saythis.json")
VERSION = "2026-09-08.1"

situations = []
for sid, group, label, lines in SITUATIONS:
    rows = []
    for suffix, text, usage, risk, lingo in lines:
        row = {"id": f"{sid}-{suffix}", "text": text, "usage": usage, "risk": risk}
        if lingo:
            row["lingo"] = lingo
        rows.append(row)
    situations.append({"id": sid, "group": group, "label": label, "lines": rows})

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "situations": situations}, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {OUT}: {len(situations)} situations, {sum(len(s['lines']) for s in situations)} lines")
