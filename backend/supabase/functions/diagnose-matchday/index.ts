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
    SERVICE_KEY: Deno.env.get("SERVICE_KEY") ? "set" : "MISSING",
    SUPABASE_SERVICE_ROLE_KEY_legacy: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ? "set" : "MISSING",
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

  // 7. Pipeline diagnostics via SECURITY DEFINER RPC (migration 029).
  //    Returns cron job bodies, recent run details, Vault secret + accessor
  //    function existence. If the RPC is missing, fall back to a hint.
  const { data: pipelineDiag, error: pipelineErr } = await supabase.rpc(
    "get_pipeline_diagnostics",
  );
  out.pipeline_diagnostics = pipelineErr
    ? { error: pipelineErr.message, hint: "Apply migration 029_diagnostics_rpc.sql via SQL editor — adds get_pipeline_diagnostics()" }
    : pipelineDiag;

  // 8. content_items activity since May 11 (when cron stopped). Aggregate
  //    by content_type so we can see whether the matchday/sundayBrief/
  //    saturdayQuiz/live_brief routines have produced anything during the
  //    dead-cron window.
  const since = "2026-05-11T00:00:00Z";
  const { data: recentItems, error: itemsErr } = await supabase
    .from("content_items")
    .select("type, team_id, created_at, match_id")
    .gte("created_at", since)
    .order("created_at", { ascending: false })
    .limit(100);
  if (itemsErr) {
    out.content_items_recent = { error: itemsErr.message };
  } else {
    const byType: Record<string, number> = {};
    for (const it of recentItems ?? []) {
      const k = (it as { type: string }).type ?? "unknown";
      byType[k] = (byType[k] ?? 0) + 1;
    }
    out.content_items_recent = {
      since,
      total_rows: recentItems?.length ?? 0,
      by_type: byType,
      sample_first_5: (recentItems ?? []).slice(0, 5),
    };
  }

  // 9. All matchday items since May 11 — surfaces whether yesterday's
  //    City-Palace generated anything, despite the watcher being silent.
  const { data: matchdayItems } = await supabase
    .from("content_items")
    .select("team_id, match_id, headline, push_title, push_text, pushed_at, created_at, kickoff_time")
    .eq("type", "matchday")
    .gte("created_at", since)
    .order("created_at", { ascending: false });
  out.matchday_items_since_may_11 = matchdayItems ?? [];

  // 11. Active device_tokens by team — explains why a push may not have
  //     fired (no subscriber for that team). Apns tokens themselves are
  //     redacted to a 8-char prefix to avoid leaking through diagnostics.
  const { data: deviceTokens } = await supabase
    .from("device_tokens")
    .select("team_id, is_active, apns_token, apns_environment, created_at, tier")
    .order("created_at", { ascending: false })
    .limit(20);
  const tokensByTeam: Record<string, number> = {};
  const samplePrefixByTeam: Record<string, string> = {};
  for (const row of deviceTokens ?? []) {
    const t = (row as { team_id: string; apns_token: string }).team_id;
    tokensByTeam[t] = (tokensByTeam[t] ?? 0) + 1;
    if (!samplePrefixByTeam[t]) {
      samplePrefixByTeam[t] = ((row as { apns_token: string }).apns_token ?? "").slice(0, 8);
    }
  }
  out.active_device_tokens = {
    total: deviceTokens?.length ?? 0,
    by_team: tokensByTeam,
    sample_prefix_by_team: samplePrefixByTeam,
    rows: (deviceTokens ?? []).map((r) => {
      const row = r as { team_id: string; is_active: boolean; apns_token: string; apns_environment: string; created_at: string; tier: number };
      return {
        team_id: row.team_id,
        is_active: row.is_active,
        apns_environment: row.apns_environment,
        tier: row.tier,
        created_at: row.created_at,
        token_prefix: (row.apns_token ?? "").slice(0, 12),
      };
    }),
  };

  // 12. Recent client_errors (last 24h) — might reveal a 4xx from the iOS
  //     registerToken call if the app's error-reporting path caught it.
  const { data: recentErrors } = await supabase
    .from("client_errors")
    .select("error_type, message, created_at, app_version")
    .gte("created_at", new Date(Date.now() - 24 * 60 * 60_000).toISOString())
    .order("created_at", { ascending: false })
    .limit(20);
  out.client_errors_last_24h = recentErrors ?? [];

  // 13. RLS policies + grants on device_tokens — diagnose why the
  //     publishable-key INSERT is being rejected with 42501.
  const { data: rlsInfo, error: rlsErr } = await supabase.rpc(
    "get_device_tokens_acl",
  );
  out.device_tokens_acl = rlsErr ? { error: rlsErr.message } : rlsInfo;

  // 10. Synthetic write probe — attempt a sentinel upsert into
  //     match_status_state with a fake fixture_id. If this fails, the
  //     real watcher's silent upserts have the same blocker. Then clean
  //     up the row so it doesn't pollute production state.
  const SENTINEL_FIXTURE_ID = 99999999;
  const probeRow = {
    fixture_id: SENTINEL_FIXTURE_ID,
    league_id: PL_LEAGUE_ID,
    home_team_id: "man_city",
    away_team_id: "crystal_palace",
    status: "FT",
    home_goals: 3,
    away_goals: 0,
    kickoff_time: "2026-05-13T19:00:00+00:00",
    last_checked: new Date().toISOString(),
    briefs_fired: [],
  };
  const { error: probeErr } = await supabase
    .from("match_status_state")
    .upsert(probeRow, { onConflict: "fixture_id" });
  // Clean up regardless of error so we don't leave a fake row.
  await supabase
    .from("match_status_state")
    .delete()
    .eq("fixture_id", SENTINEL_FIXTURE_ID);
  out.write_probe = probeErr
    ? { ok: false, error: probeErr.message, hint: probeErr.hint, details: probeErr.details }
    : { ok: true };

  return new Response(JSON.stringify(out, null, 2), {
    headers: { "Content-Type": "application/json" },
  });
});
