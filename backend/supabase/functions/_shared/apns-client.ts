// _shared/apns-client.ts
// Goal Digger — APNs HTTP/2 push notification client with JWT auth

// Note: Deno doesn't natively support HTTP/2. We use HTTP/1.1 to APNs which
// Apple also accepts. For production volume, consider a native HTTP/2 library.

import { getSupabaseClient } from "./supabase-client.ts";

interface APNsPayload {
  aps: {
    alert: {
      title: string;
      // Subtitle is optional. The end-user push (built by buildAPNsPayload)
      // omits it — the title carries the sister-voice opener and the body
      // carries the fact, no need for a middle line. The dev-alert push
      // (client-error-alert/index.ts) still sets it for app-version metadata.
      subtitle?: string;
      body: string;
    };
    sound: string;
    "mutable-content": number;
    category: string;
  };
  content_id: string;
  everyone_talking?: boolean;
}

interface APNsSendResult {
  token: string;
  success: boolean;
  status?: number;
  reason?: string;
}

function base64url(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function generateJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const keyP8 = Deno.env.get("APNS_KEY_P8");

  if (!keyId || !teamId || !keyP8) {
    throw new Error("Missing APNs credentials (APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8)");
  }

  const header = { alg: "ES256", kid: keyId };
  const now = Math.floor(Date.now() / 1000);
  const claims = { iss: teamId, iat: now };

  const encodedHeader = base64url(new TextEncoder().encode(JSON.stringify(header)));
  const encodedClaims = base64url(new TextEncoder().encode(JSON.stringify(claims)));
  const signingInput = `${encodedHeader}.${encodedClaims}`;

  // Decode the base64 P8 key
  const keyData = Uint8Array.from(atob(keyP8), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const encodedSignature = base64url(new Uint8Array(signature));
  return `${signingInput}.${encodedSignature}`;
}

// APNs rejects providers that mint a new ES256 token too often with
// 429 TooManyProviderTokenUpdates: one token must be REUSED for up to an hour.
// Minting per-send (the old behavior) meant a burst of N sends generated N
// tokens in seconds, so all but the first ~2 failed. We reuse one token for
// ~50 min, shared across Edge Function invocations via the apns_jwt_cache
// single-row table, with an in-memory memo so a single invocation's burst hits
// the DB at most once.
const JWT_TTL_MS = 50 * 60 * 1000; // refresh well inside APNs's 60-min validity
let memoJwt: { jwt: string; generatedAtMs: number } | null = null;

// Single-flight guard: a concurrent burst (bounded fan-out of N sends) calls
// getProviderJWT N times before the first mint completes. Memoizing only the
// RESULT let all N mint their own token on a cold/stale cache — N provider
// tokens in one second = APNs 429 TooManyProviderTokenUpdates for all but the
// first few (seen live 2026-07-10: 12 of 15 broadcast sends failed). Sharing
// the in-flight PROMISE means a burst performs exactly one mint.
let inflightJwt: Promise<string> | null = null;

function getProviderJWT(): Promise<string> {
  const nowMs = Date.now();
  if (memoJwt && nowMs - memoJwt.generatedAtMs < JWT_TTL_MS) {
    return Promise.resolve(memoJwt.jwt);
  }
  if (inflightJwt) return inflightJwt;
  inflightJwt = fetchOrMintJWT(nowMs).finally(() => {
    inflightJwt = null;
  });
  return inflightJwt;
}

async function fetchOrMintJWT(nowMs: number): Promise<string> {
  try {
    const supabase = getSupabaseClient();
    const { data } = await supabase
      .from("apns_jwt_cache")
      .select("jwt, generated_at")
      .eq("id", 1)
      .maybeSingle();

    if (data?.jwt && data.generated_at) {
      const ageMs = nowMs - new Date(data.generated_at as string).getTime();
      if (ageMs >= 0 && ageMs < JWT_TTL_MS) {
        memoJwt = { jwt: data.jwt as string, generatedAtMs: nowMs - ageMs };
        return memoJwt.jwt;
      }
    }

    // Missing or stale → mint one fresh token and persist it for everyone else.
    const jwt = await generateJWT();
    memoJwt = { jwt, generatedAtMs: nowMs };
    await supabase
      .from("apns_jwt_cache")
      .upsert({ id: 1, jwt, generated_at: new Date(nowMs).toISOString() });
    return jwt;
  } catch (_e) {
    // Cache table unreachable — never block a push on it. Fall back to a
    // process-local token (still far better than minting per-send).
    if (memoJwt) return memoJwt.jwt;
    const jwt = await generateJWT();
    memoJwt = { jwt, generatedAtMs: nowMs };
    return jwt;
  }
}

type APNsEnvironment = "development" | "production";

function getAPNsHost(env: APNsEnvironment): string {
  return env === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

/// Default environment when no per-token value is provided. Falls back to
/// the legacy APNS_ENVIRONMENT secret for compatibility, then to development.
function defaultAPNsEnvironment(): APNsEnvironment {
  const fromSecret = Deno.env.get("APNS_ENVIRONMENT");
  return fromSecret === "production" ? "production" : "development";
}

export async function sendPushNotification(
  token: string,
  payload: APNsPayload,
  environment?: APNsEnvironment,
): Promise<APNsSendResult> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.goaldigger.app";
  const env = environment ?? defaultAPNsEnvironment();

  try {
    const jwt = await getProviderJWT();
    const host = getAPNsHost(env);

    const doSend = (authJwt: string) =>
      fetch(`${host}/3/device/${token}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `bearer ${authJwt}`,
          "apns-topic": bundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify(payload),
      });

    let response = await doSend(jwt);
    if (response.status === 429) {
      // TooManyProviderTokenUpdates. By now the single-flight memo holds ONE
      // shared provider token — one delayed retry with it recovers the send.
      await new Promise((r) => setTimeout(r, 750));
      response = await doSend(await getProviderJWT());
    }

    if (response.ok) {
      return { token, success: true, status: 200 };
    }

    const body = await response.json().catch(() => ({}));
    return {
      token,
      success: false,
      status: response.status,
      reason: (body as Record<string, string>).reason ?? `HTTP ${response.status}`,
    };
  } catch (e) {
    return {
      token,
      success: false,
      reason: e instanceof Error ? e.message : String(e),
    };
  }
}

// ── Live Activity (ActivityKit) push ──────────────────────────────────────
// Keys MUST match the Swift Codable property names exactly (no custom
// CodingKeys on MatchActivityAttributes / ContentState).

interface LiveActivityContentState {
  homeScore: number;
  awayScore: number;
  statusLabel: string;
  // PUSH-6: match-watcher actually sends `elapsed` (the live minute the Swift
  // ContentState renders as "63' / 90"); the type was missing it and declared a
  // `note` nobody sends. Synced to the real wire shape.
  elapsed?: number | null;
  note?: string;
}

interface LiveActivityAttributesPayload {
  fixtureId: number;
  homeName: string;
  awayName: string;
  homeFlag: string;
  awayFlag: string;
  groupLabel?: string;
}

interface LiveActivityPushOptions {
  event: "start" | "update" | "end";
  contentState: LiveActivityContentState;
  /// Required for event="start" (push-to-start). The widget's ActivityAttributes type.
  attributes?: LiveActivityAttributesPayload;
  /// stale-date = now + this many seconds (the system dims the activity after).
  staleSeconds?: number;
  /// end only: dismissal-date = now + this many seconds (auto-removes the activity).
  dismissalSeconds?: number;
  /// Optional banner shown when a push-to-start activity appears.
  alert?: { title: string; body: string };
  environment?: APNsEnvironment;
  priority?: number;
}

/// Send an ActivityKit Live Activity push (start / update / end). Reuses the
/// same ES256 JWT + host selection as the alert path; differs only in the
/// `apns-push-type: liveactivity` header, the `.push-type.liveactivity` topic
/// suffix, and the `aps` payload shape. The token is a per-device
/// push-to-start token (event="start") or a per-activity update token
/// (event="update"/"end").
export async function sendLiveActivityPush(
  token: string,
  opts: LiveActivityPushOptions,
): Promise<APNsSendResult> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.goaldigger.app";
  const env = opts.environment ?? defaultAPNsEnvironment();

  try {
    const jwt = await getProviderJWT();
    const host = getAPNsHost(env);
    const now = Math.floor(Date.now() / 1000);

    const aps: Record<string, unknown> = {
      timestamp: now,
      event: opts.event,
      "content-state": opts.contentState,
    };
    if (opts.event === "start") {
      // ActivityAttributes type name (must match the Swift struct name).
      aps["attributes-type"] = "MatchActivityAttributes";
      aps["attributes"] = opts.attributes;
    }
    if (opts.alert) aps["alert"] = opts.alert;
    if (opts.staleSeconds) aps["stale-date"] = now + opts.staleSeconds;
    if (opts.event === "end" && opts.dismissalSeconds) {
      aps["dismissal-date"] = now + opts.dismissalSeconds;
    }

    const doSend = (authJwt: string) =>
      fetch(`${host}/3/device/${token}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `bearer ${authJwt}`,
          "apns-topic": `${bundleId}.push-type.liveactivity`,
          "apns-push-type": "liveactivity",
          "apns-priority": String(opts.priority ?? 10),
        },
        body: JSON.stringify({ aps }),
      });

    let response = await doSend(jwt);
    if (response.status === 429) {
      // Same TooManyProviderTokenUpdates recovery as sendPushNotification.
      await new Promise((r) => setTimeout(r, 750));
      response = await doSend(await getProviderJWT());
    }

    if (response.ok) return { token, success: true, status: 200 };
    const body = await response.json().catch(() => ({}));
    return {
      token,
      success: false,
      status: response.status,
      reason: (body as Record<string, string>).reason ?? `HTTP ${response.status}`,
    };
  } catch (e) {
    return { token, success: false, reason: e instanceof Error ? e.message : String(e) };
  }
}

