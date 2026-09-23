"""validate_overheard.py — the Overheard game's half of validate_lingo.

Called from validate_content.py with its err/warn/check_idiom/SUPERLATIVE.
Kept in its own file because the rules are many and self-contained: what she
hears (overheard), who says it (speaker), the right option (gist), the two
wrong ones (decoys) and when the word is dealt (when).

Overheard is speech, so only the shapes that encode a dated fact are banned
there (STALE_FACT). Gist and decoys are definitions and get the full
SUPERLATIVE regex: "final day" not "the last day".

An entry may also carry player variants: the same card with one
{ours|theirs}.{keeper|defender|midfielder|forward} slot, filled on the phone
from the fixture's squads. Those get every rule the plain line gets, measured
on the rendered line rather than the template, plus the rules in check_variant.
The one rule no script can check is the one that matters most: a templated line
may say what a player *is*, never what he did or that he will play.
"""
from __future__ import annotations

import re
from collections import Counter, defaultdict

from lingo_match import term_match
from lingo_overheard import MOMENTS, SLOTS, SPEAKERS, WHEN_TAGS

LIMITS = {"overheard": 120, "gist": 60, "decoy": 60}
MIN_LEN = {"overheard": 20, "gist": 12, "decoy": 12}
OVERHEARD_COMFORT = 100        # warn above: four lines on a small phone
BAND = 20                      # a decoy may differ from the gist by this many chars
MIN_PER_TAG = 5
MIN_ANY = 60
# The end-of-round commitment draws only from `anytime` and `common`: a `rare`
# line commits her to a moment that never arrives, and then asks whether she
# said it. Floors so those two bands cannot be reclassified down to nothing.
# The `anytime` floor counts only words that are actually dealt, because four
# of them are `basic` and never reach a round.
MIN_ANYTIME = 40
MIN_COMMON = 40
MAX_ALIASES = 3
# `basic` words are never dealt, so every one marked is a word out of the pool.
# A floor guard, not a style rule: mark everything and the deck empties.
MAX_BASIC = 15

# --- player variants: a line with one {ours|theirs}.{keeper|…} slot, filled on
# the phone from the fixture's squads. Everything here is measured on the
# RENDERED line, not the template, which is the rule goal-push-copy.ts already
# follows: a cap on a string with a hole in it measures nothing.
SLOT_RE = re.compile(r"\{([^{}]*)\}")
NAME_CAP = 22        # PlayerSlots refuses a display name longer than this, which is what makes the arithmetic a guarantee
NAME_FLOOR = 3       # "Son" — the shortest surname the feed prints
SLOT_FILLER = "someone"       # lowercase and meaningless: a slot must never trip the club or capitalised-word checks
SAYIT_CAP = 100               # the cap validate_content puts on the plain sayIt
VARIANT_OVERHEARD_CAP = 90    # tighter than the plain 120: a name must not push the bubble to four lines
MAX_VARIANTS = 2
# Coverage: below these the feature is invisible in a round of seven.
MIN_VARIANT_TERMS = 30
MIN_PER_SLOT = 3
MIN_VARIANT_ANY = 20

STALE_FACT = re.compile(
    r"\b(the|their|its|his|club's) only (club|team|player|manager|time|final|title|trophy|english)\b"
    r"|\b(latest|newest|all-time)\b|(?<!world-)(?<!world )\brecord\b(?! at the time)"
    r"|more than any other|\bin history\b|\b(best|worst|biggest) ever\b", re.I)
DEFINES = re.compile(r"\b(means|meaning|is when|is called|refers to|in other words|basically|which is|i\.e\.)\b", re.I)
EMOJI = re.compile(r"[\U0001F000-\U0001FFFF☀-➿]")
CLUBS = re.compile(
    r"\b(Arsenal|Chelsea|Liverpool|Everton|Spurs|Tottenham|Man(chester)? (City|Utd|United)|Newcastle|Sunderland"
    r"|Leeds|Villa|Fulham|Brentford|Brighton|Palace|Forest|Bournemouth|Coventry|Hull|Ipswich|West Ham|Wolves|Burnley)\b")
