// health-check/index.ts
// Goal Digger — GET endpoint returning system health JSON (Contract 9)
// Status: healthy / degraded / unhealthy based on pipeline activity

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

interface TeamHealth {
  last_fetch: string | null;
  last_published: string | null;
  published_today: number;
  fetch_errors_24h: number;
  review_rejections_24h: number;
}

serve(async (_req) => {
  const supabase = getSupabaseClient();

  try {
    const { data: teams } = await supabase.from("teams").select("id, display_name");
    if (!teams) throw new Error("No teams found");

    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
    const fourHoursAgo = new Date(now.getTime() - 4 * 60 * 60 * 1000).toISOString();
    const twoDaysAgo = new Date(now.getTime() - 48 * 60 * 60 * 1000).toISOString();

    const teamHealthMap: Record<string, TeamHealth> = {};
    let allHealthy = true;
    let anyUnhealthy = false;

    for (const team of teams) {
      // Last successful fetch
      const { data: lastFetch } = await supabase
        .from("pipeline_health")
        .select("created_at")
        .eq("team_id", team.id)
        .eq("stage", "fetch")
        .eq("status", "success")
        .order("created_at", { ascending: false })
        .limit(1);

      // Last published content
      const { data: lastPublished } = await supabase
        .from("content_items")
        .select("published_at")
        .eq("team_id", team.id)
        .eq("status", "published")
        .order("published_at", { ascending: false })
        .limit(1);

      // Published today count
      const { count: publishedToday } = await supabase
        .from("content_items")
        .select("*", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("status", "published")
        .gte("published_at", oneDayAgo);

      // Fetch errors in last 24h
      const { count: fetchErrors } = await supabase
        .from("pipeline_health")
        .select("*", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("stage", "fetch")
        .eq("status", "failure")
        .gte("created_at", oneDayAgo);

      // Review rejections in last 24h
      const { count: rejections } = await supabase
        .from("content_items")
        .select("*", { count: "exact", head: true })
        .eq("team_id", team.id)
        .eq("status", "rejected")
        .gte("created_at", oneDayAgo);

      const lastFetchTime = lastFetch?.[0]?.created_at ?? null;
      const lastPublishTime = lastPublished?.[0]?.published_at ?? null;

      // Check health conditions
      if (!lastFetchTime || lastFetchTime < fourHoursAgo) {
        allHealthy = false;
      }
      if (!lastPublishTime || lastPublishTime < twoDaysAgo) {
        anyUnhealthy = true;
      }

      teamHealthMap[team.id] = {
        last_fetch: lastFetchTime,
        last_published: lastPublishTime,
        published_today: publishedToday ?? 0,
        fetch_errors_24h: fetchErrors ?? 0,
        review_rejections_24h: rejections ?? 0,
      };
    }

    // Determine overall status
    let status: "healthy" | "degraded" | "unhealthy";
    if (anyUnhealthy) {
      status = "unhealthy";
    } else if (!allHealthy) {
      status = "degraded";
    } else {
      status = "healthy";
    }

    // Check external services (basic connectivity)
    const externalServices: Record<string, unknown> = {
      claude_api: "unknown",
      api_football: "unknown",
      apns: "unknown",
      rss_feeds: { healthy: 0, failing: 0, failing_feeds: [] as string[] },
    };

    // Check recent pipeline health for external service indicators
    const { data: recentHealth } = await supabase
      .from("pipeline_health")
      .select("stage, status, message")
      .gte("created_at", fourHoursAgo)
      .order("created_at", { ascending: false })
      .limit(50);

    if (recentHealth) {
      const fetchResults = recentHealth.filter((h) => h.stage === "fetch");
      const genResults = recentHealth.filter((h) => h.stage === "generate");
      const pubResults = recentHealth.filter((h) => h.stage === "publish");

      externalServices.api_football =
        fetchResults.some((r) => r.status === "success") ? "healthy" : "unknown";
      externalServices.claude_api =
        genResults.some((r) => r.status === "success") ? "healthy" : "unknown";
      externalServices.apns =
        pubResults.some((r) => r.status === "success") ? "healthy" : "unknown";
    }

    const response = {
      status,
      last_check: now.toISOString(),
      teams: teamHealthMap,
      external_services: externalServices,
    };

    return new Response(JSON.stringify(response, null, 2), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ status: "error", message: e instanceof Error ? e.message : String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
