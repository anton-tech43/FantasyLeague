#!/usr/bin/env python3
"""Import a club's sticker SHEET (a grid of players, name label under each).

    python3 tools/portraits/import_sheet.py <sheet.png> <team_id> <official_squad.json> [--dry-run]

For each name label found by OCR (ocr_boxes.swift):
  1. the player is cut out of the cell above his label, and the background
     outside the sticker's white outline is cleared (black, grey or
     transparent sheets alike), the label itself left behind;
  2. the label is matched to the Premier League's own squad list for the club
     (official_squad.json, the endpoint official-squads reads): that decides
     whether he is at the club and gives his shirt number;
  3. he is matched to our players row, whose name gives the asset key the app
     looks up (PlayerPortrait: surname, or the whole name when shared);
  4. the asset bw-<team>-<key> is written.
Prints a JSON report: imported, labels not in the official squad, official
squad players with no sticker, and the club's manager if he is on the sheet.
"""
import difflib, json, re, subprocess, sys, unicodedata
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios/GoalDigger/Resources/Assets.xcassets/Portraits"
OCR = Path(__file__).with_name("ocr_boxes.swift")
MAX_H = 700

def fold(s):
    s = (s or "").translate(str.maketrans("АВЕКМНОРСТХУаеорсху", "ABEKMHOPCTXYaeopcxy"))
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    for a, b in (("ø", "o"), ("æ", "ae"), ("ı", "i"), ("ł", "l"), ("đ", "d"), ("ß", "ss")):
        s = s.replace(a, b)
    return " ".join(re.sub(r"[^a-z0-9\- ]+", " ", s).split())

def app_folded(s):  # PlayerPortrait.folded: letters, digits and '-' only
    return " ".join(re.sub(r"[^a-z0-9\-]+", " ", fold(s)).split())

def labels(sheet):
    out = subprocess.run(["swift", str(OCR), str(sheet)], check=True, capture_output=True, text=True).stdout
    boxes = []
    for line in out.splitlines():
        x, y, w, h, t = line.split("\t", 4)
        t = t.strip()
        if len(re.sub(r"[^A-Za-z]", "", t)) >= 3:
            boxes.append({"x": float(x), "y": float(y), "w": float(w), "h": float(h), "text": t})
    return boxes

SPONSORS = {"hollywood", "bets", "betano", "bj88", "emirates", "etihad", "airways", "fly", "better", "stake",
            "sportsbet", "kaiyun", "bc", "game", "visit", "rwanda", "aramco", "sbotop", "com"}

def merge(boxes):
    """Rejoin a label the OCR read as two boxes on one line ("AMADOI", "ONANA")."""
    boxes = sorted(boxes, key=lambda b: (round(b["y"] / 20), b["x"]))
    out = []
    for b in boxes:
        if out and abs(out[-1]["y"] - b["y"]) < 12 and 0 <= b["x"] - (out[-1]["x"] + out[-1]["w"]) < 30:
            a = out[-1]
            a["text"] = a["text"] + " " + b["text"]; a["w"] = b["x"] + b["w"] - a["x"]; a["h"] = max(a["h"], b["h"])
        else:
            out.append(dict(b))
    return out

def on_plate(img, b):
    """A name label sits on a white plate with background under it; a shirt
    sponsor ("HOLLYWOOD", "bj88") has more shirt under it."""
    a = np.array(img.convert("RGBA")).astype(int)
    H, W = a.shape[:2]
    y = int(b["y"] + b["h"] + 16)
    if y >= H: return True
    xs = [int(b["x"] + b["w"] * f) for f in (0.2, 0.5, 0.8)]
    bg = 0
    for yy in (y, min(H - 1, y + 6)):
        for x in xs:
            r, g, bl, al = a[yy, min(W - 1, x)]
            if al < 30 or (r + g + bl) / 3 < 70: bg += 1
    return bg >= 4

