# Event-driven team-page prose — design, not yet built

**Status: DESIGNED 2026-09-30, deliberately not built.** The measurement it
depends on ships first (`db-health.sh` section 8 + `team_page_prose_history`,
migration 123). Revisit once there is a fortnight of evidence — see "What would
justify building this" at the end.

---

## The problem

`gd-team-page` rewrites the prose on all 20 Premier League club pages every
Monday at 02:30, because Monday is a day. Not because anything happened.

That is wrong in both directions. A club that has played three matches and
changed manager waits until Monday. A club where nothing has happened is
rewritten anyway, at ~2 minutes of routine time per club.

It is also how a wrong card survived a month. On 2026-09-30 the "ones to know"
card was found naming players who were not playing. The rewrite had run
faithfully every Monday and returned the same three every time, because the
inputs had not changed and neither had the answer. **A scheduled rewrite is not
a correction mechanism.** Running it more often would have produced the wrong
answer seven times a week instead of once.

## What would fix it

Rewrite a club's prose when something actually changed — a result finished, a
manager change, a squad change, a material move in the table — and leave it
alone otherwise. Fresher where it matters, cheaper where it does not.

## Why it is not a small change

The research below is the reason this is a document rather than a commit.

### There are two quota ceilings, and only one of them is written down

| Ceiling | Value | Source |
|---|---|---|
| Remote runs per day | **25** | Lesson 63, `IMPLEMENTATION_PROGRESS.md:2041`. "No new always-on routines" (`:2570`) |
| Fires per rolling hour, per routine | **~30** | Undocumented anywhere. Found in prod `pipeline_health` |

The second one is real and was invisible. On 2026-09-12, ten `matchday_fire`
rows carry HTTP 429 with:

> `This routine's fire rate limit has been reached. Try again in 59m40s.`

and the countdown across successive retries (59m40s → 54m6s → 38m4s → 8m3s)
shows a rolling window keyed on the first fire, not a fixed reset. That day
logged 30 successful fires in the 18:00 hour, then six 429s, then four more in
the 19:00 hour.

**This is the binding constraint, and it kills the obvious design.** A
four-match Saturday already budgets ~19 of 25 daily runs. Five matches means ten
clubs, so a naive one-fire-per-club model adds ten runs to a day that has six
left. It breaks the daily cap on its own, before the hourly one is even reached.

So **debounce and batching are a requirement, not an optimisation.**

### The worst case is the day the prose matters most

Measured from `match_status_state`, PL fixtures sharing a kickoff slot:

| fixtures in slot | occurrences | club pages affected |
|---|---|---|
| 10 | 1 (2026-05-24 15:00 — final day) | 20 |
| 5 | 1 (2026-09-12 14:00) | 10 |
| 4 | 1 | 8 |
| 3 | 1 | 6 |

Actual full-time clustering in 15-minute buckets peaks at five PL fixtures
finishing together. **The final day is not hypothetical** — all ten fixtures
kick off at 15:00 by competition rule, and 2026-05-24 is in the data. That is a
full sweep's work compressed into fifteen minutes, on the one day nobody wants
the page to be stale.

### The routine cannot currently be told to do a subset

- `TEAM_PAGE_PROMPT.md` line 3 hardcodes the scope: "for every active Premier
  League club". Step 2: "Per club, in `/tmp/_teams.txt` order."
- `fetch_team_page.sh:16` hardcodes `teams?league_id=eq.39&is_active=eq.true`,
  and **`:19` refuses to continue with fewer than 15 clubs** — a deliberate
  guard against a truncated team list, which also blocks any subset work at the
  fetch layer.
- `post_team_page.sh` is already per-club and needs no change.

The only de-facto subsetting that exists is pre-stamping `last_routine_run` on
clubs you want skipped, which is a hack rather than an interface.

### The parameter channel is one free-text string

