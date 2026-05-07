// _shared/apns-client.ts
// Goal Digger — APNs HTTP/2 push notification client with JWT auth

// Note: Deno doesn't natively support HTTP/2. We use HTTP/1.1 to APNs which
// Apple also accepts. For production volume, consider a native HTTP/2 library.

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
    const jwt = await generateJWT();
    const host = getAPNsHost(env);

    const response = await fetch(`${host}/3/device/${token}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify(payload),
    });

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

export type { APNsPayload, APNsSendResult, APNsEnvironment };
