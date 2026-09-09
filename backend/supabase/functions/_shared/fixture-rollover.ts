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
 * Statuses that mean the fixture will not be played as listed, so it must not
 * sit on the Calendar tab counting down to a kickoff that is not coming.
 * Postponed (PST) is deliberately NOT here: a postponed match is still a real
 * fixture and the calendar says "Postponed" against it rather than dropping
 * the row and leaving her wondering where the game went.
 */
export const ABANDONED_STATUSES: ReadonlySet<string> = new Set([
  "CANC", // cancelled
  "ABD", // abandoned
  "WO", // walkover (awarded, never played)
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
 * Keep only the api_football_fixtures_next response items belonging to one
 * competition (API-Football `league.id`). During the World Cup a country's
 * fixtures_next payload also carries its post-tournament games — Nations
 * League, Euro/qualifier ties (different league ids) — which must NOT surface
 * as WC "upcoming". Filtering to the WC league id (1) leaves only the group
 * games now, and future-proofs the knockout rounds (also league id 1).
 * Tolerant of malformed items (a missing league object drops the item).
 */
export function filterFixturesByLeague(response: unknown[], leagueId: number): unknown[] {
  if (!Array.isArray(response)) return [];
  return response.filter((item) => {
    const league = (item as Record<string, unknown>)?.league as Record<string, unknown> | undefined;
    return (league?.id as number | undefined) === leagueId;
  });
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

// ============================================================
// The Calendar tab's fixture list
// ============================================================

import { COVERED_CUP_LEAGUES, fixtureImportance, fixtureLabel } from "./league-helpers.ts";

/** Keep in-progress and just-finished games rather than blanking the card. */
export const FIXTURE_PAST_GRACE_MS = 3 * 60 * 60_000;

/// Competitions the app covers. Anything else in the feed (a friendly, a
/// tournament we do not follow) used to reach the Calendar tab as a row
/// labelled "Fixture", which tells her nothing.
const CALENDAR_LEAGUES: number[] = [39, ...COVERED_CUP_LEAGUES];

/// A season, not a month. `next=20` from the fetcher, 15 rows on the page:
/// enough that a January FA Cup tie and the Christmas programme are visible in
/// September, and short enough that the card stays a card.
const CALENDAR_MAX_ROWS = 15;

/// Every upcoming fixture for the iOS Calendar tab, built mechanically from
/// api_football_fixtures_next. Until Sept 2026 this card was only ever written
/// by the paid `full` mode, so every club's calendar still showed May's run-in
/// (Arsenal v Burnley, Ipswich v Luton, Leeds v West Ham — two of those clubs
/// are no longer in the division). Facts here are copied, never judged:
/// `importance_label` is the competition, which cannot go out of date. A richer
/// label already stored for the same fixture is preserved, so anything the
/// routine wrote by hand survives the 2-hourly refresh.
///
/// Works on a `next=10` payload as well as a `next=20` one: the cap is an upper
/// bound, not an expectation.
///
/// `finishedIds` comes from `collectFinishedFixtureIds` over fixtures_last, so
/// a stale snapshot cannot leave a played game sitting in the calendar. Status
/// is carried per row: `PST` stays (iOS renders "Postponed"), `TBD` stays (the
/// date with "Time TBC"), and CANC/ABD/WO are dropped, because a game that will
/// not be played should not be counting down.
export function buildUpcomingFixtures(
  data: unknown,
  teamApiFootballId: number,
  now: Date,
  existing: Array<Record<string, unknown>> | undefined,
  finishedIds: Set<number> = new Set(),
  /** API-Football ids of the top-flight clubs, so an early FA Cup tie against one of them weighs more. */
  topFlightApiIds: Set<number> = new Set(),
): Array<Record<string, unknown>> | null {
  const response = (data as Record<string, unknown> | undefined)?.response;
  if (!Array.isArray(response) || response.length === 0) return null;
  const floor = now.getTime() - FIXTURE_PAST_GRACE_MS;
  const priorByKey = new Map<string, Record<string, unknown>>(
    (existing ?? []).map((f) => [`${String(f.date).slice(0, 10)}|${f.opponent}`, f]),
  );

  const out: Array<Record<string, unknown>> = [];
  for (const item of response as Array<Record<string, unknown>>) {
    const fx = item.fixture as Record<string, unknown> | undefined;
    const teams = item.teams as Record<string, Record<string, unknown>> | undefined;
    const league = item.league as Record<string, unknown> | undefined;
    const date = fx?.date as string | undefined;
    if (!date || !teams?.home || !teams?.away) continue;
    const t = Date.parse(date);
    if (Number.isNaN(t) || t < floor) continue;
    if (!CALENDAR_LEAGUES.includes(league?.id as number)) continue;
    const status = ((fx?.status as Record<string, unknown> | undefined)?.short as string) ?? "NS";
    if (ABANDONED_STATUSES.has(status)) continue;
    const fixtureId = fx?.id as number | undefined;
    if (fixtureId != null && finishedIds.has(fixtureId)) continue;

    const isHome = (teams.home.id as number | undefined) === teamApiFootballId;
    const opponent = (isHome ? teams.away.name : teams.home.name) as string;
    const opponentApiId = (isHome ? teams.away.id : teams.home.id) as number | undefined;
    const opponentIsTopFlight = opponentApiId != null && topFlightApiIds.has(opponentApiId);
    const leagueId = league?.id as number | undefined;
    const round = league?.round as string | undefined;
    const prior = priorByKey.get(`${date.slice(0, 10)}|${opponent}`);
    const priorLabel = (prior?.importance_label as string | undefined) ?? "";
    const machineLabels = new Set([
      fixtureLabel(league?.name as string | undefined, leagueId, round).slice(0, 30),
      ((league?.name as string | undefined) ?? "").slice(0, 30),
      "Fixture",
    ]);
    const handWritten = priorLabel.length > 0 && !machineLabels.has(priorLabel);
    out.push({
      date,
      opponent,
      // The opponent's API-Football id, so the Calendar row can draw their
      // crest. Until 2026-09-07 the row was a name and a venue — the only
      // surface in the app without a badge on it.
      opponent_api_id: (isHome ? teams.away.id : teams.home.id) as number | undefined,
      ...(fixtureId != null ? { fixture_id: fixtureId } : {}),
      // So the calendar sync can name the competition from the id rather than
      // from importance_label, which may hold the routine's own prose.
      ...(leagueId != null ? { league_id: leagueId } : {}),
      status,
      venue: isHome ? "home" : "away",
      // iOS requires both fields (UpcomingFixture is non-optional on each).
      // The dots used to be a flat 3, so a Champions League leg in Naples read
      // like a League Cup tie at Ipswich. Competition and knockout round decide
      // it now.
      //
      // "Anything hand-written wins" still holds, but the old code could not
      // tell a hand-written label from its own default, so the flat 3 preserved
      // itself forever. A prior counts as hand-written only when its label says
      // something the machine would not have said.
      importance_dots: handWritten
        ? (prior!.importance_dots as number)
        : fixtureImportance(leagueId, round, opponentIsTopFlight),
      importance_label: handWritten
        ? (prior!.importance_label as string)
        : fixtureLabel(league?.name as string | undefined, leagueId, round).slice(0, 30),
    });
    if (out.length === CALENDAR_MAX_ROWS) break;
  }
  return out.length > 0 ? out : null;
}
