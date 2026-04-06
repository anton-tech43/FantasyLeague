// _shared/trigger.ts
// Goal Digger — Inter-function HTTP trigger (Contract 1)

export async function triggerFunction(
  functionName: string,
  payload: Record<string, unknown>
): Promise<void> {
  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/${functionName}`;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for trigger");
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(
      `Trigger ${functionName} failed: ${response.status} ${body}`
    );
  }
}