def grid(boxes, W, H):
    """Cell bounds per label: columns split at midpoints between label
    centres in its row; a row runs from the row above's labels to its own."""
    rows = []
    for b in sorted(boxes, key=lambda b: b["y"]):
        if rows and abs(rows[-1][0]["y"] - b["y"]) < 40: rows[-1].append(b)
        else: rows.append([b])
    cells = []
    for ri, row in enumerate(rows):
        row.sort(key=lambda b: b["x"])
        # Clear of the plates: a plate runs ~10px past its text both ways, and
        # its edge left a white line over the head of the man below.
        top = 0 if ri == 0 else max(b["y"] + b["h"] for b in rows[ri - 1]) + 16
        for ci, b in enumerate(row):
            cx = b["x"] + b["w"] / 2
            left = 0 if ci == 0 else (cx + row[ci - 1]["x"] + row[ci - 1]["w"] / 2) / 2
            right = W if ci == len(row) - 1 else (cx + row[ci + 1]["x"] + row[ci + 1]["w"] / 2) / 2
            bottom = b["y"] - 12
            cells.append((b, (int(left), int(top), int(right), int(bottom))))
    return cells

_FILLED = {}
def sheet_filled(img):
    """Every sticker on an opaque sheet as a filled shape, outlines closed on
    the whole sheet at once: a cell's cut breaks an outline that the full
    sheet still has whole."""
    k = id(img)
    if k not in _FILLED:
        a = np.array(img.convert("RGB")).astype(int).mean(axis=2)
        white = ndimage.binary_dilation(a > 200, iterations=2)
        _FILLED[k] = ndimage.binary_fill_holes(white)
    return _FILLED[k]

_COMPS = {}
def sheet_components(img):
    """Every sticker on the sheet as one labelled shape: opaque sheets by
    their filled outlines, transparent ones by alpha."""
    k = id(img)
    if k not in _COMPS:
        a = np.array(img.convert("RGBA"))
        if a[:, :, 3].min() < 250:
            mask = ndimage.binary_fill_holes(a[:, :, 3] > 40)
        else:
            mask = sheet_filled(img)
        lab, n = ndimage.label(mask)
        objs = ndimage.find_objects(lab)
        _COMPS[k] = (a, lab, objs)
    return _COMPS[k]

def whole(img, b, cell_w, cell_top=0):
    """The sticker right above this label, whole, or None when it has merged
    with a neighbour (then the cell cut is used)."""
    a, lab, objs = sheet_components(img)
    cx = b["x"] + b["w"] / 2
    best = None
    for i, sl in enumerate(objs):
        if sl is None: continue
        ys, xs = sl
        # Its foot just above the label, or running on into the label's
        # plate (Forest's sheet): then it is cut off at the label's top.
        if not (b["y"] - 90 <= ys.stop <= b["y"] + b["h"] + 30): continue
        if not (xs.start <= cx <= xs.stop) or ys.start > b["y"] - 80: continue
        # Not a chain down the sheet: it starts below the row above's labels.
        if ys.start < cell_top - 60: continue
        area = (ys.stop - ys.start) * (xs.stop - xs.start)
        if best is None or area > best[0]: best = (area, i + 1, sl)
    if not best: return None
    _, k, (ys, xs) = best
    if xs.stop - xs.start > 1.5 * cell_w or ys.stop - ys.start < 80: return None
    ys = slice(ys.start, min(ys.stop, int(b["y"]) - 4))
    crop = a[ys, xs].copy()
    keep = lab[ys, xs] == k
    lum = crop[:, :, :3].astype(int).mean(axis=2)
    if (lum[keep] < 200).mean() < 0.45: return None
    alpha = crop[:, :, 3]
    crop[:, :, 3] = np.where(keep, np.where(alpha < 250, alpha, 255), 0)
    im = Image.fromarray(crop)
    if im.height > MAX_H: im = im.resize((round(im.width * MAX_H / im.height), MAX_H), Image.LANCZOS)
    return trim_plate(im.convert("LA"))

