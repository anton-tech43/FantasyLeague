// matchday-retry.ts
//
// Retry policy for the post-FT gd-matchday routine fire.
//
// History: migration 042 added a PERMANENT cap (matchday_fire_capped) that
// stopped firing forever after 5 failures OR 2h since the first failure. That
// killed the every-minute 429 storm — but it also meant a match whose fire
// failed (quota exhausted, routine outage) NEVER produced content again without
// a MANUAL re-fire from RUNBOOK.md. For a one-person team that "won't do
// anything manually", a permanent give-up is the wrong trade-off.
//
// New policy = SPACED BACKOFF + STALENESS DEADLINE:
//   • back off after each failure (fast at first, then every 30 min) so the
//     cron flood is gone but the fixture keeps trying on its own;
//   • when the routine API recovers — the claude.ai quota resets daily at
//     22:00 UTC, an outage clears — the next spaced attempt lands the content
//     AUTOMATICALLY. Zero manual intervention.
//   • stop only when the match is too old for a "he just lost!" push to make
//     sense (kickoff + STALENESS). Only THEN set matchday_fire_capped=TRUE, as
//     a terminal marker so the SLA heartbeat treats it as an intentional
//     abandon rather than a still-live failure.
//
// The whole point: the flood is still gone, but recovery no longer needs a
// human. 12h comfortably covers a full daily-quota-reset cycle even for the
// earliest PL kickoff (12:30 UK finish ~14:30 UTC → 22:00 reset = ~7.5h wait),
// while a match from yesterday can never spuriously re-fire.
//
// Pure + deterministic (no Date.now / I/O) so it's unit-testable — nowMs is
// passed in. Tests: deno test _shared/matchday-retry.test.ts

export const MATCHDAY_STALENESS_MS = 12 * 60 * 60 * 1000;

// Minutes to wait after the Nth consecutive failure before the next attempt.
// Fast for transient blips, then a 30-min steady state that recovers within
// half an hour of the API coming back.
const BACKOFF_MINUTES = [1, 2, 5, 15, 30];

/** Wait (ms) required after `failureCount` failures before the next attempt. */
export function matchdayBackoffMs(failureCount: number): number {
  if (failureCount <= 0) return 0;
  const i = Math.min(failureCount, BACKOFF_MINUTES.length) - 1;
  return BACKOFF_MINUTES[i] * 60_000;
}

export interface MatchdayRetryInput {
  nowMs: number;
  kickoffMs: number;
  /**
   * Failure event times (ms) for THIS fixture, grouped by pipeline_health
   * `target` (one array per perspective: home / away). Backoff escalates off
   * the perspective with the MOST failures, so a fixture whose home fire keeps
   * failing doesn't get sped back up just because the away side succeeded once.
   */
  failureTimesByTarget: number[][];
}

export type MatchdayRetryDecision =
  | { action: "fire" }
  | { action: "hold"; retryAtMs: number }
  | { action: "stale" };

/**
 * Decide whether to fire the matchday routine this tick, hold for backoff, or
 * abandon the fixture as stale. See file header for the rationale.
 */
export function decideMatchdayRetry(input: MatchdayRetryInput): MatchdayRetryDecision {
  const { nowMs, kickoffMs, failureTimesByTarget } = input;

  if (nowMs - kickoffMs > MATCHDAY_STALENESS_MS) {
    return { action: "stale" };
  }

  // Worst-case perspective: most failures, and among those its latest failure.
  let worstCount = 0;
  let worstLast = 0;
  for (const times of failureTimesByTarget) {
    if (times.length === 0) continue;
    const last = Math.max(...times);
    if (times.length > worstCount || (times.length === worstCount && last > worstLast)) {
      worstCount = times.length;
      worstLast = last;
    }
  }

  if (worstCount === 0) return { action: "fire" };

  const retryAtMs = worstLast + matchdayBackoffMs(worstCount);
  return nowMs >= retryAtMs ? { action: "fire" } : { action: "hold", retryAtMs };
}
