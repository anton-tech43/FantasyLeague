// live-match-current/index.ts
// GoalDigger v2.1 — Read endpoint for the Live Activity foreground-start
// fallback (Lesson 99).
//
// GET /functions/v1/live-match-current?country_id=<id>
//
// Returns the current in-play WC match for the user's country (from
// match_status_state) so the app can start a Live Activity locally when
// push-to-start hasn't fired (older OS / first run). Mirrors
// live-brief-current's envelope: 204 No Content when nothing is live.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

const PRE_KICKOFF_BUFFER_MS = 10 * 60 * 1000;   // 10 min before kickoff
const POST_KICKOFF_BUFFER_MS = 130 * 60 * 1000; // 130 min after kickoff
const LIVE_STATUSES = ["1H", "HT", "2H", "ET", "P", "BT"];

serve(async (req) => {
  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const countryId = new URL(req.url).searchParams.get("country_id");
  if (!countryId) {
    return new Response(JSON.stringify({ error: "country_id is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  // teams.id is always lowercase letters + underscores. Guards the .or() below.
  if (!/^[a-z_]{2,32}$/.test(countryId)) {
    return new Response(JSON.stringify({ error: "Invalid country_id format" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = getSupabaseClient();
  const now = Date.now();
  const windowStartIso = new Date(now - POST_KICKOFF_BUFFER_MS).toISOString();
  const windowEndIso = new Date(now + PRE_KICKOFF_BUFFER_MS).toISOString();

  const { data: rows, error } = await supabase
    .from("match_status_state")
    .select("fixture_id, home_team_id, away_team_id, home_goals, away_goals, status")
    .or(`home_team_id.eq.${countryId},away_team_id.eq.${countryId}`)
    .gte("kickoff_time", windowStartIso)
    .lte("kickoff_time", windowEndIso)
    .in("status", LIVE_STATUSES)
    .limit(1);

  if (error) {
    console.error("live-match-current read error:", error.message);
    return new Response(JSON.stringify({ error: "State read failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!rows || rows.length === 0) {
    return new Response(null, { status: 204 }); // nothing live — expected
  }

  const r = rows[0];
  const snapshot = {
    fixture_id: r.fixture_id,
    home_team_id: r.home_team_id,
    away_team_id: r.away_team_id,
    home_goals: r.home_goals ?? 0,
    away_goals: r.away_goals ?? 0,
    status: r.status,
    // elapsed + group_label are not tracked in match_status_state; the client
    // decodes them as optional and the status label is period-based anyway.
  };

  return new Response(JSON.stringify(snapshot), {
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
});