def cut(img, box, cx=None):
    """The sticker over one label. The area is widened past the cell, since a
    sticker's elbows reach into the next one, and the sticker kept is the one
    whose outline sits nearest the label's centre."""
    W, H = img.size
    l, t, r, btm = box
    pad = int((r - l) * 0.25)
    wl, wr = max(0, l - pad), min(W, r + pad)
    crop = np.array(img.crop((wl, t, wr, btm)).convert("RGBA"))
    if crop.shape[0] < 60: return None
    rgb = crop[:, :, :3].astype(int); alpha = crop[:, :, 3]
    lum = rgb.mean(axis=2)
    centre = (cx if cx is not None else (l + r) / 2) - wl
    if alpha.min() < 250:                       # a transparent sheet
        mask = alpha > 40
        lab, n = ndimage.label(mask)
        if n == 0: return None
        best = pick(lab, n, mask, centre)
        sticker = ndimage.binary_fill_holes(lab == best)
    else:                                       # black or grey background
        filled = sheet_filled(img)[t:btm, wl:wr]
        labf, nf = ndimage.label(filled)
        if nf:
            st = labf == pick(labf, nf, filled, centre)
            # A gap of a pixel or two in the outline over a dark shirt lets the
            # fill leak out, leaving the shirt see-through (Röhl, 2026-10-02):
            # close the gaps first, kept only when that fills a lot more.
            closed = ndimage.binary_fill_holes(close_edges(ndimage.binary_closing(st, iterations=2)))
            if closed.sum() > 1.2 * st.sum(): st = closed
            # Real only if the inside is the player, not the whole cell.
            if st.sum() >= 0.25 * (crop.shape[0] * (r - l)) and (lum[st] < 200).mean() > 0.45 \
                    and st.sum() < 0.95 * st.size:
                return finish(crop, st, alpha, centre, (l - wl, r - wl))
        # Thickened by two pixels first: where the outline thins over a
        # shoulder it fell apart into pieces that never closed.
        white = ndimage.binary_dilation(lum > 200, iterations=2)
        lab, n = ndimage.label(white)
        if n == 0: return None
        best = pick(lab, n, white, centre)
        ring = lab == best
        # Where the cut's bottom edge crosses the shirt the ring is open:
        # close it between the outline's two sides, then fill it in.
        # Close it along every edge it reaches: a head can touch the top of
        # the area and an elbow the sides, not only the shirt the bottom.
        ring = close_edges(ring)
        sticker = ndimage.binary_fill_holes(ring)
    def real(st):
        # A man, not an outline: big enough, and mostly not white inside.
        return st.sum() >= 0.25 * (crop.shape[0] * (r - l)) and (lum[st] < 200).mean() > 0.45
    if alpha.min() >= 250 and not real(sticker):
        # Second way: clear the background from the top and the sides, with
        # the bottom edge a wall, and keep the part nearest the label.
        nonwhite = lum < 200
        nonwhite[-1, :] = False
        lab2, _ = ndimage.label(nonwhite)
        edges = set(np.unique(np.concatenate([lab2[0], lab2[:, 0], lab2[:, -1]]))) - {0}
        rest = ~np.isin(lab2, list(edges))
        lab3, n3 = ndimage.label(rest)
        if n3: sticker = ndimage.binary_fill_holes(lab3 == pick(lab3, n3, rest, centre))
    if not real(sticker): return None
    return finish(crop, sticker, alpha, centre, (l - wl, r - wl))

def finish(crop, sticker, alpha, centre=None, cell=None):
    # Neighbours whose outlines touch this one hang on by thin bridges:
    # cut those, keep the player nearest the label, and grow him back.
    if centre is not None:
        opened = ndimage.binary_opening(sticker, iterations=4)
        lab, n = ndimage.label(opened)
        if n > 1:
            core = lab == pick(lab, n, opened, centre)
            sticker = sticker & ndimage.binary_dilation(core, iterations=6)
    # Still reaching the widened area's edge means a neighbour is joined on
    # (Brentford's white stripes meet the next man's): keep to his own cell.
    if cell is not None and (sticker[:, 0].any() or sticker[:, -1].any()):
        clip = np.zeros_like(sticker); clip[:, cell[0]:cell[1]] = True
        sticker = sticker & clip
    out = crop.copy()
    out[:, :, 3] = np.where(sticker, np.where(alpha < 250, alpha, 255) if alpha.min() < 250 else 255, 0)
    im = Image.fromarray(out)
    im = im.crop(im.getbbox())
    if im.height > MAX_H: im = im.resize((round(im.width * MAX_H / im.height), MAX_H), Image.LANCZOS)
    return trim_plate(im.convert("LA"))

