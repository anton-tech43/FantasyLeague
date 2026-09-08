// _shared/push-tiers.ts
// Which tiers receive a live match push (kickoff / goal / half-time / result).
//
// Until now every follower of a playing team got all four, which was tolerable
// while the only competitions were the Premier League and a World Championship
// he had chosen to follow. It is not tolerable for a League Cup second-round
// tie at Lincoln: four pushes for a night he may not even watch, to someone who
// did not choose this hobby. TIERS.md §6.3 designed the gate and nothing
// implemented it.
//
//   Light (1)     result only
//   Match-fit (2) kickoff, half-time, result — no goal-by-goal (she's watching,
//                 or she'll take the result)
//   Deep (3)      everything
//
// On top of that, a competition-and-round floor. An early domestic cup round is
// a result, not an evening; a semi-final or a final is an evening for everyone.

import { parseRound } from "./league-helpers.ts";

export type LiveEvent = "kickoff" | "goal" | "ht" | "ft";

/// Above the highest real tier: nothing receives it.
export const TIER_NOBODY = 99;

/// Tier defaults to Match-fit when a device has not told us, matching
/// notification-sender's `t.tier ?? 2`.
export const DEFAULT_TIER = 2;

const BASE: Record<LiveEvent, number> = {
  kickoff: 2,
  goal: 3,
  ht: 2,
  ft: 1,
};

/**
 * Minimum tier that receives `event` for this fixture.
 *
 * - League Cup before the quarter-finals, FA Cup before the last 16: the result
 *   only, whatever the tier. Nobody needs a goal alert from the last 64.
 * - Any cup semi-final or final: everybody gets everything.
 * - Everything else, the Premier League and the World Championship included:
 *   the tier table above.
 */
export function minTierForLiveEvent(
  event: LiveEvent,
  leagueId: number | undefined,
  round: string | undefined,
): number {
  const { stage } = parseRound(round);

  // A semi-final or a final, in any competition that has them. stage 0 means a
  // league phase or an unparsed round, which is not a semi-final.
  if (stage === 1 || stage === 2) return 1;

  // Early domestic cup rounds: the result, and nothing else.
  const earlyLeagueCup = leagueId === 48 && stage > 4;
  const earlyFaCup = leagueId === 45 && stage > 8;
  if (earlyLeagueCup || earlyFaCup) return event === "ft" ? 1 : TIER_NOBODY;

  return BASE[event];
}

/** Does a device on `tier` receive a push whose floor is `minTier`? */
export function tierReceives(tier: number | null | undefined, minTier: number): boolean {
  return (tier ?? DEFAULT_TIER) >= minTier;
}
