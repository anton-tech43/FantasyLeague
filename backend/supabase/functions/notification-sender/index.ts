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

    // Query approved items that haven't been published yet
    let query = supabase
      .from("content_items")
      .select("*")
      .eq("status", "approved")
      .is("published_at", null);

    if (specificItemId) {
      query = query.eq("id", specificItemId);
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

      // Get all active device tokens for this team with their tiers
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("apns_token, tier")
        .eq("team_id", teamId)
        .eq("is_active", true);

      if (!tokens || tokens.length === 0) {
        // No devices — still mark as published so it appears in the feed
        await supabase
          .from("content_items")
          .update({ status: "published", published_at: new Date().toISOString() })
          .eq("id", item.id);
        continue;
      }

      // Group tokens by tier for anti-spam checking
      const tokensByTier: Record<number, string[]> = {};
      for (const t of tokens) {
        const tier = t.tier ?? 2;
        if (!tokensByTier[tier]) tokensByTier[tier] = [];
        tokensByTier[tier].push(t.apns_token);
      }

      // Check anti-spam for each tier group
      const eligibleTokens: string[] = [];
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
        // All tiers blocked — skip but don't reject
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

      // Build APNs payload (Contract 2)
      const payload = buildAPNsPayload(shortName, item.headline, item.id, category);

      // Send to all eligible tokens
      let successCount = 0;
      let failCount = 0;

      for (const token of eligibleTokens) {
        const result = await sendPushNotification(token, payload);

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
            // Auth broken — CRITICAL, stop all sends
            console.error("CRITICAL: APNs auth failure (403). Check .p8 key configuration.");
            await logPipelineEvent(supabase, {
              team_id: teamId,
              stage: "publish",
              status: "failure",
              duration_ms: Date.now() - startTime,
              message: "CRITICAL: APNs 403 auth failure — check .p8 key",
              content_item_id: item.id,
            });
            break;
          } else if (result.status === 429) {
            // Rate limited — back off and retry once
            await new Promise((r) => setTimeout(r, 5000));
            const retry = await sendPushNotification(token, payload);
            if (retry.success) successCount++;
          }
        }
      }

      // Mark content as published (it's in the feed regardless of push success)
      await supabase
        .from("content_items")
        .update({
          status: "published",
          published_at: new Date().toISOString(),
        })
        .eq("id", item.id);

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
