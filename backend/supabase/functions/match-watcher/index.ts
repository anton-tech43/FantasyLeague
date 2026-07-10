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
import { deactivateTokens, getSupabaseClient, isTokenDead } from "../_shared/supabase-client.ts";
import { mapWithConcurrency, PUSH_CONCURRENCY } from "../_shared/concurrency.ts";
import { seasonForLeague, FALLBACK_ACTIVE_LEAGUES } from "../_shared/league-helpers.ts";
import { detectConsequences, loadPostResultWcContext, WC_LEAGUE_ID } from "../_shared/detect-consequences.ts";
import { renderConsequence } from "../_shared/consequence-templates.ts";
import type { Team } from "../_shared/types.ts";
import { groupSituation } from "../_shared/stakes-engine.ts";
import { renderPostMatch, type PostMatchState } from "../_shared/stakes-templates.ts";
import { resultFraming, WC_FAVORITE_GAP } from "../_shared/matchup-verdict.ts";
import { decideMatchdayRetry, MATCHDAY_STALENESS_MS } from "../_shared/matchday-retry.ts";
import { buildAPNsPayload, sendLiveActivityPush, sendPushNotification } from "../_shared/apns-client.ts";
import { WC_COUNTRY_META, wcStatusLabel } from "../_shared/wc-countries.ts";
import {
  attachScorerPhotos,
  detectGoal,
  formatScorerLine,
  type GoalEvent,
  type GoalPushCopy,
  pickLatestGoalForTeam,
  renderFullTimePush,
  renderGoalPush,
  renderHalfTimePush,
  renderKickoffSoonPush,
  formatScorers,
  type StoredGoalEvent,
  toStoredGoalEvents,
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
  // Aggregate goals INCLUDING extra time; a penalty shootout never moves this
  // (its result lives only in score.penalty), so detectGoal stays quiet
  // through a shootout by construction.
  goals: { home: number | null; away: number | null };
  score?: {
    extratime?: { home: number | null; away: number | null } | null;
    penalty?: { home: number | null; away: number | null } | null;
  };
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
  comments?: string | null; // "Penalty Shootout" tags shootout kicks
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
    // Shootout kicks arrive as type "Goal" too but never move fx.goals; keep
    // them out of goal_events (a lagged tick observing a late ET goal during
    // the shootout would otherwise sweep them in as phantom scorers).
    if (typeof item.comments === "string" && item.comments.toLowerCase().includes("penalty shootout")) continue;
    const teamApiId = item.team?.id;
    if (typeof teamApiId !== "number") continue; // can't attribute → useless
    const rawMinute = item.time?.elapsed;
    const rawExtra = item.time?.extra;
    out.push({
      teamApiId,
      playerName: typeof item.player?.name === "string" ? item.player.name : null,
      playerApiId: typeof item.player?.id === "number" ? item.player.id : null,
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

/// True if any stored goal still lacks its scorer id. API-Football publishes a
/// goal's SCORE a beat before it fills in the player, so the goal-detection
/// tick can store an anonymous entry (player/id null). A later tick must
/// re-fetch to back-fill it, or the scorer stays "Goal" with no face forever
/// (seen live 2026-07-10: Merino's 88' vs Belgium).
function hasUnresolvedScorer(events: unknown): boolean {
  return Array.isArray(events) &&
    events.some((e) => e != null && typeof e === "object" &&
      (e as StoredGoalEvent).playerApiId == null);
}

/// One players lookup by provider id, stamping photo URLs onto stored events.
/// Shared by the goal-detection tick and the re-fetch-to-backfill path.
async function enrichPhotos(
  supabase: ReturnType<typeof getSupabaseClient>,
  stored: StoredGoalEvent[],
): Promise<StoredGoalEvent[]> {
  const ids = [
    ...new Set(
      stored.map((e) => e.playerApiId).filter((id): id is number => typeof id === "number"),
    ),
  ];
  if (ids.length === 0) return attachScorerPhotos(stored, new Map());
  const { data } = await supabase
    .from("players").select("api_player_id, photo_url").in("api_player_id", ids);
  return attachScorerPhotos(
    stored,
    new Map((data ?? []).map((r) => [r.api_player_id as number, (r.photo_url as string | null) ?? null])),
  );
}

/// Return prior goal_events with any anonymous scorer back-filled from a fresh
/// /fixtures/events fetch. No unresolved entry → returns prior unchanged, no
/// fetch (so this is free on the common path). A fetch that comes back empty
/// or still-anonymous falls back to prior rather than losing data.
async function resolveScorers(
  supabase: ReturnType<typeof getSupabaseClient>,
  fixtureId: number,
  apiKey: string,
  priorEvents: StoredGoalEvent[] | null | undefined,
  homeApiId: number,
  awayApiId: number,
): Promise<StoredGoalEvent[] | null> {
  if (!hasUnresolvedScorer(priorEvents)) return priorEvents ?? null;
  const fresh = toStoredGoalEvents(await fetchGoalEvents(fixtureId, apiKey), homeApiId, awayApiId);
  if (fresh.length === 0) return priorEvents ?? null;
  return await enrichPhotos(supabase, fresh);
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
    // Match a device that follows either playing country via the legacy scalar
    // (old apps) OR the multi-follow array (new apps). One row per device
    // (UNIQUE apns_token) so a device that follows BOTH playing countries still
    // appears once → one push.
    const playing = `${args.homeTeamId},${args.awayTeamId}`;
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("apns_token, country_id, country_ids, apns_environment")
      .or(`country_id.in.(${playing}),country_ids.ov.{${playing}}`)
      .eq("is_active", true);

    // Per-country tallies so we can write one apns_send pipeline_health row per
    // playing team — the live goal/HT/FT/kickoff pushes were previously invisible
    // to audits (only the briefs_fired markers proved a push was attempted, never
    // whether APNs accepted it). This is how the 429 was caught for the sweep
    // pushes; now the live pushes get the same visibility.
    // Resolve each device to the followed country + its perspective copy
    // FIRST (pure, fast), skipping devices that matched only on a stale scalar
    // or have no body for this match. Then fan the sends out with bounded
    // concurrency — a marquee country's goal could reach tens of thousands of
    // followers, and the old sequential loop blew the 400s wall-clock ceiling
    // mid-match (SCALING_50K.md §1). This runs on the every-minute tick, so it
    // MUST stay sub-minute.
    type Recipient = {
      token: string;
      country: string;
      payload: ReturnType<typeof buildAPNsPayload>;
      env: "development" | "production";
    };
    const recipients: Recipient[] = [];
    for (const t of tokens ?? []) {
      // Which of THIS device's followed countries is in the match decides the
      // perspective copy. Prefer home when a device follows both sides (they
      // play each other) so the single push is deterministic.
      const followed = (t.country_ids as string[] | null) ??
        (t.country_id ? [t.country_id as string] : []);
      const country = followed.includes(args.homeTeamId)
        ? args.homeTeamId
        : followed.includes(args.awayTeamId)
        ? args.awayTeamId
        : null;
      if (!country) continue; // matched on stale scalar only — not actually following
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
      recipients.push({ token: t.apns_token as string, country, payload, env });
    }

    const results = await mapWithConcurrency(recipients, PUSH_CONCURRENCY, async (r) => {
      const res = await sendPushNotification(r.token, r.payload, r.env);
      return { country: r.country, token: r.token, res };
    });

    // Tally per country (for the per-country pipeline_health rows) and collect
    // every dead token for ONE batched deactivation instead of an UPDATE each.
    const stats = new Map<string, { sent: number; failed: number; reason?: string; status?: number }>();
    let sent = 0;
    const deadTokens: string[] = [];
    for (const { country, token, res } of results) {
      if (isTokenDead(res)) deadTokens.push(token);
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
    await deactivateTokens(supabase, "device_tokens", deadTokens);

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
      .select("status, home_goals, away_goals, fired_finished_at, briefs_fired, matchday_fire_capped, la_started, la_sig, la_ended, goal_events")
      .eq("fixture_id", fixtureId)
      .maybeSingle();

    // Only fire when we OBSERVE a transition firsthand.
    // First observation never fires (avoids mass-fire on initial deploy).
    // matchday_fire_capped (mig 042) now means "abandoned as stale" — set only
    // once the match is too old for a matchday push; see retry policy below.
    const justFinished =
      FINISHED_STATUSES.has(status) &&
      prior !== null &&
      !prior.fired_finished_at &&
      !prior.matchday_fire_capped;

    // Retry policy for matchday_fire. Migration 042's original cap gave up
    // PERMANENTLY after 5 failures / 2h and needed a manual re-fire — the wrong
    // trade-off for a team that won't touch RUNBOOK.md by hand. We now use
    // spaced backoff + a staleness deadline (see _shared/matchday-retry.ts):
    // the every-minute flood is still gone, but when the routine API recovers
    // (daily quota reset, outage clears) the next spaced attempt lands the
    // content on its own. matchday_fire_capped is now set ONLY when the match
    // is too old to matter, as a terminal marker for the SLA heartbeat.
    //
    // pipeline_health is the source of truth for attempt history. Query both
    // perspective targets (matchday_fire:<team>:<fixture>) over the staleness
    // window; backoff escalates off whichever perspective has failed most.
    let matchdayWentStale = false;
    let matchdayBackoffHold = false;
    if (justFinished) {
      const lookbackIso = new Date(Date.now() - MATCHDAY_STALENESS_MS).toISOString();
      const { data: priorFailures } = await supabase
        .from("pipeline_health")
        .select("target, created_at")
        .eq("stage", "matchday_fire")
        .eq("status", "failure")
        .like("target", `matchday_fire:%:${fixtureId}`)
        .gte("created_at", lookbackIso);
      const failuresByTarget = new Map<string, number[]>();
      for (const r of priorFailures ?? []) {
        const tsList = failuresByTarget.get(r.target) ?? [];
        tsList.push(new Date(r.created_at).getTime());
        failuresByTarget.set(r.target, tsList);
      }
      const decision = decideMatchdayRetry({
        nowMs: Date.now(),
        kickoffMs: new Date(kickoffTime).getTime(),
        failureTimesByTarget: [...failuresByTarget.values()],
      });
      matchdayWentStale = decision.action === "stale";
      matchdayBackoffHold = decision.action === "hold";
      if (matchdayWentStale) {
        console.log(
          `matchday_fire abandoned for fixture ${fixtureId}: match older than ` +
          `staleness deadline, a "just finished" push no longer makes sense`,
        );
        // Terminal marker + one visible pipeline_health row so a postmortem
        // shows WHY we stopped (vs a silent give-up). Best-effort.
        try {
          await supabase.from("pipeline_health").insert({
            stage: "matchday_fire",
            status: "failure",
            target: `matchday_fire:abandoned:${fixtureId}`,
            error_class: "abandoned_stale",
            message: "Backoff exhausted past staleness deadline; capped, no re-fire",
          });
        } catch (_e) { /* observability is best-effort */ }
      } else if (matchdayBackoffHold) {
        console.log(
          `matchday_fire holding for fixture ${fixtureId}: inside backoff ` +
          `window, will retry automatically`,
        );
      }
    }

    const shouldFireMatchday = justFinished && !matchdayWentStale && !matchdayBackoffHold;

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
    // Live-box scorers (068): set ONLY on a tick that fetched /fixtures/events
    // (i.e. a detected goal). Stays null on quiet ticks so the upsert leaves
    // match_status_state.goal_events untouched rather than clobbering it.
    let goalEventsStored: StoredGoalEvent[] | null = null;
    // PUSH-2: WC alert pushes (goal/HT/FT/kickoff) are COLLECTED here and fired
    // only AFTER the end-of-tick state upsert succeeds — so a failed upsert can
    // never leave us having pushed without persisting the marker/score (which
    // would re-fire duplicate alerts next tick). At-most-once by construction:
    // a send failure after a good upsert is a missed push, never a duplicate.
    const pendingAlertPushes: Array<{
      args: Parameters<typeof sendWcPlayingTeamPush>[1];
      isGoal: boolean;
    }> = [];
    // Tournament-feed rows (team_id='world_championship', migration 076).
    // Collected like pendingAlertPushes and inserted only AFTER the state
    // upsert succeeds — same at-most-once discipline. Double-guarded: the
    // UNIQUE(team_id, match_id) constraint makes any re-detected insert a
    // 23505 no-op.
    const pendingTournamentItems: Array<Record<string, unknown>> = [];

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
            // wcCtx is null for knockout rounds (group math doesn't apply) —
            // but knockouts still need result items, with stakes copy instead
            // of group-situation prose. Round convention as detect-consequences
            // (empty/missing round conservatively counts as group stage, and
            // with wcCtx also null nothing fires — no phantom knockout copy).
            const roundLc = (fx.league?.round ?? "").toLowerCase();
            const isKnockoutRound = roundLc.length > 0 && !roundLc.includes("group");
            if (wcCtx || isKnockoutRound) {
              const hg = homeGoals ?? 0;
              const ag = awayGoals ?? 0;
              // Shootout / extra-time awareness: knockouts finish AET or PEN,
              // and level goals after a shootout are a WIN, not a draw.
              const pen = fx.score?.penalty;
              const pens = status === "PEN" &&
                  typeof pen?.home === "number" && typeof pen?.away === "number" &&
                  pen.home !== pen.away
                ? { home: pen.home, away: pen.away }
                : null;
              const aet = status === "AET";
              // true = home won, false = away won, null = draw (group stage,
              // or a PEN row whose shootout scores the API hasn't filled yet).
              const homeWon: boolean | null = pens
                ? pens.home > pens.away
                : hg > ag
                  ? true
                  : hg < ag
                    ? false
                    : null;
              const pw = pens ? Math.max(pens.home, pens.away) : 0;
              const pl = pens ? Math.min(pens.home, pens.away) : 0;
              // Neutral, winner-first result for the shared "Football" feed
              // (the single item everyone sees), carried by the home row below.
              const winName = homeWon ? fx.teams.home.name : fx.teams.away.name;
              const loseName = homeWon ? fx.teams.away.name : fx.teams.home.name;
              const neutralResult = homeWon === null
                ? `${fx.teams.home.name} and ${fx.teams.away.name} drew ${hg}-${ag}`
                : pens && hg === ag
                  ? `${winName} beat ${loseName} ${pw}-${pl} on penalties after a ${hg}-${ag} draw`
                  : `${winName} beat ${loseName} ${homeWon ? hg : ag}-${homeWon ? ag : hg}${aet ? " after extra time" : ""}`;

              const playing = [
                { slug: homeTeamId, apiId: fx.teams.home.id, name: fx.teams.home.name, oppName: fx.teams.away.name, gf: hg, ga: ag, won: homeWon },
                { slug: awayTeamId, apiId: fx.teams.away.id, name: fx.teams.away.name, oppName: fx.teams.home.name, gf: ag, ga: hg, won: homeWon === null ? null : !homeWon },
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
              // Goal scorers + minutes for the post-game article (075). Read the
              // list persisted during the match, but re-fetch events first if a
              // late goal's scorer never resolved (a stoppage-time goal whose
              // player the API published after the last live tick — otherwise
              // the FT summary shows "Goal" with no face forever). No unresolved
              // scorer → no fetch. Persist the corrected list so the live/FT
              // surfaces agree.
              const resolvedFtEvents = await resolveScorers(
                supabase,
                fixtureId,
                apiFootballKey,
                prior?.goal_events as StoredGoalEvent[] | null | undefined,
                homeApiId,
                awayApiId,
              );
              if (resolvedFtEvents !== (prior?.goal_events ?? null)) {
                goalEventsStored = resolvedFtEvents;
              }
              const ftScorers = formatScorers(
                resolvedFtEvents,
                fx.teams.home.name,
                fx.teams.away.name,
              );
              for (const p of playing) {
                const state: PostMatchState = p.won === null ? "draw" : p.won ? "win" : "loss";
                const isHome = p.slug === homeTeamId;
                const perspectiveHeadline = pens && state !== "draw" && p.gf === p.ga
                  ? (state === "win"
                    ? `${p.name} beat ${p.oppName} ${pw}-${pl} on penalties`
                    : `${p.name} lost ${pl}-${pw} on penalties to ${p.oppName}`)
                  : state === "win"
                    ? `${p.name} beat ${p.oppName} ${p.gf}-${p.ga}${aet ? " after extra time" : ""}`
                    : state === "loss"
                      ? `${p.name} lost ${p.gf}-${p.ga} to ${p.oppName}${aet ? " after extra time" : ""}`
                      : `${p.name} drew ${p.gf}-${p.ga} with ${p.oppName}`;

                // The feed article: group stage keeps renderPostMatch's
                // situation-aware prose + team_pages card; knockouts (no group
                // math) get result + a deterministic stakes line. "Final" must
                // be the literal round name — semis and the 3rd place match
                // also contain the word.
                let baseBody: string;
                let talkingPoint: string;
                if (wcCtx) {
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
                  baseBody = pm.text;
                  talkingPoint = pm.talking_point;
                } else {
                  // Round-aware stakes: a semi loser still has the 3rd place
                  // match, and the bronze match has no "next round" — generic
                  // through/over copy is factually wrong for both.
                  const isFinal = roundLc.trim() === "final";
                  const isSemi = roundLc.includes("semi");
                  const isBronze = roundLc.includes("3rd") || roundLc.includes("third");
                  const stakes = state === "draw"
                    ? null // PEN row missing shootout data — claim nothing wrong
                    : state === "win"
                      ? (isFinal
                        ? "They are champions of the world."
                        : isBronze
                          ? "They finish third in the world."
                          : "They are through to the next round.")
                      : (isFinal
                        ? "Beaten in the final."
                        : isSemi
                          ? "They will play for third place."
                          : isBronze
                            ? "They finish fourth."
                            : "Their World Championship is over.");
                  baseBody = stakes ? `${perspectiveHeadline}. ${stakes}` : `${perspectiveHeadline}.`;
                  talkingPoint = state === "draw"
                    ? "It went the full distance. Ask him how he got through it."
                    : state === "win"
                      ? (isFinal
                        ? "His team are world champions. This is as big as it gets."
                        : isBronze
                          ? "Third place at a World Championship. Ask him if that softens it."
                          : "Ask him how far he thinks they can go now.")
                      : (isFinal
                        ? "So close. He will not forget this one for a while."
                        : isSemi
                          ? "The final slipped away, but there is still a medal match. Ask him if he can face it."
                          : isBronze
                            ? "Fourth in the world stings. He might need a minute."
                            : "Their run is over. He might need a minute.");
                }

                // B3: append the ranking framing to this team's result body.
                const oppSlug = p.slug === homeTeamId ? awayTeamId : homeTeamId;
                const framing = resultFraming(
                  rankBySlug.get(p.slug) ?? null,
                  rankBySlug.get(oppSlug) ?? null,
                  p.gf,
                  p.ga,
                  WC_FAVORITE_GAP,
                );
                const resultBody = framing ? `${baseBody} ${framing.note}` : baseBody;
                const { data: inserted, error: itemErr } = await supabase
                  .from("content_items")
                  .insert({
                    team_id: p.slug,
                    type: "matchday",
                    match_id: String(fixtureId),
                    match_result: perspectiveHeadline,
                    headline: perspectiveHeadline,
                    body: resultBody,
                    talking_points: [talkingPoint],
                    // The lock-screen alert is sent directly by the FT push
                    // below; this feed article must NOT be re-pushed by
                    // notification-sender's sweep (double-ping). Feed-only.
                    push_eligible: false,
                    goal_events: ftScorers.length > 0 ? ftScorers : null,
                    everyone_talking: isHome,
                    everyone_talking_headline: isHome ? neutralResult : null,
                    everyone_talking_body: isHome
                      ? `${neutralResult}. ${wcCtx ? "Full-time in their World Championship group." : "Full-time at the World Championship."}`
                      : null,
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

              // Tournament-feed neutral result (076): same neutral copy +
              // photo-bearing scorers, one row on the shared feed. Inserted
              // post-upsert like the alert pushes (at-most-once).
              pendingTournamentItems.push({
                team_id: "world_championship",
                type: "matchday",
                match_id: String(fixtureId),
                match_result: neutralResult,
                headline: neutralResult,
                body: `${neutralResult}. Full-time at the World Championship.`,
                goal_events: ftScorers.length > 0 ? ftScorers : null,
                affected_team_ids: [homeTeamId, awayTeamId],
                push_eligible: false,
                everyone_talking: false,
                status: "published",
                published_at: new Date().toISOString(),
              });
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
          const list = rows ?? [];
          if (list.length === 0) return;
          // Bounded-concurrency fan-out: a big live match can have thousands of
          // active Live Activities, and this fires every tick — it must stay
          // sub-minute (SCALING_50K.md §1).
          const sent = await mapWithConcurrency(list, PUSH_CONCURRENCY, (r) =>
            sendLiveActivityPush(r.token, {
              ...opts,
              environment: r.apns_environment === "production" ? "production" : "development",
            }).then((res) => ({ token: r.token, res })),
          );
          // Clean up tokens APNs reported dead (410/400) in one UPDATE so a
          // stale Live Activity token stops being pushed on every tick.
          await deactivateTokens(
            supabase,
            "live_activity_tokens",
            sent.filter((s) => isTokenDead(s.res)).map((s) => s.token),
          );
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
          // Knockout matches start EVERY device's activity, not just the two
          // countries' followers — from the round of 32 on, every game matters
          // to everyone. Round convention mirrors detect-consequences: an
          // empty/missing round stays follower-scoped (safe default).
          const round = (fx.league?.round ?? "").toLowerCase();
          const isKnockout = round.length > 0 && !round.includes("group");
          let ptsQuery = supabase
            .from("live_activity_tokens")
            .select("token, apns_environment")
            .eq("kind", "push_to_start").eq("is_active", true);
          if (!isKnockout) {
            ptsQuery = ptsQuery
              .or(`country_id.in.(${homeTeamId},${awayTeamId}),country_ids.ov.{${homeTeamId},${awayTeamId}}`);
          }
          const { data: ptsTokens } = await ptsQuery;
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
          pendingAlertPushes.push({
            args: {
              homeTeamId,
              awayTeamId,
              copy,
              category: "WC_KICKOFF_SOON",
              fixtureId,
              label: "kickoff",
            },
            isGoal: false,
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
            // now, on a real goal — never every poll (quota). The full parsed
            // list is also stored on the row (068) so the in-app live box can
            // show who scored and when without re-hitting the API on its 60s
            // read poll. When BOTH sides scored in one tick (side === "both")
            // we can't honestly name a single scorer for the PUSH, so we skip
            // the scorer line there and keep the rotating copy — but we still
            // store the list. The scoring side's API team id (home vs away)
            // tells pickLatest... which goal to surface; the latest (highest
            // minute) is the one that just landed. Anything missing → scorerLine
            // null → clean fallback to the existing copy with no extra line.
            const events = await fetchGoalEvents(fixtureId, apiFootballKey);
            // Scorer photos (077): stamped by enrichPhotos (one players lookup
            // by provider id, CDN-URL fallback) so the live box and the FT
            // articles that copy this list render faces with no join.
            goalEventsStored = await enrichPhotos(
              supabase,
              toStoredGoalEvents(events, homeApiId, awayApiId),
            );
            let scorerLine: string | null = null;
            if (side !== "both") {
              const scoringApiId = side === "home" ? homeApiId : awayApiId;
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
            pendingAlertPushes.push({
              args: {
                homeTeamId,
                awayTeamId,
                copy,
                category: "WC_GOAL",
                fixtureId,
                label: "goal",
              },
              isGoal: true,
            });

            // NOTE: goals deliberately do NOT create per-goal tournament feed
            // rows. The in-feed LiveMatchCard (live-brief-current, 60s poll)
            // already shows the running score + every scorer with their photo,
            // updating in place — one live item, not one row per goal. Separate
            // "GOAL! x-y" rows just duplicated it and cluttered the feed. The
            // goal PUSH above still fires; the FT result row (below) carries the
            // final scorers for the post-match feed.
          } else if (hasUnresolvedScorer(prior.goal_events)) {
            // No new goal this tick, but a prior goal is still anonymous
            // (API-Football hadn't published its scorer when it was detected).
            // Re-fetch to back-fill so the live box resolves "Goal" → the name
            // within a minute, and the persisted list is correct before FT.
            goalEventsStored = await resolveScorers(
              supabase,
              fixtureId,
              apiFootballKey,
              prior.goal_events as StoredGoalEvent[] | null | undefined,
              homeApiId,
              awayApiId,
            );
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
          pendingAlertPushes.push({
            args: {
              homeTeamId,
              awayTeamId,
              copy,
              category: "WC_HALFTIME",
              fixtureId,
              label: "ht",
            },
            isGoal: false,
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
          // Shootout awareness: after PEN the goals are level but the match
          // has a winner — pass the shootout score so the winner's followers
          // never get "drew 1-1" copy.
          const ftPen = fx.score?.penalty;
          const copy = renderFullTimePush({
            home: homeTeam,
            away: awayTeam,
            homeGoals: homeGoals ?? 0,
            awayGoals: awayGoals ?? 0,
            pens: status === "PEN" &&
                typeof ftPen?.home === "number" && typeof ftPen?.away === "number" &&
                ftPen.home !== ftPen.away
              ? { home: ftPen.home, away: ftPen.away }
              : null,
          });
          pendingAlertPushes.push({
            args: {
              homeTeamId,
              awayTeamId,
              copy,
              category: "WC_RESULT",
              fixtureId,
              label: "ft",
              // Deep-link each follower to their team's just-written result
              // article (populated in the post_match block above, same tick).
              contentIdByCountry: wcResultItemIds,
            },
            isGoal: false,
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
          // Only write goal_events on a tick that fetched them (a detected
          // goal). The conditional spread below leaves the column untouched on
          // quiet ticks so a populated list is never clobbered with null.
          ...(goalEventsStored ? { goal_events: goalEventsStored } : {}),
          la_started: laStarted,
          la_sig: laSig,
          la_ended: laEnded,
          ...(matchdayWentStale
            ? { matchday_fire_capped: true }
            : {}),
          ...(bothFiresOk
            ? { fired_finished_at: new Date().toISOString() }
            : {}),
        },
        { onConflict: "fixture_id" },
      );
    if (upsertErr) {
      // State did NOT advance. Skip every collected alert push — they will be
      // re-decided identically next tick once the row is observed again. This is
      // what makes the pushes at-most-once: we never send on a tick whose state
      // we couldn't persist (which would re-fire next tick = duplicate alerts).
      console.warn(
        `state upsert failed for ${fixtureId}; skipping ${pendingAlertPushes.length} alert push(es):`,
        upsertErr.message,
      );
      upsertErrors.push({ fixture_id: fixtureId, message: upsertErr.message });
    } else {
      stateUpdates++;
      if (!prior) firstSeen++;
      // State (markers + score) is durably persisted — now safe to fire.
      for (const item of pendingTournamentItems) {
        const { error: tErr } = await supabase.from("content_items").insert(item);
        if (tErr && tErr.code !== "23505") {
          // 23505 = already on the tournament feed (idempotent no-op).
          console.error(`tournament item insert failed for ${fixtureId} (non-fatal):`, tErr.message);
        }
      }
      for (const p of pendingAlertPushes) {
        const n = await sendWcPlayingTeamPush(supabase, p.args);
        if (p.isGoal) goalPushSends += n;
      }
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
