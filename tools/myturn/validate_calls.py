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
from validate_overheard import CLUBS, EMOJI, PROPER_OK, STALE_FACT, content_words, norm

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
CALL_OPTIONAL = {"termId", "situation", "cue"}

# `situation` and `cue` answer the two questions Anton asked of the card: when
# do I get this, and why would I want it. Neither enters the push body, so
# neither carries LINE_CAP; what caps them is the card. `situation` is one line
# above the quote and `cue` is one or two under it, so the caps are the wrap
# point and the warns are where a phone at the largest text size starts to.
#
# The minimums are the real rule. "When they score" is a `cue` that has
# restated its own situation and told her nothing; 30 characters is roughly
# where a second clause has to start.
SITUATION_CAP, SITUATION_WARN, SITUATION_MIN = 72, 54, 20
CUE_CAP, CUE_WARN, CUE_MIN = 110, 88, 30

# The ten kinds of line the content pass cut (CALLED_IT_CONTRACT.md, "What the
# feed cannot say"). They were unenforceable while a call was a trigger plus a
# shout: "We have given him far too much space there" names no mechanism the
# validator can see. `situation` changed that, because it is prose ABOUT the
# trigger, so a writer promising her a corner now says the word out loud.
UNRESOLVABLE = [
    # "heads one in" is a header written without the noun, which is how it got
    # past the first draft of this row.
    (re.compile(r"\bheaders?\b|\bheaded\b|\bheads? (it|one) (in|home|down)\b|\bnods? it (in|down)\b", re.I),
     "a header"),
    (re.compile(r"\bcorners?\b", re.I), "a corner"),
    (re.compile(r"\bcrosses?\b|\bcrossed\b", re.I), "a cross"),
    (re.compile(r"\bfree[- ]kicks?\b", re.I), "a free kick"),
    (re.compile(r"\bred cards?\b|\bsent off\b|\bsending off\b|\bten men\b", re.I), "a red card"),
    (re.compile(r"\bbookings?\b|\bbooked\b|\byellows?\b", re.I), "a booking"),
    (re.compile(r"\bsubs?\b|\bsubbed\b|\bsubstitut\w+\b", re.I), "a substitution"),
    (re.compile(r"\bVAR\b"), "VAR"),
    (re.compile(r"\boffside\b", re.I), "offside"),
    (re.compile(r"\bbraces?\b|\bhat[- ]tricks?\b", re.I), "a brace or a hat-trick"),
    (re.compile(r"\bsaves?\b|\bsaved\b|\bhowlers?\b", re.I), "a save or a howler"),
    (re.compile(r"\bpossession\b", re.I), "possession"),
    (re.compile(r"\bnil[- ]nil\b|\bgoalless\b|\b0[- ]0\b", re.I), "nil-nil"),
    (re.compile(r"\bgoal difference\b|\bmargins?\b", re.I), "a margin"),
]

