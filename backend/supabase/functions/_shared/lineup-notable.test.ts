import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { bodyForDevice, type LineupPlayer, notableLineup, type Role, rolesFromGrid, type SquadRow, withLineupNotes } from "./lineup-notable.ts";

// A 4-3-3: GK, RB LCB RCB LB, three mids, three forwards. Ids 1..11.
const grid = ["1:1", "2:4", "2:3", "2:2", "2:1", "3:3", "3:2", "3:1", "4:3", "4:2", "4:1"];
const xiOf = (ids: number[]): LineupPlayer[] => ids.map((id, i) => ({ id, name: `P${id}`, grid: grid[i] }));
const base = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
const squad: SquadRow[] = [
  ...base.map((id) => ({ api_player_id: id, name: `Player ${id}`, league_starts: 9 })),
  { api_player_id: 12, name: "Spare Back", league_starts: 1 },
  { api_player_id: 13, name: "Kid Striker", league_starts: 0 },
  { api_player_id: 14, name: "Gabriel Magalhães", known_as: "Gabriel", league_starts: 1 },
];
const roles: Map<number, Role> = rolesFromGrid(xiOf(base));
const run = (ids: number[], previousXI: number[] | null = base, sq = squad) =>
  notableLineup({ xi: xiOf(ids), squad: sq, leaguePlayed: 9, previousXI, lastRole: roles, opponent: "Leeds" });

Deno.test("rolesFromGrid: outer two of a back four are full-backs", () => {
  assertEquals([1, 2, 3, 4, 5, 6, 9].map((id) => roles.get(id)), ["gk", "fb", "cb", "cb", "fb", "mid", "att"]);
});

Deno.test("unchanged XI is silent", () => {
  assertEquals(run(base), null);
});

Deno.test("a regular centre-back benched fires", () => {
  const n = run([1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11]);
  assertEquals(n?.kind, "regular_out");
  assertEquals(n?.line, "3 isn't starting against Leeds. Ask him why.");
});

Deno.test("a regular full-back rested is silent", () => {
  // 12 comes in at right-back (grid 2:4) for 2; 12 is a back, not an outsider in a substance role.
  assertEquals(run([1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11]), null);
});

Deno.test("an outsider up front fires, named the way the league names him", () => {
  const sq = squad.map((r) => r.api_player_id === 13 ? { ...r, known_as: "Nwaneri" } : r);
  // 13 replaces 9, and 9 is a regular attacker, so regular_out wins over outsider.
  assertEquals(run([1, 2, 3, 4, 5, 6, 7, 8, 13, 10, 11], base, sq)?.kind, "regular_out");
  // With 9 a fringe player, the outsider is the story.
  const sq2 = sq.map((r) => r.api_player_id === 9 ? { ...r, league_starts: 1 } : r);
  const n = run([1, 2, 3, 4, 5, 6, 7, 8, 13, 10, 11], base, sq2);
  assertEquals(n?.kind, "outsider_in");
  assertEquals(n?.players, ["Nwaneri"]);
  assertEquals(n?.line, "Nwaneri makes his first league start of the season against Leeds.");
});

Deno.test("a starter we have never heard of is a new name", () => {
  const sq = squad.map((r) => r.api_player_id === 9 ? { ...r, league_starts: 1 } : r);
  const xi = xiOf([1, 2, 3, 4, 5, 6, 7, 8, 99, 10, 11]);
  const n = notableLineup({ xi, squad: sq, leaguePlayed: 9, previousXI: base, lastRole: roles, opponent: "Leeds" });
  assertEquals(n?.line, "P99 starts against Leeds. That's a new name. Ask him who he is.");
});

