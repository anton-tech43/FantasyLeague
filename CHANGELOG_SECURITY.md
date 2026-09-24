# Goal Digger — Security & Architecture Changelog

**Purpose:** This document tracks all security fixes, GDPR changes, and architectural decisions made during the security audit of April 2026. **Every agent must read this before starting work.**

**Date:** April 6, 2026
**Audit performed by:** Cybersecurity & Best Practices review agent

---

## Summary of Changes

| # | Change | Severity Fixed | Files Modified |
|---|--------|---------------|----------------|
| 1 | Credentials moved from hardcoded Swift to xcconfig build-time injection | CRITICAL | BUILD_PLAN.md, AGENT_CONTRACTS.md |
| 2 | device_tokens table hardened with CHECK constraint, rate limit trigger, restricted RLS | HIGH | BUILD_PLAN.md |
| 3 | RSS/API input sanitization and prompt injection defenses added | HIGH | PROMPTS.md, BUILD_PLAN.md |
| 4 | GDPR-compliant privacy policy, "Delete My Data" feature, accurate App Store claims | HIGH | BUILD_PLAN.md, PRD.md, APP_STORE_STRATEGY.md |
| 5 | Content Safety review bot (Bot 4) added to pipeline | MEDIUM | PROMPTS.md, AGENT_CONTRACTS.md |
| 6 | Review bot JSON parsing security note added | MEDIUM | AGENT_CONTRACTS.md |
| 7 | Separate dev API key required for Pipeline Agent | LOW | AGENT_CONTRACTS.md |

---

## Detailed Changes

### 1. CRITICAL: Credentials Moved to Build-Time Configuration

**What changed:**
- `APIClient.swift` in BUILD_PLAN.md no longer contains hardcoded `SUPABASE_URL` or `SUPABASE_ANON_KEY`
- Credentials are now loaded from `Info.plist`, which reads from `Configuration.xcconfig`
- `Configuration.xcconfig` is in `.gitignore` — never committed
- `Configuration.xcconfig.example` is committed as a template

**iOS Agent must:**
- Create `Configuration.xcconfig` from the `.example` template
- Set the Xcode project to use this xcconfig for both Debug and Release
- Read credentials via `Bundle.main.infoDictionary` — see updated `APIClient.swift` code in BUILD_PLAN.md Step 2.3

**Backend Agent must:**
- Write real credential values to `ios/GoalDigger/Configuration.xcconfig` (gitignored) during handoff
- Commit `Configuration.xcconfig.example` with placeholder values
- Never pass secrets via commit messages or shared documents

### 2. HIGH: device_tokens Table Hardened

**What changed in BUILD_PLAN.md schema:**
- `apns_token` column now has a `CHECK` constraint: must be 64-character hex string (`'^[a-fA-F0-9]{64}$'`)
- A `BEFORE INSERT` trigger enforces a global rate limit (max 500 new registrations per hour)
- RLS UPDATE policy now restricts anon role to only changing `team_id` and `updated_at` — cannot modify `apns_token` or `is_active`

**Backend Agent must:**
- Include these constraints in `001_initial_schema.sql`
- Implement the column-level RLS policy as documented
- Test that invalid tokens (non-hex, wrong length) are rejected at the database level

### 3. HIGH: Input Sanitization for LLM Pipeline

**What changed in PROMPTS.md:**
- New section "SECURITY: Input Sanitization & Prompt Injection Defense" with 6 mandatory sanitization rules
- Content generator system prompt now includes security clause (rule 8) and content safety clause (rule 9)
- User message template wraps external data in `<external_data>` XML tags with trust_level attribute
- Reminder at end of template reinforces that external data is untrusted

**What changed in BUILD_PLAN.md:**
- New shared utility `input-sanitizer.ts` added to project structure

**Backend Agent must:**
- Implement `_shared/input-sanitizer.ts` following the 6 rules in PROMPTS.md
- Call sanitizer in `data-fetcher/index.ts` BEFORE storing to `raw_fetch_logs`
- Call sanitizer again in `content-generator/index.ts` before building the prompt

**Pipeline Agent must:**
- Include the security and content safety clauses in ALL prompts (news and matchday generators)

### 4. HIGH: GDPR Compliance

**What changed:**
- BUILD_PLAN.md Step 5.3 now contains a full GDPR-compliant privacy policy template
- New "Delete My Data" feature requirement added (Step 5.3, item 7)
- New Edge Function `delete-my-data/` added to project structure
- PRD.md has new Section 9.1 "Privacy & Data Handling"
- APP_STORE_STRATEGY.md privacy claim updated from "no data collection" to accurate description

**Backend Agent must:**
- Implement `delete-my-data/index.ts` Edge Function that accepts an APNs token and deletes the corresponding row
- Host the privacy policy at a public URL before App Store submission
- Execute a DPA with Supabase (manual step for the founder)

**iOS Agent must:**
- Add "Delete My Data" button to Settings screen
- Implement the deletion flow: call Edge Function → clear local data → return to Welcome screen
- Add a link to the privacy policy in Settings

### 5. MEDIUM: Content Safety Review Bot Added

