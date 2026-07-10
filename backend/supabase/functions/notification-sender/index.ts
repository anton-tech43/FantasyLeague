// notification-sender/index.ts
// Goal Digger — Sends push notifications for approved content.
//
// Volume control is tier-based content-type filtering (minTierForType in the
// per-item loop). Anti-spam rules removed 2026-05-17 — they were redundant
// with tier segmentation and the gap check had a bug. See
// _shared/anti-spam.ts header for the full rationale.
//
// Quiet hours are handled by iOS Do Not Disturb on the device, not server-side.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { deactivateTokens, getSupabaseClient, isTokenDead } from "../_shared/supabase-client.ts";
import { mapWithConcurrency, PUSH_CONCURRENCY } from "../_shared/concurrency.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { sendPushNotification, buildAPNsPayload } from "../_shared/apns-client.ts";
// Anti-spam removed 2026-05-17 — see _shared/anti-spam.ts header for rationale.
// Volume control now lives in tier-based content-type filtering (minTierForType)
// + iOS-side Do Not Disturb. Server no longer applies quiet-hours, daily limits,
// or 3-hour gap checks. Those rules were redundant with tier segmentation and
// had a real bug: the gap check compared the item being pushed against itself
// (it's already 'published' before the check runs), so any item with no prior
// pushed item in 24h would silently fail.
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";

function getCategoryFromType(
  type: string,
  emotionalContext: string | null
): string {
  if (type === "matchday") return "MATCHDAY_HEADS_UP";
  if (emotionalContext === "exciting" || emotionalContext === "bad_news") return "RESULT";
  return "NEWS";
}

