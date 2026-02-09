// Goal Digger — Matchday Scheduler Edge Function
// Runs daily at 07:00 UTC via pg_cron. Checks API-Football for today's
// fixtures involving our 3 teams, then schedules content generation
// 90 minutes before each kickoff. See BUILD_PLAN.md Step 1.4.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Team {
  id: string;
  display_name: string;
  api_football_id: number;
  short_name: string;
}

interface Fixture {
  fixture: {
    id: number;
    date: string; // ISO 8601 UTC
    status: { short: string };
    venue: { name: string };
    referee: string | null;
  };
  league: { id: number; name: string };
  teams: {
    home: { id: number; name: string };
    away: { id: number; name: string };
  };
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";
const PREMIER_LEAGUE_ID = 39;
const CURRENT_SEASON = 2025;
const MINUTES_BEFORE_KICKOFF = 90;
// Quiet hours: notifications only between 08:00 and 22:00 UTC
const EARLIEST_SEND_HOUR = 8;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/** Format a Date to YYYY-MM-DD for API-Football. */
function formatDate(date: Date): string {
  return date.toISOString().split("T")[0];
}

/** Fetch today's Premier League fixtures from API-Football. */
async function fetchTodaysFixtures(apiKey: string): Promise<Fixture[]> {
  const today = formatDate(new Date());
  const url = `${API_FOOTBALL_BASE}/fixtures?league=${PREMIER_LEAGUE_ID}&season=${CURRENT_SEASON}&from=${today}&to=${today}`;

  const res = await fetch(url, {
    headers: {
      "x-rapidapi-key": apiKey,
      "x-rapidapi-host": "v3.football.api-sports.io",
    },
  });

  if (!res.ok) {
    throw new Error(`API-Football returned ${res.status}: ${await res.text()}`);
  }

  const json = await res.json();
  return json.response ?? [];
}

/** Find which of our teams are playing in today's fixtures. */
function matchTeamsToFixtures(
  fixtures: Fixture[],
  teams: Team[],
): Array<{ team: Team; fixture: Fixture; isHome: boolean }> {
  const results: Array<{ team: Team; fixture: Fixture; isHome: boolean }> = [];

  for (const team of teams) {
    for (const fixture of fixtures) {
      if (fixture.teams.home.id === team.api_football_id) {
        results.push({ team, fixture, isHome: true });
      } else if (fixture.teams.away.id === team.api_football_id) {
        results.push({ team, fixture, isHome: false });
      }
    }
  }

  return results;
}

/** Calculate the send time: 90 min before kickoff, but not before 08:00 UTC. */
function calculateSendTime(kickoffTime: Date): Date {
  const sendTime = new Date(kickoffTime.getTime() - MINUTES_BEFORE_KICKOFF * 60 * 1000);

  // If send time falls before quiet hours start, push to 08:00 UTC
  if (sendTime.getUTCHours() < EARLIEST_SEND_HOUR) {
    sendTime.setUTCHours(EARLIEST_SEND_HOUR, 0, 0, 0);
  }

  return sendTime;
}

/** Trigger content generator for matchday content. */
async function triggerMatchdayGenerator(
  teamId: string,
  fixture: Fixture,
  isHome: boolean,
) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const opponentName = isHome
    ? fixture.teams.away.name
    : fixture.teams.home.name;

  await fetch(`${supabaseUrl}/functions/v1/content-generator`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      team_id: teamId,
      type: "matchday",
      fixture_data: {
        fixture_id: String(fixture.fixture.id),
        kickoff_time: fixture.fixture.date,
        venue: fixture.fixture.venue?.name ?? "TBD",
        referee: fixture.fixture.referee ?? "TBD",
        competition: fixture.league.name,
        opponent_name: opponentName,
        is_home: isHome,
        home_team: fixture.teams.home.name,
        away_team: fixture.teams.away.name,
      },
    }),
  });
}

/** Check if a match is already started or finished. */
function isMatchInProgress(fixture: Fixture): boolean {
  const activeStatuses = ["1H", "HT", "2H", "ET", "P", "FT", "AET", "PEN"];
  return activeStatuses.includes(fixture.fixture.status.short);
}

