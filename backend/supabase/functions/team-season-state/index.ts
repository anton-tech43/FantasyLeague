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
    // state_line + feeling_line are the current shape of this surface;
    // SeasonPrimerView renders those two and falls back only when they are nil.
    // They were added to the table and to the routine, and the select was never
    // updated — so the endpoint kept serving the deprecated `summary`, which no
    // routine has written since the migration. On 2026-09-07 that meant Arsenal
    // was still described as "top of the Premier League with 79 points from 36
    // games" in September. The write side moved; the read side did not.
    .select(
      "team_id, phase, state_line, feeling_line, next_fixtures, " +
        "summary, key_fact, welcome_lines, next_fixture, generated_at",
    )
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

  // next_fixtures is another field the migration left behind: the routine stopped
  // writing it, so the column still holds whatever was there in May. Offering
  // her a calendar sync for a fixture that was played four months ago is worse
  // than offering none, so drop anything already in the past. The live list
  // lives in team_pages.upcoming_fixtures, which refreshes every two hours.
  const payload = { ...(data as unknown as Record<string, unknown>) };
  if (Array.isArray(payload.next_fixtures)) {
    const now = Date.now();
    const future = (payload.next_fixtures as Array<Record<string, unknown>>).filter((f) => {
      const t = Date.parse(String(f?.kickoff_time ?? ""));
      return !Number.isNaN(t) && t > now;
    });
    payload.next_fixtures = future.length > 0 ? future : null;
  }

  return new Response(JSON.stringify(payload), {
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "max-age=300, public",
    },
  });
});
