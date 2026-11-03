// deno test backend/supabase/functions/notification-sender/throttle.test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { unpushedTierCeiling } from "./throttle.ts";

Deno.test("nothing pushed yet: send to every tier at or above the floor", () => {
  assertEquals(unpushedTierCeiling(1, []), Infinity);
  assertEquals(unpushedTierCeiling(2, []), Infinity);
});

Deno.test("P-C5: after a tier-2+ push (the Monday brief), big news still reaches Light only", () => {
  assertEquals(unpushedTierCeiling(1, [2]), 2); // tier 1 only
  assertEquals(unpushedTierCeiling(2, [2]), null); // ordinary news: throttled for all
});

Deno.test("after a big story that reached every tier, everything is throttled", () => {
  assertEquals(unpushedTierCeiling(1, [1]), null);
  assertEquals(unpushedTierCeiling(2, [1]), null);
  assertEquals(unpushedTierCeiling(1, [2, 1]), null);
});
