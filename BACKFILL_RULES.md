# BACKFILL_RULES.md — read this BEFORE any cross-team data fix

**One-line rule:** don't loop a paid Anthropic API call across teams when the same outcome can be reached via SQL or a routine.

This document exists because on May 20, 2026 a 50-team `team-page-generator` backfill burned ~$4–5 of Anthropic API credits in a few minutes and bottomed the account balance. The work could have been done for $0 via direct SQL or via a one-off claude.ai routine. The lesson is logged as **IMPLEMENTATION_PROGRESS.md Lesson 73**; this file is the operational distillation that should stop it happening again.

---

## Decision tree — pick BEFORE you fire anything

```
You need to update / fill / fix a field across N team_pages rows (or any cross-row DB write).
│
├── Is the answer already sitting in `raw_fetch_logs` or another table?
│   │
│   └── YES → Direct SQL. `UPDATE ... SET content = jsonb_set(...)`. Cost: $0.
│       Examples: pulling a player.photo URL out of api_football_squad,
│       grafting a venue.name from api_football_teams, patching a typo.
│
├── Is it pure data transformation / re-shaping of existing rows?
│   │
│   └── YES → Direct SQL. Cost: $0.
│       Examples: renormalising a JSONB field, deduplicating, repairing
│       a malformed key, applying a schema migration to in-place data.
│
├── Does the work require LLM judgement (voice, summarisation, generation)?
│   │
│   ├── For 1 team, user-triggered, on-demand
│   │   → OK to call the Edge Function (it's what they're for).
│   │     Single-team cost is small; that's the use case it was built for.
│   │
│   ├── For >1 team in a burst (10s or 100s)
│   │   → Use a one-off claude.ai cloud routine. Cost: zero API credits
│   │     (billed against the claude.ai subscription quota).
│   │     Pattern: `gd-team-pages-backfill` style routine, loops in-session,
│   │     POSTs to a thin Edge Function that only does the JSONB stitch +
│   │     `post_*.sh` pattern.
│   │
│   └── For a recurring need (daily / weekly)
│       → Build a permanent routine, not a manual fire of the Edge Function.
│         The routines in production and their schedules: the routines
│         README, section "Schedules, in one place" (gd-matchday and
│         gd-live-brief are fired by match-watcher). Same pattern: PROMPT.md in
│         `anton-tech43/goaldigger-routines`, scheduled cron, post_*.sh
│         writes to Supabase.
```

---

## Functions that burn Anthropic API credits (use sparingly)

These functions call `_shared/claude-client.ts` → `https://api.anthropic.com/v1/messages` directly using the `ANTHROPIC_API_KEY` env var. **Every invocation is billed per-token against your API credit balance, NOT your claude.ai subscription quota.**

| Function | Status | Burn rate when fired |
|---|---|---|
| `team-page-generator` | **On demand only.** `full` mode requires a `team_id`; no cron fires it. | `full`: ~5K in + ~2K out / call ≈ $0.045 / team page (Sonnet 4.5). data-fetcher triggers only `dynamic_only`, which makes no Claude call. The weekly prose comes from the `gd-team-page` routine. |
| `content-generator` | Gated off via `CONTENT_GENERATOR_ENABLED` env var (Lesson 17 — routines took over). Don't re-enable without a routine migration plan. | n/a — dormant |
| `content-reviewer` | Gated off (routines publish direct). Used only by manual smoke tests. | n/a — dormant |
| `team-season-state-generator` | Migrated to `gd-season-state` routine; the function should not be re-fired. | n/a — dormant |

If you're about to fire ANY of these in a loop across teams, **stop**. Re-check the decision tree above.

---

## Functions that DON'T burn API credits (free to fire)

The routines pipeline. These run inside a claude.ai cloud session — Claude inside the session executes the prompt, then a `post_*.sh` script writes the result back to Supabase via the service-role key. The session's tokens are charged against the user's claude.ai subscription, which is a flat monthly fee.

Lives in: `anton-tech43/goaldigger-routines` repo. Scheduled via claude.ai/code/routines.

The list of routines and their schedules is kept in one place, the routines README: [Schedules, in one place](https://github.com/anton-tech43/goaldigger-routines#schedules-in-one-place). Do not copy it here. gd-matchday and gd-live-brief have no schedule; match-watcher fires them.

Routines pay zero API credits per invocation. The right home for any cross-team backfill that needs LLM judgement is a **one-off** routine: write `BACKFILL_PROMPT.md`, schedule it once via `RemoteTrigger` with `run_once_at`, let it run.

---

## Cost-sanity audit query

Before firing anything cross-team, run this in psql to confirm whether the data is already in `raw_fetch_logs`:

```sql
SELECT source, count(*) AS rows,
       sum(octet_length(data::text))/1024 AS total_kb
FROM raw_fetch_logs
WHERE team_id = 'arsenal'  -- pick any representative team
  AND fetched_at > now() - interval '7 days'
GROUP BY source
ORDER BY source;
```

If the field you want is in there, you can backfill via SQL. If it isn't, you need an LLM — pick the routine path.

---

## Estimating LLM burst cost before firing

Multiply: `N teams × (input tokens + output tokens) × Sonnet 4.5 rate`

Sonnet 4.5 rates (as of May 2026):
- Input: $3 per 1M tokens
- Output: $15 per 1M tokens

Worked example (the May 20 mistake):
- 50 teams × ~5K input tokens × $3/M = $0.75
- 50 teams × ~5K output tokens × $15/M = $3.75
- **Total: ~$4.50 in a few minutes**

If the number is bigger than "what you'd spend on coffee", reconsider via the decision tree.

---

## Symptoms of a depleted API balance

When the Anthropic API balance hits zero, the failure mode is **misleading**:

1. Direct curl to `https://api.anthropic.com/v1/messages` returns `400` with body `"Your credit balance is too low to access the Anthropic API."`
2. The Edge Function calling `_shared/claude-client.ts` retries with 30s + 2min + 10min backoffs.
3. Supabase Edge Functions kill workers after **150 seconds of idle**, so the retry loop trips the timeout during the 2-minute sleep — before any error gets logged.
4. Symptom seen by the user: `IDLE_TIMEOUT` or `WORKER_RESOURCE_LIMIT` from `curl`, **no rows in `pipeline_health` to explain why**.

If you see this error pattern on a function that previously worked, check the Anthropic balance **first**:

```bash
# Direct ping. If 400 with "credit balance too low" → top up at:
# https://console.anthropic.com/settings/billing
source backend/.env
curl -sS --max-time 10 -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":20,"messages":[{"role":"user","content":"hi"}]}'
```

---

## V2.1 ticket: migrate `team-page-generator` to a routine (partly done)

Done: the weekly prose moved to the `gd-team-page` routine, and the 2-hourly refresh is `dynamic_only`, which makes no Claude call. Remaining: retire `full` mode, the one path left in this function that calls Claude.

Until that lands, the rules above stand.

---

## See also

- `IMPLEMENTATION_PROGRESS.md` — Lesson 73 (full narrative of the May 20 incident).
- `_shared/claude-client.ts` — top-of-file banner repeats the rule.
- `team-page-generator/index.ts` — top-of-file banner names this file.
