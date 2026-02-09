// Goal Digger — Health Check Edge Function
// Returns real-time status of the pipeline for monitoring.
// Contract 9 (AGENT_CONTRACTS.md Section 12) defines the response format.
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

    // Contract 9 response format
    const teamsHealth: Record<string, unknown> = {};
    let anyUnhealthy = false;
    let anyDegraded = false;

    for (const team of teams) {
      // Last successful fetch timestamp
      const { data: lastFetchData } = await supabase
        .from("pipeline_health")
        .select("created_at")
        .eq("team_id", team.id)
        .eq("stage", "fetch")
        .eq("status", "success")
        .order("created_at", { ascending: false })
        .limit(1);

      const lastFetch = lastFetchData?.[0]?.created_at ?? null;

      // Last published timestamp
      const { data: lastPublishedData } = await supabase
        .from("content_items")
        .select("published_at")
        .eq("team_id", team.id)
        .eq("status", "published")
        .order("published_at", { ascending: false })
        .limit(1);

      const lastPublished = lastPublishedData?.[0]?.published_at ?? null;

      // Published today count (last 24h)
      const { count: publishedToday } = await supabase
        .from("content_items")
        .select("id", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("status", "published")
        .gte("published_at", last24h);

      // Fetch errors in last 24h
      const { count: fetchErrors24h } = await supabase
        .from("pipeline_health")
        .select("id", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("stage", "fetch")
        .eq("status", "failure")
        .gte("created_at", last24h);

      // Review rejections in last 24h
      const { count: reviewRejections24h } = await supabase
        .from("content_items")
        .select("id", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("status", "rejected")
        .gte("created_at", last24h);

      // Status logic per Contract 9:
      // - "unhealthy" if no published content for 48+ hours
      // - "degraded" if missing fetches but content published in last 24h
      // - "healthy" if fetch within 4h
      const noFetchIn4h = !lastFetch || new Date(lastFetch) < new Date(last4h);
      const noPublishIn48h = !lastPublished || new Date(lastPublished) < new Date(last48h);
      const publishedIn24h = (publishedToday ?? 0) > 0;

      if (noPublishIn48h) {
        anyUnhealthy = true;
      } else if (noFetchIn4h && publishedIn24h) {
        anyDegraded = true;
      } else if (noFetchIn4h) {
        anyDegraded = true;
      }

      teamsHealth[team.id] = {
        last_fetch: lastFetch,
        last_published: lastPublished,
        published_today: publishedToday ?? 0,
        fetch_errors_24h: fetchErrors24h ?? 0,
        review_rejections_24h: reviewRejections24h ?? 0,
      };
    }

    // External services status (basic checks based on recent pipeline health)
    const { count: recentClaudeErrors } = await supabase
      .from("pipeline_health")
      .select("id", { count: "exact", head: true })
      .in("stage", ["generate", "review"])
      .eq("status", "failure")
      .gte("created_at", last4h);

    const { count: recentFetchErrors } = await supabase
      .from("pipeline_health")
      .select("id", { count: "exact", head: true })
      .eq("stage", "fetch")
      .eq("status", "failure")
      .gte("created_at", last4h);

    const { count: recentPublishErrors } = await supabase
      .from("pipeline_health")
      .select("id", { count: "exact", head: true })
      .eq("stage", "publish")
      .eq("status", "failure")
      .gte("created_at", last4h);

    // Determine overall status per Contract 9
    const overallStatus = anyUnhealthy
      ? "unhealthy"
      : anyDegraded
      ? "degraded"
      : "healthy";

    const response = {
      status: overallStatus,
      last_check: now.toISOString(),
      teams: teamsHealth,
      external_services: {
        claude_api: (recentClaudeErrors ?? 0) > 3 ? "degraded" : "healthy",
        api_football: (recentFetchErrors ?? 0) > 3 ? "degraded" : "healthy",
        apns: (recentPublishErrors ?? 0) > 3 ? "degraded" : "healthy",
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
        status: "unhealthy",
        last_check: new Date().toISOString(),
        error: String(err),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
