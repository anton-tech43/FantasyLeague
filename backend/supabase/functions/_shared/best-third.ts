// _shared/best-third.ts
//
// Cross-group best-third-place comparator for the 2026 World Cup, where the
// 8 best of the 12 third-placed teams advance to the Round of 32. Pure,
// deterministic, no I/O, no LLM.
//
// We assert "through as a best third" / detect "out" using POINTS ONLY, with
// strict separation. The official third-placed ranking is points → goal
// difference → goals scored → fair-play conduct → FIFA ranking (verified vs
// FIFA/ESPN). We can compute none of those tiebreakers reliably in advance
// (goal MARGINS of unplayed games are unknown; conduct + FIFA ranking we
// don't track), so anything that comes down to them stays SOFT and is never
// asserted. That is exactly how a push is kept from ever being wrong.
//
// Inputs are conservative bounds (see group-scenarios.coarseThirdPointsBounds):
//   - other groups: thirdMax = upper bound on their 3rd-place points,
//                    thirdMin = lower bound.
//   - focal team:    floorPts = guaranteed points floor, ceilPts = max points,
//                    plus whether it is locked / able to finish 3rd.

export interface GroupThirdBounds {
  group: string;
  thirdMin: number; // guaranteed-lower-bound points of this group's 3rd-placed team
  thirdMax: number; // possible-upper-bound points of this group's 3rd-placed team
}

export interface BestThirdInput {
  focalGroup: string;
  /** Focal team finishes exactly 3rd in every remaining scenario. */
  focalGuaranteedThird: boolean;
  /** Focal team can finish 3rd in at least one scenario. */
  focalCanBeThird: boolean;
  /** Focal team's guaranteed points floor (current points). */
  focalFloorPts: number;
  /** Focal team's maximum possible points. */
  focalCeilPts: number;
  /** The 11 OTHER groups' coarse third-place bounds. */
  otherGroups: GroupThirdBounds[];
}

export type BestThirdStatus = "guaranteed_in" | "out" | "soft";
export interface BestThirdResult {
  status: BestThirdStatus;
  reason: string;
}

// 8 of 12 thirds advance → a team is IN iff at most 7 other thirds finish
// above it, OUT iff at least 8 other thirds are guaranteed above it.
const SPOTS = 8;
const MAX_OTHERS_ABOVE_TO_QUALIFY = SPOTS - 1; // 7
const OTHER_GROUPS = 11; // 12 groups total, minus the focal group

export function classifyBestThird(input: BestThirdInput): BestThirdResult {
  const { focalGuaranteedThird, focalCanBeThird, focalFloorPts, focalCeilPts, otherGroups } = input;

  // Can never even finish 3rd (locked 4th) → not a best-third candidate.
  // This is group-internal and safe regardless of cross-group data.
  if (!focalCanBeThird) {
    return { status: "out", reason: "cannot_finish_third" };
  }

  // SOUNDNESS GUARD: in/out comparisons require ALL 11 other groups. With a
  // partial snapshot we'd UNDER-count threats and could falsely assert
  // "guaranteed in", so any cross-group assertion stays soft until complete.
  if (otherGroups.length < OTHER_GROUPS) {
    return { status: "soft", reason: "incomplete_cross_group_data" };
  }

  // GUARANTEED IN: focal is locked as a 3rd-placed team, and even at its
  // WORST 3rd-place points, at most 7 other groups' thirds could be
  // AT-OR-ABOVE it. Ties count AGAINST focal (a level-on-points rival could
  // edge it on GD), so we use >= — the safe, pessimistic direction.
  if (focalGuaranteedThird) {
    const atOrAbove = otherGroups.filter((o) => o.thirdMax >= focalFloorPts).length;
    if (atOrAbove <= MAX_OTHERS_ABOVE_TO_QUALIFY) {
      return { status: "guaranteed_in", reason: "points_locked_in" };
    }
  }

  // OUT: even at focal's BEST 3rd-place points, at least 8 other groups'
  // thirds are GUARANTEED strictly above it (their worst already beats
  // focal's ceiling). Strict > — a tie could still go focal's way on GD.
  const guaranteedAbove = otherGroups.filter((o) => o.thirdMin > focalCeilPts).length;
  if (guaranteedAbove >= SPOTS) {
    return { status: "out", reason: "points_locked_out" };
  }

  // Otherwise the cutoff is decided among teams level on points by GD /
  // goals / conduct / FIFA ranking — unknowable in advance. Stay soft.
  return { status: "soft", reason: "gd_bubble" };
}
