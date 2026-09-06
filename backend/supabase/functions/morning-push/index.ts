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
//   1. Query match_status_state for fixtures kicking off in next 18h.
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

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { deactivateTokens, getSupabaseClient, isTokenDead } from "../_shared/supabase-client.ts";
import { mapWithConcurrency, PUSH_CONCURRENCY } from "../_shared/concurrency.ts";
import { sendPushNotification, buildAPNsPayload } from "../_shared/apns-client.ts";
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";

interface Fixture {
  fixture_id: number;
  home_team_id: string;
  away_team_id: string;
  kickoff_time: string;
}

interface Team {
  id: string;
  display_name: string;
  short_name: string | null;
  entity_type: string | null;
}

/// Format kickoff time as "19:00 BST" / "20:00 GMT". We display in
/// London time since most users are UK/EU and the app's voice has a
/// UK lean. iOS shows kickoff in the user's locale on the team page;
/// the push body is short enough that one consistent timezone here
/// reads cleaner than a per-user lookup we don't have data for.
///
/// We BUILD the BST/GMT suffix ourselves from the UK offset rather than
/// letting `Intl.DateTimeFormat` emit `timeZoneName: "short"`. V8/ICU
/// builds vary in how they render the suffix for `en-GB`/`Europe/London`
/// — some emit "BST" (preferred), some emit "GMT+1". Deterministic
/// suffix avoids the rendering jitter.
function formatKickoff(iso: string): string {
  const date = new Date(iso);
  const time = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
  // Compute the UK offset at this moment from London-local vs UTC hour.
  // London is +1 during BST (late Mar → late Oct), +0 the rest of the
  // year. Doing it this way (vs. a hardcoded date range) covers the
  // year-on-year DST transition without code edits.
  const ukHour = parseInt(time.split(":")[0], 10);
  const utcHour = date.getUTCHours();
  const offset = (ukHour - utcHour + 24) % 24;
  const suffix = offset === 1 ? "BST" : "GMT";
  return `${time} ${suffix}`;
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

    const { data: fixtures, error } = await supabase
      .from("match_status_state")
      .select("fixture_id, home_team_id, away_team_id, kickoff_time")
      .gte("kickoff_time", now.toISOString())
      .lte("kickoff_time", windowEnd.toISOString())
      .order("kickoff_time", { ascending: true })
      .returns<Fixture[]>();

    if (error) {
      console.error("morning-push: match_status_state query failed:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    if (!fixtures || fixtures.length === 0) {
      // Log so silence-on-a-match-day is distinguishable from
      // "genuinely no fixtures today" when reading the cron logs.
      // Match-watcher polls every minute so any same-day fixture
      // should be in match_status_state by 08:00 UTC; if this fires
      // empty on a day we know matches exist, that's a separate bug.
      console.log("morning-push: no fixtures in next 18h, nothing to push");
      return new Response(JSON.stringify({ success: true, fixtures: 0, pushes: 0 }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Collect every distinct team_id (home + away) so we can resolve
    // display names + short names in a single query.
    const teamIds = new Set<string>();
    for (const f of fixtures) {
      teamIds.add(f.home_team_id);
      teamIds.add(f.away_team_id);
    }
    const { data: teamRows } = await supabase
      .from("teams")
      .select("id, display_name, short_name, entity_type")
      .in("id", [...teamIds])
      .returns<Team[]>();
    const teamById = new Map<string, Team>((teamRows ?? []).map((t) => [t.id, t]));

    let totalPushes = 0;
    let totalFailures = 0;

    for (const fix of fixtures) {
      const home = teamById.get(fix.home_team_id);
      const away = teamById.get(fix.away_team_id);
      if (!home || !away) {
        console.warn(`morning-push: missing team row for fixture ${fix.fixture_id}`);
        continue;
      }

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
      const teams = `${fix.home_team_id},${fix.away_team_id}`;
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("apns_token, apns_environment, team_id, country_id, team_ids, country_ids")
        .or(
          `team_id.eq.${fix.home_team_id},country_id.eq.${fix.home_team_id},` +
          `team_id.eq.${fix.away_team_id},country_id.eq.${fix.away_team_id},` +
          `team_ids.ov.{${teams}},country_ids.ov.{${teams}}`,
        )
        .eq("is_active", true);

      if (!tokens || tokens.length === 0) continue;

      const kickoffStr = formatKickoff(fix.kickoff_time);

      // Body name-drops both teams + kickoff time, then teases the lineup as a
      // conversation starter — lineups drop ~60min before kickoff per
      // API-Football's publication cadence. It's fixture-constant; only the
      // title/payload differ per device (named after whichever side that device
      // follows), so resolve payloads first then fan out with bounded
      // concurrency. The old sequential loop + a pipeline_health insert PER
      // token would blow the 400s wall-clock ceiling for a popular club at 50k
      // followers (SCALING_50K.md §1).
      const body =
        `${home.display_name} vs ${away.display_name} at ${kickoffStr}. ` +
        `Lineups drop an hour before — good thing to ask him about.`;

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
        recipients.push({ token: tk.apns_token, payload, env });
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
        team_id: home.id,
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
