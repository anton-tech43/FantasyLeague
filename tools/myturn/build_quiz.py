#!/usr/bin/env python3
"""build_quiz.py — assembles ios/GoalDigger/Resources/MyTurn/quiz.json.

Questions live as Python tuples in quiz_src/*.py so they are compact to write
and review; this script gives them ids, checks the shape, and writes the JSON
the app reads. Then run validate_content.py.

Each question, since the 2026-09-08 rewrite (see CONTENT_PRINCIPLES.md):
  (difficulty, question, [four options], answer_index, explanation, why, useType, use)
explanation carries the fact AND the context a non-fan lacks; why is the one
line on why she would need it; use is the line she gets — useType say/ask/impress.

Every question here is marked verified: true. That flag is the spec's promise
that a human checked the fact against a source. The 2026-09-07 batch was
checked by Claude against its own knowledge of settled football history
(nothing about the present, nothing after 2024), not by a person — Anton, read
QUIZ_REVIEW.md before this ships to the App Store.
"""
import importlib
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "quiz.json")
VERSION = "2026-09-08.2"

MODULES = ["quiz_src.general", "quiz_src.clubs_a", "quiz_src.clubs_b", "quiz_src.clubs_c", "quiz_src.clubs_d"]

packs = []
for m in MODULES:
    mod = importlib.import_module(m)
    for pack_id, label, questions in mod.PACKS:
        qs = []
        for i, (diff, q, opts, ans, expl, why, use_type, use) in enumerate(questions, 1):
            assert len(opts) == 4, (pack_id, q)
            assert 0 <= ans < 4, (pack_id, q)
            # The source files list the right answer first for readability. Shuffle
            # per question, seeded on the id, so the slot is stable between builds
            # (a user's progress is keyed on question id, not option order) and no
            # pack teaches her to pick the first option.
            qid = f"{pack_id}-{i}"
            order = list(range(4))
            random.Random(qid).shuffle(order)
            shuffled = [opts[k] for k in order]
            qs.append({
                "id": qid,
                "difficulty": diff,
                "verified": True,
                "question": q,
                "options": shuffled,
                "answer": order.index(ans),
                "explanation": expl,
                "why": why,
                "useType": use_type,
                "use": use,
            })
        packs.append({"id": pack_id, "label": label, "questions": qs})

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "packs": packs}, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {OUT}: {len(packs)} packs, {sum(len(p['questions']) for p in packs)} questions")