# --- the agreement table. One row per trigger facet, each with a `required`
# half (the trigger has it, so the situation must say it) and a `forbidden`
# half (the trigger has not got it, so the situation must not promise it). The
# forbidden half is the one that earns the table: "their striker scores from
# the spot" on a trigger with no `penalty` key fires on every open-play goal
# for the rest of the season and nothing else would catch it.
KIND_SAYS = {
    "goal": re.compile(r"\b(scor\w+|goals?|nets?|one goes in|it goes in)\b", re.I),
    "halftime": re.compile(r"\b(half-?time|the break|the interval)\b", re.I),
    "fulltime": re.compile(r"\b(full-?time|final whistle|at the end|by the end|when it (is )?over|finish\w*)\b", re.I),
}
# Narrower than the required half on purpose. "before half-time" and "after the
# break" are how a goal's minute window is said out loud, so only the phrasing
# that names the whistle ITSELF as the moment is refused.
KIND_DENIES = {
    "goal": re.compile(r"\b(scores|scoring)\b|\b(we|they) score\b", re.I),
    "halftime": re.compile(r"\bat half-?time\b|\bat the break\b|\bat the interval\b", re.I),
    "fulltime": re.compile(r"\b(full-?time|final whistle)\b", re.I),
}
SIDE_SAYS = {
    "us": re.compile(r"\b(we|we're|us|our|ours)\b", re.I),
    "them": re.compile(r"\b(they|they're|them|their|theirs)\b", re.I),
}
# `side: any` is the widest call in the file and the easiest to quietly narrow:
# "if they score" on it reads as a promise and fires on ours too. A call that
# does not care which end it went in at must not name an end.
SIDE_ANY_DENIES = re.compile(r"\b(we|we're|us|our|ours|they|they're|them|their|theirs)\b", re.I)
ROLE_SAYS = {
    "Goalkeeper": re.compile(r"\b(keepers?|goalkeepers?)\b", re.I),
    "Defender": re.compile(r"\b(defenders?|centre-halfs?|centre-backs?|full-backs?|back four)\b", re.I),
    "Midfielder": re.compile(r"\b(midfield|midfielders?)\b", re.I),
    "Attacker": re.compile(r"\b(strikers?|forwards?|front ?man|number nine)\b", re.I),
}
ROLE_DENIES = re.compile("|".join(p.pattern for p in ROLE_SAYS.values()), re.I)
PENALTY_SAYS = re.compile(r"\b(penalty|penalties|from the spot|spot[- ]kick)\b", re.I)
OWNGOAL_SAYS = re.compile(r"\b(own goal|own net|his own)\b", re.I)
HT_STATE_SAYS = {
    "ahead": re.compile(r"\b(ahead|in front|leading|winning)\b", re.I),
    "level": re.compile(r"\b(level|all square)\b", re.I),
    "behind": re.compile(r"\b(behind|losing)\b", re.I),
}
HT_STATE_DENIES = re.compile("|".join(p.pattern for p in HT_STATE_SAYS.values()), re.I)
FT_STATE_SAYS = {
    "win": re.compile(r"\b(wins?|winning|won|beat|three points|in front (at|when))\b", re.I),
    "draw": re.compile(r"\b(draws?|drawn|a point|share the points|honours even)\b", re.I),
    "loss": re.compile(r"\b(lose|losing|lost|beaten|defeat)\b", re.I),
}
FT_STATE_DENIES = re.compile("|".join(p.pattern for p in FT_STATE_SAYS.values()), re.I)
# `conceded: 0` at half-time and `cleanSheet` at full-time are the same English.
# Note what it is NOT allowed to become: the feed cannot see whether WE have
# scored, so "nothing at either end" is a lie and the banlist refuses it.
CLEAN_SAYS = re.compile(
    r"\b(clean sheet|nobody has (put|got|had) one past|nothing past us|nothing in at"
    r"|not conceded|have not conceded|haven'?t conceded|without (letting|conceding)"
    r"|not let one in|haven'?t let one in|kept them out)\b", re.I)
COMEBACK_SAYS = re.compile(r"\b(from behind|comeback|come back|came back|turn(ed)? it around)\b", re.I)

