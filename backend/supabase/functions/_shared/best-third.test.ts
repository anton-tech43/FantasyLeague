// Deno tests for the cross-group best-third comparator.
//   deno test backend/supabase/functions/_shared/best-third.test.ts

import { classifyBestThird, type GroupThirdBounds } from "./best-third.ts";
import { classifyExactForTeam, coarseThirdPointsBounds, type GroupTeam } from "./group-scenarios.ts";

function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

// Build N "other group" third-bounds. `aboveCount` of them have a thirdMax
// at-or-above `pivot`; the rest are clearly below. `minPts` sets thirdMin.
function others(n: number, opts: { thirdMax: number; thirdMin: number }[]): GroupThirdBounds[] {
  return opts.slice(0, n).map((o, i) => ({ group: `G${i}`, thirdMax: o.thirdMax, thirdMin: o.thirdMin }));
}
function repeat(n: number, thirdMax: number, thirdMin: number): { thirdMax: number; thirdMin: number }[] {
  return Array.from({ length: n }, () => ({ thirdMax, thirdMin }));
}

Deno.test("guaranteed_in: ≤7 other thirds can reach focal's floor", () => {
  // floor=4; 7 groups can reach 4 (thirdMax 5), 4 groups below (thirdMax 3).
  const og = others(11, [...repeat(7, 5, 0), ...repeat(4, 3, 0)]);
  const r = classifyBestThird({ focalGroup: "GX", focalGuaranteedThird: true, focalCanBeThird: true, focalFloorPts: 4, focalCeilPts: 7, otherGroups: og });
  eq(r.status, "guaranteed_in", "status");
});

Deno.test("boundary: exactly 8 others at-or-above floor → NOT guaranteed_in (soft)", () => {
  const og = others(11, [...repeat(8, 5, 0), ...repeat(3, 3, 0)]);
  const r = classifyBestThird({ focalGroup: "GX", focalGuaranteedThird: true, focalCanBeThird: true, focalFloorPts: 4, focalCeilPts: 7, otherGroups: og });
  eq(r.status, "soft", "8 at-or-above → not in");
});

Deno.test("out: ≥8 other thirds guaranteed above focal's ceiling", () => {
  // ceil=2; 8 groups thirdMin=3 (>2) → guaranteed above; 3 groups low.
  const og = others(11, [...repeat(8, 9, 3), ...repeat(3, 9, 0)]);
  const r = classifyBestThird({ focalGroup: "GX", focalGuaranteedThird: false, focalCanBeThird: true, focalFloorPts: 2, focalCeilPts: 2, otherGroups: og });
  eq(r.status, "out", "status");
});

Deno.test("boundary: exactly 7 guaranteed above ceiling → NOT out (soft)", () => {
  const og = others(11, [...repeat(7, 9, 3), ...repeat(4, 9, 0)]);
  const r = classifyBestThird({ focalGroup: "GX", focalGuaranteedThird: false, focalCanBeThird: true, focalFloorPts: 2, focalCeilPts: 2, otherGroups: og });
  eq(r.status, "soft", "7 above → not out");
});

Deno.test("out: focal can never finish 3rd (locked 4th)", () => {
  const og = others(11, repeat(11, 5, 0));
  const r = classifyBestThird({ focalGroup: "GX", focalGuaranteedThird: false, focalCanBeThird: false, focalFloorPts: 0, focalCeilPts: 0, otherGroups: og });
  eq(r.status, "out", "cannot finish third");
  eq(r.reason, "cannot_finish_third", "reason");
});

Deno.test("end-to-end: coarse group bounds → exact focal → best-third guaranteed_in", () => {
  const team = (id: number, points: number): GroupTeam => ({ teamApiId: id, teamName: `T${id}`, points, played: 3, goalsDiff: 0, goalsFor: 0 });
  // Focal group fully played: A is locked EXACTLY 3rd on 3 points.
  const focal = [team(1, 3), team(2, 9), team(3, 6), team(4, 0)];
  const ex = classifyExactForTeam(focal, [], 1);
  // 7 other groups whose 3rd has 3 pts (== focal floor → counts via >=),
  // 4 whose 3rd has only 2 pts (below). atOrAbove = 7 → guaranteed_in.
  const grp = (pts: number[], tag: string): GroupThirdBounds => ({ group: tag, ...coarseThirdPointsBounds(pts.map((p, i) => team(10 + i, p))) });
  const otherGroups = [
    ...Array.from({ length: 7 }, (_, i) => grp([5, 4, 3, 0], `H${i}`)),
    ...Array.from({ length: 4 }, (_, i) => grp([5, 4, 2, 0], `L${i}`)),
  ];
  const r = classifyBestThird({
    focalGroup: "F", focalGuaranteedThird: ex.guaranteedThird, focalCanBeThird: ex.canFinishThird,
    focalFloorPts: 3, focalCeilPts: 3, otherGroups,
  });
  if (r.status !== "guaranteed_in") throw new Error(`expected guaranteed_in, got ${r.status} (ex.guaranteedThird=${ex.guaranteedThird})`);
});

Deno.test("soundness guard: incomplete cross-group data → soft (never falsely 'in')", () => {
  // Only 5 of the 11 other groups present → can't safely assert; must be soft.
  const og = others(5, repeat(5, 3, 0));
  const r = classifyBestThird({ focalGroup: "GX", focalGuaranteedThird: true, focalCanBeThird: true, focalFloorPts: 4, focalCeilPts: 7, otherGroups: og });
  eq(r.status, "soft", "incomplete data stays soft");
  eq(r.reason, "incomplete_cross_group_data", "reason");
});

Deno.test("soft: GD bubble (level on points, neither in nor out on points)", () => {
  // 8 groups can reach focal's floor (so not guaranteed_in), but none are
  // GUARANTEED above its ceiling (so not out) → decided on GD → soft.
  const og = others(11, [...repeat(8, 5, 2), ...repeat(3, 5, 2)]);
  const r = classifyBestThird({ focalGroup: "GX", focalGuaranteedThird: true, focalCanBeThird: true, focalFloorPts: 4, focalCeilPts: 7, otherGroups: og });
  eq(r.status, "soft", "GD bubble stays soft");
  eq(r.reason, "gd_bubble", "reason");
});
