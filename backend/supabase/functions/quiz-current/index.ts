// quiz-current/index.ts
// GoalDigger v1.1 — Read endpoint for the SaturdayQuizCard (V1.1 task C3).
//
// GET /functions/v1/quiz-current?team_id=<id>
//
// Returns the freshest saturday_quiz_items row for the team if it was
// published within the last 36 hours (Saturday 07:00 UTC through Sunday
// 19:00 UTC). Outside that window, returns 204 No Content so iOS hides
// the card cleanly. Pattern lifted from live-brief-current — same
// envelope so the iOS APIClient method is symmetric.
//
// Not polled: iOS fetches once on view load and on team change (the feed
// .task(id:) re-fires on team switch). The quiz is set-and-forget for the
// weekend.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

// 36-hour freshness window. Routine fires Saturday 07:00 UTC, so:
//   Sat 07:00 UTC publish → visible through Sun 19:00 UTC
// The window deliberately straddles a weekend, not a calendar day, so the
// card disappears Monday morning before the work week starts.
const FRESHNESS_WINDOW_MS = 36 * 60 * 60 * 1000;

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

  // Defensive format check — teams.id is always lowercase letters +
  // underscores. Same regex as team-season-state / live-brief-current.
  if (!/^[a-z_]{2,32}$/.test(teamId)) {
    return new Response(JSON.stringify({ error: "Invalid team_id format" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = getSupabaseClient();

  const freshThresholdIso = new Date(Date.now() - FRESHNESS_WINDOW_MS).toISOString();

  const { data: rows, error } = await supabase
    .from("saturday_quiz_items")
    .select("id, team_id, match_id, headline, questions, share_template, published_at")
    .eq("team_id", teamId)
    .gte("published_at", freshThresholdIso)
    .order("published_at", { ascending: false })
    .limit(1);

  if (error) {
    console.error("quiz-current read error:", error.message);
    return new Response(JSON.stringify({ error: "Read failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!rows || rows.length === 0) {
    // No quiz in the freshness window. 204 = "nothing right now, expected."
    // iOS hides the card. Avoids a 404 which iOS might confuse with a real
    // not-found error.
    return new Response(null, { status: 204 });
  }

  return new Response(JSON.stringify(rows[0]), {
    headers: {
      "Content-Type": "application/json",
      // No Cache-Control: the read is cheap (one indexed lookup) and a
      // mid-Saturday re-publish should reach the user immediately.
      "Cache-Control": "no-store",
    },
  });
});
