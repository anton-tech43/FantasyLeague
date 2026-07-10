// Deno tests for the bounded-concurrency fan-out helper.
//   deno test backend/supabase/functions/_shared/concurrency.test.ts

import { mapWithConcurrency, PUSH_CONCURRENCY } from "./concurrency.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

Deno.test("preserves input order regardless of completion order", async () => {
  const items = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  // Later items finish first (descending delay) — output must still be ordered.
  const out = await mapWithConcurrency(items, 4, async (n) => {
    await sleep((items.length - n) * 2);
    return n * n;
  });
  assert(out.length === items.length, "same length");
  for (const n of items) assert(out[n] === n * n, `slot ${n} === ${n * n}, got ${out[n]}`);
});

Deno.test("never exceeds the concurrency limit in flight", async () => {
  const limit = 3;
  let inFlight = 0;
  let maxInFlight = 0;
  const items = Array.from({ length: 20 }, (_, i) => i);
  await mapWithConcurrency(items, limit, async () => {
    inFlight++;
    maxInFlight = Math.max(maxInFlight, inFlight);
    await sleep(5);
    inFlight--;
    return null;
  });
  assert(maxInFlight <= limit, `max in flight ${maxInFlight} <= ${limit}`);
  assert(maxInFlight === limit, `should reach the cap (got ${maxInFlight})`);
});

Deno.test("processes every item exactly once", async () => {
  const items = Array.from({ length: 50 }, (_, i) => i);
  const seen = new Set<number>();
  let calls = 0;
  const out = await mapWithConcurrency(items, 8, async (n, idx) => {
    calls++;
    seen.add(n);
    assert(idx === n, `index matches item (${idx} === ${n})`);
    return n;
  });
  assert(calls === items.length, `called once per item (${calls})`);
  assert(seen.size === items.length, "every item seen");
  assert(out.length === items.length, "result per item");
});

Deno.test("empty input returns empty array without calling fn", async () => {
  let called = false;
  const out = await mapWithConcurrency([], 4, async () => {
    called = true;
    return 1;
  });
  assert(out.length === 0, "empty result");
  assert(!called, "fn never called");
});

Deno.test("limit larger than item count still completes all", async () => {
  const items = [1, 2, 3];
  const out = await mapWithConcurrency(items, 100, async (n) => n + 1);
  assert(out.join(",") === "2,3,4", `got ${out.join(",")}`);
});

Deno.test("default PUSH_CONCURRENCY is a sane positive cap", () => {
  assert(Number.isInteger(PUSH_CONCURRENCY) && PUSH_CONCURRENCY > 0, "positive int");
});
