// Deno tests for the matchday-reminder copy.
//   deno test backend/supabase/functions/_shared/matchday-reminder-copy.test.ts

import { dayWord, renderMatchdayReminder } from "./matchday-reminder-copy.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

const zero = () => 0;

Deno.test("dayWord: same Stockholm date is 'today'", () => {
  // Kickoff 20:00 UTC (22:00 CEST) Jun 15; reminder 07:00 UTC (09:00 CEST) Jun 15.
  eq(
    dayWord(new Date("2026-06-15T20:00:00Z"), new Date("2026-06-15T07:00:00Z")),
    "today",
    "evening game reminded same morning",
  );
});

Deno.test("dayWord: after-midnight kickoff reminded the morning before is 'tomorrow'", () => {
  // Sweden vs Tunisia: 02:00 UTC (04:00 CEST) Jun 15; reminder 07:00 UTC Jun 14.
  eq(
    dayWord(new Date("2026-06-15T02:00:00Z"), new Date("2026-06-14T07:00:00Z")),
    "tomorrow",
    "night game reminded the day before",
  );
});

Deno.test("renderMatchdayReminder: Sweden night game reads as tomorrow + local 04:00", () => {
  const copy = renderMatchdayReminder({
    teamName: "Sweden",
    opponent: "Tunisia",
    kickoffUtc: new Date("2026-06-15T02:00:00Z"),
    now: new Date("2026-06-14T07:00:00Z"),
    rng: zero,
  });
  eq(copy.title, "Sweden play tomorrow", "title");
  assert(copy.body.includes("Tunisia"), "names the opponent");
  assert(copy.body.includes("tomorrow at 04:00"), `Stockholm-local kickoff (got: ${copy.body})`);
});

Deno.test("renderMatchdayReminder: evening game reads as today + local time", () => {
  const copy = renderMatchdayReminder({
    teamName: "USA",
    opponent: "Paraguay",
    kickoffUtc: new Date("2026-06-15T18:00:00Z"), // 20:00 CEST
    now: new Date("2026-06-15T07:00:00Z"),
    rng: zero,
  });
  eq(copy.title, "USA play today", "title");
  assert(copy.body.includes("today at 20:00"), `local kickoff (got: ${copy.body})`);
});

Deno.test("every body variant: names opponent + time, bounded, no em/en dashes", () => {
  const longest = "Bosnia & Herzegovina";
  for (let i = 0; i < 6; i++) {
    // Step the rng across all variants.
    const rng = () => i / 6;
    const copy = renderMatchdayReminder({
      teamName: longest,
      opponent: longest,
      kickoffUtc: new Date("2026-06-15T02:00:00Z"),
      now: new Date("2026-06-14T07:00:00Z"),
      rng,
    });
    assert(copy.body.includes("04:00"), `variant ${i} carries the time`);
    assert(copy.body.length <= 160, `variant ${i} bounded (got ${copy.body.length}: ${copy.body})`);
    assert(copy.title.length <= 40, `title bounded (got ${copy.title.length}: ${copy.title})`);
    const all = copy.title + copy.body;
    assert(!all.includes("—") && !all.includes("–"), `variant ${i} no em/en dash`);
  }
});

// ── mig 082: per-reader timezone ────────────────────────────────────────────

Deno.test("tz: same kickoff renders 17:30 for Stockholm and 16:30 for London", () => {
  // Arsenal v Chelsea 2026-09-06 15:30 UTC (CEST +2, BST +1).
  const kickoff = new Date("2026-09-06T15:30:00Z");
  const now = new Date("2026-09-06T07:00:00Z");
  const se = renderMatchdayReminder({ teamName: "Arsenal", opponent: "Chelsea", kickoffUtc: kickoff, now, rng: zero });
  const uk = renderMatchdayReminder({ teamName: "Arsenal", opponent: "Chelsea", kickoffUtc: kickoff, now, tz: "Europe/London", rng: zero });
  assert(se.body.includes("today at 17:30"), "default zone is Stockholm: " + se.body);
  assert(uk.body.includes("today at 16:30"), "London reader sees BST clock: " + uk.body);
  eq(se.title, uk.title, "title is zone-independent");
});

Deno.test("tz: invalid or missing zone falls back to Stockholm, never throws", () => {
  const kickoff = new Date("2026-09-06T15:30:00Z");
  const now = new Date("2026-09-06T07:00:00Z");
  for (const tz of ["Not/AZone", "", null, undefined, "garbage;drop table"]) {
    const c = renderMatchdayReminder({ teamName: "Arsenal", opponent: "Chelsea", kickoffUtc: kickoff, now, tz, rng: zero });
    assert(c.body.includes("today at 17:30"), `fallback for ${JSON.stringify(tz)}: ${c.body}`);
  }
});

Deno.test("tz: 'today'/'tomorrow' follows the reader's calendar date", () => {
  // Kickoff 23:30 UTC Sep 6 = 01:30 CEST Sep 7 (tomorrow in Stockholm) but
  // 00:30 BST Sep 7 (also tomorrow) vs 19:30 EDT Sep 6 (today in New York).
  const kickoff = new Date("2026-09-06T23:30:00Z");
  const now = new Date("2026-09-06T07:00:00Z");
  eq(dayWord(kickoff, now), "tomorrow", "Stockholm");
  eq(dayWord(kickoff, now, "Europe/London"), "tomorrow", "London");
  eq(dayWord(kickoff, now, "America/New_York"), "today", "New York");
});
