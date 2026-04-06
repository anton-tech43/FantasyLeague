// _shared/anti-spam.ts
// Goal Digger — Anti-spam rule enforcement (Contract 4)
// Tier-based daily limits: Tier 1=1, Tier 2=2, Tier 3=3

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SpamCheckResult } from "./types.ts";

type ContentType = "news" | "matchday" | "result" | "weekly_summary" | "monthly_summary";

const TIER_LIMITS: Record<number, number> = { 1: 1, 2: 2, 3: 3 };

export async function checkAntiSpamRules(
  supabase: SupabaseClient,
  teamId: string,
  contentType: ContentType,
  tier: number = 2
): Promise<SpamCheckResult> {
  // 1. Quiet hours check (22:00-08:00 UTC) — result notifications bypass this
  const hour = new Date().getUTCHours();
  if ((hour >= 22 || hour < 8) && contentType !== "result") {
    return { canSend: false, reason: "quiet_hours" };
  }

  // 2. Daily limit check — tier-dependent
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count } = await supabase
    .from("content_items")
    .select("*", { count: "exact", head: true })
    .eq("team_id", teamId)
    .eq("status", "published")
    .gte("published_at", oneDayAgo);

  const dailyMax = TIER_LIMITS[tier] ?? 2;
  if ((count ?? 0) >= dailyMax) {
    return { canSend: false, reason: "daily_limit_reached" };
  }

  // 3. Gap check — min 3 hours between notifications (matchday bypasses this)
  if (contentType !== "matchday" && contentType !== "result") {
    const { data } = await supabase
      .from("content_items")
      .select("published_at")
      .eq("team_id", teamId)
      .eq("status", "published")
      .order("published_at", { ascending: false })
      .limit(1);

    if (data?.[0]?.published_at) {
      const hoursSinceLast =
        (Date.now() - new Date(data[0].published_at).getTime()) / (1000 * 60 * 60);
      if (hoursSinceLast < 3) {
        return { canSend: false, reason: "gap_too_short" };
      }
    }
  }

  return { canSend: true };
}
