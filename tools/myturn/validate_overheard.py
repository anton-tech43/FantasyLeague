"""validate_overheard.py — the Overheard game's half of validate_lingo.

Called from validate_content.py with its err/warn/check_idiom/SUPERLATIVE.
Kept in its own file because the rules are many and self-contained: what she
hears (overheard), who says it (speaker), the right option (gist), the wrong
one she is shown (decoy), the reviewed reserve she is not (spare) and when the
word is dealt (when).

Overheard is speech, so only the shapes that encode a dated fact are banned
there (STALE_FACT). Gist, decoy and spare are definitions and get the full
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

LIMITS = {"overheard": 120, "gist": 60, "decoy": 60, "spare": 60}
MIN_LEN = {"overheard": 20, "gist": 12, "decoy": 12, "spare": 12}
OVERHEARD_COMFORT = 100        # warn above: four lines on a small phone
# How far a decoy may sit from the gist in characters. One absolute number
# cannot be right across a 23-to-52-character gist range: 20 was 87% of the
# shortest gists and a third of the longest. So a floor, below which a
# difference is invisible anyway, and a proportion above it.
BAND_FLOOR = 10
BAND_RATIO = 0.25
# A word that opens an option and answers it. At three options the tell was a
# first word two options shared; at two there is no odd one out, so what is left
# is the register difference an article announces.
DETERMINERS = {"a", "an", "the"}
# Set-level skew, symmetric because at two options there is no third option to
# hide behind: a solver tapping on one surface should score a coin flip. 40/60
# is about 2.5 SD at n=158, wide enough not to fire on noise.
SKEW_ERR = (0.40, 0.60)
SKEW_WARN = (0.45, 0.55)
MIN_DECIDED = 30               # below this the share is noise, not skew
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


def band_for(gist: str) -> int:
    return max(BAND_FLOOR, round(BAND_RATIO * len(gist)))


# The four surfaces a solver reads without reading: how long it is, how many
# words, how many commas (a two-part truth carries one, a flat assertion does
# not) and how long its longest word.
FEATURES = {
    "character length": len,
    "word count": lambda s: len(s.split()),
    "comma count": lambda s: s.count(","),
    "longest word": lambda s: max((len(w) for w in re.findall(r"[\w'-]+", s)), default=0),
}


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

    # --- the bubble must not hand over the answer, gist and decoy being inherited
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
        o, sp, g, when = t.get("overheard"), t.get("speaker"), t.get("gist"), t.get("when")
        d, spare = t.get("decoy"), t.get("spare")
        if not all([o, sp, g, d, spare, when]):
            err(f"lingo/{tid}: Overheard entry missing or incomplete (overheard, speaker, gist, decoy, spare, when) — "
                f"add it to tools/myturn/lingo_overheard/{t.get('category')}.py")
            if t.get("playerVariants"):
                # Said plainly here rather than letting every variant rule fail
                # against fields that do not exist yet.
                err(f"lingo/{tid}: has a player variant on an incomplete entry. A variant inherits speaker, "
                    f"gist, decoy, when and moment, so there is nothing to inherit. Finish the entry first")
            continue
        complete += 1
        where = f"lingo/{tid}"
        # Checked before anything reads it: the leak rule below needs the
        # shipping decoy as a string, and the list form is the shape a
        # half-finished rename leaves behind.
        if not isinstance(d, str) or not d.strip():
            err(f"{where}: decoy must be one non-empty string, got {d!r}; a term with no decoy is unplayable")
            d = ""
        if not isinstance(spare, str) or not spare.strip():
            err(f"{where}: spare must be one non-empty string, got {spare!r}; without it the walk back to "
                f"three options is a writing job, not a one-line change")
            spare = ""

        for field, text in (("meaning", t.get("meaning", "")), ("heard", t.get("heard", "")), ("sayIt", t.get("sayIt", "")),
                            ("overheard", o), ("gist", g), ("decoy", d), ("spare", spare)):
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
        # The excuse is the shipping decoy alone. A word echoed by the gist and
        # by text she never sees is still a word echoed by the only right
        # answer on the card.
        d_st = {w[:5] for w in content_words(d) if len(w) >= 5}
        leak = (bubble & g_st) - d_st
        if leak:
            err(f"{where}: '{sorted(leak)[0]}…' is in the bubble and only in the gist, the bubble hands over the answer: {o}")

        # --- playerVariants: the same card with a real name from the fixture in it
        pv = t.get("playerVariants")
        if pv is not None:
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
                                       gist_stems=g_st, decoy_stems=d_st)
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

        # --- the options. She sees two: the gist and the decoy that ships.
        # `spare` is the reviewed reserve, held so three options stay one line
        # away; it gets the format rules and none of the balance ones, because
        # balancing a card against text she never reads proves nothing.
        opts = [("gist", g), ("decoy", d)]
        for field, x in [(f, x) for f, x in opts + [("spare", spare)] if x]:
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
        band = band_for(g)
        if d and abs(len(d) - len(g)) > band:
            err(f"{where}: decoy length {len(d)} is more than {band} off the gist ({len(g)}), "
                f"length gives it away with two options: {d}")
        if spare and abs(len(spare) - len(g)) > band:
            warn(f"{where}: spare length {len(spare)} is more than {band} off the gist ({len(g)}); "
                 f"it could not take the decoy's place as written")
        written = [x for x in (g, d, spare) if x]
        if len({norm(x) for x in written}) != len(written):
            err(f"{where}: gist, decoy and spare must be three different options")
        # Exactly one article is the new first-word tell. "A tally handed out by
        # finishing position" against "Three for a win, one for a draw" is an
        # article against a number, and she never has to read past word one.
        if g and d and (first_word(g) in DETERMINERS) != (first_word(d) in DETERMINERS):
            err(f"{where}: exactly one option opens with a/an/the, which is the whole card at two options. "
                f"Give both an article or neither: {g!r} / {d!r}")
        clash = content_words(g) & content_words(re.sub(r"[^\w\s-]", "", t.get("term", "")))
        if clash:
            err(f"{where}: gist repeats a word of the term ({', '.join(sorted(clash))}), which is bolded in the bubble: {g}")
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
        for x, shipping in ((t.get("decoy"), True), (t.get("spare"), False)):
            if not isinstance(x, str) or not x:
                continue
            label = "decoy" if shipping else "spare"
            owner = gists.get(norm(x))
            if owner and (owner == tid or owner in neighbours):
                (err if shipping else warn)(
                    f"lingo/{tid}: {label} '{x}' is the gist of {owner}, a synonym she would rightly pick")
            elif owner:
                warn(f"lingo/{tid}: {label} '{x}' is {owner}'s gist")
    for text, n in overheards.items():
        if n > 1:
            err(f"lingo: duplicate overheard line: {text[:60]}")

    if only_category:
        return complete

    # Skew across the set. Each card passes its own band, but a surface that
    # points at the gist most of the time beats the game without reading a word,
    # and at two options there is no third to dilute it. Ties are counted apart
    # and charged to neither side: an equal pair tells her nothing, and folding
    # it into one half is exactly what hid the comma tell, which sat at 90.6%.
    pairs = [(t["gist"], t["decoy"]) for t in terms
             if t.get("gist") and isinstance(t.get("decoy"), str) and t["decoy"]]
    for label, f in FEATURES.items():
        higher = sum(1 for g, d in pairs if f(g) > f(d))
        ties = sum(1 for g, d in pairs if f(g) == f(d))
        decided = len(pairs) - ties
        if decided < MIN_DECIDED:
            warn(f"lingo: {label} separates only {decided} of {len(pairs)} cards ({ties} tied); "
                 f"too few to read a skew from")
            continue
        share = higher / decided
        where = (f"the gist has the higher {label} in {higher} of the {decided} cards where the two options "
                 f"differ ({share:.0%}), {ties} tied")
        if not SKEW_ERR[0] <= share <= SKEW_ERR[1]:
            err(f"lingo: {where}. A solver reading nothing but {label} scores {max(share, 1 - share):.0%}; "
                f"bring it inside {SKEW_ERR[0]:.0%}-{SKEW_ERR[1]:.0%}")
        elif not SKEW_WARN[0] <= share <= SKEW_WARN[1]:
            warn(f"lingo: {where}, outside the {SKEW_WARN[0]:.0%}-{SKEW_WARN[1]:.0%} aim")

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


if __name__ == "__main__":
    # Self-check: the rules that decide a two-option card, each fired once.
    # `python3 tools/myturn/validate_overheard.py` prints OK or raises. The file
    # went without one until the arity change, which is how a gist-only comma in
    # 90.6% of cards and a lone article in 38 of them lived here unremarked.
    _decoy = "The trick that leaves him on the floor"
    ok = dict(id="nutmeg", category="tactics", term="Nutmeg", meaning="Through the legs", heard="Commentary, mostly", level=1,
              sayIt="Through his legs, that", overheard="He got nutmegged there and he knows it.",
              speaker="him", gist="The ball played through his legs",
              decoy=_decoy, spare="The shot that goes in off the post",
              when=["any"], moment="common")
    NEVER = re.compile(r"(?!x)x")

    def run(terms, category="tactics"):
        errs: list[str] = []
        warns: list[str] = []
        validate_overheard(terms, err=errs.append, warn=warns.append,
                           check_idiom=lambda w, v: None, superlative=NEVER, only_category=category)
        return errs, warns

    def fires(needle, where="err", **changes):
        errs, warns = run([dict(ok, **changes)])
        got = errs if where == "err" else warns
        assert any(needle in m for m in got), f"expected {needle!r}, got {got}"

    assert run([ok]) == ([], []), run([ok])
    # --- arity: one decoy ships, and the spare is still written down
    # The list form left in place: truthy, so it clears the completeness gate.
    fires("decoy must be one non-empty string", decoy=[_decoy])
    fires("spare must be one non-empty string", spare=[_decoy])
    # --- the band is a floor plus a proportion, so it means the same at 23 chars and at 52
    fires("length gives it away", decoy="The trick that leaves him flat on the floor, twice over")
    fires("it could not take the decoy's place", "warn",
          spare="The shot that goes in off the post after a deflection")
    # --- one article between two options is the whole card
    fires("exactly one option opens with a/an/the", gist="Played through his legs, all ends up")
    fires("three different options", spare=_decoy)
    # --- a leak the spare would have excused is still a leak: she never reads the spare
    fires("hands over the answer", overheard="He got nutmegged straight through there.",
          spare="Passing it straight through the middle")
    # --- set level, so no category: the floors fire too and are not what is asserted
    skewed = [dict(ok, id=f"t{i}", overheard=f"He got nutmegged there, number {i} of the night.",
                   gist=f"Ball {i} played through both of his legs",
                   decoy=f"Trick {i} on the floor", spare="The post that keeps it out again")
              for i in range(40)]
    errs, warns = run(skewed, category=None)
    assert any("A solver reading nothing but character length" in m for m in errs), errs
    assert any("comma count separates only 0" in m for m in warns), warns
    print("validate_overheard self-check: OK")
