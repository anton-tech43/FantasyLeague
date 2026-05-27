// client-error-alert/index.ts
// Goal Digger — Receives error reports from the iOS client, logs them,
// and pushes alerts to registered developer devices.
//
// Throttling: same error_type fires at most once per 30 minutes. Prevents
// a flapping endpoint from spamming the dev's lock screen 100 times.
//
// Auth: iOS POSTs with the anon key (same as any other edge call). The
// function uses the service role internally to write to the protected
// client_errors and dev_alert_devices tables.
//
// Expected POST body:
// {
//   error_type: string,
//   message: string,
//   request_path?: string,
//   team_id?: string,
//   app_version?: string,
//   device_model?: string,
//   os_version?: string
// }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { sendPushNotification } from "../_shared/apns-client.ts";

const THROTTLE_MINUTES = 30;

interface ErrorReport {
  error_type: string;
  message: string;
  request_path?: string;
  team_id?: string;
  app_version?: string;
  device_model?: string;
  os_version?: string;
}

serve(async (req) => {
  // Caller-auth gate (see _shared/require-service-auth.ts). Server-only
  // function — rejects anon-key / no-auth callers; accepts the service
  // key that triggerFunction + pg_cron present.
  const denied = requireServiceAuth(req);
  if (denied) return denied;
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = getSupabaseClient();

  let report: ErrorReport;
  try {
    report = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!report.error_type || !report.message) {
    return new Response(
      JSON.stringify({ error: "error_type and message are required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  // Insert the log row regardless of whether we send a push.
  // Full history lives in client_errors so the dev can review trends.
  const { data: inserted, error: insertErr } = await supabase
    .from("client_errors")
    .insert({
      error_type: report.error_type,
      message: report.message.slice(0, 1000),
      request_path: report.request_path?.slice(0, 500) ?? null,
      team_id: report.team_id ?? null,
      app_version: report.app_version ?? null,
      device_model: report.device_model ?? null,
      os_version: report.os_version ?? null,
    })
    .select("id, created_at")
    .single();

  if (insertErr || !inserted) {
    return new Response(
      JSON.stringify({ error: `log insert failed: ${insertErr?.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Throttle: skip the push if we've alerted on this error_type recently.
  const cutoff = new Date(Date.now() - THROTTLE_MINUTES * 60_000).toISOString();
  const { data: recentAlert } = await supabase
    .from("client_errors")
    .select("id")
    .eq("error_type", report.error_type)
    .gte("alerted_at", cutoff)
    .limit(1)
    .maybeSingle();

  if (recentAlert) {
    return new Response(
      JSON.stringify({ logged: true, alerted: false, reason: "throttled" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  // Send pushes to all active dev_alert_devices.
  const { data: devices } = await supabase
    .from("dev_alert_devices")
    .select("apns_token, label, apns_environment")
    .eq("is_active", true);

  if (!devices || devices.length === 0) {
    // Nothing to push to. Log row is still saved.
    return new Response(
      JSON.stringify({ logged: true, alerted: false, reason: "no_dev_devices" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const title = `⚠️ Goal Digger: ${report.error_type}`;
  const body = report.team_id
    ? `[${report.team_id}] ${report.message}`.slice(0, 200)
    : report.message.slice(0, 200);

  const pushResults = await Promise.all(
    devices.map((d) => {
      const env = (d.apns_environment === "production" ? "production" : "development") as
        "development" | "production";
      return sendPushNotification(d.apns_token, {
        aps: {
          alert: {
            title,
            subtitle: report.app_version ?? "",
            body,
          },
          sound: "default",
          "mutable-content": 1,
          category: "DEV_ALERT",
        },
        content_id: "dev-alert",
      }, env);
    }),
  );

  const successes = pushResults.filter((r) => r.success).length;

  // Mark the row as alerted so the next throttle window starts now.
  await supabase
    .from("client_errors")
    .update({ alerted_at: new Date().toISOString() })
    .eq("id", inserted.id);

  return new Response(
    JSON.stringify({
      logged: true,
      alerted: true,
      pushes_sent: successes,
      pushes_failed: pushResults.length - successes,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
