// Deno tests for the WC goal-push helpers.
//   deno test backend/supabase/functions/_shared/goal-push.test.ts

import {
  detectGoal,
  formatMinute,
  formatScorerLine,
  type GoalEvent,
  interpolate,
  pickLatestGoalForTeam,
  renderFullTimePush,
  renderGoalPush,
  renderHalfTimePush,
  renderKickoffSoonPush,
  toStoredGoalEvents,
} from "./goal-push.ts";
import {
  FT_DRAW,
  FT_LOSS,
  FT_WIN,
  GOAL_BOTH,
  GOAL_CONCEDED,
  GOAL_SCORED,
  HT_AHEAD,
  HT_BEHIND,
  HT_LEVEL,
  KICKOFF_SOON,
} from "./goal-push-copy.ts";
import { WC_COUNTRY_META } from "./wc-countries.ts";

const MEX = { id: "mexico", name: "Mexico", flag: "🇲🇽" };
const RSA = { id: "south_africa", name: "S. Africa", flag: "🇿🇦" };
const JPN = { id: "japan", name: "Japan", flag: "🇯🇵" };
const NED = { id: "netherlands", name: "Netherlands", flag: "🇳🇱" };

// Deterministic rng so a test knows which pool entry was chosen (index 0).
const zero = () => 0;

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

// ============================================================
// detectGoal (unchanged behavior)
// ============================================================

Deno.test("detectGoal: home / away / both / none", () => {
  eq(detectGoal(0, 0, 1, 0), "home", "home goal");
  eq(detectGoal(1, 0, 1, 1), "away", "away goal");
  eq(detectGoal(0, 0, 1, 1), "both", "two goals between ticks");
  eq(detectGoal(2, 1, 2, 1), null, "no change");
});

Deno.test("detectGoal: null prior (pre-kickoff row) counts as 0", () => {
  eq(detectGoal(null, null, 1, 0), "home", "first goal vs null prior");
  eq(detectGoal(undefined, undefined, 0, 0), null, "0-0 vs null prior is no goal");
});

Deno.test("detectGoal: VAR overturn (decrease) never pushes", () => {
  eq(detectGoal(1, 0, 0, 0), null, "home goal disallowed");
  eq(detectGoal(2, 1, 2, 0), null, "away goal disallowed");
  eq(detectGoal(1, 0, 0, 1), "away", "swap: disallowed home + scored away");
});

// ============================================================
// interpolate
// ============================================================

Deno.test("interpolate: fills present tokens, drops absent ones, tidies spacing", () => {
  eq(
    interpolate("{flag} {team} score! {score}.", { flag: "🇲🇽", team: "Mexico", score: "2-0" }),
    "🇲🇽 Mexico score! 2-0.",
    "all tokens",
  );
  // An absent token leaves no double space behind.
  eq(interpolate("{team} score, {score}.", { score: "2-0" }), "score, 2-0.", "absent {team} tidied");
});

// ============================================================
// renderGoalPush perspective routing (rng:zero pins pool index 0)
// ============================================================

Deno.test("renderGoalPush: scorer pool to scorer slug, conceder pool to conceder slug", () => {
  const copy = renderGoalPush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0, side: "home", rng: zero });
  eq(copy.title, "GOAL: Mexico 2-0 S. Africa", "title carries home-away scoreline");
  const vars = { flag: MEX.flag, team: MEX.name, score: "2-0" };
  eq(copy.bodies.mexico, interpolate(GOAL_SCORED[0], vars), "scorer body from GOAL_SCORED");
  eq(copy.bodies.south_africa, interpolate(GOAL_CONCEDED[0], vars), "conceder body from GOAL_CONCEDED");
});

Deno.test("renderGoalPush: side away flips which slug gets the scorer pool", () => {
  const copy = renderGoalPush({ home: MEX, away: RSA, homeGoals: 0, awayGoals: 1, side: "away", rng: zero });
  const vars = { flag: RSA.flag, team: RSA.name, score: "0-1" };
  eq(copy.bodies.south_africa, interpolate(GOAL_SCORED[0], vars), "away scorer body");
  eq(copy.bodies.mexico, interpolate(GOAL_CONCEDED[0], vars), "home conceder body references the scorer");
});

