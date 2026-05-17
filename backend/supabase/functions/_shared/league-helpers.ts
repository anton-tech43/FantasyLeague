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
 *   - 1  (FIFA World Cup): season 2026 = the 2026 tournament.
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
    case 39: return now.getUTCMonth() >= 6 ? year : year - 1;
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
export const FALLBACK_ACTIVE_LEAGUES: number[] = [39, 1];
