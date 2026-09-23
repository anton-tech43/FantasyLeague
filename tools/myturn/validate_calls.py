"""validate_calls.py — the Called It half of the My Turn gate.

Called from validate_content.py with its err/warn/check_idiom, the way
validate_overheard is. It reads the `calls` key of lingo.json, which
build_lingo.py copies out of lingo_calls.py.

The rule that earns this file is the closed trigger grammar. A call is a
promise that the app can tell her the moment came, and the app can only see
kickoff, goals, half-time and full-time, with side / scorer position / penalty /
own goal / minute inside a goal (CALLED_IT_CONTRACT.md, "What is actually
resolvable"). So an unknown key in a trigger is an error rather than something
ignored: `{"kind": "goal", "header": true}` would validate as "any goal" and
ship a line that fires on the wrong moment for the rest of the season.

The other rule worth naming is the banker cover. An offer is one banker, one
likely and one longshot, and the offer function refuses a slip with no banker,
so every tag the app can be in must be able to reach one. A banker carrying
`any` covers every tag at once, which is the normal way this passes.
"""
from __future__ import annotations

import re
from collections import Counter

from lingo_overheard import WHEN_TAGS
from validate_overheard import CLUBS, EMOJI, STALE_FACT

BANDS = ("banker", "likely", "longshot")
SIDES = ("us", "them", "any")
ROLES = ("Goalkeeper", "Defender", "Midfielder", "Attacker", "any")
ID_RE = re.compile(r"^[a-z0-9-]+$")

# Her line REPLACES the goal push's flavour line rather than riding after it, so
# it gets what is left of the 90-character push body. The arithmetic, so the
# next writer does not have to rediscover it:
#
#     90  the push body budget (goal-push-copy.ts)
#   - 27  the worst-case scorer lead, "Calvert-Lewin 90+3' (pen)."
#   - 13  the wrapper, Called it: "…"
#   = 50
#
# The wrapper is not negotiable: without it a matched push is a bare sentence
# in quotes with nothing saying it was hers, which is the whole feature. So the
# framing stays and the lines get shorter. The contract stores 120; this is
# what actually reaches her.
LINE_CAP = 50
LINE_MIN = 12
MIN_BANKERS = 8
MIN_PER_TAG = 3      # below this an offer for that week keeps handing her the same line
MAX_TAGS = 5

CALL_KEYS = {"id", "line", "trigger", "band", "when"}
CALL_OPTIONAL = {"termId"}

# The closed grammar. Every key a trigger may carry, and what it may hold.
# Anything outside this is refused: see the module docstring.
ENUM = "enum"
BOOL = "bool"
MINUTE = "minute"
TRIGGER_FIELDS: dict[str, dict[str, tuple]] = {
    "goal": {
        "side": (ENUM, SIDES),
        "scorerRole": (ENUM, ROLES),
        "penalty": (BOOL, ()),
        "ownGoal": (BOOL, ()),
        "minuteFrom": (MINUTE, ()),
        "minuteTo": (MINUTE, ()),
    },
    "halftime": {
        "state": (ENUM, ("ahead", "level", "behind")),
        # The feed gives the number, but a line about conceding exactly two is a
        # line about a scoreline she can already read. Only "nothing in" is a call.
        "conceded": (ENUM, (0,)),
    },
    "fulltime": {
        "state": (ENUM, ("win", "draw", "loss")),
        "cleanSheet": (BOOL, ()),
        "comeback": (BOOL, ()),
    },
}
# `side` is the one field with no sensible default: "a goal" and "a goal for us"
# are different calls, and leaving it out would silently mean the first.
TRIGGER_REQUIRED = {"goal": ("side",), "halftime": (), "fulltime": ()}


