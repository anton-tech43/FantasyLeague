// _shared/trigger.ts
// Goal Digger — Inter-function HTTP trigger, fire-and-forget
// We do NOT wait for the target function to finish. Each stage of the pipeline
// runs in its own invocation with its own CPU budget. This prevents one long
// Claude call from blowing the 150s CPU limit on the caller.

// deno-lint-ignore no-explicit-any
declare const EdgeRuntime: any;

export async function triggerFunction(
  functionName: string,
  payload: Record<string, unknown>
): Promise<void> {
  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/${functionName}`;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for trigger");
  }

  // Fire the request. We don't await the body — we only need to know the request
  // was accepted (headers arrived). The target function runs independently.
  const fetchPromise = fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": serviceKey,
      "Authorization": `Bearer ${serviceKey}`,
    },
    body: JSON.stringify(payload),
    // keepalive lets the request complete even if this function returns
    keepalive: true,
  })
    .then((r) => {
      // Only throw on sync-phase 401/403/400 (bad trigger). 2xx/5xx from the
      // target function is its own problem once it's running.
      if (r.status === 401 || r.status === 403 || r.status === 400) {
        return r.text().catch(() => "").then((body) => {
          console.error(`Trigger ${functionName} rejected: ${r.status} ${body}`);
        });
      }
    })
    .catch((e) => {
      console.error(`Trigger ${functionName} network error:`, e instanceof Error ? e.message : e);
    });

  // Ask the Supabase runtime to keep the fetch alive after we return a response.
  // Falls back to a small await if EdgeRuntime.waitUntil isn't available.
  if (typeof EdgeRuntime !== "undefined" && typeof EdgeRuntime.waitUntil === "function") {
    EdgeRuntime.waitUntil(fetchPromise);
  } else {
    // Best-effort: give the TCP connection a moment to actually start sending
    await Promise.race([
      fetchPromise,
      new Promise((res) => setTimeout(res, 500)),
    ]);
  }
}
