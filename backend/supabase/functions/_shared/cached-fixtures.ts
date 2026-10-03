// _shared/cached-fixtures.ts
// Upcoming fixtures from data-fetcher's own cache (raw_fetch_logs,
// source='api_football_fixtures_next', every 2h 06-22 UTC, one row per entity).
//
// The morning pushes used match_status_state as their no-API fallback, but
// since migration 094 match-watcher only polls a league from 35 min before
// kickoff, so at 07:00/08:00 UTC that table holds nothing for the day ahead and
// the fallback could never fire (QA-06). poll_leagues() already plans from
// this same cache, so it is the source the rest of the system trusts.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2.117.0";

export interface CachedFixture {
  fixture: { id: number; date: string; status?: { short?: string } };
  league?: { id?: number; round?: string };
  teams: { home: { id: number; name: string }; away: { id: number; name: string } };
}

/// Newest NON-EMPTY snapshot per entity (API-Football returns [] for a few
/// minutes during its nightly refresh), flattened and deduped by fixture id —
/// Coventry v Newcastle is in both clubs' payloads. `rows` must be newest first.
export function latestFixtures(
  rows: Array<{ team_id: string; data: unknown }>,
): CachedFixture[] {
  const seenTeam = new Set<string>();
  const byId = new Map<number, CachedFixture>();
  for (const r of rows) {
    if (seenTeam.has(r.team_id)) continue;
    const resp = (r.data as { response?: unknown } | null)?.response;
    if (!Array.isArray(resp) || resp.length === 0) continue;
    seenTeam.add(r.team_id);
    for (const f of resp as CachedFixture[]) {
      if (f?.fixture?.id != null && !byId.has(f.fixture.id)) byId.set(f.fixture.id, f);
    }
  }
  return [...byId.values()];
}

/// Every cached upcoming fixture from the last `hours` of fetches. ~25 entities
/// x 9 runs a day stays well under PostgREST's 1000-row page. Throws on a read
/// error so a caller can tell "no fixtures" from "could not look".
export async function cachedUpcomingFixtures(
  supabase: SupabaseClient,
  hours = 26,
): Promise<CachedFixture[]> {
  const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase
    .from("raw_fetch_logs")
    .select("team_id, data")
    .eq("source", "api_football_fixtures_next")
    .gte("fetched_at", since)
    .order("fetched_at", { ascending: false });
  if (error) throw new Error(`raw_fetch_logs fixtures_next read failed: ${error.message}`);
  return latestFixtures(data ?? []);
}
