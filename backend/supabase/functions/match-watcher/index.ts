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
import { detectConsequences, loadPostResultWcContext, WC_LEAGUE_ID } from "../_shared/detect-consequences.ts";
import { renderConsequence } from "../_shared/consequence-templates.ts";
import type { Team } from "../_shared/types.ts";
import { groupSituation } from "../_shared/stakes-engine.ts";
import { renderPostMatch, type PostMatchState } from "../_shared/stakes-templates.ts";
import { resultFraming, WC_FAVORITE_GAP } from "../_shared/matchup-verdict.ts";
import { buildAPNsPayload, sendLiveActivityPush, sendPushNotification } from "../_shared/apns-client.ts";
import { WC_COUNTRY_META, wcStatusLabel } from "../_shared/wc-countries.ts";
import {
  detectGoal,
  formatScorerLine,
  type GoalEvent,
  type GoalPushCopy,
  pickLatestGoalForTeam,
  renderFullTimePush,
  renderGoalPush,
  renderHalfTimePush,
  renderKickoffSoonPush,
} from "../_shared/goal-push.ts";

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

// API-Football GET /fixtures/events?fixture={id} → { response: ApiEvent[] }.
// Each timeline event (goals, cards, subs, VAR). We narrow to Goal events.
// All fields are typed loosely + parsed defensively (parseGoalEvents) because
// the live feed occasionally ships partial rows mid-match.
interface ApiEvent {
  time?: { elapsed?: number | null; extra?: number | null } | null;
  team?: { id?: number | null; name?: string | null } | null;
  player?: { id?: number | null; name?: string | null } | null;
  type?: string | null; // "Goal" | "Card" | "subst" | "Var" | ...
  detail?: string | null; // "Normal Goal" | "Penalty" | "Own Goal" | "Missed Penalty" | ...
}

/// Parse a raw /fixtures/events `response` array into our GoalEvent shape,
/// keeping ONLY goals that actually changed the score. Excluded:
///   - non-Goal types (cards, subs, VAR overturns)
///   - detail === "Missed Penalty" (type is "Goal" but no goal was scored)
/// Own goals are kept with isOwnGoal=true: API-Football credits the event's
/// `team` to the BENEFITING side (the side whose score rose), so the teamApiId
/// already matches detectGoal's side — but the named player belongs to the
/// OTHER team, so formatScorerLine drops the name for own goals. Tolerant of a
/// null / non-array payload (returns []). Never throws.
export function parseGoalEvents(raw: unknown): GoalEvent[] {
  if (!Array.isArray(raw)) return [];
  const out: GoalEvent[] = [];
  for (const item of raw as ApiEvent[]) {
    if (!item || typeof item !== "object") continue;
    if (item.type !== "Goal") continue;
    const detail = typeof item.detail === "string" ? item.detail : "";
    if (detail === "Missed Penalty") continue; // type "Goal" but no goal scored
    const teamApiId = item.team?.id;
    if (typeof teamApiId !== "number") continue; // can't attribute → useless
    const rawMinute = item.time?.elapsed;
    const rawExtra = item.time?.extra;
    out.push({
      teamApiId,
      playerName: typeof item.player?.name === "string" ? item.player.name : null,
      minute: typeof rawMinute === "number" ? rawMinute : null,
      extra: typeof rawExtra === "number" ? rawExtra : null,
      isOwnGoal: detail === "Own Goal",
      isPenalty: detail === "Penalty",
    });
  }
  return out;
}

