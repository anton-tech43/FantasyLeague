# Security seat: council 2026-10-29

Commit 376d3f2, app 2.4 (18) not yet uploaded. I worked read-only: SELECT-only SQL, `supabase functions list`, and unauthenticated GETs that are refused before any work runs. I made no writes and did not use the publishable key. There was no census file yet when this was written, so census ids are given as chapter plus element; the editor maps them.

Baseline: I do not re-report anything that `SECURITY_PROBE_2026-10-07.md` or `CHANGELOG_SECURITY.md` lists as fixed. Nothing there has regressed (see "What holds up").

The intended anon RPCs are **four, not three**. From iOS: `register_device_token`, `register_la_token` and `save_match_calls` in `APIClient.swift`, plus `log_events` (migrations 142 and 144), which `Analytics.swift` and `NotificationService.swift:42` call. `db-health.sh` §7 `ALLOWED` already lists all four. The skill text ("three RPCs") is out of date.

## Findings

### S-1 MEDIUM: `log_events`' per-install limit can be bypassed, so a junk-row flood is capped only by the global limit (3,000 rows a minute)
- **Where:** live `log_events` prosrc, lines 42–44 (same as `144_push_delivered.sql:62-68`). The per-install check counts `occurred_at > now() - interval '1 hour'`. `occurred_at` is the client's `at` field, clamped only to [now − 8 days, now].
- **Impact:** Anyone holding the publishable key can skip the per-install cap in two ways: send `at` = two days ago, or use a fresh `install_id` on each call. Only the global 3,000 rows a minute then applies, which is about 4.3 M rows and roughly 1–2 GB of table plus three indexes a day. The whole database is 218 MB today. This is the instance that ran out of resources in August. The global cap also drops everything: while a flood runs, every real user's events are discarded, including `data_deleted` (see S-2). The analytics that steer the Meta ad goal can also be poisoned with fabricated events.
- **How checked:** I read the deployed `prosrc` and `pg_database_size`. The flood was not exercised (no writes allowed). **CONFIRMED in deployed code**; volume is computed.
- **Minimal fix:** Key the per-install check on `created_at`, which the server sets, not on `occurred_at`. Add a per-IP cap using `current_setting('request.headers', true)::json->>'x-forwarded-for'` (for example 300 rows a minute per IP), so rotating `install_id` stops helping. Add a §4-style size alarm on `app_events`.

### S-2 MEDIUM: Delete My Data can tell her the analytics are gone when they are not
- **Where:**
  - Client: `ios/GoalDigger/Services/Analytics.swift:121-133`. `forgetInstall` appends `data_deleted` to the end of the queue. On the first failed batch it `break`s, then empties the queue and rotates `installId` anyway.
  - Server: in `log_events` (live prosrc, lines 37–44), the flood or per-install check `RETURN`s with 204 before the `data_deleted` branch at lines 79–90.
  - Glue: `SettingsView.swift:545-573` runs `forgetInstall` first and never checks its result.
- **Impact:** Three ways the deletion silently fails:
  - She is offline, which is the exact case the "Couldn't Delete" alert exists for. The old install id is discarded, so a retry can never delete those events.
  - She has logged 600 events in the hour, or someone is flooding the endpoint (S-1). The server accepts the call and does nothing.
  - Up to 13 months of her `app_events` stay keyed to an id nobody holds, while the app and the prepared policy paragraph ("Delete My Data in Settings deletes these records too") say they are gone.

  This is a GDPR erasure claim that is false in a predictable case. The data is not linked to an identity, which lowers the harm but does not make the claim true.
- **How checked:** Read the code end to end and the deployed prosrc. **CONFIRMED in code, SUSPECTED at runtime** (2.4 has not shipped and `app_events` holds 0 rows).
- **Minimal fix:** Send `install_id` in the existing `delete-my-data` body (`APIClient.swift:605`). In `delete-my-data/index.ts`, validate it as a UUID and `DELETE FROM app_events WHERE install_id = $1` with the service client, next to the token deletes. Its success or failure then shows in the existing alert. Rotate the id only after a 2xx. In `log_events`, handle `data_deleted` before the flood check.

### S-3 LOW: privacy text before 2.4 ships: the live policy contradicts the build, and the prepared paragraph understates the exit row
- **Where:** `https://getgoaldigger.carrd.co` (fetched today). It says "How we use it: Only to send you the notifications…" and does not mention `app_events`. `docs/TRACKING_PLAN.md:289-303` holds the ready-to-paste paragraph, which says the anonymous exit row keeps "only… how many days after install". In fact `data_deleted` keeps all common props (`Analytics.swift:73-83`): club, relationship, tier, app version, build, env, days_since_install and the clubs count. With 92 devices, Arsenal + "parent" + tier 3 + day 4 is close to identifying.
- **How checked:** Fetched the page and read the code. Already a known pre-submit gate in STATUS.md:49; the understatement is new. **CONFIRMED.**
- **Minimal fix:** Strip `data_deleted` props down to `days_since_install` (and `clubs` if needed), either server-side in `log_events` or in `forgetInstall`. Then the paragraph is true as written. Publish it before submitting 2.4.

