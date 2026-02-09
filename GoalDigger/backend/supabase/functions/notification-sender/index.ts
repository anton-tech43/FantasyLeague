// Goal Digger — Notification Sender Edge Function
// Sends APNs push notifications for approved content. Respects quiet hours
// (08:00-22:00 GMT). Handles token expiry and errors.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ContentItem {
  id: string;
  team_id: string;
  headline: string;
  status: string;
  published_at: string | null;
}

interface DeviceToken {
  id: string;
  team_id: string;
  apns_token: string;
  is_active: boolean;
}

// ---------------------------------------------------------------------------
// APNs JWT helper
// ---------------------------------------------------------------------------

/** Create a JWT for APNs authentication using the .p8 key. */
async function createAPNsJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY");

  if (!keyId || !teamId || !privateKeyPem) {
    throw new Error("APNs credentials not configured (APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY)");
  }

  // Parse the PKCS#8 private key
  const pemContent = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  // Build JWT
  const header = { alg: "ES256", kid: keyId };
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: teamId, iat: now };

  const encode = (obj: unknown) => {
    const json = JSON.stringify(obj);
    const bytes = new TextEncoder().encode(json);
    return btoa(String.fromCharCode(...bytes))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  };

  const headerB64 = encode(header);
  const payloadB64 = encode(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${headerB64}.${payloadB64}.${sigB64}`;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/** Check if current time is within quiet hours (08:00-22:00 GMT). */
function isWithinActiveHours(): boolean {
  const now = new Date();
  const hour = now.getUTCHours();
  return hour >= 8 && hour < 22;
}

/** Send a single APNs push notification. */
async function sendPush(
  token: string,
  teamShortName: string,
  headline: string,
  contentId: string,
  jwt: string,
  isProduction: boolean,
): Promise<{ success: boolean; status: number; reason?: string }> {
  const host = isProduction
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com";

  const apnsPayload = {
    aps: {
      alert: {
        title: "Goal Digger",
        subtitle: teamShortName,
        body: headline,
      },
      sound: "default",
      "mutable-content": 1,
    },
    content_id: contentId,
  };

  try {
    const res = await fetch(`https://${host}/3/device/${token}`, {
      method: "POST",
      headers: {
        Authorization: `bearer ${jwt}`,
        "apns-topic": "com.goaldigger.app",
        "apns-push-type": "alert",
        "apns-priority": "10",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(apnsPayload),
    });

    if (res.status === 200) {
      return { success: true, status: 200 };
    }

    const body = await res.text();
    return { success: false, status: res.status, reason: body };
  } catch (err) {
    return { success: false, status: 0, reason: String(err) };
  }
}

/** Get the team's short name. */
async function getTeamShortName(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
): Promise<string> {
  const { data } = await supabase
    .from("teams")
    .select("short_name")
    .eq("id", teamId)
    .single();
  return data?.short_name ?? teamId;
}

/** Log pipeline health. */
async function logHealth(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
  status: string,
  durationMs: number,
  message: string,
  contentItemId?: string,
) {
  await supabase.from("pipeline_health").insert({
    team_id: teamId,
    stage: "publish",
    status,
    duration_ms: durationMs,
    message,
    content_item_id: contentItemId,
  });
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  try {
    const supabase = getSupabaseClient();

    // Check quiet hours
    if (!isWithinActiveHours()) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "Outside active hours (08:00-22:00 GMT)" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch {
      // No body — sweep mode
    }

    const isSweep = body.sweep === true;
    const specificContentId = body.content_item_id as string | undefined;

    // Find approved but unpublished items
    let query = supabase
      .from("content_items")
      .select("*")
      .eq("status", "approved")
      .is("published_at", null);

    if (specificContentId) {
      query = query.eq("id", specificContentId);
    }

    const { data: items, error: queryErr } = await query;

    if (queryErr) {
      return new Response(
        JSON.stringify({ error: "Query failed", details: queryErr }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    if (!items || items.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, reason: "No approved items to publish" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Create APNs JWT (reuse for all pushes in this batch)
    let jwt: string;
    try {
      jwt = await createAPNsJWT();
    } catch (err) {
      // APNs not configured yet (Phase 5) — log and return
      console.warn("APNs JWT creation failed (expected before Phase 5):", err);

      // Still mark items as published so the pipeline doesn't get stuck
      for (const item of items as ContentItem[]) {
        await supabase
          .from("content_items")
          .update({ status: "published", published_at: new Date().toISOString() })
          .eq("id", item.id);

        await logHealth(
          supabase,
          item.team_id,
          "success",
          0,
          "Published (APNs not configured — push skipped)",
          item.id,
        );
      }

      return new Response(
        JSON.stringify({
          sent: 0,
          published: items.length,
          note: "APNs not configured yet. Items marked as published without push.",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Determine environment (default to sandbox until production is confirmed)
    const isProduction = Deno.env.get("APNS_ENVIRONMENT") === "production";

    const results: Record<string, { sent: number; failed: number; deactivated: number }> = {};

    for (const item of items as ContentItem[]) {
      const startTime = Date.now();
      const teamShortName = await getTeamShortName(supabase, item.team_id);

      // Get active device tokens for this team
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("*")
        .eq("team_id", item.team_id)
        .eq("is_active", true);

      let sent = 0;
      let failed = 0;
      let deactivated = 0;

      if (tokens && tokens.length > 0) {
        for (const token of tokens as DeviceToken[]) {
          const pushResult = await sendPush(
            token.apns_token,
            teamShortName,
            item.headline,
            item.id,
            jwt,
            isProduction,
          );

          if (pushResult.success) {
            sent++;
          } else if (pushResult.status === 410) {
            // 410 Gone — token expired, deactivate it
            await supabase
              .from("device_tokens")
              .update({ is_active: false, updated_at: new Date().toISOString() })
              .eq("id", token.id);
            deactivated++;
          } else if (pushResult.status === 429) {
            // Rate limited — back off (don't retry immediately)
            console.warn(`APNs rate limited for token ${token.id}`);
            failed++;
          } else {
            // Other error
            console.error(
              `APNs error for token ${token.id}: ${pushResult.status} ${pushResult.reason}`,
            );
            failed++;
          }
        }
      }

      // Mark as published regardless of push success/failure
      // (content is available in the feed even if push failed)
      await supabase
        .from("content_items")
        .update({
          status: "published",
          published_at: new Date().toISOString(),
        })
        .eq("id", item.id);

      results[item.id] = { sent, failed, deactivated };

      await logHealth(
        supabase,
        item.team_id,
        failed > sent ? "failure" : "success",
        Date.now() - startTime,
        `Sent: ${sent}, Failed: ${failed}, Deactivated: ${deactivated}`,
        item.id,
      );
    }

    return new Response(
      JSON.stringify({ success: true, results }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Notification sender error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
