// Deno tests for the WC next-fixture rollover helpers.
//   deno test backend/supabase/functions/_shared/fixture-rollover.test.ts

import { collectFinishedFixtureIds, dropFinished, filterFixturesByLeague } from "./fixture-rollover.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

const lastPayload = (rows: Array<[number, string]>) => ({
  response: rows.map(([id, short]) => ({ fixture: { id, status: { short } } })),
});

Deno.test("collectFinishedFixtureIds: only finished statuses, ids collected", () => {
  const s = collectFinishedFixtureIds([
    lastPayload([[100, "FT"], [101, "AET"], [102, "NS"], [103, "PEN"], [104, "PST"]]),
  ]);
  assert(s.has(100) && s.has(101) && s.has(103), "FT/AET/PEN counted");
  assert(!s.has(102) && !s.has(104), "NS/PST (not played) excluded");
  eq(s.size, 3, "exactly the three played");
});

Deno.test("collectFinishedFixtureIds: unions across payloads, tolerates junk", () => {
  const s = collectFinishedFixtureIds([
    lastPayload([[200, "FT"]]),
    { response: [] }, // a transiently-empty later fetch must not erase 200
    null,
    { nonsense: true },
    lastPayload([[201, "FT"]]),
  ]);
  assert(s.has(200) && s.has(201), "union keeps both, empty/bad payloads ignored");
  eq(s.size, 2, "no phantom ids from junk");
});

Deno.test("dropFinished: removes played fixtures, keeps unplayed + id-less", () => {
  const fx = [
    { fixtureId: 100, opp: "Tunisia" }, // played
    { fixtureId: 200, opp: "Netherlands" }, // still to play
    { opp: "Japan" }, // no id → kept (date-grace is its guard)
  ];
  const out = dropFinished(fx, new Set([100]));
  eq(out.length, 2, "one dropped");
  assert(out.some((f) => f.opp === "Netherlands") && out.some((f) => f.opp === "Japan"), "right ones kept");
  assert(!out.some((f) => f.opp === "Tunisia"), "played one gone");
});

Deno.test("dropFinished: empty finished-set is a no-op (today's pre-tournament state)", () => {
  const fx = [{ fixtureId: 1 }, { fixtureId: 2 }];
  eq(dropFinished(fx, new Set<number>()).length, 2, "nothing dropped when nothing played");
});

Deno.test("filterFixturesByLeague: keeps WC (league 1) games, drops Nations League / quals", () => {
  // The real shape: England's fixtures_next carries 3 WC games (league 1) plus
  // 6 UEFA Nations League games (league 5) dated Sep-Nov 2026.
  const response = [
    { league: { id: 1, name: "World Cup" }, fixture: { id: 1 }, teams: {} },
    { league: { id: 5, name: "UEFA Nations League" }, fixture: { id: 2 }, teams: {} },
    { league: { id: 1, name: "World Cup" }, fixture: { id: 3 }, teams: {} },
    { league: { id: 5, name: "UEFA Nations League" }, fixture: { id: 4 }, teams: {} },
    { fixture: { id: 5 } }, // malformed (no league) → dropped
  ];
  const wc = filterFixturesByLeague(response, 1);
  eq(wc.length, 2, "only the two WC games survive");
  assert(
    wc.every((i) => ((i as Record<string, unknown>).league as Record<string, unknown>).id === 1),
    "every surviving item is league 1",
  );
  eq(filterFixturesByLeague([], 1).length, 0, "empty in, empty out");
  // deno-lint-ignore no-explicit-any
  eq(filterFixturesByLeague(null as any, 1).length, 0, "non-array in, empty out");
});

Deno.test("rollover: a stale fixtures_next still listing a played opener rolls to game 2", () => {
  // Simulate the fallback hazard: a stale snapshot lists all 3 group games;
  // the opener (id 100) has since been played per fixtures_last.
  const staleUpcoming = [
    { fixtureId: 100, opponentName: "Tunisia", date: "2026-06-15T18:00:00+00:00" },
    { fixtureId: 200, opponentName: "Netherlands", date: "2026-06-21T18:00:00+00:00" },
    { fixtureId: 300, opponentName: "Japan", date: "2026-06-25T18:00:00+00:00" },
  ];
  const finished = collectFinishedFixtureIds([lastPayload([[100, "FT"]])]);
  const surviving = dropFinished(staleUpcoming, finished);
  eq(surviving[0].opponentName, "Netherlands", "next rolls forward to game 2, not the played opener");
});
