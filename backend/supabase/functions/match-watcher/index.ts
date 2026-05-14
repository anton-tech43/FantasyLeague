// match-watcher/index.ts
// Goal Digger — Polls API-Football every 1 min for PL fixture status,
// detects transitions to "finished", and fires the gd-matchday Claude
// Code Routine for both teams in the match.
//
// State lives in match_status_state (migration 007). On first observation
// of a fixture (no prior row), we record the state but do NOT fire the
// routine — only fire on a transition we observe firsthand. Prevents
// mass-firing on initial deploy when several matches are already FT.
//
// Schedule: every 1 min via pg_cron (see migration 017).
//
// SEASON constant: bump each August when a new PL season starts. The
// season number is the year it BEGAN (Aug 2025 → May 2026 = SEASON=2025).
// API-Football's /fixtures?league=39 endpoint requires `season` — without
// it the response is empty (or an error object that gets silently
// swallowed), which is exactly the bug that ran for weeks and left
// match_status_state empty. Loud error guard below catches a recurrence.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";

const FINISHED_STATUSES = new Set(["FT", "AET", "PEN"]);
// Live = match is in play (or in HT pause). Both halves + extra time
// brackets. We DON'T include "TBD"/"PST" (postponed) or "INT" (interrupted)
// — those aren't moments worth commenting on.
const LIVE_STATUSES = new Set(["1H", "HT", "2H", "ET", "P", "BT"]);
const PL_LEAGUE_ID = 39;
const SEASON = 2025; // BUMP THIS EACH AUGUST: Aug 2026 → May 2027 = SEASON=2026
const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";

interface ApiFixture {
  fixture: {
    id: number;
    status: { short: string; elapsed: number | null };
    date: string;
  };
  teams: { home: { id: number; name: string }; away: { id: number; name: string } };
  goals: { home: number | null; away: number | null };
}

