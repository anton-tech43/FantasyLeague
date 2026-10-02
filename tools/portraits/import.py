#!/usr/bin/env python3
"""Import black-and-white player stickers into the app, one club at a time.

    python3 tools/portraits/import.py <zip-or-folder> <team_id> [--dry-run]
    python3 tools/portraits/import.py --manifest [team_id ...]

Each sticker is a transparent PNG: the player, a gap, and his name on a label
underneath. For every image this:
  1. splits the label off at the transparent gap,
  2. reads the label with macOS's own OCR (ocr.swift) - the label names the
     man, never the file name: Arsenal's bench zip had every file name shifted
     one along against its own labels,
  3. matches that name to the club's squad (players table) or its manager,
  4. writes the body, greyscale with alpha at 700px tall, as the asset
     bw-<team_id>-<key> in Resources/Assets.xcassets/Portraits/, where key is
     the folded surname - or the folded full name when two men in the squad
     share one. PlayerPortrait in the app finds it by that name; no code to
     change per player.
Then it lists who at the club still has no portrait.

--manifest writes tools/portraits/manifest/<team_id>.md for every Premier
League club (or the ones named): each man, his number, minutes, the name to
print on his label, and whether the app has his portrait yet.

Reads the database (backend/.env, SUPABASE_DB_URL) and writes nothing to it.
"""
import io, json, os, re, subprocess, sys, tempfile, unicodedata, zipfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios/GoalDigger/Resources/Assets.xcassets/Portraits"
MANIFEST = ROOT / "tools/portraits/manifest"
OCR = Path(__file__).with_name("ocr.swift")
HEIGHT = 700


def env_db_url():
    for line in (ROOT / "backend/.env").read_text().splitlines():
        if line.startswith("SUPABASE_DB_URL="):
            return line.split("=", 1)[1].strip().strip('"')
    sys.exit("SUPABASE_DB_URL not in backend/.env")


def sql(query):
    out = subprocess.run(["/opt/homebrew/opt/libpq/bin/psql", env_db_url(), "-At", "-F", "\t", "-c", query],
                         check=True, capture_output=True, text=True).stdout
    return [l.split("\t") for l in out.splitlines() if l]


def fold(name):
    s = unicodedata.normalize("NFD", name.lower())
    s = "".join(c for c in s if not unicodedata.combining(c)).replace("ø", "o").replace("æ", "ae")
    return " ".join(re.sub(r"[^a-z0-9\-]+", " ", s).split())


def surname(name):
    parts = fold(name).split()
    return parts[-1] if parts else ""


def squad(team):
    rows = sql(f"select coalesce(number::text,''), name, coalesce(position,''), coalesce(minutes,0) "
               f"from players where team_id = '{team}' order by minutes desc nulls last")
    men = [{"number": r[0], "name": r[1], "position": r[2], "minutes": int(r[3])} for r in rows]
    manager = sql(f"select coalesce(manager_name,'') from teams where id = '{team}'")
    if manager and manager[0][0]:
        men.append({"number": "", "name": manager[0][0], "position": "Manager", "minutes": 0})
    return men


def key_for(man, men):
    """The app's rule (PlayerPortrait): surname, or the whole name when shared."""
    s = surname(man["name"])
    if sum(1 for m in men if surname(m["name"]) == s) > 1:
        return "-".join(fold(man["name"]).split())
    return s


def have(team):
    return {p.name[len(f"bw-{team}-"):-len(".imageset")] for p in ASSETS.glob(f"bw-{team}-*.imageset")}


def split(img):
    """(body, label) at the last transparent gap, or (img, None) without one."""
    a = img.getchannel("A")
    w, h = img.size
    rows = [a.crop((0, y, w, y + 1)).getextrema()[1] > 20 for y in range(h)]
    y = h - 1
    while y > 0 and not rows[y]: y -= 1
    bottom = y
    while y > 0 and rows[y]: y -= 1
    label_top = y
    while y > 0 and not rows[y]: y -= 1
    if y <= 0 or bottom - label_top > h * 0.3:
        return img, None
    body = img.crop((0, 0, w, y + 1))
    label = img.crop((0, label_top, w, bottom + 1))
    return body.crop(body.getbbox()), label.crop(label.getbbox())


def ocr(paths):
    out = subprocess.run(["swift", str(OCR), *map(str, paths)], check=True, capture_output=True, text=True).stdout
    return dict(line.split("\t", 1) for line in out.splitlines() if "\t" in line)


