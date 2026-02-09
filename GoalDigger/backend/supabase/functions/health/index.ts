// Goal Digger — Health Check Edge Function
// Returns real-time status of the pipeline for monitoring.
// See RUNBOOK.md for alert conditions.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async () => {
  try {
    const supabase = getSupabaseClient();
    const now = new Date();
    const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
    const last4h = new Date(now.getTime() - 4 * 60 * 60 * 1000).toISOString();
    const last48h = new Date(now.getTime() - 48 * 60 * 60 * 1000).toISOString();

    // Get all teams
    const { data: teams } = await supabase.from("teams").select("*");
    if (!teams) throw new Error("Failed to load teams");

    const teamHealth: Record<string, unknown> = {};

    for (const team of teams) {
      // Last pipeline stage timestamps
      const stages = ["fetch", "generate", "review", "publish"];
      const lastActivity: Record<string, string | null> = {};

      for (const stage of stages) {
        const { data } = await supabase
          .from("pipeline_health")
          .select("created_at")
          .eq("team_id", team.id)
          .eq("stage", stage)
          .eq("status", "success")
          .order("created_at", { ascending: false })
          .limit(1);

        lastActivity[stage] = data?.[0]?.created_at ?? null;
      }

      // Error counts in last 24h
      const { count: errorCount } = await supabase
        .from("pipeline_health")
        .select("id", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("status", "failure")
        .gte("created_at", last24h);

      // Published content count in last 24h
      const { count: publishedCount } = await supabase
        .from("content_items")
        .select("id", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("status", "published")
        .gte("published_at", last24h);

      // Total published content
      const { count: totalPublished } = await supabase
        .from("content_items")
        .select("id", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("status", "published");

      // Active device tokens
      const { count: activeTokens } = await supabase
        .from("device_tokens")
        .select("id", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("is_active", true);

      // Alert conditions
      const alerts: string[] = [];

      // No fetch in 4 hours
      if (!lastActivity.fetch || new Date(lastActivity.fetch) < new Date(last4h)) {
        alerts.push("HIGH: No successful fetch in 4+ hours");
      }

      // No generated content in 12 hours
      const last12h = new Date(now.getTime() - 12 * 60 * 60 * 1000).toISOString();
      if (!lastActivity.generate || new Date(lastActivity.generate) < new Date(last12h)) {
        alerts.push("HIGH: No content generated in 12+ hours");
      }

      // No published content in 48 hours
      if (!lastActivity.publish || new Date(lastActivity.publish) < new Date(last48h)) {
        alerts.push("CRITICAL: No published content in 48+ hours");
      }

      // High error rate
      if ((errorCount ?? 0) > 10) {
        alerts.push(`MEDIUM: ${errorCount} errors in last 24 hours`);
      }

      teamHealth[team.id] = {
        display_name: team.display_name,
        last_activity: lastActivity,
        errors_24h: errorCount ?? 0,
        published_24h: publishedCount ?? 0,
        total_published: totalPublished ?? 0,
        active_devices: activeTokens ?? 0,
        alerts,
        status: alerts.some((a) => a.startsWith("CRITICAL"))
          ? "critical"
          : alerts.length > 0
          ? "warning"
          : "healthy",
      };
    }

    // Overall system health
    const overallAlerts = Object.values(teamHealth)
      .flatMap((t) => (t as Record<string, unknown>).alerts as string[]);

    const response = {
      timestamp: now.toISOString(),
      overall_status: overallAlerts.some((a) => a.startsWith("CRITICAL"))
        ? "critical"
        : overallAlerts.length > 0
        ? "warning"
        : "healthy",
      teams: teamHealth,
      system: {
        supabase: "connected",
        environment: Deno.env.get("APNS_ENVIRONMENT") ?? "sandbox",
      },
    };

    return new Response(JSON.stringify(response, null, 2), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Health check error:", err);
    return new Response(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        overall_status: "error",
        error: String(err),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
