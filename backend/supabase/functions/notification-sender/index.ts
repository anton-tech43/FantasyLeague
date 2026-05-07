// notification-sender/index.ts
// Goal Digger — Sends push notifications for approved content
// Enforces anti-spam rules (Contract 4), tier-based limits, quiet hours
// Result notifications bypass quiet hours (22:00-08:00)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { sendPushNotification, buildAPNsPayload } from "../_shared/apns-client.ts";
import { checkAntiSpamRules } from "../_shared/anti-spam.ts";
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
      // outage doesn't trigger a flood when the sweep recovers.
      query = query
        .or(
          "and(status.eq.approved,published_at.is.null)," +
          "and(status.eq.published,pushed_at.is.null,published_at.lt." +
          new Date(Date.now() - 5 * 60_000).toISOString() + ")"
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

      // Get all active device tokens for this team with their tiers + APNs env.
      // The env tells us whether to push to sandbox (DEBUG iOS builds) or production
      // (App Store / TestFlight builds) — Apple's two endpoints aren't interchangeable.
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("apns_token, tier, apns_environment")
        .eq("team_id", teamId)
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

      // Group tokens by tier (carry env alongside) for anti-spam checking
      type TokenEntry = { token: string; env: "development" | "production" };
      const tokensByTier: Record<number, TokenEntry[]> = {};
      for (const t of tokens) {
        const tier = t.tier ?? 2;
        const env = (t.apns_environment === "production" ? "production" : "development") as "development" | "production";
        if (!tokensByTier[tier]) tokensByTier[tier] = [];
        tokensByTier[tier].push({ token: t.apns_token, env });
      }

      // Check anti-spam for each tier group
      const eligibleTokens: TokenEntry[] = [];
      for (const [tierStr, tierTokens] of Object.entries(tokensByTier)) {
        const tier = parseInt(tierStr);
        const contentType = isResult ? "result" as const : item.type as "news" | "matchday";

        const spamCheck = await checkAntiSpamRules(supabase, teamId, contentType, tier);
        if (spamCheck.canSend) {
          eligibleTokens.push(...tierTokens);
        } else {
          console.log(
            `Anti-spam blocked for tier ${tier} (${teamId}): ${spamCheck.reason}`
          );
        }
      }

      if (eligibleTokens.length === 0) {
        // All tiers blocked — skip but don't reject. Mark pushed_at so the
        // sweep won't keep re-picking this item; the anti-spam decision is
        // a deliberate "we considered this and chose not to send."
        await supabase
          .from("content_items")
          .update({ pushed_at: new Date().toISOString() })
          .eq("id", item.id);
        await logPipelineEvent(supabase, {
          team_id: teamId,
          stage: "publish",
          status: "skipped",
          duration_ms: Date.now() - startTime,
          message: "All tiers blocked by anti-spam rules",
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
        const result = await sendPushNotification(token, payload, env);

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
              const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
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

      await logPipelineEvent(supabase, {
        team_id: teamId,
        stage: "publish",
        status: "success",
        duration_ms: Date.now() - startTime,
        message: `Published. Push: ${successCount} sent, ${failCount} failed of ${eligibleTokens.length} eligible`,
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
