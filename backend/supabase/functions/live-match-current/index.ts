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
import { WC_LEAGUE_ID } from "../_shared/detect-consequences.ts";
import { competitionName } from "../_shared/league-helpers.ts";

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

  // Pseudo country_id from iOS meaning "whichever World Championship match is
  // live right now", independent of follows. Scope by league_id instead of
  // home/away country, earliest kickoff wins if two are somehow live at once.
  // homeTeamId/awayTeamId in the response are still real country slugs either
  // way, so the client's Country(rawValue:) decode is unaffected.
  const isWc = countryId === "world_championship";
  let stateQuery = supabase
    .from("match_status_state")
    .select("fixture_id, league_id, home_team_id, away_team_id, home_goals, away_goals, status")
    .gte("kickoff_time", windowStartIso)
    .lte("kickoff_time", windowEndIso)
    .in("status", LIVE_STATUSES);
  stateQuery = isWc
    ? stateQuery.eq("league_id", WC_LEAGUE_ID).order("kickoff_time", { ascending: true })
    : stateQuery.or(`home_team_id.eq.${countryId},away_team_id.eq.${countryId}`);
  const { data: rows, error } = await stateQuery.limit(1);

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

  // Team NAMES, not just slugs. The app's local Live Activity fallback resolved
  // a side through its compiled Country/Team enums and gave up when neither
  // matched, so a cup tie against Lincoln, or Napoli v Arsenal, started no
  // activity at all. Cup opponents live in `teams` (is_active=false, registered
  // by match-watcher on first sighting), so the name is one lookup away.
  const slugs = [r.home_team_id as string, r.away_team_id as string];
  const { data: nameRows } = await supabase
    .from("teams")
    .select("id, short_name, display_name")
    .in("id", slugs);
  const nameById = new Map(
    (nameRows ?? []).map((t) => [t.id as string, (t.short_name as string) || (t.display_name as string)]),
  );

  const snapshot = {
    fixture_id: r.fixture_id,
    home_team_id: r.home_team_id,
    away_team_id: r.away_team_id,
    home_name: nameById.get(r.home_team_id as string) ?? null,
    away_name: nameById.get(r.away_team_id as string) ?? null,
    home_goals: r.home_goals ?? 0,
    away_goals: r.away_goals ?? 0,
    status: r.status,
    // The widget renders group_label above the score. For a World Championship
    // group match match-watcher's own group logic owns it, so leave it unset;
    // for a club match the competition is the useful thing to say.
    group_label: (r.league_id as number | null) === WC_LEAGUE_ID
      ? null
      : competitionName(r.league_id as number | undefined),
    // elapsed is not tracked in match_status_state; the client decodes it as
    // optional and the status label is period-based anyway.
  };

  return new Response(JSON.stringify(snapshot), {
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
});
