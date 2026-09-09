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
//   Light (1)     goals and the result
//   Match-fit (2) + kickoff and half-time
//   Deep (3)      everything
//
// **A goal reaches every tier, in every competition** (Anton, 2026-09-08). The
// Live Activity runs on the lock screen for every match a followed club plays
// and scores as it goes, so a goal push is the same fact arriving by another
// route; gating one and not the other was incoherent. TIERS.md §6.3 put
// goal-by-goal at Deep only, and that call is superseded.
//
// On top of that, a competition-and-round floor for the FRAMING pushes only. An
// early domestic cup round does not need to announce its own kickoff; a
// semi-final or a final is an evening for everyone.

import { parseRound } from "./league-helpers.ts";

export type LiveEvent = "kickoff" | "goal" | "ht" | "ft";

/// Above the highest real tier: nothing receives it.
export const TIER_NOBODY = 99;

/// Tier defaults to Match-fit when a device has not told us, matching
/// notification-sender's `t.tier ?? 2`.
export const DEFAULT_TIER = 2;

const BASE: Record<LiveEvent, number> = {
  kickoff: 2,
  goal: 1,
  ht: 2,
  ft: 1,
};

/**
 * Minimum tier that receives `event` for this fixture.
 *
 * - A goal is never gated, by tier or by round. It is what the Live Activity
 *   on her lock screen is already showing her.
 * - League Cup before the quarter-finals, FA Cup before the last 16: no kickoff
 *   and no half-time push, whatever the tier. The match still reaches her
 *   through its goals and its result.
 * - Any cup semi-final or final: everybody gets everything.
 * - Everything else, the Premier League and the World Championship included:
 *   the tier table above.
 */
export function minTierForLiveEvent(
  event: LiveEvent,
  leagueId: number | undefined,
  round: string | undefined,
): number {
  // A goal goes to everyone, whatever the competition and whatever the round.
  if (event === "goal") return 1;

  const { stage } = parseRound(round, leagueId);

  // A semi-final or a final, in any competition that has them. stage 0 means a
  // league phase or an unparsed round, which is not a semi-final.
  if (stage === 1 || stage === 2) return 1;

  // Early domestic cup rounds: the goals and the result, no framing pushes.
  // A domestic cup has no league phase, so an unparsed round (stage 0) there
  // is an early or unknown one and gets the quiet treatment, not the loud one.
  const earlyLeagueCup = leagueId === 48 && (stage === 0 || stage > 4);
  const earlyFaCup = leagueId === 45 && (stage === 0 || stage > 8);
  if (earlyLeagueCup || earlyFaCup) return event === "ft" ? 1 : TIER_NOBODY;

  return BASE[event];
}

/** Does a device on `tier` receive a push whose floor is `minTier`? */
export function tierReceives(tier: number | null | undefined, minTier: number): boolean {
  return (tier ?? DEFAULT_TIER) >= minTier;
}