**What changed in PROMPTS.md:**
- New "Review Bot 4 — Content Safety" (Section 6) screens for: personal life comments, defamation, discrimination, inappropriate content, copyright violations
- Table of Contents renumbered
- Pipeline order is now: Tone → Accuracy → Brevity → Safety

**What changed in AGENT_CONTRACTS.md:**
- Contract 6 updated to reference 4 review bots (not 3)
- JSON parsing security note added: failed parses must be treated as FAIL, not PASS

**Backend Agent must:**
- Add the 4th review bot call in `content-reviewer/index.ts`
- Update `pipeline_health` stage values to include `'safety_review'`
- Wrap all `JSON.parse` calls in try/catch — parse failure = review FAIL

### 6. MEDIUM: Review Bot JSON Parsing Security

**What changed in AGENT_CONTRACTS.md:**
- Explicit security note: `JSON.parse` of review bot responses must be wrapped in try/catch with schema validation
- Parse failures are treated as FAIL (not pass) — defense against adversarial content manipulating review output

### 7. LOW: Separate Dev API Key for Pipeline Agent

**What changed in AGENT_CONTRACTS.md:**
- Pipeline Agent's `ANTHROPIC_API_KEY` must be a separate key from production
- Named `goaldigger-dev` in Anthropic Console with lower rate limits

---

## Outstanding Items (Not Yet Fixed)

| Item | Severity | Status | Notes |
|------|----------|--------|-------|
| Automated testing strategy | HIGH | Deferred to post-build | User will be walked through XCTest (iOS), Deno test (Edge Functions), and prompt regression tests after the app is built. Do NOT block on this during build phase. |
| CI/CD pipeline | MEDIUM | Not started | Recommended: GitHub Actions for Edge Function deploy + iOS build |
| Certificate pinning on iOS | MEDIUM | Not started | ATS provides baseline protection |
| APNs key rotation plan | MEDIUM | Not started | Document annual rotation schedule |
| RSS source terms of service review | MEDIUM | Not started | Legal review needed before launch |
| Crash analytics (Sentry/Crashlytics) | LOW | Not started | Apple's built-in crash reports are minimum viable |

---

## 2026-09-23 — anon is read-only (migration 115)

**What was wrong.** The publishable key that ships in the App Store binary held
INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER and MAINTAIN on 23 tables
in `public` — `players`, `teams`, `content_items`, `team_pages`, the lot. Only
RLS stood in the way. RLS did hold (a write probe with the shipped key is
refused with `42501`), so this was never exploitable, which is the reason to
fix it now rather than after someone adds a table and forgets a policy.

**Why it existed.** Nobody granted it. Supabase's `ALTER DEFAULT PRIVILEGES` on
`public` gives `arwdDxtm` to `anon` and `authenticated` for every new table, so
every migration ever written inherited the full set.

**What the app actually needs, checked not assumed.** It issues no POST, PATCH
or DELETE at all. Every REST call is a GET, and both writes go through
`register_device_token` and `register_la_token`, which are SECURITY DEFINER and
run as their owner. So: SELECT, and nothing else.

**Applied.** All write privileges revoked from `anon` and `authenticated` on
every table in `public`, and the default privileges changed so new tables come
out SELECT-only. MAINTAIN was included deliberately: it does not appear in
`information_schema.role_table_grants`, so it survives a revoke you thought was
complete — anon held it on 22 of 25 tables, carrying VACUUM, REINDEX and
REFRESH MATERIALIZED VIEW on the compute that ran out in August.

**The one exception.** `device_tokens` keeps INSERT and UPDATE, because 2.2 is
in the App Store and still PATCHes the tier directly. It goes when
`107_drop_anon_token_write.sql.PENDING_APP_RELEASE` is applied after 2.3 ships.
That migration now finishes this one.

**Verified after applying:** every read the app makes returns 200, including
the new `player_cards` squad join; `players` INSERT and `team_pages` DELETE are
refused with `permission denied for table` rather than by RLS; and
`register_device_token` still returns 204 and lands a row with the right club
and tier (probe row removed). Feed and team page screenshotted clean.

**Not done, noted here instead.** Function EXECUTE still defaults to `anon` for
everything in `public`, which is how the two RPCs work but also means every new
function is callable with the shipped key. Tightening that needs a per-function
allow-list and is its own change.

---

## 2026-09-23 — anon cannot execute (migration 116)

**What was wrong.** Seven `SECURITY DEFINER` functions were callable with the
publishable key from the App Store binary. Two are meant to be
(`register_device_token`, `register_la_token`). The other five:
`claim_match_watcher_tick` and `claim_fixture_marker` — the leases match-watcher
uses to decide whether to run the minute and whether a push has already gone
out, so one caller a minute silently stops every kickoff, goal, half-time and
full-time push and Live Activity, while match-watcher reports its ordinary
"tick already claimed" — plus `prune_departed_players` (DELETEs from `players`)
and the two full-table syncs, callable in a loop against the smallest instance.
`SECURITY DEFINER` bypasses RLS by design, so migration 115 did not cover any
of it.

