// deno test backend/supabase/functions/_shared/last-match.test.ts

import type { StoredGoalEvent } from "./goal-push.ts";
import {
  ordinal,
  parseFixtureStats,
  pickThreeNumbers,
  renderGoals,
  renderVerdict,
  sideGoals,
  type VerdictInput,
} from "./last-match.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${m}: ${JSON.stringify(a)} !== ${JSON.stringify(b)}`);
}

const ev = (side: "home" | "away", minute: number, extra: number | null = null, more: Partial<StoredGoalEvent> = {}): StoredGoalEvent =>
  ({ side, player: "B. Saka", playerApiId: 1460, minute, extra, isOwnGoal: false, isPenalty: false, ...more });

function input(over: Partial<VerdictInput>): VerdictInput {
  return {
    teamName: "Arsenal", opponentName: "Leeds", state: "win", teamScore: 2, oppScore: 1,
    ht: { mine: 1, theirs: 0 }, goals: [], mine: {}, theirs: {}, unusualFinish: false,
    fallback: "Arsenal beat Leeds 2-1 at home in the Premier League.", ...over,
  };
}

Deno.test("ordinal", () => {
  eq([1, 2, 3, 4, 11, 12, 13, 21, 88, 90].map(ordinal), ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "88th", "90th"], "ordinals");
});

Deno.test("running score is ours-first and in time order, stoppage after the minute", () => {
  const g = sideGoals([ev("home", 88), ev("away", 61), ev("home", 23), ev("away", 45, 2)], "home");
  eq(g.map((x) => `${x.mine}-${x.theirs}`), ["1-0", "1-1", "1-2", "2-2"], "order");
  eq(g[2].shownMinute, "61'", "plain minute");
  eq(sideGoals([ev("home", 45, 2)], "away")[0].shownMinute, "45+2'", "stoppage");
  eq(sideGoals([ev("home", 10)], "away")[0].ours, false, "away perspective");
});

Deno.test("late winner verdict and number", () => {
  const goals = sideGoals([ev("home", 23), ev("away", 61), ev("home", 88)], "home");
  const v = input({ goals, mine: { shots: 6, onTarget: 3 }, theirs: { shots: 9, onTarget: 2 } });
  eq(renderVerdict(v), "Won it in the 88th minute after Leeds had more of the chances.", "verdict");
  const n = pickThreeNumbers(v);
  assert(n.length === 3, "three numbers");
  eq(n[0], { value: "88'", caption: "when the winner went in." }, "winner minute first");
});

Deno.test("crushing win: zero on target leads", () => {
  const goals = sideGoals([ev("home", 12), ev("home", 33), ev("home", 41), ev("home", 77)], "home");
  const v = input({ teamScore: 4, oppScore: 0, ht: { mine: 3, theirs: 0 }, goals,
    mine: { shots: 17, onTarget: 9, possession: 62 }, theirs: { shots: 4, onTarget: 0, possession: 38 } });
  eq(renderVerdict(v), "Over long before the end. Leeds never had a shot on target.", "verdict");
  eq(pickThreeNumbers(v).map((r) => r.value), ["0", "17–4", "3–0"], "numbers");
});

Deno.test("bore draw", () => {
  const v = input({ state: "draw", teamScore: 0, oppScore: 0, ht: { mine: 0, theirs: 0 },
    mine: { shots: 8, onTarget: 1, possession: 68 }, theirs: { shots: 5, onTarget: 1, possession: 32 } });
  eq(renderVerdict(v), "Ninety minutes, 2 shots on target between them.", "verdict");
  eq(pickThreeNumbers(v)[0], { value: "68%", caption: "possession, and nothing to show for it." }, "possession");
});

Deno.test("unlucky loss and late equalisers", () => {
  const v = input({ state: "loss", teamScore: 0, oppScore: 1, ht: { mine: 0, theirs: 0 },
    goals: sideGoals([ev("away", 71)], "home"),
    mine: { shots: 21, onTarget: 7, xg: 2.4 }, theirs: { shots: 5, onTarget: 2, xg: 0.6 } });
  eq(renderVerdict(v), "Arsenal had the chances, Leeds had the goal.", "verdict");
  assert(pickThreeNumbers(v).some((r) => r.value === "2.4"), "xG shows on an unlucky loss");
  const saved = input({ state: "draw", teamScore: 1, oppScore: 1, goals: sideGoals([ev("away", 30), ev("home", 90, 3)], "home") });
  eq(renderVerdict(saved), "Saved a point in the 90th minute.", "late equaliser");
});

Deno.test("extra time falls back to the plain sentence", () => {
  eq(renderVerdict(input({ unusualFinish: true })), "Arsenal beat Leeds 2-1 at home in the Premier League.", "fallback");
});

Deno.test("goal lines: season count only from a sync before kickoff", () => {
  const goals = sideGoals([ev("home", 23, null, { playerApiId: 7 }), ev("home", 88, null, { playerApiId: 7, isPenalty: true }), ev("away", 50)], "home");
  const kickoff = "2026-10-10T14:00:00Z";
  const fresh = renderGoals(goals, "Arsenal", "Leeds", kickoff,
    new Map([[7, { name: "Kai Havertz", number: 29, goals: 2, statsUpdatedAt: "2026-10-10T05:30:00Z" }]]));
  eq(fresh.length, 3, "both sides' goals");
  eq(fresh[0], { ours: true, team: "Arsenal", player: "Kai Havertz", api_player_id: 7, number: 29, minute: "23'", score: "1–0 Arsenal", line: "His 3rd goal of the season." }, "first goal");
  eq(fresh[1].line, "The equaliser.", "their goal, from their side");
  eq([fresh[1].ours, fresh[1].team, fresh[1].score], [false, "Leeds", "1–1 Leeds"], "their goal is named for them");
  eq(fresh[2].line, "His 4th goal of the season, from the penalty spot.", "second goal counts on");
  const stale = renderGoals(goals, "Arsenal", "Leeds", kickoff,
    new Map([[7, { name: "Kai Havertz", number: 29, goals: 3, statsUpdatedAt: "2026-10-10T15:00:00Z" }]]));
  eq(stale[0].line, "The opener.", "no count from a mid-game sync");
  eq(stale[2].line, "Scored from the penalty spot.", "penalty still said");
});

Deno.test("parseFixtureStats", () => {
  const m = parseFixtureStats([
    { team: { id: 42 }, statistics: [{ type: "Total Shots", value: 17 }, { type: "Shots on Goal", value: 6 }, { type: "Ball Possession", value: "61%" }, { type: "expected_goals", value: "2.13" }, { type: "Corner Kicks", value: null }] },
    { team: { id: 63 }, statistics: [{ type: "Total Shots", value: null }] },
    "junk",
  ]);
  eq(m.get(42), { shots: 17, onTarget: 6, possession: 61, xg: 2.13 }, "home stats");
  eq(m.get(63), {}, "nulls skipped");
  eq(parseFixtureStats(null).size, 0, "null input");
});
