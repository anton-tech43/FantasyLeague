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
