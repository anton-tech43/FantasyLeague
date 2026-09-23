"""validate_overheard.py — the Overheard game's half of validate_lingo.

Called from validate_content.py with its err/warn/check_idiom/SUPERLATIVE.
Kept in its own file because the rules are many and self-contained: what she
hears (overheard), who says it (speaker), the right option (gist), the two
wrong ones (decoys) and when the word is dealt (when).

Overheard is speech, so only the shapes that encode a dated fact are banned
there (STALE_FACT). Gist and decoys are definitions and get the full
SUPERLATIVE regex: "final day" not "the last day".
"""
from __future__ import annotations

import re
from collections import Counter, defaultdict

from lingo_match import term_match
from lingo_overheard import MOMENTS, SPEAKERS, WHEN_TAGS

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

    for t in terms:
        tid = t.get("id", "?")
        if only_category and t.get("category") != only_category:
            continue
        o, sp, g, ds, when = t.get("overheard"), t.get("speaker"), t.get("gist"), t.get("decoys"), t.get("when")
        if not all([o, sp, g, ds, when]):
            err(f"lingo/{tid}: Overheard entry missing or incomplete (overheard, speaker, gist, decoys, when) — "
                f"add it to tools/myturn/lingo_overheard/{t.get('category')}.py")
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
            err(f"lingo: tag '{tag}' has {tag_count[tag]} terms (min {MIN_PER_TAG}), a deck would come up thin")
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
