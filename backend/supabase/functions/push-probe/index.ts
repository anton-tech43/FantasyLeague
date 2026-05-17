// push-probe — one-off diagnostic that fires a single APNs push at a
// specific device_token and returns the raw response (status, reason,
// body). Used to debug "notification-sender said success but the phone
// got nothing" cases where the issue is between APNs accepting and iOS
// displaying.
//
// Call: POST /functions/v1/push-probe with body {"token_prefix": "abc12345"}
//       OR with body {"team_id": "arsenal"} to pick the most recent active
//       token for that team. Returns the APNs status code + reason text.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { sendPushNotification, buildAPNsPayload } from "../_shared/apns-client.ts";

serve(async (req) => {
  // Diagnostic endpoint — require service-role bearer. Deployed with
  // --no-verify-jwt (Lesson 37) so the gateway doesn't gate it; without
  // this check, anyone can POST {"team_id":"<any>"} and trigger a
  // synthetic push to the most recent device for that team. Payload is
  // fixed text, so impersonation impact is bounded, but on-demand push
  // spam is unauthenticated. Lock to service-role.
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const auth = req.headers.get("authorization") ?? "";
  if (!serviceKey || auth !== `Bearer ${serviceKey}`) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = getSupabaseClient();
  let body: { token_prefix?: string; team_id?: string } = {};
  try {
    body = await req.json();
  } catch {
    /* no body, use defaults */
  }

  // Find the target token.
  let query = supabase
    .from("device_tokens")
    .select("apns_token, team_id, apns_environment, tier")
    .eq("is_active", true)
    .order("created_at", { ascending: false })
    .limit(1);

  if (body.team_id) query = query.eq("team_id", body.team_id);

  const { data: rows, error: tokenErr } = await query;
  if (tokenErr) {
    return new Response(JSON.stringify({ error: tokenErr.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (!rows || rows.length === 0) {
    return new Response(
      JSON.stringify({ error: "no active device_token matching filter" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const target = rows[0];
  const env = target.apns_environment === "production" ? "production" : "development";
  const tokenPrefix = (target.apns_token as string).slice(0, 12);

  // Synthetic payload — small text, alert type, fixed content_id (won't
  // deep-link to anything real, but the push itself is what we're testing).
  const payload = buildAPNsPayload(
    "GoalDigger",                 // teamShortName
    "Push pipeline test",         // headline
    "00000000-0000-0000-0000-000000000000", // contentId
    "BACKGROUND",                 // category
    false,                        // everyone_talking
    "Tap to confirm the push pipeline is working end-to-end.", // push_text
    "Push test",                  // push_title
  );

  const result = await sendPushNotification(target.apns_token, payload, env);

  return new Response(
    JSON.stringify({
      target: {
        team_id: target.team_id,
        token_prefix: tokenPrefix,
        apns_environment: env,
        tier: target.tier,
      },
      push_result: result,
      payload,
    }, null, 2),
    { headers: { "Content-Type": "application/json" } },
  );
});
