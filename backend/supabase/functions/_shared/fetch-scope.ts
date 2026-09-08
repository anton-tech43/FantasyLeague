// _shared/fetch-scope.ts
// Goal Digger — what one data-fetcher run is allowed to fetch, and the
// per-run standings cache that stops us buying the same league table twenty
// times.
//
// Two jobs, both pure enough to test without a network or a database:
//
//  1. `parseFetchScope` reads the request body. No body = today's behaviour
//     (every active entity, every endpoint). `{ team_ids: [...] }` narrows to
//     those entities; `{ only: [...] }` narrows to those endpoints. The narrow
//     form is what match-watcher calls at full time: standings + fixtures for
//     the two clubs that just played, five API calls, no RSS, no squad.
//  2. `StandingsCache` makes `/standings?league=X&season=Y` a once-per-run
//     purchase shared by every entity in that league. Every entity still gets
//     its own `raw_fetch_logs` row from the shared payload, so no consumer
//     downstream can tell the difference.

/** Endpoint groups a caller may ask for. "fixtures" = next + last. */
export const FETCH_ONLY_KEYS = [
  "standings",
  "fixtures",
  "injuries",
  "transfers",
  "squad",
  "coachs",
  "rss",
  "player_stats",
] as const;

export type FetchOnlyKey = typeof FETCH_ONLY_KEYS[number];

export interface FetchScope {
  /** Entity ids to fetch, or null for "every active entity". */
  teamIds: string[] | null;
  /** Endpoint groups to fetch, or null for "all of them". */
  only: FetchOnlyKey[] | null;
}

export type ScopeResult =
  | { ok: true; scope: FetchScope }
  | { ok: false; error: string };

/** Team ids are slugs we generate ourselves (`man_utd`, `champions_league`). */
const TEAM_ID_RE = /^[a-z0-9][a-z0-9_]{1,63}$/;

/** How many entities one scoped call may name. The full active set is 25. */
const MAX_TEAM_IDS = 100;

export const ALL_SCOPES: FetchScope = { teamIds: null, only: null };

/**
 * Validate a request body into a scope, or say why it is not one.
 *
 * Existence of the ids is NOT checked here — the caller checks that against
 * the `teams` rows it reads anyway, so we don't buy a second round-trip for a
 * check the first query already answers.
 */
export function parseFetchScope(body: unknown): ScopeResult {
  if (body === null || body === undefined) return { ok: true, scope: ALL_SCOPES };
  if (typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, error: "body must be a JSON object" };
  }

  const b = body as Record<string, unknown>;
  const ids: string[] = [];

  if (b.team_ids !== undefined && b.team_ids !== null) {
    if (!Array.isArray(b.team_ids) || b.team_ids.length === 0) {
      return { ok: false, error: "team_ids must be a non-empty array of team id strings" };
    }
    if (b.team_ids.length > MAX_TEAM_IDS) {
      return { ok: false, error: `team_ids may name at most ${MAX_TEAM_IDS} teams` };
    }
    for (const t of b.team_ids) {
      if (typeof t !== "string" || !TEAM_ID_RE.test(t)) {
        return { ok: false, error: `invalid team id: ${JSON.stringify(t)}` };
      }
      ids.push(t);
    }
  }

  // Legacy single-team form, still used by the manual fan-out curls.
  if (b.team_id !== undefined && b.team_id !== null) {
    if (typeof b.team_id !== "string" || !TEAM_ID_RE.test(b.team_id)) {
      return { ok: false, error: `invalid team id: ${JSON.stringify(b.team_id)}` };
    }
    ids.push(b.team_id);
  }

  let only: FetchOnlyKey[] | null = null;
  if (b.only !== undefined && b.only !== null) {
    if (!Array.isArray(b.only) || b.only.length === 0) {
      return { ok: false, error: "only must be a non-empty array of endpoint names" };
    }
    const picked: FetchOnlyKey[] = [];
    for (const k of b.only) {
      if (typeof k !== "string" || !(FETCH_ONLY_KEYS as readonly string[]).includes(k)) {
        return {
          ok: false,
          error: `unknown fetch scope ${JSON.stringify(k)}; known: ${FETCH_ONLY_KEYS.join(", ")}`,
        };
      }
      if (!picked.includes(k as FetchOnlyKey)) picked.push(k as FetchOnlyKey);
    }
    only = picked;
  }

  return {
    ok: true,
    scope: { teamIds: ids.length > 0 ? [...new Set(ids)] : null, only },
  };
}

/** Is this endpoint group in scope? An unscoped run wants everything. */
export function wants(scope: FetchScope, key: FetchOnlyKey): boolean {
  return scope.only === null || scope.only.includes(key);
}

/**
 * One `/standings` purchase per (league, season) per run.
 *
 * The Premier League table is the same twenty rows whichever of our twenty
 * clubs asked for it, so before this the cron bought it twenty times a run,
 * nine times a day. Keyed on league AND season because a cup entity and a club
 * can share a league id but never a run in which they disagree about the year.
 *
 * A failed fetch is cached too (as null): one bad league costs one call a run,
 * not twenty. The next run retries.
 */
export class StandingsCache {
  private readonly store = new Map<string, Promise<unknown | null>>();
  /** Distinct (league, season) pairs actually bought from the API. */
  calls = 0;
  /** Times a caller was handed a payload someone else had already paid for. */
  saved = 0;

  static key(leagueId: number, season: number): string {
    return `${leagueId}:${season}`;
  }

  get(
    leagueId: number,
    season: number,
    fetcher: () => Promise<unknown | null>,
  ): Promise<unknown | null> {
    const k = StandingsCache.key(leagueId, season);
    const hit = this.store.get(k);
    if (hit) {
      this.saved++;
      return hit;
    }
    this.calls++;
    // Store the PROMISE, not the value: two entities in the same league fetched
    // concurrently must share the one in-flight request, not race to start two.
    const p = fetcher().catch(() => null);
    this.store.set(k, p);
    return p;
  }
}