Deno.test("renderGoalPush: 'both' shares one neutral body across both slugs", () => {
  const copy = renderGoalPush({ home: JPN, away: NED, homeGoals: 1, awayGoals: 1, side: "both", rng: zero });
  const body = interpolate(GOAL_BOTH[0], { home: "Japan", away: "Netherlands", score: "1-1" });
  eq(copy.bodies.japan, body, "japan body from GOAL_BOTH");
  eq(copy.bodies.netherlands, body, "same neutral body both sides");
});

// ============================================================
// renderHalfTimePush perspective routing
// ============================================================

Deno.test("renderHalfTimePush: ahead/behind pools by perspective, score follower-first", () => {
  const copy = renderHalfTimePush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0, rng: zero });
  eq(copy.title, "Half-time: Mexico 2-0 S. Africa", "title carries home-away scoreline");
  eq(copy.bodies.mexico, interpolate(HT_AHEAD[0], { score: "2-0", team: "Mexico" }), "leader from HT_AHEAD");
  eq(copy.bodies.south_africa, interpolate(HT_BEHIND[0], { score: "0-2", team: "S. Africa" }), "trailer from HT_BEHIND");
});

Deno.test("renderHalfTimePush: level draws both sides from HT_LEVEL", () => {
  const copy = renderHalfTimePush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 1, rng: zero });
  eq(copy.bodies.mexico, interpolate(HT_LEVEL[0], { score: "1-1", team: "Mexico" }), "home from HT_LEVEL");
  eq(copy.bodies.south_africa, interpolate(HT_LEVEL[0], { score: "1-1", team: "S. Africa" }), "away from HT_LEVEL");
});

// ============================================================
// renderFullTimePush perspective routing
// ============================================================

Deno.test("renderFullTimePush: win/loss pools by perspective", () => {
  const copy = renderFullTimePush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0, rng: zero });
  eq(copy.title, "Full-time: Mexico 2-0 S. Africa", "title carries the scoreline");
  eq(copy.bodies.mexico, interpolate(FT_WIN[0], { score: "2-0", team: "Mexico" }), "winner from FT_WIN");
  eq(copy.bodies.south_africa, interpolate(FT_LOSS[0], { score: "0-2", team: "S. Africa" }), "loser from FT_LOSS");
});

Deno.test("renderFullTimePush: draw draws both sides from FT_DRAW", () => {
  const copy = renderFullTimePush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 1, rng: zero });
  eq(copy.bodies.mexico, interpolate(FT_DRAW[0], { score: "1-1", team: "Mexico" }), "home from FT_DRAW");
  eq(copy.bodies.south_africa, interpolate(FT_DRAW[0], { score: "1-1", team: "S. Africa" }), "away from FT_DRAW");
});

// ============================================================
// renderKickoffSoonPush (30-min nudge) — names each follower's own team
// ============================================================

Deno.test("renderKickoffSoonPush: each side's body names its own team + opponent", () => {
  const copy = renderKickoffSoonPush({ home: MEX, away: RSA, rng: zero });
  eq(copy.title, "Kickoff soon: Mexico v S. Africa", "title is the factual fixture");
  eq(copy.bodies.mexico, interpolate(KICKOFF_SOON[0], { team: "Mexico", opp: "S. Africa" }), "home names Mexico");
  eq(copy.bodies.south_africa, interpolate(KICKOFF_SOON[0], { team: "S. Africa", opp: "Mexico" }), "away names S. Africa");
});

Deno.test("KICKOFF_SOON pool: unique, <=90 chars, no em/en dashes, names team + opp", () => {
  assert(new Set(KICKOFF_SOON).size === KICKOFF_SOON.length, "no duplicate lines");
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const longest = [...names].sort((a, b) => b.length - a.length)[0];
  for (const template of KICKOFF_SOON) {
    const body = interpolate(template, { team: longest, opp: longest });
    assert(body.length > 0, `non-empty: ${template}`);
    assert(body.length <= 90, `<=90 chars (got ${body.length}): ${body}`);
    assert(!body.includes("—") && !body.includes("–"), `no em/en dash: ${body}`);
  }
});

// ============================================================
// Pool integrity + safety sweep across all 360 variants
// ============================================================

const POOLS: Record<string, readonly string[]> = {
  GOAL_SCORED,
  GOAL_CONCEDED,
  GOAL_BOTH,
  HT_AHEAD,
  HT_BEHIND,
  HT_LEVEL,
  FT_WIN,
  FT_LOSS,
  FT_DRAW,
};

