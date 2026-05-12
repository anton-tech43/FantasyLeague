// team-season-state/index.ts
// GoalDigger v1.1 — Read-only endpoint for the post-onboarding primer.
//
// GET /functions/v1/team-season-state?team_id=<id>
//
// Returns the most recent generated snapshot for the given team, or 404 if
// none exists yet. iOS calls this once after onboarding and renders a
// one-screen primer plus three welcome-drop one-liners.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

serve(async (req) => {
  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const url = new URL(req.url);
  const teamId = url.searchParams.get("team_id");
  if (!teamId) {
    return new Response(JSON.stringify({ error: "team_id is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Validate format: lowercase letters and underscores, matches teams.id
  // pattern (e.g., "arsenal", "man_utd"). Defensive against query mangling.
  if (!/^[a-z_]{2,32}$/.test(teamId)) {
    return new Response(JSON.stringify({ error: "Invalid team_id format" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = getSupabaseClient();
  const { data, error } = await supabase
    .from("team_season_state")
    .select("team_id, phase, summary, key_fact, welcome_lines, next_fixture, generated_at")
    .eq("team_id", teamId)
    .maybeSingle();

  if (error) {
    console.error("team-season-state read error:", error.message);
    return new Response(JSON.stringify({ error: "Read failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!data) {
    return new Response(JSON.stringify({ error: "No season state for team" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify(data), {
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "max-age=300, public",
    },
  });
});
