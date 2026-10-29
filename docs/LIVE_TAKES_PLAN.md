# Live takes: plan

**Status:** plan, agreed with Anton on 2026-10-29. Nothing is built yet.

Match statistics turned into one line she can say, so she sounds like one of
the lads (memory: she wants to sound smart). It is the "4. stats" item.

## What she gets

| When | Where | What | New push? |
|---|---|---|---|
| ~30' | Live Activity, the `note` line under the score | a take on how it is going | No. A silent update. |
| Half-time | the existing HT push, in the `Say: "…"` slot | the take, instead of the generic saying | No. Same push, better line. |
| HT tap | live card at the top of her club's feed | the take plus "If someone pushes back: …" | No. |
| ~70' | Live Activity `note` | a second-half take | No. Silent. |
| Full time | Matchday › After, the verdict line | the verdict plus a push-back line | No. |

Silence whenever nothing stands out. A dull game gives no note, the generic
HT saying and today's verdict.

## Rules for every line (from the brainstorm)

- Plain pub talk. No word she could not explain in one sentence: no "xG",
  no "low block". Stats stay hidden; one number is fine when saying it is
  the smart thing ("One shot on target and they score").
- An opinion about what should happen, never a verdict on what the squad
  can do. "They need to shoot from the edge of the box more", not "they need
  someone who'll actually shoot".
- At least two stats must agree before a line fires. A single number is
  never enough.
- Conclusions only, never a reaction to one moment. The feed is minutes
  behind.
- Decided in code, deterministic, with no model call (CLAUDE.md, PUSH_RULES).

## Where it already fits (found 2026-10-29)

- `MatchActivityAttributes.ContentState.note` exists, and the widget draws it
  on the lock screen and in the expanded Dynamic Island (2 lines, 12 pt). It
  has been in every build since 2.1 (235c2a9), so 2.2 and 2.3 show it too,
  and no app build is needed for the Live Activity part. Nothing sets it today.
- The HT push body is `periodBody + Say: "<saying>"` (`goal-push.ts`
  `renderHalfTimePush`, `withSaying`). The take replaces the saying from
  `HT_SAY_*`, and `withSaying` already trims to the lock-screen budget.
- An HT push tap opens her club's feed (`AppDelegate`, `pendingOpenFeed`),
  where `LiveMatchCard` (tier 2+) reads `live-brief-current`, which already
  reads `match_status_state`.
- The After verdict is `renderVerdict` in `_shared/last-match.ts`. It is
  stored in `team_pages.content.cards.last_match` and already gets one
  `/fixtures/statistics` call at full time.

## The traps (each one has a fix in the build)

