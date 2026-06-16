// matchday-reminder/index.ts
//
// "His team plays" reminder push. Scheduled daily at 07:00 UTC (09:00
// Europe/Stockholm). For every followed WC country whose next fixture kicks off
// within the next 24h, sends ONE deterministic reminder to that country's
// followers. Evening/late kickoffs are caught that morning; after-midnight
// kickoffs fall into the previous day's 24h window, so they fire the morning
// before (the user's rule: "morning of match day, the day before for night
// games").
//
// Source of truth is team_season_state.next_fixtures (known days ahead), NOT
// match_status_state (only populated ~2h before kickoff, too late for a
// day-before reminder). Idempotent via matchday_reminders_sent (PK team_id +
// kickoff_time). Deterministic copy, zero Claude.
//
// ?dry_run=1 reports what WOULD fire without claiming markers or sending — safe
// to invoke any time against live data.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { buildAPNsPayload, sendPushNotification } from "../_shared/apns-client.ts";
import { renderMatchdayReminder, renderPreMatchBuildup } from "../_shared/matchday-reminder-copy.ts";
import { preMatchVerdict, WC_FAVORITE_GAP } from "../_shared/matchup-verdict.ts";

const WINDOW_MS = 24 * 60 * 60 * 1000;

interface NextFixture {
  opponent: string;
  kickoff_time: string;
  venue?: string;
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

  // Country entities only. PL clubs are off-season during the WC; their
  // reminders (team_id-keyed recipients) can be added when the league resumes.
  const { data: countries, error: cErr } = await supabase
    .from("teams")
    .select("id, display_name, strength_rank")
    .eq("entity_type", "country");
  if (cErr) return json({ error: `teams query: ${cErr.message}` }, 500);
  const nameById = new Map((countries ?? []).map((t) => [t.id as string, t.display_name as string]));
  const rankById = new Map((countries ?? []).map((t) => [t.id as string, (t.strength_rank as number | null) ?? null]));
  // display_name (lowercased) -> id, to resolve the opponent named in next_fixtures.
  const idByName = new Map((countries ?? []).map((t) => [(t.display_name as string).toLowerCase(), t.id as string]));
  const countryIds = [...nameById.keys()];
  if (countryIds.length === 0) return json({ reminders_sent: 0, note: "no country entities" });

  // Only bother with countries that actually have a follower — no point
  // claiming markers or rendering copy for the other ~40 teams nobody follows.
  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("country_id, country_ids")
    .or("country_id.not.is.null,country_ids.not.is.null")
    .eq("is_active", true);
  // Used only to decide who gets the reminder PUSH. The build-up FEED item is
  // written for ALL countries with a fixture in window (below), independent of
  // followers, so the feed is populated for whatever country the user views.
  // V2.2: a device may follow up to 2 countries (country_ids array); union the
  // legacy scalar with the array so multi-follow devices count too.
  const followedCountries = new Set<string>();
  for (const r of tokenRows ?? []) {
    if (r.country_id) followedCountries.add(r.country_id as string);
    for (const c of (r.country_ids as string[] | null) ?? []) followedCountries.add(c);
  }

  const { data: states, error: sErr } = await supabase
    .from("team_season_state")
    .select("team_id, next_fixtures")
    .in("team_id", countryIds);
  if (sErr) return json({ error: `season_state query: ${sErr.message}` }, 500);

  let remindersSent = 0;
  const results: Array<Record<string, unknown>> = [];

  for (const row of states ?? []) {
    const teamId = row.team_id as string;
    const teamName = nameById.get(teamId) ?? teamId;
    const fixtures = (row.next_fixtures as NextFixture[] | null) ?? [];

    for (const fx of fixtures) {
      const kickoff = new Date(fx.kickoff_time);
      if (isNaN(kickoff.getTime())) continue;
      // Only fixtures kicking off within the next 24h (future-only).
      if (kickoff <= now || kickoff >= windowEnd) continue;

      // ── A1: deterministic build-up FEED item (ALL countries) ──────────────
      // So a country's feed is never empty in the ~24h before a match, even for
      // RSS-starved nations the news routine skips. Idempotent via a stable
      // match_id (buildup-<kickoff epoch>); feed-only (the reminder push below
      // is the alert). Verdict comes from FIFA ranks when the opponent resolves.
      const oppId = idByName.get((fx.opponent ?? "").toLowerCase()) ?? null;
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
      if (!dryRun) {
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

      // ── Reminder PUSH — followed countries only ──────────────────────────
      const isFollowed = followedCountries.has(teamId);
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
      // survives cron retries and a fixture lingering in next_fixtures.
      const { error: claimErr } = await supabase
        .from("matchday_reminders_sent")
        .insert({ team_id: teamId, kickoff_time: kickoff.toISOString() });
      if (claimErr) {
        if (claimErr.code === "23505") continue; // already sent
        results.push({ team_id: teamId, kickoff: kickoff.toISOString(), error: claimErr.message });
        continue;
      }

      // Send to this country's followers (legacy scalar OR V2.2 array).
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("apns_token, apns_environment")
        .or(`country_id.eq.${teamId},country_ids.cs.{${teamId}}`)
        .eq("is_active", true);

      let sent = 0;
      for (const t of tokens ?? []) {
        const payload = buildAPNsPayload(
          "", // teamShortName fallback unused — pushTitle is set below
          copy.body, // headline fallback
          `wc-matchday-${teamId}-${kickoff.getTime()}`, // non-UUID sentinel: tap just opens the app
          "WC_MATCHDAY",
          false,
          copy.body, // push_text
          copy.title, // push_title
        );
        const env = t.apns_environment === "production" ? "production" : "development";
        const res = await sendPushNotification(t.apns_token as string, payload, env);
        if (res.success) sent++;
      }

      remindersSent++;
      results.push({
        team_id: teamId,
        opponent: fx.opponent,
        kickoff: kickoff.toISOString(),
        tokens_sent: sent,
        buildup: buildupWritten,
      });
    }
  }

  return json({ dry_run: dryRun, reminders_sent: remindersSent, count: results.length, results });
});