def validate_calls(calls, *, err, warn, check_idiom, lingo_ids: set) -> int:
    """Returns the number of calls. Every failure is an error, not a warning."""
    if not isinstance(calls, list) or not calls:
        err("calls: lingo.json has no `calls` list — run build_lingo.py")
        return 0

    band_count: Counter = Counter()
    tag_count: Counter = Counter()
    banker_tags: set[str] = set()
    banker_any = False
    ids: list[str] = []
    lines: Counter = Counter()

    for c in calls:
        if not isinstance(c, dict):
            err(f"calls: entry is not an object: {c!r}")
            continue
        cid = c.get("id", "?")
        where = f"calls/{cid}"
        ids.append(cid)
        if not isinstance(cid, str) or not ID_RE.match(cid):
            err(f"{where}: id is not kebab-case")
        extra = set(c) - CALL_KEYS - CALL_OPTIONAL
        if extra:
            err(f"{where}: unknown key(s) {sorted(extra)}; a call is {sorted(CALL_KEYS)} plus optional termId")
        missing = CALL_KEYS - set(c)
        if missing:
            err(f"{where}: missing {sorted(missing)}")
            continue

        # --- line: what she says out loud, so it has to fit in a breath
        line = c["line"]
        if not isinstance(line, str):
            err(f"{where}: line must be a string")
            continue
        lines[line] += 1
        n = len(line)
        if n > LINE_CAP:
            err(f"{where}: line is {n} chars (cap {LINE_CAP}, what the 90-char push has left after the scorer and the wrapper): {line[:50]}…")
        if n < LINE_MIN:
            err(f"{where}: line is {n} chars (min {LINE_MIN}), too short to sound like a person: {line}")
        if "—" in line or "–" in line:
            err(f"{where}: line has an em-dash, write two sentences: {line}")
        if line.count("!") > 1:
            err(f"{where}: line has more than one exclamation mark: {line}")
        if EMOJI.search(line):
            err(f"{where}: line has an emoji")
        if line[0] in "\"“'‘":
            err(f"{where}: line must not be wrapped in quotes, the app supplies them: {line}")
        if line.rstrip()[-1] not in ".!?…":
            err(f"{where}: line must end with . ! ? or …: {line}")
        if CLUBS.search(line):
            err(f"{where}: line names a club; it ships in the binary and is dealt against all twenty: {line}")
        m = STALE_FACT.search(line)
        if m:
            err(f"{where}: line has a dated-fact superlative ('{m.group(0)}'): {line}")
        check_idiom(where, line)

        # --- band
        if c["band"] not in BANDS:
            err(f"{where}: band {c['band']!r} must be one of {', '.join(BANDS)}")
        else:
            band_count[c["band"]] += 1

        # --- when: the Overheard tag vocabulary, unchanged
        when = c["when"]
        if not isinstance(when, list) or not when:
            err(f"{where}: when must be a non-empty list of tags")
            when = []
        bad = [w for w in when if w not in WHEN_TAGS]
        if bad:
            err(f"{where}: when tags {bad} are not in WHEN_TAGS")
        if len(when) != len(set(when)):
            err(f"{where}: duplicate when tag")
        if len(when) > MAX_TAGS:
            err(f"{where}: {len(when)} when tags (max {MAX_TAGS})")
        for w in when:
            if w in WHEN_TAGS:
                tag_count[w] += 1
        if c.get("band") == "banker":
            banker_tags |= {w for w in when if w in WHEN_TAGS}
            banker_any = banker_any or "any" in when

        # --- termId: the words she learned are the words she gets to use
        term = c.get("termId")
        if term is not None and term not in lingo_ids:
            err(f"{where}: termId '{term}' is not a term in lingo.json")

        check_trigger(c.get("trigger"), where=where, err=err)

    # --- the set as a whole
    for i, k in Counter(ids).items():
        if k > 1:
            err(f"calls: duplicate id '{i}'")
    for text, k in lines.items():
        if k > 1:
            err(f"calls: duplicate line: {text}")
    if band_count["banker"] < MIN_BANKERS:
        err(f"calls: {band_count['banker']} bankers (min {MIN_BANKERS}); every offer needs one and she "
            f"would see the same one every week")
    for band in BANDS:
        if not band_count[band]:
            err(f"calls: no '{band}' calls; an offer is one of each and cannot be built")
    for tag, k in sorted(tag_count.items()):
        if k < MIN_PER_TAG:
            err(f"calls: tag '{tag}' has {k} call(s) (min {MIN_PER_TAG}); a slip for that week comes up thin")
    # The offer refuses a slip without a banker, so every tag the app can be in
    # must reach one. `any` bankers are the fill pool and cover the lot.
    if not banker_any:
        uncovered = [t for t in WHEN_TAGS if t not in banker_tags]
        if uncovered:
            err(f"calls: no banker carries 'any', and these tags have no banker of their own: "
                f"{', '.join(uncovered)}. The offer function would refuse to build a slip")
    with_term = sum(1 for c in calls if isinstance(c, dict) and c.get("termId"))
    if with_term * 2 < len(calls):
        warn(f"calls: only {with_term} of {len(calls)} carry a termId; the link back to Lingo is the point")
    return len(calls)


