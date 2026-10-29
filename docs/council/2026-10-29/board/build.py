"""Merge census + editor verdicts + dependency check + Swedish explanations into the board page."""
import base64, csv, json, os, subprocess

S = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V = os.path.join(S, "verdicts")
B = os.path.join(S, "board")
GROUPS = ("FIRST", "FEED_LOCK", "TEAM_MD", "MY_SET")

census = {}
for f in ("census-app.csv", "census-other.csv"):
    for r in csv.DictReader(open(os.path.join(S, f))):
        census[r["id"]] = r

dep = {}
p = os.path.join(V, "dependency.csv")
if os.path.exists(p):
    for r in csv.DictReader(open(p)):
        dep[r["id"]] = r

exp_rows, exp_screens = {}, {}
for g in GROUPS:
    p = os.path.join(B, f"explain-{g}.json")
    if os.path.exists(p):
        j = json.load(open(p))
        exp_rows.update(j.get("rows", {}))
        exp_screens.update(j.get("screens", {}))


def thumb(rel):
    """A small JPEG data URI of a screenshot, or None."""
    if not rel:
        return None
    src = os.path.join(S, rel)
    if not os.path.exists(src):
        return None
    out = os.path.join(B, "tmp", rel.replace("/", "__") + ".jpg")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if not os.path.exists(out):
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "55", "-Z", "560", src, "--out", out],
                       check=True, capture_output=True)
    return "data:image/jpeg;base64," + base64.b64encode(open(out, "rb").read()).decode()


VALID = {"Keep", "Iterate", "Move", "Delete"}
rows, missing = [], []
for g in GROUPS:
    for r in csv.DictReader(open(os.path.join(V, f"{g}.csv"))):
        c = census[r["id"]]
        v, dg, depnote = r["verdict"], "", ""
        d = dep.get(r["id"])
        if d:
            depnote = "; ".join(x for x in (
                d.get("readers") and "Read by: " + d["readers"],
                d.get("producer") and "Made by: " + d["producer"],
                d.get("old_build_risk") and "Old builds: " + d["old_build_risk"],
                d.get("note")) if x)
            if d.get("result") == "DOWNGRADE":
                dg = "en bakgrundsrutin måste köras vidare så länge 2.2/2.3 används"
        assert v in VALID, (r["id"], v)
        x = exp_rows.get(r["id"]) or {}
        if not x:
            missing.append(r["id"])
        rows.append({
            "id": r["id"], "ch": c["chapter"], "el": c["element"], "t": (c["text"] or "")[:400], "v": v, "dg": dg,
            "h": r["how_or_where"], "w": r["why"], "e": r["evidence"], "conf": r["confidence"],
            "u": r["usage_can_settle"], "dep": depnote,
            "what": x.get("what", ""), "proposal": x.get("proposal", ""), "why": x.get("why", ""), "ifa": x.get("if_accept", ""),
        })

assert len(rows) == len(census) == len({r["id"] for r in rows}), "coverage gate"
screens = {}
for r in rows:
    k = "-".join(r["id"].split("-")[:2])
    if k in screens:
        continue
    s = exp_screens.get(k) or {}
    screens[k] = {"title": s.get("title") or census[r["id"]]["screen"], "summary": s.get("summary", ""), "img": thumb(s.get("shot"))}

data = {"rows": rows, "screens": screens, **json.load(open(os.path.join(B, "lists.json")))}
html = open(os.path.join(B, "template.html")).read()
blob = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
open(os.path.join(B, "GoalDigger-Council-Board.html"), "w").write(html.replace("__DATA__", blob))
print(len(rows), "rows,", len(rows) - len(missing), "explained,", len(screens), "screens,",
      sum(1 for s in screens.values() if s["img"]), "with picture,", len(blob) // 1024, "KB")
if missing:
    print("missing explanations:", len(missing), missing[:10])
