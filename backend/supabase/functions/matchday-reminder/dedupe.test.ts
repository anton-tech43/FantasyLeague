// deno test backend/supabase/functions/matchday-reminder/dedupe.test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { tokensStillToRemind } from "./dedupe.ts";

const both = { apns_token: "a", team_ids: ["arsenal", "liverpool"] };
const away = { apns_token: "b", team_ids: ["liverpool"] };
const legacyBoth = { apns_token: "c", team_id: "arsenal", team_ids: ["liverpool"] };

Deno.test("P-C6: the away side's retry skips a dual follower the home side already reminded", () => {
  // Run 1 sent Arsenal's reminder; Liverpool's claim failed. Run 2, Liverpool side:
  const left = tokensStillToRemind([both, away, legacyBoth], new Set(), "arsenal", true);
  assertEquals(left.map((t) => t.apns_token), ["b"]);
});

Deno.test("nobody is skipped when the other side has not been reminded", () => {
  const left = tokensStillToRemind([both, away], new Set(), "arsenal", false);
  assertEquals(left.map((t) => t.apns_token), ["a", "b"]);
});

Deno.test("same run: tokens already reminded for this fixture are skipped (QA-18)", () => {
  const left = tokensStillToRemind([both, away], new Set(["a"]), null, false);
  assertEquals(left.map((t) => t.apns_token), ["b"]);
});