CLUB_OK = {"kop", "the-boot-room", "the-invincibles", "tiki-taka"}   # the meaning already names the club
# Capitalised words allowed mid-sentence in overheard. Anything else capitalised
# is probably a person, and a current person is the one staleness nobody can
# validate against the present. Warn, not error.
PROPER_OK = {
    "VAR", "MOTD", "BBC", "Sky", "FA", "UEFA", "FIFA", "PL", "Cup", "League", "Premier", "Championship",
    "Champions", "Europa", "Conference", "Wembley", "Anfield", "Kop", "Fergie", "Ferguson", "Twitter",
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "January", "February",
    "March", "April", "May", "June", "July", "August", "September", "October", "November", "December",
    "Christmas", "Boxing", "Day", "Europe", "England", "English", "Row", "Z", "I", "I'm", "I'll", "I've",
    "Ref", "Lino", "Keeper", "God", "Tuesday's", "Saturday's", "Sunday's", "Ten", "Two", "Three", "Four",
    "Five", "Six", "Seven", "Eight", "Nine", "Ninety", "Route", "One", "Tube", "OK", "TV", "Deadline",
}


STEM_OK = {"there", "their", "about", "match", "games", "going", "think", "would", "could", "still", "never",
           "every", "again", "right", "which", "where", "whole", "other", "thing", "thats", "youre", "theyr", "after",
           "befor", "playe", "score", "goals"}   # "player"/"score"/"goal" are the wallpaper of every line


def aliases_words(aliases) -> set[str]:
    out: set[str] = set()
    for a in aliases or ():
        out |= content_words(a)
    return out


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", s.lower()).strip()


def content_words(s: str) -> set[str]:
    return {w for w in re.findall(r"[a-z']+", s.lower()) if len(w) >= 4}


def first_word(s: str) -> str:
    m = re.match(r"[A-Za-z']+", s.strip())
    return m.group(0).lower() if m else ""


def render(text: str, name: str) -> str:
    """The line as she reads it, with every slot filled by one name."""
    return SLOT_RE.sub(name, text)


def defang(text: str) -> tuple[str, list[tuple[int, int]]]:
    """The line with each slot replaced by a lowercase, opaque filler, plus where the fillers landed.

    Every prose rule runs against this, so a slot can never be mistaken for a
    club, a proper noun or the term itself.
    """
    out: list[str] = []
    spans: list[tuple[int, int]] = []
    i = n = 0
    for m in SLOT_RE.finditer(text):
        out.append(text[i:m.start()])
        n += m.start() - i
        spans.append((n, n + len(SLOT_FILLER)))
        out.append(SLOT_FILLER)
        n += len(SLOT_FILLER)
        i = m.end()
    out.append(text[i:])
    return "".join(out), spans


def strip_slots(text: str) -> str:
    return re.sub(r"\s+", " ", SLOT_RE.sub(" ", text)).strip()


