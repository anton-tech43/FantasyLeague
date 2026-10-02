#!/usr/bin/env python3
"""Import a sheet of MANAGER stickers, any clubs, plate = name over club.

    python3 tools/portraits/import_managers.py <sheet.png> [--dry-run | --out DIR]

Each plate's name is matched to teams.manager_name (human-verified, migration
085), which gives the club; the club line on the plate must agree. Writes
bw-<club>-<surname>, the key PlayerPortrait looks a manager up by.
"""
import difflib, json, sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
import import_sheet as m

def main():
    sheet = sys.argv[1]
    if "--out" in sys.argv: m.ASSETS = Path(sys.argv[sys.argv.index("--out") + 1])
    dry = "--dry-run" in sys.argv
    teams = json.loads(m.psql("select json_agg(t) from (select id, display_name, manager_name from teams "
                              "where league_id = 39 and is_active and manager_name is not null) t"))
    img = Image.open(sheet).convert("RGBA")
    flat = Image.new("RGBA", img.size, (0, 0, 0, 255)); flat.alpha_composite(img); img = flat
    boxes = m.merge(m.labels(sheet))
    def best(text, field):
        s = sorted(((difflib.SequenceMatcher(None, m.fold(text), m.fold(t[field])).ratio(), i) for i, t in enumerate(teams)), reverse=True)
        return teams[s[0][1]] if s and s[0][0] >= 0.85 else None
    plates = []
    for b in boxes:
        t = best(b["text"], "manager_name")
        if not t: continue
        # The club line under the name: it must name the same club, and the
        # cell above stops at the name, the next row starts below the club.
        club = next((c for c in boxes if 0 < c["y"] - b["y"] < 3 * b["h"] and abs((c["x"] + c["w"] / 2) - (b["x"] + b["w"] / 2)) < 60), None)
        plates.append((dict(b, h=(club["y"] + club["h"] - b["y"]) if club else b["h"]), t, club and club["text"]))
    rep = {"imported": [], "club_line_disagrees": [], "unread": [], "not_on_sheet": []}
    cells = m.grid([p[0] for p in plates], *img.size)
    for (b, box), (_, t, club_text) in zip(cells, sorted(plates, key=lambda p: (round(p[0]["y"] / 40), p[0]["x"]))):
        if club_text and difflib.SequenceMatcher(None, m.fold(club_text), m.fold(t["display_name"])).ratio() < 0.6 \
                and m.fold(t["display_name"]).split()[0] not in m.fold(club_text):
            rep["club_line_disagrees"].append(f"{b['text']} / {club_text} vs {t['display_name']}"); continue
        im = m.whole(img, b, box[2] - box[0], box[1]) or m.cut(img, box, b["x"] + b["w"] / 2)
        if im is None: rep["unread"].append(b["text"]); continue
        key = f"bw-{t['id']}-{m.app_folded(t['manager_name']).split()[-1]}"
        rep["imported"].append({"label": b["text"], "club": t["id"], "asset": key, "replaces": (m.ASSETS / f"{key}.imageset").exists()})
        if not dry: m.write(key, im)
    seen = {i["club"] for i in rep["imported"]}
    rep["not_on_sheet"] = [t["id"] for t in teams if t["id"] not in seen]
    print(json.dumps(rep, ensure_ascii=False, indent=1))

if __name__ == "__main__":
    main()
