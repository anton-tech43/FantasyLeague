// _shared/la-channels.ts
//
// Which push-to-start tokens get a broadcast-channel Live Activity
// (docs/LIVE_ACTIVITY_PLAN.md §5 step 3). Behind the LA_CHANNELS secret:
//   off (default, also any unknown value) — nobody; the token path only
//   allowlist — only tokens whose first 16 hex chars are in LA_CHANNEL_TOKENS
//               (comma-separated). No iOS check: the point is to learn what a
//               given phone and build does with a channel start.
//   on        — every token registered from Darwin 24+ (iOS 18+) by app build
//               16 or later. On iOS 17 a channel start is dropped by the
//               system; build 16 (2.3) is the only build the channel test has
//               proven (2026-11-02), and a start APNs accepts but a build
//               ignores leaves that phone with no card at all, since the token
//               fallback only runs when the channel cannot be created (bug
//               hunt 2026-11-03, P-C4). Unknown iOS or build = token path.

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

/// The first app build proven to show a channel start (la-channel-test).
/// Lower it only after the procedure in LIVE_ACTIVITY_PLAN §8 passes on that
/// build; raise nothing above it without the same.
export const LA_CHANNEL_MIN_BUILD = 16;

export function wantsChannel(
  mode: LaChannelMode,
  prefixes: Set<string>,
  row: { token: string; darwin_major?: number | null; app_build?: number | null },
): boolean {
  if (mode === "on") return (row.darwin_major ?? 0) >= 24 && (row.app_build ?? 0) >= LA_CHANNEL_MIN_BUILD;
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

/// Whether la-end-sweep may send the last end to a fixture's channels and
/// delete them (bug hunt 2026-11-03, P-C7). Channels are no-storage (policy 0,
/// so `apns-expiration` must be 0): a phone offline at full time never gets
/// the end, and a deleted channel cannot reach it later. So a FINISHED match
/// keeps its channels until three hours past kickoff (about an hour after the
/// whistle, after the 30 minutes the final score is shown), and the sweep then
/// broadcasts the end once more before deleting: a phone back online by then
/// loses the card. A match that ended any other way (abandoned, postponed) is
/// retired at once, as before; six hours past kickoff always.
/// ponytail: one re-send, not a schedule; a phone offline for the whole hour
/// still keeps its card until iOS's own limit. Upgrade: a policy-1 channel
/// (stores the latest message) if Apple's budget allows it for scores.
export function channelRetireDue(a: {
  ended: boolean; // FT/AET/PEN or ABD/CANC/PST/AWD/WO
  finished: boolean; // FT/AET/PEN: an end was broadcast at the whistle
  live: boolean;
  kickoffMs: number;
  nowMs: number;
}): boolean {
  const past = (h: number) => a.kickoffMs < a.nowMs - h * 3600_000;
  if (past(6)) return true;
  if (past(3) && !a.live) return true;
  return a.ended && !a.finished;
}
