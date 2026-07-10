// Deno tests for the pure WC qualification helpers in detect-consequences.
//   deno test backend/supabase/functions/_shared/detect-consequences.test.ts

import { guaranteedExactlyThird, matchdayFromRound, wcSnapshotComplete } from "./detect-consequences.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

Deno.test("matchdayFromRound parses the group-stage matchday", () => {
  eq(matchdayFromRound("Group Stage - 3"), 3, "MD3");
  eq(matchdayFromRound("Group Stage - 1"), 1, "MD1");
  eq(matchdayFromRound("Round of 16"), null, "knockout → null");
  eq(matchdayFromRound(undefined), null, "missing → null");
});

Deno.test("wcSnapshotComplete: incomplete simultaneous final matchday → false (defer hard pushes)", () => {
  // MD3: two playing teams at 3, the OTHER game not yet in the snapshot (a team still 2).
  assert(!wcSnapshotComplete([3, 3, 2, 3], "Group Stage - 3"), "incomplete MD3 → false");
  assert(wcSnapshotComplete([3, 3, 3, 3], "Group Stage - 3"), "complete MD3 → true");
  assert(wcSnapshotComplete([2, 2, 2, 2], "Group Stage - 2"), "complete MD2 → true");
  assert(!wcSnapshotComplete([2, 1, 2, 2], "Group Stage - 2"), "incomplete MD2 → false");
  assert(wcSnapshotComplete([1, 1, 0, 1], "Round of 16"), "unknown round → true (fallback)");
});

Deno.test("guaranteedExactlyThird: locked 3rd (2 above, 1 below, games done)", () => {
  assert(
    guaranteedExactlyThird(3, 3, [{ points: 9, played: 3 }, { points: 6, played: 3 }, { points: 0, played: 3 }]),
    "3 pts, two clear above, one clear below → guaranteed 3rd",
  );
});

Deno.test("guaranteedExactlyThird: NOT locked while games remain", () => {
  assert(
    !guaranteedExactlyThird(3, 2, [{ points: 4, played: 2 }, { points: 4, played: 2 }, { points: 1, played: 2 }]),
    "a game left → nobody guaranteed above focal's ceiling → not locked",
  );
});

Deno.test("guaranteedExactlyThird: focal is 4th (3 above) → not 'exactly 3rd'", () => {
  assert(
    !guaranteedExactlyThird(0, 3, [{ points: 9, played: 3 }, { points: 6, played: 3 }, { points: 3, played: 3 }]),
    "locked 4th is not guaranteed-3rd",
  );
});
