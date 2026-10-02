#!/usr/bin/env python3
"""Import a sheet of player stickers from ANY clubs (name plate under each,
optionally a club line under the name).

    python3 tools/portraits/import_mixed.py <sheet.png> <official_dir> [--dry-run | --out DIR]

<official_dir> holds the Premier League's squad list per club
(tools/audit/export.sh writes it). The club is decided by that list alone,
the league's own registration on the day: a player must be in exactly one
club's squad. Our players table (API-Football) is cross-checked and every
disagreement reported, as is a club line on the plate naming another club.
"""
import difflib, json, sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
import import_sheet as m

def main():
    sheet, offdir = sys.argv[1], Path(sys.argv[2])
    if "--out" in sys.argv: m.ASSETS = Path(sys.argv[sys.argv.index("--out") + 1])
    dry = "--dry-run" in sys.argv
    official = {f.stem: json.load(open(f))["players"] for f in offdir.glob("*.json")}
    names = dict(l.split("|", 1) for l in m.psql("select id || '|' || display_name from teams where league_id = 39 and is_active").splitlines())
    img = Image.open(sheet).convert("RGBA")
    flat = Image.new("RGBA", img.size, (0, 0, 0, 255)); flat.alpha_composite(img); img = flat
    boxes = m.merge(m.labels(sheet))
    rep = {"imported": [], "unmatched": [], "in_two_squads": [], "club_line_disagrees": [], "feed_disagrees": [], "unread": []}
    plates = []
    for b in boxes:
        hits = [(c, o) for c, squad in official.items() if (o := m.match_official(b["text"], squad))]
        if not hits:
            if len(m.fold(b["text"]).split()) >= 1 and m.on_plate(img, b) and not any(
                    difflib.SequenceMatcher(None, m.fold(b["text"]), m.fold(n)).ratio() > 0.7 for n in names.values()):
                rep["unmatched"].append(b["text"])
            continue
        if len(hits) > 1:
            # "BEN WHITE" also hits Gibbs-White on a shared word: the closest
            # whole name wins when it is clearly closest.
            score = sorted(((difflib.SequenceMatcher(None, m.fold(b["text"]), m.fold(o["name"]["display"])).ratio(), i)
                            for i, (c, o) in enumerate(hits)), reverse=True)
            if score[0][0] >= 0.85 and score[0][0] - score[1][0] >= 0.1: hits = [hits[score[0][1]]]
        if len(hits) > 1:
            rep["in_two_squads"].append(f"{b['text']}: " + ", ".join(f"{c} {o['name']['display']}" for c, o in hits)); continue
        club = next((c for c in boxes if 0 < c["y"] - b["y"] < 3 * b["h"]
                     and abs((c["x"] + c["w"] / 2) - (b["x"] + b["w"] / 2)) < 60), None)
        plates.append((dict(b, h=(club["y"] + club["h"] - b["y"]) if club else b["h"]), hits[0], club and club["text"]))
    plates.sort(key=lambda p: p[0]["y"])
    cells = {id(p[0]): box for p in plates for b, box in m.grid([q[0] for q in plates], *img.size) if b is p[0]}
    for b, (team, o), club_text in plates:
        disp = names.get(team, team)
        if club_text and difflib.SequenceMatcher(None, m.fold(club_text), m.fold(disp)).ratio() < 0.6 \
                and m.fold(disp).split()[0] not in m.fold(club_text):
            rep["club_line_disagrees"].append(f"{b['text']}: plate says {club_text}, PL squad {disp}")
        rows = json.loads(m.psql(f"select coalesce(json_agg(p),'[]') from (select api_player_id, name, number, minutes, team_id from players where team_id='{team}') p") or "[]")
        r = m.match_row(o, rows)
        if not r:
            elsewhere = json.loads(m.psql("select coalesce(json_agg(p),'[]') from (select team_id, name from players where name ilike '%"
                                          + m.fold(o["name"].get("last") or o["name"]["display"]).split()[-1].replace("'", "") + "%') p") or "[]")
            rep["feed_disagrees"].append(f"{o['name']['display']}: PL squad {disp}, our feed " + (", ".join(f"{e['name']} at {e['team_id']}" for e in elsewhere) or "nowhere"))
        box = cells[id(b)]
        im = m.whole(img, b, box[2] - box[0], box[1]) or m.cut(img, box, b["x"] + b["w"] / 2)
        if im is None: rep["unread"].append(b["text"]); continue
        key = f"bw-{team}-{m.key_for(r['name'] if r else o['name']['display'], rows)}"
        rep["imported"].append({"label": b["text"], "club": disp, "number": o.get("shirtNum"), "loan": o.get("loan"),
                                "joined": (o.get("dates") or {}).get("joinedClub"), "asset": key})
        if not dry: m.write(key, im)
    print(json.dumps(rep, ensure_ascii=False, indent=1))

if __name__ == "__main__":
    main()
