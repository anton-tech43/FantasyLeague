#!/usr/bin/env python3
"""Fact-check the My Turn audit dumps against the raw API-Football payloads.

Truth = the latest raw payloads in raw_fetch_logs (exported as raw_*.json),
teams.manager_name (human-verified) and the players table. Every check that
cannot be made from those is listed as MANUAL for the web pass.
Usage: check.py <dir> [label]   (export.sh <dir> first; reads <dir>/dumps/myturn-audit-<club>-<label>.json)
"""
import json, re, sys, unicodedata, glob, os
from datetime import datetime, timezone
S = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else sys.exit(__doc__)
L = lambda n: json.load(open(f"{S}/raw_{n}.json"))
fx_next, fx_last, standings = L("api_football_fixtures_next"), L("api_football_fixtures_last"), L("api_football_standings")
squad_raw, preds, pstats = L("api_football_squad"), L("api_football_predictions"), L("api_football_players_stats")
teams = {t["id"]: t for t in L("teams")}
players = L("players"); pages = L("pages")
last_table = {e["team"]["id"]: e for e in json.load(open(f"{S}/raw_standings_2025.json"))["response"][0]["league"]["standings"][0]}
PROMOTED = {"coventry": "Championship winners", "ipswich": "Championship runners-up", "hull": "Promoted through the play-offs"}
def last_season_ok(tid, text):
    if tid in PROMOTED: return PROMOTED[tid].lower() in text.lower()
    e = last_table.get(teams[tid]["api_football_id"])
    if not e: return False
    head = "Champions" if e["rank"] == 1 else ordinal(e["rank"])
    return text.startswith(head) and (str(e["points"]) in text or "points" not in text)
by_api = {t["api_football_id"]: t for t in teams.values() if t.get("api_football_id")}

