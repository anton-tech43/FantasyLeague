// _shared/page-refresh.ts
// Goal Digger — full time is an event, not a schedule.
//
// The league table used to move only when the two-hourly cron came round, so a
// Saturday 17:30 kick-off left the table an hour and forty minutes behind the
// score the app had just pushed to her, and anything finishing after 22:00 UTC
// stayed wrong until six the next morning. match-watcher already knows full
// time to the minute; this decides what to re-fetch when it sees one.

export const PAGE_REFRESH_MARKER = "PAGE_REFRESH";
/** One of these per failed attempt; after PAGE_REFRESH_MAX_ATTEMPTS the fixture stops asking. */
export const PAGE_REFRESH_FAIL_PREFIX = "PAGE_REFRESH_FAIL_";
export const PAGE_REFRESH_MAX_ATTEMPTS = 3;

/**
 * The marker to persist after an attempt: success is final; a failure counts
 * one more attempt, so the next tick retries until the cap. Before this the
 * success marker was written BEFORE the call, so a 15-second timeout at 22:05
 * left the table wrong until the 06:00 cron.
 */
export function pageRefreshMarker(briefsFired: readonly string[], ok: boolean): string {
  if (ok) return PAGE_REFRESH_MARKER;
  const fails = briefsFired.filter((m) => m.startsWith(PAGE_REFRESH_FAIL_PREFIX)).length;
  return `${PAGE_REFRESH_FAIL_PREFIX}${fails + 1}`;
}

/**
 * Covered competitions that HAVE a table, and the `teams` row that holds it.
 * The two domestic cups (45, 48) are straight knockouts — data-fetcher already
 * skips `/standings` for them, so a League Cup night moves no table but its
 * clubs'. `europe_standings` on a club page is derived from these entities.
 */
export const TOURNAMENTS_WITH_A_TABLE: Record<number, string> = {
  2: "champions_league",
  3: "europa_league",
  848: "conference_league",
};

/** Statuses that mean the match is over. Mirrors match-watcher's own set. */
const FINISHED = new Set(["FT", "AET", "PEN"]);

export interface PageRefreshInput {
  status: string;
  /** Status we last recorded, or null when this is the first observation. */
  priorStatus: string | null;
  /** `match_status_state.briefs_fired` — our once-per-fixture guard. */
  briefsFired: readonly string[];
  homeTeamId: string;
  awayTeamId: string;
  /** Clubs we write for. A cup opponent is in `teams` but not in here. */
  activeTeamIds: ReadonlySet<string>;
  leagueId: number;
}

/**
 * Which entities need their standings and fixtures re-fetched now, or an empty
 * array for "nothing to do this tick".
 *
 * Fires when a fixture is over, we have seen it before, at least one side is
 * ours, and we have not already fired for it. Deliberately NOT gated on the
 * live→finished transition the way the full-time push is: a push that arrives
 * late is wrong, but a table that catches up late is exactly the point, so a
 * deploy or a replay mid-evening should still repair the pages once.
 *
 * A European tie also moves `europe_standings`, so the competition entity rides
 * along — otherwise the club's page has the new result and the table under it
 * still says what it said before kick-off.
 */
export function planPageRefresh(input: PageRefreshInput): string[] {
  if (!FINISHED.has(input.status)) return [];
  if (input.priorStatus === null) return []; // never fire on first sight
  if (input.briefsFired.includes(PAGE_REFRESH_MARKER)) return [];
  const fails = input.briefsFired.filter((m) => m.startsWith(PAGE_REFRESH_FAIL_PREFIX)).length;
  if (fails >= PAGE_REFRESH_MAX_ATTEMPTS) return [];

  const ours = [input.homeTeamId, input.awayTeamId].filter((id) =>
    input.activeTeamIds.has(id)
  );
  if (ours.length === 0) return [];

  const tournament = TOURNAMENTS_WITH_A_TABLE[input.leagueId];
  return tournament ? [...new Set([...ours, tournament])] : [...new Set(ours)];
}

/**
 * Merge per-fixture refresh lists into the one data-fetcher call a tick needs.
 * Five of our clubs can finish inside the same minute on a Saturday; that is
 * one call with ten ids (and, thanks to the standings cache, one league table),
 * not five calls the every-minute watcher has to sit through.
 */
export function mergeRefreshTargets(
  plans: ReadonlyArray<{ teamIds: readonly string[] }>,
): string[] {
  return [...new Set(plans.flatMap((p) => [...p.teamIds]))];
}

/**
 * Call another Edge Function and WAIT for it, unlike `triggerFunction`'s
 * fire-and-forget. The full-time refresh is worth waiting for — it is five API
 * calls — and waiting is what lets us record whether it worked.
 *
 * Never throws: the caller is a once-a-minute watcher whose real job is pushes.
 *
 * The 15-second default is set by the caller's own budget, not by the callee:
 * the match-watcher cron row gives the whole tick 30 seconds (`pg_net`
 * `timeout_milliseconds := 30000`). The biggest realistic batch — eight
 * entities on a Champions League night — measured 2.6s.
 */
export async function callFunction(
  functionName: string,
  payload: Record<string, unknown>,
  timeoutMs = 15_000,
): Promise<{ ok: boolean; status: number; body: string }> {
  const base = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SERVICE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!base || !serviceKey) {
    return { ok: false, status: 0, body: "missing SUPABASE_URL or SERVICE_KEY" };
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(`${base}/functions/v1/${functionName}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    const body = await resp.text().catch(() => "");
    return { ok: resp.ok, status: resp.status, body: body.slice(0, 500) };
  } catch (e) {
    return { ok: false, status: 0, body: e instanceof Error ? e.message : String(e) };
  } finally {
    clearTimeout(timer);
  }
}
