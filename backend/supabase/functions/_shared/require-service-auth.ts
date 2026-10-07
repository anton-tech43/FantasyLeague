// _shared/require-service-auth.ts
//
// Caller-authentication gate for server-only Edge Functions.
//
// WHY THIS EXISTS
// Supabase's gateway `verify_jwt` flag only checks that a JWT is present,
// signed, and unexpired — NOT its role. The anon/publishable key is a
// valid JWT that ships inside the iOS binary (extractable). So ANY
// function doing paid/sensitive work (Claude calls, API-Football quota,
// APNs sends, privileged DB writes) is invocable by anyone holding the
// anon key unless it checks the caller is presenting the SERVICE key.
//
// Confirmed live (2026-05-27): team-page-generator ran with no auth
// header at all → an attacker could loop POSTs and drain the Anthropic
// balance. This gate closes that for every server-only function.
//
// WHAT IT ACCEPTS — two credentials, each checked against its real caller:
//   - SERVICE_KEY (sb_secret_* custom secret) — what triggerFunction
//     (_shared/trigger.ts), page-refresh and notification-sender's alert
//     call send, and the routines' post scripts. Covers all inter-function
//     calls.
//   - CRON_AUTH_KEY (custom secret = the Vault `cron_service_key` value)
//     — what pg_cron jobs send via `get_cron_service_key()` AND what
//     manual ops curl sends from backend/.env. A random secret, changed
//     with scripts/rotate-cron-key.sh.
// The auto-injected SUPABASE_SERVICE_ROLE_KEY is deliberately NOT accepted
// (2026-10-07): no caller sends it, and a legacy key has no place here.
//
// DO NOT add this gate to functions the iOS app calls with the anon key
// (delete-my-data, live-brief-current, quiz-current) — it would break
// them. Those need a different control (rate-limit / read-only).
//
// Returns a 401 Response when the caller is NOT authorised (the handler
// should `return` it immediately). Returns null when authorised.

/// Constant-time string equality (QA-14). `===` / Array.includes return at the
/// first differing character, which leaks how much of a guess was right. The
/// length check returns early, but the length of a key is not the secret.
export function timingSafeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

export function requireServiceAuth(req: Request): Response | null {
  const presented = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();

  const accepted = [
    Deno.env.get("SERVICE_KEY"),
    Deno.env.get("CRON_AUTH_KEY"),
  ].filter((k): k is string => !!k && k.length > 0);

  // Compare against every key without short-circuiting, so the time taken
  // does not say which one matched.
  let ok = false;
  for (const k of accepted) ok = timingSafeEqual(presented, k) || ok;
  if (presented.length > 0 && ok) {
    return null;
  }

  // Don't leak which part failed. Generic 401.
  return new Response(
    JSON.stringify({ error: "unauthorized" }),
    { status: 401, headers: { "Content-Type": "application/json" } },
  );
}