**Why it existed, and this is the part worth remembering.** Migrations 084,
095, 096 and 103 had already made this decision and written it:

    REVOKE EXECUTE ON FUNCTION public.claim_match_watcher_tick(timestamptz) FROM PUBLIC;
    GRANT  EXECUTE ON FUNCTION public.claim_match_watcher_tick(timestamptz) TO service_role;

`FROM PUBLIC` removes the implicit privilege. `anon` and `authenticated` hold
an **explicit** grant from `ALTER DEFAULT PRIVILEGES`, which `FROM PUBLIC` does
not touch. Four migrations read as though they had locked the function and none
had. Migration 108 is the only earlier one that got it right, because it wrote
`FROM PUBLIC, anon, authenticated`. Same failure shape as 072's wrong policy
names: a statement that looks like the fix and is not.

Verified before the change: `POST /rest/v1/rpc/sync_players_from_squads` with
the shipped key returned **HTTP 200**.

**Applied.** EXECUTE revoked from `PUBLIC, anon, authenticated` on eleven
functions — the five above, the two service tools (`poll_leagues`,
`check_pipeline_heartbeat`) and the four name-matching helpers from migrations
110/113 — written one at a time so the file reads as the list of what is
closed. Default privileges changed so no new function comes out anon-callable;
**the next migration that adds an RPC must grant it explicitly.** The four
trigger-returning functions were left alone: PostgREST cannot expose them.

**Every caller was inventoried first.** The two `claim_*` are the only ones of
the five that travel over PostgREST, from match-watcher, whose client resolves
`SERVICE_KEY ?? SUPABASE_SERVICE_ROLE_KEY` and runs as `service_role`. The
three player-sync functions never touch PostgREST at all — pg_cron job bodies
and manual psql, both as `postgres`. The routines repo makes no RPC calls.

**Verified after applying:** all six previously-open endpoints now answer 401;
`register_device_token` and `register_la_token` both return 204 with the row
landing correctly (probes removed); match-watcher kept taking its lease every
minute with no new failures in `pipeline_health`; `sync_players_from_squads()`,
`prune_departed_players()` and `poll_leagues()` still run as `postgres`;
`service_role` and `postgres` retain EXECUTE on all 22 functions; feed, team
page and the on-device squad quiz screenshotted clean; `db-health.sh` all clear.

Anon-executable surface is now exactly: `register_device_token`,
`register_la_token`, and three trigger functions that cannot be called.

---

## 2026-09-24 — what the red-team pass found in 108/115/116, and what is left open

Fixed, and covered in migration 120: `device_tokens` had **no triggers at all**,
so the rate limit migration 108 rewrote had never run; the INSERT/UPDATE grant
115 kept for App Store 2.2 was already useless (2.2's tier PATCH is a *filtered*
UPDATE and 106 revoked the SELECT its WHERE clause needs), so it was pure
surface and is now revoked; and 116's `ALTER DEFAULT PRIVILEGES` for functions
does not close a new function, because every function is born with an implicit
`EXECUTE TO PUBLIC`. Detection replaces prevention — `db-health.sh` section 7.

### Open, with the reasoning rather than a promise

**`net` is the sharpest thing still reachable by `anon`, and the cost of ever
exposing it is higher than "SSRF".** `anon` holds write privileges on
`net.http_request_queue` and `net._http_response` (RLS is off on both) and
EXECUTE on `net.http_post`/`http_get`/`http_delete`. The only thing between the
shipped publishable key and that is PostgREST's exposed-schema list, which does
not include `net`. This was already an accepted deferral; what was not written
down is that **`net.http_request_queue.headers` carries
`Authorization: Bearer <cron service key>`** for every pg_cron job —
`match-watcher-1min` writes one every minute — and `anon` holds SELECT on that
table. So adding `net` to the exposed schemas would not merely open an SSRF
primitive, it would disclose the service key. It cannot be fixed with a REVOKE:
`extensions.grant_pg_net_access()` runs on an event trigger and re-grants all of
it on any `CREATE EXTENSION`. It has to stay closed at the schema-exposure
layer, and that constraint is now recorded rather than remembered.

**`supabase_admin`'s default privileges for `public` are still permissive**
(`anon=arwdDxtm` on tables, `X` on functions), so a table created by the
platform — a `CREATE EXTENSION` landing objects in `public`, which `pg_net`
already did — would come out writable by anon. Attempted the documented hedge:

    ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
      REVOKE ... FROM anon, authenticated;

It runs without error as `postgres` and changes nothing — the ACL is byte
identical afterwards. So this is not ours to close. `db-health.sh` section 7
lists every table `anon` can write regardless of who created it, which turns an
invisible gap into a failing check the next morning.

**Duplicate migration version numbers** (`112_club_style` / `112_player_cards_squad_link`,
`117_match_calls` / `117_player_link_knows_first_names`) would break
`supabase db push`. Nothing uses it — `schema_migrations` stops at 017 and every
later migration was applied by hand — so the files are left as the historical
record they are. The two I added in this pass were renumbered to 120/121 rather
than adding a third collision.

---

*This changelog is authoritative. If you see a conflict between this document and older content in BUILD_PLAN.md or AGENT_CONTRACTS.md, this document reflects the latest decisions.*
