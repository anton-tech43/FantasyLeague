# Scaling GoalDigger to ~50,000 users

Written 2026-06-17, ahead of the ad push. Grounded in the actual code, not generic
advice. TL;DR: **one thing genuinely breaks, and it breaks *worse* the more successful
the campaign is. Everything else is a cheap knob-turn.** The economics are friendly —
content and push delivery cost the same at 50k as at 500.

---

## 0. What does NOT scale with users (the good news)

- **Content generation is global per team**, produced by claude.ai routines on a flat
  subscription (`ARCHITECTURE.md` §4). 50k users read the *same* `content_items`. Cost
  is independent of install count.
- **APNs is free** from Apple. No per-push cost.
- **No Supabase Auth users** — the app uses anon + device tokens, so the 100K-MAU auth
  billing line almost certainly doesn't apply. Bandwidth/egress + compute do.

So scaling to 50k is mostly an **engineering fix** (the push loop below) plus a **modest
compute bump** — not a cost explosion. Expect a Supabase bill in the low hundreds/mo at
50k, dominated by compute + egress, not LLM spend.

---

## 1. THE blocker: push fan-out is fully sequential

Both send paths loop over recipients one at a time, awaiting each APNs round-trip:

- `notification-sender/index.ts:284` — `for (const entry of eligibleTokens) { await sendPushNotification(...); await logPipelineEvent(...) }`
  Two sequential awaits **per recipient**: the APNs send **and** a `pipeline_health`
  insert that fires for *every* token (line 307, unconditional). On a 410/400 it does a
  third await (per-token `UPDATE device_tokens`).
- `match-watcher/index.ts:267` (`sendWcPlayingTeamPush`) — `for (const t of tokens) { await sendPushNotification(...); await deactivateTokenIfDead(...) }`
  One APNs round-trip per recipient, sequential. (Logging here is already batched per
  country — good.)

APNs over **HTTP/1.1** (`_shared/apns-client.ts:4` — Deno has no native HTTP/2; the file
itself flags "for production volume, consider a native HTTP/2 library").

### The math against the Edge limits

