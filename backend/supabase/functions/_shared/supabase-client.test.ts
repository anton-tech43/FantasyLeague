// deno test backend/supabase/functions/_shared/supabase-client.test.ts
import { assertEquals, assertRejects } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { fetchAllRows, isTokenDead } from "./supabase-client.ts";

Deno.test("isTokenDead: only a token-level APNs verdict kills a token (QA-03)", () => {
  assertEquals(isTokenDead({ success: true, status: 200 }), false);
  assertEquals(isTokenDead({ success: false, status: 410, reason: "Unregistered" }), true);
  assertEquals(isTokenDead({ success: false, status: 400, reason: "BadDeviceToken" }), true);
  assertEquals(isTokenDead({ success: false, status: 400, reason: "DeviceTokenNotForTopic" }), true);
  // Faults in OUR request: every recipient gets them, none of them is dead.
  for (const reason of ["BadTopic", "TopicDisallowed", "PayloadEmpty", "BadPriority", "MissingTopic", "HTTP 400"]) {
    assertEquals(isTokenDead({ success: false, status: 400, reason }), false, reason);
  }
  assertEquals(isTokenDead({ success: false, status: 403, reason: "InvalidProviderToken" }), false);
  assertEquals(isTokenDead({ success: false, reason: "network down" }), false);
});

Deno.test("fetchAllRows reads past the 1000-row page and stops on a short page (QA-04)", async () => {
  const all = Array.from({ length: 2345 }, (_, i) => i);
  const windows: Array<[number, number]> = [];
  const rows = await fetchAllRows<number>((from, to) => {
    windows.push([from, to]);
    return Promise.resolve({ data: all.slice(from, to + 1), error: null });
  });
  assertEquals(rows.length, 2345);
  assertEquals(windows, [[0, 999], [1000, 1999], [2000, 2999]]);
});

Deno.test("fetchAllRows throws on a page error instead of returning a partial list", async () => {
  let calls = 0;
  await assertRejects(() =>
    fetchAllRows<number>(() =>
      Promise.resolve(
        calls++ === 0
          ? { data: Array(1000).fill(0), error: null }
          : { data: null, error: { message: "boom" } },
      )
    )
  );
});