def trim_plate(im):
    """Drop the plate's white top edge where it hangs under the shirt: the
    bottom rows (a few) that are paper white. A white kit is not: photo
    white is shaded, under a tenth of it is past 240 (Fulham, Spurs)."""
    a = np.array(im)
    lum, alpha = a[:, :, 0].astype(int), a[:, :, -1]
    cut = a.shape[0]
    while cut > a.shape[0] - 12:
        on = alpha[cut - 1] > 128
        if on.sum() >= 5 and (lum[cut - 1][on] > 240).mean() < 0.3: break
        cut -= 1
    if cut == a.shape[0] - 12: return im      # twelve rows of it: not a plate
    im = im.crop((0, 0, im.width, cut))
    return im.crop(im.getbbox()) if im.getbbox() else im

def close_edges(ring):
    ring = ring.copy()
    for edge in (ring[0, :], ring[-1, :], ring[:, 0], ring[:, -1]):
        pass
    h, w = ring.shape
    band = 6
    top = np.where(ring[:band].any(axis=0))[0]
    if top.size >= 2: ring[0, top.min():top.max() + 1] = True
    bot = np.where(ring[-band:].any(axis=0))[0]
    if bot.size >= 2: ring[-1, bot.min():bot.max() + 1] = True
    left = np.where(ring[:, :band].any(axis=1))[0]
    if left.size >= 2: ring[left.min():left.max() + 1, 0] = True
    right = np.where(ring[:, -band:].any(axis=1))[0]
    if right.size >= 2: ring[right.min():right.max() + 1, -1] = True
    return ring

def pick(lab, n, mask, centre):
    """Of the big components, the one whose middle is nearest the label."""
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    big = [i + 1 for i, sz in enumerate(sizes) if sz >= 0.15 * sizes.max()]
    def dist(k):
        xs = np.where((lab == k).any(axis=0))[0]
        return abs((xs.min() + xs.max()) / 2 - centre)
    return min(big, key=dist)

def match_official(text, official):
    t = fold(text); toks = set(t.split())
    for o in official:
        if fold(o["name"]["display"]) == t: return o
    def tokset(o):
        base = (fold(o["name"]["display"]) + " " + fold(o["name"].get("first", "")) + " " + fold(o["name"].get("last", ""))).split()
        return set(base) | {p for w in base for p in w.split("-")}
    hits = [o for o in official if t.split() and t.split()[-1] in tokset(o)]
    if len(hits) > 1: hits = [o for o in hits if toks <= tokset(o)] or [o for o in hits if t.split()[0] in tokset(o)]
    if len(hits) == 1: return hits[0]
    hits = [o for o in official if len(toks & tokset(o)) >= 2]
    if len(hits) == 1: return hits[0]
    # The OCR misreads a letter or two, or cuts the end off ("BRODKS",
    # "CALVERT-LEWI"): the closest whole name, if it is close and alone.
    near = sorted(((difflib.SequenceMatcher(None, t, fold(o["name"]["display"])).ratio(), i)
                   for i, o in enumerate(official)), reverse=True)
    if near and near[0][0] >= 0.85 and (len(near) == 1 or near[0][0] - near[1][0] >= 0.1):
        return official[near[0][1]]
    return None

def match_row(official_player, rows):
    """Our players row for an official man: the same logic as official-squads."""
    disp = fold(official_player["name"]["display"]); first = fold(official_player["name"].get("first", ""))
    last = fold(official_player["name"].get("last", ""))
    toks = set((disp + " " + first + " " + last).split())
    cands = []
    for r in rows:
        ours = fold(r["name"]).split()
        if not ours: continue
        if " ".join(ours) == disp: return r
        if ours[-1] in toks or any(part in toks for part in ours[-1].split("-") if len(part) > 2):
            ini = ours[0] if len(ours[0]) == 1 else None
            if ini and not (first.startswith(ini) or disp.startswith(ini)): continue
            cands.append(r)
        elif len(ours) == 1 and (first == ours[0] or disp.split()[0] == ours[0]):
            cands.append(r)
    if len(cands) == 1: return cands[0]
    # A spelling apart ("Yarmoliuk" / "Yarmolyuk"): the one close surname.
    import difflib
    close = [r for r in rows if fold(r["name"]).split() and
             difflib.SequenceMatcher(None, fold(r["name"]).split()[-1], last.split()[-1] if last else disp.split()[-1]).ratio() >= 0.8]
    return close[0] if len(close) == 1 else None

def key_for(name, rows):
    s = app_folded(name).split()
    sur = s[-1] if s else ""
    shared = sum(1 for r in rows if (app_folded(r["name"]).split() or [""])[-1] == sur) > 1
    return "-".join(s) if shared and len(s) > 1 else sur

