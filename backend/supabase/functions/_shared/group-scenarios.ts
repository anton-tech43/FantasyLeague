// _shared/group-scenarios.ts
//
// Exact within-group qualification math for a World Cup group (4 teams,
// 6 games, 3 matchdays). Pure, deterministic, no I/O, no LLM.
//
// Brute-forces every remaining Win/Draw/Loss combination (<= 3^6 = 729;
// collapses to 9 on the final matchday) and reads off each team's exact
// best/worst possible final POSITION. From that we assert statements that
// are true by construction: "guaranteed to win the group", "at worst 2nd
// (guaranteed top-2)", "can still finish 1st", "cannot finish top-2".
//
// TRUTH MODEL (the whole point — no statement is ever wrong):
//   - A W/D/L scenario advances POINTS deterministically, but goal MARGINS
//     are unknowable from W/D/L, so goal difference / goals scored are NOT
//     used to rank.
//   - 2026 within-group tiebreakers are head-to-head FIRST, then overall GD,
//     goals, fair-play conduct, FIFA ranking (verified vs FIFA/ESPN). We do
//     NOT implement any of these. Instead we are TIEBREAKER-AGNOSTIC: when
//     teams are level on points we resolve PESSIMISTICALLY for the focal
//     team (assume it loses every tie) when computing its WORST position,
//     and OPTIMISTICALLY for its BEST position. So "at worst 2nd" holds no
//     matter how a tie actually breaks — it can't be falsified.
//
// The displayed standings TABLE comes straight from API-Football (which
// applies the official tiebreakers); this module is only for the forward-
// looking "what's locked" assertions.

export interface GroupTeam {
  teamApiId: number;
  teamName: string;
  points: number;
  played: number; // 0..3
  goalsDiff: number; // current only; unused for ranking (margins of unplayed games unknown)
  goalsFor: number; // current only
}

export interface RemainingGame {
  homeApiId: number;
  awayApiId: number;
}

export type Outcome = "home" | "draw" | "away";

export const GROUP_GAMES_PER_TEAM = 3;

export interface ExactGroupState {
  worstRank: number; // 1..4, highest (worst) finish across all scenarios (pessimistic ties)
  bestRank: number; // 1..4, lowest (best) finish across all scenarios (optimistic ties)
  guaranteedGroupWin: boolean; // worstRank === 1
  guaranteedTop2: boolean; // worstRank <= 2  ("at worst 2nd")
  canFinishFirst: boolean; // bestRank === 1
  top2Closed: boolean; // bestRank > 2  (can't reach top-2)
  canFinishThird: boolean; // 3 is a reachable finish
  guaranteedThird: boolean; // finishes exactly 3rd in every scenario
}

// ============================================================
// Enumeration
// ============================================================

function* enumerateOutcomes(n: number): Generator<Outcome[]> {
  if (n === 0) {
    yield [];
    return;
  }
  const opts: Outcome[] = ["home", "draw", "away"];
  const idx = new Array(n).fill(0);
  while (true) {
    yield idx.map((i) => opts[i]);
    let k = n - 1;
    while (k >= 0 && idx[k] === 2) {
      idx[k] = 0;
      k--;
    }
    if (k < 0) return;
    idx[k]++;
  }
}

/** Final points per team for one outcome assignment (points only). */
function finalPoints(
  teams: GroupTeam[],
  remaining: RemainingGame[],
  outcomes: Outcome[],
): Map<number, number> {
  const pts = new Map<number, number>();
  for (const t of teams) pts.set(t.teamApiId, t.points);
  remaining.forEach((g, i) => {
    const o = outcomes[i];
    if (o === "home") pts.set(g.homeApiId, (pts.get(g.homeApiId) ?? 0) + 3);
    else if (o === "away") pts.set(g.awayApiId, (pts.get(g.awayApiId) ?? 0) + 3);
    else {
      pts.set(g.homeApiId, (pts.get(g.homeApiId) ?? 0) + 1);
      pts.set(g.awayApiId, (pts.get(g.awayApiId) ?? 0) + 1);
    }
  });
  return pts;
}

// ============================================================
// Public: exact position bounds for a focal team
// ============================================================

export function classifyExactForTeam(
  teams: GroupTeam[],
  remaining: RemainingGame[],
  focalApiId: number,
): ExactGroupState {
  let worstRank = 1;
  let bestRank = teams.length; // 4
  let canFinishThird = false;

  for (const outcomes of enumerateOutcomes(remaining.length)) {
    const pts = finalPoints(teams, remaining, outcomes);
    const fp = pts.get(focalApiId) ?? 0;
    let above = 0;
    let tied = 0;
    for (const t of teams) {
      if (t.teamApiId === focalApiId) continue;
      const p = pts.get(t.teamApiId) ?? 0;
      if (p > fp) above++;
      else if (p === fp) tied++;
    }
    const pessimisticRank = 1 + above + tied; // ties lose
    const optimisticRank = 1 + above; // ties win
    if (pessimisticRank > worstRank) worstRank = pessimisticRank;
    if (optimisticRank < bestRank) bestRank = optimisticRank;
    // 3rd is reachable if the focal team's rank window in THIS scenario spans 3.
    if (optimisticRank <= 3 && pessimisticRank >= 3) canFinishThird = true;
  }

  return {
    worstRank,
    bestRank,
    guaranteedGroupWin: worstRank === 1,
    guaranteedTop2: worstRank <= 2,
    canFinishFirst: bestRank === 1,
    top2Closed: bestRank > 2,
    canFinishThird,
    guaranteedThird: bestRank === 3 && worstRank === 3,
  };
}

// ============================================================
// Public: SAFE coarse third-place points bounds (no pairings needed)
// ============================================================

/**
 * Conservative bounds on the points a group's 3rd-placed team can finish
 * with, computed from current standings ALONE (no remaining pairings).
 * Used for the OTHER 11 groups in the cross-group best-third comparator,
 * where we only have the league-wide standings snapshot.
 *
 *   thirdMax = 3rd-highest of each team's MAX possible points  → upper bound
 *              (overestimate ⇒ makes "guaranteed in" harder ⇒ safe)
 *   thirdMin = 3rd-highest of each team's CURRENT points        → lower bound
 *              (underestimate ⇒ makes "out" harder ⇒ safe)
 *
 * "3rd-highest" is the points of the 3rd slot; the realised 3rd-place points
 * can't exceed the 3rd-highest of per-team ceilings, nor drop below the
 * 3rd-highest of per-team floors (points never decrease).
 */
export function coarseThirdPointsBounds(
  teams: GroupTeam[],
): { thirdMin: number; thirdMax: number } {
  const maxes = teams
    .map((t) => t.points + 3 * Math.max(0, GROUP_GAMES_PER_TEAM - t.played))
    .sort((a, b) => b - a);
  const floors = teams.map((t) => t.points).sort((a, b) => b - a);
  // index 2 = 3rd-highest (0-based) for a 4-team group.
  return { thirdMin: floors[2] ?? 0, thirdMax: maxes[2] ?? 0 };
}

/** Points reachability floor/ceiling for one team (no pairings). */
export function teamPointsBounds(t: GroupTeam): { floor: number; ceil: number } {
  return { floor: t.points, ceil: t.points + 3 * Math.max(0, GROUP_GAMES_PER_TEAM - t.played) };
}