Deno.test("Newcastle v Everton (2026-11-02): benched gets 'Ask him why', missing from the squad does not", () => {
  // 3 (a regular centre-back) is out of the XI; on the bench, then not.
  const xi = xiOf([1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11]);
  const benched = notableLineup({ xi, squad, leaguePlayed: 9, previousXI: base, lastRole: roles, opponent: "Everton", bench: [3, 13] });
  assertEquals(benched?.line, "3 is on the bench against Everton. Ask him why.");
  const missing = notableLineup({ xi, squad, leaguePlayed: 9, previousXI: base, lastRole: roles, opponent: "Everton", bench: [13] });
  assertEquals(missing?.line, "3 isn't even in the squad against Everton.");
});

Deno.test("five starts out of eight is not a regular any more (70%)", () => {
  const sq = squad.map((r) => r.api_player_id === 3 ? { ...r, league_starts: 6 } : r); // 6 of 9 = 67%
  // 3 is no longer a regular, so the story is the fringe centre-back coming in.
  assertEquals(run([1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11], base, sq)?.kind, "outsider_in");
});

Deno.test("six changes with nobody regular missing fires as rotation", () => {
  const fringe = squad.map((r) => ({ ...r, league_starts: 4 })); // nobody ≥ 70%, nobody ≤ 20%
  const prev = [1, 2, 3, 4, 5, 26, 27, 28, 29, 30, 31];
  const n = run(base, prev, fringe);
  assertEquals(n?.kind, "rotation");
  assertEquals(n?.line.startsWith("6 changes"), true);
});

Deno.test("too early in the season to call anyone a regular", () => {
  const n = notableLineup({
    xi: xiOf([1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11]), squad, leaguePlayed: 2,
    previousXI: null, lastRole: roles, opponent: "Leeds",
  });
  assertEquals(n, null);
});

Deno.test("no stored role: a regular midfielder out still fires, a defender does not", () => {
  const sq = squad.map((r) => r.api_player_id === 6 ? { ...r, position: "Midfielder" }
    : r.api_player_id === 3 ? { ...r, position: "Defender" } : r);
  const none = new Map<number, Role>();
  const mid = notableLineup({ xi: xiOf([1, 2, 3, 4, 5, 12, 7, 8, 9, 10, 11]).map((p, i) => i === 5 ? { ...p, grid: "3:3" } : p),
    squad: sq.map((r) => r.api_player_id === 12 ? { ...r, league_starts: 5 } : r), leaguePlayed: 9, previousXI: null, lastRole: none, opponent: "Leeds" });
  assertEquals(mid?.players, ["6"]);
  const def = notableLineup({ xi: xiOf([1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11]),
    squad: sq.map((r) => r.api_player_id === 12 ? { ...r, league_starts: 5 } : r), leaguePlayed: 9, previousXI: null, lastRole: none, opponent: "Leeds" });
  assertEquals(def, null);
});

Deno.test("kickoff push: a lineup line replaces only its own side's body, never a derby follower's", () => {
  const bodies = { arsenal: "Arsenal vs Spurs kicks off in 25 minutes.", spurs: "Spurs vs Arsenal kicks off in 25 minutes." };
  const note = "Saka is on the bench against Spurs. Ask him why.";
  const { bodies: b, derby } = withLineupNotes(bodies, [{ slug: "arsenal", note }, { slug: undefined, note: "x" }, { slug: "spurs", note: null }]);
  assertEquals(b, { arsenal: note, spurs: bodies.spurs });
  assertEquals(bodyForDevice(["arsenal"], "arsenal", "spurs", b, derby), { side: "arsenal", body: note });
  assertEquals(bodyForDevice(["chelsea", "spurs"], "arsenal", "spurs", b, derby), { side: "spurs", body: bodies.spurs });
  assertEquals(bodyForDevice(["spurs", "arsenal"], "arsenal", "spurs", b, derby), { side: "arsenal", body: bodies.arsenal });
  assertEquals(bodyForDevice(["chelsea"], "arsenal", "spurs", b, derby), null);
  // Every other push passes no derby map and is unchanged: home's body for both.
  assertEquals(bodyForDevice(["spurs", "arsenal"], "arsenal", "spurs", bodies), { side: "arsenal", body: bodies.arsenal });
});
