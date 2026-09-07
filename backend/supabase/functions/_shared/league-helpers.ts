// _shared/league-helpers.ts
// V2.0: shared league/season mapping. Used by data-fetcher, match-watcher,
// and matchday-scheduler so all three agree on which season to fetch for
// each league. Single source of truth — bump here when a new season starts.

/**
 * Map an API-Football league_id to the current season we should fetch.
 *
 *   - 39 (Premier League): date-aware. PL seasons start in early August.
 *     From July onwards we should fetch the next season's number, otherwise
 *     the previous (= current) season. The `getUTCMonth()` cutoff at >=6
 *     (July) gives a 1-month buffer before kickoff. Without this the old
 *     hardcoded `return 2025` would silently return empty fixtures from
 *     August 2026 onwards (when PL switches to season 2026).
 *   - 1  (World Championship): season 2026 = the 2026 tournament.
 *     Stays 2026 until WC 2030 enters API-Football.
 *
 * For any unknown league, defaults to the current calendar year — safe-ish
 * fallback for cup competitions but the table should explicitly map every
 * league we actually run.
 */
export function seasonForLeague(leagueId: number): number {
  const now = new Date();
  const year = now.getUTCFullYear();
  switch (leagueId) {
    case 39:
    case 2:  return now.getUTCMonth() >= 6 ? year : year - 1;
    case 1:  return 2026;
    default: return year;
  }
}

/**
 * Active leagues we currently fetch data for. Used by match-watcher and
 * matchday-scheduler to decide which leagues to poll fixtures for.
 *
 * The DB-authoritative version is `SELECT DISTINCT league_id FROM teams
 * WHERE league_id IS NOT NULL` — Edge Functions should prefer that query
 * over this hardcoded list when possible. This constant exists as a
 * fallback / sanity check when the DB query fails.
 */
export const FALLBACK_ACTIVE_LEAGUES: number[] = [39, 2, 1];

/**
 * Competitions we write content for beyond a club's home league. Used by the
 * `active_competition_ids()` SQL function (migration 087) and mirrored here so
 * the Edge side can name them. A club's cup runs are deliberately absent: we
 * do not cover the League Cup or the FA Cup yet, and polling them would cost
 * API budget for content nobody writes.
 */
export const COVERED_CUP_LEAGUES: number[] = [2]; // 2 = UEFA Champions League

/** Human name for a competition id, for card copy and calendar labels. */
export function competitionName(leagueId: number): string {
  switch (leagueId) {
    case 39: return "Premier League";
    case 2: return "Champions League";
    case 1: return "World Championship";
    default: return "Cup";
  }
}

/**
 * How much a fixture matters, 1-5, for the Calendar tab's dots.
 *
 * Everything used to be a flat 3, so a Champions League away leg in Naples read
 * exactly like a League Cup tie at Ipswich. The whole point of the calendar is
 * that she can see which night is the big one without knowing football.
 *
 * Knockout weight comes from the round name, which API-Football gives us
 * verbatim ("Round of 16", "Quarter-finals", "Semi-finals", "Final").
 */
export function fixtureImportance(leagueId: number | undefined, round: string | undefined): number {
  const r = (round ?? "").toLowerCase();
  const isFinal = /\bfinal\b/.test(r) && !/semi|quarter|3rd|third/.test(r);
  const isSemi = /semi/.test(r);
  const isQuarter = /quarter/.test(r);
  const isLast16 = /round of 16|1\/8/.test(r);

  if (leagueId === 2) {
    // Champions League. Even the league phase is a bigger night than a
    // midtable Saturday, and the knockouts are the biggest nights of his year.
    if (isFinal) return 5;
    if (isSemi || isQuarter) return 5;
    if (isLast16) return 4;
    return 4;
  }
  if (leagueId === 39) return 3; // Premier League
  if (leagueId === 1) {
    if (isFinal || isSemi || isQuarter) return 5;
    return 4;
  }
  return 2; // domestic cups we do not cover in depth
}

/**
 * Calendar label. Trims the sponsor prefix off the competition name and, for a
 * knockout tie, says which round — "Champions League semi-final" tells her more
 * than "UEFA Champions League".
 */
export function fixtureLabel(leagueName: string | undefined, leagueId: number | undefined, round: string | undefined): string {
  const base = (leagueName ?? "Fixture").replace(/^UEFA\s+/i, "").replace(/^FIFA\s+/i, "");
  const r = (round ?? "").toLowerCase();
  if (/\bfinal\b/.test(r) && !/semi|quarter|3rd|third/.test(r)) return `${base} final`;
  if (/semi/.test(r)) return `${base} semi-final`;
  if (/quarter/.test(r)) return `${base} quarter-final`;
  if (/round of 16|1\/8/.test(r)) return `${base} last 16`;
  return base;
}
