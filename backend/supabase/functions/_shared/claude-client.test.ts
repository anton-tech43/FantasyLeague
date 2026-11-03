// deno test --allow-env backend/supabase/functions/_shared/claude-client.test.ts
// No network: fetch and setTimeout are stubbed. Bug hunt 2026-11-03 O-C5, E-C2/O-C1.
import { assertEquals, assertRejects } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { callClaude, refuseDormantPaidCall, singleTeamId } from "./claude-client.ts";

async function run(statuses: Array<number | "net">) {
  Deno.env.set("ANTHROPIC_API_KEY", "stub-not-a-key");
  const realFetch = globalThis.fetch, realTimeout = globalThis.setTimeout;
  let posts = 0;
  const sleeps: number[] = [];
  globalThis.fetch = (() => {
    const s = statuses[Math.min(posts++, statuses.length - 1)];
    if (s === "net") return Promise.reject(new TypeError("connection reset"));
    return Promise.resolve(new Response(s === 200 ? '{"content":[],"stop_reason":"end_turn"}' : "{}", { status: s }));
  }) as typeof fetch;
  // deno-lint-ignore no-explicit-any
  (globalThis as any).setTimeout = (fn: () => void, ms: number) => { sleeps.push(ms); return realTimeout(fn, 0); };
  try {
    let error: string | null = null;
    try { await callClaude({ system: "s", messages: [{ role: "user", content: "x" }] }); }
    catch (e) { error = String(e); }
    return { posts, sleeps, error };
  } finally {
    globalThis.fetch = realFetch;
    globalThis.setTimeout = realTimeout;
  }
}

Deno.test("a 4xx is thrown at once, no retry and no sleep", async () => {
  for (const s of [400, 401, 403, 404, 413]) {
    const r = await run([s]);
    assertEquals([r.posts, r.sleeps.length], [1, 0], `status ${s}`);
  }
});

Deno.test("429, 5xx and network errors retry with backoff, total sleep under a minute", async () => {
  const r = await run([429, 529, "net", 500]);
  assertEquals(r.posts, 4);
  assertEquals(r.sleeps, [2_000, 8_000, 20_000]);
  assertEquals(r.error?.includes("500"), true);
  const ok = await run([503, 200]);
  assertEquals([ok.posts, ok.error], [2, null]);
});

Deno.test("dormant guard: flag must be exactly 'true' and one target must be named", () => {
  Deno.env.delete("X_ENABLED");
  assertEquals(refuseDormantPaidCall("f", "X_ENABLED", "arsenal")?.status, 403);
  Deno.env.set("X_ENABLED", "1");
  assertEquals(refuseDormantPaidCall("f", "X_ENABLED", "arsenal")?.status, 403);
  Deno.env.set("X_ENABLED", "true");
  assertEquals(refuseDormantPaidCall("f", "X_ENABLED", null)?.status, 400);
  assertEquals(refuseDormantPaidCall("f", "X_ENABLED", "arsenal"), null);
});

Deno.test("singleTeamId refuses empty, arrays and non-ids", () => {
  for (const v of [undefined, null, "", [], ["arsenal"], {}, "a", "Arsenal; drop", 7]) {
    assertEquals(singleTeamId(v), null, JSON.stringify(v));
  }
  assertEquals(singleTeamId("man_city"), "man_city");
});

Deno.test("callClaude without a key throws before any fetch", async () => {
  Deno.env.delete("ANTHROPIC_API_KEY");
  await assertRejects(() => callClaude({ system: "s", messages: [] }), Error, "Missing ANTHROPIC_API_KEY");
});
