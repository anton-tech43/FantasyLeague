// deno test --allow-env backend/supabase/functions/_shared/apns-timeout.test.ts
//
// Bug hunt 2026-11-03 (E-C3): no APNs request had a timeout, so one hung
// connection could hold match-watcher's tick past its minute. Every request
// apns-client makes must carry an AbortSignal. fetch is stubbed: nothing
// leaves the process.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub.invalid");
Deno.env.set("SERVICE_KEY", "stub");
// A throwaway signing key, so a provider token can always be minted locally.
const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
Deno.env.set("APNS_KEY_P8", btoa(String.fromCharCode(...pkcs8)));
Deno.env.set("APNS_KEY_ID", "STUBKEY");
Deno.env.set("APNS_TEAM_ID", "STUBTEAM");

const seen: Array<{ url: string; signal: AbortSignal | null | undefined }> = [];
globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
  const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
  if (url.startsWith("http://stub.invalid")) {
    // The shared provider-token cache: a fresh token, so nothing is minted.
    return Promise.resolve(new Response(JSON.stringify({ jwt: "stub.jwt", generated_at: new Date().toISOString() }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }));
  }
  seen.push({ url, signal: init?.signal });
  return Promise.resolve(new Response(null, { status: url.endsWith("/channels") && init?.method === "POST" ? 201 : 200, headers: { "apns-channel-id": "c3R1Yg==" } }));
}) as typeof fetch;

const apns = await import("./apns-client.ts");

Deno.test("every APNs request carries a timeout", async () => {
  const cs = { homeScore: 0, awayScore: 0, statusLabel: "1H", elapsed: 1, clockStart: null };
  await apns.sendPushNotification("ab".repeat(32), { aps: { alert: { title: "t", body: "b" } } } as never, "development");
  await apns.sendLiveActivityPush("ab".repeat(32), { event: "update", contentState: cs, environment: "development" });
  await apns.createChannel("development");
  await apns.deleteChannel("development", "c3R1Yg==");
  await apns.sendBroadcast("c3R1Yg==", { event: "update", contentState: cs, environment: "development" });
  assertEquals(seen.length, 5, "five APNs requests");
  for (const r of seen) assert(r.signal instanceof AbortSignal, `no timeout on ${r.url}`);
  assertEquals(apns.APNS_TIMEOUT_MS, 10_000);
});
