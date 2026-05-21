// _shared/detect-consequences.ts
//
// Deterministic, LLM-free detector for cross-team consequences of a just-
// finished match. Triggered by match-watcher after gd-matchday fires
// successfully. For each non-playing team in the same league/group whose
// race state mathematically changed (title-won, relegated, UCL-clinched,
// WC knockout-qualified, etc), returns a structured Consequence record
// so the caller can INSERT a templated content_items row.
//
// Pure math + table reads. No Anthropic API calls. No claude.ai routine
// fires. Cost: $0.
//
// Math model (works for both PL and WC group stage):
//
//   For each team T in the league/group:
//     points_now = T.points (post-fixture)
//     games_left = total_games_per_team − T.played
//     min_possible = points_now + 0
//     max_possible = points_now + 3 × games_left
//
//   TITLE_WON (PL): T.min > every other team's max
//   RELEGATED (PL): T.max < (17th-placed team's min) AND not already
//                   guaranteed relegation (state change check via the
//                   partial unique index — caller's ON CONFLICT handles
//                   the no-op).
//   UCL_CLINCHED (PL): T.min > (5th-placed team's max)
//   EUROPE_CLINCHED (PL): T.min > (8th-placed team's max)   ← UEL/UECL slot floor
//
//   WC_GROUP_WON: T.min > (2nd-placed team's max within group)
//   WC_KNOCKOUT_QUALIFIED: T.min > (3rd-placed team's max within group)
//                          (top-2 path — best-3rd cohort is V1.1 work)
//   WC_KNOCKOUT_ELIMINATED: T.max < (2nd-placed team's min within group)
//                           (conservative — only fires for teams who can't
//                            even reach top-2; best-3rd top-up is V1.1)
//
// We deliberately compute the math AFTER applying this fixture's result
// to the standings (the api_football_standings snapshot may be from
// before the result lands). The detector mutates a local copy of the
// standings array, never the underlying log.
//
// Idempotency is enforced at INSERT time by the partial unique index
// on (team_id, consequence_type) — see migration 051. The detector can
// return the same consequence on consecutive matches and the second
// INSERT is a no-op. So we don't need to maintain detector-side state.
//
// See: BACKFILL_RULES.md (the cost-discipline doctrine that prevented us
// from solving this with a per-team LLM routine), IMPLEMENTATION_PROGRESS
// Lesson 74 (the May 19 Arsenal title incident that prompted this layer).

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// PL = 39, WC = 1 per the teams.league_id values in our DB.
export const PL_LEAGUE_ID = 39;
export const WC_LEAGUE_ID = 1;

export type ConsequenceType =
  | "TITLE_WON"
  | "RELEGATED"
  | "UCL_CLINCHED"
  | "EUROPE_CLINCHED"
  | "WC_KNOCKOUT_QUALIFIED"
  | "WC_KNOCKOUT_ELIMINATED"
  | "WC_GROUP_WON";

export interface Consequence {
  /** team_id (goaldigger slug, e.g. "arsenal") of the AFFECTED team — not the playing team. */
  team_id: string;
  consequence_type: ConsequenceType;
  /**
   * Templated string the consequence-templates module embeds verbatim, e.g.
   * "Manchester City could only draw 1-1 at Bournemouth" or "Bournemouth beat Brentford 2-1".
   * Built deterministically from the fixture — no LLM voice.
   */
  trigger_summary: string;
}

interface StandingsEntry {
  rank: number;
  points: number;
  all: { played: number; win: number; draw: number; lose: number };
  team: { id: number; name: string };
  group?: string; // present on WC standings; ignored on PL
}

/**
 * Main entry. Returns `[]` if no math-driven consequence exists for any
 * non-playing team. Idempotency is the caller's concern — the partial
 * unique index makes duplicate INSERTs a no-op.
 */