Edge Functions: **400s wall-clock**, 2s CPU, 150s idle timeout
([Supabase limits](https://supabase.com/docs/guides/functions/limits)). The loop is
almost all I/O wait, so wall-clock is the binding constraint.

| Path | Round-trips/recipient | ~ms/recipient | Recipients before 400s kill |
|---|---|---|---|
| notification-sender | 2 (send + health insert) | ~200ms | **~2,000** |
| match-watcher WC push | 1 (+ occasional) | ~120ms | **~3,000–4,000** |

**At 50k installs, any marquee team (England, Brazil, Arsenal, Liverpool…) will be
followed by far more than 2–4k users.** Today the function would push to the first ~2k,
then get killed mid-loop — everyone after the cutoff **silently gets nothing**. The
match-watcher case is worse: it runs on a `* * * * *` cron, so a long goal-burst fan-out
can overrun the next minute's tick.

This is the failure mode that gets *worse* with ad success: more installs → more
followers on the big teams → more recipients per push → faster timeout.

### Fix (in priority order)

1. **Bounded-concurrency fan-out.** Replace the sequential `for` with chunked
   `Promise.all` (≈100–250 in flight). 50k recipients drops from "unbounded fail" to
   ~10–30s. Highest-leverage single change. Add to BOTH paths.
2. **Stop the per-recipient `pipeline_health` insert** in notification-sender — it
   doubles round-trips and writes 50k rows per push. Aggregate to one row per team like
   `sendWcPlayingTeamPush` already does (or sample).
3. **Batch dead-token deactivation** — collect 410/400 tokens, do one
   `UPDATE device_tokens SET is_active=false WHERE apns_token = ANY($1)` after the loop,
   not a write per dead token.
4. **Offload the biggest audiences off the cron tick.** A dispatcher that pages
   `device_tokens` and invokes a worker per N-token batch (or pgmq/a queue) so no single
   invocation can approach 400s and the watcher tick stays sub-minute. Needed if any one
   team exceeds ~10–20k followers.
5. **Real HTTP/2 to APNs** (multiplex many streams on one connection) — much cheaper than
   N HTTP/1.1 connections. Bigger lift; do after 1–4 if volume warrants.

Items 1–3 are small, well-scoped diffs and are enough for 50k spread across ~24 PL clubs
+ 48 countries. Item 4 matters only if the install base concentrates hard on a few teams.

---

## 2. Database / infra

- **Compute.** Pro ($25/mo) base is a **Micro** (1GB, ~60 connections) that saturates
  around 40–50 concurrent connections
  ([pricing](https://www.metacto.com/blogs/the-true-cost-of-supabase-a-comprehensive-guide-to-pricing-integration-and-maintenance)).
  At 50k with **kickoff/FT spikes** (everyone opens the app at once), bump to a
  **Medium/Large compute add-on** (+$50–150/mo). Read load is spiky around match events,
  not steady.
- **Connection pooling.** Ensure PostgREST + Edge + cron all go through **Supavisor
  (transaction mode)**, not direct connections — otherwise 60 conns vanish instantly
  under a spike.
- **Egress.** 50k pulling feeds. Heavily mitigated because the app is **cache-first**
  (`CacheService` SwiftData 30-day feed cache + `TeamPageCache` 24h + `URLCache` for
  crests, `ARCHITECTURE.md` §6) and content is identical per team. Adding HTTP cache
  headers / a CDN in front of the read endpoints would collapse most repeat reads.
- **Indexes: already fine for 50k.** `device_tokens` has btree `team_id` (mig 001) +
  partial btree `country_id` (033) + partial GIN `country_ids`/`team_ids` on `is_active`
  (069). No change needed.

---

## 3. Security item that gets more serious with scale

`device_tokens` + `live_activity_tokens` still allow **anon SELECT of all rows**
(`ARCHITECTURE.md` §9, `AUDIT_FINDINGS.md` SEC-1/2/3). That's a PII + cross-device-tamper
exposure that's a nuisance at 500 users and a real liability at 50k. The fix is already
built (SECURITY DEFINER RPCs, migration 071); the staged drop of anon access
(`072_…PENDING_APP_RELEASE`) just needs the RPC-using build to ship. **Ship that build
before mass adoption.**

---

## 4. Prioritized checklist

**Must-fix before the ads drive volume:**
- [x] Parallelize the push fan-out loops (bounded concurrency, `PUSH_CONCURRENCY=100`). *(§1.1)* — **shipped 2026-06-17**: `_shared/concurrency.ts::mapWithConcurrency` now backs all four senders (`notification-sender`, `match-watcher` WC push, `morning-push`, `matchday-reminder`) + the Live Activity `sendAll`.
- [x] Drop/aggregate per-recipient `pipeline_health` insert. *(§1.2)* — **shipped**: `notification-sender` writes one aggregate `apns_send` row per item; `morning-push` one `morning_push` row per fixture.
- [x] Batch dead-token deactivation. *(§1.3)* — **shipped**: `_shared/supabase-client.ts::deactivateTokens` (one `UPDATE … WHERE token = ANY`), called once per send.
- [ ] Bump Supabase compute to Medium+ and confirm everything uses the pooler. *(§2)* — **dashboard action, still open.**
- [ ] Ship the build that closes anon access on token tables (apply mig 072). *(§3)* — **App Store action, still open.**

**Should-do as volume grows:**
- [ ] Dispatcher/queue fan-out if any single team > ~10–20k followers. *(§1.4)*
- [ ] HTTP cache headers / CDN in front of content reads. *(§2)*
- [ ] Load-test a single team's FT push at 10k/25k/50k synthetic tokens (sandbox).

**Monitor (don't pre-optimize):**
- [ ] `pipeline_health` apns_send partial/failure rates at peak.
- [ ] Supabase connection saturation + CPU during a marquee FT.
- [ ] Egress trend vs. the Pro included allotment.

---

### Sources
- [Supabase Edge Function limits (400s wall-clock / 2s CPU / 150s idle)](https://supabase.com/docs/guides/functions/limits)
- [Supabase 2026 pricing / compute tiers / connection saturation](https://www.metacto.com/blogs/the-true-cost-of-supabase-a-comprehensive-guide-to-pricing-integration-and-maintenance)
- [Supabase pricing at 10K–100K users](https://designrevision.com/blog/supabase-pricing)
