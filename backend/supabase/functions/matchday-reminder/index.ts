// matchday-reminder/index.ts
//
// "His team plays" reminder push. Scheduled daily at 07:00 UTC (09:00
// Europe/Stockholm). For every ACTIVE entity (PL club today; WC country when a
// tournament is on) with a fixture kicking off within the next 24h, sends ONE
// deterministic reminder to that entity's followers, with the kickoff in
// the reader's own time (device_tokens.timezone, mig 082; London when unknown). PL never kicks off after midnight, so in practice this is
// "the morning of the match"; the 24h window is kept as a guard and the copy
// says "today"/"tomorrow" on its own.
//
// Source of truth (audit 2026-09, A27): API-Football fixtures for each active
// league, fetched live in this run — NOT team_season_state.next_fixtures. That
// column is written by a Claude routine; for WC countries it was written once
// (24 Jun 2026) with group-stage fixtures only, so the whole knockout stage got
// zero reminders; for PL clubs it carried 2025-26 data (A18). Fallback when the
// API call fails: match_status_state rows already in the window (match-watcher
// inserts today's fixtures from 00:00 UTC). Idempotent via
// matchday_reminders_sent (PK team_id + kickoff_time). Deterministic copy, zero
// Claude. morning-push checks matchday_reminders_sent and skips fixtures we
// already covered, so a follower never gets both.
//
// ?dry_run=1 reports what WOULD fire without claiming markers or sending — safe
// to invoke any time against live data.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { deactivateTokens, getSupabaseClient, isTokenDead } from "../_shared/supabase-client.ts";
import { mapWithConcurrency, PUSH_CONCURRENCY } from "../_shared/concurrency.ts";
import { buildAPNsPayload, sendPushNotification } from "../_shared/apns-client.ts";
import { renderMatchdayReminder, renderPreMatchBuildup, safeTz } from "../_shared/matchday-reminder-copy.ts";
import { preMatchVerdict, WC_FAVORITE_GAP } from "../_shared/matchup-verdict.ts";
import { seasonForLeague } from "../_shared/league-helpers.ts";

const WINDOW_MS = 24 * 60 * 60 * 1000;
const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";

/// One reminder candidate: OUR team, the opponent's display name, kickoff.
interface Candidate {
  teamId: string;
  opponent: string;
  opponentId: string | null;
  kickoff: Date;
  source: "api_football" | "match_status_state";
}

interface ApiFixtureLite {
  fixture: { id: number; date: string; status?: { short?: string } };
  teams: { home: { id: number; name: string }; away: { id: number; name: string } };
}

interface TeamRow {
  id: string;
  display_name: string;
  entity_type: string;
  league_id: number;
  api_football_id: number | null;
  strength_rank: number | null;
}

