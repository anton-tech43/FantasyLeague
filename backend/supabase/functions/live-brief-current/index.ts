// live-brief-current/index.ts
// GoalDigger v1.1 — Read endpoint for the LiveMatchCard (V1.1 task C5).
//
// GET /functions/v1/live-brief-current?team_id=<id>
//
// Returns the most recent live_match_briefs row for the given team IF the
// team has a match currently in the "live window" — defined as kickoff
// minus 10 minutes through kickoff plus 130 minutes (2h 10m, covers full
// time + extra time + a healthy buffer).
//
// Returns 204 No Content (with no body) when there's no live match in the
// window. This lets iOS distinguish "no fetch error, just no live card"
// from real failures without parsing a body. Polled every 60s during the
// live window.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

const PRE_KICKOFF_BUFFER_MS = 10 * 60 * 1000;   // 10 min before kickoff
const POST_KICKOFF_BUFFER_MS = 130 * 60 * 1000; // 130 min after kickoff

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

  // Validate format: same regex as team-season-state. Defensive against
  // query mangling — teams.id is always lowercase letters + underscores.
  if (!/^[a-z_]{2,32}$/.test(teamId)) {
    return new Response(JSON.stringify({ error: "Invalid team_id format" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = getSupabaseClient();

  // 1. Is there a fixture for this team that's actually IN PLAY?
  // Two filters compose: (a) status must be a live in-play state and
  // (b) kickoff is within a sane window. Status alone is the stronger
  // signal — a FT/AET/PEN match shouldn't trigger the card even if it
  // ended within the window. Kickoff window is a defensive backstop in
  // case the match-watcher fails to update status promptly.
  //
  // LIVE_STATUSES = ['1H', 'HT', '2H', 'ET', 'P', 'BT'] — same set the
  // match-watcher uses to detect live fixtures. Mirroring it keeps the
  // two pieces of code in sync.
  const LIVE_STATUSES = ["1H", "HT", "2H", "ET", "P", "BT"];
  const now = Date.now();
  const windowStartIso = new Date(now - POST_KICKOFF_BUFFER_MS).toISOString();
  const windowEndIso = new Date(now + PRE_KICKOFF_BUFFER_MS).toISOString();

  const { data: stateRows, error: stateErr } = await supabase
    .from("match_status_state")
    .select("fixture_id, status, home_team_id, away_team_id, home_goals, away_goals")
    .or(`home_team_id.eq.${teamId},away_team_id.eq.${teamId}`)
    .gte("kickoff_time", windowStartIso)
    .lte("kickoff_time", windowEndIso)
    .in("status", LIVE_STATUSES)
    .limit(1);

  if (stateErr) {
    console.error("live-brief-current state read error:", stateErr.message);
    return new Response(JSON.stringify({ error: "State read failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!stateRows || stateRows.length === 0) {
    // No fixture in the live window. 204 = "nothing right now, this is
    // expected." iOS interprets this as "skip the LiveMatchCard." Avoids
    // a 404 which iOS might confuse with a real not-found error.
    return new Response(null, { status: 204 });
  }

  // 2. Fetch the most recent brief for this team. Could constrain by
  // match_id from stateRows[0].fixture_id, but if a stale brief from an
  // older match leaks in, the published_at filter below catches it.
  const { data: briefs, error: briefErr } = await supabase
    .from("live_match_briefs")
    .select("id, team_id, match_id, headline, body, minute, trigger_label, generated_at")
    .eq("team_id", teamId)
    .gte("generated_at", new Date(now - POST_KICKOFF_BUFFER_MS).toISOString())
    .order("generated_at", { ascending: false })
    .limit(1);

  if (briefErr) {
    console.error("live-brief-current briefs read error:", briefErr.message);
    return new Response(JSON.stringify({ error: "Briefs read failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const headers = {
    "Content-Type": "application/json",
    // No CDN caching: polled endpoint, want fresh values every 60s.
    "Cache-Control": "no-store",
  };

  // Routine brief present → return it (the richer half-time analysis).
  if (briefs && briefs.length > 0) {
    return new Response(JSON.stringify(briefs[0]), { headers });
  }

  // No routine brief yet — match just kicked off and HT hasn't landed, or the
  // gd-live-brief routine is late / rate-limited. Synthesize a DETERMINISTIC
  // live-score card from match_status_state so the feed shows a live card from
  // kickoff, independent of the claude.ai routine (same deterministic-floor
  // principle as the pushes). The richer brief replaces this the moment it lands.
  const synth = await synthesizeLiveCard(supabase, teamId, stateRows[0] as MatchState, now);
  return new Response(JSON.stringify(synth), { headers });
});

interface MatchState {
  fixture_id: number;
  status: string;
  home_team_id: string;
  away_team_id: string;
  home_goals: number | null;
  away_goals: number | null;
}

/// Build a LiveMatchBrief-shaped object from the live score alone (no Claude).
/// Headline is the follower-first scoreline; body is a short period line. The
/// id is STABLE per (fixture, score, status) so the card only re-animates when
/// something actually changes, not on every 60s poll.
async function synthesizeLiveCard(
  supabase: ReturnType<typeof getSupabaseClient>,
  teamId: string,
  state: MatchState,
  nowMs: number,
): Promise<Record<string, unknown>> {
  const { data: teamRows } = await supabase
    .from("teams")
    .select("id, short_name, display_name")
    .in("id", [state.home_team_id, state.away_team_id]);
  const nameOf = (id: string): string => {
    const r = (teamRows ?? []).find((t) => t.id === id) as
      | { short_name?: string; display_name?: string }
      | undefined;
    return (r?.short_name && r.short_name.length > 0 ? r.short_name : r?.display_name) || id;
  };

  const hg = state.home_goals ?? 0;
  const ag = state.away_goals ?? 0;
  const isHome = state.home_team_id === teamId;
  const myName = nameOf(teamId);
  const oppName = nameOf(isHome ? state.away_team_id : state.home_team_id);
  const myGoals = isHome ? hg : ag;
  const oppGoals = isHome ? ag : hg;

  return {
    id: await stableUuid(`${state.fixture_id}-${hg}-${ag}-${state.status}`),
    team_id: teamId,
    match_id: String(state.fixture_id),
    headline: `${myName} ${myGoals}-${oppGoals} ${oppName}`,
    body: periodLine(state.status),
    minute: null,
    // null → the card shows a "LIVE" badge; "HT" → "HALF TIME".
    trigger_label: state.status === "HT" ? "HT" : null,
    generated_at: new Date(nowMs).toISOString(),
  };
}

function periodLine(status: string): string {
  switch (status) {
    case "1H": return "First half under way.";
    case "HT": return "Half-time.";
    case "2H": return "Second half under way.";
    case "ET": return "Extra time.";
    case "P": return "Penalty shootout.";
    case "BT": return "Break before extra time.";
    default: return "Live now.";
  }
}

/// Deterministic UUID (SHA-256 of the key, first 16 bytes in UUID format).
/// Swift's UUID parser accepts it; it does not validate version/variant bits.
async function stableUuid(key: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(key)),
  );
  const h = [...digest.slice(0, 16)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}