def check_trigger(t, *, where: str, err) -> None:
    """One trigger against the closed grammar. An unknown key is an error."""
    if not isinstance(t, dict):
        err(f"{where}: trigger must be an object, got {t!r}")
        return
    kind = t.get("kind")
    if kind not in TRIGGER_FIELDS:
        err(f"{where}: trigger kind {kind!r} is not resolvable. Only {', '.join(TRIGGER_FIELDS)} push, "
            f"and the push is the delivery (CALLED_IT_CONTRACT.md)")
        return
    grammar = TRIGGER_FIELDS[kind]
    for key in sorted(set(t) - {"kind"} - set(grammar)):
        err(f"{where}: trigger field '{key}' is not in the {kind} grammar ({', '.join(sorted(grammar))}). "
            f"The feed cannot answer it, so the line would fire on the wrong moment")
    for key in TRIGGER_REQUIRED[kind]:
        if key not in t:
            err(f"{where}: a {kind} trigger needs '{key}'")
    # `goal` narrows by existing at all, and side=any is a deliberate widest call.
    # half-time and full-time happen in every match, so a bare one is not a call.
    if kind != "goal" and not set(t) - {"kind"}:
        err(f"{where}: a bare '{kind}' trigger fires in every match; give it a state, a clean sheet or a comeback")
    for key, value in t.items():
        if key == "kind" or key not in grammar:
            continue
        shape, allowed = grammar[key]
        if shape == ENUM and value not in allowed:
            err(f"{where}: trigger {key}={value!r} must be one of {allowed}")
        elif shape == BOOL and not isinstance(value, bool):
            err(f"{where}: trigger {key} must be true or false, got {value!r}")
        elif shape == MINUTE and (isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= 120):
            err(f"{where}: trigger {key} must be a minute 1 to 120, got {value!r}")
    lo, hi = t.get("minuteFrom"), t.get("minuteTo")
    if isinstance(lo, int) and isinstance(hi, int) and lo > hi:
        err(f"{where}: minuteFrom {lo} is after minuteTo {hi}; nothing can match")


if __name__ == "__main__":
    # Self-check: the guards that stop an unshippable line, each fired once.
    # `python3 tools/myturn/validate_calls.py` prints OK or raises.
    ok = dict(id="a-call", line="Told you there'd be a goal.", band="banker", when=["any"],
              trigger=dict(kind="goal", side="any"))

    def run(*calls, ids=None):
        out: list[str] = []
        validate_calls(list(calls), err=out.append, warn=lambda m: None,
                       check_idiom=lambda w, v: None, lingo_ids=ids or {"penalty"})
        return out

    def only(bad, needle, **floors):
        # Eight copies so the banker floor and the per-tag floor never fire instead.
        pack = [dict(ok, id=f"filler-{i}", line=f"Told you there'd be goal number {i}.")
                for i in range(MIN_BANKERS)]
        pack += [dict(ok, id="l", band="likely", line="A point's a point."),
                 dict(ok, id="s", band="longshot", line="An own goal, of all things.")]
        msgs = [m for m in run(*pack, bad) if "filler" not in m]
        assert any(needle in m for m in msgs), f"expected {needle!r}, got {msgs}"

    only(dict(ok, id="x", trigger=dict(kind="goal", side="any", header=True)), "not in the goal grammar")
    only(dict(ok, id="x", trigger=dict(kind="corner", side="any")), "is not resolvable")
    only(dict(ok, id="x", trigger=dict(kind="goal", scorerRole="Winger", side="any")), "must be one of")
    only(dict(ok, id="x", trigger=dict(kind="goal")), "needs 'side'")
    only(dict(ok, id="x", trigger=dict(kind="fulltime")), "fires in every match")
    only(dict(ok, id="x", trigger=dict(kind="goal", side="us", minuteFrom=80, minuteTo=20)), "is after minuteTo")
    only(dict(ok, id="x", line="It's a proper Arsenal goal, that."), "names a club")
    only(dict(ok, id="x", line="A goal " + "and another " * 8 + "one."), "cap 50")
    only(dict(ok, id="x", line="Their only final, and it's gone in."), "dated-fact superlative")
    only(dict(ok, id="x", band="nailed-on"), "must be one of")
    only(dict(ok, id="x", when=["matchday"]), "not in WHEN_TAGS")
    only(dict(ok, id="x", termId="not-a-term"), "is not a term")
    only(dict(ok, id="x", side="us"), "unknown key")
    assert any("duplicate id" in m for m in run(ok, dict(ok, band="likely"), dict(ok, band="longshot")))
    assert any("duplicate line" in m for m in run(ok, dict(ok, id="b", band="likely")))
    assert any("bankers (min" in m for m in run(ok, dict(ok, id="b", band="likely", line="A point's a point."),
                                                dict(ok, id="c", band="longshot", line="An own goal, that.")))
    # No banker carries `any`, so the tags that have no banker of their own are named.
    derby = [dict(ok, id=f"d-{i}", when=["derby"], line=f"Against this lot, goal {i}.")
             for i in range(MIN_BANKERS)]
    assert any("would refuse to build a slip" in m
               for m in run(*derby, dict(ok, id="l", band="likely", when=["derby"], line="A point's a point."),
                            dict(ok, id="s", band="longshot", when=["derby"], line="An own goal, of all things.")))
    print("validate_calls self-check: OK")
