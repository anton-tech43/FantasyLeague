// The tap on a push opens the feed of the club in `team_id`. Without it the
// app opened whatever feed was last showing, and a club story flagged
// everyone_talking stranded the follower on Football (2026-10-26).
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { buildAPNsPayload } from "./apns-client.ts";

Deno.test("team_id rides along when given", () => {
  const p = buildAPNsPayload("", "b", "live-goal-1", "C", false, "b", "t", "arsenal");
  assertEquals(p.team_id, "arsenal");
  assertEquals(p.everyone_talking, undefined);
});

Deno.test("no team_id key when there is no club behind the push", () => {
  const p = buildAPNsPayload("", "b", "uuid", "C", true, "b", "t", null);
  assertEquals("team_id" in p && p.team_id !== undefined, false);
  assertEquals(p.everyone_talking, true);
});
