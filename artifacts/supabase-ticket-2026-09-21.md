# Supabase support ticket — project cwgpsmbunrocrofziqad

Paste into a support request. Everything below is measured, not inferred.
Do not paste any key or password; the project ref is enough.

---

**Subject:** Whole-instance degradation 2026-09-20 22:42 – 2026-09-21 15:26 UTC (project cwgpsmbunrocrofziqad, eu-west-1)

**Project ref:** cwgpsmbunrocrofziqad
**Region:** eu-west-1
**Plan:** smallest compute (max_worker_processes 6, shared_buffers 224 MB, max_connections 60)
**Database size:** 119 MB
**Window:** 2026-09-20 22:42 UTC to 2026-09-21 15:26 UTC, recovered on its own

## What we saw

Every layer of the project degraded at once for roughly seventeen hours,
including your own components, on a 119 MB database that never exceeded 20
of 60 connections and recorded zero deadlocks and zero lock waits
throughout.

**1. PostgREST unreachable while Postgres was healthy.** Probing both layers
side by side from the same laptop, one second apart:

```
15:25:13  pooler=up  rest=000 (no response in 8s)
15:25:19  pooler=up  rest=000
15:25:25  pooler=up  rest=503
15:25:27  pooler=up  rest=503
15:25:30  pooler=up  rest=503
```

Twelve consecutive REST probes timed out at 8s, then two returned 503, then
timeouts resumed. Postgres answered every single probe in the same period.
The dashboard reported the *database* as unhealthy for this entire window,
which is misleading — the database was serving.

**2. Your own pooler auth query took over a second, repeatedly.** From
`pg_stat_statements` after the restart:

```
SELECT * FROM pgbouncer.get_auth($1)   61 calls   mean 1111 ms
```

This is what surfaced to us as client-side
`FATAL: authentication did not complete within 15000ms` and
`FATAL: (ECHECKOUTTIMEOUT) unable to check out connection from the pool
after 15000ms in Session mode`.

**3. Your own dashboard introspection queries took 13–23 seconds.**

```
with tables as (SELECT c.oid::int8 AS id, nc.nspname ...)   7 calls   mean 13815 ms
with f as (-- CTE with sane arg_modes, arg_names ...)       4 calls   mean 23307 ms
```

These are Supabase-generated queries against catalog tables on a 119 MB
database. We cannot cause a 23-second catalog read.

**4. pg_cron could not start jobs.** 235 × `job startup timeout` on our
per-minute job between 22:42 and 15:25. Hour by hour, runs recorded out of
60 possible:

```
22:00  57    23:00  60    00:00  60    01:00  60     <- healthy
02:00  21    03:00  18    04:00  48    05:00  18     <- collapse begins
06:00   1    07:00  16    08:00  24    09:00  34
10:00  68    11:00  16    12:00  19    13:00  28     <- stalls and catch-up bursts
14:00  81    15:00  25
```

The workload did not change at 02:00. The same job ran 60/60 with 100%
success for the four hours before.

**5. Trivial internal calls hit statement timeout**, including Vault key
decryption that measures 46 ms when the instance is healthy.

## What we ruled out, with measurements

- **Connection saturation:** 16–20 of 60 throughout. Not saturation.
- **Lock contention:** `wait_event_type = 'Lock'` count zero throughout.
- **Table bloat:** `net._http_response` 0 MB, `cron.job_run_details` 10 MB,
  `pipeline_health` 2 MB. We vacuum these on schedule since a prior incident.
- **Our SQL:** the slowest queries in the window were yours, not ours.
- **Client network:** the same laptop reached the pooler reliably, second by
  second, while REST from the same laptop timed out.
- **Hostname/port config:** unchanged for months, and the pooler worked.

## What we would like

1. Confirmation of what degraded this instance in that window, and whether
   it relates to the open "401 errors due to JWT rejections" incident and
   the fleet-wide deploy changes described as rolling out from 18 September.
2. Whether this instance is on a host that needs to be moved.
3. Guidance on whether the smallest compute is the actual constraint here.
   We are willing to upgrade, but the same workload ran cleanly on this
   instance for months and for four hours immediately before the collapse,
   so we would rather not buy our way past someone else's incident.

## Note on the automated lint reply

The automated triage returned `CONNECT_TIMEOUT` against the database and
suggested checking hostname, firewall, VPN, IPv6 and pool exhaustion. All
five are ruled out above. Note that the direct endpoint
`db.cwgpsmbunrocrofziqad.supabase.co` publishes **no A record at all**, only
AAAA, so any IPv4-only checker will always report CONNECT_TIMEOUT against it
regardless of instance health. That check appears to be measuring its own
lack of IPv6, not our database.
