// matchday-scheduler/index.ts
// Goal Digger — Daily 07:00 UTC, checks API-Football for today's fixtures
// Schedules content generation at kickoff - 90 minutes for each matched team

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { triggerFunction } from "../_shared/trigger.ts";
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";
import { seasonForLeague, FALLBACK_ACTIVE_LEAGUES } from "../_shared/league-helpers.ts";

const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";
const SEND_LEAD_TIME_MS = 90 * 60 * 1000; // 90 minutes before kickoff

interface Fixture {
  fixture: {
    id: number;
    date: string;
    status: { short: string };
  };
  teams: {
    home: { id: number; name: string };
    away: { id: number; name: string };
  };
  league: {
    id: number;
  };
}

serve(async (req) => {
  // Caller-auth gate (see _shared/require-service-auth.ts). Server-only
  // function — rejects anon-key / no-auth callers; accepts the service
  // key that triggerFunction + pg_cron present.
  const denied = requireServiceAuth(req);
  if (denied) return denied;
  const startTime = Date.now();
  const supabase = getSupabaseClient();

  try {
    const apiKey = Deno.env.get("API_FOOTBALL_KEY");
    if (!apiKey) throw new Error("Missing API_FOOTBALL_KEY");

    // Get our teams
    const { data: teams } = await supabase.from("teams").select("*");
    if (!teams) throw new Error("No teams found");

    const teamMap = new Map(teams.map((t) => [t.api_football_id, t]));

    // Get today's date in YYYY-MM-DD format
    const today = new Date().toISOString().split("T")[0];

    // V2.0: iterate over active leagues (PL + WC + future). Read from
    // teams.league_id distinct values, fall back to the hardcoded list
    // if the query fails.
    const { data: leagueRows } = await supabase
      .from("teams")
      .select("league_id")
      .not("league_id", "is", null);
    const activeLeagues: number[] = leagueRows
      ? [...new Set(leagueRows.map((r) => r.league_id as number))]
      : FALLBACK_ACTIVE_LEAGUES;

    // Fetch today's fixtures across all active leagues
    const fixtures: Fixture[] = [];
    for (const leagueId of activeLeagues) {
      const season = seasonForLeague(leagueId);
      try {
        const response = await fetch(
          `${API_FOOTBALL_BASE}/fixtures?league=${leagueId}&season=${season}&from=${today}&to=${today}`,
          {
            headers: {
              "x-rapidapi-key": apiKey,
              "x-rapidapi-host": "v3.football.api-sports.io",
            },
          }
        );
        if (!response.ok) {
          console.warn(`matchday-scheduler league=${leagueId} returned ${response.status}`);
          continue;
        }
        const data = await response.json();
        fixtures.push(...((data.response as Fixture[]) ?? []));
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        console.warn(`matchday-scheduler league=${leagueId} fetch failed:`, msg);
      }
    }

    let scheduledCount = 0;

    for (const fixture of fixtures) {
      // V2.0: only fixtures whose league is in our active set. The fetch
      // already filters by league, but defence-in-depth (API-Football
      // occasionally returns related leagues e.g. a WC qualifier under
      // the main WC query).
      if (!activeLeagues.includes(fixture.league.id)) continue;

      // Check if either team is one of ours
      const homeTeam = teamMap.get(fixture.teams.home.id);
      const awayTeam = teamMap.get(fixture.teams.away.id);
      const ourTeam = homeTeam ?? awayTeam;

      if (!ourTeam) continue;

      // SCHED-1: gd-matchday (what content-generator fires) produces nothing for
      // WC country entities — match-watcher skips them for the same reason. Don't
      // schedule a content-generator run that would be wasted (or, if it reached
      // a callClaude path, billed). PL clubs only; countries get the deterministic
      // matchday-reminder + match-watcher FT result instead.
      if ((ourTeam as { entity_type?: string }).entity_type === "country") continue;

      const opponent = homeTeam
        ? fixture.teams.away.name
        : fixture.teams.home.name;

      const kickoffTime = new Date(fixture.fixture.date);
      const sendTime = new Date(kickoffTime.getTime() - SEND_LEAD_TIME_MS);
      const now = new Date();

      // Skip if match has already started or finished
      const matchStatus = fixture.fixture.status.short;
      if (["1H", "HT", "2H", "ET", "P", "FT", "AET", "PEN"].includes(matchStatus)) {
        continue;
      }

      if (sendTime > now) {
        // Future send — schedule via pg_cron one-off job
        const minute = sendTime.getUTCMinutes();
        const hour = sendTime.getUTCHours();
        const day = sendTime.getUTCDate();
        const month = sendTime.getUTCMonth() + 1;
        const cronExpr = `${minute} ${hour} ${day} ${month} *`;
        const jobName = `matchday-${ourTeam.id}-${today}`;

        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        // SERVICE_KEY = new-model sb_secret_*; legacy JWT as transition fallback.
        const serviceKey =
          Deno.env.get("SERVICE_KEY") ??
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

        // Create one-off pg_cron job
        const { error: cronError } = await supabase.rpc("schedule_matchday_job", {
          job_name: jobName,
          cron_expression: cronExpr,
          function_url: `${supabaseUrl}/functions/v1/content-generator`,
          service_key: serviceKey,
          payload: JSON.stringify({
            team_id: ourTeam.id,
            trigger: "matchday",
            fixture_id: String(fixture.fixture.id),
            kickoff_time: kickoffTime.toISOString(),
            opponent,
          }),
        });

        if (cronError) {
          // Fallback: trigger immediately if cron scheduling fails
          console.warn(`pg_cron scheduling failed for ${jobName}, triggering immediately:`, cronError);
          await triggerFunction("content-generator", {
            team_id: ourTeam.id,
            trigger: "matchday",
            fixture_id: String(fixture.fixture.id),
            kickoff_time: kickoffTime.toISOString(),
            opponent,
          });
        }

        scheduledCount++;
      } else {
        // Send time has passed — trigger immediately
        await triggerFunction("content-generator", {
          team_id: ourTeam.id,
          trigger: "matchday",
          fixture_id: String(fixture.fixture.id),
          kickoff_time: kickoffTime.toISOString(),
          opponent,
        });
        scheduledCount++;
      }

      await logPipelineEvent(supabase, {
        team_id: ourTeam.id,
        stage: "generate",
        status: "success",
        duration_ms: Date.now() - startTime,
        message: `Matchday scheduled: ${ourTeam.display_name} vs ${opponent}, kickoff ${kickoffTime.toISOString()}`,
        content_item_id: null,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        date: today,
        fixtures_found: fixtures.length,
        scheduled: scheduledCount,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("matchday-scheduler error:", message);

    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
