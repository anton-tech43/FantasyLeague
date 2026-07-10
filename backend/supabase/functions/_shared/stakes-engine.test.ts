// Deno tests for the stakes engine. Run:
//   deno test backend/supabase/functions/_shared/stakes-engine.test.ts
//
// No external deps (local assert helpers) so this runs offline.

import {
  annotateFixtures,
  classifyTopTwo,
  groupSituation,
  type GroupStanding,
  type UpcomingGroupFixture,
} from "./stakes-engine.ts";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error("assertion failed: " + msg);
}
function eq<T>(a: T, b: T, msg: string): void {
  if (a !== b) throw new Error(`${msg}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

// Team api ids: A=1 B=2 C=3 D=4
const A = 1, B = 2, C = 3, D = 4;
function g(pts: [number, number][], played: [number, number][] = []): GroupStanding[] {
  // pts entries are [apiId, points]; played defaults to 2 each unless given.
  const playedMap = new Map(played);
  return pts.map(([id, points]) => ({
    teamApiId: id,
    teamName: `T${id}`,
    points,
    played: playedMap.get(id) ?? 2,
  }));
}
function fx(opponentApiId: number, date = "2026-06-20T18:00:00+00:00"): UpcomingGroupFixture {
  return { date, opponentApiId, opponentName: `T${opponentApiId}`, venue: "home" };
}

// ---- classifyTopTwo ----

Deno.test("classifyTopTwo: group_won when no rival can reach my floor", () => {
  // A 6/2 (min6), others max 3 → clear of all.
  const group = g([[A, 6], [B, 0], [C, 0], [D, 0]]);
  eq(classifyTopTwo(group, A), "group_won", "group_won");
});

Deno.test("classifyTopTwo: through when exactly one rival can reach me", () => {
  const group = g([[A, 6], [B, 4], [C, 1], [D, 1]]);
  eq(classifyTopTwo(group, A), "through", "through");
});

Deno.test("classifyTopTwo: top2_gone when two rivals are certainly above", () => {
  const group = g([[A, 0], [B, 6], [C, 4], [D, 4]]);
  eq(classifyTopTwo(group, A), "top2_gone", "top2_gone");
});

Deno.test("classifyTopTwo: contention when undecided", () => {
  const group = g([[A, 3], [B, 3], [C, 0], [D, 0]], [[A, 1], [B, 1], [C, 1], [D, 1]]);
  eq(classifyTopTwo(group, A), "contention", "contention");
});

// ---- per-fixture scenario labels ----

Deno.test("a draw that secures top-2 → certain 'point sends them through'", () => {
  // Last matchday: A 4/2 vs B 1/2; C 4/2 and D 1/2 play each other.
  const group = g([[A, 4], [B, 1], [C, 4], [D, 1]]);
  const [s] = annotateFixtures(group, A, [fx(B)]);
  eq(s.reason, "avoid_defeat_through", "reason");
  eq(s.certainty, "certain", "certainty");
  assert(s.importance_label.includes("point") || s.importance_label.includes("through"), "label asserts through");
});

Deno.test("win secures, draw does not → certain 'win and they're through'", () => {
  const group = g([[A, 4], [B, 1], [C, 2], [D, 2]]);
  const [s] = annotateFixtures(group, A, [fx(B)]);
  eq(s.reason, "win_through", "reason");
  eq(s.certainty, "certain", "certainty");
});

Deno.test("losing kills top-2 but winning isn't yet enough → soft must-not-lose", () => {
  // C & D both 4/2 and play each other, so the winner reaches 7 and could
  // pass A even if A wins → win not guaranteed; loss → top2_gone.
  const group = g([[A, 3], [B, 0], [C, 4], [D, 4]]);
  const [s] = annotateFixtures(group, A, [fx(B)]);
  eq(s.reason, "must_not_lose", "reason");
  eq(s.certainty, "soft", "certainty (depends on other game)");
});

Deno.test("already won the group → dead rubber, certain", () => {
  const group = g([[A, 6], [B, 0], [C, 0], [D, 0]]);
  const [s] = annotateFixtures(group, A, [fx(B)]);
  eq(s.reason, "group_won_dead_rubber", "reason");
  eq(s.stakes_level, "qualified_already", "level");
});

Deno.test("through but win can top group → can_improve_seeding, certain", () => {
  // A 6/2 through; only D 1 can't catch but B 4 can → not group_won; beating
  // C (1) takes A to 9 and clear of everyone → win tops the group.
  const group = g([[A, 6], [B, 4], [C, 1], [D, 1]]);
  const [s] = annotateFixtures(group, A, [fx(C)]);
  eq(s.reason, "seeding_top_spot", "reason");
  eq(s.stakes_level, "can_improve_seeding", "level");
});

Deno.test("through and win still can't top → dead rubber (already through)", () => {
  const group = g([[A, 6], [B, 6], [C, 1], [D, 1]]);
  const [s] = annotateFixtures(group, A, [fx(C)]);
  eq(s.reason, "through_dead_rubber", "reason");
  eq(s.stakes_level, "qualified_already", "level");
});

Deno.test("top2 gone → soft long-shot, never asserts elimination", () => {
  const group = g([[A, 0], [B, 6], [C, 4], [D, 4]]);
  const [s] = annotateFixtures(group, A, [fx(B)]);
  eq(s.reason, "third_place_longshot", "reason");
  eq(s.certainty, "soft", "soft");
  const lc = s.importance_label.toLowerCase();
  assert(!lc.includes("out") && !lc.includes("eliminat"), "must not assert out");
});

Deno.test("pre-tournament opener (no games played) → soft opener", () => {
  const group = g([[A, 0], [B, 0], [C, 0], [D, 0]], [[A, 0], [B, 0], [C, 0], [D, 0]]);
  const [s] = annotateFixtures(group, A, [fx(B)]);
  eq(s.reason, "group_opener", "reason");
  eq(s.certainty, "soft", "soft");
});

Deno.test("non-group fixture (friendly) marked low importance", () => {
  const group = g([[A, 0], [B, 0], [C, 0], [D, 0]], [[A, 0], [B, 0], [C, 0], [D, 0]]);
  const [s] = annotateFixtures(group, A, [fx(999)]); // 999 not in group
  eq(s.reason, "non_group", "reason");
  assert(s.importance_dots <= 2, "low dots");
});

// ---- live / just-finished override (team-page live-game bug) ----

function fxLive(
  opponentApiId: number,
  phase: "live" | "just_finished",
  date = "2026-06-17T20:00:00+00:00",
): UpcomingGroupFixture {
  return { ...fx(opponentApiId, date), phase };
}

Deno.test("live opener: in_progress label, and the genuine next game is NOT mislabeled the opener", () => {
  // The exact buggy condition: nobody has played yet (played 0 all round), so
  // labelSoonestGroupGame would stamp the soonest game "group_opener". With A's
  // first game live, A vs B leads as in_progress and A's next game (C) must be
  // a later_group_game, not "First game".
  const group = g([[A, 0], [B, 0], [C, 0], [D, 0]], [[A, 0], [B, 0], [C, 0], [D, 0]]);
  const [live, next] = annotateFixtures(group, A, [
    fxLive(B, "live"),
    fx(C, "2026-06-23T20:00:00+00:00"),
  ]);
  eq(live.reason, "in_progress", "live game labeled in_progress");
  assert(live.importance_label.toLowerCase().includes("live"), "live label");
  eq(next.reason, "later_group_game", "next game is not the opener (regression guard)");
});

Deno.test("just-finished override: full-time label, next game still not the opener", () => {
  const group = g([[A, 0], [B, 0], [C, 0], [D, 0]], [[A, 0], [B, 0], [C, 0], [D, 0]]);
  const [done, next] = annotateFixtures(group, A, [fxLive(B, "just_finished"), fx(C)]);
  eq(done.reason, "just_finished", "just_finished label");
  eq(next.reason, "later_group_game", "next not opener");
});

Deno.test("openerPlayed: a finished opener (standings still 0) → next game is NOT 'group opener'", () => {
  // The residual bug: A beat B, but the standings feed still reads played 0 for
  // everyone. Without openerPlayed, the next game (C) gets stamped group_opener
  // ("First game"). With openerPlayed=true (from match_status_state), it must not.
  const group = g([[A, 0], [B, 0], [C, 0], [D, 0]], [[A, 0], [B, 0], [C, 0], [D, 0]]);
  const [s] = annotateFixtures(group, A, [fx(C)], undefined, undefined, true);
  assert(s.reason !== "group_opener", "must not be the opener after a game has been played");
  // Sanity: the same input WITHOUT openerPlayed still hits the (buggy) opener path.
  const [bug] = annotateFixtures(group, A, [fx(C)]);
  eq(bug.reason, "group_opener", "control: laggy standings alone would mislabel");
});

// ---- invariants across all branches ----

Deno.test("all importance_labels are <= 30 chars and dots in 1..5", () => {
  const scenarios: GroupStanding[][] = [
    g([[A, 6], [B, 0], [C, 0], [D, 0]]),
    g([[A, 6], [B, 4], [C, 1], [D, 1]]),
    g([[A, 0], [B, 6], [C, 4], [D, 4]]),
    g([[A, 4], [B, 1], [C, 4], [D, 1]]),
    g([[A, 3], [B, 0], [C, 4], [D, 4]]),
    g([[A, 0], [B, 0], [C, 0], [D, 0]], [[A, 0], [B, 0], [C, 0], [D, 0]]),
  ];
  for (const group of scenarios) {
    const ann = annotateFixtures(group, A, [fx(B), fx(C)]);
    for (const s of ann) {
      assert(s.importance_label.length <= 30, `label too long: "${s.importance_label}"`);
      assert(s.importance_dots >= 1 && s.importance_dots <= 5, `dots out of range: ${s.importance_dots}`);
    }
  }
});

Deno.test("TRUTH: a 'certain' label only appears when a result guarantees top-2", () => {
  // The two certain assertive labels must never be emitted for a team that
  // can't actually reach top-2 from that result. Re-derive and check.
  const group = g([[A, 4], [B, 1], [C, 4], [D, 1]]); // avoid_defeat_through
  const [s] = annotateFixtures(group, A, [fx(B)]);
  if (s.certainty === "certain") {
    // For avoid_defeat: a draw must yield top-2.
    const afterDraw = classifyTopTwo(
      group.map((t) =>
        t.teamApiId === A
          ? { ...t, points: t.points + 1, played: t.played + 1 }
          : t.teamApiId === B
          ? { ...t, points: t.points + 1, played: t.played + 1 }
          : t
      ),
      A,
    );
    assert(afterDraw === "through" || afterDraw === "group_won", "certain claim must be backed by math");
  }
});

Deno.test("groupSituation: top2_gone is soft, through is certain", () => {
  eq(groupSituation(g([[A, 0], [B, 6], [C, 4], [D, 4]]), A).certainty, "soft", "gone is soft");
  eq(groupSituation(g([[A, 6], [B, 4], [C, 1], [D, 1]]), A).stakes_level, "qualified_already", "through level");
});

// ---- exact-math override path ----

function exactState(p: Partial<import("./stakes-engine.ts").ExactInfo["state"]>) {
  return {
    worstRank: 4, bestRank: 4, guaranteedGroupWin: false, guaranteedTop2: false,
    canFinishFirst: false, top2Closed: false, canFinishThird: false, guaranteedThird: false,
    ...p,
  };
}

Deno.test("exact: guaranteed top-2 → certain 'At worst 2nd'", () => {
  const [s] = annotateFixtures(g([[A, 6], [B, 4], [C, 1], [D, 1]]), A, [fx(B)], 3, {
    state: exactState({ worstRank: 2, bestRank: 1, guaranteedTop2: true, canFinishFirst: true }),
  });
  eq(s.reason, "at_worst_second", "reason");
  eq(s.certainty, "certain", "certain");
});

Deno.test("exact: best-third guaranteed_in → certain 'through as a best third'", () => {
  const [s] = annotateFixtures(g([[A, 3], [B, 6], [C, 6], [D, 0]]), A, [fx(B)], 3, {
    state: exactState({ worstRank: 3, bestRank: 3, top2Closed: true, canFinishThird: true, guaranteedThird: true }),
    bestThird: { status: "guaranteed_in", reason: "points_locked_in" },
  });
  eq(s.reason, "third_place_through", "reason");
  eq(s.certainty, "certain", "certain");
});

Deno.test("exact: best-third out → in-app 'out of the tournament' (muted, eliminated level)", () => {
  const [s] = annotateFixtures(g([[A, 0], [B, 6], [C, 4], [D, 4]]), A, [fx(B)], 3, {
    state: exactState({ worstRank: 4, bestRank: 3, top2Closed: true, canFinishThird: true }),
    bestThird: { status: "out", reason: "points_locked_out" },
  });
  eq(s.reason, "third_place_out", "reason");
  eq(s.stakes_level, "eliminated", "level");
});

Deno.test("exact: best-third soft → falls back to soft longshot", () => {
  const [s] = annotateFixtures(g([[A, 0], [B, 6], [C, 4], [D, 4]]), A, [fx(B)], 3, {
    state: exactState({ worstRank: 4, bestRank: 3, top2Closed: true, canFinishThird: true }),
    bestThird: { status: "soft", reason: "gd_bubble" },
  });
  eq(s.certainty, "soft", "soft");
  eq(s.reason, "third_place_longshot", "reason");
});