Deno.test("every pool has exactly 40 unique variants", () => {
  for (const [name, pool] of Object.entries(POOLS)) {
    eq(pool.length, 40, `${name} length`);
    eq(new Set(pool).size, 40, `${name} has no duplicate lines`);
  }
});

Deno.test("every variant: non-empty, <=90 chars, no em/en dashes, contains the score", () => {
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const longestName = [...names].sort((a, b) => b.length - a.length)[0];
  const longestFlag = [...Object.values(WC_COUNTRY_META).map((m) => m.flag)]
    .sort((a, b) => b.length - a.length)[0]; // England/Scotland tag-flags are the widest
  const score = "10-10"; // worst-case width

  const goalVars = { flag: longestFlag, team: longestName, score };
  const bothVars = { home: longestName, away: longestName, score };
  const periodVars = { score, team: longestName };

  const groups: Array<[readonly string[], Record<string, string>]> = [
    [GOAL_SCORED, goalVars],
    [GOAL_CONCEDED, goalVars],
    [GOAL_BOTH, bothVars],
    [HT_AHEAD, periodVars],
    [HT_BEHIND, periodVars],
    [HT_LEVEL, periodVars],
    [FT_WIN, periodVars],
    [FT_LOSS, periodVars],
    [FT_DRAW, periodVars],
  ];

  for (const [pool, vars] of groups) {
    for (const template of pool) {
      const body = interpolate(template, vars);
      assert(body.length > 0, `non-empty: ${template}`);
      assert(body.length <= 90, `<=90 chars (got ${body.length}): ${body}`);
      assert(!body.includes("—") && !body.includes("–"), `no em/en dash: ${body}`);
      assert(body.includes(score), `contains score: ${body}`);
    }
  }
});

// ============================================================
// Titles stay factual + bounded, no em/en dashes
// ============================================================

Deno.test("titles carry the scoreline, stay bounded, no em/en dashes", () => {
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const [a, b] = [...names].sort((x, y) => y.length - x.length).slice(0, 2);
  const home = { id: "a", name: a, flag: "🏳️" };
  const away = { id: "b", name: b, flag: "🏳️" };
  const titles = [
    renderGoalPush({ home, away, homeGoals: 10, awayGoals: 10, side: "home", rng: zero }).title,
    renderHalfTimePush({ home, away, homeGoals: 10, awayGoals: 10, rng: zero }).title,
    renderFullTimePush({ home, away, homeGoals: 10, awayGoals: 10, rng: zero }).title,
  ];
  for (const t of titles) {
    assert(t.length <= 50, `title bounded (got ${t.length}): ${t}`);
    assert(t.includes("10-10"), `title carries the score: ${t}`);
    assert(!t.includes("—") && !t.includes("–"), `no em/en dash: ${t}`);
  }
});

// ============================================================
// A2: scorer + minute enrichment (formatMinute / formatScorerLine /
// pickLatestGoalForTeam / renderGoalPush scorerLine weaving)
// ============================================================

function ev(p: Partial<GoalEvent>): GoalEvent {
  return {
    teamApiId: 1,
    playerName: null,
    minute: null,
    extra: null,
    isOwnGoal: false,
    isPenalty: false,
    ...p,
  };
}

Deno.test("formatMinute: plain, stoppage, and unknown", () => {
  eq(formatMinute(47, null), "47'", "plain minute");
  eq(formatMinute(45, 2), "45+2'", "stoppage time");
  eq(formatMinute(90, 0), "90'", "extra 0 is not shown");
  eq(formatMinute(null, null), "", "unknown minute → empty");
  eq(formatMinute(90, null), "90'", "no extra");
});

Deno.test("formatScorerLine: normal goal names player + minute", () => {
  eq(formatScorerLine(ev({ playerName: "Pedri", minute: 47 })), "⚽ Pedri 47'", "normal goal");
});

Deno.test("formatScorerLine: penalty tagged (pen)", () => {
  eq(
    formatScorerLine(ev({ playerName: "H. Kane", minute: 90, extra: 3, isPenalty: true })),
    "⚽ H. Kane 90+3' (pen)",
    "penalty in stoppage",
  );
});

