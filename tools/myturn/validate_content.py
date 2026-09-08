#!/usr/bin/env python3
"""validate_content.py — the CI gate for My Turn content.

The four JSON files under ios/GoalDigger/Resources/MyTurn are generated, and
generated text drifts: it runs long, it clumps into one sentence shape, it
slides into American football English, and it asserts facts. Every rule in
the spec's "Validering" section is here, and the build breaks on any of them.

    python3 tools/myturn/validate_content.py            # exit 1 on any error
    python3 tools/myturn/validate_content.py --quiet    # errors only

Also run by tools/myturn/publish_content.sh before it uploads anything.
"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import Counter, defaultdict

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "ios", "GoalDigger", "Resources", "MyTurn")
ID_RE = re.compile(r"^[a-z0-9-]+$")

LIMITS = {"text": 60, "usage": 100, "meaning": 170, "heard": 90, "sayIt": 100, "question": 100, "option": 40, "explanation": 170, "why": 110, "use": 140}

# UK idiom banlist. Generated football English drifts American. Word-boundary,
# case-insensitive; "field" and "tie" are banned outright because the validator
# cannot tell "the field of play" from "midfield" — write pitch, and write draw.
BANNED = {
    r"\bsoccer\b": "soccer → football",
    r"\bcleats?\b": "cleats → boots",
    r"\bfield\b": "field → pitch",
    r"\btied?\b(?! up| down| in)": "tie → draw (a cup match is a 'game' or 'round')",
    r"\bPK\b": "PK → penalty",
    r"\boffense\b": "offense → attack",
    r"\bdefense\b": "defense → defence",
    r"\bzero[- ]zero\b": "zero-zero → nil-nil",
    r"\bschedule\b": "schedule → fixtures",
    r"\bcolor\b": "color → colour",
    r"\bfavorite\b": "favorite → favourite",
    r"\bcenter\b": "center → centre",
}

# Superlatives tied to the present. The first batch called 2006 Arsenal's "only"
# Champions League final; they played the 2026 final. The writer has a knowledge
# cut-off and this script cannot see the present, so the words that go stale
# are banned outright. Write the dated fact instead. "last-minute" is allowed.
SUPERLATIVE = re.compile(
    r"\b(the|their|its|his|club's) only\b"            # "their only final" — the exact shape that went stale
    r"|\bonly (club|team|player|manager|time|final|title|trophy|english|one)\b"
    r"|\b(the|their|its|his) last\b(?! (minute|kick|second|three minutes|game of|day of))|\blast time\b|\bmost recent\b"
    r"|\bmost\b|(?<!world-)(?<!world )\brecord\b(?! at the time)|\b(latest|newest|all-time)\b|more than any other"
    r"|\bstill\b|\bnever\b(?! walk alone)",
    re.I)

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load(name: str) -> dict:
    path = os.path.join(ROOT, name)
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        err(f"{name}: missing")
        return {}
    except json.JSONDecodeError as e:
        err(f"{name}: not valid JSON — {e}")
        return {}
    if not re.match(r"^\d{4}-\d{2}-\d{2}\.\d+$", str(data.get("contentVersion", ""))):
        err(f"{name}: contentVersion must look like 2026-09-07.1")
    return data


def check_len(where: str, field: str, value: str) -> None:
    cap = LIMITS[field]
    if len(value) > cap:
        err(f"{where}: {field} is {len(value)} chars (cap {cap}): {value[:50]}…")


def check_idiom(where: str, value: str) -> None:
    for pat, fix in BANNED.items():
        if re.search(pat, value, re.IGNORECASE):
            err(f"{where}: UK idiom — {fix}: {value[:70]}")


def check_ids(where: str, ids: list[str]) -> None:
    for i in ids:
        if not ID_RE.match(i):
            err(f"{where}: id '{i}' is not kebab-case")
    dupes = [i for i, n in Counter(ids).items() if n > 1]
    for d in dupes:
        err(f"{where}: duplicate id '{d}'")


def first_word(s: str) -> str:
    m = re.match(r"[A-Za-z']+", s.strip())
    return m.group(0).lower() if m else ""


# ---------------------------------------------------------------- saythis
def validate_saythis(d: dict, lingo_ids: set) -> tuple[int, int]:
    sits = d.get("situations", [])
    check_ids("saythis", [s.get("id", "") for s in sits])
    all_lines: list[str] = []
    line_ids: list[str] = []
    groups = Counter()
    for s in sits:
        sid = s.get("id", "?")
        if s.get("group") not in ("moments", "how_its_going", "when_he_asks"):
            err(f"saythis/{sid}: group '{s.get('group')}' invalid")
        groups[s.get("group")] += 1
        if not s.get("label"):
            err(f"saythis/{sid}: no label")
        lines = s.get("lines", [])
        if not 3 <= len(lines) <= 5:
            err(f"saythis/{sid}: {len(lines)} lines (need 3-5)")
        starts = Counter()
        for ln in lines:
            lid = ln.get("id", "?")
            line_ids.append(lid)
            text, usage = ln.get("text", ""), ln.get("usage", "")
            if not text or not usage:
                err(f"saythis/{lid}: text and usage are both required")
            check_len(f"saythis/{lid}", "text", text)
            check_len(f"saythis/{lid}", "usage", usage)
            check_idiom(f"saythis/{lid}", text + " " + usage)
            if ln.get("risk") not in ("safe", "bold"):
                err(f"saythis/{lid}: risk '{ln.get('risk')}' invalid")
            lref = ln.get("lingo")
            if lref is not None and lref not in lingo_ids:
                err(f"saythis/{lid}: lingo '{lref}' does not exist in lingo.json")
            all_lines.append(text)
            starts[first_word(text)] += 1
        for w, n in starts.items():
            if n > 1:
                err(f"saythis/{sid}: {n} lines start with '{w}' — vary the sentence shape")
    check_ids("saythis lines", line_ids)
    for t, n in Counter(all_lines).items():
        if n > 1:
            err(f"saythis: duplicate line text: {t}")
    if len(sits) < 18:
        err(f"saythis: {len(sits)} situations (launch floor 18)")
    if groups["how_its_going"] < groups["moments"]:
        warn("saythis: spec weights 'How it's going' over 'Moments'; it has fewer situations")
    if not any("What did you make of it" in t for t in all_lines):
        err("saythis: the line 'What did you make of it?' must exist (the spec's one required line)")
    return len(sits), len(all_lines)


# ------------------------------------------------------------------ lingo
def validate_lingo(d: dict) -> int:
    terms = d.get("terms", [])
    ids = [t.get("id", "") for t in terms]
    check_ids("lingo", ids)
    seen: set[str] = set()
    term_names = Counter(t.get("term", "").lower() for t in terms)
    for name, n in term_names.items():
        if n > 1:
            err(f"lingo: duplicate term '{name}'")
    for t in terms:
        tid = t.get("id", "?")
        if t.get("category") not in ("rules", "tactics", "match_situations", "culture"):
            err(f"lingo/{tid}: category '{t.get('category')}' invalid")
        meaning, heard, say_it = t.get("meaning", ""), t.get("heard", ""), t.get("sayIt", "")
        if not t.get("term") or not meaning or not heard:
            err(f"lingo/{tid}: term, meaning and heard are all required")
        if not say_it:
            err(f"lingo/{tid}: sayIt is required — a definition without a line to say is not a tool")
        check_len(f"lingo/{tid}", "meaning", meaning)
        check_len(f"lingo/{tid}", "heard", heard)
        check_len(f"lingo/{tid}", "sayIt", say_it)
        check_idiom(f"lingo/{tid}", meaning + " " + heard + " " + say_it)
        for ref in t.get("seeAlso", []) or []:
            if ref not in ids:
                err(f"lingo/{tid}: seeAlso '{ref}' does not exist")
            if ref == tid:
                err(f"lingo/{tid}: seeAlso points at itself")
        seen.add(tid)
    if len(terms) < 120:
        err(f"lingo: {len(terms)} terms (launch floor 120)")
    return len(terms)


# ------------------------------------------------------------------- quiz
def validate_quiz(d: dict) -> tuple[int, int]:
    packs = d.get("packs", [])
    check_ids("quiz packs", [p.get("id", "") for p in packs])
    total = 0
    qids: list[str] = []
    for p in packs:
        pid = p.get("id", "?")
        if not p.get("label"):
            err(f"quiz/{pid}: no label")
        qs = p.get("questions", [])
        if len(qs) < 20:
            err(f"quiz/{pid}: {len(qs)} questions (each pack needs 20)")
        answers = Counter()
        for q in qs:
            qid = q.get("id", "?")
            qids.append(qid)
            if q.get("difficulty") not in (1, 2, 3):
                err(f"quiz/{qid}: difficulty must be 1, 2 or 3")
            if q.get("verified") is not True:
                err(f"quiz/{qid}: verified is not true — a question ships only after a human has checked it")
            question = q.get("question", "")
            check_len(f"quiz/{qid}", "question", question)
            opts = q.get("options", [])
            if len(opts) != 4:
                err(f"quiz/{qid}: {len(opts)} options (need exactly 4)")
            if len(set(o.strip().lower() for o in opts)) != len(opts):
                err(f"quiz/{qid}: duplicate options")
            for o in opts:
                check_len(f"quiz/{qid}", "option", o)
            ans = q.get("answer")
            if not isinstance(ans, int) or not 0 <= ans < len(opts):
                err(f"quiz/{qid}: answer index {ans!r} is not a valid option index")
            else:
                answers[ans] += 1
            expl = q.get("explanation", "")
            if not expl:
                err(f"quiz/{qid}: explanation is required — it is where the learning happens")
            check_len(f"quiz/{qid}", "explanation", expl)
            why, use, use_type = q.get("why", ""), q.get("use", ""), q.get("useType")
            if not why or not use:
                err(f"quiz/{qid}: why and use are required — a fact with no use is not a question (CONTENT_PRINCIPLES.md §1)")
            check_len(f"quiz/{qid}", "why", why)
            check_len(f"quiz/{qid}", "use", use)
            if use_type not in ("say", "ask", "impress"):
                err(f"quiz/{qid}: useType must be say, ask or impress")
            check_idiom(f"quiz/{qid}", question + " " + " ".join(opts) + " " + expl + " " + why + " " + use)
            for field, text in (("question", question), ("explanation", expl), ("why", why), ("use", use)):
                m = SUPERLATIVE.search(text)
                if m:
                    err(f"quiz/{qid}: {field} has a superlative that can go stale ('{m.group(0)}') — write the dated fact: {text[:60]}")
            # Static content must not age: no "current", "this season", "now".
            if re.search(r"\b(this season|currently|right now|current manager|current captain|this year)\b", question + " " + expl, re.I):
                err(f"quiz/{qid}: asks about the present — static content must be finished history: {question}")
        total += len(qs)
        if qs and max(answers.values()) > len(qs) * 0.5:
            warn(f"quiz/{pid}: the correct answer sits in one slot more than half the time")
    check_ids("quiz questions", qids)
    if total < 200:
        err(f"quiz: {total} questions (launch floor 200)")
    return len(packs), total


# ----------------------------------------------------------------- drills
def validate_drills(d: dict, lingo_ok: bool, saythis_ok: bool) -> int:
    decks = d.get("decks", [])
    check_ids("drills decks", [x.get("id", "") for x in decks])
    for deck in decks:
        did = deck.get("id", "?")
        src = deck.get("source")
        if src not in ("saythis", "lingo", "static"):
            err(f"drills/{did}: source '{src}' invalid")
        if not deck.get("label"):
            err(f"drills/{did}: no label")
        if src != "static":
            if deck.get("cards"):
                err(f"drills/{did}: a {src}-sourced deck must not carry its own cards")
            continue
        cards = deck.get("cards", [])
        if len(cards) < 10:
            err(f"drills/{did}: {len(cards)} cards (a session is 10 cards)")
        check_ids(f"drills/{did}", [c.get("id", "") for c in cards])
        for c in cards:
            cid = c.get("id", "?")
            ft = c.get("frontType")
            if ft not in ("image", "text", "kit"):
                err(f"drills/{cid}: frontType '{ft}' invalid")
            back = c.get("back", "")
            if not back:
                err(f"drills/{cid}: back is required")
            if ft == "image":
                path = os.path.join(ROOT, str(c.get("front", "")))
                if not os.path.isfile(path):
                    err(f"drills/{cid}: image '{c.get('front')}' is not in the bundle")
            elif ft == "kit":
                kit = c.get("front")
                if not isinstance(kit, dict):
                    err(f"drills/{cid}: a kit front is an object")
                    continue
                for k in ("primary", "secondary"):
                    if not re.match(r"^#[0-9A-Fa-f]{6}$", str(kit.get(k, ""))):
                        err(f"drills/{cid}: kit.{k} must be a #RRGGBB colour")
                if kit.get("pattern") not in ("plain", "stripes", "hoops", "halves", "sash", "sleeves", "pinstripes", "quarters"):
                    err(f"drills/{cid}: kit.pattern '{kit.get('pattern')}' invalid")
                if kit.get("shorts") is not None and not re.match(r"^#[0-9A-Fa-f]{6}$", str(kit.get("shorts"))):
                    err(f"drills/{cid}: kit.shorts must be a #RRGGBB colour")
            elif not c.get("front"):
                err(f"drills/{cid}: front is required")
            # The back of a Players card is the name only — never "plays for X".
            if did == "players" and re.search(r"\b(plays for|at [A-Z]|of [A-Z])", back):
                err(f"drills/{cid}: a Players back is the name only, never a club — clubs change")
    return len(decks)


def main() -> int:
    quiet = "--quiet" in sys.argv
    saythis = load("saythis.json")
    lingo = load("lingo.json")
    quiz = load("quiz.json")
    drills = load("drills.json")
    n_terms = validate_lingo(lingo) if lingo else 0
    lingo_ids = {t.get("id") for t in lingo.get("terms", [])} if lingo else set()
    n_sit, n_lines = validate_saythis(saythis, lingo_ids) if saythis else (0, 0)
    n_packs, n_q = validate_quiz(quiz) if quiz else (0, 0)
    n_decks = validate_drills(drills, bool(lingo), bool(saythis)) if drills else 0

    if not quiet:
        print(f"saythis: {n_sit} situations, {n_lines} lines")
        print(f"lingo:   {n_terms} terms")
        print(f"quiz:    {n_packs} packs, {n_q} questions")
        print(f"drills:  {n_decks} decks")
    for w in warnings:
        print(f"warn: {w}")
    for e in errors:
        print(f"ERROR: {e}")
    if errors:
        print(f"\n{len(errors)} error(s). The build does not ship this content.")
        return 1
    print("My Turn content: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
