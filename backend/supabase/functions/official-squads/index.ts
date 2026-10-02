// official-squads/index.ts
//
// Second source for players: the Premier League's own squad list, fetched for
// each club with teams.pl_squad_id (migration 127) and matched to our players
// rows by name. A matched man gets the official shirt number (players.number,
// which every reader already uses, and players.official_number) and
// in_official_squad = true; anyone at the club the official list does not have
// gets in_official_squad = false, and the app leaves him out of its questions.
//
// Runs daily at 05:50 UTC, after the 05:30 API-Football squad sync. Free: one
// GET per club to the public endpoint premierleague.com itself reads. Zero
// Claude. ?dry_run=1 reports and writes nothing.
//
// Why: the pre-launch audit (2026-10-02) found ~30 numbers the feed had wrong
// (Mitoma 22, officially 7) and youth players not in the registered squad.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { matchOfficial, type OfficialPlayer } from "../_shared/official-squads.ts";

const ENDPOINT = "https://sdp-prem-prod.premier-league-prod.pulselive.com/api/v2/competitions/8/seasons";

function seasonYear(now: Date): number {
  // The 2026-27 season is "2026" from July.
  return now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
}

serve(async (req) => {
  const denied = requireServiceAuth(req);
  if (denied) return denied;
  const dryRun = new URL(req.url).searchParams.get("dry_run") === "1";
  const supabase = getSupabaseClient();
  const now = new Date();
  const season = seasonYear(now);

  const { data: teams, error } = await supabase.from("teams").select("id, pl_squad_id")
    .eq("is_active", true).not("pl_squad_id", "is", null);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

  const report: Record<string, unknown>[] = [];
  for (const t of teams ?? []) {
    let official: OfficialPlayer[];
    try {
      const resp = await fetch(`${ENDPOINT}/${season}/teams/${t.pl_squad_id}/squad`);
      const json = await resp.json();
      official = (json.players ?? []).map((p: Record<string, any>) => ({
        display: p.name?.display ?? "", first: p.name?.first ?? "", last: p.name?.last ?? "",
        number: typeof p.shirtNum === "number" ? p.shirtNum : null,
      }));
    } catch (e) {
      report.push({ team: t.id, error: (e as Error).message });
      continue;
    }
    // An empty or failed list must never mark a whole squad as not registered.
    if (official.length < 15) { report.push({ team: t.id, skipped: `only ${official.length} official players` }); continue; }

    const { data: rows } = await supabase.from("players").select("api_player_id, name, number, minutes").eq("team_id", t.id);
    const matches = matchOfficial((rows ?? []) as { api_player_id: number; name: string; number: number | null }[], official);
    const changed = matches.filter((m) => m.official && m.official.number != null && m.official.number !== m.row.number);
    // Unmatched with minutes on the pitch is a spelling we cannot pair
    // ("Yarmolyuk" / "Yarmoliuk"), not a man outside the squad: unknown.
    const played = (m: { row: unknown }) => ((m.row as { minutes?: number | null }).minutes ?? 0) > 0;
    const notIn = matches.filter((m) => !m.official && !played(m));
    const unpaired = matches.filter((m) => !m.official && played(m));
    report.push({
      team: t.id, official: official.length, ours: rows?.length ?? 0,
      numbers_corrected: changed.map((m) => `${m.row.name} ${m.row.number}→${m.official!.number}`),
      not_in_official: notIn.map((m) => m.row.name),
      unpaired_but_playing: unpaired.map((m) => m.row.name),
    });
    if (dryRun) continue;
    for (const m of matches) {
      if (!m.official && played(m)) continue;
      const patch = m.official
        ? { in_official_squad: true, official_number: m.official.number, official_checked_at: now.toISOString(),
            ...(m.official.number != null ? { number: m.official.number } : {}) }
        : { in_official_squad: false, official_checked_at: now.toISOString() };
      await supabase.from("players").update(patch).eq("api_player_id", m.row.api_player_id);
    }
  }
  return new Response(JSON.stringify({ dry_run: dryRun, season, report }), { headers: { "Content-Type": "application/json" } });
});
