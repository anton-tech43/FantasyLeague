// _shared/la-channels.ts
//
// Which push-to-start tokens get a broadcast-channel Live Activity
// (docs/LIVE_ACTIVITY_PLAN.md §5 step 3). Behind the LA_CHANNELS secret:
//   off (default, also any unknown value) — nobody; the token path only
//   allowlist — only tokens whose first 16 hex chars are in LA_CHANNEL_TOKENS
//               (comma-separated). No iOS check: the point is to learn what a
//               given phone and build does with a channel start.
//   on        — every token registered from Darwin 24+ (iOS 18+). On iOS 17 a
//               channel start is dropped by the system, so unknown = no.

import type { APNsEnvironment } from "./apns-client.ts";
import { type LaAudience, LA_AUDIENCES } from "./la-notes.ts";

export type LaChannelMode = "off" | "allowlist" | "on";

export function laChannelMode(raw: string | undefined): LaChannelMode {
  const v = (raw ?? "").trim().toLowerCase();
  return v === "allowlist" || v === "on" ? v : "off";
}

export function laChannelPrefixes(raw: string | undefined): Set<string> {
  return new Set(
    (raw ?? "").split(",").map((p) => p.trim().toLowerCase().slice(0, 16)).filter((p) => p.length === 16),
  );
}

export function wantsChannel(
  mode: LaChannelMode,
  prefixes: Set<string>,
  row: { token: string; darwin_major?: number | null },
): boolean {
  if (mode === "on") return (row.darwin_major ?? 0) >= 24;
  if (mode === "allowlist") return prefixes.has(row.token.slice(0, 16).toLowerCase());
  return false;
}

/// A fixture's broadcast channels (match_status_state.la_channels, mig 158):
/// up to three per environment, one per audience (_shared/la-notes.ts), since
/// a broadcast reaches everyone on the channel and a take note must only reach
/// the side it is about. Channels cannot cross environments.
export type LaChannels = Partial<Record<APNsEnvironment, Partial<Record<LaAudience, string>>>>;

export function parseLaChannels(raw: unknown): LaChannels {
  const out: LaChannels = {};
  if (!raw || typeof raw !== "object") return out;
  for (const env of ["production", "development"] as const) {
    const e = (raw as Record<string, unknown>)[env];
    if (!e || typeof e !== "object") continue;
    for (const aud of LA_AUDIENCES) {
      const id = (e as Record<string, unknown>)[aud];
      if (typeof id === "string" && id.length > 0) (out[env] ??= {})[aud] = id;
    }
  }
  return out;
}

/// Every channel in the map, flat.
export function channelList(ch: LaChannels): Array<{ env: APNsEnvironment; audience: LaAudience; channelId: string }> {
  const out: Array<{ env: APNsEnvironment; audience: LaAudience; channelId: string }> = [];
  for (const env of ["production", "development"] as const) {
    for (const audience of LA_AUDIENCES) {
      const channelId = ch[env]?.[audience];
      if (channelId) out.push({ env, audience, channelId });
    }
  }
  return out;
}
