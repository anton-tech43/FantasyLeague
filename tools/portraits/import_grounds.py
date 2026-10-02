#!/usr/bin/env python3
"""Import a sheet of stadium stickers, plate = club over ground.

    python3 tools/portraits/import_grounds.py <sheet.png> [--dry-run | --out DIR]

The club line is matched to teams.display_name; the ground line is checked
against that club's basics.stadium on its team page, and any mismatch is
reported. Writes ground-<club> into Assets.xcassets/Grounds.
"""
import difflib, json, sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
import import_sheet as m

def main():
    sheet = sys.argv[1]
    m.ASSETS = m.ROOT / "ios/GoalDigger/Resources/Assets.xcassets/Grounds"
    if "--out" in sys.argv: m.ASSETS = Path(sys.argv[sys.argv.index("--out") + 1])
    dry = "--dry-run" in sys.argv
    teams = json.loads(m.psql("select json_agg(t) from (select id, display_name, (select content->'cards'->'basics'->>'stadium' "
                              "from team_pages where team_id = id) stadium from teams where league_id = 39 and is_active) t"))
    img = Image.open(sheet).convert("RGBA")
    flat = Image.new("RGBA", img.size, (0, 0, 0, 255)); flat.alpha_composite(img); img = flat
    boxes = m.merge(m.labels(sheet))
    def club_of(text):
        s = sorted(((difflib.SequenceMatcher(None, m.fold(text), m.fold(t["display_name"])).ratio(), i) for i, t in enumerate(teams)), reverse=True)
        return teams[s[0][1]] if s[0][0] >= 0.9 and s[0][0] - s[1][0] >= 0.1 else None
    plates = []
    for b in boxes:
        t = club_of(b["text"])
        if not t: continue
        ground = next((c for c in boxes if 0 < c["y"] - b["y"] < 3 * b["h"] and abs((c["x"] + c["w"] / 2) - (b["x"] + b["w"] / 2)) < 60), None)
        plates.append((dict(b, h=(ground["y"] + ground["h"] - b["y"]) if ground else b["h"]), t, ground and ground["text"]))
    # The club's name is also painted on its stand ("ASTON VILLA" over Villa
    # Park): the plate is the lowest one.
    lowest = {}
    for p in plates:
        if p[1]["id"] not in lowest or p[0]["y"] > lowest[p[1]["id"]][0]["y"]: lowest[p[1]["id"]] = p
    plates = list(lowest.values())
    rep = {"imported": [], "ground_differs": [], "unread": [], "not_on_sheet": []}
    cells = {id(b): box for b, box in m.grid([p[0] for p in plates], *img.size)}
    for b, t, ground in plates:
        ours = (t["stadium"] or "").split(",")[0]
        if not ground or difflib.SequenceMatcher(None, m.fold(ground), m.fold(ours)).ratio() < 0.8:
            rep["ground_differs"].append(f"{t['id']}: plate {ground!r}, our page {ours!r}")
        box = cells[id(b)]
        im = m.whole(img, b, box[2] - box[0], box[1]) or m.cut(img, box, b["x"] + b["w"] / 2)
        if im is None: rep["unread"].append(b["text"]); continue
        rep["imported"].append({"club": t["id"], "asset": f"ground-{t['id']}", "size": list(im.size)})
        if not dry: m.write(f"ground-{t['id']}", im)
    seen = {i["club"] for i in rep["imported"]}
    rep["not_on_sheet"] = [t["id"] for t in teams if t["id"] not in seen]
    print(json.dumps(rep, ensure_ascii=False, indent=1))

if __name__ == "__main__":
    main()
