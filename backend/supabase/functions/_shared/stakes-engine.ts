// _shared/stakes-engine.ts
//
// Pure, deterministic World Championship group-stage stakes computation.
// No I/O, no LLM, no Anthropic call. Cost: $0.
//
// Forward-looking cousin of detect-consequences.ts: where that detector
// fires AFTER a result settles a race, this answers — for a followed
// team's UPCOMING group fixtures — "what's at stake in this game" and
// "how important is it", so the team page (and pushes) can be truthful
// and stakes-aware.
//
// TRUTH DISCIPLINE (the West Ham "stayed up while 18th" lesson + the
// design doc §3.1). We only ever ASSERT what points math guarantees:
//   - Top-2 (direct qualification) is points-certain → we may assert it
//     ("Win and they're through").
//   - 3rd place / best-third is CROSS-GROUP and only settles after other
//     groups finish → NEVER asserted here. Anything depending on it is
//     `certainty: "soft"` and the templates hedge it ("still alive"),
//     never "you're through" / "you're out".
//   - We never assert ELIMINATED from single-group math — a 3rd-placed
//     side can still advance as one of the best thirds. Mirrors the
//     deliberately-disabled WC_KNOCKOUT_ELIMINATED in detect-consequences.
//
// Tie safety: when testing whether a rival "can finish at or above" the
// followed team we use >= (a points tie can flip on goal difference), so
// the engine is conservative in the direction that matters — it never
// over-claims a guaranteed top-2.

import type { ExactGroupState } from "./group-scenarios.ts";
import type { BestThirdResult } from "./best-third.ts";

export const WC_TOTAL_GROUP_GAMES = 3;

/** Optional exact-math hint the caller computes (group-scenarios + best-third). */
export interface ExactInfo {
  state: ExactGroupState;
  bestThird?: BestThirdResult;
}

/** Minimal per-team slice of a group table (one of the 4 teams). */
export interface GroupStanding {
  teamApiId: number;
  teamName: string;
  points: number;
  played: number;
}

/** One upcoming fixture for the followed team, with the opponent resolved. */
export interface UpcomingGroupFixture {
  date: string; // ISO 8601 kickoff
  opponentApiId: number;
  opponentName: string;
  venue: "home" | "away";
}

export type StakesLevel =
  | "decisive" // the result genuinely swings qualification
  | "can_improve_seeding" // already through, but 1st vs 2nd still in play
  | "qualified_already" // through and placement fixed → dead rubber (good)
  | "eliminated"; // out for sure — NEVER emitted from single-group math here

export type Certainty = "certain" | "soft";

export interface FixtureStakes {
  date: string;
  opponent: string;
  venue: "home" | "away";
  importance_dots: number; // 1-5
  importance_label: string; // <= 30 chars, statement form
  stakes_level: StakesLevel;
  reason: string; // machine reason, drives template tone
  certainty: Certainty;
}

/** Current top-2 (direct-qualification) standing of the followed team. */
export type TopTwoState =
  | "group_won" // 1st locked (no rival can reach my floor)
  | "through" // top-2 locked (at most 1 rival can reach my floor)
  | "contention" // still being decided
  | "top2_gone"; // can't reach top-2 (best-third may still be alive — soft)

export interface GroupSituation {
  state: TopTwoState;
  /** stakes_level/reason for the team right now (used by post_match / this_week). */
  stakes_level: StakesLevel;
  reason: string;
  certainty: Certainty;
}

// ============================================================
// Core reachability (points-only, conservative)
// ============================================================

function reach(s: GroupStanding, totalGames: number): { min: number; max: number } {
  const gamesLeft = Math.max(0, totalGames - s.played);
  return { min: s.points, max: s.points + 3 * gamesLeft };
}

/**
 * Classify the followed team's CURRENT direct-qualification (top-2) state
 * from the group table. Points-only, tie-safe (>= treats a points tie as a
 * live threat so we never over-claim a guaranteed top-2).
 */
export function classifyTopTwo(
  group: GroupStanding[],
  teamApiId: number,
  totalGames: number = WC_TOTAL_GROUP_GAMES,
): TopTwoState {
  const me = group.find((t) => t.teamApiId === teamApiId);
  if (!me) return "contention";
  const myR = reach(me, totalGames);
  const others = group
    .filter((t) => t.teamApiId !== teamApiId)
    .map((t) => reach(t, totalGames));

  // Rivals who could finish at or above my floor (tie counts as a threat).
  const canReachMyFloor = others.filter((o) => o.max >= myR.min).length;
  // Rivals certain to finish above my ceiling (their floor beats my max).
  const certainlyAboveMe = others.filter((o) => o.min > myR.max).length;

  if (canReachMyFloor === 0) return "group_won"; // clear of everyone → 1st
  if (canReachMyFloor <= 1) return "through"; // at most 1 above me → top-2
  if (certainlyAboveMe >= 2) return "top2_gone"; // 2 certainly above → no top-2
  return "contention";
}

function isTop2(state: TopTwoState): boolean {
  return state === "through" || state === "group_won";
}

