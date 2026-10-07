# Security probe — anon/publishable key, 2026-10-07

**Scope:** what anyone holding the key that ships in the iOS app can do. This covers the REST tables, the RPCs, internal schemas, storage and the 20 Edge Functions.
**Method:** read-only SQL on the catalogs (inside `BEGIN READ ONLY … ROLLBACK`), plus live GET-only requests using the shipped `sb_publishable_*` key. No writes, pushes or Claude calls were made.

**Verdict: no high or medium holes.** Two low findings remain, both defense in depth; one was withdrawn as a false positive.

## What holds (verified live)
- **Anon can write no tables.** The `has_table_privilege` check found no INSERT, UPDATE, DELETE or TRUNCATE for anon or authenticated on `public`.
- **Private tables refuse the key.** `device_tokens`, `live_activity_tokens` and `raw_fetch_logs` return 401.
- **The 13 public tables hold intentionally public content.** `content_items` is filtered to `status='published'`: `?status=neq.published` returns `*/0`. No anon-readable column holds a token, email or device id.
- **Internal schemas aren't reachable over REST.** Requests to `net`, `cron`, `storage` and `vault` via `Accept-Profile` return 401. Root OpenAPI and GraphQL are disabled, and storage has no buckets.
- **The RPCs are tightly validated.** `register_device_token`, `register_la_token` and `save_match_calls` are SECURITY DEFINER with `search_path=""`, regex-check every input, cap array sizes and payload length, and allow only known team ids.
- **Edge Functions:** the 15 that do paid or sensitive work all call `_shared/require-service-auth.ts` first. It uses a constant-time compare, fails closed when env vars are missing, and gates every HTTP method. Live check: `content-generator` and `notification-sender` return **401** with the public key. The 5 ungated functions (`quiz-current`, `live-brief-current`, `live-match-current`, `team-season-state`, `delete-my-data`) only read public data with regex-validated input, apart from `delete-my-data`, which needs an exact 256-bit token.

## Findings

### L1: anon holds EXECUTE on `net.http_post` / `http_get` and INSERT on `net.http_request_queue`
These are Supabase's default grants. Combined, they would let anyone make the database send arbitrary HTTP requests (SSRF). Today that isn't reachable, because `net` isn't exposed over REST (verified: 401). It becomes live the moment someone adds `net` to the exposed schemas, or writes a SECURITY INVOKER function that passes user input through.
```sql
SELECT has_function_privilege('anon','net.http_post(text,jsonb,jsonb,jsonb,integer)','EXECUTE');  -- t
```
**Fix: not possible from our side.** Every grant here was made by `supabase_admin` (`nspacl`: `anon=U/supabase_admin`; `http_post` has `=X/supabase_admin`). A REVOKE run as `postgres` only warns "no privileges could be revoked" and leaves them in place, as tried and verified on 2026-10-07. Accepted risk: the guard is that `net` must never be added to the API's exposed schemas, and no SECURITY INVOKER function may pass user input to `net.*`. Only Supabase support could change the grants.

### L2: fake device registrations (bounded)
`register_device_token` accepts any well-formed token, so a script could add junk rows to `device_tokens`; `notification-sender` would then attempt pushes to dead tokens. There is no data exposure. **Bounded since migration 129:** new registrations are capped at 1,000 an hour for device tokens and 2,000 for Live Activity tokens, with a `pipeline_health` warning from 25 and 50 (triggers `enforce_token_rate_limit` and `enforce_la_token_rate_limit`, checked live 2026-10-07). Tokens already registered are not limited.

### ~~L3~~: withdrawn
The four `*_write` policies are `TO service_role`. The audit query printed `USING (true)` but not the policy roles, so this was a false positive.

### Notes (no action)
- Three trigger functions are executable by anon (`touch_la_tokens_updated_at`, `suppress_wc_result_recap_push`, `player_cards_link_player`). Trigger functions can't be called over RPC. `db-health.sh` §7 already permits these.
- The ungated read endpoints have no rate limit. The only abuse is volume: invocation billing and DB load. None of them call Claude, APNs or API-Football.
- PostgREST error messages name columns (`column teams.nope does not exist`). That's standard and only exposes already-public tables.
- The comment in `require-service-auth.ts:31-33` lists 3 ungated functions, but there are 5.

## Reproduce
- SQL: run the catalog queries above via `psql "$SUPABASE_DB_URL"`, using `has_table_privilege`, `has_function_privilege` and `pg_policy`.
- HTTP: `curl -H "apikey: $PUBLISHABLE" -H "Prefer: count=exact" -H "Range: 0-0" https://cwgpsmbunrocrofziqad.supabase.co/rest/v1/<table>`
