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

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.117.0";

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

/// PUSH-3: deactivate a token row when APNs reports it dead. Shared by ALL
/// senders so a dead token stops being retried on every goal/match. `table`
/// picks the key column (device_tokens.apns_token vs live_activity_tokens.token).
///
/// True when APNs reported THIS TOKEN permanently dead: 410 Unregistered, or a
/// 400 whose reason names the token (BadDeviceToken / DeviceTokenNotForTopic).
/// Any other 400 (BadTopic, TopicDisallowed, PayloadEmpty, BadPriority, ...) is
/// a fault in OUR request — treating it as dead once deactivated every token
/// that received a malformed push (QA-03). Rule lives here only.
const DEAD_TOKEN_REASONS = new Set(["Unregistered", "BadDeviceToken", "DeviceTokenNotForTopic"]);

export function isTokenDead(
  result: { success: boolean; status?: number; reason?: string },
): boolean {
  if (result.success) return false;
  return result.status === 410 || DEAD_TOKEN_REASONS.has(result.reason ?? "");
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
  const col = table === "live_activity_tokens" ? "token" : "apns_token";
  // Chunked: the `.in()` list rides in the URL, and the gateway caps a request
  // line at about 8 KB. 25 Live Activity tokens (up to ~256 chars each) stay
  // under it (QA-04). Best-effort; a failure is logged, never thrown, so the
  // send loop is never broken by cleanup.
  for (let i = 0; i < tokens.length; i += 25) {
    const chunk = tokens.slice(i, i + 25);
    try {
      const { error } = await supabase
        .from(table)
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .in(col, chunk);
      if (error) console.error(`deactivateTokens(${table}) failed for ${chunk.length} tokens: ${error.message}`);
    } catch (e) {
      console.error(`deactivateTokens(${table}) threw for ${chunk.length} tokens: ${e instanceof Error ? e.message : e}`);
    }
  }
}

/// Read every row of a query past PostgREST's 1000-row cap (QA-04). `page`
/// builds the query for one [from, to] window; it must be stably ordered.
/// Throws on a read error so a caller never fans out to a silently partial list.
export async function fetchAllRows<T>(
  page: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: { message: string } | null }>,
  pageSize = 1000,
): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0;; from += pageSize) {
    const { data, error } = await page(from, from + pageSize - 1);
    if (error) throw new Error(error.message);
    rows.push(...(data ?? []));
    if (!data || data.length < pageSize) return rows;
  }
}