/** Apply one fixture's outcome to a clone, advancing only the two teams. */
function simulate(
  group: GroupStanding[],
  teamApiId: number,
  opponentApiId: number,
  outcome: "win" | "draw" | "loss",
): GroupStanding[] {
  return group.map((t) => {
    if (t.teamApiId === teamApiId) {
      const pts = outcome === "win" ? 3 : outcome === "draw" ? 1 : 0;
      return { ...t, points: t.points + pts, played: t.played + 1 };
    }
    if (t.teamApiId === opponentApiId) {
      const pts = outcome === "loss" ? 3 : outcome === "draw" ? 1 : 0;
      return { ...t, points: t.points + pts, played: t.played + 1 };
    }
    return t;
  });
}

function clampLabel(s: string): string {
  return s.length <= 30 ? s : s.slice(0, 30).trimEnd();
}

// ============================================================
// Public: overall situation (for post_match / this_week / preview tone)
// ============================================================

export function groupSituation(
  group: GroupStanding[],
  teamApiId: number,
  totalGames: number = WC_TOTAL_GROUP_GAMES,
): GroupSituation {
  const state = classifyTopTwo(group, teamApiId, totalGames);
  switch (state) {
    case "group_won":
      return { state, stakes_level: "qualified_already", reason: "group_won", certainty: "certain" };
    case "through":
      return { state, stakes_level: "qualified_already", reason: "through", certainty: "certain" };
    case "top2_gone":
      // Top-2 route closed, but best-third can still rescue them → soft, and
      // still high-stakes (must win to keep the long shot alive).
      return { state, stakes_level: "decisive", reason: "third_place_longshot", certainty: "soft" };
    default:
      return { state, stakes_level: "decisive", reason: "in_contention", certainty: "soft" };
  }
}

/**
 * Build a sound ExactGroupState from POINTS reachability alone (no fixture
 * pairings, no enumeration). Conservative: worstRank uses "any rival that
 * COULD reach my floor counts against me" and bestRank uses "only rivals
 * GUARANTEED above me". So `guaranteedTop2`/`guaranteedGroupWin`/`top2Closed`
 * are never over-claimed. The full enumeration (group-scenarios.ts) gives
 * tighter bounds (e.g. on the final matchday when two rivals play each other)
 * and can be substituted when remaining pairings are available.
 */
export function classifyExactPointsOnly(
  group: GroupStanding[],
  focalApiId: number,
  totalGames: number = WC_TOTAL_GROUP_GAMES,
): ExactGroupState {
  const me = group.find((t) => t.teamApiId === focalApiId);
  if (!me) {
    return {
      worstRank: 4, bestRank: 4, guaranteedGroupWin: false, guaranteedTop2: false,
      canFinishFirst: false, top2Closed: false, canFinishThird: false, guaranteedThird: false,
    };
  }
  const fFloor = me.points;
  const fCeil = me.points + 3 * Math.max(0, totalGames - me.played);
  const others = group.filter((t) => t.teamApiId !== focalApiId);
  const canReachMyFloor = others.filter(
    (o) => o.points + 3 * Math.max(0, totalGames - o.played) >= fFloor,
  ).length;
  const guaranteedAbove = others.filter((o) => o.points > fCeil).length;
  return {
    worstRank: 1 + canReachMyFloor,
    bestRank: 1 + guaranteedAbove,
    guaranteedGroupWin: canReachMyFloor === 0,
    guaranteedTop2: canReachMyFloor <= 1,
    canFinishFirst: guaranteedAbove === 0,
    top2Closed: guaranteedAbove >= 2,
    canFinishThird: guaranteedAbove <= 2 && canReachMyFloor >= 2,
    guaranteedThird: guaranteedAbove === 2 && canReachMyFloor === 2,
  };
}

// ============================================================
// Public: per-fixture stakes for the team's upcoming group games
// ============================================================

/**
 * Annotate each upcoming fixture with stakes. Only the SOONEST group fixture
 * (the live decision) gets a scenario-derived precise label; later group
 * fixtures get an honest generic label (computing exact stakes for game 3
 * before games 1-2 are played would be meaningless). Non-group fixtures
 * (warm-ups) are marked low-importance.
 *
 * `fixtures` must be in chronological order (soonest first) and already
 * filtered to future kickoffs by the caller.
 */
export function annotateFixtures(
  group: GroupStanding[],
  teamApiId: number,
  fixtures: UpcomingGroupFixture[],
  totalGames: number = WC_TOTAL_GROUP_GAMES,
  exact?: ExactInfo,
): FixtureStakes[] {
  const groupIds = new Set(group.map((t) => t.teamApiId));
  let nextGroupGameSeen = false;

  return fixtures.map((fx) => {
    const base = { date: fx.date, opponent: fx.opponentName, venue: fx.venue };

    // Non-group fixture (e.g. a pre-tournament friendly).
    if (!groupIds.has(fx.opponentApiId)) {
      return {
        ...base,
        importance_dots: 2,
        importance_label: "Warm-up game",
        stakes_level: "qualified_already",
        reason: "non_group",
        certainty: "soft",
      };
    }

    if (!nextGroupGameSeen) {
      nextGroupGameSeen = true;
      return { ...base, ...labelSoonestGroupGame(group, teamApiId, fx, totalGames, exact) };
    }

    // A later group game: honest generic by current state.
    const state = classifyTopTwo(group, teamApiId, totalGames);
    const dots = state === "contention" || state === "top2_gone" ? 4 : 2;
    return {
      ...base,
      importance_dots: dots,
      importance_label: "Group stage game",
      stakes_level: isTop2(state) ? "qualified_already" : "decisive",
      reason: "later_group_game",
      certainty: "soft",
    };
  });
}

