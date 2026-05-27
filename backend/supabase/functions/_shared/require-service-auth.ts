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
// WHAT IT ACCEPTS — three distinct credentials, because the key model
// fragmented after the May-11 rotation. Verified each against its real
// caller:
//   - SERVICE_KEY (sb_secret_* custom secret) — what triggerFunction
//     (_shared/trigger.ts) and the function's own DB client use. Covers
//     all inter-function trigger calls.
//   - SUPABASE_SERVICE_ROLE_KEY (auto-injected legacy JWT) — transition
//     fallback; included for completeness.
//   - CRON_AUTH_KEY (custom secret = the Vault `cron_service_key` value)
//     — what pg_cron jobs send via `get_cron_service_key()` AND what
//     manual ops curl sends from backend/.env. This value diverged from
//     the auto-injected SUPABASE_SERVICE_ROLE_KEY in the rotation, so it
//     must be accepted explicitly or every cron 401s. Set via
//     `supabase secrets set CRON_AUTH_KEY=<cron_service_key value>`.
//
// DO NOT add this gate to functions the iOS app calls with the anon key
// (delete-my-data, live-brief-current, quiz-current) — it would break
// them. Those need a different control (rate-limit / read-only).
//
// Returns a 401 Response when the caller is NOT authorised (the handler
// should `return` it immediately). Returns null when authorised.

export function requireServiceAuth(req: Request): Response | null {
  const presented = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();

  const accepted = [
    Deno.env.get("SERVICE_KEY"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    Deno.env.get("CRON_AUTH_KEY"),
  ].filter((k): k is string => !!k && k.length > 0);

  if (presented.length > 0 && accepted.includes(presented)) {
    return null;
  }

  // Don't leak which part failed. Generic 401.
  return new Response(
    JSON.stringify({ error: "unauthorized" }),
    { status: 401, headers: { "Content-Type": "application/json" } },
  );
}
