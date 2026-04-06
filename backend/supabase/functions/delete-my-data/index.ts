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

    if (!data || data.length === 0) {
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
