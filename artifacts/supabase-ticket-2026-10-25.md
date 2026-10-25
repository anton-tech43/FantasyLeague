# Supabase support ticket — cwgpsmbunrocrofziqad (2026-10-25)

Written to Supabase's own format (their "Formatting support requests for faster
resolution" guide): their nine headings, under 300 words excluding logs, no
speculation. Everything below the line is measured. No keys or secrets.

---

**Summary**
Project `cwgpsmbunrocrofziqad` has been unreachable since 2026-10-24 06:00 UTC.
Postgres accepts TCP but completes no query through any path, including your own
dashboard.

**Impact**
Production iOS app fully dark for 27 hours, ongoing. No reads, no content, no
push notifications. All 22 scheduled jobs silent.

**Expected behaviour**
Queries complete via the pooler and via PostgREST.

**Actual behaviour**
```
pooler  2026-10-25 07:05Z  FATAL: (EAUTHQUERY) authentication query failed:
                                  connection to database not available
pooler  2026-10-25 07:18Z  FATAL: (ECIRCUITBREAKER) failed to retrieve database
                                  credentials after multiple attempts
REST    /rest/v1/ no apikey        → 401 in 0.09s
REST    /rest/v1/teams valid key   → no response in 30s, 0 bytes
Dashboard → Database → Tables      → "Failed to run sql query:
                                      Connection terminated due to connection timeout"
Dashboard → Database → Publications → same error
```

**Steps to reproduce**
Any query from any client. 100% reproducible.

**Environment**
`cwgpsmbunrocrofziqad`, eu-west-1, smallest compute (max_worker_processes 6,
shared_buffers 224 MB, max_connections 60). Database ~119 MB. Dashboard shows
"about to deplete its Disk IO Budget". No deploy, migration or configuration
change in three weeks.

**Troubleshooting completed**
- Fast database reboot, 2026-10-25 07:00 UTC — no change
- Pause attempted three times — project never enters paused state
- Raw TCP connect to pooler:5432 — succeeds
- Probed from a second machine on a different network — identical

**Evidence**
External health check (separate network, every 3h): passed 2026-10-24 00:18 UTC,
failed 06:17 UTC, failed every run since.

Physical backups completed 10-18, 10-19, 10-20, 10-21, 10-22 04:44 UTC — then
none on 10-23 or 10-24, next on 10-25 08:24 UTC. We cannot explain the two-day
gap and note it as unverified.

Project Health, last 60 minutes: 295 requests, 54.9% success. Realtime accounts
for 215 requests and 102 errors. Our application contains no Realtime code in
either the iOS client or any Edge Function.

**Request**
1. Restart or stop the instance from your side; pause does not complete for us.
2. Please check whether a replication slot is inactive and retaining WAL, and
   how much. We cannot query `pg_replication_slots` ourselves.
3. Confirm or rule out Disk IO budget exhaustion, and tell us what consumed it.
   We would rather fix the consumer than keep resizing.

**Missing information**
- Did backups fail on 10-23 and 10-24, and if so with what error?
- Was there a platform-side event on this instance between 10-22 and 10-24?
