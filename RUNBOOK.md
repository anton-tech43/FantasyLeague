# Goal Digger — Pipeline Reliability & Error Recovery Runbook

**Version:** 1.0
**Date:** February 8, 2026
**Companion documents:** [PRD.md](./PRD.md) | [BUILD_PLAN.md](./BUILD_PLAN.md)

---

## Why This Document Exists

Users paid $10 for this app. If the pipeline breaks and no content is generated for 24 hours, that's a broken product. This runbook covers every failure scenario, how to detect it, and how to recover.

**The goal:** No user should ever go more than 48 hours without content during an active Premier League matchweek — even if things break.

---

## Monitoring Setup

### Health Check Table

Add this table to the database to track pipeline health:

> **Note:** The `pipeline_health` table is defined in the initial schema migration (`001_initial_schema.sql`) in [BUILD_PLAN.md](./BUILD_PLAN.md#step-12-database-schema). The schema below must match that migration.

```sql
CREATE TABLE pipeline_health (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id         TEXT NOT NULL REFERENCES teams(id),
    stage           TEXT NOT NULL CHECK (stage IN ('fetch', 'generate', 'review', 'publish')),
    status          TEXT NOT NULL CHECK (status IN ('success', 'failure', 'skipped')),
    duration_ms     INTEGER,
    message         TEXT,
    content_item_id UUID REFERENCES content_items(id),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pipeline_health_recent
    ON pipeline_health(team_id, stage, created_at DESC);
```

Every function in the pipeline logs a row here — success or failure. This is the single source of truth for "is the pipeline healthy?"

### Alert Conditions

Set up alerts (via Supabase webhook, or a simple Edge Function that runs hourly) for these conditions:

| Condition | Severity | Alert Method | Response Time |
|-----------|----------|-------------|---------------|
| No successful `fetch` for any team in 4 hours (during active hours) | HIGH | Email/Slack | Within 1 hour |
| No successful `generate` for any team in 12 hours | HIGH | Email/Slack | Within 2 hours |
| No content published for any team in 48 hours (during matchweek) | CRITICAL | Email/Slack/SMS | Immediate |
| Claude API error rate > 50% in last 10 calls | HIGH | Email/Slack | Within 1 hour |
| API-Football returning errors for 2+ consecutive runs | MEDIUM | Email/Slack | Within 4 hours |
| More than 5 RSS feeds failing simultaneously | MEDIUM | Email/Slack | Within 4 hours |
| Review rejection rate > 80% in last 24 hours | MEDIUM | Email/Slack | Within 4 hours |
| APNs delivery failure rate > 20% | HIGH | Email/Slack | Within 2 hours |

### Health Check Query

Run this query hourly to get a snapshot:

```sql
-- Last successful run per team per stage
SELECT
    t.display_name,
    ph.stage,
    ph.status,
    ph.created_at as last_run,
    EXTRACT(EPOCH FROM (NOW() - ph.created_at)) / 3600 as hours_ago,
    ph.message
FROM teams t
CROSS JOIN LATERAL (
    SELECT *
    FROM pipeline_health ph
    WHERE ph.team_id = t.id
    AND ph.stage = s.stage
    ORDER BY created_at DESC
    LIMIT 1
) ph
CROSS JOIN (VALUES ('fetch'), ('generate'), ('review'), ('publish')) s(stage)
ORDER BY t.id, ph.stage;
```

### Dashboard (Simple)

A single Edge Function endpoint (`GET /functions/v1/health`) that returns:

```json
{
    "status": "healthy",
    "last_check": "2026-02-08T14:30:00Z",
    "teams": {
        "arsenal": {
            "last_fetch": "2026-02-08T14:00:00Z",
            "last_published": "2026-02-08T11:23:00Z",
            "published_today": 1,
            "fetch_errors_24h": 0,
            "review_rejections_24h": 1
        },
        "man_utd": { ... },
        "west_ham": { ... }
    },
    "external_services": {
        "claude_api": "healthy",
        "api_football": "healthy",
        "apns": "healthy",
        "rss_feeds": {
            "healthy": 10,
            "failing": 2,
            "failing_feeds": ["mirror_rss", "telegraph_rss"]
        }
    }
}
```

Bookmark this URL. Check it daily. It should take 5 seconds to see if everything's working.

---

## Failure Scenarios & Recovery

### Scenario 1: Claude API is Down

**Detection:** `content-generator` or `content-reviewer` functions return 500/503/529 errors from the Anthropic API.

**Impact:** No new content is generated. No drafts are reviewed. Pipeline stalls at the generation/review stage.

**Automatic Recovery:**
```
1. First failure: Retry after 30 seconds
2. Second failure: Retry after 2 minutes
3. Third failure: Retry after 10 minutes
4. Fourth failure: Log CRITICAL alert, stop retrying for this cycle
5. Next scheduled cycle (30 min later): Try again from scratch
```

**Manual Recovery (if down > 2 hours):**
1. Check [Anthropic Status Page](https://status.anthropic.com) for outage info
2. If extended outage, no action needed — the pipeline will automatically resume when the API comes back
3. Content from the last successful run is still in the feed — users still have something to read
4. If outage lasts > 12 hours during a matchweek, consider manually writing 1-2 content items and inserting them directly into the database:
```sql
INSERT INTO content_items (team_id, type, headline, body, talking_points, status, published_at)
VALUES (
    'arsenal',
    'news',
    'Your manually written headline here',
    'Your manually written body here',
    '["Talking point 1", "Talking point 2", "Talking point 3"]',
    'published',
    NOW()
);
```

**Prevention:**
- The pipeline fetches data independently of content generation. Even if Claude is down, raw data continues to accumulate in `raw_fetch_logs`. When Claude comes back, the next generation run has fresh data to work with — nothing is lost.

---

### Scenario 2: API-Football is Down or Changes Response Format

**Detection:** `data-fetcher` function gets HTTP errors or unexpected JSON structure from API-Football endpoints.

**Impact:** No fresh fixture data, injuries, standings, or transfers. News RSS feeds still work.

**Automatic Recovery:**
```
1. Individual endpoint failure: Log warning, skip that endpoint, continue with others
2. All endpoints failing: Retry once after 60 seconds
3. Still failing: Log HIGH alert, continue pipeline with RSS data only
4. Next cycle: Try API-Football again
```

**Manual Recovery (if down > 6 hours):**
1. Check [RapidAPI status](https://rapidapi.com) and API-Football's Twitter for outage info
2. The pipeline should still produce NEWS content from RSS feeds — just no stats/fixtures/injuries
3. If matchday content is needed and API-Football is down:
   - Manually check the fixture time on the Premier League website
   - Create a matchday content item manually (without detailed stats)
   - Or temporarily use an alternative API: [football-data.org](https://www.football-data.org/) as backup

**Response Format Change:**
- API-Football occasionally updates their response structure
- If parsing fails, the `data-fetcher` should log the raw response so you can see what changed
- Fix: Update the parser in the Edge Function to match the new format
- Deploy the fix — Supabase Edge Functions deploy in seconds

**Prevention:**
- Log raw API responses to `raw_fetch_logs` — makes debugging format changes trivial
- Don't hardcode deeply nested JSON paths. Use defensive parsing with fallbacks:
  ```typescript
  const position = data?.response?.[0]?.league?.standings?.[0]?.[0]?.rank ?? null;
  ```
- Keep the API-Football documentation URL bookmarked: their docs show the current response format

---

### Scenario 3: RSS Feeds Failing

**Detection:** `data-fetcher` gets timeouts, 404s, or unparseable XML from RSS sources.

**Impact:** Reduced news coverage. The more feeds that fail, the more likely we miss stories.

**Automatic Recovery:**
```
1. Individual feed failure: Log warning, skip it, continue with other feeds
   (This is the most common case — one feed goes down occasionally)
2. 3+ feeds failing: Log MEDIUM alert
3. All feeds failing: Log HIGH alert — likely a network issue on our side
4. Each feed is tried fresh every cycle — no persistent blacklisting
```

**Manual Recovery:**
1. Check if the RSS URL has changed (publications occasionally restructure their RSS)
2. Visit the publication's website and find their current RSS URL
3. Update the feed URL in the Edge Function config and redeploy
4. If a publication removes RSS entirely, find an alternative source or remove it from the list

**Prevention:**
- Use 12+ RSS sources (we have 12 in the build plan) so no single source is critical
- The pipeline should produce useful content even if half the RSS feeds are down
- Store a fallback URL for each feed (e.g., the main site's root RSS vs the football-specific one)

**Feed URL Maintenance Schedule:**
- Monthly: Run a quick check that all feed URLs return 200 with valid XML
- After any feed fails 3 cycles in a row: investigate and fix

---

### Scenario 4: Supabase is Down

**Detection:** Any function call to the Supabase database or REST API fails.

**Impact:** Complete pipeline failure. iOS app can't fetch feed. Nothing works.

**Automatic Recovery:**
- Supabase has their own incident management. Outages are rare and typically short.
- The iOS app has local caching (SwiftData) — users can still read previously loaded content
- No action possible during a Supabase outage — everything depends on it

**Manual Recovery (if down > 1 hour):**
1. Check [Supabase Status Page](https://status.supabase.com)
2. Wait. There's nothing to do — the database is the backbone
3. Once Supabase is back, the pipeline resumes automatically on the next cron cycle
4. The iOS app will refresh when the user pulls to refresh

**Prevention:**
- The iOS app's SwiftData cache ensures users aren't staring at a blank screen
- Consider the cache as a 48-hour buffer — if it's been less than 48 hours since the last content, most users won't notice
- Supabase Pro plan includes automatic backups. Enable them.

**Future consideration (v1.1+):** If reliability becomes a concern, add a CDN cache layer (Cloudflare, Vercel Edge) in front of the Supabase REST API. The feed endpoint is read-heavy and cacheable with a 5-minute TTL.

---

### Scenario 5: APNs Delivery Failures

**Detection:** `notification-sender` gets error responses from Apple's push notification service.

**Impact:** Users don't receive push notifications. Feed still works in-app.

**Error Types and Responses:**

| APNs Error | Meaning | Action |
|-----------|---------|--------|
| 200 | Success | None |
| 400 BadDeviceToken | Token is malformed | Deactivate token (`is_active = false`) |
| 403 Forbidden | Auth issue with .p8 key | CRITICAL — fix immediately, no pushes going out |
| 410 Unregistered | App uninstalled or token expired | Deactivate token |
| 429 TooManyRequests | Rate limited by Apple | Back off 5 seconds, retry |
| 500 InternalServerError | Apple's problem | Retry after 30 seconds, max 3 retries |
| 503 ServiceUnavailable | APNs maintenance | Retry after 5 minutes, max 3 retries |

**Automatic Recovery:**
```
For each notification send attempt:
1. 429 or 5xx → retry with exponential backoff (5s, 30s, 5min)
2. 410 → deactivate token, continue to next token
3. 400 → deactivate token, log for investigation
4. 403 → STOP ALL SENDS, log CRITICAL alert (auth is broken)
5. After all retries exhausted → mark content as published anyway
   (it's in the feed — the push was a bonus, not the only delivery)
```

**Manual Recovery for 403 (Auth Broken):**
1. This means the .p8 key, Key ID, or Team ID is wrong or expired
2. Go to Apple Developer → Keys → verify the APNs key is still active
3. If the key was revoked, generate a new one and update backend environment variables
4. Redeploy the notification sender function
5. Run the notification sender manually to catch up on any unsent notifications

**Prevention:**
- APNs keys don't expire (unlike certificates). Once set up correctly, auth issues are rare
- Re-register the device token on every app launch (tokens can change after iOS updates)
- Clean up inactive tokens weekly to keep the send list lean

---

### Scenario 6: Content Quality Degradation

**Detection:** Review rejection rate exceeds 80% over 24 hours, OR manual review finds consistently bad content.

**Impact:** Either nothing gets published (if review bots are catching it) or bad content reaches users (if the problem is in what the review bots consider acceptable).

**This is the hardest problem to detect automatically.** The review bots catch obvious issues, but subtle tone drift is hard to measure.

**Signs of Quality Degradation:**
- Headlines start sounding generic or formulaic
- Talking points become factual instead of conversational
- Body text gets longer and more formal over time
- Same sentence structures repeating across content items
- Football jargon slipping through that the tone bot doesn't catch

**Recovery:**
1. Pull the last 20 published content items
2. Rate each one 1-5 against the golden examples in CONTENT_EXAMPLES.md
3. Identify the pattern — what specifically is drifting?
4. Adjust the relevant prompt (see PROMPTS.md Section 8 for iteration process)
5. Test the updated prompt against the same raw data
6. Deploy the fix
7. Monitor the next 10 items to confirm improvement

**Prevention:**
- Weekly manual review of 10 random published items (schedule this — don't skip it)
- Compare against golden examples every time
- Log prompt changes in the iteration log
- Never change multiple prompts at once — change one, measure, then change the next

---

### Scenario 7: Pipeline Hasn't Produced Content in 24+ Hours

**Detection:** Alert fires when no `content_items` have been published for a team in 24 hours (during an active matchweek).

**This could be legitimate or a bug. Investigate before acting.**

**Legitimate Reasons (No Action Needed):**
- International break (no Premier League action for 1-2 weeks)
- Off-season (May to August)
- Genuinely no newsworthy stories (it happens — the anti-spam rule is working correctly)

**Bug Indicators (Action Needed):**
- The `data-fetcher` isn't running (check `pipeline_health` for recent `fetch` entries)
- Data is being fetched but no content is generated (check for `generate` entries)
- Content is generated but all rejected by review bots (check rejection rate)
- Content is approved but not published (notification sender broken)

**Diagnosis Flowchart:**

```
Is the data fetcher running?
├── NO → Check pg_cron schedule, check Edge Function deployment
│         Fix: Redeploy function, verify cron job exists
│
└── YES → Is it finding new data?
    ├── NO → Check if RSS feeds are working, check API-Football
    │         Fix: See Scenarios 2 and 3
    │
    └── YES → Is the content generator running?
        ├── NO → Check if it's being triggered after fetch
        │         Fix: Check trigger mechanism, redeploy
        │
        └── YES → Is it marking content as newsworthy?
            ├── NO → Check newsworthiness threshold, review raw data
            │         Could be legitimate (no news) or threshold too high
            │         Fix: Temporarily lower threshold to 5, or manually verify
            │
            └── YES → Are review bots approving?
                ├── NO → Rejection rate too high. Check review_notes.
                │         Fix: Review bot prompts may be too strict. Loosen criteria.
                │
                └── YES → Is the notification sender publishing?
                    ├── NO → Check the sender function logs
                    │         Fix: Likely a deployment issue, redeploy
                    │
                    └── YES → Content IS being published.
                              Check if the alert is wrong (stale health check?)
```

---

### Scenario 8: Database Running Out of Space

**Detection:** Supabase dashboard shows storage approaching limits.

**Impact:** Writes start failing → pipeline breaks.

**Prevention:**
- `raw_fetch_logs` is the biggest table (raw API responses every 30 minutes for 3 teams)
- Set up a cleanup job:

```sql
-- Run weekly: delete raw fetch logs older than 30 days
SELECT cron.schedule(
    'cleanup-raw-logs',
    '0 3 * * 0',  -- Every Sunday at 03:00 GMT
    $$DELETE FROM raw_fetch_logs WHERE fetched_at < NOW() - INTERVAL '30 days'$$
);

-- Run weekly: delete pipeline health logs older than 90 days
SELECT cron.schedule(
    'cleanup-health-logs',
    '0 3 * * 0',
    $$DELETE FROM pipeline_health WHERE created_at < NOW() - INTERVAL '90 days'$$
);

-- Run weekly: delete rejected content items older than 14 days
SELECT cron.schedule(
    'cleanup-rejected-content',
    '0 3 * * 0',
    $$DELETE FROM content_items
      WHERE status = 'rejected' AND created_at < NOW() - INTERVAL '14 days'$$
);
```

**Space Estimates (Monthly):**
- `raw_fetch_logs`: ~30 fetches/day x 3 teams x 6 endpoints x ~5KB = ~2.7GB/month
  - With 30-day cleanup: max ~2.7GB at any time
- `content_items`: ~2 items/day x 3 teams x ~2KB = ~360KB/month (negligible)
- `pipeline_health`: ~30 logs/day x 3 teams x 4 stages x ~0.5KB = ~5.4MB/month (negligible)
- `device_tokens`: ~0.5KB per user (negligible until thousands of users)

Supabase free tier: 500MB database. **This is tight with raw_fetch_logs.** Either:
- Reduce raw log retention to 7 days instead of 30, OR
- Move to Supabase Pro ($25/month, 8GB), OR
- Store raw logs in Supabase Storage (S3-compatible) instead of the database

**Recommendation:** Start with 7-day retention for raw logs. Increase if needed on Pro plan.

---

## Emergency Playbook: "Nothing Has Worked for 48+ Hours"

If the entire pipeline has been down for 2+ days during an active matchweek:

### Step 1: Triage (5 minutes)
- Check the `/health` endpoint
- Check Supabase status page
- Check Anthropic status page
- Check API-Football on RapidAPI

### Step 2: Quick Fix Attempt (15 minutes)
- Redeploy all Edge Functions (sometimes a cold start issue)
- Manually trigger the data fetcher via HTTP
- Check the most recent `pipeline_health` entries for error messages

### Step 3: Manual Content (30 minutes)
If automated recovery isn't working, manually create content to keep users fed:
1. Check BBC Sport for the latest news on each team
2. Write 1 content item per team using the tone from CONTENT_EXAMPLES.md
3. Insert directly into the database with status `'published'`
4. Manually trigger the notification sender (or skip pushes — the content is in the feed)

### Step 4: Root Cause Fix (variable time)
- Once users have content, take time to properly diagnose and fix the pipeline
- Follow the diagnosis flowchart in Scenario 7
- Fix, test, deploy
- Monitor for the next 24 hours

### Step 5: Post-Incident Review
After any outage > 12 hours:
1. Document what happened and when
2. Document what the root cause was
3. Document how long users were affected
4. Identify what monitoring could have caught it earlier
5. Implement the monitoring improvement
6. Update this runbook if needed

---

## Maintenance Schedule

| Task | Frequency | Time | Description |
|------|-----------|------|-------------|
| Check `/health` endpoint | Daily | 09:00 GMT | 5-second visual check — is everything green? |
| Review 10 published items | Weekly | Monday morning | Compare against golden examples |
| Check RSS feed URLs | Monthly | First of month | Verify all feeds return 200 with valid XML |
| Update player name lists | Each transfer window | Jan, Jul-Aug | Add/remove players per team |
| Review costs | Monthly | First of month | Check Anthropic, RapidAPI, Supabase bills |
| Purge old data | Automatic | Weekly (cron) | Raw logs, health logs, rejected content |
| Prompt iteration review | Bi-weekly | Every other Friday | Check prompt iteration log, plan adjustments |
| Full pipeline dry run | Before each season | July-August | Run the entire pipeline end-to-end before the PL season starts |

---

*This runbook is a living document. Update it after every incident. The best runbook is one that gets shorter over time because the pipeline gets more reliable.*

---

## SOP: Push pipeline health check ("user says no push")

When a user reports they're not getting push notifications they expected, run this 5-step check. Each step has a "what to do if it fails" branch.

### Step 1 — Cron + gateway health (the silent-failure pattern)

```sql
SELECT id, status_code, LEFT(content::text, 100) AS body, created::timestamp AT TIME ZONE 'Europe/Stockholm' AS local_time
FROM net._http_response
WHERE created > NOW() - INTERVAL '15 minutes'
ORDER BY id DESC
LIMIT 10;
```

**Pass:** all `status_code = 200`.
**Fail with `401 UNAUTHORIZED_INVALID_JWT_FORMAT`:** Vault has wrong-shape key. See IOS_GOTCHAS.md #14 for the fix (`vault.update_secret` to legacy JWT). Phase 27.3 of IMPLEMENTATION_PROGRESS.md has the full case study.
**Fail with `5xx`:** Function-side error. Check the Edge Function logs in the Supabase dashboard.

### Step 2 — Did the relevant fixture get observed?

For the user's team (e.g., West Ham, API-Football id=48):
```sql
SELECT fixture_id, home_team_id, away_team_id, status, fired_finished_at, last_checked, league_id
FROM match_status_state
WHERE (home_team_id = 'west_ham' OR away_team_id = 'west_ham')
  AND last_checked > NOW() - INTERVAL '48 hours'
ORDER BY last_checked DESC LIMIT 5;
```

**No rows + a fixture happened:** match-watcher missed it. Two common causes:
- Fixture is in a non-tracked league (e.g., FA Cup `league_id=45` isn't in `SELECT DISTINCT league_id FROM teams` since we only have PL=39 and WC=1). This is the V2.1 cup-coverage gap documented in Phase 27.4.
- API-Football didn't return the fixture for the date filter (timezone drift, abandoned match, etc.).

**Row present but `fired_finished_at IS NULL`:** match-watcher saw it but didn't catch the FT transition. Often the first-observation guard (deploy-during-live-match).

### Step 3 — Did a content_item land?

```sql
SELECT id, team_id, type, LEFT(headline, 60) AS headline, status, pushed_at
FROM content_items
WHERE team_id IN ('<user team>', '<opponent>')
  AND created_at > NOW() - INTERVAL '48 hours'
ORDER BY created_at DESC LIMIT 10;
```

**No rows:** routine never produced content. Either the routine (in `goaldigger-routines` repo) didn't fire, or its post-script validator rejected.
**Rows exist but all `pushed_at IS NULL`:** notification-sender hasn't picked them up. Go to Step 4.
**Rows exist, `pushed_at` set:** APNs was attempted. Go to Step 5.

### Step 4 — Why hasn't notification-sender swept?

Sweep cron is `notification-sweep` at minute 15 of each hour. Sweep query filters to items with `published_at > NOW() - INTERVAL '24h' AND published_at < NOW() - INTERVAL '5 min'`. Items older than 24h are NOT pushed (correct — no stale news).

Manual sweep:
```bash
SERVICE_KEY=$(grep "^SUPABASE_SERVICE_ROLE_KEY=" backend/.env | cut -d= -f2)
curl -s -X POST "https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/notification-sender" \
  -H "Authorization: Bearer $SERVICE_KEY" -H "Content-Type: application/json" -d '{}'
```
Returns `{"success":true,"items_processed":N}`.

### Step 5 — Did APNs accept the push?

Use the `push-probe` Edge Function (read-only diagnostic):
```bash
curl -s -X POST "https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/push-probe" \
  -H "Authorization: Bearer $SERVICE_KEY" -H "Content-Type: application/json" \
  -d '{"team_id":"<user team>"}'
```

Response shape:
- `push_result.status: 200` + `success: true` → APNs accepted. iOS side issue (see Step 6).
- `push_result.status: 410` → token expired/dead. User needs to re-onboard.
- `push_result.status: 400` + `reason: BadDeviceToken` → environment mismatch (production token sent to sandbox or vice versa).
- `push_result.status: 403` → APNs key rotated or expired. Check `APNS_KEY_ID`/`APNS_TEAM_ID`/`APNS_KEY_P8` secrets.

### Step 6 — APNs accepted but iOS didn't display

- iOS Settings → app → Notifications → confirm "Allow" is ON.
- Notification Center on lock screen — was it grouped into a summary?
- Focus mode / Do Not Disturb active?
- Phone was rebooting when push arrived?
- Permission was revoked by the user post-install?

### Recovery actions

If matchday content was missed entirely (Step 2 fail), manually invoke `gd-matchday` from the `goaldigger-routines` repo with the right fixture_id + team_id payload.

If content_items exist but unpushed and are still <24h old, Step 4's manual sweep handles them.

If push-probe fails at APNs, look at `dev_alert_devices` and `client_errors` for parallel 403/410 traces from other tokens — if it's only this token, the user has to re-onboard. If it's all tokens, the APNs key/secrets are the issue.
