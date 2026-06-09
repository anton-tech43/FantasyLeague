// Deno tests for the exact within-group scenario engine.
//   deno test backend/supabase/functions/_shared/group-scenarios.test.ts

import {
  classifyExactForTeam,
  coarseThirdPointsBounds,
  type GroupTeam,
  type RemainingGame,
} from "./group-scenarios.ts";
import { classifyExactPointsOnly } from "./stakes-engine.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

const A = 1, B = 2, C = 3, D = 4;
function g(spec: Record<number, [number, number]>): GroupTeam[] {
  return Object.entries(spec).map(([id, [points, played]]) => ({
    teamApiId: Number(id), teamName: `T${id}`, points, played, goalsDiff: 0, goalsFor: 0,
  }));
}
const rg = (h: number, a: number): RemainingGame => ({ homeApiId: h, awayApiId: a });

Deno.test("guaranteed group win → worstRank 1", () => {
  const s = classifyExactForTeam(g({ [A]: [6, 2], [B]: [0, 2], [C]: [0, 2], [D]: [0, 2] }), [rg(A, B), rg(C, D)], A);
  eq(s.worstRank, 1, "worstRank");
  assert(s.guaranteedGroupWin && s.guaranteedTop2, "guaranteed win+top2");
});

Deno.test("at worst 2nd (guaranteed top-2, not group win)", () => {
  const s = classifyExactForTeam(g({ [A]: [6, 2], [B]: [4, 2], [C]: [1, 2], [D]: [1, 2] }), [rg(A, C), rg(B, D)], A);
  eq(s.worstRank, 2, "worstRank");
  assert(s.guaranteedTop2, "guaranteedTop2");
  assert(!s.guaranteedGroupWin, "not guaranteed win");
  assert(s.canFinishFirst, "can still finish 1st");
});

Deno.test("can only finish 4th → top2 closed, can't be 3rd (an 'out' shape)", () => {
  const s = classifyExactForTeam(g({ [A]: [0, 2], [B]: [6, 2], [C]: [4, 2], [D]: [4, 2] }), [rg(A, B), rg(C, D)], A);
  eq(s.worstRank, 4, "worstRank");
  eq(s.bestRank, 4, "bestRank");
  assert(s.top2Closed, "top2Closed");
  assert(!s.canFinishThird, "cannot be 3rd");
});

Deno.test("level on 4 with a rival able to overtake → NOT guaranteed top-2 (ties count against)", () => {
  // Current GD might favour A, but the engine ignores GD and counts the
  // points-tie against A, so it refuses 'at worst 2nd'.
  const s = classifyExactForTeam(g({ [A]: [4, 2], [B]: [4, 2], [C]: [4, 2], [D]: [0, 2] }), [rg(A, D), rg(B, C)], A);
  assert(!s.guaranteedTop2, "must NOT claim guaranteed top-2");
  eq(s.worstRank, 3, "worstRank (can be 3rd)");
  assert(s.canFinishThird, "can be 3rd");
  assert(s.canFinishFirst, "can still win it");
});

Deno.test("enumeration is TIGHTER than points-only when the two rivals play each other", () => {
  // A=6, the only two teams that could catch A (B,C on 4) play EACH OTHER on
  // the final matchday, so at most one can reach 7 → A is at worst 2nd.
  const teams = g({ [A]: [6, 2], [B]: [4, 2], [C]: [4, 2], [D]: [1, 2] });
  const remaining = [rg(A, D), rg(B, C)]; // A v D, and the rivals B v C
  const exact = classifyExactForTeam(teams, remaining, A);
  const pointsOnly = classifyExactPointsOnly(
    teams.map((t) => ({ teamApiId: t.teamApiId, teamName: t.teamName, points: t.points, played: t.played })),
    A,
  );
  assert(exact.guaranteedTop2, "enumeration: at worst 2nd (rivals play each other)");
  assert(!pointsOnly.guaranteedTop2, "points-only: cannot prove it (both rivals could reach 7 independently)");
});

Deno.test("coarseThirdPointsBounds: 3rd-highest of maxes (upper) and of floors (lower)", () => {
  const b = coarseThirdPointsBounds(g({ [A]: [6, 2], [B]: [4, 2], [C]: [3, 2], [D]: [1, 2] }));
  eq(b.thirdMax, 6, "thirdMax = 3rd-highest of maxes [9,7,6,4]");
  eq(b.thirdMin, 3, "thirdMin = 3rd-highest of floors [6,4,3,1]");
});

Deno.test("guaranteedThird: locked exactly 3rd (two clear above, one clear below, no tie)", () => {
  const s = classifyExactForTeam(g({ [A]: [3, 3], [B]: [9, 3], [C]: [6, 3], [D]: [0, 3] }), [], A);
  eq(s.worstRank, 3, "worst");
  eq(s.bestRank, 3, "best");
  assert(s.guaranteedThird, "guaranteedThird (above==2, tied==0 in every scenario)");
  assert(s.canFinishThird && s.top2Closed, "canFinishThird + top2Closed");
});

Deno.test("goal difference is IGNORED — a big GD lead never earns a top-2 claim", () => {
  const teams = g({ [A]: [4, 2], [B]: [4, 2], [C]: [4, 2], [D]: [0, 2] });
  teams.find((t) => t.teamApiId === A)!.goalsDiff = 99; // huge (irrelevant) GD lead
  teams.find((t) => t.teamApiId === A)!.goalsFor = 99;
  const s = classifyExactForTeam(teams, [rg(A, D), rg(B, C)], A);
  assert(!s.guaranteedTop2, "GD must NOT earn 'guaranteed top-2' on a level-points tie");
  eq(s.worstRank, 3, "can still be 3rd on the tie");
});

Deno.test("no remaining games → bounds reflect current points exactly", () => {
  // All played; A clear 1st, D clear 4th.
  const s = classifyExactForTeam(g({ [A]: [9, 3], [B]: [6, 3], [C]: [3, 3], [D]: [0, 3] }), [], A);
  eq(s.worstRank, 1, "A locked 1st");
  const sd = classifyExactForTeam(g({ [A]: [9, 3], [B]: [6, 3], [C]: [3, 3], [D]: [0, 3] }), [], D);
  eq(sd.worstRank, 4, "D locked 4th");
  assert(sd.top2Closed && !sd.canFinishThird, "D out");
});
