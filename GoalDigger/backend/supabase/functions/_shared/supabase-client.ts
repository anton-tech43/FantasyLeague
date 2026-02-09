// Goal Digger — Shared Supabase Client
// Creates a Supabase client with the service role key for backend operations.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

let _client: SupabaseClient | null = null;

/** Get a Supabase client configured with the service role key. */
export function getSupabaseClient(): SupabaseClient {
  if (!_client) {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!url || !key) {
      throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set");
    }

    _client = createClient(url, key);
  }
  return _client;
}

/** Log a pipeline health entry. */
export async function logPipelineHealth(
  teamId: string,
  stage: "fetch" | "generate" | "review" | "publish",
  status: "success" | "failure" | "skipped",
  durationMs: number,
  message: string,
  contentItemId?: string,
): Promise<void> {
  const supabase = getSupabaseClient();
  await supabase.from("pipeline_health").insert({
    team_id: teamId,
    stage,
    status,
    duration_ms: durationMs,
    message,
    content_item_id: contentItemId ?? null,
  });
}

/** Trigger another Edge Function by name. */
export async function triggerFunction(
  functionName: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const res = await fetch(`${supabaseUrl}/functions/v1/${functionName}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error(`Failed to trigger ${functionName}: ${res.status} ${text}`);
  }
}
