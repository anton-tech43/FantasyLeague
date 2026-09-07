#!/usr/bin/env python3
"""build_drills.py — writes ios/GoalDigger/Resources/MyTurn/drills.json.

Six decks. Two are derived in the app (Lines from Say This, Terms from Lingo);
four are static and built here so the data lives in one place:

  kits       — drawn by the app from a colour + pattern spec, not a PNG. The
               spec's one hard rule for kits is that all twenty sit on the
               same silhouette; a vector shirt guarantees that exactly, and
               nobody has to redraw twenty PNGs when a club changes sponsor.
  badges     — badges/<club-id>.png (API-Football CDN, 150x150, fetched once).
  nicknames  — "The Gunners" → Arsenal.
  players    — players/<player-id>.png, back is the NAME ONLY. Rebuilt once a
               season from players_deck_source.txt (team|name|slug|api_id),
               which tools/myturn/refresh_players.sh regenerates from the DB.

Club ids are kebab-case and stable; the app maps Team.rawValue (snake_case)
to them by swapping _ for -.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "ios", "GoalDigger", "Resources", "MyTurn", "drills.json")
VERSION = "2026-09-07.1"

# id, display name, nickname, home kit (primary, secondary, pattern, shorts)
CLUBS = [
    ("arsenal",        "Arsenal",                  "The Gunners",      ("#EF0107", "#FFFFFF", "sleeves",   "#FFFFFF")),
    ("aston-villa",    "Aston Villa",              "The Villans",      ("#670E36", "#95BFE5", "sleeves",   "#FFFFFF")),
    ("bournemouth",    "AFC Bournemouth",          "The Cherries",     ("#DA291C", "#000000", "stripes",   "#000000")),
    ("brentford",      "Brentford",                "The Bees",         ("#E30613", "#FFFFFF", "stripes",   "#000000")),
    ("brighton",       "Brighton & Hove Albion",   "The Seagulls",     ("#0057B8", "#FFFFFF", "stripes",   "#FFFFFF")),
    ("chelsea",        "Chelsea",                  "The Blues",        ("#034694", "#FFFFFF", "plain",     "#034694")),
    ("coventry",       "Coventry City",            "The Sky Blues",    ("#78D0F5", "#FFFFFF", "plain",     "#78D0F5")),
    ("crystal-palace", "Crystal Palace",           "The Eagles",       ("#C4122E", "#1B458F", "stripes",   "#1B458F")),
    ("everton",        "Everton",                  "The Toffees",      ("#003399", "#FFFFFF", "plain",     "#FFFFFF")),
    ("fulham",         "Fulham",                   "The Cottagers",    ("#FFFFFF", "#000000", "plain",     "#000000")),
    ("hull",           "Hull City",                "The Tigers",       ("#F5A12D", "#000000", "stripes",   "#000000")),
    ("ipswich",        "Ipswich Town",             "The Tractor Boys", ("#0E3DA6", "#FFFFFF", "sleeves",   "#FFFFFF")),
    ("leeds",          "Leeds United",             "The Whites",       ("#FFFFFF", "#1D428A", "plain",     "#FFFFFF")),
    ("liverpool",      "Liverpool",                "The Reds",         ("#C8102E", "#FFFFFF", "plain",     "#C8102E")),
    ("man-city",       "Manchester City",          "The Citizens",     ("#6CABDD", "#FFFFFF", "plain",     "#FFFFFF")),
    ("man-utd",        "Manchester United",        "The Red Devils",   ("#DA291C", "#FFFFFF", "plain",     "#FFFFFF")),
    ("newcastle",      "Newcastle United",         "The Magpies",      ("#241F20", "#FFFFFF", "stripes",   "#241F20")),
    ("nottm-forest",   "Nottingham Forest",        "The Tricky Trees", ("#DD0000", "#FFFFFF", "plain",     "#FFFFFF")),
    ("spurs",          "Tottenham Hotspur",        "Spurs",            ("#FFFFFF", "#132257", "plain",     "#132257")),
    ("sunderland",     "Sunderland",               "The Black Cats",   ("#EB172B", "#FFFFFF", "stripes",   "#000000")),
]


def players():
    src = os.path.join(HERE, "players_deck_source.txt")
    out = []
    for line in open(src, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        team, name, slug, _api = line.split("|")
        out.append({"id": f"player-{slug}", "frontType": "image", "front": f"players/{slug}.png", "back": name})
    return out


decks = [
    {"id": "lines", "label": "Lines", "source": "saythis"},
    {"id": "terms", "label": "Terms", "source": "lingo"},
    {"id": "kits", "label": "Kits", "source": "static", "cards": [
        {"id": f"kit-{cid}", "frontType": "kit",
         "front": {"primary": k[0], "secondary": k[1], "pattern": k[2], "shorts": k[3]},
         "back": name}
        for cid, name, _nick, k in CLUBS
    ]},
    {"id": "badges", "label": "Badges", "source": "static", "cards": [
        {"id": f"badge-{cid}", "frontType": "image", "front": f"badges/{cid}.png", "back": name}
        for cid, name, _nick, _k in CLUBS
    ]},
    {"id": "nicknames", "label": "Nicknames", "source": "static", "cards": [
        {"id": f"nick-{cid}", "frontType": "text", "front": nick, "back": name}
        for cid, name, nick, _k in CLUBS
    ]},
    {"id": "players", "label": "Players", "source": "static", "cards": players()},
]

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"contentVersion": VERSION, "decks": decks}, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {OUT}: " + ", ".join(f"{d['id']} {len(d.get('cards', []))}" for d in decks))
