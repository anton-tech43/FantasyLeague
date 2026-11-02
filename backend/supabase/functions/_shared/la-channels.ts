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

/// match_status_state column holding the fixture's channel for an environment
/// (migration 157). Channels cannot cross environments.
export function channelColumn(env: APNsEnvironment): "la_channel_id" | "la_channel_id_dev" {
  return env === "production" ? "la_channel_id" : "la_channel_id_dev";
}