/** Log pipeline health. */
async function logHealth(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
  status: string,
  durationMs: number,
  message: string,
) {
  await supabase.from("pipeline_health").insert({
    team_id: teamId,
    stage: "generate",
    status,
    duration_ms: durationMs,
    message: `[matchday-scheduler] ${message}`,
  });
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async () => {
  try {
    const supabase = getSupabaseClient();
    const rapidApiKey = Deno.env.get("RAPIDAPI_KEY");

    if (!rapidApiKey) {
      return new Response(
        JSON.stringify({ error: "RAPIDAPI_KEY not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // Get all teams
    const { data: teams, error: teamsErr } = await supabase
      .from("teams")
      .select("*");

    if (teamsErr || !teams) {
      return new Response(
        JSON.stringify({ error: "Failed to load teams" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // Fetch today's PL fixtures
    const fixtures = await fetchTodaysFixtures(rapidApiKey);

    if (fixtures.length === 0) {
      return new Response(
        JSON.stringify({ matchday: false, reason: "No Premier League fixtures today" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Match our teams to today's fixtures
    const matches = matchTeamsToFixtures(fixtures, teams as Team[]);

    if (matches.length === 0) {
      return new Response(
        JSON.stringify({ matchday: false, reason: "None of our 3 teams play today" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const now = new Date();
    const results: Record<string, unknown> = {};

    for (const match of matches) {
      const startTime = Date.now();
      const kickoffTime = new Date(match.fixture.fixture.date);
      const sendTime = calculateSendTime(kickoffTime);

      // Skip if match already started/finished
      if (isMatchInProgress(match.fixture)) {
        results[match.team.id] = {
          status: "skipped",
          reason: "Match already in progress or finished",
        };
        await logHealth(
          supabase,
          match.team.id,
          "skipped",
          Date.now() - startTime,
          `Match already in progress (status: ${match.fixture.fixture.status.short})`,
        );
        continue;
      }

      // Check: is send time in the past?
      if (sendTime <= now) {
        // Send immediately — the 07:00 run caught a match with send time already passed
        console.log(`${match.team.id}: Send time already passed, triggering immediately`);
        try {
          await triggerMatchdayGenerator(
            match.team.id,
            match.fixture,
            match.isHome,
          );
          results[match.team.id] = {
            status: "triggered_immediately",
            kickoff: kickoffTime.toISOString(),
            send_time: "now",
          };
          await logHealth(
            supabase,
            match.team.id,
            "success",
            Date.now() - startTime,
            `Triggered matchday content immediately (kickoff: ${kickoffTime.toISOString()})`,
          );
        } catch (err) {
          console.error(`Failed to trigger matchday for ${match.team.id}:`, err);
          results[match.team.id] = { status: "error", error: String(err) };
          await logHealth(
            supabase,
            match.team.id,
            "failure",
            Date.now() - startTime,
            `Failed to trigger matchday content: ${err}`,
          );
        }
      } else {
        // Schedule for later using pg_cron one-off job
        const cronMinute = sendTime.getUTCMinutes();
        const cronHour = sendTime.getUTCHours();
        const cronDay = sendTime.getUTCDate();
        const cronMonth = sendTime.getUTCMonth() + 1;
        const jobName = `matchday-${match.team.id}-${formatDate(now)}`;

        // Create one-off cron job to trigger content generation at send time
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

        const opponentName = match.isHome
          ? match.fixture.teams.away.name
          : match.fixture.teams.home.name;

        // Use Supabase's RPC to schedule a pg_cron job
        const { error: cronErr } = await supabase.rpc("schedule_matchday_job", {
          job_name: jobName,
          cron_schedule: `${cronMinute} ${cronHour} ${cronDay} ${cronMonth} *`,
          function_url: `${supabaseUrl}/functions/v1/content-generator`,
          payload: JSON.stringify({
            team_id: match.team.id,
            type: "matchday",
            fixture_data: {
              fixture_id: String(match.fixture.fixture.id),
              kickoff_time: match.fixture.fixture.date,
              venue: match.fixture.fixture.venue?.name ?? "TBD",
              referee: match.fixture.fixture.referee ?? "TBD",
              competition: match.fixture.league.name,
              opponent_name: opponentName,
              is_home: match.isHome,
              home_team: match.fixture.teams.home.name,
              away_team: match.fixture.teams.away.name,
            },
          }),
        });

        if (cronErr) {
          // Fallback: trigger immediately if cron scheduling fails
          console.warn(`pg_cron scheduling failed for ${match.team.id}, triggering immediately:`, cronErr);
          try {
            await triggerMatchdayGenerator(match.team.id, match.fixture, match.isHome);
            results[match.team.id] = {
              status: "triggered_immediately_fallback",
              kickoff: kickoffTime.toISOString(),
              reason: "pg_cron scheduling failed",
            };
          } catch (err) {
            results[match.team.id] = { status: "error", error: String(err) };
          }
        } else {
          results[match.team.id] = {
            status: "scheduled",
            kickoff: kickoffTime.toISOString(),
            send_time: sendTime.toISOString(),
            cron_job: jobName,
          };
          await logHealth(
            supabase,
            match.team.id,
            "success",
            Date.now() - startTime,
            `Scheduled matchday content for ${sendTime.toISOString()} (kickoff: ${kickoffTime.toISOString()})`,
          );
        }
      }
    }

    return new Response(
      JSON.stringify({ matchday: true, fixtures: matches.length, results }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Matchday scheduler error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