/// Fetch the goal events for one fixture from API-Football. ONLY call this when
/// a goal was actually detected this tick (quota matters — one extra request
/// per goal, never per poll). Reuses the same base URL + x-apisports-key header
/// as the fixtures poll. Returns [] on any error (network, non-array payload,
/// API `errors` object) so the caller falls back cleanly to scorer-less copy.
async function fetchGoalEvents(fixtureId: number, apiKey: string): Promise<GoalEvent[]> {
  try {
    const resp = await fetch(
      `${API_FOOTBALL_BASE}/fixtures/events?fixture=${fixtureId}`,
      { headers: { "x-apisports-key": apiKey } },
    );
    const json = await resp.json().catch(() => null);
    if (
      !json ||
      !Array.isArray(json.response) ||
      (json.errors && Object.keys(json.errors).length > 0)
    ) {
      console.warn(
        `match-watcher: /fixtures/events fixture=${fixtureId} unusable ` +
        `(status=${resp.status}, errors=${JSON.stringify(json?.errors ?? {})})`,
      );
      return [];
    }
    return parseGoalEvents(json.response);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn(`match-watcher: /fixtures/events fixture=${fixtureId} fetch failed:`, msg);
    return [];
  }
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

/// Direct APNs alert to the followers of the two PLAYING WC countries (goal /
/// half-time / full-time). Unlike consequence content_items, which wait on
/// notification-sender's hourly sweep (5-75 min), these fire immediately from
/// the tick that observed the event, since a goal alert is worthless an hour
/// late. Recipients: device_tokens whose country_id matches either playing
/// team; sent to ALL tiers (matches existing WC push behaviour). The body is
/// the follower's perspective (copy.bodies keyed by country slug); the title
/// is shared. content_id is a non-UUID sentinel so an app tap just opens the
/// app (AppDelegate only deep-links when content_id parses as a UUID). Returns
/// the number of pushes successfully dispatched. Best-effort and self-
/// contained: a token-query or send error never aborts the tick.
async function sendWcPlayingTeamPush(
  supabase: ReturnType<typeof getSupabaseClient>,
  args: {
    homeTeamId: string;
    awayTeamId: string;
    copy: GoalPushCopy;
    category: string;
    fixtureId: number;
    label: string; // "goal" | "ht" | "ft" — content_id discriminator + logs
    // Optional country_id → content_item UUID. When present for a follower's
    // country, the push deep-links to that article (FT result); otherwise the
    // content_id is a non-UUID sentinel and the tap just opens the app.
    contentIdByCountry?: Record<string, string>;
  },
): Promise<number> {
  try {
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("apns_token, country_id, apns_environment")
      .in("country_id", [args.homeTeamId, args.awayTeamId])
      .eq("is_active", true);

    // Per-country tallies so we can write one apns_send pipeline_health row per
    // playing team — the live goal/HT/FT/kickoff pushes were previously invisible
    // to audits (only the briefs_fired markers proved a push was attempted, never
    // whether APNs accepted it). This is how the 429 was caught for the sweep
    // pushes; now the live pushes get the same visibility.
    const stats = new Map<string, { sent: number; failed: number; reason?: string; status?: number }>();
    let sent = 0;
    for (const t of tokens ?? []) {
      const country = t.country_id as string;
      const body = args.copy.bodies[country];
      if (!body) continue; // follower of a team not in this match — shouldn't happen
      const contentId = args.contentIdByCountry?.[country] ?? `wc-${args.label}-${args.fixtureId}`;
      const payload = buildAPNsPayload(
        "", // teamShortName fallback unused — we pass pushTitle below
        body, // headline fallback
        contentId, // UUID (deep-links to the article) or non-UUID sentinel (just opens)
        args.category,
        false,
        body, // push_text (lock-screen body)
        args.copy.title, // push_title (lock-screen title)
      );
      const env = t.apns_environment === "production" ? "production" : "development";
      const res = await sendPushNotification(t.apns_token as string, payload, env);
      const s = stats.get(country) ?? { sent: 0, failed: 0 };
      if (res.success) {
        s.sent++;
        sent++;
      } else {
        s.failed++;
        s.reason = res.reason;
        s.status = res.status;
      }
      stats.set(country, s);
    }

    // Best-effort observability: never let a logging error break the send.
    try {
      for (const [country, s] of stats) {
        const total = s.sent + s.failed;
        const status = s.failed === 0 ? "success" : s.sent === 0 ? "failure" : "partial";
        await supabase.from("pipeline_health").insert({
          team_id: country,
          stage: "apns_send",
          status,
          target: `wc_${args.label}:${country}:${args.fixtureId}`,
          http_status: s.status ?? null,
          response_excerpt: s.failed > 0 ? (s.reason ?? "unknown").slice(0, 200) : null,
          error_class: status === "success" ? "success" : "apns_send_failed",
          message: `WC ${args.label}: ${s.sent} sent, ${s.failed} failed of ${total}`,
        });
      }
    } catch (logErr) {
      console.error("sendWcPlayingTeamPush logging failed (non-fatal):", logErr);
    }

    return sent;
  } catch (e) {
    console.error(`sendWcPlayingTeamPush failed for fixture ${args.fixtureId} [${args.label}] (non-fatal):`, e);
    return 0;
  }
}

/// Merge a deterministic post_match card into a team's team_pages.content.
/// Best-effort: a missing page or write error never blocks the FT tick.
async function writeWcPostMatch(
  supabase: ReturnType<typeof getSupabaseClient>,
  teamSlug: string,
  pm: { state: "win" | "loss" | "draw"; text: string; talking_point: string },
): Promise<void> {
  try {
    const { data: existing } = await supabase
      .from("team_pages")
      .select("content")
      .eq("team_id", teamSlug)
      .maybeSingle();
    if (!existing?.content) return;
    const content = existing.content as Record<string, unknown>;
    const cards = (content.cards ?? {}) as Record<string, unknown>;
    cards.post_match = {
      state: pm.state,
      text: pm.text,
      talking_point: pm.talking_point,
      expires_at: new Date(Date.now() + 48 * 60 * 60_000).toISOString(),
    };
    content.cards = cards;
    await supabase.from("team_pages").update({ content }).eq("team_id", teamSlug);
  } catch (e) {
    console.error(`writeWcPostMatch failed for ${teamSlug} (non-fatal):`, e);
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

  // `today` is the UTC date — API-Football's `fixtures?date=` filters by UTC.
  // This used to be computed in Europe/London, which broke the WC's US-night
  // games: London is UTC+1 in June, so from 23:00 UTC the watcher asked for
  // TOMORROW's fixtures while 22:00-23:30 UTC kickoffs were still running —
  // their 2H/FT became invisible mid-match (30 WC fixtures affected). UTC
  // matches the API's indexing; the hangover poll below covers games that
  // legitimately straddle UTC midnight.
  const today = dateOverride ?? new Date().toISOString().slice(0, 10);

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

  // Poll plan: every active league polls `today` (UTC). Additionally, while a
  // fixture dated YESTERDAY (UTC) is still in a non-terminal status — a
  // 22:00-23:30 UTC kickoff running past midnight — poll yesterday's date too,
  // so the game stays visible through FT. Guaranteed-known: such a fixture was
  // polled all day under its own date, so its state row exists; once it goes
  // terminal the extra poll stops. Query failure degrades to today-only
  // (current behavior). Skipped under ?date= override (operator intent).
  const pollPairs: Array<{ leagueId: number; date: string }> =
    activeLeagues.map((leagueId) => ({ leagueId, date: today }));
  if (!dateOverride) {
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const { data: hangover } = await supabase
      .from("match_status_state")
      .select("league_id")
      .gte("kickoff_time", `${yesterday}T00:00:00Z`)
      .lt("kickoff_time", `${today}T00:00:00Z`)
      .not("status", "in", "(FT,AET,PEN,PST,CANC,ABD,AWD,WO)");
    for (const leagueId of new Set((hangover ?? []).map((r) => r.league_id as number))) {
      if (activeLeagues.includes(leagueId)) pollPairs.push({ leagueId, date: yesterday });
    }
  }

  // Fetch fixtures for each (league, date) pair, combine into one array. Per-
  // pair errors are logged but don't abort the whole run — a WC API
  // hiccup shouldn't stop PL match-watcher work.
  const fixtures: ApiFixture[] = [];
  const leagueErrors: Array<{ league_id: number; message: string }> = [];
  for (const { leagueId, date: pollDate } of pollPairs) {
    const season = seasonForLeague(leagueId);
    try {
      const resp = await fetch(
        `${API_FOOTBALL_BASE}/fixtures?league=${leagueId}&season=${season}&date=${pollDate}`,
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
  let goalPushSends = 0;
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
      .select("status, home_goals, away_goals, fired_finished_at, briefs_fired, matchday_fire_capped, la_started, la_sig, la_ended")
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
    // Markers for direct-push idempotency (HT_PUSH / FT_PUSH). Kept SEPARATE
    // from newTriggers: newTriggers drives the paid gd-live-brief routine fire
    // loop below, so polluting it would fire a spurious (billed) routine. These
    // markers only ever land in briefs_fired for the once-per-window guard.
    const pushMarkers: string[] = [];
    // country_id → the just-written FT result article id, so the FT push can
    // deep-link straight to it (the post_match block below populates this a few
    // steps before the push fires, same tick).
    const wcResultItemIds: Record<string, string> = {};

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
        // WC matchday content is now deterministic (the post_match block below
        // writes the result article + talking points). gd-matchday produces
        // nothing for country entities, so firing it for WC is pure wasted
        // routine quota (which busy WC days need for gd-live-brief). Skip the
        // fire and just mark this perspective OK so the deterministic
        // consequence + post_match block still runs and fired_finished_at sets.
        if (fixtureLeagueId === WC_LEAGUE_ID) {
          if (isHome) homeFireOk = true;
          else awayFireOk = true;
          continue;
        }
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
          const teamRowsById = new Map<string, Team>();
          if (consequences.length > 0) {
            const { data: teamRows } = await supabase
              .from("teams")
              .select("id, display_name, short_name, api_football_id, entity_type, league_id")
              .in("id", consequences.map((c) => c.team_id));
            // DB columns are wider than the Team type (short_name nullable,
            // entity_type a free string); renderConsequence only reads
            // display_name, so coerce to satisfy Team without behaviour change.
            for (const t of teamRows ?? []) {
              teamRowsById.set(t.id, {
                ...t,
                short_name: t.short_name ?? "",
                entity_type: t.entity_type as "club" | "country" | undefined,
              });
            }
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
              // Rival-result rows are idempotent per (team_id, match_id) via
              // the existing unique_matchday_content constraint — one per
              // affected team per triggering fixture. The once-per-type index
              // excludes WC_RIVAL_RESULT (migration 060) so each matchday's
              // rival result lands. Math consequences keep match_id null.
              match_id: c.consequence_type === "WC_RIVAL_RESULT" ? String(fixtureId) : null,
              headline: rendered.headline,
              body: rendered.body,
              push_text: rendered.push_text,
              push_title: rendered.push_title,
              // WC_RIVAL_RESULT is scoped to the rival's OWN feed only: a Czech
              // fan sees "a result in your group" on the Czech feed, but it must
              // NOT enter the shared "Football" (everyone_talking) feed — there
              // it read as a confusing near-duplicate ("...in Czech's group" /
              // "...in Korea's group") with no group context. The single neutral
              // result for the Football feed comes from the playing-team article
              // below. Math consequences (TITLE_WON etc.) stay everyone-worthy.
              everyone_talking: c.consequence_type !== "WC_RIVAL_RESULT",
              everyone_talking_headline: rendered.everyone_talking_headline,
              // "Your move" prompts. WC_RIVAL_RESULT now ships a safe open
              // talking point so the section is never empty (was []); other
              // consequence types still render none.
              talking_points: rendered.talking_points,
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

          // Deterministic post_match card for the two PLAYING WC teams.
          // Uses the live FT score (accurate immediately, unlike the
          // standings table which lags the data-fetch). Tone follows the
          // post-result group situation: through/won reads upbeat; top-two
          // gone reads muted and respectful, never "enjoy it". Zero Claude.
          if (fixtureLeagueId === WC_LEAGUE_ID) {
            const wcCtx = await loadPostResultWcContext(supabase, {
              leagueId: fixtureLeagueId,
              homeTeamId,
              homeApiId: fx.teams.home.id,
              awayApiId: fx.teams.away.id,
              homeGoals: homeGoals ?? 0,
              awayGoals: awayGoals ?? 0,
              round: fx.league?.round,
            });
            if (wcCtx) {
              const hg = homeGoals ?? 0;
              const ag = awayGoals ?? 0;
              // Neutral, winner-first result for the shared "Football" feed
              // (the single item everyone sees), carried by the home row below.
              const neutralResult = hg === ag
                ? `${fx.teams.home.name} and ${fx.teams.away.name} drew ${hg}-${ag}`
                : hg > ag
                  ? `${fx.teams.home.name} beat ${fx.teams.away.name} ${hg}-${ag}`
                  : `${fx.teams.away.name} beat ${fx.teams.home.name} ${ag}-${hg}`;

              const playing = [
                { slug: homeTeamId, apiId: fx.teams.home.id, name: fx.teams.home.name, oppName: fx.teams.away.name, gf: hg, ga: ag },
                { slug: awayTeamId, apiId: fx.teams.away.id, name: fx.teams.away.name, oppName: fx.teams.home.name, gf: ag, ga: hg },
              ];
              // B3: one lookup for both teams' strength_rank (FIFA for WC
              // countries) → deterministic "as expected / upset / surprise"
              // framing appended to each perspective's body. C1 may later
              // enrich this same row.
              const { data: rankRows } = await supabase
                .from("teams")
                .select("id, strength_rank")
                .in("id", [homeTeamId, awayTeamId]);
              const rankBySlug = new Map<string, number | null>();
              for (const r of rankRows ?? []) {
                rankBySlug.set(r.id as string, (r.strength_rank as number | null) ?? null);
              }
              for (const p of playing) {
                const state: PostMatchState = p.gf > p.ga ? "win" : p.gf < p.ga ? "loss" : "draw";
                const pm = renderPostMatch({
                  teamName: p.name,
                  opponentName: p.oppName,
                  teamScore: p.gf,
                  oppScore: p.ga,
                  state,
                  situation: groupSituation(wcCtx.group, p.apiId),
                  bestThird: wcCtx.bestThirdByApiId.get(p.apiId),
                });
                await writeWcPostMatch(supabase, p.slug, pm);

                // B3: append the ranking framing to this team's result body.
                const oppSlug = p.slug === homeTeamId ? awayTeamId : homeTeamId;
                const framing = resultFraming(
                  rankBySlug.get(p.slug) ?? null,
                  rankBySlug.get(oppSlug) ?? null,
                  p.gf,
                  p.ga,
                  WC_FAVORITE_GAP,
                );
                const resultBody = framing ? `${pm.text} ${framing.note}` : pm.text;

                // The feed article the user was missing: a real result item on
                // the PLAYING team's own feed, perspective-framed, WITH a talking
                // point (renderPostMatch's situation-aware prose). gd-matchday
                // produces nothing for WC, so this deterministic floor is what
                // guarantees the playing teams are never newsless again. Only
                // the HOME row carries everyone_talking → the Football feed shows
                // exactly ONE neutral result (no perspective duplicate).
                const isHome = p.slug === homeTeamId;
                const perspectiveHeadline = state === "win"
                  ? `${p.name} beat ${p.oppName} ${p.gf}-${p.ga}`
                  : state === "loss"
                    ? `${p.name} lost ${p.gf}-${p.ga} to ${p.oppName}`
                    : `${p.name} drew ${p.gf}-${p.ga} with ${p.oppName}`;
                const { data: inserted, error: itemErr } = await supabase
                  .from("content_items")
                  .insert({
                    team_id: p.slug,
                    type: "matchday",
                    match_id: String(fixtureId),
                    match_result: perspectiveHeadline,
                    headline: perspectiveHeadline,
                    body: resultBody,
                    talking_points: [pm.talking_point],
                    // The lock-screen alert is sent directly by the FT push
                    // below; this feed article must NOT be re-pushed by
                    // notification-sender's sweep (double-ping). Feed-only.
                    push_eligible: false,
                    everyone_talking: isHome,
                    everyone_talking_headline: isHome ? neutralResult : null,
                    everyone_talking_body: isHome ? `${neutralResult}. Full-time in their World Championship group.` : null,
                    status: "published",
                    published_at: new Date().toISOString(),
                  })
                  .select("id")
                  .maybeSingle();
                if (!itemErr && inserted?.id) {
                  wcResultItemIds[p.slug] = inserted.id as string;
                } else if (itemErr && itemErr.code !== "23505") {
                  // 23505 = already written this match (idempotent no-op).
                  console.error(`wc result item insert failed for ${p.slug}/${fixtureId} (non-fatal):`, itemErr.message);
                }
              }
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

    // ─── Live Activity (Lock Screen / Dynamic Island) drive ──────────────
    // WC matches only (the activity UI + flag emoji are WC-scoped). Start once
    // at kickoff (push-to-start), update on score/period change, end at FT.
    // Idempotency via la_started / la_sig / la_ended on the row. Pushes carry
    // the full attributes + content-state, so the widget needs no network.
    let laStarted = (prior?.la_started as boolean | undefined) ?? false;
    let laSig = (prior?.la_sig as string | null | undefined) ?? null;
    let laEnded = (prior?.la_ended as boolean | undefined) ?? false;

    if (fixtureLeagueId === WC_LEAGUE_ID && !laEnded) {
      const homeMeta = WC_COUNTRY_META[homeTeamId];
      const awayMeta = WC_COUNTRY_META[awayTeamId];
      if (homeMeta && awayMeta) {
        // Live minute drives the "63' / 90" badge. Only meaningful during an
        // active half (1H/2H/ET) — null at HT/BT/penalties/FT so the badge
        // shows the period label there and the per-minute updates stop. Folded
        // into `sig` so each new minute pushes one silent LA update.
        const liveMinute = isLive && status !== "HT" && status !== "BT"
          ? (elapsed ?? null)
          : null;
        const contentState = {
          homeScore: homeGoals ?? 0,
          awayScore: awayGoals ?? 0,
          statusLabel: wcStatusLabel(status),
          elapsed: liveMinute,
        };
        const sig = `${contentState.homeScore}-${contentState.awayScore}-${contentState.statusLabel}-${liveMinute ?? ""}`;
        const matchFinished = FINISHED_STATUSES.has(status);

        const sendAll = async (
          rows: Array<{ token: string; apns_environment: string }> | null,
          opts: Parameters<typeof sendLiveActivityPush>[1],
        ) => {
          for (const r of rows ?? []) {
            await sendLiveActivityPush(r.token, {
              ...opts,
              environment: r.apns_environment === "production" ? "production" : "development",
            });
          }
        };

        if (matchFinished && laStarted) {
          // END — final score + auto-dismiss after 2h.
          const { data: updTokens } = await supabase
            .from("live_activity_tokens")
            .select("token, apns_environment")
            .eq("kind", "update").eq("fixture_id", fixtureId).eq("is_active", true);
          await sendAll(updTokens, { event: "end", contentState, dismissalSeconds: 7200 });
          laEnded = true;
          laSig = sig;
        } else if (isLive && !laStarted && prior !== null) {
          // START — push-to-start the followers' activities (first observed
          // live tick; prior!==null mirrors the matchday first-observation guard).
          const { data: ptsTokens } = await supabase
            .from("live_activity_tokens")
            .select("token, apns_environment")
            .eq("kind", "push_to_start").eq("is_active", true)
            .in("country_id", [homeTeamId, awayTeamId]);
          await sendAll(ptsTokens, {
            event: "start",
            attributes: {
              fixtureId,
              homeName: homeMeta.name,
              awayName: awayMeta.name,
              homeFlag: homeMeta.flag,
              awayFlag: awayMeta.flag,
            },
            contentState,
            alert: { title: `${homeMeta.name} v ${awayMeta.name}`, body: "It's kicked off." },
            staleSeconds: 5400,
          });
          laStarted = true;
          laSig = sig;
        } else if (isLive && laStarted && sig !== laSig) {
          // UPDATE — goal or period change since the last push.
          const { data: updTokens } = await supabase
            .from("live_activity_tokens")
            .select("token, apns_environment")
            .eq("kind", "update").eq("fixture_id", fixtureId).eq("is_active", true);
          await sendAll(updTokens, { event: "update", contentState, staleSeconds: 5400 });
          laSig = sig;
        }
      }
    }

    // ─── Goal / half-time / full-time pushes (WC playing teams) ──────────
    // The alert banners the user asked for: followers of BOTH playing
    // countries get a lock-screen push at every goal, at the break, and at
    // full-time. Distinct from the Live Activity above (that's the persistent
    // lock-screen score; these are the one-shot alerts) and from WC_RIVAL_RESULT
    // (which stays after-the-game-only for the OTHER teams in the group).
    // Deterministic, zero Claude. Fires for any WC round including knockouts —
    // it keys off the live score, not group math.
    if (fixtureLeagueId === WC_LEAGUE_ID) {
      const homeMeta = WC_COUNTRY_META[homeTeamId];
      const awayMeta = WC_COUNTRY_META[awayTeamId];
      if (homeMeta && awayMeta) {
        const homeTeam = { id: homeTeamId, name: homeMeta.name, flag: homeMeta.flag };
        const awayTeam = { id: awayTeamId, name: awayMeta.name, flag: awayMeta.flag };

        // 30-MINUTES-TO-KICKOFF — the "it's about to start" nudge. Fire once
        // when the fixture is still NS and kickoff is within the next 30 min.
        // Future-only (minsToKickoff > 0) so a delayed game already past its
        // listed time can't fire it; marker-gated so a deploy inside the window
        // fires at most once. The fixture is in match_status_state ~2h before
        // kickoff (date roll), so the 30-min mark is always observed.
        const minsToKickoff = (new Date(kickoffTime).getTime() - Date.now()) / 60000;
        if (
          status === "NS" && minsToKickoff > 0 && minsToKickoff <= 30 &&
          !briefsFired.includes("PREKICK_PUSH")
        ) {
          const copy = renderKickoffSoonPush({ home: homeTeam, away: awayTeam });
          await sendWcPlayingTeamPush(supabase, {
            homeTeamId,
            awayTeamId,
            copy,
            category: "WC_KICKOFF_SOON",
            fixtureId,
            label: "kickoff",
          });
          pushMarkers.push("PREKICK_PUSH");
        }

        // GOAL — the score rose since the last observed tick. `prior !== null`
        // avoids a phantom goal when we first observe an in-progress game
        // (mirrors the matchday / Live Activity first-observation guard).
        // Idempotency needs no marker: the end-of-tick upsert advances
        // home_goals/away_goals, so next tick detectGoal sees no change.
        if (isLive && prior !== null) {
          const side = detectGoal(prior.home_goals, prior.away_goals, homeGoals, awayGoals);
          if (side) {
            // Scorer + minute enrichment (A2). Fetch the fixture's events ONLY
            // now, on a real goal — never every poll (quota). When BOTH sides
            // scored in one tick (side === "both") we can't honestly name a
            // single scorer, so we skip the lookup and keep the rotating copy.
            // The scoring side's API team id (home vs away) tells pickLatest...
            // which goal to surface; the latest (highest minute) is the one
            // that just landed. Anything missing → scorerLine null → clean
            // fallback to the existing copy with no extra line.
            let scorerLine: string | null = null;
            if (side !== "both") {
              const scoringApiId = side === "home" ? homeApiId : awayApiId;
              const events = await fetchGoalEvents(fixtureId, apiFootballKey);
              scorerLine = formatScorerLine(pickLatestGoalForTeam(events, scoringApiId));
            }
            const copy = renderGoalPush({
              home: homeTeam,
              away: awayTeam,
              homeGoals: homeGoals ?? 0,
              awayGoals: awayGoals ?? 0,
              side,
              scorerLine,
            });
            goalPushSends += await sendWcPlayingTeamPush(supabase, {
              homeTeamId,
              awayTeamId,
              copy,
              category: "WC_GOAL",
              fixtureId,
              label: "goal",
            });
          }
        }

        // HALF-TIME — fire once on the literal break. Gated on status === "HT"
        // only (NOT "2H"): a "half-time" alert delivered mid-second-half reads
        // wrong, and 1-min polling always catches the ~15-min break. Decoupled
        // from liveBriefConfigured (the feed brief is a separate surface).
        // `prior.status !== "HT"` requires we OBSERVE the transition into the
        // break, so a deploy mid-break can't fire a late HT push.
        if (
          status === "HT" && prior !== null && prior.status !== "HT" &&
          !briefsFired.includes("HT_PUSH")
        ) {
          const copy = renderHalfTimePush({
            home: homeTeam,
            away: awayTeam,
            homeGoals: homeGoals ?? 0,
            awayGoals: awayGoals ?? 0,
          });
          await sendWcPlayingTeamPush(supabase, {
            homeTeamId,
            awayTeamId,
            copy,
            category: "WC_HALFTIME",
            fixtureId,
            label: "ht",
          });
          pushMarkers.push("HT_PUSH");
        }

        // FULL-TIME own-result — the gap that left tonight silent. Fire once
        // when we OBSERVE the live→finished transition. `!FINISHED_STATUSES
        // .has(prior.status)` is the first-observation guard (mirrors
        // `justFinished`): a deploy or re-observation of an already-finished
        // game can't fire a late FT push. Independent of the gd-matchday cap /
        // fired_finished_at logic (that routine path no-ops for WC).
        if (
          FINISHED_STATUSES.has(status) && prior !== null &&
          !FINISHED_STATUSES.has(prior.status as string) &&
          !briefsFired.includes("FT_PUSH")
        ) {
          const copy = renderFullTimePush({
            home: homeTeam,
            away: awayTeam,
            homeGoals: homeGoals ?? 0,
            awayGoals: awayGoals ?? 0,
          });
          await sendWcPlayingTeamPush(supabase, {
            homeTeamId,
            awayTeamId,
            copy,
            category: "WC_RESULT",
            fixtureId,
            label: "ft",
            // Deep-link each follower to their team's just-written result
            // article (populated in the post_match block above, same tick).
            contentIdByCountry: wcResultItemIds,
          });
          pushMarkers.push("FT_PUSH");
        }
      }
    }

    // Compute the updated briefs_fired array (append newTriggers + push
    // markers, dedupe). We write this into the upsert below so a second tick
    // within the same trigger window won't re-fire — even if the prior row
    // never existed (first-observation skip case is handled by the
    // `prior !== null` guard on trigger detection above).
    const updatedBriefsFired = [...new Set([...briefsFired, ...newTriggers, ...pushMarkers])];

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
          elapsed: elapsed ?? null,
          kickoff_time: kickoffTime,
          last_checked: new Date().toISOString(),
          briefs_fired: updatedBriefsFired,
          la_started: laStarted,
          la_sig: laSig,
          la_ended: laEnded,
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
      goal_push_sends: goalPushSends,
      upsert_errors: upsertErrors,
      date: today,
      active_leagues: activeLeagues,
      league_errors: leagueErrors,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
}