/// Fetch every fixture for `leagueId` kicking off in (now, windowEnd] from
/// API-Football. Returns null on any error so the caller can fall back.
async function fetchLeagueFixtures(
  leagueId: number,
  now: Date,
  windowEnd: Date,
  apiKey: string,
): Promise<ApiFixtureLite[] | null> {
  const from = now.toISOString().slice(0, 10);
  const to = windowEnd.toISOString().slice(0, 10);
  const season = seasonForLeague(leagueId);
  try {
    const resp = await fetch(
      `${API_FOOTBALL_BASE}/fixtures?league=${leagueId}&season=${season}&from=${from}&to=${to}`,
      { headers: { "x-apisports-key": apiKey } },
    );
    const json = await resp.json();
    if (!Array.isArray(json.response) || (json.errors && Object.keys(json.errors).length > 0)) {
      console.warn(`matchday-reminder: API-Football league=${leagueId} season=${season} errors=${JSON.stringify(json.errors ?? {})}`);
      return null;
    }
    return json.response as ApiFixtureLite[];
  } catch (e) {
    console.warn(`matchday-reminder: API-Football league=${leagueId} fetch failed:`, e instanceof Error ? e.message : String(e));
    return null;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  const denied = requireServiceAuth(req);
  if (denied) return denied;

  const dryRun = new URL(req.url).searchParams.get("dry_run") === "1";
  const supabase = getSupabaseClient();
  const now = new Date();
  const windowEnd = new Date(now.getTime() + WINDOW_MS);

  // Every ACTIVE entity with a league (audit 2026-09, A2/A27): PL clubs now,
  // WC countries only while a tournament is on (mig 079 flipped them inactive).
  const { data: teamRows, error: cErr } = await supabase
    .from("teams")
    .select("id, display_name, entity_type, league_id, api_football_id, strength_rank")
    .eq("is_active", true)
    .not("league_id", "is", null)
    .returns<TeamRow[]>();
  if (cErr) return json({ error: `teams query: ${cErr.message}` }, 500);
  const teams = teamRows ?? [];
  const nameById = new Map(teams.map((t) => [t.id, t.display_name]));
  const typeById = new Map(teams.map((t) => [t.id, t.entity_type]));
  const rankById = new Map(teams.map((t) => [t.id, t.strength_rank ?? null]));
  const idByApiId = new Map<number, string>(
    teams.filter((t) => t.api_football_id != null).map((t) => [t.api_football_id as number, t.id]),
  );
  const leagueIds = [...new Set(teams.map((t) => t.league_id))];
  if (teams.length === 0) return json({ reminders_sent: 0, note: "no active entities" });

  // Only bother with entities that actually have a follower — no point
  // claiming markers or rendering copy for teams nobody follows. Clubs are
  // followed via team_id/team_ids, countries via country_id/country_ids; union
  // all four (legacy scalars + V2.2 multi-follow arrays).
  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("team_id, team_ids, country_id, country_ids")
    .eq("is_active", true);
  // Used only to decide who gets the reminder PUSH. The build-up FEED item is
  // written for ALL entities with a fixture in window (below), independent of
  // followers, so the feed is populated for whatever team the user views.
  const followed = new Set<string>();
  for (const r of tokenRows ?? []) {
    if (r.team_id) followed.add(r.team_id as string);
    if (r.country_id) followed.add(r.country_id as string);
    for (const c of (r.team_ids as string[] | null) ?? []) followed.add(c);
    for (const c of (r.country_ids as string[] | null) ?? []) followed.add(c);
  }

  // ── Fixture source: API-Football per active league, match_status_state as
  //    fallback. One API call per league per day (Pro plan: 7 500/day).
  const apiKey = Deno.env.get("API_FOOTBALL_KEY") ?? "";
  const candidates: Candidate[] = [];
  const sourceByLeague: Record<string, string> = {};
  for (const leagueId of leagueIds) {
    const apiFixtures = apiKey ? await fetchLeagueFixtures(leagueId, now, windowEnd, apiKey) : null;
    if (apiFixtures) {
      sourceByLeague[String(leagueId)] = "api_football";
      for (const fx of apiFixtures) {
        const kickoff = new Date(fx.fixture.date);
        if (isNaN(kickoff.getTime()) || kickoff <= now || kickoff >= windowEnd) continue;
        const homeId = idByApiId.get(fx.teams.home.id) ?? null;
        const awayId = idByApiId.get(fx.teams.away.id) ?? null;
        // One candidate per OUR team in the fixture (a PL derby yields two —
        // each side's followers get their own reminder).
        if (homeId) {
          candidates.push({ teamId: homeId, opponent: awayId ? (nameById.get(awayId) ?? fx.teams.away.name) : fx.teams.away.name, opponentId: awayId, kickoff, source: "api_football" });
        }
        if (awayId) {
          candidates.push({ teamId: awayId, opponent: homeId ? (nameById.get(homeId) ?? fx.teams.home.name) : fx.teams.home.name, opponentId: homeId, kickoff, source: "api_football" });
        }
      }
      continue;
    }
    // Fallback: whatever match-watcher already wrote for the window. Covers
    // same-day fixtures (inserted from 00:00 UTC) but not tomorrow's early ones.
    sourceByLeague[String(leagueId)] = "match_status_state";
    const { data: stateRows } = await supabase
      .from("match_status_state")
      .select("home_team_id, away_team_id, kickoff_time")
      .eq("league_id", leagueId)
      .gt("kickoff_time", now.toISOString())
      .lt("kickoff_time", windowEnd.toISOString());
    for (const r of stateRows ?? []) {
      const kickoff = new Date(r.kickoff_time as string);
      const homeId = r.home_team_id as string;
      const awayId = r.away_team_id as string;
      if (nameById.has(homeId)) candidates.push({ teamId: homeId, opponent: nameById.get(awayId) ?? awayId, opponentId: awayId, kickoff, source: "match_status_state" });
      if (nameById.has(awayId)) candidates.push({ teamId: awayId, opponent: nameById.get(homeId) ?? homeId, opponentId: homeId, kickoff, source: "match_status_state" });
    }
  }

  let remindersSent = 0;
  const results: Array<Record<string, unknown>> = [];

  for (const cand of candidates) {
    const teamId = cand.teamId;
    const teamName = nameById.get(teamId) ?? teamId;
    const fx = { opponent: cand.opponent };
    const kickoff = cand.kickoff;
    {

      // ── A1: deterministic build-up FEED item (ALL countries) ──────────────
      // So a country's feed is never empty in the ~24h before a match, even for
      // RSS-starved nations the news routine skips. Idempotent via a stable
      // match_id (buildup-<kickoff epoch>); feed-only (the reminder push below
      // is the alert). Verdict comes from FIFA ranks when the opponent resolves.
      const oppId = cand.opponentId;
      const verdict = preMatchVerdict(
        rankById.get(teamId) ?? null,
        oppId ? (rankById.get(oppId) ?? null) : null,
        WC_FAVORITE_GAP,
      );
      const buildup = renderPreMatchBuildup({
        teamName,
        opponent: fx.opponent,
        kickoffUtc: kickoff,
        now,
        verdict: verdict?.tag ?? null,
      });
      const buildupMatchId = `buildup-${kickoff.getTime()}`;
      let buildupWritten = false;
      // The build-up floor exists for RSS-starved WC nations. PL clubs have a
      // full news routine, so keep their feeds free of deterministic filler
      // (audit 2026-09: scope of the A27 fix is the REMINDER, not feed volume).
      const wantsBuildup = typeById.get(teamId) === "country";
      if (!dryRun && wantsBuildup) {
        const { data: existing } = await supabase
          .from("content_items")
          .select("id")
          .eq("team_id", teamId)
          .eq("match_id", buildupMatchId)
          .limit(1)
          .maybeSingle();
        if (!existing) {
          const { error: insErr } = await supabase.from("content_items").insert({
            team_id: teamId,
            type: "news",
            match_id: buildupMatchId,
            headline: buildup.headline,
            body: buildup.body,
            talking_points: [buildup.talkingPoint],
            push_eligible: false,
            pipeline_source: "edge_function",
            status: "published",
            published_at: new Date().toISOString(),
          });
          if (!insErr) buildupWritten = true;
          else if (insErr.code !== "23505") {
            results.push({ team_id: teamId, kickoff: kickoff.toISOString(), buildup_error: insErr.message });
          }
        }
      }

      // ── Reminder PUSH — followed entities only ───────────────────────────
      const isFollowed = followed.has(teamId);
      // Default-zone copy for the dry-run report; real sends render per zone below.
      const copy = renderMatchdayReminder({ teamName, opponent: fx.opponent, kickoffUtc: kickoff, now });

      if (dryRun) {
        results.push({
          team_id: teamId,
          opponent: fx.opponent,
          kickoff: kickoff.toISOString(),
          buildup_headline: buildup.headline,
          followed: isFollowed,
          reminder_title: isFollowed ? copy.title : null,
          would_push: isFollowed,
        });
        continue;
      }

      if (!isFollowed) {
        results.push({ team_id: teamId, kickoff: kickoff.toISOString(), buildup: buildupWritten, followed: false });
        continue;
      }

      // Claim the reminder atomically. PK (team_id, kickoff_time): a duplicate
      // insert (23505) means we already reminded for this fixture — skip. This
      // survives cron retries and the same fixture returned by both sources.
      const { error: claimErr } = await supabase
        .from("matchday_reminders_sent")
        .insert({ team_id: teamId, kickoff_time: kickoff.toISOString() });
      if (claimErr) {
        if (claimErr.code === "23505") continue; // already sent
        results.push({ team_id: teamId, kickoff: kickoff.toISOString(), error: claimErr.message });
        continue;
      }

      // Send to this entity's followers: club via team_id/team_ids, country via
      // country_id/country_ids (legacy scalars OR V2.2 arrays). One row per
      // device (UNIQUE apns_token) → one push even if it follows both sides.
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("apns_token, apns_environment, timezone")
        .or(`team_id.eq.${teamId},team_ids.cs.{${teamId}},country_id.eq.${teamId},country_ids.cs.{${teamId}}`)
        .eq("is_active", true);

      // Mig 082: kickoff is rendered in each READER's zone. Followers cluster
      // into a handful of zones, so build one payload per zone (not per device)
      // and fan the sends out with bounded concurrency — the old sequential
      // loop blew the 400s wall-clock ceiling for a popular team at 50k
      // followers (SCALING_50K.md §1). Unknown/invalid zone → London (paying market).
      const payloadByTz = new Map<string, ReturnType<typeof buildAPNsPayload>>();
      const payloadFor = (tzRaw: string | null | undefined) => {
        const tz = safeTz(tzRaw);
        let p = payloadByTz.get(tz);
        if (!p) {
          const c = renderMatchdayReminder({ teamName, opponent: fx.opponent, kickoffUtc: kickoff, now, tz });
          p = buildAPNsPayload(
            "", // teamShortName fallback unused — pushTitle is set below
            c.body, // headline fallback
            `matchday-${teamId}-${kickoff.getTime()}`, // non-UUID sentinel: tap just opens the app
            "WC_MATCHDAY", // category string is not interpreted by iOS today; kept for log continuity
            false,
            c.body, // push_text
            c.title, // push_title
          );
          payloadByTz.set(tz, p);
        }
        return p;
      };
      const sendResults = await mapWithConcurrency(tokens ?? [], PUSH_CONCURRENCY, async (t) => {
        const env = t.apns_environment === "production" ? "production" : "development";
        const res = await sendPushNotification(t.apns_token as string, payloadFor(t.timezone as string | null), env);
        return { token: t.apns_token as string, res };
      });
      const zones = [...payloadByTz.keys()];
      await deactivateTokens(
        supabase,
        "device_tokens",
        sendResults.filter((r) => isTokenDead(r.res)).map((r) => r.token),
      );
      const sent = sendResults.filter((r) => r.res.success).length;

      remindersSent++;
      results.push({
        team_id: teamId,
        opponent: fx.opponent,
        kickoff: kickoff.toISOString(),
        tokens_sent: sent,
        timezones: zones,
        buildup: buildupWritten,
        source: cand.source,
      });
    }
  }

  return json({
    dry_run: dryRun,
    reminders_sent: remindersSent,
    candidates: candidates.length,
    fixture_source: sourceByLeague,
    count: results.length,
    results,
  });
});