type StakesCore = Pick<
  FixtureStakes,
  "importance_dots" | "importance_label" | "stakes_level" | "reason" | "certainty"
>;

function labelSoonestGroupGame(
  group: GroupStanding[],
  teamApiId: number,
  fx: UpcomingGroupFixture,
  totalGames: number,
  exact?: ExactInfo,
): StakesCore {
  // Exact-math overrides: when the outcome is mathematically LOCKED we state
  // it directly (no point saying "win and you're through" if already
  // through). Falls through to the per-result simulation for live cases.
  if (exact) {
    const s = exact.state;
    if (s.guaranteedGroupWin) {
      return mk(2, "Won the group", "qualified_already", "group_won_dead_rubber", "certain");
    }
    if (s.guaranteedTop2) {
      return s.canFinishFirst
        ? mk(3, "At worst 2nd", "can_improve_seeding", "at_worst_second", "certain")
        : mk(2, "Through, 2nd locked in", "qualified_already", "at_worst_second", "certain");
    }
    if (s.top2Closed) {
      const bt = exact.bestThird?.status;
      if (bt === "guaranteed_in") {
        return mk(2, "Through as a best third", "qualified_already", "third_place_through", "certain");
      }
      if (bt === "out") {
        // IN-APP only; never pushed (handled in the push path).
        return mk(1, "Out of the tournament", "eliminated", "third_place_out", "certain");
      }
      // best-third undecided → genuinely a long shot.
      return mk(4, "Win to keep hopes alive", "decisive", "third_place_longshot", "soft");
    }
    // contention → fall through to the per-result simulation below.
  }

  const current = classifyTopTwo(group, teamApiId, totalGames);

  // Pre-tournament (no games played by anyone in the group): nothing is
  // decided yet — label by matchday position, all genuinely important.
  const played = group.find((t) => t.teamApiId === teamApiId)?.played ?? 0;
  if (played === 0 && current === "contention") {
    return {
      importance_dots: 4,
      importance_label: "Group opener",
      stakes_level: "decisive",
      reason: "group_opener",
      certainty: "soft",
    };
  }

  if (current === "group_won") {
    return mk(2, "Already won the group", "qualified_already", "group_won_dead_rubber", "certain");
  }

  if (current === "through") {
    const afterWin = classifyTopTwo(simulate(group, teamApiId, fx.opponentApiId, "win"), teamApiId, totalGames);
    if (afterWin === "group_won") {
      return mk(3, "Win to top the group", "can_improve_seeding", "seeding_top_spot", "certain");
    }
    return mk(2, "Already through", "qualified_already", "through_dead_rubber", "certain");
  }

  if (current === "top2_gone") {
    // Best-third may still rescue them — soft, but still must-win stakes.
    return mk(4, "Win to keep hopes alive", "decisive", "third_place_longshot", "soft");
  }

  // current === "contention" (and some games already played).
  const afterWin = classifyTopTwo(simulate(group, teamApiId, fx.opponentApiId, "win"), teamApiId, totalGames);
  const afterDraw = classifyTopTwo(simulate(group, teamApiId, fx.opponentApiId, "draw"), teamApiId, totalGames);
  const afterLoss = classifyTopTwo(simulate(group, teamApiId, fx.opponentApiId, "loss"), teamApiId, totalGames);

  if (isTop2(afterDraw)) {
    // A draw already guarantees top-2 → so does a win. CERTAIN.
    return mk(5, "A point sends them through", "decisive", "avoid_defeat_through", "certain");
  }
  if (isTop2(afterWin)) {
    // Only a win guarantees it. CERTAIN.
    return mk(5, "Win and they're through", "decisive", "win_through", "certain");
  }
  if (afterLoss === "top2_gone") {
    // Losing closes the top-2 door; a win keeps it open but doesn't yet
    // guarantee it (depends on the other group game) → SOFT.
    return mk(5, "Must win to stay in it", "decisive", "must_not_lose", "soft");
  }
  // Win helps but guarantees nothing yet — depends on the other result.
  return mk(4, "Big one in the group", "decisive", "contention_generic", "soft");
}

function mk(
  dots: number,
  label: string,
  level: StakesLevel,
  reason: string,
  certainty: Certainty,
): StakesCore {
  return {
    importance_dots: dots,
    importance_label: clampLabel(label),
    stakes_level: level,
    reason,
    certainty,
  };
}
