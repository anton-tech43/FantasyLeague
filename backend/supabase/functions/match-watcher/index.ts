// match-watcher/index.ts
// Goal Digger — Polls API-Football every 1 min for fixture status across
// ALL active leagues (PL + WC), detects transitions to "finished", and
// fires the gd-matchday Claude Code Routine for both teams in the match.
//
// V2.0: parameterised across leagues. Reads `SELECT DISTINCT league_id FROM
// teams` at request time, so new leagues (Euros, FA Cup, etc.) added to
// the teams table get watched automatically without code changes.
//
// State lives in match_status_state (migration 007). On first observation
// of a fixture (no prior row), we record the state but do NOT fire the
// routine — only fire on a transition we observe firsthand. Prevents
// mass-firing on initial deploy when several matches are already FT.
//
// Schedule: every 1 min via pg_cron (see migration 017).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { seasonForLeague, FALLBACK_ACTIVE_LEAGUES } from "../_shared/league-helpers.ts";
import { detectConsequences } from "../_shared/detect-consequences.ts";
import { renderConsequence } from "../_shared/consequence-templates.ts";

const FINISHED_STATUSES = new Set(["FT", "AET", "PEN"]);
// Live = match is in play (or in HT pause). Both halves + extra time
// brackets. We DON'T include "TBD"/"PST" (postponed) or "INT" (interrupted)
// — those aren't moments worth commenting on.
const LIVE_STATUSES = new Set(["1H", "HT", "2H", "ET", "P", "BT"]);
const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";

interface ApiFixture {
  fixture: {
    id: number;
    status: { short: string; elapsed: number | null };
    date: string;
  };
  league: { id: number; name: string; season: number; round?: string };
  teams: { home: { id: number; name: string }; away: { id: number; name: string } };
  goals: { home: number | null; away: number | null };
}

