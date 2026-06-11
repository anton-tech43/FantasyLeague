// _shared/fixture-rollover.ts
//
// Authoritative "has this fixture been played?" detection for the WC team
// page's next-fixture rollover. The team page recomputes its next fixture
// from raw_fetch_logs on every refresh; the only hard question is which
// upcoming entries are actually still to play.
//
// A kickoff date is a WEAK signal (a just-finished game lingers within the
// grace window; a transiently-empty fixtures_next fetch makes us fall back
// to a stale snapshot that may still list a played game). So we corroborate
// against api_football_fixtures_last, which carries each fixture's id +
// finished status — the authoritative played list. The caller keeps the
// date-grace as a fallback for the lag before fixtures_last catches up.

/** API-Football short statuses that mean the match is definitively played. */
export const FINISHED_STATUSES: ReadonlySet<string> = new Set([
  "FT", // full time
  "AET", // after extra time
  "PEN", // decided on penalties
  "WO", // walkover
]);

/**
 * Union the played fixture ids from any number of api_football_fixtures_last
 * payloads. Union (not newest-only) because a finished game stays finished
 * even if a later fetch is transiently empty — once played, always played.
 * Tolerant of malformed / empty payloads.
 */
export function collectFinishedFixtureIds(payloads: unknown[]): Set<number> {
  const ids = new Set<number>();
  for (const data of payloads) {
    try {
      const response = (data as Record<string, unknown>)?.response as unknown[];
      if (!Array.isArray(response)) continue;
      for (const item of response) {
        const fixture = (item as Record<string, unknown>).fixture as Record<string, unknown> | undefined;
        const id = fixture?.id as number | undefined;
        const status = (fixture?.status as Record<string, unknown> | undefined)?.short as string | undefined;
        if (typeof id === "number" && status && FINISHED_STATUSES.has(status)) {
          ids.add(id);
        }
      }
    } catch {
      // skip a bad payload, keep scanning the rest
    }
  }
  return ids;
}

/**
 * Drop fixtures that are already played. The caller has already applied the
 * kickoff date-grace; this additionally removes games that are finished even
 * when their kickoff is recent (just-finished) or a stale fixtures_next
 * snapshot still lists them. Fixtures with no id (shouldn't happen for
 * API-Football) are kept — the date-grace remains their guard.
 */
export function dropFinished<T extends { fixtureId?: number }>(
  fixtures: T[],
  finishedIds: Set<number>,
): T[] {
  if (finishedIds.size === 0) return fixtures;
  return fixtures.filter((f) => f.fixtureId == null || !finishedIds.has(f.fixtureId));
}
