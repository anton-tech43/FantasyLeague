// _shared/trigger.ts
// Goal Digger — Inter-function HTTP trigger (Contract 1)
//
// Fire-and-forget by design. The previous synchronous-await version blocked
// the caller for the entire downstream call (Claude generation = 15-30s per
// team), which meant data-fetcher serially-awaited 20 teams worth of work
// and hit the Edge Function 150s timeout long before finishing.
//
// Now: the HTTP call is started, registered with EdgeRuntime.waitUntil so
// the runtime keeps it alive after the parent function returns, and the
// caller is unblocked immediately. Errors are logged but don't propagate.

declare const EdgeRuntime: {
  waitUntil?: (p: Promise<unknown>) => void;
} | undefined;

export async function triggerFunction(
  functionName: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/${functionName}`;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for trigger");
  }

  const fetchPromise = fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify(payload),
    keepalive: true,
  })
    .then(async (response) => {
      if (!response.ok) {
        const body = await response.text().catch(() => "");
        console.error(
          `Trigger ${functionName} failed: ${response.status} ${body.slice(0, 200)}`,
        );
      }
    })
    .catch((err) => {
      console.error(`Trigger ${functionName} threw:`, err);
    });

  // Keep the request alive after the parent function returns. If the runtime
  // doesn't expose waitUntil (older Deno), fall back to a short race so we at
  // least give the request a chance to leave the box before the function dies.
  if (typeof EdgeRuntime !== "undefined" && typeof EdgeRuntime.waitUntil === "function") {
    EdgeRuntime.waitUntil(fetchPromise);
  } else {
    await Promise.race([
      fetchPromise,
      new Promise<void>((resolve) => setTimeout(resolve, 500)),
    ]);
  }
}
