import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { fanOutRow } from "./pipeline-logger.ts";

Deno.test("fanOutRow counts sends and failure reasons", () => {
  const row = fanOutRow("la update p5", [
    { success: true, status: 200 },
    { success: false, status: 410, reason: "Unregistered" },
    { success: false, status: 410, reason: "Unregistered" },
    { success: false, reason: "timeout" },
  ]);
  assertEquals(row.status, "partial");
  assertEquals(row.http_status, 410);
  assertEquals(row.message, "la update p5: 1 sent, 3 failed of 4");
  assertEquals(row.response_excerpt, '{"410 Unregistered":2,"? timeout":1}');
  // The digest parses the sent count out of the message.
  assertEquals(row.message.match(/(\d+) sent/)?.[1], "1");
});

Deno.test("fanOutRow: all sent, none failed, nobody to send to", () => {
  assertEquals(fanOutRow("x", [{ success: true }]).status, "success");
  assertEquals(fanOutRow("x", [{ success: false, status: 403 }]).status, "failure");
  assertEquals(fanOutRow("x", []).status, "skipped");
});