1. **"They" has no owner on the Live Activity.** Updates go to every
   `kind='update'` token for the fixture, home and away followers alike.
   *Fix:* split the update tokens by `team_ids`. A token following exactly
   one side gets that side's note; a token following both sides or neither
   (WC-era `country_ids` rows) gets no note. Lines name the team ("Arsenal
   have had all the ball…"), because the activity shows two teams.
2. **A note vanishes on the next update.** Every update replaces the whole
   ContentState, so a goal update without `note` wipes it. *Fix:* keep the
   current note per side in `match_status_state` and include it in every
   update. A **score change clears it**: a "they're not hurting them" note
   is wrong the moment they score. The HT status change clears it too, and
   the end state never carries one.
3. **Breaking the minute-only logic.** `sig` is `score-status-minute`, and
   `minuteOnly` strips the last segment. Putting the note into `sig` would
   make a note change look like a goal (priority 10). *Fix:* the note gets its
   own `la_note_sig`. A note-only change is sent at priority 5 on a tick with
   no other update; on a tick with one, it rides along.
4. **A silent update must stay silent.** An `alert` on a Live Activity
   update lights up the screen and can buzz. *Fix:* no `alert` on any update
   that carries a note; a test asserts it.
5. **Firing late.** If a deploy or a missed cron tick lands at 41', a "30
   minutes in" line is wrong. *Fix:* windows are 30'–36' in `1H` and 70'–76'
   in `2H`, there is a marker per moment (`TAKE_30`, `TAKE_70`) in
   `briefs_fired`, and an observed window is required, mirroring the HT
   first-observation guard. A missed window is skipped, not caught up.
6. **Holding up the HT push.** *Fix:* the stats call at HT gets a short
   timeout. If it fails or returns nothing, the push goes out with today's
   copy. The HT push never waits for or depends on stats.
7. **Stats that lag or are missing.** Cup ties at small grounds return
   nothing; the feed can trail by a minute or two. *Fix:* any missing input
   means silence for that rule, never a default of 0. (`renderVerdict`
   treats a missing value as 0 today: `?? 0`. Fix that in passing.)
8. **Extra time, penalties, `INT`, `SUSP`, abandoned.** No takes after 90';
   the verdict keeps its `unusualFinish` fallback.
9. **One device following both teams** (a derby between her two clubs).
   No Live Activity note. The HT push keeps whatever `sendPlayingTeamPush`
   does for a two-sided device today, so there is no new behaviour.
10. **Line length.** The note has 2 lines at 12 pt on a narrow phone. *Fix:*
    every line and backup is at most 60 characters, and a test runs over every
    variant.
11. **Trusting the feed.** `/fixtures/statistics` is still marked
    **unverified** in DATA_SOURCES.md. *Fix:* phase 0 below. Nothing reaches a
    phone before it is done.
12. **Repetition.** Seeded by fixture and side (`seededRng`), like the
    existing push copy, so a re-run picks the same line. 2–3 variants per
    situation.

## Build

**Phase 0: data and dry run (backend only)**
- `_shared/match-take.ts`, a pure function:
  `decideTake(moment, mine, theirs, score, htSnapshot?) → {kind, line, backup} | null`.
  The thresholds are constants at the top. Each situation from the brainstorm
  is one rule with its two agreeing conditions; the rest return null.
- `parseFixtureStats` gains `corners`, `fouls`, `yellow` and `red`, plus
  `saves` (goalkeeper saves).
- `match_status_state.stat_snapshots jsonb` holds `{ "30": …, "ht": …, "70": …,
  "ft": … }`, one `/fixtures/statistics` call per moment. That is about 4
  calls per match, or about 40 on a full Premier League Saturday, against the
  7,500 cap. The HT snapshot is what makes "since half-time" lines possible.
- `LIVE_TAKES_MODE = "dry_run"`: decide and log to `pipeline_health` (stage
  `live_take`, target `take:<fixture>:<side>:<moment>`). Nothing is sent.
- Deno tests:
  - Each brainstorm scenario as a fixture: fires, with the right kind.
  - The dull 0–0, missing stats, a single strong stat: silent.
  - Every variant is at most 60 characters.
  - No banned words (xG, expected, low block, …).
- One weekend of dry run. By hand, compare 4–5 matches' 30', HT and FT
  numbers against BBC or Sky, and write the result into DATA_SOURCES.md.
  Anton reads the logged takes and says which ones he would say.

**Phase 1: Live Activity note (backend only; works on 2.2/2.3/2.4)**
- Traps 1–5 and 9. `LIVE_TAKES_MODE = "live"`.
- Test: `simctl` cannot run a push-driven activity update reliably, so use a
  dev token on a device. Check that a goal clears the note, that a note-only
  change goes at priority 5, and that the other side's follower gets no note.
- Watch `pipeline_health` LA sends per match: priority-10 count unchanged.

**Phase 2: HT push + live card + After (backend + one app build)**
- HT: `renderHalfTimePush` takes an optional take per side. When present it
  replaces the `HT_SAY_*` pick.
- The take and backup are stored on `match_status_state` per side.
  `live-brief-current` returns `take` and `take_backup` (old apps ignore
  unknown keys). `LiveMatchCard` shows the take and, under it, "If someone
  pushes back: …".
- After: `renderVerdict` returns `{line, backup}`. The card stores
  `verdict_backup`; the app shows it under the verdict when present.
- PUSH_RULES.md: one paragraph saying that the HT line can now come from
  stats and that the Live Activity note is silent. Run
  `verify-push-rules.sh`.

**Phase 3 (later): patterns across matches**
- "Third game running…" needs the last few matches' snapshots per club.
  Read them from the stored `last_match` cards. Not before phases 0–2 have
  run for a few weeks.

## Not doing

- A new push of any kind.
- Reacting to single moments (a goal, a chance, a save).
- Showing the numbers behind a line on the lock screen. The backup line is
  the basis, in words, in the app.
