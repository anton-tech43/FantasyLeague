// morning-push/index.ts
// Goal Digger — Daily 08:00 UTC "Game day at <team>" push.
//
// Why: GoalDigger's other notifications are reactive (matchday brief
// after FT, live brief at HT, sunday brief on Sunday morning, news
// when something newsworthy lands). Users wanted a PROactive heads-up
// the morning of a game: "Hey, today is game day, kickoff is at X."
// Not generated content — purely templated, no LLM call.
//
// Schedule: pg_cron `0 8 * * *` UTC (migration 048). 08:00 UTC =
// ~09:00 BST / ~10:00 CEST — good for the UK + EU audience. Per-user
// timezone scheduling is V2.1.
//
// Pipeline:
//   1. Read fixtures kicking off in the next 18h from data-fetcher's cache
//      (raw_fetch_logs fixtures_next). It read match_status_state until
//      2026-10-04, which since migration 094 is empty at 08:00 (match-watcher
//      polls from 35 min before kickoff), so this push never fired (QA-06).
//   2. For each fixture, find subscribed device_tokens for either team.
//   3. Build a templated APNs payload — title "Game day at <Team>",
//      body "<Home> vs <Away> at <HH:mm tz>. He'll be glued to it."
//   4. Send via the existing sendPushNotification helper.
//   5. Log each (token, fixture) attempt to pipeline_health with
//      stage='morning_push'. Dedupe via target uniqueness — we don't
//      want to double-push if the cron is invoked twice in a window.
//
// No content_items row is created — this is push-only, the team page's
// Calendar tab is where the user goes to see the fixture details.

import { competitionProse, COVERED_CUP_LEAGUES } from "../_shared/league-helpers.ts";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { deactivateTokens, fetchAllRows, getSupabaseClient, isTokenDead } from "../_shared/supabase-client.ts";
import { cachedUpcomingFixtures } from "../_shared/cached-fixtures.ts";
import { mapWithConcurrency, PUSH_CONCURRENCY } from "../_shared/concurrency.ts";
import { sendPushNotification, buildAPNsPayload } from "../_shared/apns-client.ts";
import { hhmm, safeTz } from "../_shared/matchday-reminder-copy.ts";
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";

interface Fixture {
  fixture_id: number;
  league_id: number | null;
  home_team_id: string;
  away_team_id: string;
  kickoff_time: string;
}

interface Team {
  id: string;
  display_name: string;
  short_name: string | null;
  entity_type: string | null;
  api_football_id?: number | null;
  is_active?: boolean;
  league_id?: number | null;
}

