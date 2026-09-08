// _shared/player-stats.ts
// Pure helpers for the daily per-player season stats fetch (data-fetcher,
// source `api_football_players_stats`). Kept out of index.ts so they can be
// tested without booting the function.
//
// Why once a day: /players?team=&season=&page=N is ~20 players a page, so two
// pages per club. The daily pipeline runs nine times a day (0 6-22/2 UTC); at
// every run that would be 360 calls a day against a 7,500 cap already carrying
// match-watcher's per-minute poll. Minutes played change at most once every
// three days per club, so one fetch a day is the honest cadence: ~40 calls.

/** raw_fetch_logs.source for the merged stats payload. */
export const PLAYER_STATS_SOURCE = "api_football_players_stats";

/**
 * Refetch when the newest stored row is older than this. 20h rather than 24h
 * so the gate lands on the 06:00 run every day even when a run is slow, and
 * still only once: by the 08:00 run the row is 2h old.
 */
export const PLAYER_STATS_MAX_AGE_HOURS = 20;

/**
 * Hard ceiling on pages. A PL squad is 30-45 players (2 pages). The cap stops
 * a feed that reports a wrong `paging.total` from spending the day's quota.
 */
export const PLAYER_STATS_MAX_PAGES = 3;

export interface PlayerStatsPage {
  paging?: { current?: number; total?: number };
  response?: unknown[];
  errors?: unknown;
}

/**
 * The once-a-day gate. `lastFetchedAt` is the newest raw_fetch_logs.fetched_at
 * for (team, PLAYER_STATS_SOURCE), or null when we have never fetched.
 *
 * Time-based rather than "is it 06:00 UTC" so a missed or shifted run still
 * catches up the same day instead of skipping until tomorrow.
 */
export function isPlayerStatsDue(
  lastFetchedAt: string | null | undefined,
  now: Date = new Date(),
): boolean {
  if (!lastFetchedAt) return true;
  const last = Date.parse(lastFetchedAt);
  if (Number.isNaN(last)) return true; // unreadable timestamp: fetch, don't stall
  return now.getTime() - last >= PLAYER_STATS_MAX_AGE_HOURS * 3_600_000;
}

/** How many pages to ask for, given page 1. Always at least 1, never over the cap. */
export function pagesToFetch(firstPage: PlayerStatsPage): number {
  const total = firstPage?.paging?.total;
  if (typeof total !== "number" || !Number.isFinite(total) || total < 1) return 1;
  return Math.min(Math.trunc(total), PLAYER_STATS_MAX_PAGES);
}

/**
 * Merge the pages into ONE payload stored as a single raw_fetch_logs row.
 *
 * One row rather than one per page because the retention sweep keeps only the
 * newest row per (source, team_id) after 7 days — a page-2 row would be swept
 * while page 1 survived, and the sync would silently see half a squad.
 *
 * Deduped by player.id: the feed re-serves a player on the page boundary when
 * the squad changes between two calls, and two entries for one player would
 * double his minutes in sync_player_stats_from_raw().
 */
export function mergePlayerStatPages(pages: PlayerStatsPage[]): {
  response: unknown[];
  results: number;
  paging: { current: number; total: number };
} {
  const seen = new Set<unknown>();
  const response: unknown[] = [];

  for (const page of pages) {
    for (const entry of page?.response ?? []) {
      const id = (entry as { player?: { id?: unknown } })?.player?.id;
      if (id !== undefined && id !== null) {
        if (seen.has(id)) continue;
        seen.add(id);
      }
      response.push(entry);
    }
  }

  return {
    response,
    results: response.length,
    paging: { current: 1, total: pages.length },
  };
}