def match(text, men):
    """The one man whose surname, and if possible first name, the label reads."""
    words = set(fold(text).split())
    joined = fold(text)
    hits = [m for m in men if surname(m["name"]) in words or surname(m["name"]) in joined]
    if len(hits) > 1:
        full = [m for m in hits if all(p in words for p in fold(m["name"]).split() if len(p) > 1)]
        hits = full or hits
    return hits[0] if len(hits) == 1 else None


def write_asset(name, body):
    body = body.convert("RGBA")
    r, g, b, a = body.split()
    body.putalpha(a.point(lambda v: 0 if v < 40 else v))   # no near-transparent haze
    body = body.crop(body.getbbox())
    s = HEIGHT / body.height
    body = body.resize((round(body.width * s), HEIGHT), Image.LANCZOS).convert("LA")
    d = ASSETS / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    body.save(d / f"{name}.png", optimize=True)
    (d / "Contents.json").write_text(json.dumps(
        {"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
        indent=2) + "\n")


def load(source):
    src = Path(source)
    if src.is_dir():
        return [(p.name, Image.open(p)) for p in sorted(src.rglob("*.png"))]
    with zipfile.ZipFile(src) as z:
        return [(Path(n).name, Image.open(io.BytesIO(z.read(n))))
                for n in sorted(z.namelist()) if n.lower().endswith(".png") and not Path(n).name.startswith(".")]


def run_import(source, team, dry):
    men = squad(team)
    if not men:
        sys.exit(f"no squad rows for {team}")
    images = load(source)
    tmp = Path(tempfile.mkdtemp())
    parts = []
    for fname, img in images:
        img = img.convert("RGBA")
        if img.getchannel("A").getextrema()[0] == 255:
            print(f"  ✗ {fname}: no transparent background, so no label to split off"); continue
        body, label = split(img)
        if label is None:
            print(f"  ✗ {fname}: no name label under the player"); continue
        lp = tmp / f"{len(parts)}.png"
        bg = Image.new("RGBA", label.size, (255, 255, 255, 255)); bg.alpha_composite(label)
        bg.convert("RGB").save(lp)
        parts.append((fname, body, lp))
    read = ocr([p[2] for p in parts]) if parts else {}
    done = set()
    for fname, body, lp in parts:
        text = read.get(str(lp), "").strip()
        man = match(text, men)
        if not man:
            print(f"  ✗ {fname}: label reads '{text}', which is no one in {team}'s squad"); continue
        key = key_for(man, men)
        stem = fold(Path(fname).stem.replace("_", " "))
        note = "" if surname(man["name"]).replace("-", " ") in stem.replace("-", " ") \
            else f"  (file name says '{Path(fname).stem}': the label wins)"
        print(f"  ✓ {fname}: '{text}' -> {man['name']} -> bw-{team}-{key}{note}")
        if key in done:
            print(f"    ! a second image for {man['name']}; the later one wins")
        done.add(key)
        if not dry:
            write_asset(f"bw-{team}-{key}", body)
    missing = [m for m in men if key_for(m, men) not in have(team) | (done if dry else set())
               and (m["minutes"] > 0 or m["position"] == "Manager")]
    if missing:
        print(f"\n  Still without a portrait at {team} (played this season, plus the manager):")
        for m in missing:
            print(f"    {m['number'] or '–':>3}  {m['name']}  ({m['position']}, {m['minutes']} min)")
    print("\n  Dry run: nothing written." if dry else f"\n  Written to {ASSETS.relative_to(ROOT)}. Rebuild the app.")


def run_manifest(teams):
    if not teams:
        teams = [r[0] for r in sql("select id from teams where league_id = 39 and is_active order by id")]
    MANIFEST.mkdir(parents=True, exist_ok=True)
    for team in teams:
        men = squad(team)
        got = have(team)
        lines = [f"# {team} portraits", "",
                 f"Print each label with the name as written here; the file name does not matter.",
                 f"Import: `python3 tools/portraits/import.py <zip> {team}`", "",
                 "| # | Name on the label | Position | Minutes | Asset | In the app |", "|---|---|---|---|---|---|"]
        for m in men:
            k = key_for(m, men)
            lines.append(f"| {m['number'] or '–'} | {m['name']} | {m['position']} | {m['minutes']} | "
                         f"bw-{team}-{k} | {'yes' if k in got else '—'} |")
        (MANIFEST / f"{team}.md").write_text("\n".join(lines) + "\n")
        print(f"  {team}: {sum(1 for m in men if key_for(m, men) in got)} of {len(men)} in the app")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--manifest":
        run_manifest(args[1:])
    elif len(args) >= 2:
        run_import(args[0], args[1], "--dry-run" in args)
    else:
        sys.exit(__doc__)