def check_variant(t: dict, v: dict, idx: int, *, err, check_idiom,
                  term_stems: set[str], gist_stems: set[str], decoy_stems: set[str]) -> str | None:
    """One player variant, against every rule the plain line gets and six of its own.

    Returns the declared slot when it is one of the eight, else None.
    """
    tid = t.get("id", "?")
    term = t.get("term", "")
    where = f"lingo/{tid}/player[{idx}]"
    slot = v.get("slot")
    o, say = v.get("overheard"), v.get("sayIt")
    if not isinstance(o, str) or not isinstance(say, str) or not o or not say:
        err(f"{where}: a variant needs overheard and sayIt, got {v!r}")
        return None
    if slot not in SLOTS:
        err(f"{where}: slot {slot!r} is not one of {', '.join(SLOTS)}. There is no winger slot: "
            f"the only trustworthy position data has four buckets, so a forward line must be true of a winger too")
        slot = None

    # --- the slot itself: exactly one, the declared one, and present in the bubble
    used = {m.group(1) for m in SLOT_RE.finditer(o)} | {m.group(1) for m in SLOT_RE.finditer(say)}
    if slot and used != {slot}:
        err(f"{where}: declares '{slot}' but the lines use {sorted(used) or 'no slot at all'}; "
            f"one slot per variant, and it must be the declared one")
    if slot and slot not in {m.group(1) for m in SLOT_RE.finditer(o)}:
        err(f"{where}: '{{{slot}}}' is only in sayIt. The named card is the bubble; put it in overheard")

    # --- caps and floors on the rendered worst cases, never on the template
    long_o, short_o = render(o, "W" * NAME_CAP), render(o, "W" * NAME_FLOOR)
    if len(long_o) > VARIANT_OVERHEARD_CAP:
        err(f"{where}: overheard renders to {len(long_o)} chars with a {NAME_CAP}-character name "
            f"(cap {VARIANT_OVERHEARD_CAP}), which is four lines on a small phone: {o}")
    if len(short_o) < MIN_LEN["overheard"]:
        err(f"{where}: overheard renders to {len(short_o)} chars with a {NAME_FLOOR}-character name "
            f"(min {MIN_LEN['overheard']}); the slot is padding a line too short to sound like a person: {o}")
    long_s = render(say, "W" * NAME_CAP)
    if len(long_s) > SAYIT_CAP:
        err(f"{where}: sayIt renders to {len(long_s)} chars with a {NAME_CAP}-character name (cap {SAYIT_CAP}): {say}")

    # --- every plain-overheard rule, re-run on the variant
    defanged, spans = defang(o)
    for field, text in (("overheard", o), ("sayIt", say)):
        if "—" in text or "–" in text:
            err(f"{where}: {field} has an em-dash, write two sentences: {text[:60]}")
    if o[0] in "\"“'‘":
        err(f"{where}: overheard must not be wrapped in quotes, the bubble supplies them")
    if o.rstrip()[-1] not in ".!?…":
        err(f"{where}: overheard must end with . ! ? or …: {o}")
    if o.count("!") > 1:
        err(f"{where}: overheard has more than one exclamation mark: {o}")
    if EMOJI.search(o):
        err(f"{where}: overheard has an emoji")
    m = DEFINES.search(defanged)
    if m:
        err(f"{where}: overheard defines the term ('{m.group(0)}') instead of using it: {o}")
    m = STALE_FACT.search(defanged)
    if m:
        err(f"{where}: overheard has a dated-fact superlative ('{m.group(0)}'): {o}")
    if CLUBS.search(defanged) and tid not in CLUB_OK:
        err(f"{where}: overheard names a club, write they/we/this lot: {o}")
    # Warn on a plain line, error here: the variant is exactly where a writer is
    # tempted to hand-write a name to show what the slot will look like.
    for w in re.findall(r"(?<=[a-z,;] )([A-Z][\w'’]+)", defanged):
        if w not in PROPER_OK and w.lower() not in norm(term):
            err(f"{where}: '{w}' is capitalised mid-sentence. The name comes from the slot, never from the file: {o}")
    check_idiom(where, defanged)
    check_idiom(where, defang(say)[0])

    # --- the term must still be found, and not inside the name
    hit = term_match(term, tid, t.get("aliases") or [], defanged)
    if not hit:
        err(f"{where}: overheard does not contain '{term}' (or an alias): {o}")
    else:
        clean = [m for m in re.finditer(re.escape(hit), defanged)
                 if all(m.end() <= s or m.start() >= e for s, e in spans)]
        if not clean:
            err(f"{where}: '{term}' is only matched inside the slot, so the app would bold the player's name: {o}")

    # --- the bubble must not hand over the answer, gist and decoys being inherited
    bubble = {w[:5] for w in content_words(strip_slots(o)) if len(w) >= 5} - term_stems - STEM_OK
    leak = (bubble & gist_stems) - decoy_stems
    if leak:
        err(f"{where}: '{sorted(leak)[0]}…' is in the bubble and only in the inherited gist, "
            f"the bubble hands over the answer: {o}")

    # --- a variant that is the plain line with a name dropped in is not a variant
    plain_o = t.get("overheard") or ""
    plain_say = (t.get("sayIt") or "").strip("\"“”")
    bare_o, bare_say = strip_slots(o), strip_slots(say)
    if norm(bare_o) == norm(plain_o):
        err(f"{where}: overheard is the plain line with a slot dropped in. Rewrite it around the name: {o}")
    if norm(bare_o) == norm(plain_say) or norm(bare_o) == norm(bare_say.strip("\"“”")):
        err(f"{where}: overheard is sayIt copied over. sayIt is her line back; overheard is the line that made her need one")
    if norm(bare_say.strip("\"“”")) == norm(plain_say):
        err(f"{where}: sayIt is the plain sayIt with a slot dropped in: {say}")
    return slot