serve(async (req) => {
  // Caller-auth gate. Server-only — invoked by the notification-sweep
  // cron (CRON_AUTH_KEY) + content-reviewer triggerFunction (SERVICE_KEY).
  // Without it, anyone with the anon key could drive APNs sends.
  const denied = requireServiceAuth(req);
  if (denied) return denied;

  const startTime = Date.now();
  const supabase = getSupabaseClient();

  try {
    const body = await req.json().catch(() => ({}));
    const specificItemId = body.content_item_id as string | undefined;
    const specificTeamId = body.team_id as string | undefined;
    // Manual-recovery override. The specific-item path normally respects
    // push_eligible (Lesson 83) so a feed-only item can't be force-pushed
    // through the side door. An operator replaying a push deliberately can
    // pass force_push:true to bypass the gate.
    const forcePush = body.force_push === true;

    // Three modes:
    //   1. Specific-item (caller passes content_item_id): routine path. Item
    //      is already status='published'; we just need to push.
    //   2. Sweep (no body): the hourly cron. Catches:
    //      a) Legacy edge-function approved-but-unpublished items (in case
    //         CONTENT_GENERATOR_ENABLED is ever turned back on).
    //      b) Unpushed published items (status='published' AND pushed_at IS NULL
    //         AND published_at < NOW() - 5min). This is the resilience layer:
    //         if APNs was down or post_news.sh's curl failed, the item still
    //         got published but never got a push. The sweep retries it.
    //   The 5-min grace window prevents the sweep from racing post_news.sh's
    //   own push trigger.
    let query = supabase.from("content_items").select("*");
    if (specificItemId) {
      // Explicit per-item invocation (the routine path: post_news.sh POSTs
      // {content_item_id} right after insert). Lesson 83: this path MUST
      // respect push_eligible, otherwise the Lesson 82 speculation/teaser
      // downgrade is defeated — the item ships push_eligible=false but the
      // direct trigger pushes it anyway (the Rogers/PSG push, 2026-06-01).
      // The sweep already filtered; this side door has to as well. Manual
      // recovery can still override with force_push:true.
      query = query.eq("id", specificItemId);
      if (!forcePush) {
        query = query.eq("push_eligible", true);
      }
    } else {
      // Sweep: union of (a) and (b) above. Limit to 50 per run so a long
      // outage doesn't trigger a flood when the sweep recovers. The 24h
      // lower bound on published_at prevents a stuck row from pushing
      // days later — a "Spurs drew 1-1" push five days after the match
      // is creepier than no push at all.
      const now = Date.now();
      const fiveMinAgo = new Date(now - 5 * 60_000).toISOString();
      const twentyFourHoursAgo = new Date(now - 24 * 60 * 60_000).toISOString();
      query = query
        .or(
          "and(status.eq.approved,published_at.is.null)," +
          "and(status.eq.published,pushed_at.is.null,published_at.lt." +
          fiveMinAgo + ",published_at.gt." + twentyFourHoursAgo + ")"
        )
        // Push-eligibility gate (Lesson 76). Routines tag fun-trivia
        // items (e.g. "Arsenal's Odegaard heading to the WC as Norway
        // captain" written for Arsenal followers) with
        // push_eligible=false. They still publish to the feed; this
        // filter just excludes them from the APNs fanout. Default TRUE
        // on the column means legacy rows and routines that don't know
        // about the field ship the legacy behaviour.
        .eq("push_eligible", true)
        .limit(50);
    }

    const { data: items, error: itemsErr } = await query;
    if (itemsErr) throw new Error(`Failed to fetch items: ${itemsErr.message}`);
    if (!items || items.length === 0) {
      return new Response(JSON.stringify({ message: "No items to publish" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get team short names + entity types (entity_type='tournament' marks
    // broadcast pseudo-entities like 'world_championship')
    const { data: teams } = await supabase.from("teams").select("id, short_name, entity_type");
    const teamShortNames: Record<string, string> = {};
    const teamEntityTypes: Record<string, string> = {};
    for (const t of teams ?? []) {
      teamShortNames[t.id] = t.short_name;
      teamEntityTypes[t.id] = t.entity_type;
    }

    // Per-team push throttle window (audit 2026-06-05, Lesson 89). Kept at
    // 5 min — tight enough to collapse same-fire doubles (a routine writing
    // two items seconds apart, each triggering a push) without suppressing
    // genuinely-spaced matchday news (a result then a later, different item).
    const PUSH_THROTTLE_MINUTES = 5;

    for (const item of items) {
      const teamId = item.team_id;
      const shortName = teamShortNames[teamId] ?? teamId;
      const category = getCategoryFromType(item.type, item.emotional_context);
      const isResult = category === "RESULT";

      // Guard A — never send a push with an empty push_title. The 2026-06-05
      // audit found 17 (backfilled) items with null push_title; a real one
      // would render a blank/broken lock-screen ping. Publish to the feed +
      // mark pushed_at (so the sweep won't retry), but send no APNs.
      if (!item.push_title || String(item.push_title).trim() === "") {
        const update: Record<string, string> = { pushed_at: new Date().toISOString() };
        if (item.status !== "published") {
          update.status = "published";
          update.published_at = new Date().toISOString();
        }
        await supabase.from("content_items").update(update).eq("id", item.id);
        await logPipelineEvent(supabase, {
          team_id: teamId,
          stage: "publish",
          status: "skipped",
          duration_ms: Date.now() - startTime,
          message: "Skipped push: empty push_title",
          content_item_id: item.id,
        });
        continue;
      }

      // Guard B — per-team push throttle. If this team already received a
      // push within PUSH_THROTTLE_MINUTES, leave this item feed-only (the
      // story still publishes). force_push bypasses for manual recovery.
      if (!forcePush) {
        const throttleSince = new Date(Date.now() - PUSH_THROTTLE_MINUTES * 60_000).toISOString();
        const { count: recentCount } = await supabase
          .from("content_items")
          .select("id", { count: "exact", head: true })
          .eq("team_id", teamId)
          .not("pushed_at", "is", null)
          .gte("pushed_at", throttleSince)
          .neq("id", item.id);
        if ((recentCount ?? 0) > 0) {
          const update: Record<string, string> = { pushed_at: new Date().toISOString() };
          if (item.status !== "published") {
            update.status = "published";
            update.published_at = new Date().toISOString();
          }
          await supabase.from("content_items").update(update).eq("id", item.id);
          await logPipelineEvent(supabase, {
            team_id: teamId,
            stage: "publish",
            status: "skipped",
            duration_ms: Date.now() - startTime,
            message: `Throttled: ${teamId} already pushed within ${PUSH_THROTTLE_MINUTES}m`,
            content_item_id: item.id,
          });
          continue;
        }
      }

      // Get all active device tokens for this team OR country with their
      // tiers + APNs env. The env tells us whether to push to sandbox
      // (DEBUG iOS builds) or production (App Store / TestFlight) — Apple's
      // two endpoints aren't interchangeable.
      //
      // V2.0: content_items.team_id is a polymorphic slug — either a PL club
      // (e.g. "arsenal") or a WC country ("england"). Match either column
      // so:
      //   - PL content reaches PL subscribers via team_id=team_id
      //   - WC content reaches WC subscribers via country_id=team_id
      //   - A user who follows both their club and country (`device_tokens`
      //     row has BOTH columns set) gets both kinds of pushes
      //
      // V2.2: a device may follow up to 2 countries + 2 clubs, stored in the
      // country_ids/team_ids arrays. Match the legacy scalar (old apps) OR the
      // array containing this slug (new apps). One row per device → one push.
      //
      // Tournament broadcast (WC knockout match-day analysis, team_id=
      // 'world_championship'): goes to ALL active devices, EXCEPT devices
      // following either competing country (item.affected_team_ids) — those
      // users already get the 07:00 UTC matchday-reminder that morning and
      // must not be double-pinged. Exclusion happens in code after the fetch:
      // PostgREST not.in / not.ov would drop rows with NULL country_id /
      // country_ids (SQL NULL semantics), wrongly excluding club-only devices.
      //
      // Paginated with .range(): PostgREST silently caps one response at
      // max-rows (Supabase default 1000), which would truncate an all-devices
      // broadcast to the first 1000 users. Ordered by apns_token (UNIQUE) so
      // pages neither skip nor duplicate rows. The same loop serves the
      // follower path — it rarely needs page 2, but correctness is free.
      const isTournament = teamEntityTypes[teamId] === "tournament";
      const affected: string[] = isTournament ? (item.affected_team_ids ?? []) : [];
      const TOKEN_PAGE_SIZE = 1000;
      // deno-lint-ignore no-explicit-any
      const tokens: any[] = [];
      for (let from = 0; ; from += TOKEN_PAGE_SIZE) {
        let pageQuery = supabase
          .from("device_tokens")
          .select("apns_token, tier, apns_environment, country_id, country_ids")
          .eq("is_active", true)
          .order("apns_token")
          .range(from, from + TOKEN_PAGE_SIZE - 1);
        if (!isTournament) {
          pageQuery = pageQuery.or(
            `team_id.eq.${teamId},country_id.eq.${teamId},team_ids.cs.{${teamId}},country_ids.cs.{${teamId}}`,
          );
        }
        const { data: page, error: pageErr } = await pageQuery;
        // Throw rather than continue: a mid-pagination error would otherwise
        // look like "no more devices" and mark the item pushed with a partial
        // (or empty) audience. Unpushed items get retried by the sweep.
        if (pageErr) throw new Error(`Failed to fetch device tokens: ${pageErr.message}`);
        for (const t of page ?? []) {
          if (affected.includes(t.country_id)) continue;
          if ((t.country_ids ?? []).some((c: string) => affected.includes(c))) continue;
          tokens.push(t);
        }
        if (!page || page.length < TOKEN_PAGE_SIZE) break;
      }

      if (tokens.length === 0) {
        // No devices — still mark as published so it appears in the feed,
        // unless the item is already published (routine flow). Also mark
        // pushed_at so the sweep doesn't re-pick this item indefinitely:
        // there's nothing TO push to.
        const update: Record<string, string> = { pushed_at: new Date().toISOString() };
        if (item.status !== "published") {
          update.status = "published";
          update.published_at = new Date().toISOString();
        }
        await supabase.from("content_items").update(update).eq("id", item.id);
        continue;
      }

      // Tier-based content-type filter. Each content type declares the
      // minimum tier that receives it. Today only sunday_brief is T2+; all
      // other types reach T1+. As we add new tier-gated surfaces (Saturday
      // Quiz, Player Dossier), extend the mapping below.
      //
      // No anti-spam rules. Tier segmentation IS the volume control:
      //   T1 ≈ matchday + result + news (3-4 pushes/day on busy days)
      //   T2 ≈ T1 + sunday_brief
      //   T3 ≈ T2 + future T3-only surfaces
      // Quiet hours handled by iOS Do Not Disturb on the device, not by the
      // server (server-side quiet hours meant matchday pushes for late-evening
      // games never reached the user — bad trade for a feature iOS does natively).
      const minTierForType = item.type === "sunday_brief" ? 2 : 1;

      type TokenEntry = { token: string; env: "development" | "production" };
      const eligibleTokens: TokenEntry[] = [];
      for (const t of tokens) {
        const tier = t.tier ?? 2;
        if (tier < minTierForType) continue;
        const env = (t.apns_environment === "production" ? "production" : "development") as "development" | "production";
        eligibleTokens.push({ token: t.apns_token, env });
      }

      if (eligibleTokens.length === 0) {
        // No devices match the min-tier filter — all subscribers are at a
        // lower tier than this content type targets. Mark pushed_at so the
        // sweep doesn't keep re-picking this item.
        await supabase
          .from("content_items")
          .update({ pushed_at: new Date().toISOString() })
          .eq("id", item.id);
        await logPipelineEvent(supabase, {
          team_id: teamId,
          stage: "publish",
          status: "skipped",
          duration_ms: Date.now() - startTime,
          message: `No tokens at or above min tier ${minTierForType} for type=${item.type}`,
          content_item_id: item.id,
        });
        continue;
      }

      // Build APNs payload (Contract 2). Pass push_title + push_text so the
      // lock-screen ping uses the sister-voice opener as title and the
      // hand-tuned push body — instead of falling back to team short_name +
      // long headline. Backwards-compat: if either field is NULL (rows
      // pre-migration 011/012), buildAPNsPayload falls back to teamShortName
      // and headline respectively.
      //
      // Tournament-broadcast items need everyone_talking=true in the payload
      // so old apps deep-link into the Everyone context. That already works:
      // the routine writes everyone_talking=true on the row and
      // item.everyone_talking is passed straight through below into the
      // payload's everyone_talking userInfo field. No hardcode needed.
      const payload = buildAPNsPayload(
        shortName,
        item.headline,
        item.id,
        category,
        item.everyone_talking ?? false,
        item.push_text ?? null,
        item.push_title ?? null,
      );

      // Send to all eligible tokens with bounded concurrency. The old
      // sequential `for … await` fan-out blew the 400s Edge wall-clock ceiling
      // for any team with more than ~2k followers — the function died mid-loop
      // and everyone after the cutoff silently got nothing (SCALING_50K.md §1).
      // A fixed in-flight pool keeps the whole send to ~tens of seconds. The
      // per-recipient side effects (dead-token cleanup, observability) are now
      // batched AFTER the loop instead of adding two DB round-trips per token.
      let aborted = false; // set on the first 403 — stop hammering APNs on auth failure
      type SendOutcome = {
        token: string;
        success: boolean;
        status?: number;
        reason?: string;
        skipped?: boolean;
      };
      const outcomes = await mapWithConcurrency<TokenEntry, SendOutcome>(
        eligibleTokens,
        PUSH_CONCURRENCY,
        async ({ token, env }) => {
          // A prior task hit a 403 (bad .p8 / JWT) — every send is doomed the
          // same way, so skip the rest rather than spray thousands of requests.
          if (aborted) return { token, success: false, skipped: true };
          let result = await sendPushNotification(token, payload, env);
          // 429 = APNs back-pressure. Back off once and retry this one token.
          if (result.status === 429) {
            await new Promise((r) => setTimeout(r, 5000));
            result = await sendPushNotification(token, payload, env);
          }
          if (result.status === 403) aborted = true;
          return { token, success: result.success, status: result.status, reason: result.reason };
        },
      );

      const attempted = outcomes.filter((o) => !o.skipped);
      const successCount = attempted.filter((o) => o.success).length;
      const failCount = attempted.length - successCount;

      // Batch-deactivate every token APNs reported dead (410/400) in ONE UPDATE.
      const deadTokens = attempted.filter((o) => isTokenDead(o)).map((o) => o.token);
      await deactivateTokens(supabase, "device_tokens", deadTokens);

      // One aggregate apns_send observability row per item (was one row PER
      // token — 50k inserts per push at scale). The message carries the
      // per-class failure breakdown so push churn stays visible in
      // pipeline_health; the dominant class is recorded in error_class.
      const classCounts = new Map<string, number>();
      for (const o of attempted) {
        if (o.success) continue;
        const cls = o.status === 410
          ? "410"
          : o.status === 400
            ? "400"
            : o.status === 403
              ? "403"
              : o.status === 429
                ? "429"
                : "other";
        classCounts.set(cls, (classCounts.get(cls) ?? 0) + 1);
      }
      const breakdown = [...classCounts.entries()].map(([k, v]) => `${k}:${v}`).join(" ");
      const sawAuthFailure = classCounts.has("403");
      const apnsErrorClass = failCount === 0
        ? "success"
        : sawAuthFailure
          ? "auth_failure"
          : classCounts.has("429")
            ? "rate_limited"
            : classCounts.has("410")
              ? "token_expired"
              : classCounts.has("400")
                ? "bad_token"
                : "apns_error";
      try {
        await logPipelineEvent(supabase, {
          team_id: teamId,
          stage: "apns_send",
          status: failCount === 0 ? "success" : successCount === 0 ? "failure" : "partial",
          target: `item:${item.id}`,
          error_class: apnsErrorClass,
          message:
            `APNs: ${successCount} sent, ${failCount} failed of ${attempted.length}` +
            (breakdown ? ` (${breakdown})` : ""),
          content_item_id: item.id,
        });
      } catch (e) {
        console.error("apns_send pipeline_health log failed (non-fatal):", e);
      }

      // A 403 means the provider JWT/.p8 is broken — every push is doomed and
      // the fan-out already aborted. Fire one CRITICAL alert to the dev iPhone
      // (throttled to once per 30 min inside client-error-alert) + a high-level
      // 'publish' failure row for the heartbeat to find.
      if (sawAuthFailure) {
        console.error("CRITICAL: APNs auth failure (403). Check .p8 key configuration.");
        await logPipelineEvent(supabase, {
          team_id: teamId,
          stage: "publish",
          status: "failure",
          duration_ms: Date.now() - startTime,
          message: "CRITICAL: APNs 403 auth failure — check .p8 key",
          content_item_id: item.id,
        });
        try {
          const supabaseUrl = Deno.env.get("SUPABASE_URL");
          // SERVICE_KEY = new sb_secret_*; legacy JWT as transition fallback.
          const serviceKey =
            Deno.env.get("SERVICE_KEY") ??
            Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
          if (supabaseUrl && serviceKey) {
            await fetch(`${supabaseUrl}/functions/v1/client-error-alert`, {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${serviceKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                error_type: "apns_auth_failure",
                message: `APNs 403 sending content_item=${item.id} team=${teamId}. Check APNS_KEY_P8/KEY_ID/TEAM_ID secrets.`,
                team_id: teamId,
                app_version: "backend-notification-sender",
              }),
            });
          }
        } catch (e) {
          console.error("Failed to fire client-error-alert for apns_auth_failure:", e);
        }
      }

      // Mark pushed_at always (we attempted; outcome is recorded in successCount).
      // Mark status=published only if it wasn't already (routine items come in
      // pre-published; we don't want to overwrite their original timestamp).
      const update: Record<string, string> = { pushed_at: new Date().toISOString() };
      if (item.status !== "published") {
        update.status = "published";
        update.published_at = new Date().toISOString();
      }
      await supabase.from("content_items").update(update).eq("id", item.id);

      // Aggregate publish row — status reflects the actual outcome across
      // tokens. 'success' = all sent, 'partial' = some sent some failed,
      // 'failure' = none sent. The per-token detail is in the apns_send
      // rows logged above.
      const aggregateStatus =
        failCount === 0
          ? "success"
          : successCount === 0
            ? "failure"
            : "partial";
      await logPipelineEvent(supabase, {
        team_id: teamId,
        stage: "publish",
        status: aggregateStatus,
        duration_ms: Date.now() - startTime,
        message: `Push: ${successCount} sent, ${failCount} failed of ${eligibleTokens.length} eligible`,
        content_item_id: item.id,
      });
    }

    return new Response(
      JSON.stringify({ success: true, items_processed: items.length }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("notification-sender error:", message);

    await logPipelineEvent(supabase, {
      team_id: "unknown",
      stage: "publish",
      status: "failure",
      duration_ms: Date.now() - startTime,
      message,
      content_item_id: null,
    });

    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