### S-4 LOW: `delete-my-data` returns 400 before the Live Activity delete when the APNs token is not 64 hex characters
- **Where:** `delete-my-data/index.ts:36-42` returns 400 before line 65. The app treats that 400 as success (`APIClient.swift:624-628`).
- **Impact:** A phone whose APNs token is not 64 hex characters keeps its Live Activity token row (followed clubs and countries) after "Data Deleted". `device_tokens` holds one such 160-character row, from 2026-05-15 (development environment, still active). `purge_stale_rows()` only removes `is_active = false` rows, so it never expires. **CONFIRMED in code; real-world frequency SUSPECTED low.**
- **Minimal fix:** On a malformed `apns_token`, skip the device-token delete and carry on with the LA delete instead of returning. Delete that row by hand.

### S-5 LOW: nothing detects a new view that leaks a private table to anon
- **Where:** The `pg_default_acl` row `postgres|public|r|{…anon=r/postgres…}`: every relation `postgres` creates in `public`, views included, comes out anon-SELECT. Views default to `security_invoker = off`, so they read as their owner and bypass RLS. All eight `v_*` views and `analytics_events` are currently revoked and none of them is anon-readable. However, `db-health.sh` §7 checks only function EXECUTE and non-SELECT grants, through `information_schema`, which cannot see MAINTAIN. A future `CREATE VIEW v_x AS SELECT … FROM device_tokens` without a REVOKE would serve tokens over REST, and nothing would fail.
- **How checked:** SQL on `pg_default_acl` and `pg_class.reloptions`. **CONFIRMED** (gap, not an active leak).
- **Minimal fix:** Add one §7 query: any `public` relation where `has_table_privilege('anon', oid, 'SELECT')` is true and the relation is not on the 15-name allow-list (or is a view without `security_invoker=true`) is a failure. Switch the WRITABLE check to `has_table_privilege(..., 'INSERT,UPDATE,DELETE,TRUNCATE,MAINTAIN')`.

### S-6 LOW: the Meta SDK sends app events at launch, before any consent
- **Where:** `App/AppDelegate.swift:13-17` (`isAutoLogAppEventsEnabled = true` at launch). The ATT sheet only comes after onboarding (`GoalDiggerApp.swift:433`).
- **Impact:** Without the IDFA, iOS and Meta treat this as allowed. The privacy manifest declares `ep1.facebook.com` as a tracking domain, and the policy discloses it. Under UK PECR, however, non-essential device access for advertising measurement generally needs consent first. **SUSPECTED** (a legal reading, not a defect).
- **Minimal fix:** Decide deliberately. If the risk is not accepted, set auto-log off until the ATT answer and enable it on `.authorized`, accepting the attribution loss.

### S-7 LOW: leftover worktrees
`git worktree list` shows `.claude/worktrees/distracted-hypatia-a88d73` (branch `claude/nifty-ride-5adaf5`, head from 2026-04-15, abandoned) and `.claude/worktrees/matchday` (`claude/matchday-tab`). Neither has a `backend/.env` (presence checked, nothing read). `matchday` holds a `Configuration.xcconfig`; memory says that file may carry the dead legacy anon key. **CONFIRMED.** Fix: `git worktree remove` both once the matchday PR lands.

### S-8 LOW (hygiene): `clearAllData` leaves some keys on the phone
`AppState.swift:333-349` does not remove `liveActivityPushToStartToken`, `attPrompted` or `metaActivatedSent`, nor the App Group `commonProps` (club, relationship, tier). None is a name or anything she typed. The confirmation promises "clears everything GoalDigger keeps on this phone". **CONFIRMED in code.** Fix: add the three keys, and `SharedAnalytics.defaults?.removeObject(forKey: commonPropsKey)`.