serve(async (req) => {
  const supabase = getSupabaseClient();

  // Optional ?date=YYYY-MM-DD override for replay diagnostics. When set,
  // the watcher queries the API for that specific date instead of "today
  // in Europe/London". Used to replay a past matchday and see whether the
  // upsert path actually works. NOT meant for normal cron operation — the
  // cron sends no params so today's London date is computed below.
  const url = new URL(req.url);
  const dateOverride = url.searchParams.get("date");

  const apiFootballKey = Deno.env.get("API_FOOTBALL_KEY");
  const routineUrl = Deno.env.get("MATCHDAY_ROUTINE_URL");
  const routineToken = Deno.env.get("MATCHDAY_ROUTINE_TOKEN");
  // V1.1 C5: live-brief routine for HT / 75' triggers. Optional — if either
  // env var is missing we still run the FT-transition flow but skip live
  // brief firing. This keeps the watcher resilient during phased rollout.
  const liveBriefUrl = Deno.env.get("LIVE_BRIEF_ROUTINE_URL");
  const liveBriefToken = Deno.env.get("LIVE_BRIEF_ROUTINE_TOKEN");
  const liveBriefConfigured = !!liveBriefUrl && !!liveBriefToken;

  if (!apiFootballKey || !routineUrl || !routineToken) {
    return new Response(
      JSON.stringify({
        error: "Missing one of: API_FOOTBALL_KEY, MATCHDAY_ROUTINE_URL, MATCHDAY_ROUTINE_TOKEN",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Fetch today's PL fixtures from API-Football.
  //
  // `today` is computed in Europe/London so that late-kickoff games (e.g.
  // a 20:00 GMT winter Saturday finishing 22:00 GMT) stay attached to
  // their kickoff day rather than rolling to UTC tomorrow at 00:00 UTC.
  // BST is +01:00, so this matters in winter more than summer, but the
  // code is calendar-stable year-round this way.
  const today = dateOverride ?? new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
  }).format(new Date()); // en-CA gives YYYY-MM-DD shape
  const apiResp = await fetch(
    `${API_FOOTBALL_BASE}/fixtures?league=${PL_LEAGUE_ID}&season=${SEASON}&date=${today}`,
    { headers: { "x-apisports-key": apiFootballKey } },
  );
  const fixturesJson = await apiResp.json();

  // Loud error guard. API-Football returns { errors: { ... } } when the
  // query is malformed (e.g. missing `season`) or when the key is rate-
  // limited / invalid. Without this guard, the original code silently
  // proceeded with an empty fixture list — which was the actual bug that
  // ran for weeks. Now: bail with 500 + log so the next silent failure is
  // a loud one.
  if (
    !Array.isArray(fixturesJson.response) ||
    (fixturesJson.errors &&
      Object.keys(fixturesJson.errors).length > 0)
  ) {
    const errMsg = `API-Football returned unexpected shape: errors=${JSON.stringify(fixturesJson.errors ?? {})}, response_type=${typeof fixturesJson.response}`;
    console.error("match-watcher:", errMsg);
    return new Response(
      JSON.stringify({
        error: errMsg,
        date: today,
        season: SEASON,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
  const fixtures: ApiFixture[] = fixturesJson.response;

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
  let liveBriefFires = 0;
  const upsertErrors: Array<{ fixture_id: number; message: string }> = [];

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
      .select("status, fired_finished_at, briefs_fired")
      .eq("fixture_id", fixtureId)
      .maybeSingle();

    // Only fire when we OBSERVE a transition firsthand.
    // First observation never fires (avoids mass-fire on initial deploy).
    const justFinished =
      FINISHED_STATUSES.has(status) &&
      prior !== null &&
      !prior.fired_finished_at;

    // ─── V1.1 C5: live-brief trigger detection ────────────────────────
    // For LIVE fixtures, decide which (if any) trigger label to fire
    // this minute. The briefs_fired JSONB array on match_status_state is
    // the idempotency guard — once a label is in the array, we won't
    // re-fire it. First observation also skips (we don't know how long
    // we've been past the trigger window).
    const elapsed = fx.fixture.status.elapsed;
    const briefsFired: string[] = Array.isArray(prior?.briefs_fired)
      ? prior!.briefs_fired as string[]
      : [];
    const isLive = LIVE_STATUSES.has(status);
    const newTriggers: string[] = [];

    if (isLive && prior !== null && liveBriefConfigured) {
      // HT trigger: status == "HT" (the literal break) OR status == "2H"
      // AND we haven't fired HT yet (catches the case where we missed
      // the HT window because the cron didn't tick during the break).
      if (
        !briefsFired.includes("HT") &&
        (status === "HT" || status === "2H")
      ) {
        newTriggers.push("HT");
      }
      // 75' trigger: status == "2H" AND elapsed >= 75. Note: API-Football's
      // `elapsed` includes added time, so 90+1 = 91 etc. — the >= 75 check
      // still works because we're only asking "are we past the 75' mark?".
      if (
        !briefsFired.includes("75") &&
        status === "2H" &&
        elapsed !== null &&
        elapsed >= 75
      ) {
        newTriggers.push("75");
      }
    }

    // Track per-perspective fire success. We only mark fired_finished_at
    // when BOTH home and away routine POSTs succeed — otherwise the failed
    // perspective never retries on the next tick, and half the audience for
    // this fixture silently gets no matchday content. The routine post-script
    // should idempotently upsert content_items on (team_id, match_id) so the
    // re-fire on the successful side is a no-op rather than a duplicate row.
    let homeFireOk = false;
    let awayFireOk = false;
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
            if (isHome) homeFireOk = true;
            else awayFireOk = true;
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

    // V1.1 C5: fire gd-live-brief for any new in-match trigger windows.
    // One fire per (team, trigger) pair — both home and away teams get
    // briefs, each tailored to their own perspective.
    for (const trigger of newTriggers) {
      for (const [teamId, _opponentTeamId, _isHome] of [
        [homeTeamId, awayTeamId, true],
        [awayTeamId, homeTeamId, false],
      ] as const) {
        const homeName = fx.teams.home.name;
        const awayName = fx.teams.away.name;
        const briefMinute = elapsed ?? (trigger === "HT" ? 46 : 75);
        // Compose the payload the routine expects. Semicolon-separated
        // key=value pairs match the existing gd-matchday convention.
        // home_goals and away_goals always refer to the literal home/away
        // teams (NOT user/opponent). The routine derives user-vs-opponent
        // by matching `user_team_id` against `home_team_id`/`away_team_id`.
        // An earlier version used a user/opponent indirection that inverted
        // the away team's brief score — fixed.
        const text = [
          `home_team_id=${homeTeamId}`,
          `away_team_id=${awayTeamId}`,
          `home_team_name=${homeName}`,
          `away_team_name=${awayName}`,
          `user_team_id=${teamId}`,
          `home_goals=${homeGoals ?? 0}`,
          `away_goals=${awayGoals ?? 0}`,
          `minute=${briefMinute}`,
          `trigger=${trigger}`,
          `fixture_id=${fixtureId}`,
        ].join("; ");

        try {
          const fireResp = await fetch(liveBriefUrl!, {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${liveBriefToken}`,
              "anthropic-beta": "experimental-cc-routine-2026-04-01",
              "anthropic-version": "2023-06-01",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ text }),
          });
          if (fireResp.ok) {
            liveBriefFires++;
            console.log(`live-brief fired for ${teamId}/${fixtureId} [${trigger}]`);
          } else {
            const body = await fireResp.text().catch(() => "");
            console.error(
              `live-brief fire failed for ${teamId}/${fixtureId} [${trigger}]: ${fireResp.status} ${body.slice(0, 200)}`,
            );
          }
        } catch (e) {
          console.error(`live-brief fire threw for ${teamId}/${fixtureId} [${trigger}]:`, e);
        }
      }
    }

    // Compute the updated briefs_fired array (append newTriggers, dedupe).
    // We write this into the upsert below so a second tick within the
    // same trigger window won't re-fire — even if the prior row never
    // existed (first-observation skip case is handled by the
    // `prior !== null` guard on trigger detection above).
    const updatedBriefsFired = [...new Set([...briefsFired, ...newTriggers])];

    // Upsert state. fired_finished_at is set ONLY when justFinished AND both
    // home and away routine fires succeeded — if one failed, the next tick
    // will retry both perspectives. The routine post-script must upsert
    // content_items on (team_id, match_id) so the successful side's re-fire
    // is a no-op rather than a duplicate.
    const bothFiresOk = justFinished && homeFireOk && awayFireOk;
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
          briefs_fired: updatedBriefsFired,
          ...(bothFiresOk
            ? { fired_finished_at: new Date().toISOString() }
            : {}),
        },
        { onConflict: "fixture_id" },
      );
    if (upsertErr) {
      console.warn(`state upsert failed for ${fixtureId}:`, upsertErr.message);
      upsertErrors.push({ fixture_id: fixtureId, message: upsertErr.message });
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
      live_brief_fires: liveBriefFires,
      live_brief_configured: liveBriefConfigured,
      upsert_errors: upsertErrors,
      date: today,
      season: SEASON,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