export function buildAPNsPayload(
  teamShortName: string,
  headline: string,
  contentId: string,
  category: string,
  everyoneTalking = false,
  pushText?: string | null,
  pushTitle?: string | null,
): APNsPayload {
  // Lock-screen layout decisions:
  // - title = push_title when present (≤35 chars, sister-voice opener like
  //   "Stories incoming" / "Six weeks of moping" / "Crisis averted"), else
  //   the team short_name as fallback ("Forest") for legacy rows written
  //   before migration 012. iOS already shows the app icon + name above
  //   the alert, so the title slot is for the conversational hook, not
  //   identification.
  // - subtitle = omitted.
  // - body = push_text when present (≤90 chars, lock-screen-optimized), else
  //   the headline (fallback for rows pre-migration 011), truncated to 200
  //   chars to match iOS expanded-push limits.
  const title = (pushTitle && pushTitle.trim().length > 0)
    ? pushTitle.trim()
    : teamShortName;
  const body = (pushText && pushText.trim().length > 0)
    ? pushText.trim()
    : headline.slice(0, 200);

  return {
    aps: {
      alert: {
        title,
        body,
      },
      sound: "default",
      "mutable-content": 1,
      category,
    },
    content_id: contentId,
    everyone_talking: everyoneTalking || undefined,
  };
}

export type {
  APNsPayload,
  APNsSendResult,
  APNsEnvironment,
  LiveActivityContentState,
  LiveActivityAttributesPayload,
};
