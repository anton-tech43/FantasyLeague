# MAINTENANCE.md — GoalDigger twice-weekly upkeep routine

**What this is:** the checklist a cloud routine (`gd-maintenance`) follows twice a
week to keep GoalDigger alive and its data honest — autonomously, while nobody is
watching. It runs **Tuesday** (Pass A — drift & health) and **Friday** (Pass B —
freshness & content).

**What this is NOT:** a re-derivation of how the app works. It mostly *invokes*
things that already exist (`db-health-check` skill, `stale-data-audit` skill,
`scripts/*.sh`) and only itself covers the glue. Keep it thin — see §5.

---

## 0. Agent contract — the two hard rules (read every run)

Everything below obeys these. They come from `CLAUDE.md`, `DATA_SOURCES.md` and
`BACKFILL_RULES.md`; if this doc ever contradicts those, those win.

**Rule 1 — Source of truth per field, via `DATA_SOURCES.md`.**
Before changing any user-visible fact, look up where its truth lives.
- **Automatic source** (fixtures, events/scorers, standings, squads, injuries, our
  own `*_verified_at` tables, `raw_fetch_logs`) → **fix it yourself** via SQL,
  reading from that source. Log the before-value.
- **Human source** (manager = `teams.manager_name`, migration 085; a photo when both
  CDNs return only a silhouette; anything `DATA_SOURCES.md` marks human-verified) →
  there is **no correct value to copy from autonomously**. **Detect and push a
  proposal** (see §4). Never overwrite verified data from a feed the doc says lies
  (`/coachs`, `/transfers`, silhouette photos on HTTP 200).

**Rule 2 — Never loop a paid Anthropic API call across teams.**
`team-page-generator` (and any `_shared/claude-client.ts` caller) bills the API
credit balance per token. One team on demand is fine; a loop over teams bottomed
the balance on 2026-05-20 (~$4–5). If a fix needs LLM regeneration for more than one
team, **STOP and push** — do not fire it. See `BACKFILL_RULES.md` for the SQL /
routine alternatives that cost $0.

---

## 1. Environment & access

The routine runs in the cloud (env `gd-env`), on its own checkout — **no
`backend/.env`** (it is gitignored). Secrets come from the environment.

```bash
# DB (cloud): SUPABASE_DB_URL injected by gd-env
psql "$SUPABASE_DB_URL" -c 'select 1'
# DB (local, when run by hand): set -a && source backend/.env && set +a && \
#   /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL"
```

**If the DB is unreachable** (no secret, auth fail, timeout): that IS the finding.
Report it and push — do not skip the pass silently.

JSONB null trap (from CLAUDE.md): `WHERE x IS NULL` does not match a JSONB literal
`null`; use `WHERE x IS NULL OR jsonb_typeof(x) = 'null'`.

---

## 2. Pass A — Drift & health (Tuesday)

Goal: is the backend actually serving the app, and will it keep serving until Friday?

| # | Check | Command / source | Green looks like | If red |
|---|-------|------------------|------------------|--------|
| A1 | Backend serving | `./scripts/db-health.sh` (or the `db-health-check` skill) | all layers OK | `RUNBOOK.md`, `DB_BASICS.md`; **push** |
| A2 | pg_cron healthy | `cron.job_run_details` failures last 72h; no "job startup timeout" | no failed/looping jobs | see `project_db_maintenance` note; **auto-fix A3 first** |
| A3 | pg_net bloat | row count of `net._http_response` | not growing unbounded | **AUTO-FIX**: truncate it (unlogged log table; this is the known cause of "job startup timeout" that starves pg_cron). Log rows removed. |
| A4 | Routines producing | latest `content_items` per source (gd-news, gd-insider, gd-season-state, gd-quiz, gd-matchday) | each within its cadence window | a stale routine → **push** (its own repo is `anton-tech43/goaldigger-routines`; do not fix here) |
| A5 | Push contract | `./scripts/verify-push-eligible.sh` | exit 0, no violations | **push** with the violations |
| A6 | API balance sanity | is `team-page-generator` failing with IDLE_TIMEOUT? | function healthy or idle | IDLE_TIMEOUT pattern = **balance depleted, not broken** (`BACKFILL_RULES.md`). Do NOT refire. **Push.** |
| A7 | Secret hygiene | `./scripts/pre-commit-secret-scan.sh`; `ls .claude/worktrees/` | clean; no stray worktrees holding `.env` | remove abandoned worktrees; **push** if a secret leaked |

Anything in A1/A2/A3 that is a deterministic, reversible cleanup → auto-fix and log.
Anything that needs a human decision or is outside this repo → push.

---

## 3. Pass B — Freshness & content (Friday, before the weekend's matches)

Goal: nothing user-visible states something out of date going into the weekend.

1. **Run the `stale-data-audit` skill** — this is its whole job (clubs, managers,
   squads, player cards, team-page prose, season labels, hardcoded lists, store
   copy). Apply Rule 1 to everything it flags.
2. **Automatic-source fields** (trusted per `DATA_SOURCES.md`): fixtures,
   events/scorers, standings, squads (match on SURNAME), injuries (filter to latest
   fixture + dedupe). Fill nulls / refresh staleness via SQL from
   `raw_fetch_logs`/our tables. **Auto-fix, log before-values.**
3. **Human-source fields** — detect, don't overwrite:
   - **Manager**: age of `teams.manager_name` vs news of a change → **push a
     proposal** (you approve with one tap).
   - **Photos**: checksum vs the known silhouette → if placeholder, **push** (both
     CDNs return HTTP 200, so there is no automatic correct value).
4. **Store / hardcoded copy**: price is **free** (never £4.99 — it was never restored
   after the World Cup); season strings current. Fix copy that has a known-correct
   value; push anything ambiguous.
5. **World Cup surfaces are being retired** (branch `claude/retire-world-championship`).
   Do not treat WC freshness as a permanent item; if a WC surface still exists and is
   stale, prefer removal per the retirement work over refreshing it.

---

## 4. Reporting & push

Every run, regardless of outcome:

- **Write** `reports/maintenance/YYYY-MM-DD-pass{A,B}.md`: what was checked, green/red
  per item, every auto-fix with its before-value, and every push sent.
- **Commit** it to the repo so the history is readable on return
  (`git add reports/ && git commit`). Commit any doc self-revision (§5) too.

**Push to the phone (`PushNotification`) ONLY when** — so vacation isn't spammed:
- something is **RED** (backend down / broken), or
- a **human-source** finding needs a decision (manager, photo, ambiguous copy), or
- the **cost ceiling** (Rule 2) was hit and a fix was deferred, or
- the **DB was unreachable** (§1).

**Green = silent.** No push when everything is fine and all fixes were in the
automatic-source class.

Keep each push to one line: what + which report file to read.

---

## 5. Keep this doc alive (meta-rule)

This checklist rots the moment the app changes. Two mechanisms keep it honest:

- **Definition of done:** any PR that adds a surface holding rot-prone data, or a new
  cron job / routine, **must update `DATA_SOURCES.md` AND this file in the same PR.**
  Same habit `stale-data-audit` already requires.
- **Self-revision (last step of every run):** does this checklist still match the app?
  Delete dead rows (e.g. WC once retired), add new surfaces, fix any drift between
  this doc, `DATA_SOURCES.md` and reality. Commit the change with the report.

A doc that audits itself twice a week does not go stale.

---

_Routine: `gd-maintenance` (cloud, `gd-env`), cron `0 6 * * 2,5` (Tue+Fri 08:00
Europe/Stockholm in summer / 07:00 winter). Model: claude-sonnet-5. Created 2026-09-23._
