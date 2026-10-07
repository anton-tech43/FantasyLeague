# docs/system-map — the six models

The handover map. Published privately as an Artifact; **this directory is the source.**

```bash
./scripts/arch-facts.sh        # read the verifiable facts out of the live system
./scripts/verify-arch-map.sh   # does the map still describe it?  (offline, no DB)
python3 -m http.server 8000 --directory docs/system-map   # open it locally
open http://localhost:8000/index.html?check=1             # console must say CHECK OK
```

## Why the facts are generated

The map is 390 hand-written boxes, and hand-written facts rot — eighteen root
documents here already carry a "historical" banner. The map shipped with one
wrong on day one: it said `client-error-alert` had no caller, while
`notification-sender` was calling it on every APNs auth failure.

So the split is: **prose by hand, facts by query.** `arch-facts.sh` writes
`facts.json` from `cron.job`, the functions directory, the fetch cache and the
tables; `app.js` fills the masthead from it; `verify-arch-map.sh` fails if the
map names something that no longer exists, or misses something that does.

`facts.json` is committed because the cloud maintenance routine cannot reach
Postgres (MAINTENANCE.md §1), so the offline check is the one that runs twice a
week. Re-run the generator from a laptop when the system changes.

## Files

| File | What |
|---|---|
| `index.html` | the page: markup, CSS, the prose sections |
| `data.js` | models 1 and 2 — what runs when, where the code lives |
| `model3.js` | models 3 and 4 — the timetable, and what sends a push |
| `model5.js` | model 5 — what was deliberately not built |
| `model6.js` | model 6 — what has gone wrong, in order |
| `plain.js` | one plain-English line per box, for a non-technical reader |
| `app.js` | the renderer: grid → SVG, the panel, blast radius, the self-check |
| `files.js` | the searchable file index at the foot of the page |
| `facts.json` | **generated** — do not hand-edit |
| `status-overrides.json` | the four functions where "has a caller" ≠ "can run", each naming the gate that makes it so |

## Adding a box

Every node carries its own `[col, row]`. Nothing is laid out automatically, so a
new box is a cell you choose. `?check=1` asserts: ids unique, every edge resolves,
no two boxes in one cell, every box inside a band, every cross-link real, and
every box with something to show a non-technical reader. It caught nine empty
panels in this directory's own first draft.

Keep `PUSH_RULES.md` in mind for anything about notifications — that page is a
contract with its own check, and the map defers to it.