/// Format kickoff as "HH:MM" in the READER's zone (device_tokens.timezone,
/// mig 082; London when unknown). Until Sept 2026 this rendered London time
/// with a BST/GMT suffix for everyone (audit 2026-09, A5). No suffix: the time
/// is in her own zone, so a suffix would only add noise.
function formatKickoff(iso: string, tz: string): string {
  return hhmm(new Date(iso), safeTz(tz));
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
    // 18-hour window: 08:00 UTC fire catches fixtures kicking off until
    // 02:00 UTC next day. Covers UK / EU evening + late-night kickoffs.
    const now = new Date();
    const windowEnd = new Date(now.getTime() + 18 * 60 * 60 * 1000);

    // Our entities by API id. Every known club, active or not: a cup opponent
    // is in `teams` (inactive) so the tie resolves, exactly as match-watcher
    // maps it. A fixture is ours when at least one side is ACTIVE.
    const { data: teamRows, error: teamsErr } = await supabase
      .from("teams")
      .select("id, display_name, short_name, entity_type, api_football_id, is_active, league_id")
      .not("api_football_id", "is", null)
      .neq("entity_type", "tournament")
      .returns<Team[]>();
    if (teamsErr) {
      console.error("morning-push: teams query failed:", teamsErr);
      return new Response(JSON.stringify({ error: teamsErr.message }), { status: 500 });
    }
    const teamByApiId = new Map<number, Team>((teamRows ?? []).map((t) => [t.api_football_id as number, t]));
    // The competitions matchday-reminder covers (and match_status_state used to
    // hold): home leagues of active entities plus the cups. A mid-season
    // friendly in the cache is not "game day".
    const leagues = new Set<number>([
      ...(teamRows ?? []).filter((t) => t.is_active && t.league_id != null).map((t) => t.league_id as number),
      ...COVERED_CUP_LEAGUES,
    ]);

    let cached;
    try {
      cached = await cachedUpcomingFixtures(supabase);
    } catch (e) {
      const message = (e as Error).message;
      console.error("morning-push:", message);
      return new Response(JSON.stringify({ error: message }), { status: 500 });
    }
    const fixtures: Array<Fixture & { home: Team; away: Team }> = [];
    for (const f of cached) {
      const kickoff = new Date(f.fixture.date);
      if (isNaN(kickoff.getTime()) || kickoff < now || kickoff > windowEnd) continue;
      if (!leagues.has(f.league?.id as number)) continue;
      // An opponent never seen before (a first cup tie) has no row yet; name it
      // from the feed. Its synthetic id matches no follower.
      const side = (t: { id: number; name: string }): Team =>
        teamByApiId.get(t.id) ??
          { id: `api_${t.id}`, display_name: t.name, short_name: t.name, entity_type: "club", is_active: false };
      const home = side(f.teams.home);
      const away = side(f.teams.away);
      if (!home.is_active && !away.is_active) continue;
      fixtures.push({
        fixture_id: f.fixture.id,
        league_id: f.league?.id ?? null,
        home_team_id: home.id,
        away_team_id: away.id,
        kickoff_time: kickoff.toISOString(),
        home,
        away,
      });
    }
    fixtures.sort((a, b) => a.kickoff_time.localeCompare(b.kickoff_time));

    if (fixtures.length === 0) {
      // Log so silence-on-a-match-day is distinguishable from
      // "genuinely no fixtures today" when reading the cron logs.
      console.log("morning-push: no fixtures in next 18h, nothing to push");
      return new Response(JSON.stringify({ success: true, fixtures: 0, pushes: 0 }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    let totalPushes = 0;
    let totalFailures = 0;

    for (const fix of fixtures) {
      const { home, away } = fix;

      // PUSH-8: WC country fixtures are owned by matchday-reminder (07:00 UTC).
      // Skip them here so a followed country doesn't get that reminder AND this
      // "Game day at X" push an hour apart. morning-push covers PL clubs only.
      if (home.entity_type === "country" || away.entity_type === "country") continue;

      // Audit 2026-09 (A2/A27): matchday-reminder now covers PL clubs too, with
      // Stockholm kickoff times. If it already claimed this fixture for either
      // side (matchday_reminders_sent, 07:00 UTC run), skip here so nobody gets
      // two "game day" pushes an hour apart. morning-push stays as the fallback
      // for the morning the reminder run failed.
      const { data: claimed } = await supabase
        .from("matchday_reminders_sent")
        .select("team_id")
        .eq("kickoff_time", fix.kickoff_time)
        .in("team_id", [fix.home_team_id, fix.away_team_id])
        .limit(1);
      if (claimed && claimed.length > 0) {
        console.log(`morning-push: ${fix.home_team_id} v ${fix.away_team_id} already reminded by matchday-reminder, skipping`);
        continue;
      }

      // Tokens subscribed to EITHER team (PL via team_id, WC via country_id).
      // Same .or() filter as notification-sender — legacy scalar OR the V2.2
      // multi-follow arrays. One row per device → one push.
      // Paged (QA-04): one PostgREST response caps at 1000 rows.
      const teams = `${fix.home_team_id},${fix.away_team_id}`;
      let tokens: Array<Record<string, unknown>>;
      try {
        tokens = await fetchAllRows((from, to) =>
          supabase
            .from("device_tokens")
            .select("apns_token, apns_environment, team_id, country_id, team_ids, country_ids, timezone")
            .or(
              `team_id.eq.${fix.home_team_id},country_id.eq.${fix.home_team_id},` +
              `team_id.eq.${fix.away_team_id},country_id.eq.${fix.away_team_id},` +
              `team_ids.ov.{${teams}},country_ids.ov.{${teams}}`,
            )
            .eq("is_active", true)
            .order("apns_token")
            .range(from, to)
        );
      } catch (e) {
        console.error(`morning-push: device_tokens read failed for fixture ${fix.fixture_id}:`, (e as Error).message);
        totalFailures++;
        continue;
      }

      if (tokens.length === 0) continue;

      // Body name-drops both teams + kickoff time, then teases the lineup as a
      // conversation starter — lineups drop ~60min before kickoff per
      // API-Football's publication cadence. Fixture-constant except the kickoff
      // clock, which is rendered in each reader's zone (mig 082) — memoised per
      // zone since followers cluster into a few zones. Resolve payloads first,
      // then fan out with bounded concurrency (SCALING_50K.md §1).
      const bodyByTz = new Map<string, string>();
      const bodyFor = (tzRaw: string | null | undefined): string => {
        const tz = safeTz(tzRaw);
        let b = bodyByTz.get(tz);
        if (!b) {
          // The competition, when it is not the league. A cup morning read
          // exactly like a Premier League Saturday before this, which is the
          // one thing this push exists to tell her.
          const comp = COVERED_CUP_LEAGUES.includes(fix.league_id as number)
            ? `${competitionProse(fix.league_id as number)}. `
            : "";
          b = `${comp}${home.display_name} vs ${away.display_name} at ${formatKickoff(fix.kickoff_time, tz)}. ` +
            `Lineups drop an hour before, a good thing to ask about.`;
          bodyByTz.set(tz, b);
        }
        return b;
      };

      type Recipient = {
        token: string;
        payload: ReturnType<typeof buildAPNsPayload>;
        env: "development" | "production";
      };
      const recipients: Recipient[] = [];
      for (const tk of tokens) {
        // Pick which team this user follows so the title says "Game day at
        // Arsenal" (not "Game day at Burnley") when the user is an Arsenal
        // subscriber. Falls back to home team if both match. V2.2: check the
        // legacy scalars AND the multi-follow arrays.
        const follows = new Set<string>([
          ...((tk.team_ids as string[] | null) ?? (tk.team_id ? [tk.team_id as string] : [])),
          ...((tk.country_ids as string[] | null) ??
            (tk.country_id ? [tk.country_id as string] : [])),
        ]);
        const followsHome = follows.has(fix.home_team_id);
        const followsAway = follows.has(fix.away_team_id);
        const subject = followsHome ? home : (followsAway ? away : home);
        const title = `Game day at ${subject.short_name ?? subject.display_name}`;
        const body = bodyFor(tk.timezone as string | null);
        // contentId here is the fixture_id (not a content_items UUID); iOS uses
        // it as a deep-link key to the team page Calendar tab.
        const payload = buildAPNsPayload(
          subject.short_name ?? subject.display_name,
          body,
          `fixture:${fix.fixture_id}`,
          "MATCHDAY_HEADS_UP",
          false,
          body,
          title,
        );
        const env = (tk.apns_environment === "production" ? "production" : "development") as
          | "development" | "production";
        recipients.push({ token: tk.apns_token as string, payload, env });
      }

      const results = await mapWithConcurrency(recipients, PUSH_CONCURRENCY, async (r) => {
        const res = await sendPushNotification(r.token, r.payload, r.env);
        return { token: r.token, res };
      });

      // Batch the dead-token cleanup + derive counters from the results.
      await deactivateTokens(
        supabase,
        "device_tokens",
        results.filter((r) => isTokenDead(r.res)).map((r) => r.token),
      );
      const fixtureSent = results.filter((r) => r.res.success).length;
      const fixtureFailed = results.length - fixtureSent;
      totalPushes += fixtureSent;
      totalFailures += fixtureFailed;

      // One aggregate morning_push row per fixture (was one row PER token).
      await logPipelineEvent(supabase, {
        team_id: home.is_active ? home.id : away.id, // FK: a synthetic opponent id is not in teams
        stage: "morning_push",
        status: fixtureFailed === 0 ? "success" : fixtureSent === 0 ? "failure" : "partial",
        duration_ms: Date.now() - startTime,
        message:
          `morning_push ${fix.home_team_id} v ${fix.away_team_id}: ` +
          `${fixtureSent} sent, ${fixtureFailed} failed of ${results.length}`,
        content_item_id: null,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        fixtures: fixtures.length,
        pushes: totalPushes,
        failures: totalFailures,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("morning-push error:", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