Deno.test("formatScorerLine: own goal omits the (opposing-team) player name", () => {
  // API names the own-goal scorer from the CONCEDING side; surfacing that name
  // on the celebrating side's push would mislead. Label only.
  eq(
    formatScorerLine(ev({ playerName: "J. Stones", minute: 23, isOwnGoal: true })),
    "⚽ Own goal 23'",
    "own goal labelled, player dropped",
  );
  eq(formatScorerLine(ev({ minute: null, isOwnGoal: true })), "⚽ Own goal", "own goal, no minute");
});

Deno.test("formatScorerLine: graceful partials and null", () => {
  eq(formatScorerLine(ev({ playerName: "Vinicius", minute: null })), "⚽ Vinicius", "name only");
  eq(formatScorerLine(ev({ playerName: null, minute: 60 })), "⚽ Goal 60'", "minute only");
  eq(formatScorerLine(ev({ playerName: "  ", minute: null })), null, "no fact → null");
  eq(formatScorerLine(null), null, "null event → null");
});

Deno.test("pickLatestGoalForTeam: latest goal of the scoring side", () => {
  const events: GoalEvent[] = [
    ev({ teamApiId: 10, playerName: "Early", minute: 12 }),
    ev({ teamApiId: 20, playerName: "OtherTeam", minute: 80 }),
    ev({ teamApiId: 10, playerName: "Latest", minute: 67 }),
    ev({ teamApiId: 10, playerName: "Stoppage", minute: 67, extra: 2 }),
  ];
  const picked = pickLatestGoalForTeam(events, 10);
  eq(picked?.playerName, "Stoppage", "highest minute+extra for team 10");
  eq(pickLatestGoalForTeam(events, 99)?.playerName ?? null, null, "no goal for absent team");
  eq(pickLatestGoalForTeam([], 10), null, "empty array → null");
  eq(pickLatestGoalForTeam(null, 10), null, "null events → null");
});

Deno.test("toStoredGoalEvents: tags side from API ids, sorts chronologically", () => {
  const events: GoalEvent[] = [
    ev({ teamApiId: 20, playerName: "Away2", minute: 80 }),
    ev({ teamApiId: 10, playerName: "Home1", minute: 12, isPenalty: true }),
    ev({ teamApiId: 10, playerName: "HomeStoppage", minute: 45, extra: 2 }),
    ev({ teamApiId: 10, playerName: "HomeLevel", minute: 45 }),
  ];
  const stored = toStoredGoalEvents(events, 10, 20);
  eq(stored.length, 4, "all events for the two sides kept");
  eq(stored[0].player, "Home1", "min 12 first");
  eq(stored[0].side, "home", "home id → home side");
  eq(stored[0].isPenalty, true, "penalty preserved");
  eq(stored[1].player, "HomeLevel", "min 45 (no stoppage) before 45+2");
  eq(stored[2].player, "HomeStoppage", "45+2 after 45");
  eq(stored[3].side, "away", "away id → away side");
});

Deno.test("toStoredGoalEvents: drops events for neither side; tolerant of empty", () => {
  const events: GoalEvent[] = [
    ev({ teamApiId: 99, playerName: "Ghost", minute: 10 }),
    ev({ teamApiId: 10, playerName: "Real", minute: 20 }),
  ];
  const stored = toStoredGoalEvents(events, 10, 20);
  eq(stored.length, 1, "event for an unrelated team id is dropped");
  eq(stored[0].player, "Real", "only the matching-side event survives");
  eq(toStoredGoalEvents([], 10, 20).length, 0, "empty array → []");
  eq(toStoredGoalEvents(null, 10, 20).length, 0, "null → []");
});

Deno.test("renderGoalPush: scorerLine appended to both bodies, additive", () => {
  const withScorer = renderGoalPush({
    home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", scorerLine: "⚽ Pedri 47'", rng: zero,
  });
  const without = renderGoalPush({
    home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", rng: zero,
  });
  // The scorer line is appended after the unchanged rotating-copy body.
  assert(withScorer.bodies.mexico.startsWith(without.bodies.mexico), "scorer body keeps rotating copy");
  assert(withScorer.bodies.mexico.endsWith("⚽ Pedri 47'"), "scorer body ends with the fact");
  assert(withScorer.bodies.south_africa.endsWith("⚽ Pedri 47'"), "conceder body also carries the fact");
  // Null / empty scorerLine is a clean no-op (fallback path).
  eq(
    renderGoalPush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", scorerLine: null, rng: zero }).bodies.mexico,
    without.bodies.mexico,
    "null scorerLine = unchanged copy",
  );
});