# --- the minute window table. Each phrase claims a window; the trigger holds
# one. Three ways they can disagree and all three are errors: the phrase
# reaching minutes the app will never mark, a trigger that narrows in silence
# (she is promised any goal and gets one in eleven), and a phrase on a trigger
# with no minute key at all, which is the same lie the other way round.
#
# The vocabulary is `LingoCalls.window(from:to:)`'s, so a hand-written situation
# and the derived fallback say the same thing about the same trigger.
MINUTE_PHRASES = [
    (re.compile(r"\b(?:in|inside|within) (?:the )?first ten minutes\b", re.I), 1, 10),
    (re.compile(r"\b(?:in|inside|within) (?:the )?first twenty minutes\b", re.I), 1, 20),
    (re.compile(r"\bbefore (?:half-?time|the break)\b|\bin the first half\b", re.I), 1, 45),
    (re.compile(r"\bin the first hour\b|\binside the hour\b", re.I), 1, 60),
    (re.compile(r"\bafter (?:half-?time|the break)\b|\bin the second half\b", re.I), 46, 120),
    (re.compile(r"\blate on\b", re.I), 61, 120),
    (re.compile(r"\bin the last ten minutes\b", re.I), 76, 120),
    (re.compile(r"\bin the last few minutes\b", re.I), 86, 120),
    (re.compile(r"\bin the last couple of minutes\b", re.I), 88, 120),
    (re.compile(r"\bin (?:added|stoppage|injury) time\b", re.I), 90, 120),
]

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
    situations: Counter = Counter()
    cues: Counter = Counter()

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

        # --- situation and cue: optional today, because 47 of the 59 are still
        # on the derived fallback. Anything that IS written gets the lot.
        sit, cue = c.get("situation"), c.get("cue")
        if sit is not None:
            if check_voice(sit, where=where, field="situation", cap=SITUATION_CAP,
                           warn_at=SITUATION_WARN, minimum=SITUATION_MIN,
                           err=err, warn=warn, check_idiom=check_idiom):
                situations[norm(sit)] += 1
                check_agreement(c.get("trigger"), sit, where=where, err=err)
                check_minutes(c.get("trigger"), sit, where=where, err=err)
        if cue is not None:
            if check_voice(cue, where=where, field="cue", cap=CUE_CAP, warn_at=CUE_WARN,
                           minimum=CUE_MIN, err=err, warn=warn, check_idiom=check_idiom):
                cues[norm(cue)] += 1
                # A cue that only restates its situation has answered "when" twice
                # and "why would I want it" not at all, which was the whole
                # complaint. Normalised equality catches the copy-paste; the
                # content-word subset catches the reword.
                if isinstance(sit, str):
                    cw_sit, cw_cue = content_words(sit), content_words(cue)
                    if norm(cue) == norm(sit) or (cw_cue and cw_cue <= cw_sit):
                        err(f"{where}: cue restates situation and adds nothing. The situation says when; "
                            f"the cue has to say why she would want it: {cue}")

    # --- the set as a whole
    for i, k in Counter(ids).items():
        if k > 1:
            err(f"calls: duplicate id '{i}'")
    for text, k in lines.items():
        if k > 1:
            err(f"calls: duplicate line: {text}")
    # Two cards reading the same are one card she is asked about twice: the
    # offer draws one per band and nothing stops both of them being written.
    for text, k in situations.items():
        if k > 1:
            err(f"calls: duplicate situation: {text}")
    for text, k in cues.items():
        if k > 1:
            err(f"calls: duplicate cue: {text}")
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


def check_voice(text, *, where: str, field: str, cap: int, warn_at: int, minimum: int,
                err, warn, check_idiom) -> bool:
    """The rules `line` already lives under, on the two fields beside it.

    Returns False when the value is unusable, so the callers that read it after
    this do not run against a number or an empty string.

    One difference from `line`, and it is deliberate: a capitalised word
    mid-sentence is an ERROR here rather than the warning it is in Overheard.
    `situation` is prose about football on a card that ships in the binary, and
    it is exactly where a writer reaches for a player's name to make the moment
    concrete. A name goes stale the week he is sold.
    """
    if not isinstance(text, str):
        err(f"{where}: {field} must be a string, got {text!r}")
        return False
    if not text.strip():
        err(f"{where}: {field} is empty; leave the key out and the card falls back to the trigger")
        return False
    n = len(text)
    if n > cap:
        err(f"{where}: {field} is {n} chars (cap {cap}); it has one line on the card: {text[:60]}…")
    elif n > warn_at:
        warn(f"{where}: {field} is {n} chars (aim under {warn_at}, it wraps at a large text size): {text[:60]}…")
    if n < minimum:
        err(f"{where}: {field} is {n} chars (min {minimum}), too short to answer the question: {text}")
    if "—" in text or "–" in text:
        err(f"{where}: {field} has an em-dash, write two sentences: {text}")
    if text.count("!") > 1:
        err(f"{where}: {field} has more than one exclamation mark: {text}")
    if EMOJI.search(text):
        err(f"{where}: {field} has an emoji")
    if text[0] in "\"“'‘":
        err(f"{where}: {field} must not be wrapped in quotes; only the line is quoted: {text}")
    if text.rstrip()[-1] not in ".!?…":
        err(f"{where}: {field} must end with . ! ? or …: {text}")
    if CLUBS.search(text):
        err(f"{where}: {field} names a club; it ships in the binary and is dealt against all twenty: {text}")
    m = STALE_FACT.search(text)
    if m:
        err(f"{where}: {field} has a dated-fact superlative ('{m.group(0)}'): {text}")
    for w in re.findall(r"(?<=[a-z,;] )([A-Z][\w'’]+)", text):
        if w not in PROPER_OK:
            err(f"{where}: '{w}' is capitalised mid-sentence in {field}. A living person goes stale the "
                f"week he is sold, and this file cannot see the present: {text}")
    check_idiom(where, text)
    for pat, what in UNRESOLVABLE:
        m = pat.search(text)
        if m:
            err(f"{where}: {field} promises {what} ('{m.group(0)}'), which no push carries, so the app can "
                f"never tell her the moment came (CALLED_IT_CONTRACT.md): {text}")
    return True


