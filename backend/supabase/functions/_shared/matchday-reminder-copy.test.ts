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
