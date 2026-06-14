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
import { renderMatchdayReminder } from "../_shared/matchday-reminder-copy.ts";

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
    .select("id, display_name")
    .eq("entity_type", "country");
  if (cErr) return json({ error: `teams query: ${cErr.message}` }, 500);
  const nameById = new Map((countries ?? []).map((t) => [t.id as string, t.display_name as string]));
  const countryIds = [...nameById.keys()];
  if (countryIds.length === 0) return json({ reminders_sent: 0, note: "no country entities" });

  // Only bother with countries that actually have a follower — no point
  // claiming markers or rendering copy for the other ~40 teams nobody follows.
  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("country_id")
    .not("country_id", "is", null)
    .eq("is_active", true);
  const followedCountries = new Set((tokenRows ?? []).map((r) => r.country_id as string));
  if (followedCountries.size === 0) return json({ reminders_sent: 0, note: "no followed countries" });

  const { data: states, error: sErr } = await supabase
    .from("team_season_state")
    .select("team_id, next_fixtures")
    .in("team_id", [...followedCountries].filter((id) => nameById.has(id)));
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

      const copy = renderMatchdayReminder({ teamName, opponent: fx.opponent, kickoffUtc: kickoff, now });

      if (dryRun) {
        results.push({
          team_id: teamId,
          opponent: fx.opponent,
          kickoff: kickoff.toISOString(),
          title: copy.title,
          body: copy.body,
          would_fire: true,
        });
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

      // Send to this country's followers.
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("apns_token, apns_environment")
        .eq("country_id", teamId)
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
      });
    }
  }

  return json({ dry_run: dryRun, reminders_sent: remindersSent, count: results.length, results });
});