serve(async (req) => {
  // Caller-auth gate (see _shared/require-service-auth.ts). Server-only
  // function — rejects anon-key / no-auth callers; accepts the service
  // key that triggerFunction + pg_cron present.
  const denied = requireServiceAuth(req);
  if (denied) return denied;
  try {
    return await handleRequest(req);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const stack = e instanceof Error ? e.stack : undefined;
    // Stack stays server-side. HTTP response only carries the message so
    // any future stack frames that mention env-derived URLs or sandbox
    // paths don't leak via the response body.
    console.error("match-watcher unhandled:", msg, stack);
    return new Response(
      JSON.stringify({ error: "unhandled", message: msg }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

// V2.x observability: record every routine-fire attempt into pipeline_health.
// stage = 'matchday_fire' | 'live_brief_fire' | 'consequence_fire'. Captures
// success, failure (non-2xx from the routine API, or DB error on the
// consequence INSERT), and throws (network errors). The observability rule
// is: never let a hop fail silently — every attempt produces a row.
//
// Wrapped in try/catch so a logging failure can never break the actual
// fire loop. logging is best-effort.
async function logFire(
  supabase: ReturnType<typeof getSupabaseClient>,
  args: {
    stage: "matchday_fire" | "live_brief_fire" | "consequence_fire";
    teamId: string;
    fixtureId: number;
    trigger?: string; // "HT" for live_brief; consequence_type for consequence_fire; absent for matchday
    httpStatus: number | null;
    success: boolean;
    threw: boolean;
    bodyExcerpt: string | null;
    /**
     * Optional explicit status override. Used by consequence_fire to
     * distinguish "INSERT inserted a new row" (success) from "INSERT
     * deduplicated against the partial unique index" (skipped). Without
     * this, every detector run that re-detects a still-true consequence
     * would log as failure.
     */
    status?: "success" | "failure" | "skipped";
  },
): Promise<void> {
  try {
    const target = args.trigger
      ? `${args.stage}:${args.teamId}:${args.fixtureId}:${args.trigger}`
      : `${args.stage}:${args.teamId}:${args.fixtureId}`;
    const status = args.status ?? (args.success ? "success" : "failure");

    // Single dispatch off status. The failure branch still has to peek
    // at args.threw to distinguish network errors from non-2xx HTTP.
    const meta: { error_class: string; message: string | null } =
      status === "success"
        ? { error_class: "success", message: null }
        : status === "skipped"
          ? { error_class: "success", message: "Deduplicated against existing consequence row" }
          : args.threw
            ? { error_class: "fire_threw", message: "Network error reaching routine API" }
            : { error_class: "fire_failed", message: `Routine API returned non-2xx: ${args.httpStatus}` };

    await supabase.from("pipeline_health").insert({
      team_id: args.teamId,
      stage: args.stage,
      status,
      target,
      http_status: args.httpStatus,
      response_excerpt: args.bodyExcerpt,
      error_class: meta.error_class,
      message: meta.message,
    });
  } catch (e) {
    // Logging is best-effort. Don't break the fire loop.
    console.error("logFire failed (non-fatal):", e);
  }
}

async function handleRequest(req: Request): Promise<Response> {
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
  // Note: a starting-XI pre-kickoff trigger lived here briefly on May 18
  // night. The user opted for a simpler design (morning push references
  // lineups as a teaser, no fetch). Trigger removed; routine disabled
  // via RemoteTrigger. Migrations 046/047 left in place — unused enums
  // but harmless. If we revisit, the pattern was: env-driven URL/token,
  // trigger label STARTING_XI, fire window kickoff−65min, branch the
  // fire loop on `trigger === "STARTING_XI"` to pick the right URL.

  if (!apiFootballKey || !routineUrl || !routineToken) {
    return new Response(
      JSON.stringify({
        error: "Missing one of: API_FOOTBALL_KEY, MATCHDAY_ROUTINE_URL, MATCHDAY_ROUTINE_TOKEN",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // `today` is computed in Europe/London so that late-kickoff games (e.g.
  // a 20:00 GMT winter Saturday finishing 22:00 GMT) stay attached to
  // their kickoff day rather than rolling to UTC tomorrow at 00:00 UTC.
  // BST is +01:00, so this matters in winter more than summer, but the
  // code is calendar-stable year-round this way.
  const today = dateOverride ?? new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/London",
  }).format(new Date()); // en-CA gives YYYY-MM-DD shape

  // V2.0: single combined query for both league iteration AND the
  // api_football_id → team_id map. Previously this was two separate
  // SELECTs; combining them is cheaper (one round-trip per tick instead
  // of two) and atomic (no risk of a team being inserted between queries).
  const { data: teams, error: teamsErr } = await supabase
    .from("teams")
    .select("id, api_football_id, league_id")
    .not("league_id", "is", null);
  if (teamsErr) {
    return new Response(
      JSON.stringify({ error: `teams query failed: ${teamsErr.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
  const activeLeagues: number[] = teams && teams.length > 0
    ? [...new Set(teams.map((t) => t.league_id as number))]
    : FALLBACK_ACTIVE_LEAGUES;
  const teamIdMap = new Map<number, string>(
    (teams ?? []).map((t) => [t.api_football_id as number, t.id as string]),
  );

  // Fetch fixtures for each active league, combine into one array. Per-
  // league errors are logged but don't abort the whole run — a WC API
  // hiccup shouldn't stop PL match-watcher work.
  const fixtures: ApiFixture[] = [];
  const leagueErrors: Array<{ league_id: number; message: string }> = [];
  for (const leagueId of activeLeagues) {
    const season = seasonForLeague(leagueId);
    try {
      const resp = await fetch(
        `${API_FOOTBALL_BASE}/fixtures?league=${leagueId}&season=${season}&date=${today}`,
        { headers: { "x-apisports-key": apiFootballKey } },
      );
      const json = await resp.json();
      if (
        !Array.isArray(json.response) ||
        (json.errors && Object.keys(json.errors).length > 0)
      ) {
        const errMsg = `API-Football league=${leagueId} season=${season}: errors=${JSON.stringify(json.errors ?? {})}, response_type=${typeof json.response}`;
        console.warn("match-watcher:", errMsg);
        leagueErrors.push({ league_id: leagueId, message: errMsg });
        continue;
      }
      fixtures.push(...(json.response as ApiFixture[]));
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn(`match-watcher league=${leagueId} fetch failed:`, msg);
      leagueErrors.push({ league_id: leagueId, message: msg });
    }
  }

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
    const fixtureLeagueId = fx.league?.id;

    // Defensive: skip fixtures where either team isn't one of our 20.
    // Should never happen for league=39 but cheap to check.
    if (!homeTeamId || !awayTeamId) continue;
    // V2.0: skip fixtures with no league context — match_status_state.league_id
    // is NOT NULL with no FK, so writing `?? 0` would create ghost rows that
    // pollute diagnostics. A fixture with no league.id is unactionable anyway.
    if (!fixtureLeagueId) {
      console.warn(`match-watcher: skipping fixture ${fixtureId} — no league.id`);
      continue;
    }

    const { data: prior } = await supabase
      .from("match_status_state")
      .select("status, fired_finished_at, briefs_fired, matchday_fire_capped")
      .eq("fixture_id", fixtureId)
      .maybeSingle();

    // Only fire when we OBSERVE a transition firsthand.
    // First observation never fires (avoids mass-fire on initial deploy).
    // matchday_fire_capped is the "we gave up" flag from migration 042 —
    // see retry-cap logic below + IMPLEMENTATION_PROGRESS Lesson 65.
    const justFinished =
      FINISHED_STATUSES.has(status) &&
      prior !== null &&
      !prior.fired_finished_at &&
      !prior.matchday_fire_capped;

    // Retry-cap pre-check for matchday_fire. Migration 042 added the
    // matchday_fire_capped column to stop infinite retry loops when the
    // routine API persistently fails (429 quota, 503 outage, etc.). The
    // cap is N=5 failures OR T=2h since first failure, whichever first.
    // Once tripped we set matchday_fire_capped=TRUE on the upsert and
    // skip future fires for this fixture forever.
    //
    // pipeline_health is the source of truth for attempt history. Query
    // both home + away perspective targets in one call via LIKE pattern;
    // if EITHER target has hit the cap we treat the fixture as capped
    // (in practice the two perspectives move in lockstep when the cause
    // is a global rate limit, so either-trips-cap is the right rule).
    let matchdayCapTrippedThisTick = false;
    if (justFinished) {
      const sixHoursAgoIso = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
      const twoHoursAgoMs = Date.now() - 2 * 60 * 60 * 1000;
      const { data: priorFailures } = await supabase
        .from("pipeline_health")
        .select("target, created_at")
        .eq("stage", "matchday_fire")
        .eq("status", "failure")
        .like("target", `matchday_fire:%:${fixtureId}`)
        .gte("created_at", sixHoursAgoIso);
      const failuresByTarget = new Map<string, number[]>();
      for (const r of priorFailures ?? []) {
        const tsList = failuresByTarget.get(r.target) ?? [];
        tsList.push(new Date(r.created_at).getTime());
        failuresByTarget.set(r.target, tsList);
      }
      for (const timestamps of failuresByTarget.values()) {
        if (timestamps.length >= 5) {
          matchdayCapTrippedThisTick = true;
          break;
        }
        if (Math.min(...timestamps) < twoHoursAgoMs) {
          matchdayCapTrippedThisTick = true;
          break;
        }
      }
      if (matchdayCapTrippedThisTick) {
        console.log(
          `matchday_fire capped for fixture ${fixtureId}: failure history ` +
          `triggered the cap (5 attempts or 2h since first failure)`,
        );
      }
    }

    const shouldFireMatchday = justFinished && !matchdayCapTrippedThisTick;

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
      // 75' trigger DROPPED 2026-05-17 — fired 2 per match × 2 perspectives = 4
      // routine runs each, doubling live_brief budget for marginal UX value.
      // HT is the high-leverage in-match moment (gives her something to send
      // him at half-time). 75' was redundant for most users and ate quota
      // that match-day matchday_fire runs needed. Quota cap is 25/day; a busy
      // PL Saturday with 6 matches needs every run for matchday output.
      // See IMPLEMENTATION_PROGRESS Lesson 63 (routine quota economics).
    }

    // (STARTING_XI trigger removed — see env-vars comment above.)

    // Track per-perspective fire success. We only mark fired_finished_at
    // when BOTH home and away routine POSTs succeed — otherwise the failed
    // perspective never retries on the next tick, and half the audience for
    // this fixture silently gets no matchday content. The routine post-script
    // should idempotently upsert content_items on (team_id, match_id) so the
    // re-fire on the successful side is a no-op rather than a duplicate row.
    let homeFireOk = false;
    let awayFireOk = false;
    if (shouldFireMatchday) {
      // Fire the routine for both teams. Each fan sees the match through their lens.
      for (const [teamId, opponent, isHome] of [
        [homeTeamId, awayTeamId, true],
        [awayTeamId, homeTeamId, false],
      ] as const) {
        const score = isHome
          ? `${homeGoals}-${awayGoals}`
          : `${awayGoals}-${homeGoals}`;
        const text = `team_id=${teamId}; fixture_id=${fixtureId}; status=finished; opponent=${opponent}; score=${score}; kickoff_time=${kickoffTime}`;

        let matchdayHttpStatus: number | null = null;
        let matchdayBodyExcerpt: string | null = null;
        let matchdaySuccess = false;
        let matchdayThrew = false;
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
          matchdayHttpStatus = fireResp.status;
          if (fireResp.ok) {
            firesDispatched++;
            matchdaySuccess = true;
            if (isHome) homeFireOk = true;
            else awayFireOk = true;
            console.log(`fired routine for ${teamId}/${fixtureId}`);
          } else {
            const body = await fireResp.text().catch(() => "");
            matchdayBodyExcerpt = body.slice(0, 200);
            console.error(
              `fire failed for ${teamId}/${fixtureId}: ${fireResp.status} ${matchdayBodyExcerpt}`,
            );
          }
        } catch (e) {
          matchdayThrew = true;
          matchdayBodyExcerpt = e instanceof Error ? e.message.slice(0, 200) : null;
          console.error(`fire threw for ${teamId}/${fixtureId}:`, e);
        }
        await logFire(supabase, {
          stage: "matchday_fire",
          teamId,
          fixtureId,
          httpStatus: matchdayHttpStatus,
          success: matchdaySuccess,
          threw: matchdayThrew,
          bodyExcerpt: matchdayBodyExcerpt,
        });
      }

      // Cross-team consequence layer (Lesson 74). Pure math, zero
      // routine quota, idempotent via the (team_id, consequence_type)
      // unique index. Gated on bothFiresOk so a failed matchday_fire
      // retries the whole sequence on the next tick.
      if (homeFireOk && awayFireOk) {
        try {
          const consequences = await detectConsequences(supabase, {
            fixtureId,
            leagueId: fixtureLeagueId,
            homeTeamId,
            awayTeamId,
            homeApiId: fx.teams.home.id,
            awayApiId: fx.teams.away.id,
            homeGoals: homeGoals ?? 0,
            awayGoals: awayGoals ?? 0,
            homeDisplayName: fx.teams.home.name,
            awayDisplayName: fx.teams.away.name,
            round: fx.league?.round,   // B2: knockout-stage gate in detectConsequences
          });

          // Batch-resolve affected teams in ONE query rather than per-
          // consequence (the alternative was 1-6 sequential roundtrips
          // per FT).
          const teamRowsById = new Map<string, {
            id: string; display_name: string; short_name: string | null;
            api_football_id: number; entity_type?: string; league_id?: number;
          }>();
          if (consequences.length > 0) {
            const { data: teamRows } = await supabase
              .from("teams")
              .select("id, display_name, short_name, api_football_id, entity_type, league_id")
              .in("id", consequences.map((c) => c.team_id));
            for (const t of teamRows ?? []) teamRowsById.set(t.id, t);
          }

          for (const c of consequences) {
            const team = teamRowsById.get(c.team_id);
            if (!team) {
              console.warn(`consequence for unknown team_id=${c.team_id}, skipping`);
              continue;
            }

            const rendered = renderConsequence(c, team);

            const { error } = await supabase.from("content_items").insert({
              team_id: c.team_id,
              type: "news",
              consequence_type: c.consequence_type,
              headline: rendered.headline,
              body: rendered.body,
              push_text: rendered.push_text,
              push_title: rendered.push_title,
              everyone_talking: true,
              everyone_talking_headline: rendered.everyone_talking_headline,
              status: "published",
              published_at: new Date().toISOString(),
            });

            // Postgres unique-violation code 23505 = idempotent no-op
            // (consequence already fired on an earlier match).
            const isDedup = error?.code === "23505";
            const consequenceStatus: "success" | "failure" | "skipped" = isDedup
              ? "skipped"
              : error
                ? "failure"
                : "success";

            await logFire(supabase, {
              stage: "consequence_fire",
              teamId: c.team_id,
              fixtureId,
              trigger: c.consequence_type,
              httpStatus: error ? (isDedup ? 200 : 500) : 200,
              success: !error,
              threw: false,
              bodyExcerpt: error?.message?.slice(0, 200) ?? null,
              status: consequenceStatus,
            });

            if (!error) {
              console.log(
                `consequence_fire success: ${c.team_id} ${c.consequence_type} (triggered by fixture ${fixtureId})`,
              );
            }
          }
        } catch (e) {
          // Detector itself threw — never block the rest of the tick.
          // Phase J observability captures this as a system-level error.
          console.error(`consequence detection threw for fixture ${fixtureId}:`, e);
          await logFire(supabase, {
            stage: "consequence_fire",
            teamId: homeTeamId, // best-effort tag
            fixtureId,
            httpStatus: 500,
            success: false,
            threw: true,
            bodyExcerpt: e instanceof Error ? e.message.slice(0, 200) : String(e).slice(0, 200),
          });
        }
      }
    }

    // V1.1 C5: fire gd-live-brief for any new in-match trigger windows.
    // One fire per (team, trigger) pair — both home and away teams get
    // briefs, each tailored to their own perspective. Only HT today
    // (75' was dropped 2026-05-17, see briefsFired comment above).
    for (const trigger of newTriggers) {
      if (!liveBriefUrl || !liveBriefToken) continue;
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

        let liveHttpStatus: number | null = null;
        let liveBodyExcerpt: string | null = null;
        let liveSuccess = false;
        let liveThrew = false;
        try {
          const fireResp = await fetch(liveBriefUrl, {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${liveBriefToken}`,
              "anthropic-beta": "experimental-cc-routine-2026-04-01",
              "anthropic-version": "2023-06-01",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ text }),
          });
          liveHttpStatus = fireResp.status;
          if (fireResp.ok) {
            liveBriefFires++;
            liveSuccess = true;
            console.log(`live-brief fired for ${teamId}/${fixtureId} [${trigger}]`);
          } else {
            const body = await fireResp.text().catch(() => "");
            liveBodyExcerpt = body.slice(0, 200);
            console.error(
              `live-brief fire failed for ${teamId}/${fixtureId} [${trigger}]: ${fireResp.status} ${liveBodyExcerpt}`,
            );
          }
        } catch (e) {
          liveThrew = true;
          liveBodyExcerpt = e instanceof Error ? e.message.slice(0, 200) : null;
          console.error(`live-brief fire threw for ${teamId}/${fixtureId} [${trigger}]:`, e);
        }
        await logFire(supabase, {
          stage: "live_brief_fire",
          teamId,
          fixtureId,
          trigger,
          httpStatus: liveHttpStatus,
          success: liveSuccess,
          threw: liveThrew,
          bodyExcerpt: liveBodyExcerpt,
        });
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
    const bothFiresOk = shouldFireMatchday && homeFireOk && awayFireOk;
    const { error: upsertErr } = await supabase
      .from("match_status_state")
      .upsert(
        {
          fixture_id: fixtureId,
          league_id: fixtureLeagueId,
          home_team_id: homeTeamId,
          away_team_id: awayTeamId,
          status,
          home_goals: homeGoals,
          away_goals: awayGoals,
          kickoff_time: kickoffTime,
          last_checked: new Date().toISOString(),
          briefs_fired: updatedBriefsFired,
          ...(matchdayCapTrippedThisTick
            ? { matchday_fire_capped: true }
            : {}),
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
      active_leagues: activeLeagues,
      league_errors: leagueErrors,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
}