def check_agreement(t, situation: str, *, where: str, err) -> None:
    """The hand-written situation against the machine-readable trigger.

    Every row is a facet with two halves. Required: the trigger holds it, so the
    card has to say it, or she is being narrowed in silence. Forbidden: the
    trigger does not hold it, so the card must not promise it, or the line fires
    on every other one of that shape too.
    """
    if not isinstance(t, dict):
        return
    kind = t.get("kind")
    if kind not in TRIGGER_FIELDS:
        return      # check_trigger has already refused it; one complaint is enough

    def need(pat, facet: str) -> None:
        if not pat.search(situation):
            err(f"{where}: the trigger narrows to {facet} and the situation does not say so. She would be "
                f"offered a moment the app only marks some of the time: {situation}")

    def deny(pat, facet: str) -> None:
        m = pat.search(situation)
        if m:
            err(f"{where}: situation promises {facet} ('{m.group(0)}') but the trigger has no key for it, so "
                f"the line fires on every other one as well: {situation}")

    for k, pat in KIND_SAYS.items():
        if kind == k:
            need(pat, f"a {k} moment")
        else:
            deny(KIND_DENIES[k], f"a {k} moment")

    # goal-only facets --------------------------------------------------------
    own_goal = t.get("ownGoal") is True
    if kind == "goal":
        # An own goal is credited to the side that BENEFITED (API-Football, and
        # `LingoCalls.goalMoment` reads it the same way), so on `side: us` with
        # `ownGoal` the man who put it in plays for THEM. The pronoun the
        # situation owes her is the other one.
        side = t.get("side")
        if own_goal:
            side = {"us": "them", "them": "us"}.get(side, side)
        if side in SIDE_SAYS:
            need(SIDE_SAYS[side], "our end" if side == "us" else "their end")
        elif side == "any":
            deny(SIDE_ANY_DENIES, "one particular side")

    role = t.get("scorerRole")
    if kind == "goal" and role in ROLE_SAYS:
        need(ROLE_SAYS[role], f"a {role}")
    else:
        deny(ROLE_DENIES, "a particular position")

    if t.get("penalty") is True:
        need(PENALTY_SAYS, "a penalty")
    else:
        deny(PENALTY_SAYS, "a penalty")
    if own_goal:
        need(OWNGOAL_SAYS, "an own goal")
    else:
        deny(OWNGOAL_SAYS, "an own goal")

    # halftime ---------------------------------------------------------------
    state = t.get("state")
    if kind == "halftime" and state in HT_STATE_SAYS:
        need(HT_STATE_SAYS[state], f"being {state} at the break")
    elif kind == "halftime":
        deny(HT_STATE_DENIES, "a half-time scoreline")

    # fulltime ---------------------------------------------------------------
    if kind == "fulltime" and state in FT_STATE_SAYS:
        need(FT_STATE_SAYS[state], f"a {state}")
    elif kind == "fulltime":
        deny(FT_STATE_DENIES, "a result")
    if t.get("comeback") is True:
        need(COMEBACK_SAYS, "coming from behind")
    else:
        deny(COMEBACK_SAYS, "coming from behind")

    # the clean sheet, spelled `conceded: 0` at the break and `cleanSheet` at the end
    if t.get("conceded") == 0 or t.get("cleanSheet") is True:
        need(CLEAN_SAYS, "nothing conceded")
    else:
        deny(CLEAN_SAYS, "nothing conceded")


