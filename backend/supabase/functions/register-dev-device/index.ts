// register-dev-device/index.ts
// Goal Digger — Auto-register a developer's APNs token to receive
// error-monitoring push alerts.
//
// Called by the iOS app in DEBUG builds only (the call site is
// compile-time gated with #if DEBUG, so App Store / TestFlight
// builds never call this). DEBUG builds = builds you run from
// Xcode onto your own device or simulator.
//
// Idempotent — calling repeatedly with the same token is fine.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

interface RegisterRequest {
  apns_token: string;
  label?: string;
  apns_environment?: "development" | "production";
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: RegisterRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid JSON body" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  // Validate token format — same constraint as the table
  if (!body.apns_token || !/^[a-fA-F0-9]{64}$/.test(body.apns_token)) {
    return new Response(
      JSON.stringify({ error: "apns_token must be 64 hex characters" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const label = (body.label ?? "dev-device").slice(0, 100);
  const env = body.apns_environment === "production" ? "production" : "development";

  const supabase = getSupabaseClient();
  const { error } = await supabase
    .from("dev_alert_devices")
    .upsert(
      { apns_token: body.apns_token, label, is_active: true, apns_environment: env },
      { onConflict: "apns_token" },
    );

  if (error) {
    return new Response(
      JSON.stringify({ error: `upsert failed: ${error.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ registered: true, label }),
    { headers: { "Content-Type": "application/json" } },
  );
});
