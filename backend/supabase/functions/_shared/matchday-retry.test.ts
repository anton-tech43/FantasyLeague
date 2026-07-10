// Deno tests for the matchday-fire retry policy.
//   deno test backend/supabase/functions/_shared/matchday-retry.test.ts

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  decideMatchdayRetry,
  matchdayBackoffMs,
  MATCHDAY_STALENESS_MS,
} from "./matchday-retry.ts";

const MIN = 60_000;
const KICKOFF = 1_000_000_000_000; // arbitrary fixed epoch (no Date.now in tests)
const FINISHED = KICKOFF + 2 * 60 * MIN; // ~2h after kickoff

Deno.test("backoff schedule escalates then plateaus at 30 min", () => {
  assertEquals(matchdayBackoffMs(0), 0);
  assertEquals(matchdayBackoffMs(1), 1 * MIN);
  assertEquals(matchdayBackoffMs(2), 2 * MIN);
  assertEquals(matchdayBackoffMs(3), 5 * MIN);
  assertEquals(matchdayBackoffMs(4), 15 * MIN);
  assertEquals(matchdayBackoffMs(5), 30 * MIN);
  assertEquals(matchdayBackoffMs(9), 30 * MIN); // plateaus, never gives up
});

Deno.test("fires immediately when there is no failure history", () => {
  const d = decideMatchdayRetry({
    nowMs: FINISHED,
    kickoffMs: KICKOFF,
    failureTimesByTarget: [[], []],
  });
  assertEquals(d, { action: "fire" });
});

Deno.test("holds inside the backoff window after a failure", () => {
  const failedAt = FINISHED;
  const d = decideMatchdayRetry({
    nowMs: failedAt + 30_000, // 30s later, backoff after 1 failure is 1 min
    kickoffMs: KICKOFF,
    failureTimesByTarget: [[failedAt], []],
  });
  assertEquals(d, { action: "hold", retryAtMs: failedAt + 1 * MIN });
});

Deno.test("fires again once the backoff window elapses", () => {
  const failedAt = FINISHED;
  const d = decideMatchdayRetry({
    nowMs: failedAt + 1 * MIN, // exactly at the retry time
    kickoffMs: KICKOFF,
    failureTimesByTarget: [[failedAt], []],
  });
  assertEquals(d, { action: "fire" });
});

Deno.test("recovers automatically after a long quota outage (no manual re-fire)", () => {
  // 5 failures over the first hour, then quiet; quota resets and a tick lands
  // 40 min after the last failure — inside staleness, past the 30-min backoff.
  const base = FINISHED;
  const fails = [base, base + 1 * MIN, base + 3 * MIN, base + 8 * MIN, base + 23 * MIN];
  const d = decideMatchdayRetry({
    nowMs: base + 23 * MIN + 40 * MIN,
    kickoffMs: KICKOFF,
    failureTimesByTarget: [fails, fails],
  });
  assertEquals(d, { action: "fire" });
});

Deno.test("escalates off the worst perspective, not the recovered one", () => {
  // away succeeded (0 failures); home has 5 failures and its last was 5 min ago
  // → still inside the 30-min backoff → hold.
  const homeLast = FINISHED + 50 * MIN;
  const homeFails = [FINISHED, FINISHED + 10 * MIN, FINISHED + 20 * MIN, FINISHED + 35 * MIN, homeLast];
  const d = decideMatchdayRetry({
    nowMs: homeLast + 5 * MIN,
    kickoffMs: KICKOFF,
    failureTimesByTarget: [homeFails, []],
  });
  assertEquals(d, { action: "hold", retryAtMs: homeLast + 30 * MIN });
});

Deno.test("abandons as stale past the staleness deadline", () => {
  const d = decideMatchdayRetry({
    nowMs: KICKOFF + MATCHDAY_STALENESS_MS + 1,
    kickoffMs: KICKOFF,
    failureTimesByTarget: [[KICKOFF + 3 * MIN], []],
  });
  assertEquals(d, { action: "stale" });
});
