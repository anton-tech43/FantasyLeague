// _shared/anti-spam.ts
//
// DEPRECATED 2026-05-17 — kept as a tombstone for the type export only.
//
// All anti-spam rules removed. Volume control now lives in:
//   1. Tier-based content-type filtering (notification-sender minTierForType)
//   2. iOS Do Not Disturb (device-side quiet hours)
//
// Why removed (May 17):
//   - The 3-hour gap check had a bug: queried "most recent published_at" but
//     the item being considered for push is ALREADY 'published' at that point,
//     so it compared against itself → always 0h gap → always blocked when no
//     prior content_item existed for the team in the last 24h. Caused silent
//     push failures (user reports 5 instances of "didn't get a push").
//   - The 24h daily limit was redundant: tier segmentation in
//     notification-sender (minTierForType) already controls who receives what.
//     T1 gets matchday + news (capped naturally by how many newsworthy stories
//     exist per team per day). T2 adds sunday_brief. T3 reserved for future
//     premium surfaces. Total volume is bounded by content cadence, not by an
//     arbitrary 24h cap.
//   - Quiet hours (22:00-08:00 UTC server-side) suppressed matchday pushes for
//     late-evening fixtures, which is exactly when the user MOST wants the
//     post-FT push. iOS DND handles this better — push arrives, device respects
//     user's quiet hours settings.
//
// If new volume-control rules are needed in future, prefer:
//   - Tier-based content-type filter (extend notification-sender's minTierForType)
//   - Per-content-type frequency caps inside the routines (e.g., gd-news's own
//     dedup logic in PROMPT.md)
//   - User-side preferences (eventually: in-app "notify me only for X" toggle)

import { SpamCheckResult } from "./types.ts";

// Stub exported only to avoid import errors if any forgotten call site exists.
// Always returns canSend=true — every caller will push.
export async function checkAntiSpamRules(
  _supabase: unknown,
  _teamId: string,
  _contentType: string,
  _tier: number = 2,
): Promise<SpamCheckResult> {
  return { canSend: true };
}