ALIAS = {"nott m forest": "nottingham forest", "man utd": "manchester united", "man city": "manchester city", "spurs": "tottenham"}
def fold0(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    return " ".join(re.sub(r"[^a-z0-9 ]+", " ", "".join(c for c in s if not unicodedata.combining(c)).replace("ø", "o")).split())
def fold(s):
    f = fold0(s)
    for k, v in ALIAS.items():   # anywhere, as a whole phrase ("Drew 1-1 with Man Utd")
        f = re.sub(rf"(^| ){k}( |$)", rf"\g<1>{v}\g<2>", f)
    return f
def raw_same(a, b):
    a, b = fold(a), fold(b)
    if not a or not b: return False
    return a == b or a in b or b in a
def same(a, b):
    ta, tb = team_of_name(a), team_of_name(b)
    if ta and tb: return ta == tb
    a, b = fold(a), fold(b)
    if not a or not b: return False
    return a == b or a in b or b in a
def surname(n): p = fold(n).split(); return p[-1] if p else ""
def ordinal(n): return f"{n}{'th' if 11 <= n % 100 <= 13 else {1:'st',2:'nd',3:'rd'}.get(n % 10, 'th')}"
def team_of_name(name):
    for t in teams.values():
        if raw_same(t["display_name"], name) or (t.get("short_name") and raw_same(t["short_name"], name)): return t["id"]
    return None

def next_fixture(tid, now):
    resp = (fx_next.get(tid) or {}).get("response", [])
    rows = sorted(resp, key=lambda x: x["fixture"]["date"])
    api = teams[tid]["api_football_id"]
    out = []
    for r in rows:
        d = datetime.fromisoformat(r["fixture"]["date"].replace("Z", "+00:00"))
        if d <= now: continue
        home = r["teams"]["home"]; away = r["teams"]["away"]
        opp = away if home["id"] == api else home
        out.append({"date": d, "opp": opp["name"], "opp_api": opp["id"], "league": r["league"]["name"], "id": r["fixture"]["id"]})
    return out

def last_results(tid):
    api = teams[tid]["api_football_id"]
    resp = (fx_last.get(tid) or {}).get("response", [])
    out = []
    for r in sorted(resp, key=lambda x: x["fixture"]["date"], reverse=True):
        if r["fixture"]["status"]["short"] not in ("FT", "AET", "PEN"): continue
        h, a = r["teams"]["home"], r["teams"]["away"]
        mine_home = h["id"] == api
        g = r["goals"]; my = g["home"] if mine_home else g["away"]; th = g["away"] if mine_home else g["home"]
        out.append({"date": r["fixture"]["date"][:10], "opp": (a if mine_home else h)["name"], "my": my, "th": th,
                    "home": mine_home, "league": r["league"]["name"]})
    return out

def table(tid):
    for blk in (standings.get(tid) or {}).get("response", []):
        for grp in blk["league"]["standings"]:
            for e in grp:
                if e["team"]["id"] == teams[tid]["api_football_id"]:
                    return {"rank": e["rank"], "points": e["points"], "played": e["all"]["played"], "league": blk["league"]["name"]}
    return None

def squad_rows(tid): return [p for p in players if p["team_id"] == tid]
def top_scorer(tid):
    rows = [p for p in squad_rows(tid) if (p["goals"] or 0) > 0]
    if not rows: return None, False, 0
    m = max(p["goals"] for p in rows); lv = [p for p in rows if p["goals"] == m]
    return lv[0]["name"], len(lv) > 1, m
def form_label(w, d, l, n): return f"Won {w}, drew {d}, lost {l} of the last {['','one','two','three','four','five','six'][n]}"

issues = []; manual = []
def bad(club, where, msg): issues.append((club, where, msg))
def man(club, where, msg): manual.append((club, where, msg))
# The CDN's placeholder images (DATA_SOURCES.md): HTTP 200, never a 404.
PLACEHOLDERS = {"f512b984f93ca6915dd623351b93b531", "3e52d4ec4bb65b0a2019236c4dabd3fc",
                "68ac0d5773da5ee81444ade70d89533d", "0e3bde19a08632f2e893bc2a835598bc",
                "430d67fd79ad0a355b212d5780886e34"}
_ph = {}
def placeholder(url):
    if not url.startswith("http"): return False      # a bundled portrait
    if url not in _ph:
        import hashlib, urllib.request
        try: _ph[url] = hashlib.md5(urllib.request.urlopen(url, timeout=15).read()).hexdigest() in PLACEHOLDERS
        except Exception: _ph[url] = False
    return _ph[url]
def basics_off(T, qid, answer):
    """The answer against the club's live page, which the app should be
    reading fresh (a stale cache said Goodison Park, 2026-10-02)."""
    b = ((pages.get(T) or {}).get("cards") or {}).get("basics") or {}
    field = {"stadium": "stadium", "nickname": "nickname", "last-title": "last_title"}.get(qid.split("-", 1)[1])
    if not field or not b.get(field): return None
    want = b[field].split(",")[0].strip()
    return None if fold(want) in fold(answer) or fold(answer) in fold(want) else f"{answer} vs page {b[field]}"

label = sys.argv[2] if len(sys.argv) > 2 else "now"
for f in sorted(glob.glob(f"{S}/dumps/myturn-audit-*-{label}.json")):
    d = json.load(open(f)); club = d["team"]
    now = datetime.fromisoformat(d["now"].replace("Z", "+00:00"))
    ph = d["context"]["phase"]
    nxt = next_fixture(club, now)
    nxt_comp = [x for x in nxt if "Friendl" not in x["league"]]
    # ── Opponent ──
    if ph["kind"] == "before":
        # A friendly is never "next up" (Villa v Sevilla, 2026-10-02).
        truth = nxt_comp[0] if nxt_comp else None
        friendly = next((x for x in nxt if "Friendl" in x["league"] and same(ph["opponent"], x["opp"])), None)
        if friendly: bad(club, "opponent", f"prep is about a FRIENDLY ({friendly['opp']}, {friendly['date']:%d %b})")
        if not truth: bad(club, "opponent", f"app says {ph['opponent']}, feed has no next competitive fixture")
        else:
            if not same(ph["opponent"], truth["opp"]):
                bad(club, "opponent", f"app: {ph['opponent']} {ph['kickoff']} / feed next: {truth['opp']} {truth['date']:%Y-%m-%d %H:%M} ({truth['league']})")
            k = datetime.fromisoformat(ph["kickoff"].replace("Z", "+00:00"))
            if abs((k - truth["date"]).total_seconds()) > 60 and same(ph["opponent"], truth["opp"]):
                bad(club, "kickoff", f"app {k} vs feed {truth['date']}")
    else:
        man(club, "phase", f"phase {ph}")
    opp_id = d.get("opponentTeam")
    # ── Opponent pack ──
    op = d.get("opponentPack")
    if ph["kind"] == "before" and opp_id and not op: bad(club, "opponentPack", "missing though the opponent is a known club")
    for q in (op or {}).get("questions", []):
        w = f"opp {q['id']}"
        if len(q["options"]) != 2: bad(club, w, f"{len(q['options'])} options, want 2")
        T = opp_id
        if q["id"] == "opp-manager":
            if not same(q["answer"], teams[T]["manager_name"]): bad(club, w, f"answer {q['answer']} vs teams.manager_name {teams[T]['manager_name']}")
            if not q["image"]: bad(club, w, "no manager photo")
            elif placeholder(q["image"]): bad(club, w, f"manager photo is a CDN placeholder: {q['image']}")
        elif q["id"] == "opp-table-position":
            t = table(T)
            if not t or q["answer"] != ordinal(t["rank"]): bad(club, w, f"answer {q['answer']} vs standings {t}")
            elif f"from {t['played']} games" not in q["explanation"] or str(t["points"]) not in q["explanation"]:
                bad(club, w, f"explanation '{q['explanation']}' vs {t}")
        elif q["id"] == "opp-form":
            r = last_results(T)[:3]
            names = [x["opp"] for x in r]
            if not all(fold(n) in fold(q["question"]) or surname(n) in fold(q["question"]) for n in names):
                bad(club, w, f"question '{q['question']}' vs last three {names}")
            W = sum(x["my"] > x["th"] for x in r); D = sum(x["my"] == x["th"] for x in r); Lo = sum(x["my"] < x["th"] for x in r)
            if q["answer"] != form_label(W, D, Lo, len(r)): bad(club, w, f"answer {q['answer']} vs {W}-{D}-{Lo} {r}")
            for x in r:
                if f"{x['my']}–{x['th']}" not in q["explanation"]: bad(club, w, f"score {x['my']}-{x['th']} v {x['opp']} missing from '{q['explanation']}'")
            if q["options"][0] == q["options"][1]: bad(club, w, "both options equal")
        elif q["id"] == "opp-top-scorer":
            n, tied, g = top_scorer(T)
            if tied: bad(club, w, f"asked though the top scorers are tied on {g}")
            elif not n or surname(n) not in fold(q["answer"]): bad(club, w, f"answer {q['answer']} vs players {n} ({g})")
            elif f"{g} goal" not in q["explanation"]: bad(club, w, f"goals in '{q['explanation']}' vs {g}")
            if not q["image"]: man(club, w, "no scorer photo yet (fills on the next sources fetch)")
        elif q["id"] == "opp-last-meeting":
            p = (preds.get(club) or {}).get("response", [{}])[0]
            pt = p.get("teams", {})
            # A predictions payload for another fixture (Palace's cup tie) has
            # another h2h: nothing to check against, so it goes to the web pass.
            if pt and not any(same(pt.get(s, {}).get("name", ""), ph.get("opponent", "")) for s in ("home", "away")):
                man(club, w, f"{q['answer']} ({q['explanation']}): predictions payload is for {pt.get('home',{}).get('name')} v {pt.get('away',{}).get('name')}, check on the web"); continue
            h2h = sorted([h for h in p.get("h2h", []) if h["goals"]["home"] is not None], key=lambda h: h["fixture"]["date"], reverse=True)
            if not h2h: man(club, w, "no raw h2h to check against"); continue
            h = h2h[0]; ours = teams[club]["api_football_id"]
            mh = h["teams"]["home"]["id"] == ours
            my, th = (h["goals"]["home"], h["goals"]["away"]) if mh else (h["goals"]["away"], h["goals"]["home"])
            want = f"We won {max(my,th)}–{min(my,th)}" if my > th else f"They won {max(my,th)}–{min(my,th)}" if th > my else f"{my}–{th} draw"
            if q["answer"] != want: bad(club, w, f"answer {q['answer']} vs raw h2h {h['fixture']['date'][:10]} {h['teams']['home']['name']} {h['goals']['home']}-{h['goals']['away']} {h['teams']['away']['name']}")
        elif q["id"] in ("opp-nickname", "opp-stadium"):
            if (e := basics_off(T, q["id"], q["answer"])): bad(club, w, e)
            man(club, w, f"{q['question']} -> {q['answer']}")
        elif q["id"] == "opp-last-season":
            e = last_table.get(teams[T]["api_football_id"])
            if not e or q["answer"] != ordinal(e["rank"]): bad(club, w, f"{q['answer']} vs 2025-26 table {e and e['rank']}")
    # ── His club pack ──
    for q in (d.get("clubPack") or {}).get("questions", []):
        w = f"club {q['id']}"
        if q["id"] == "live-manager-name":
            if not same(q["answer"], teams[club]["manager_name"]): bad(club, w, f"{q['answer']} vs {teams[club]['manager_name']}")
        elif q["id"] == "live-last-season":
            if not last_season_ok(club, q["answer"]): bad(club, w, f"{q['answer']} vs 2025-26 table")
        elif q["id"] in ("live-table-position", "live-points"):
            t = table(club)
            want = ordinal(t["rank"]) if q["id"] == "live-table-position" else str(t["points"])
            if q["answer"] != want: bad(club, w, f"{q['answer']} vs standings {t}")
        elif q["id"] == "live-next-opponent":
            truth = nxt_comp[0]["opp"] if nxt_comp else None
            if not truth or not same(q["answer"], truth): bad(club, w, f"{q['answer']} vs feed next competitive {truth}")
        elif q["id"] == "live-last-result":
            r = last_results(club)
            if r:
                x = r[0]; verb = "Beat" if x["my"] > x["th"] else "Lost" if x["my"] < x["th"] else "Drew"
                if not (same(x["opp"], q["answer"]) or surname(x["opp"]) in fold(q["answer"])) or f"{x['my']}-{x['th']}" not in q["answer"] or not q["answer"].startswith(verb):
                    bad(club, w, f"{q['answer']} vs feed last {x}")
        elif q["id"] == "live-form":
            r = last_results(club)[:5]
            W = sum(x["my"] > x["th"] for x in r); D = sum(x["my"] == x["th"] for x in r); Lo = sum(x["my"] < x["th"] for x in r)
            n = len(r)
            # The form card may count a different window; check the counts the answer claims.
            m = re.match(r"Won (\d+), drew (\d+), lost (\d+) of the last (\w+)", q["answer"])
            if m and n >= int(m.group(1)) + int(m.group(2)) + int(m.group(3)):
                k = int(m.group(1)) + int(m.group(2)) + int(m.group(3))
                rk = r[:k]; w2 = sum(x["my"] > x["th"] for x in rk); d2 = sum(x["my"] == x["th"] for x in rk); l2 = sum(x["my"] < x["th"] for x in rk)
                if (w2, d2, l2) != tuple(int(m.group(i)) for i in (1, 2, 3)):
                    bad(club, w, f"{q['answer']} vs raw last {k}: {w2}-{d2}-{l2} {[(x['opp'], x['my'], x['th'], x['league']) for x in rk]}")
            else: man(club, w, f"{q['answer']} (raw has only {n} results to check)")
        elif q["id"] == "live-top-scorer":
            n, tied, g = top_scorer(club)
            if tied or not n or surname(n) not in fold(q["answer"]): bad(club, w, f"{q['answer']} vs players {n} ({g}, tied={tied})")
        else:
            if q["id"] in ("live-stadium", "live-nickname", "live-last-title") and (e := basics_off(club, q["id"].replace("live-", "x-"), q["answer"])):
                bad(club, w, e)
            man(club, w, f"{q['question']} -> {q['answer']}")
    # ── His squad ──
    rows = squad_rows(club)
    for q in (d.get("squadPack") or {}).get("questions", []):
        w = f"squad {q['id']}"
        m = re.match(r"squad-(photo|number|pos)-(\d+)", q["id"])
        if not m: continue
        pid = int(m.group(2)); p = next((x for x in rows if x["api_player_id"] == pid), None)
        if not p: bad(club, w, "player not in the squad table"); continue
        if m.group(1) == "photo" and surname(p["name"]) not in fold(q["answer"]): bad(club, w, f"answer {q['answer']} vs {p['name']}")
        if m.group(1) == "number":
            same_no = [x for x in rows if x["number"] == p["number"]]
            if q["answer"] != str(p["number"]): bad(club, w, f"{q['answer']} vs {p['number']}")
            if len(same_no) > 1: man(club, w, f"{p['name']} {p['number']} shared with {[x['name'] for x in same_no if x is not p]} (regular rule)")
        if m.group(1) == "pos":
            want = {"Goalkeeper": "Goalkeeper", "Defender": "Defender", "Midfielder": "Midfielder", "Attacker": "Forward"}.get(p["position"], p["position"])
            if q["answer"] != want: bad(club, w, f"{q['answer']} vs {p['position']}")
    # ── 7 words: named players ──
    for t in d["words"]:
        nm = t.get("named")
        if not nm: continue
        who = nm["name"]; role = nm["role"]
        side_club = team_of_name(role.split(", ")[-1]) if ", " in role else None
        pool = squad_rows(side_club) if side_club else []
        hit = [p for p in pool if surname(p["name"]) == surname(who)]
        if not side_club: bad(club, f"word {t['id']}", f"named {who} ({role}): club not resolvable")
        elif not hit: bad(club, f"word {t['id']}", f"named {who} ({role}) not in {side_club}'s squad")
        else:
            p = hit[0]
            if (p["minutes"] or 0) == 0: bad(club, f"word {t['id']}", f"named {who} has 0 minutes")
            pos = {"Goalkeeper": "goalkeeper", "Defender": "defender", "Midfielder": "midfielder", "Attacker": "forward"}.get(p["position"], "?")
            if pos not in role.lower(): bad(club, f"word {t['id']}", f"{who} called '{role}', squad says {p['position']}")
            if side_club not in (club, opp_id): bad(club, f"word {t['id']}", f"{who} is from {side_club}, neither side of this fixture")
    # ── Calendar words before a game ──
    if ph["kind"] == "before":
        for t in d["words"]:
            if t["when"] and set(t["when"]) <= {"window", "early-season", "run-in"}: bad(club, f"word {t['id']}", f"calendar-only word {t['when']} before a game")
    # ── Slip ──
    if ph["kind"] == "before" and len(d["slip"]) < 3: bad(club, "slip", f"only {len(d['slip'])} sayings offered")
    # ── Copy hygiene across everything ──
    def walk(x):
        if isinstance(x, str): yield x
        elif isinstance(x, dict):
            for v in x.values(): yield from walk(v)
        elif isinstance(x, list):
            for v in x: yield from walk(v)
    for s in walk(d):
        if "—" in s and not s.startswith("http"): bad(club, "copy", f"em dash: {s[:80]}")
        if "[his" in s or "{ours" in s or "{theirs" in s or "{slot" in s: bad(club, "copy", f"unfilled placeholder: {s[:80]}")

print(f"== {len(issues)} automatic failures ==")
for c, w, m in issues: print(f"  ✗ {c:15} {w:28} {m}")
print(f"\n== {len(manual)} for the manual/web pass ==")
for c, w, m in manual: print(f"  ? {c:15} {w:28} {m}")
json.dump({"issues": issues, "manual": manual}, open(f"{S}/check-{label}.json", "w"), indent=1)
