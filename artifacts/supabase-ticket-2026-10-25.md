# Supabase support ticket — project cwgpsmbunrocrofziqad (2026-10-25)

Paste the section below into a support request. Everything in it is measured,
not inferred. Do not paste any key or password; the project ref is enough.

---

**Subject:** Project unreachable since 2026-10-24 ~06:00 UTC — fast reboot had no
effect, pause will not take (cwgpsmbunrocrofziqad, eu-west-1)

**Project ref:** cwgpsmbunrocrofziqad
**Region:** eu-west-1
**Plan:** smallest compute (max_worker_processes 6, shared_buffers 224 MB, max_connections 60)
**Database size:** ~119 MB at last measurement
**Down for:** ~27 hours and ongoing at time of writing (2026-10-25 09:00 UTC)

## Summary

The project has been unreachable for about 27 hours. Postgres accepts TCP but
cannot answer a single query, through any path — the pooler, PostgREST, or your
own dashboard. A fast database reboot did not change anything. Attempting to
pause the project does not take (tried three times). We have exhausted every
self-service action available to us.

The dashboard is showing a **"Your project is about to deplete its Disk IO
Budget"** warning.

## Timeline (UTC)

| When | What |
|---|---|
| 2026-10-24 00:18 | External health check passes. Project healthy. |
| 2026-10-24 06:17 | External health check alerts: REST returns no response. Alerts every 3h since. |
| 2026-10-25 ~07:00 | Fast database reboot performed. No change. |
| 2026-10-25 ~08:00 | Pause attempted three times. Project does not enter paused state. |
| 2026-10-25 09:00 | Still unreachable. |

The health check runs from a different machine on a different network and
probes the project exactly as a client would, so the 00:18 → 06:17 window is
the outage onset as observed from outside.

## What we measure, from an external machine

**1. Pooler accepts TCP, cannot authenticate.** The error escalated over time:

```
07:05 UTC  FATAL: (EAUTHQUERY) authentication query failed:
                  connection to database not available
07:18 UTC  FATAL: (ECIRCUITBREAKER) failed to retrieve database credentials
                  after multiple attempts, new connections are temporarily blocked
```

A raw TCP connect to `aws-1-eu-west-1.pooler.supabase.com:5432` succeeds. The
auth query behind it does not complete.

**2. The API gateway is alive; everything behind it is not.**

```
GET /rest/v1/            (no apikey)      → 401 in 0.09s
GET /rest/v1/teams?...   (valid apikey)   → no response in 30s, zero bytes
```

The fast 401 shows the gateway responding without touching the database. A
request that must reach PostgREST never returns.

**3. Your own dashboard cannot query it either.** Database → Tables and
Database → Publications both return:

```
Failed to run sql query: Connection terminated due to connection timeout
```

**4. Project Health, last 60 minutes (from the dashboard):** 295 total
requests, 54.9% success rate. Broken down: Realtime 215 requests / 102 errors,
Storage 69 / 5 errors, API Gateway 10 / 4 errors, Edge Functions 1 / 0 errors.

## What we suspect, and cannot verify from outside

Realtime is 215 of 295 requests against this project. **This application
contains no Realtime code at all** — no subscriptions in the iOS client, none
in any Edge Function. It polls REST. We have never knowingly used the feature.

Our working hypothesis is an inactive logical replication slot holding WAL:
nothing consumes it, its `restart_lsn` never advances, and WAL accumulates
without bound until disk IO is saturated. That would fit the fact that nothing
in the project changed before the outage — no deploy, no migration, no
configuration change in three weeks — and that it arrived as a threshold rather
than an event.

Supporting evidence from a previous incident: on 2026-09-06 we recorded the
dashboard reporting 478 MB for this project while `pg_database_size()` returned
308 MB. We were unable to account for the 170 MB difference at the time.

We cannot test any of this: `pg_replication_slots`, `pg_ls_waldir()` and
`pg_stat_user_tables` all require a query, and no query completes.

## What we are asking

1. **Can you see, from your side, whether a replication slot on this project is
   inactive and retaining WAL?** If so, how much, and may we drop it? Nothing
   in our application consumes Realtime.
2. **Why does pause not take?** We assume it requires a clean shutdown the
   instance cannot currently perform. If so, can you pause or stop it from your
   side so the IO budget can refill with no load against it?
3. **Can you perform a full restart** (not the dashboard's fast reboot, which
   we have already tried without effect)?
4. **Please confirm or rule out Disk IO budget exhaustion as the cause**, and
   tell us what consumed it. We would rather fix the consumer than resize the
   instance.

## Relevant history on this project

- **2026-06-01** — Disk IO budget depletion warning. Root cause was an index
  that did not cover the whole predicate, causing ~55 large-JSONB heap fetches
  per index scan. Fixed with a composite index; no resize needed.
- **2026-08-23 → 09-06** — progressive degradation ending in seven days fully
  down. Dashboard showed Disk IO 100%, Compute 100%. Recovered by a database
  reboot.
- **2026-09-20 → 09-21** — whole-instance degradation for ~17 hours, including
  PostgREST returning 000/503 while the pooler stayed up. Recovered on its own;
  never explained. (We filed a ticket at the time.)
- **2026-10-24 → ongoing** — this incident.

Three of these four involve the Disk IO budget on the same small instance, and
we have never been given a confirmed cause for the September one.