def write(name, im):
    d = ASSETS / f"{name}.imageset"; d.mkdir(parents=True, exist_ok=True)
    im.save(d / f"{name}.png", optimize=True)
    (d / "Contents.json").write_text(json.dumps({"images": [{"filename": f"{name}.png", "idiom": "universal"}],
                                                 "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

def main():
    sheet, team, offpath = sys.argv[1], sys.argv[2], sys.argv[3]
    dry = "--dry-run" in sys.argv
    global ASSETS
    if "--out" in sys.argv: ASSETS = Path(sys.argv[sys.argv.index("--out") + 1])
    official = json.load(open(offpath))["players"]
    rows = json.loads(psql(f"select coalesce(json_agg(p),'[]') from (select api_player_id, name, number, minutes from players where team_id='{team}') p") or "[]")
    manager = psql(f"select coalesce(manager_name,'') from teams where id='{team}'").strip()
    img = Image.open(sheet).convert("RGBA")
    # On black, so every sheet is cut by its white outlines: on a transparent
    # one the stickers touch, and alpha alone glued the neighbours' elbows on.
    flat = Image.new("RGBA", img.size, (0, 0, 0, 255)); flat.alpha_composite(img); img = flat
    rep = {"team": team, "imported": [], "not_in_official": [], "unread": [], "no_row": []}
    seen = set()
    def is_label(b):
        words = fold(b["text"]).split()
        if words and match_official(b["text"], official): return True
        # The shirt sponsor read badly ("kalyun.com", "1ea kaiyun") is not a
        # name: junk tokens dropped, near-misses of a sponsor count as one.
        words_ = [w for w in words if len(w) > 2 and not re.search(r"\d", w)]
        if not words_ or all(w in SPONSORS or difflib.get_close_matches(w, SPONSORS, 1, 0.6) for w in words_):
            return False
        if manager and words[-1:] == fold(manager).split()[-1:]: return True
        return len(words) >= 2 and on_plate(img, b)
    plates = [b for b in merge(labels(sheet)) if is_label(b)]
    for b, box in grid(plates, *img.size):
        im = whole(img, b, box[2] - box[0], box[1]) or cut(img, box, b["x"] + b["w"] / 2)
        if im is None: rep["unread"].append(b["text"]); continue
        if manager and fold(b["text"]).split()[-1:] == fold(manager).split()[-1:]:
            k = app_folded(manager).split()[-1]
            rep["imported"].append({"label": b["text"], "as": "manager", "asset": f"bw-{team}-{k}"})
            if not dry: write(f"bw-{team}-{k}", im)
            continue
        o = match_official(b["text"], official)
        if not o: rep["not_in_official"].append(b["text"]); continue
        seen.add(o["id"])
        r = match_row(o, rows)
        name = r["name"] if r else o["name"]["display"]
        if not r: rep["no_row"].append(o["name"]["display"])
        k = key_for(name, rows)
        rep["imported"].append({"label": b["text"], "official": o["name"]["display"], "number": o.get("shirtNum"),
                                "ours": r["name"] if r else None, "our_number": r["number"] if r else None,
                                "asset": f"bw-{team}-{k}", "size": list(im.size)})
        if not dry: write(f"bw-{team}-{k}", im)
    rep["official_without_sticker"] = [f"{o['name']['display']} ({o.get('shirtNum')}, {o.get('position')})"
                                       for o in official if o["id"] not in seen]
    print(json.dumps(rep, ensure_ascii=False))

def psql(query):
    """One query, retried: the pooler drops the odd connection. Errors are
    reported without the command, which carries the database URL."""
    import time
    for attempt in range(4):
        r = subprocess.run(["/opt/homebrew/opt/libpq/bin/psql", db(), "-At", "-c", query], capture_output=True, text=True)
        if r.returncode == 0: return r.stdout
        time.sleep(2 * (attempt + 1))
    sys.exit("psql failed: " + r.stderr.strip()[:200])

def db():
    for line in (ROOT / "backend/.env").read_text().splitlines():
        if line.startswith("SUPABASE_DB_URL="): return line.split("=", 1)[1].strip().strip('"')

if __name__ == "__main__":
    main()
