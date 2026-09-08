// _shared/poll-plan.ts
// Which (league, date) pairs match-watcher fetches on a tick.
//
// Pulled out of match-watcher so it can be tested without a database: the
// polling decision is the one thing in that function whose failure mode is
// silent. Poll too little and a match goes uncovered; poll too much and the
// API-Football day quota is gone by teatime.

import { COVERED_CUP_LEAGUES } from "./league-helpers.ts";

export interface PollPair {
  leagueId: number;
  date: string; // YYYY-MM-DD (UTC)
}

/**
 * Build the poll plan.
 *
 *   - `dateOverride` (the `?date=` operator handle): look at that date across
 *     every league we cover, whatever the schedule says. An operator asking
 *     about a specific day wants the whole day, not the subset that happens to
 *     be live now.
 *   - normal tick: whatever `poll_leagues()` returned (migration 094).
 *   - RPC failure: the old always-on behaviour for home leagues on `today`.
 *     Degrading loud but covered beats degrading quiet.
 *
 * An empty result on a normal tick is legitimate — most minutes of most days
 * have no football on. That is the point of the function.
 */
export function buildPollPairs(args: {
  rpcRows: Array<{ league_id: number; poll_date: string }> | null;
  rpcFailed: boolean;
  dateOverride: string | null;
  today: string;
  homeLeagues: number[];
}): PollPair[] {
  const { rpcRows, rpcFailed, dateOverride, today, homeLeagues } = args;

  if (dateOverride) {
    const leagues = [...new Set([...homeLeagues, ...COVERED_CUP_LEAGUES])];
    return leagues.map((leagueId) => ({ leagueId, date: dateOverride }));
  }

  if (rpcFailed || !Array.isArray(rpcRows)) {
    return homeLeagues.map((leagueId) => ({ leagueId, date: today }));
  }

  const seen = new Set<string>();
  const out: PollPair[] = [];
  for (const row of rpcRows) {
    const leagueId = Number(row.league_id);
    // Postgres hands a `date` back as YYYY-MM-DD; slice defensively in case a
    // driver ever widens it to a timestamp.
    const date = String(row.poll_date ?? "").slice(0, 10);
    if (!Number.isFinite(leagueId) || date.length !== 10) continue;
    const key = `${leagueId}|${date}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ leagueId, date });
  }
  return out;
}
