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
import { getSupabaseClient } from "../_shared/supabase-client.ts";
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
  const startTime = Date.now();
  const supabase = getSupabaseClient();

  try {
    const body = await req.json().catch(() => ({}));
    const specificItemId = body.content_item_id as string | undefined;
    const specificTeamId = body.team_id as string | undefined;

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
      query = query.eq("id", specificItemId);
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
        .limit(50);
    }

    const { data: items, error: itemsErr } = await query;
    if (itemsErr) throw new Error(`Failed to fetch items: ${itemsErr.message}`);
    if (!items || items.length === 0) {
      return new Response(JSON.stringify({ message: "No items to publish" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get team short names
    const { data: teams } = await supabase.from("teams").select("id, short_name");
    const teamShortNames: Record<string, string> = {};
    for (const t of teams ?? []) {
      teamShortNames[t.id] = t.short_name;
    }

    for (const item of items) {
      const teamId = item.team_id;
      const shortName = teamShortNames[teamId] ?? teamId;
      const category = getCategoryFromType(item.type, item.emotional_context);
      const isResult = category === "RESULT";

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
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("apns_token, tier, apns_environment")
        .or(`team_id.eq.${teamId},country_id.eq.${teamId}`)
        .eq("is_active", true);

      if (!tokens || tokens.length === 0) {
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
      const payload = buildAPNsPayload(
        shortName,
        item.headline,
        item.id,
        category,
        item.everyone_talking ?? false,
        item.push_text ?? null,
        item.push_title ?? null,
      );

      // Send to all eligible tokens
      let successCount = 0;
      let failCount = 0;

      for (const entry of eligibleTokens) {
        const { token, env } = entry;
        const tokenPrefix = token.slice(0, 12);
        const result = await sendPushNotification(token, payload, env);

        // Per-attempt apns_send observability row. Captures the APNs status
        // for every token attempt so we see push churn (410/400 deactivations)
        // and per-token success patterns in pipeline_health. See Phase J.
        // Best-effort; logging never breaks the send loop.
        const APNS_STATUS_TO_ERROR_CLASS: Record<number, string> = {
          410: "token_expired",
          400: "bad_token",
          403: "auth_failure",
          429: "rate_limited",
        };
        const errorClass = result.success
          ? "success"
          : (result.status !== undefined && APNS_STATUS_TO_ERROR_CLASS[result.status]) ||
            "apns_error";
        try {
          await logPipelineEvent(supabase, {
            team_id: teamId,
            stage: "apns_send",
            status: result.success ? "success" : "failure",
            target: `apns:${tokenPrefix}:${item.id}`,
            http_status: result.status ?? null,
            error_class: errorClass,
            message: result.success
              ? null
              : `APNs ${result.status}${result.reason ? ` ${result.reason}` : ""}`,
            content_item_id: item.id,
          });
        } catch (e) {
          console.error("apns_send pipeline_health log failed (non-fatal):", e);
        }

        if (result.success) {
          successCount++;
        } else {
          failCount++;

          // Handle specific APNs errors
          if (result.status === 410 || result.reason === "Unregistered") {
            // Token expired — deactivate
            await supabase
              .from("device_tokens")
              .update({ is_active: false, updated_at: new Date().toISOString() })
              .eq("apns_token", token);
          } else if (result.status === 400) {
            // Bad token — deactivate
            await supabase
              .from("device_tokens")
              .update({ is_active: false, updated_at: new Date().toISOString() })
              .eq("apns_token", token);
          } else if (result.status === 403) {
            // Auth broken — CRITICAL, stop all sends. Log + alert dev iPhone
            // via the existing client-error-alert path so we find out within
            // minutes (throttled to once per 30 min by the alert function).
            // Note: the apns_send row above already captured this 403 with
            // error_class='auth_failure'; this 'publish' row is the
            // higher-level CRITICAL signal for the heartbeat to find.
            console.error("CRITICAL: APNs auth failure (403). Check .p8 key configuration.");
            await logPipelineEvent(supabase, {
              team_id: teamId,
              stage: "publish",
              status: "failure",
              duration_ms: Date.now() - startTime,
              message: "CRITICAL: APNs 403 auth failure — check .p8 key",
              content_item_id: item.id,
            });
            // Fire client-error-alert so the dev iPhone gets a push. The
            // function logs + throttles + pushes via dev_alert_devices. Without
            // this we'd only know via Supabase function logs (manual check).
            // Best-effort: don't block the break-out on failure here.
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
            break;
          } else if (result.status === 429) {
            // Rate limited — back off and retry once
            await new Promise((r) => setTimeout(r, 5000));
            const retry = await sendPushNotification(token, payload, env);
            if (retry.success) successCount++;
          }
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
