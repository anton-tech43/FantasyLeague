---
name: db-health-check
description: Check whether the GoalDigger backend is actually serving the app, and identify which layer is broken when it is not. Run daily, and immediately whenever the app is blank, slow, stuck on a spinner, showing grey boxes, or the Supabase dashboard reports anything unhealthy.
---

# Backend health check

The app has no database of its own. Everything it shows — the feed, the team
page, the squad, the quiz — is fetched over HTTPS at the moment you look at
it. So "the app is broken" and "the backend stopped answering" look identical
from the sofa, and the Supabase dashboard is not reliable at telling them
apart. On 2026-09-21 it reported the database unhealthy for an hour while
Postgres answered every query we sent it; the real casualty was PostgREST,
the HTTP layer in front of it.

This skill exists so that question gets a measured answer in thirty seconds
instead of an hour of guessing.

**Read `/DB_BASICS.md` first if the layer names below mean nothing to you.**
It explains what Postgres, PostgREST, the pooler and pg_cron each are, in
terms of this project.

## Run it

```bash
cd /Users/anton/FantasyLeague && ./scripts/db-health.sh
```

Exit code 0 means clear, 1 means a human is needed. It takes about 20
seconds, is entirely read-only, and touches nothing.

## How to read the result

The script prints six sections. Sections 1 and 2 are the diagnosis; 3 to 6
are the things that rot quietly.

### Sections 1 + 2 together are the whole diagnosis

They probe the two layers over two different network paths on purpose. The
combination, not either line alone, tells you what is wrong:

| Section 1 (app's HTTP) | Section 2 (Postgres) | What it means | What to do |
|---|---|---|---|
| OK | OK | Everything is serving. | Nothing. |
| **FAIL** | **OK** | **The data is safe. Supabase's HTTP layer is down.** | Nothing on our side fixes this. Do not restart the database — it is not the patient. Check status.supabase.com, wait, restart the project once if it drags. |
| FAIL | FAIL | The whole project is unreachable. | status.supabase.com, then restart the project, then a support ticket with UTC timestamps. |
| OK | FAIL | Your laptop cannot reach the pooler, but the app can reach its data. | Local network, VPN or firewall. Users are fine. |

The second row is the one that cost an hour. **"Database unhealthy" in the
Supabase dashboard is derived from a health check that probes the same path
PostgREST uses, so it goes red when PostgREST goes down even though Postgres
is perfectly healthy.** Believe section 2 over the dashboard.

A support reply that asks you to check the hostname, the firewall, the VPN
or connection pool exhaustion is a generic checklist. Sections 2 and 6 have
already ruled all four out; say so, with the numbers, and ask them to look
at the HTTP layer for the project ref and the UTC timestamps.

### Section 3 — the per-minute watcher

`match-watcher-1min` is what notices goals, kickoffs and final whistles. A
minute that never ran is a minute where that happened unseen, and no user
will ever report it — they just get fewer pushes than they should.

- Under 90% succeeded, or more than 200 missing minutes: something is
  stopping pg_cron from starting jobs.
- Known causes, both real here: the `net._http_response` table bloating
  (section 4), and pg_net's DNS lookups hanging for 30 s and blocking its
  single worker (migration 105 cut the timeout to 15 s).
- A single bad day right after an outage is expected — the outage itself
  ate the minutes. Two bad days in a row is a real regression.

### Section 4 — bloat

Three tables that have each caused an incident. Over 20 MB means a vacuum
job from migration 104 has stopped running; check `cron.job` still lists
`pgnet_response_vacuum`, `pgnet_response_vacuum_full`,
`cron_job_run_details_vacuum` and `pipeline_health_retention_sweep` as
active.

`net._http_response` is UNLOGGED, which means autovacuum never touches it
no matter how large it gets. That is not a misconfiguration we can fix —
we hold `MAINTAIN` on that table but not ownership, so `ALTER TABLE … SET
(autovacuum_…)` is refused. Scheduled VACUUM is the only lever.

### Section 5 — freshness

Over 12 hours is worth a glance, over 24 is wrong. The usual cause is that
the claude.ai routines did not run, not that the database is broken.
Content arrives from routines, not from the Edge Functions.

### Section 6 — connections

Almost never the cause, which is exactly why it is here: it takes one query
to rule out, and ruling it out both times this month is what forced the
search somewhere more useful. Over 80% of 60 is real saturation.

## When to run it

- Once a day, and it costs nothing to run more often.
- The moment the app looks broken — before changing any code.
- Before and after applying a migration that touches cron, pg_net or
  vacuum settings.
- Whenever the Supabase dashboard shows anything unhealthy, so you find out
  within a minute whether that reflects the database or only the layer in
  front of it.

## What this deliberately does not do

It does not alert. `check_pipeline_heartbeat()` already runs every 30
minutes and pushes an alert on content staleness, and it is blind in exactly
the way this script is not: it runs inside the database on pg_cron and
alerts through pg_net, so when the database or its HTTP path is the casualty
it can neither run nor tell anyone. Keep both. If this script is ever
automated, it has to run somewhere outside Supabase or it inherits the same
blindness.