A fired routine receives exactly one field, `text`, as a
`<routine-fire-payload>` message beside its configured prompt (verified
2026-09-30). `gd-live-brief` and `gd-matchday` both parse semicolon-separated
`key=value` out of it. There is no structured parameter object, no per-run env
override, no file injection. Whatever the queue hands over has to fit in that
string.

---

## The design

### 1. A queue table, not a fire per club

```
team_page_refresh_queue (team_id, reason, enqueued_at, drained_at)
```

`match-watcher` enqueues; it never fires. A separate drain — one fire carrying
`team_ids=a,b,c,d,e; reason=results` — does the work. One run for a whole
Saturday afternoon instead of ten, which fits both ceilings with room to spare.

### 2. Enqueue from the page-refresh block, not the fixture loop

The insertion point is `match-watcher/index.ts:2313-2373`, **after** the
per-fixture loop has finished, in the existing full-time page-refresh block.
Everything needed is already there:

- every push has been sent (they fire inside the loop at `:2294-2297`), so a
  fault here cannot cost a notification;
- the affected clubs are already deduplicated across fixtures by
  `mergeRefreshTargets` (`_shared/page-refresh.ts`), whose own docstring names
  this scenario: *"Five of our clubs can finish inside the same minute on a
  Saturday"*;
- the "must not fail the tick, must not fire twice" discipline is already
  written down at `:2307-2312`.

The tick has a **15-second** budget (migration 105 cut it from 30s, and all 18
recorded `page_refresh` failures sit at exactly 15002 ms — a timed-out refresh
burns the whole tick). An INSERT is affordable there. **Draining is not** — the
drain belongs in its own pg_cron job.

### 3. Debounce in the drain, not the enqueue

The drain runs every N minutes (start at 15) and takes everything enqueued and
not yet drained. A club that finishes two matches in a week is enqueued twice
and written once. A club enqueued during a drain is picked up by the next one.

Debounce is what turns the final day from 20 fires into one or two.

### 4. The weekly sweep stays

Monday keeps running, unchanged, over all 20.

This is not belt-and-braces, it is a specific known failure: **a routine that
reports SUCCEEDED may have written nothing.** From the routines repo's own
`README.md:168-172` — a routine that cannot reach Supabase finishes its run,
loses its sandbox, and is recorded as succeeded. On 2026-09-06 the Sunday brief
wrote twenty briefs into a sandbox that then vanished. The stale-data-audit
skill states it flatly: *"A routine that reports success is not evidence it
wrote anything."*

Event-driven must never become the only path.

### 5. Blockers to clear first

- **`fetch_team_page.sh:19`** — the `n >= 15` floor has to become conditional on
  whether a club filter was supplied, and line 16's query has to accept one.
- **`pipeline_health.stage`** has no value for a new fire stage. Adding one means
  a full `DROP CONSTRAINT` / `ADD CONSTRAINT` with the complete list (the
  current authority is `108_token_rate_limit...:31-39`) plus the TS union at
  `_shared/types.ts:85-101` — five stages once existed in SQL but not TS and
  writing them failed to compile.
- **Prior art to reconcile:** `BACKFILL_RULES.md:146` already names an intended
  end state — `team-page-generator` becomes `gd-team-pages` (a daily routine)
  plus a thin `accept-team-page-payload` Edge function that does only the JSONB
  stitch. This design should land as a step toward that, not across it.

---

## What would justify building this

The measurement shipped on 2026-09-30 answers it. After a fortnight, from
`team_page_prose_history` and `db-health.sh` section 8:

1. **How often does the prose actually change between Mondays?** If the answer
   is "rarely", the weekly cadence is fine and this whole document is a
   solution looking for a problem.
2. **How often does section 8 trip between Mondays?** That is the count of times
   a card was wrong and stayed wrong until the next scheduled rewrite. It is the
   number that converts into customer harm.
3. **How stale is the prose at its worst?** Measured as the gap between a result
   and the rewrite that first reflects it.

If (2) is near zero, do not build this. The complexity lands in the one function
that owns the push path, and the cost of getting it wrong is silence on a
matchday — which is strictly worse than prose that is six days old.
