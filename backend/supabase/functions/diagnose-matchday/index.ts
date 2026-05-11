// diagnose-matchday/index.ts
// One-off diagnostic endpoint to verify EVERY assumption the match-watcher
// pipeline depends on. Read-only. Returns a comprehensive health snapshot.
//
// What it checks:
//   1. API-Football reachable + season param accepted
//   2. Today's PL fixtures + their team IDs
//   3. Upcoming PL fixtures (next 7 days) + their team IDs
//   4. Full 2025-26 PL team roster from API-Football
//   5. Our `teams` table contents
//   6. Diff: teams in current PL that we DON'T have in our DB
//   7. cron.job_run_details for match-watcher-1min (last 10 runs)
//   8. match_status_state row count
//   9. MATCHDAY_ROUTINE_URL / TOKEN env presence (not value)
//
// Call: POST /functions/v1/diagnose-matchday (no body needed)
// Auth: service-role key in Authorization header

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";
const PL_LEAGUE_ID = 39;
const SEASON = 2025;

serve(async (_req) => {
  const supabase = getSupabaseClient();
  const out: Record<string, unknown> = {};

  // 0. Env vars
  const apiFootballKey = Deno.env.get("API_FOOTBALL_KEY");
  out.env_check = {
    API_FOOTBALL_KEY: apiFootballKey ? "set" : "MISSING",
    MATCHDAY_ROUTINE_URL: Deno.env.get("MATCHDAY_ROUTINE_URL") ? "set" : "MISSING",
    MATCHDAY_ROUTINE_TOKEN: Deno.env.get("MATCHDAY_ROUTINE_TOKEN") ? "set" : "MISSING",
    SUPABASE_URL: Deno.env.get("SUPABASE_URL") ? "set" : "MISSING",
    SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ? "set" : "MISSING",
  };

  if (!apiFootballKey) {
    return new Response(JSON.stringify(out, null, 2), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 1. Today's fixtures
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
  }).format(new Date());

  const todayResp = await fetch(
    `${API_FOOTBALL_BASE}/fixtures?league=${PL_LEAGUE_ID}&season=${SEASON}&date=${today}`,
    { headers: { "x-apisports-key": apiFootballKey } },
  );
  const todayJson = await todayResp.json();
  out.today = {
    date: today,
    http_status: todayResp.status,
    api_errors: todayJson.errors ?? null,
    results_count: todayJson.results ?? null,
    fixtures: (todayJson.response ?? []).map((f: any) => ({
      fixture_id: f.fixture?.id,
      status: f.fixture?.status?.short,
      kickoff: f.fixture?.date,
      league_id: f.league?.id,
      home: { id: f.teams?.home?.id, name: f.teams?.home?.name },
      away: { id: f.teams?.away?.id, name: f.teams?.away?.name },
    })),
  };

  // 2. Next 7 days fixtures
  const sevenDaysLater = new Date();
  sevenDaysLater.setDate(sevenDaysLater.getDate() + 7);
  const to = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
  }).format(sevenDaysLater);

  const weekResp = await fetch(
    `${API_FOOTBALL_BASE}/fixtures?league=${PL_LEAGUE_ID}&season=${SEASON}&from=${today}&to=${to}`,
    { headers: { "x-apisports-key": apiFootballKey } },
  );
  const weekJson = await weekResp.json();
  out.next_seven_days = {
    from: today,
    to,
    http_status: weekResp.status,
    api_errors: weekJson.errors ?? null,
    results_count: weekJson.results ?? null,
    fixtures: (weekJson.response ?? []).map((f: any) => ({
      fixture_id: f.fixture?.id,
      status: f.fixture?.status?.short,
      kickoff: f.fixture?.date,
      home: { id: f.teams?.home?.id, name: f.teams?.home?.name },
      away: { id: f.teams?.away?.id, name: f.teams?.away?.name },
    })),
  };

  // 3. Full 2025-26 PL team roster from API-Football
  const rosterResp = await fetch(
    `${API_FOOTBALL_BASE}/teams?league=${PL_LEAGUE_ID}&season=${SEASON}`,
    { headers: { "x-apisports-key": apiFootballKey } },
  );
  const rosterJson = await rosterResp.json();
  const apiRoster: { id: number; name: string }[] = (rosterJson.response ?? []).map(
    (t: any) => ({ id: t.team?.id, name: t.team?.name }),
  );
  out.pl_2025_26_roster = {
    http_status: rosterResp.status,
    api_errors: rosterJson.errors ?? null,
    count: apiRoster.length,
    teams: apiRoster,
  };

  // 4. Our teams table
  const { data: ourTeams } = await supabase
    .from("teams")
    .select("id, api_football_id")
    .order("id");
  out.our_teams_table = {
    count: (ourTeams ?? []).length,
    teams: ourTeams ?? [],
  };

  // 5. Diff: PL teams missing from our table
  const ourApiIds = new Set((ourTeams ?? []).map((t) => t.api_football_id));
  const missingFromOurDb = apiRoster.filter((t) => !ourApiIds.has(t.id));
  const extraInOurDb = (ourTeams ?? []).filter(
    (t) => !apiRoster.some((r) => r.id === t.api_football_id),
  );
  out.diff_teams = {
    pl_teams_missing_from_our_db: missingFromOurDb,
    teams_in_our_db_not_currently_in_pl: extraInOurDb,
  };

  // 6. match_status_state row count + last-N rows
  const { data: stateRows, count: stateCount } = await supabase
    .from("match_status_state")
    .select("*", { count: "exact" })
    .order("last_checked", { ascending: false })
    .limit(5);
  out.match_status_state = {
    total_rows: stateCount,
    last_5: stateRows ?? [],
  };

  // 7. cron.job_run_details for match-watcher-1min (last 10 runs)
  // Requires an RPC or raw SQL. Try RPC first.
  const { data: cronRuns, error: cronErr } = await supabase.rpc(
    "get_match_watcher_cron_runs",
  );
  out.cron_recent_runs = cronErr
    ? { error: cronErr.message, hint: "Need an RPC like get_match_watcher_cron_runs that selects from cron.job_run_details — if missing, this section is unknowable from edge function" }
    : cronRuns;

  return new Response(JSON.stringify(out, null, 2), {
    headers: { "Content-Type": "application/json" },
  });
});
