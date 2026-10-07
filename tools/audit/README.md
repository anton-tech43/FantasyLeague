# My Turn audit

Everything she sees in My Turn, for all 20 Premier League clubs, checked
against the truth. Run it before every release and after every transfer
window. It costs $0: no paid API calls, only the database, the PL's public
squad lists and the simulator.

```bash
D=/tmp/myturn-audit            # any scratch dir, never the repo
tools/audit/export.sh $D       # the truth: raw payloads, teams, players, pages, official squads
# a DEBUG build installed on the booted simulator, then:
tools/audit/dump.sh $D now                              # what the app shows today
tools/audit/dump.sh $D after 2026-10-13T12:00:00Z       # -gdNow: after the match, the roll to the next one
python3 tools/audit/check.py $D now                     # -> $D/check-now.json
```

- `check.py` fails a question automatically when:
  - a fact disagrees with the raw feed: the opponent, the table, the form, the top scorer, the last meeting, a shirt number or a named player;
  - it doesn't match `teams.manager_name`;
  - the options are wrong: a distractor is also right, or there's the wrong number of them;
  - the explanation contradicts the answer;
  - a slot is left unfilled, or a line has an em dash.

  Anything it can't decide goes under `manual`.
- `REVIEW_BRIEF.md` is the "does this make sense to her" rubric for reviewer agents, five clubs each. Verify every finding before acting on it.
- **Simulator trap**: install the build you just made, not one a DerivedData glob finds: get `TARGET_BUILD_DIR` from `xcodebuild -showBuildSettings` with the same flags as the build (`IOS_GOTCHAS.md` §19). A glob can install a stale build, and every preset is then ignored.

## Portraits (`tools/portraits/import_sheet.py`)

A sticker sheet per club (a grid of players, each with a name plate):

```bash
python3 tools/portraits/import_sheet.py <sheet.png> <team_id> $D/official/<team_id>.json [--dry-run | --out DIR]
```

- It reads each plate and matches it to the PL's official squad, which is the club check and the shirt number.
- It cuts the sticker out with the plate left behind and writes `bw-<club>-<key>`.
- The JSON report lists:
  - stickers not in the official squad (left the club, or the name doesn't exist);
  - squad players with no sticker.
- Always preview with `--out` and look at a contact sheet first.
- Delete the club's old `bw-<club>-*` assets before a real run, so that leavers don't keep a face.