def check_minutes(t, situation: str, *, where: str, err) -> None:
    """The window the phrase claims against the window the trigger holds."""
    if not isinstance(t, dict):
        return
    lo, hi = t.get("minuteFrom"), t.get("minuteTo")
    lo = lo if isinstance(lo, int) and not isinstance(lo, bool) else 1
    hi = hi if isinstance(hi, int) and not isinstance(hi, bool) else 120
    narrowed = "minuteFrom" in t or "minuteTo" in t
    found = [(p, a, b) for p, a, b in MINUTE_PHRASES if p.search(situation)]

    if narrowed and not found:
        err(f"{where}: the trigger only marks minutes {lo} to {hi} and the situation says nothing about "
            f"when. That is the narrowing she cannot see: {situation}")
    for pat, a, b in found:
        phrase = pat.search(situation).group(0)
        if not narrowed:
            err(f"{where}: situation says '{phrase}' but the trigger carries no minuteFrom or minuteTo, so "
                f"the line fires at any point in the match: {situation}")
        elif a < lo or b > hi:
            err(f"{where}: situation says '{phrase}' (minutes {a} to {b}) but the trigger only marks {lo} "
                f"to {hi}. She is promised minutes the app will never mark: {situation}")


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
    # --- situation and cue. `only` is not enough for these: a badly written
    # situation trips two or three rows at once by accident, and a guard that
    # can only be seen next to another is a guard nobody will trust. So each
    # case has to be the ONLY complaint the pack produces.
    SIT = "If anybody scores, at either end of the pitch."
    CUE = "Say it as the net moves, whoever got it. Almost every match hands you this one."
    good = dict(ok, id="x", situation=SIT, cue=CUE)

    def once(bad, needle):
        pack = [dict(ok, id=f"filler-{i}", line=f"Told you there'd be goal number {i}.")
                for i in range(MIN_BANKERS)]
        pack += [dict(ok, id="l", band="likely", line="A point's a point."),
                 dict(ok, id="s", band="longshot", line="An own goal, of all things.")]
        msgs = [m for m in run(*pack, bad) if "filler" not in m]
        assert len(msgs) == 1 and needle in msgs[0], f"expected exactly {needle!r}, got {msgs}"

    assert not [m for m in run(good) if "x" in m.split(":")[0]], "the good pair must pass"

    # 1. the voice rules `line` already gets, on both fields
    once(dict(good, situation=SIT[:-1] + " at any point in the whole ninety minutes."), "cap 72")
    once(dict(good, situation="A goal."), "min 20")
    once(dict(good, cue=CUE + " " + CUE), "cap 110")
    once(dict(good, cue="Say it early."), "min 30")
    once(dict(good, situation="If anybody scores — at either end."), "em-dash")
    once(dict(good, situation=SIT[:-1]), "must end with")
    once(dict(good, situation='"' + SIT), "must not be wrapped in quotes")
    # A made-up surname, because the guard is about the SHAPE of a name: this is
    # the field where a writer types the striker he is picturing.
    once(dict(good, cue="Say it as the net moves, the way Ramsgate does it every week."), "capitalised mid-sentence")

    # 2. the unresolvable-vocabulary banlist, newly enforceable because the
    #    situation is prose about the trigger
    once(dict(good, situation="If anybody scores with a header, at either end."), "a header")
    once(dict(good, cue="Say it as the net moves. A corner is where half of them come from."), "a corner")

    # 3. situation and trigger agree, both halves
    once(dict(good, trigger=dict(kind="goal", side="any", penalty=True)), "narrows to a penalty")
    once(dict(good, situation="If anybody scores from the spot, at either end."), "promises a penalty")
    once(dict(good, situation="If they score, whoever gets it."), "promises one particular side")
    once(dict(good, situation="If a striker scores, at either end."), "promises a particular position")
    # An own goal is credited to the side that BENEFITED, so `side: us` wants
    # one of THEIRS. Getting it the wrong way round is why the row inverts.
    once(dict(good, trigger=dict(kind="goal", side="us", ownGoal=True),
              situation="If one of ours puts it into his own net."), "narrows to their end")

    # 4. the minute window
    once(dict(good, trigger=dict(kind="goal", side="any", minuteTo=10),
              situation="If a goal goes in before half-time."), "never mark")
    once(dict(good, trigger=dict(kind="goal", side="any", minuteFrom=46)), "says nothing about when")
    once(dict(good, situation="If a goal goes in inside the first ten minutes."), "no minuteFrom or minuteTo")

    # 5. set level
    once(dict(good, cue="Anybody scores, at either end of the pitch."), "restates situation")
    assert any("duplicate situation" in m
               for m in run(good, dict(good, id="y", band="likely", line="A point's a point.", cue=CUE + " Twice.")))
    assert any("duplicate cue" in m
               for m in run(good, dict(good, id="y", band="likely", line="A point's a point.",
                                       situation="If we score, whoever gets it.")))
    print("validate_calls self-check: OK")