## What holds up
- **Functions:** In `public`, anon and authenticated can EXECUTE exactly the four RPCs plus three trigger functions, so §7 is clean. All four RPCs are SECURITY DEFINER with `search_path=""` and unchanged since migration 129 (validation counts intact). `get_cron_service_key`, `roll_up_app_events` and `purge_stale_rows` are not anon-executable. The `storage` and `graphql_public` functions are Supabase defaults; storage has no buckets, and its tables have RLS on with zero policies.
- **Tables:** Anon has no INSERT, UPDATE, DELETE, TRUNCATE or MAINTAIN on any `public` table (checked with `has_table_privilege`, which does see MAINTAIN). It can SELECT 15 content tables, all with RLS and read policies, and `content_items` is filtered to published. `device_tokens`, `live_activity_tokens`, `app_events`, `analytics_events`, `client_errors` and every `v_*` view grant anon nothing. `everyone_talking_daily` is `security_invoker=true`. An `authenticated` JWT gains nothing over anon (identical grants, 0 `auth.users`).
- **Edge Functions:** 20 deployed, matching 20 directories. All 15 gated functions call `requireServiceAuth` as the first statement, and live GETs with a bogus bearer returned 401 on all 15. The 4 read endpoints regex-validate `team_id`/`country_id` and allow GET only. `delete-my-data` is POST-only (405 on GET), returns the same answer whether or not anything matched, and logs only when something matched.
- **Cron and vault:** No `cron.job` command embeds a literal key. Anon has no USAGE on `vault` or `cron`. The `net` grants (probe L1) are unchanged and still an accepted risk.
- **Bundle:** `Info.plist` holds the host and publishable key through xcconfig, the Facebook App ID and client token (client-side by Meta's design), and accurate ATT and calendar strings. Hardcoded URLs: the API-Football and Wikipedia crest CDNs and the carrd privacy page. No secret is in Swift.
- **Git history:** The legacy `service_role` JWTs in migrations 006 and 015–017 are still in public history. They were removed in 28a6ae9 and cryptographically dead since HS256 was revoked (IMPLEMENTATION_PROGRESS §22.4). There are no `sb_secret_`, real `sk-ant-` or APNs `.p8` keys and no 64-hex tokens in any commit; the `sk-ant` hits are the placeholder `sk-ant-your_…`. The pre-commit secret hook is installed, and `.env` and `Configuration.xcconfig` are ignored. The repo is **public on GitHub**: known since May, but it means every accepted risk written in these documents is public too.
- **Names:** `herName` and `hisName` live only in UserDefaults. No RPC, analytics prop, extension or Live Activity reads them, and `clearAllData` wipes them. The live policy says so accurately.
- **The 2.2/2.3 deletion path:** It deletes the `device_tokens` row (tokens, follows, tier, timezone, `match_calls`) and the push-to-start LA row. Per-match update tokens are purged after 3 days.

## Verdict proposals
| Element | Verdict | Why |
|---|---|---|
| SET Delete My Data row (`SettingsView.swift:444`) | **Keep** | It works for everything 2.3 stores. It becomes **Iterate** the moment 2.4 ships analytics unless S-2 is fixed in the same build. |
| SET Delete confirmation alert text (`:138`) | **Iterate** | "clears everything… on this phone" is not quite true (S-8), and "from our servers" is not reliably true under 2.4 (S-2). Fix the code, not the words. |
| SET "Couldn't Delete" alert | **Keep** | It is the right surface for S-2's fix. |
| SET Privacy Policy row → carrd | **Iterate** | The link works and is honest for 2.3. The policy text must be published before 2.4 is submitted (S-3), with the exit-row sentence made true. |
| ATT prompt (`NSUserTrackingUsageDescription`, after onboarding) | **Keep** | The copy is accurate and the timing avoids stacking two system sheets. S-6 is a separate decision about the SDK, not about the prompt. |
| SET name fields (Edit Your Name / His Name) and onboarding name inputs | **Keep** | Local-only, never transmitted, wiped on delete (verified). |
| STO privacy label | **Iterate** | It must gain Product Interaction (analytics, third-party ads, tracking) with 2.4, as `PrivacyInfo.xcprivacy` already declares. |

## Summary
1. No HIGH findings. Function, table, RLS and Edge gates all hold; 15 of 15 gated functions refuse a bogus key live, and §7 is clean with four intended RPCs (not three).
2. MEDIUM S-1: the per-install limit in `log_events` keys on the client's clock, so the only binding cap is 3,000 rows a minute globally. That allows a GB-a-day junk flood which also drops every real event.
3. MEDIUM S-2: under 2.4, Delete My Data can fail silently to erase analytics (offline, or rate-limited). Fix by deleting `app_events` inside `delete-my-data` by `install_id`.
4. LOW items: the policy and exit-row props before 2.4 (S-3), a 400 that skips the LA delete (S-4), no detector for anon-readable views (S-5), the Meta SDK firing before consent (S-6), two stale worktrees (S-7), and leftover local keys (S-8).
5. Fix S-1, S-2 and S-3 before 2.4 (18) is submitted, since tracking first reaches users in that build. Everything else can follow.
