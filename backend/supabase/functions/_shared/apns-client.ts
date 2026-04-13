// _shared/apns-client.ts
// Goal Digger — APNs HTTP/2 push notification client with JWT auth

// Note: Deno doesn't natively support HTTP/2. We use HTTP/1.1 to APNs which
// Apple also accepts. For production volume, consider a native HTTP/2 library.

interface APNsPayload {
  aps: {
    alert: {
      title: string;
      subtitle: string;
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

function getAPNsHost(): string {
  const env = Deno.env.get("APNS_ENVIRONMENT") ?? "development";
  return env === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

export async function sendPushNotification(
  token: string,
  payload: APNsPayload
): Promise<APNsSendResult> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.goaldigger.app";

  try {
    const jwt = await generateJWT();
    const host = getAPNsHost();

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
  everyoneTalking = false
): APNsPayload {
  return {
    aps: {
      alert: {
        title: "Goal Digger",
        subtitle: teamShortName,
        body: headline.slice(0, 200),
      },
      sound: "default",
      "mutable-content": 1,
      category,
    },
    content_id: contentId,
    everyone_talking: everyoneTalking || undefined,
  };
}

export type { APNsPayload, APNsSendResult };