export async function detectConsequences(
  supabase: SupabaseClient,
  args: {
    fixtureId: number;
    leagueId: number;
    homeTeamId: string;     // goaldigger slug
    awayTeamId: string;
    homeApiId: number;      // API-Football team id
    awayApiId: number;
    homeGoals: number;
    awayGoals: number;
    homeDisplayName: string;
    awayDisplayName: string;
  },
): Promise<Consequence[]> {
  // 1. Load the latest standings snapshot for this league.
  // We index by either playing team's slug — both teams share the same
  // standings log row in raw_fetch_logs (data-fetcher writes per-team).
  // We use the home team's row by convention.
  const { data: log } = await supabase
    .from("raw_fetch_logs")
    .select("data, fetched_at")
    .eq("source", "api_football_standings")
    .eq("team_id", args.homeTeamId)
    .order("fetched_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!log?.data) return [];

  // Has the data-fetcher cron already pulled standings AFTER this fixture
  // finished? If yes, the standings already reflect this match's points
  // — applyResult would double-count and could trip false-positive
  // consequences for boundary teams (e.g. the 5th-placed team for
  // UCL_CLINCHED). The detector runs at FT detection time; standings
  // fetched within the last 5 minutes of "now" are treated as fresh-and-
  // post-result. Larger margin would over-skip; smaller would over-apply.
  const fetchedAt = new Date(log.fetched_at as string).getTime();
  const ageMs = Date.now() - fetchedAt;
  const standingsAlreadyIncludesResult = ageMs >= 0 && ageMs < 5 * 60_000;

  // 2. Resolve the standings array for THIS match's competition slice:
  //    PL → standings[0]   (single 20-team league array)
  //    WC → standings[i]   (i = index of group containing both playing teams)
  const data = log.data as Record<string, unknown>;
  const response = (data.response as Array<Record<string, unknown>> | undefined) ?? [];
  const leagueBlock = response[0]?.league as Record<string, unknown> | undefined;
  const standings = leagueBlock?.standings as StandingsEntry[][] | undefined;
  if (!Array.isArray(standings) || standings.length === 0) return [];

  let group: StandingsEntry[] | undefined;
  if (args.leagueId === PL_LEAGUE_ID) {
    group = standings[0];
  } else if (args.leagueId === WC_LEAGUE_ID) {
    group = standings.find((g) =>
      Array.isArray(g) &&
      g.some((t) => t.team?.id === args.homeApiId) &&
      g.some((t) => t.team?.id === args.awayApiId)
    );
  }
  if (!group || group.length === 0) return [];

  // 3. Build trigger_summary deterministically from the fixture.
  //    Examples:
  //      "Manchester City could only draw 1-1 at Bournemouth"
  //      "Bournemouth beat Brentford 2-1"
  //      "Liverpool lost 0-3 to Chelsea"
  //    Voice is neutral/reportable — the per-consequence template wraps
  //    this in the right emotional context for the affected team.
  const trigger_summary = buildTriggerSummary(args);

  // 4. Apply this fixture's result to a LOCAL COPY of the standings —
  //    UNLESS the standings have already ingested this result (see the
  //    age check above). data-fetcher's cron fires every 2h waking, so
  //    99% of the time the standings are stale and we DO need to apply.
  const localGroup = standingsAlreadyIncludesResult
    ? cloneGroup(group)
    : applyResult(group, args);

  // 5. Determine total games per team for max_possible math.
  const totalGames = args.leagueId === PL_LEAGUE_ID ? 38 : 3;

  // 6. Build a slug map so we can convert API-Football team.id → our slug.
  const apiIdToSlug = await buildApiIdToSlugMap(supabase, localGroup);

  // 7. Compute consequences for non-playing teams.
  const consequences: Consequence[] = [];
  for (const team of localGroup) {
    // Skip the two playing teams — their result is already covered by
    // gd-matchday. Cross-team consequences are about ANYONE ELSE whose
    // race state shifted because of this result.
    if (team.team?.id === args.homeApiId || team.team?.id === args.awayApiId) continue;

    const slug = apiIdToSlug.get(team.team.id);
    if (!slug) continue; // team not in our DB — skip silently

    const detected = consequencesForTeam(team, localGroup, totalGames, args.leagueId);
    for (const type of detected) {
      consequences.push({ team_id: slug, consequence_type: type, trigger_summary });
    }
  }

  return consequences;
}

// ============================================================
// Helpers — deterministic, no I/O beyond the slug map lookup
// ============================================================

function buildTriggerSummary(args: {
  homeDisplayName: string;
  awayDisplayName: string;
  homeGoals: number;
  awayGoals: number;
}): string {
  const { homeDisplayName, awayDisplayName, homeGoals, awayGoals } = args;
  if (homeGoals === awayGoals) {
    // Draw — the away team's perspective tends to read as the "newsworthy"
    // angle ("could only draw at X") since road draws are more often the
    // result that triggers a title swing. Pick the higher-points-team
    // mention later if needed.
    return `${awayDisplayName} could only draw ${homeGoals}-${awayGoals} at ${homeDisplayName}`;
  }
  if (homeGoals > awayGoals) {
    return `${homeDisplayName} beat ${awayDisplayName} ${homeGoals}-${awayGoals}`;
  }
  return `${awayDisplayName} beat ${homeDisplayName} ${awayGoals}-${homeGoals}`;
}

function cloneGroup(group: StandingsEntry[]): StandingsEntry[] {
  return group.map((t) => ({
    rank: t.rank,
    points: t.points,
    all: { played: t.all.played, win: t.all.win, draw: t.all.draw, lose: t.all.lose },
    team: { id: t.team.id, name: t.team.name },
    group: t.group,
  }));
}

function applyResult(
  group: StandingsEntry[],
  args: { homeApiId: number; awayApiId: number; homeGoals: number; awayGoals: number },
): StandingsEntry[] {
  const copy = cloneGroup(group);

  const home = copy.find((t) => t.team.id === args.homeApiId);
  const away = copy.find((t) => t.team.id === args.awayApiId);
  if (!home || !away) return copy;

  // Only apply if standings haven't already counted this result. We can
  // tell by comparing played counts: if both teams' played is < the league
  // maximum already-played-by-anyone, this result hasn't been ingested.
  // Conservative: always apply, trusting that the partial unique index
  // catches duplicate consequence INSERTs anyway. The cost of double-
  // counting a single match in the local copy is at most one extra fire-
  // and-no-op.

  if (args.homeGoals > args.awayGoals) {
    home.points += 3;
    home.all.win += 1;
    away.all.lose += 1;
  } else if (args.homeGoals < args.awayGoals) {
    away.points += 3;
    home.all.lose += 1;
    away.all.win += 1;
  } else {
    home.points += 1;
    away.points += 1;
    home.all.draw += 1;
    away.all.draw += 1;
  }
  home.all.played += 1;
  away.all.played += 1;

  // Re-sort by points DESC (re-rank). Tiebreakers (goal diff, GS) are
  // V1.1 work — for now, same-points teams keep their original relative
  // order via stable sort.
  copy.sort((a, b) => b.points - a.points);
  copy.forEach((t, i) => (t.rank = i + 1));
  return copy;
}

function consequencesForTeam(
  team: StandingsEntry,
  group: StandingsEntry[],
  totalGames: number,
  leagueId: number,
): ConsequenceType[] {
  const out: ConsequenceType[] = [];
  const gamesLeft = totalGames - team.all.played;
  const myMin = team.points;
  const myMax = team.points + 3 * gamesLeft;

  // For each math check below we ignore THIS team in the comparison.
  const others = group.filter((t) => t.team.id !== team.team.id);
  const maxOf = (sub: StandingsEntry[]) =>
    Math.max(...sub.map((t) => t.points + 3 * (totalGames - t.all.played)));
  const minOf = (sub: StandingsEntry[]) =>
    Math.min(...sub.map((t) => t.points));

  if (leagueId === PL_LEAGUE_ID) {
    // TITLE_WON: my floor exceeds every other team's ceiling.
    if (myMin > maxOf(others)) out.push("TITLE_WON");

    // UCL_CLINCHED: my floor exceeds the 5th-placed team's ceiling.
    // (Top-4 = UCL spots in the PL.) Sort others by ceiling DESC and
    // take the 4th to compare with — i.e. the floor of "team currently
    // outside top-4 with the highest potential to catch you".
    if (group.length >= 5) {
      // Sort copy by current rank ascending — the team currently ranked 5th
      // is the boundary we have to overshoot.
      const sortedByRank = [...group].sort((a, b) => a.rank - b.rank);
      const fifth = sortedByRank[4];
      if (fifth && fifth.team.id !== team.team.id) {
        const fifthMax = fifth.points + 3 * (totalGames - fifth.all.played);
        if (myMin > fifthMax) out.push("UCL_CLINCHED");
      }
    }

    // EUROPE_CLINCHED: top-8 floor (assumes Conference League slot at 8th).
    if (group.length >= 9) {
      const sortedByRank = [...group].sort((a, b) => a.rank - b.rank);
      const ninth = sortedByRank[8];
      if (ninth && ninth.team.id !== team.team.id) {
        const ninthMax = ninth.points + 3 * (totalGames - ninth.all.played);
        if (myMin > ninthMax) out.push("EUROPE_CLINCHED");
      }
    }

    // RELEGATED: my ceiling is below the 17th-placed team's floor.
    // (18th, 19th, 20th go down — so the boundary is the 17th-placed
    // team's floor.) For a 20-team league, 17th is index 16 sorted by rank.
    if (group.length >= 18) {
      const sortedByRank = [...group].sort((a, b) => a.rank - b.rank);
      const seventeenth = sortedByRank[16];
      if (seventeenth && seventeenth.team.id !== team.team.id) {
        const seventeenthMin = seventeenth.points;
        if (myMax < seventeenthMin) out.push("RELEGATED");
      }
    }
  } else if (leagueId === WC_LEAGUE_ID) {
    // Group stage — 4 teams per group, 3 games each.
    // WC_KNOCKOUT_QUALIFIED: my floor exceeds the 3rd-ranked team's ceiling
    // within this group (top-2 advance directly; best-3rd is V1.1).
    if (group.length >= 3) {
      const sortedByRank = [...group].sort((a, b) => a.rank - b.rank);
      const third = sortedByRank[2];
      if (third && third.team.id !== team.team.id) {
        const thirdMax = third.points + 3 * (totalGames - third.all.played);
        if (myMin > thirdMax) out.push("WC_KNOCKOUT_QUALIFIED");
      }
    }
    // WC_GROUP_WON: my floor exceeds the 2nd-ranked team's ceiling.
    if (group.length >= 2) {
      const sortedByRank = [...group].sort((a, b) => a.rank - b.rank);
      const second = sortedByRank[1];
      if (second && second.team.id !== team.team.id) {
        const secondMax = second.points + 3 * (totalGames - second.all.played);
        if (myMin > secondMax) out.push("WC_GROUP_WON");
      }
    }
    // WC_KNOCKOUT_ELIMINATED: my ceiling below the 2nd-ranked team's floor.
    // Conservative — ignores best-3rd cohort. V1.1 will tighten.
    if (group.length >= 2) {
      const sortedByRank = [...group].sort((a, b) => a.rank - b.rank);
      const second = sortedByRank[1];
      if (second && second.team.id !== team.team.id) {
        const secondMin = second.points;
        if (myMax < secondMin) out.push("WC_KNOCKOUT_ELIMINATED");
      }
    }
  }

  return out;
}

async function buildApiIdToSlugMap(
  supabase: SupabaseClient,
  group: StandingsEntry[],
): Promise<Map<number, string>> {
  const apiIds = group.map((t) => t.team?.id).filter((id): id is number => typeof id === "number");
  if (apiIds.length === 0) return new Map();

  const { data } = await supabase
    .from("teams")
    .select("id, api_football_id")
    .in("api_football_id", apiIds);

  const map = new Map<number, string>();
  for (const row of data ?? []) {
    const apiId = (row as { api_football_id: number }).api_football_id;
    const slug = (row as { id: string }).id;
    if (apiId && slug) map.set(apiId, slug);
  }
  return map;
}
