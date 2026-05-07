// match-watcher/index.ts
// Goal Digger — Polls API-Football every 5 min for PL fixture status,
// detects transitions to "finished", and fires the gd-matchday Claude
// Code Routine for both teams in the match.
//
// State lives in match_status_state (migration 007). On first observation
// of a fixture (no prior row), we record the state but do NOT fire the
// routine — only fire on a transition we observe firsthand. Prevents
// mass-firing on initial deploy when several matches are already FT.
//
// Schedule: every 5 min via pg_cron (see migration 008).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

const FINISHED_STATUSES = new Set(["FT", "AET", "PEN"]);
const PL_LEAGUE_ID = 39;
const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";

interface ApiFixture {
  fixture: { id: number; status: { short: string }; date: string };
  teams: { home: { id: number }; away: { id: number } };
  goals: { home: number | null; away: number | null };
}

serve(async (_req) => {
  const supabase = getSupabaseClient();

  const apiFootballKey = Deno.env.get("API_FOOTBALL_KEY");
  const routineUrl = Deno.env.get("MATCHDAY_ROUTINE_URL");
  const routineToken = Deno.env.get("MATCHDAY_ROUTINE_TOKEN");

  if (!apiFootballKey || !routineUrl || !routineToken) {
    return new Response(
      JSON.stringify({
        error: "Missing one of: API_FOOTBALL_KEY, MATCHDAY_ROUTINE_URL, MATCHDAY_ROUTINE_TOKEN",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Fetch today's PL fixtures from API-Football
  const today = new Date().toISOString().slice(0, 10);
  const apiResp = await fetch(
    `${API_FOOTBALL_BASE}/fixtures?league=${PL_LEAGUE_ID}&date=${today}`,
    { headers: { "x-apisports-key": apiFootballKey } },
  );
  const fixturesJson = await apiResp.json();
  const fixtures: ApiFixture[] = fixturesJson.response ?? [];

  // Map api_football_id → our team_id slug
  const { data: teams, error: teamsErr } = await supabase
    .from("teams")
    .select("id, api_football_id");
  if (teamsErr) {
    return new Response(
      JSON.stringify({ error: `teams query failed: ${teamsErr.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
  const teamIdMap = new Map<number, string>(
    (teams ?? []).map((t) => [t.api_football_id as number, t.id as string]),
  );

  let firesDispatched = 0;
  let firstSeen = 0;
  let stateUpdates = 0;

  for (const fx of fixtures) {
    const fixtureId = fx.fixture.id;
    const status = fx.fixture.status.short;
    const homeApiId = fx.teams.home.id;
    const awayApiId = fx.teams.away.id;
    const homeTeamId = teamIdMap.get(homeApiId);
    const awayTeamId = teamIdMap.get(awayApiId);
    const homeGoals = fx.goals.home;
    const awayGoals = fx.goals.away;
    const kickoffTime = fx.fixture.date;

    // Defensive: skip fixtures where either team isn't one of our 20.
    // Should never happen for league=39 but cheap to check.
    if (!homeTeamId || !awayTeamId) continue;

    const { data: prior } = await supabase
      .from("match_status_state")
      .select("status, fired_finished_at")
      .eq("fixture_id", fixtureId)
      .maybeSingle();

    // Only fire when we OBSERVE a transition firsthand.
    // First observation never fires (avoids mass-fire on initial deploy).
    const justFinished =
      FINISHED_STATUSES.has(status) &&
      prior !== null &&
      !prior.fired_finished_at;

    if (justFinished) {
      // Fire the routine for both teams. Each fan sees the match through their lens.
      for (const [teamId, opponent, isHome] of [
        [homeTeamId, awayTeamId, true],
        [awayTeamId, homeTeamId, false],
      ] as const) {
        const score = isHome
          ? `${homeGoals}-${awayGoals}`
          : `${awayGoals}-${homeGoals}`;
        const text = `team_id=${teamId}; fixture_id=${fixtureId}; status=finished; opponent=${opponent}; score=${score}; kickoff_time=${kickoffTime}`;

        try {
          const fireResp = await fetch(routineUrl, {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${routineToken}`,
              "anthropic-beta": "experimental-cc-routine-2026-04-01",
              "anthropic-version": "2023-06-01",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ text }),
          });
          if (fireResp.ok) {
            firesDispatched++;
            console.log(`fired routine for ${teamId}/${fixtureId}`);
          } else {
            const body = await fireResp.text().catch(() => "");
            console.error(
              `fire failed for ${teamId}/${fixtureId}: ${fireResp.status} ${body.slice(0, 200)}`,
            );
          }
        } catch (e) {
          console.error(`fire threw for ${teamId}/${fixtureId}:`, e);
        }
      }
    }

    // Upsert state. If we just fired, mark fired_finished_at so we don't re-fire.
    const { error: upsertErr } = await supabase
      .from("match_status_state")
      .upsert(
        {
          fixture_id: fixtureId,
          league_id: PL_LEAGUE_ID,
          home_team_id: homeTeamId,
          away_team_id: awayTeamId,
          status,
          home_goals: homeGoals,
          away_goals: awayGoals,
          kickoff_time: kickoffTime,
          last_checked: new Date().toISOString(),
          ...(justFinished
            ? { fired_finished_at: new Date().toISOString() }
            : {}),
        },
        { onConflict: "fixture_id" },
      );
    if (upsertErr) {
      console.warn(`state upsert failed for ${fixtureId}:`, upsertErr.message);
    } else {
      stateUpdates++;
      if (!prior) firstSeen++;
    }
  }

  return new Response(
    JSON.stringify({
      fixtures_seen: fixtures.length,
      first_seen: firstSeen,
      state_updates: stateUpdates,
      fires_dispatched: firesDispatched,
      date: today,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