def validate_overheard(terms: list[dict], *, err, warn, check_idiom, superlative: re.Pattern,
                       only_category: str | None = None) -> int:
    """Returns the number of terms carrying a complete Overheard entry.

    `only_category` restricts the per-term checks to one category and skips the
    file-wide floors, so a writer can validate their own file before the other
    three exist.
    """
    by_id = {t.get("id"): t for t in terms}
    gists: dict[str, str] = {}
    overheards: Counter = Counter()
    tag_count: Counter = Counter()
    moment_count: Counter = Counter()
    # Counted without `basic` words, which are never dealt and so can never be offered.
    dealt_moment_count: Counter = Counter()
    speaker_by_cat: dict[str, Counter] = defaultdict(Counter)
    complete = 0
    variant_terms = 0
    variant_any = 0
    slot_count: Counter = Counter()

    for t in terms:
        tid = t.get("id", "?")
        if only_category and t.get("category") != only_category:
            continue
        o, sp, g, ds, when = t.get("overheard"), t.get("speaker"), t.get("gist"), t.get("decoys"), t.get("when")
        if not all([o, sp, g, ds, when]):
            err(f"lingo/{tid}: Overheard entry missing or incomplete (overheard, speaker, gist, decoys, when) — "
                f"add it to tools/myturn/lingo_overheard/{t.get('category')}.py")
            if t.get("playerVariants"):
                # Said plainly here rather than letting every variant rule fail
                # against fields that do not exist yet.
                err(f"lingo/{tid}: has a player variant on an incomplete entry. A variant inherits speaker, "
                    f"gist, decoys, when and moment, so there is nothing to inherit. Finish the entry first")
            continue
        complete += 1
        where = f"lingo/{tid}"

        for field, text in (("meaning", t.get("meaning", "")), ("heard", t.get("heard", "")), ("sayIt", t.get("sayIt", "")),
                            ("overheard", o), ("gist", g), *((f"decoy", x) for x in ds)):
            if "—" in text or "–" in text:
                err(f"{where}: {field} has an em-dash, write two sentences: {text[:60]}")

        # --- overheard: what she hears
        n = len(o)
        if n > LIMITS["overheard"]:
            err(f"{where}: overheard is {n} chars (cap {LIMITS['overheard']}): {o[:50]}…")
        elif n > OVERHEARD_COMFORT:
            warn(f"{where}: overheard is {n} chars, four lines on a small phone")
        if n < MIN_LEN["overheard"]:
            err(f"{where}: overheard is {n} chars (min {MIN_LEN['overheard']}), too short to sound like a person")
        if o[0] in "\"“'‘":
            err(f"{where}: overheard must not be wrapped in quotes, the bubble supplies them")
        if o.rstrip()[-1] not in ".!?…":
            err(f"{where}: overheard must end with . ! ? or …: {o}")
        if o.count("!") > 1:
            err(f"{where}: overheard has more than one exclamation mark: {o}")
        if EMOJI.search(o):
            err(f"{where}: overheard has an emoji")
        m = DEFINES.search(o)
        if m:
            err(f"{where}: overheard defines the term ('{m.group(0)}') instead of using it: {o}")
        if CLUBS.search(o) and tid not in CLUB_OK:
            err(f"{where}: overheard names a club, write they/we/this lot: {o}")
        aliases = t.get("aliases") or []
        hit = term_match(t.get("term", ""), tid, aliases, o)
        if not hit:
            err(f"{where}: overheard does not contain '{t.get('term')}' (or an alias): {o}")
        elif t.get("overheardTerm") and norm(t["overheardTerm"]) != norm(hit):
            err(f"{where}: overheardTerm is stale, rerun build_lingo.py")
        say_it = (t.get("sayIt") or "").strip("\"“”")
        if norm(o) == norm(say_it):
            err(f"{where}: overheard is sayIt copied over. sayIt is her line back; overheard is the line that made her need one")
        heard = t.get("heard") or ""
        if norm(o) and (norm(o) in norm(heard) or norm(heard) in norm(o)):
            warn(f"{where}: overheard duplicates heard")
        m = STALE_FACT.search(o)
        if m:
            err(f"{where}: overheard has a dated-fact superlative ('{m.group(0)}'): {o}")
        for w in re.findall(r"(?<=[a-z,;] )([A-Z][\w'’]+)", o):
            if w not in PROPER_OK and w.lower() not in norm(t.get("term", "")):
                warn(f"{where}: '{w}' is capitalised mid-sentence in overheard. A person? Nobody living, please")
        overheards[norm(o)] += 1
        check_idiom(where, o)
        # A word she can see in the bubble that reappears in exactly one option
        # is a match-the-word puzzle, not a meaning puzzle. Stems of 5+ letters,
        # the term's own words excluded (they are bolded and expected).
        term_stems = {w[:5] for w in content_words(re.sub(r"[^\w\s-]", "", t.get("term", ""))) | set(aliases_words(aliases))}
        bubble = {w[:5] for w in content_words(o) if len(w) >= 5} - term_stems - STEM_OK
        g_st = {w[:5] for w in content_words(g) if len(w) >= 5}
        d_st = [{w[:5] for w in content_words(x) if len(w) >= 5} for x in (ds if isinstance(ds, list) else [])]
        leak = bubble & g_st - set().union(*d_st) if d_st else set()
        if leak:
            err(f"{where}: '{sorted(leak)[0]}…' is in the bubble and only in the gist, the bubble hands over the answer: {o}")

        # --- playerVariants: the same card with a real name from the fixture in it
        pv = t.get("playerVariants")
        if pv is not None:
            decoy_stems = set().union(*d_st) if d_st else set()
            if not isinstance(pv, list) or not pv:
                err(f"{where}: playerVariants must be a non-empty list, got {pv!r}")
                pv = []
            if len(pv) > MAX_VARIANTS:
                err(f"{where}: {len(pv)} player variants (max {MAX_VARIANTS}); a round deals two named cards in total")
            if t.get("basic") is True:
                err(f"{where}: a basic word is never dealt in a round, so a player variant on it can never appear")
            sides = [str(v.get("slot", "")).split(".")[0] for v in pv if isinstance(v, dict)]
            if len(sides) == 2 and sides[0] == sides[1]:
                err(f"{where}: both player variants are '{sides[0]}'; two variants on one term must take different sides")
            got_slots = [check_variant(t, v, i, err=err, check_idiom=check_idiom, term_stems=term_stems,
                                       gist_stems=g_st, decoy_stems=decoy_stems)
                         for i, v in enumerate(pv) if isinstance(v, dict)]
            if any(got_slots):
                variant_terms += 1
                if "any" in (when if isinstance(when, list) else []):
                    variant_any += 1
            for s in got_slots:
                if s:
                    slot_count[s] += 1

        # --- speaker
        if sp not in SPEAKERS:
            err(f"{where}: speaker '{sp}' invalid (him, telly, chat, pundit)")
        speaker_by_cat[t.get("category", "?")][sp] += 1

        # --- gist and decoys share a shape
        if not isinstance(ds, list) or len(ds) != 2:
            err(f"{where}: decoys must be exactly 2, got {ds!r}")
            ds = list(ds or [])[:2]
        opts = [("gist", g)] + [("decoy", x) for x in ds]
        for field, x in opts:
            if len(x) > LIMITS[field]:
                err(f"{where}: {field} is {len(x)} chars (cap {LIMITS[field]}): {x}")
            if len(x) < MIN_LEN[field]:
                err(f"{where}: {field} is {len(x)} chars (min {MIN_LEN[field]}): {x}")
            if x.rstrip().endswith("."):
                err(f"{where}: {field} must not end with a full stop, it is an option not a sentence: {x}")
            if not x[0].isupper():
                err(f"{where}: {field} must start with a capital: {x}")
            m = superlative.search(x)
            if m:
                err(f"{where}: {field} has a superlative that can go stale ('{m.group(0)}'), write the dated fact: {x}")
            check_idiom(where, x)
        for x in ds:
            if abs(len(x) - len(g)) > BAND:
                err(f"{where}: decoy length {len(x)} is more than {BAND} off the gist ({len(g)}), length gives it away: {x}")
        if len({norm(x) for _, x in opts}) != 3:
            err(f"{where}: gist and decoys must be three different options")
        clash = content_words(g) & content_words(re.sub(r"[^\w\s-]", "", t.get("term", "")))
        if clash:
            err(f"{where}: gist repeats a word of the term ({', '.join(sorted(clash))}), which is bolded in the bubble: {g}")
        fw = [first_word(x) for _, x in opts]
        if len(fw) == 3 and fw[1] == fw[2] != fw[0]:
            err(f"{where}: both decoys start with '{fw[1]}' and the gist does not, the odd one out is the answer")
        if norm(g) in gists:
            err(f"{where}: gist is identical to {gists[norm(g)]}'s gist: {g}")
        gists[norm(g)] = tid

        # --- when
        if not isinstance(when, list):
            err(f"{where}: when must be a list of tags")
            when = []
        bad = [w for w in when if w not in WHEN_TAGS]
        if bad:
            err(f"{where}: when tags {bad} are not in the enum ({', '.join(WHEN_TAGS)})")
        if len(when) != len(set(when)):
            err(f"{where}: duplicate when tag")
        if not 1 <= len(when) <= 5:
            err(f"{where}: when needs 1 to 5 tags, got {len(when)}")
        # Only words that can actually be dealt count towards the floor. A `basic`
        # word never reaches a round, so tagging one does not thicken the block.
        if not t.get("basic"):
            for w in when:
                tag_count[w] += 1

        # --- moment: how often this line's moment actually arrives
        moment = t.get("moment")
        if moment not in MOMENTS:
            err(f"{where}: moment is {moment!r}, must be one of {', '.join(MOMENTS)} "
                f"(judge the sayIt line, not the term)")
        else:
            moment_count[moment] += 1
            if moment != "rare" and t.get("basic") is not True:
                dealt_moment_count[moment] += 1
        if len(aliases) > MAX_ALIASES:
            err(f"{where}: more than {MAX_ALIASES} aliases; aliases are the exception, not the rule")

        # --- basic: guessable from the words themselves, so never dealt
        if "basic" in t and not isinstance(t["basic"], bool):
            err(f"{where}: basic must be true or false, got {t['basic']!r}")

    # --- second pass: a decoy must not be a synonym's right answer
    for t in terms:
        tid = t.get("id", "?")
        if only_category and t.get("category") != only_category:
            continue
        neighbours = set(t.get("seeAlso") or []) | {o.get("id") for o in terms if tid in (o.get("seeAlso") or [])}
        for x in t.get("decoys") or []:
            owner = gists.get(norm(x))
            if owner and (owner == tid or owner in neighbours):
                err(f"lingo/{tid}: decoy '{x}' is the gist of {owner}, a synonym she would rightly pick")
            elif owner:
                warn(f"lingo/{tid}: decoy '{x}' is {owner}'s gist")
    for text, n in overheards.items():
        if n > 1:
            err(f"lingo: duplicate overheard line: {text[:60]}")

    # Length skew across the set: each entry passes the 20-char band, but if the
    # gist is the longest option most of the time, "tap the longest" beats the
    # game without reading. Counted here, over every complete entry.
    longest = shortest = 0
    for t in terms:
        g, ds = t.get("gist"), t.get("decoys")
        if not g or not isinstance(ds, list) or len(ds) != 2:
            continue
        lens = [len(g), len(ds[0]), len(ds[1])]
        if lens[0] > max(lens[1:]):
            longest += 1
        if lens[0] < min(lens[1:]):
            shortest += 1
    if only_category:
        return complete
    if complete:
        share = longest / complete
        if share > 0.45:
            err(f"lingo: the gist is the longest option in {longest} of {complete} entries ({share:.0%}, max 45%); "
                f"'tap the longest' would beat the game. Pad decoys or trim gists")
        if shortest / complete < 0.20:
            err(f"lingo: the gist is the shortest option in only {shortest} of {complete} entries (min 20%)")

    # --- file-wide floors: a deck must never come up thin
    for tag in WHEN_TAGS:
        if tag == "any":
            continue
        if tag_count[tag] < MIN_PER_TAG:
            err(f"lingo: tag '{tag}' has {tag_count[tag]} dealt terms (min {MIN_PER_TAG}), a deck would come up thin")
    if tag_count["any"] < MIN_ANY:
        err(f"lingo: only {tag_count['any']} terms carry 'any' (min {MIN_ANY}); the fill pool runs dry")
    for band, floor in (("anytime", MIN_ANYTIME), ("common", MIN_COMMON)):
        if dealt_moment_count[band] < floor:
            ids = sorted(t.get("id", "?") for t in terms
                         if t.get("moment") == band and t.get("basic") is not True)
            err(f"lingo: only {dealt_moment_count[band]} dealt terms are moment '{band}' "
                f"({moment_count[band]} counting basic ones, min {floor}); the line she leaves with "
                f"comes only from anytime and common, and a thin pool hands her the same line "
                f"every week: {', '.join(ids)}")
    # --- player variants: two of seven cards should name a real man, which only
    # happens if enough of the pool can carry one.
    if variant_terms < MIN_VARIANT_TERMS:
        err(f"lingo: only {variant_terms} terms carry a player variant (min {MIN_VARIANT_TERMS}); "
            f"a round of seven would rarely deal one")
    for s in SLOTS:
        if slot_count[s] < MIN_PER_SLOT:
            err(f"lingo: slot '{s}' has {slot_count[s]} variants (min {MIN_PER_SLOT}); "
                f"a fixture that resolves that slot would see the same line every week")
    if variant_any < MIN_VARIANT_ANY:
        err(f"lingo: only {variant_any} terms with a player variant carry 'any' (min {MIN_VARIANT_ANY}); "
            f"the fill pool is what reaches them in an ordinary week")
    basic = [t.get("id", "?") for t in terms if t.get("basic") is True]
    if len(basic) > MAX_BASIC:
        err(f"lingo: {len(basic)} terms are marked basic (max {MAX_BASIC}); every one is out of the deck pool, "
            f"and marking them all empties it: {', '.join(sorted(basic))}")
    for cat, c in speaker_by_cat.items():
        total = sum(c.values()) or 1
        for sp in SPEAKERS:
            share = c[sp] / total
            if share < 0.10 or share > 0.55:
                warn(f"lingo/{cat}: speaker '{sp}' is {share:.0%} of the category (aim 10-55%)")
    return complete
