// delete-my-data/index.ts
// Goal Digger — GDPR data deletion endpoint
// Accepts an APNs token and deletes the corresponding device_tokens row
// Required for GDPR compliance (CHANGELOG_SECURITY.md item 4)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

serve(async (req) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const apnsToken = body.apns_token as string | undefined;
    // SEC-6: also delete the device's Live Activity token (a DIFFERENT token,
    // holds followed-country data). The client sends its push-to-start token.
    const laToken = body.la_token as string | undefined;

    if (!apnsToken || typeof apnsToken !== "string") {
      return new Response(
        JSON.stringify({ error: "apns_token is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Validate token format (64-char hex)
    if (!/^[a-fA-F0-9]{64}$/.test(apnsToken)) {
      return new Response(
        JSON.stringify({ error: "Invalid token format" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = getSupabaseClient();

    // Delete the device token row
    const { data, error } = await supabase
      .from("device_tokens")
      .delete()
      .eq("apns_token", apnsToken)
      .select("id");

    if (error) {
      console.error("Delete failed:", error.message);
      return new Response(
        JSON.stringify({ error: "Deletion failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Best-effort: delete the Live Activity token(s) for this device too.
    let laDeleted = 0;
    if (laToken && /^[a-fA-F0-9]{16,}$/.test(laToken)) {
      const { data: laData, error: laErr } = await supabase
        .from("live_activity_tokens")
        .delete()
        .eq("token", laToken)
        .select("id");
      if (laErr) console.error("LA token delete failed (non-fatal):", laErr.message);
      else laDeleted = laData?.length ?? 0;
    }

    if ((!data || data.length === 0) && laDeleted === 0) {
      return new Response(
        JSON.stringify({ error: "No matching device token found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Your data has been deleted. You will no longer receive notifications.",
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Invalid request body" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
});
