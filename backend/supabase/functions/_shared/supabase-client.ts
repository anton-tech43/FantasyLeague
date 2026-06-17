// _shared/supabase-client.ts
// Goal Digger — Creates authenticated Supabase client for Edge Functions
//
// Key resolution order (2026-05-11 onward):
//   1. SERVICE_KEY  — new-model sb_secret_* key (Custom secret in dashboard)
//   2. SUPABASE_SERVICE_ROLE_KEY — legacy auto-managed JWT (transition fallback)
//
// The new-model key is preferred. The legacy fallback exists for the brief
// transition window while crons / routines / iOS rotate over. Once the legacy
// service_role JWT is disabled in the Supabase Dashboard (Settings → API
// Keys → Legacy tab), the fallback becomes dead code and can be removed.
// This switch was forced by a public-repo leak of the legacy JWT in
// migrations 015-017; full context in IMPLEMENTATION_PROGRESS.md.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

let _client: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (_client) return _client;

  const url = Deno.env.get("SUPABASE_URL");
  const key =
    Deno.env.get("SERVICE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !key) {
    throw new Error(
      "Missing SUPABASE_URL or SERVICE_KEY (legacy SUPABASE_SERVICE_ROLE_KEY also unset)",
    );
  }

  _client = createClient(url, key, {
    auth: { persistSession: false },
  });

  return _client;
}

/// PUSH-3: deactivate a token row when APNs reports it dead (410 Unregistered /
/// 400 BadDeviceToken). Shared by ALL senders so a dead token stops being
/// retried on every goal/match — previously only notification-sender did this,
/// so WC-only followers' dead tokens were never cleaned. Best-effort; never
/// throws. `table` picks the key column (device_tokens.apns_token vs
/// live_activity_tokens.token).
/// True when APNs reported this token permanently dead (410 Unregistered /
/// 400 BadDeviceToken). Shared by the single-token and batched deactivation
/// paths so the "what counts as dead" rule lives in exactly one place.
export function isTokenDead(
  result: { success: boolean; status?: number; reason?: string },
): boolean {
  if (result.success) return false;
  return result.status === 410 || result.status === 400 ||
    result.reason === "Unregistered" || result.reason === "BadDeviceToken";
}

export async function deactivateTokenIfDead(
  supabase: SupabaseClient,
  table: "device_tokens" | "live_activity_tokens",
  token: string,
  result: { success: boolean; status?: number; reason?: string },
): Promise<void> {
  if (!isTokenDead(result)) return;
  await deactivateTokens(supabase, table, [token]);
}

/// Batched variant of deactivateTokenIfDead: flip is_active=false for many dead
/// tokens in ONE UPDATE. The parallel fan-out senders collect the dead tokens
/// from their results array and call this once after the loop, instead of an
/// UPDATE per dead token. No-op on empty input. Best-effort — a permission/
/// logging hiccup must never break the send path. `table` picks the key column
/// (device_tokens.apns_token vs live_activity_tokens.token).
export async function deactivateTokens(
  supabase: SupabaseClient,
  table: "device_tokens" | "live_activity_tokens",
  tokens: string[],
): Promise<void> {
  if (tokens.length === 0) return;
  try {
    const col = table === "live_activity_tokens" ? "token" : "apns_token";
    await supabase
      .from(table)
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .in(col, tokens);
  } catch (_e) {
    // best-effort; a logging/permission hiccup must not break the send loop
  }
}
