// Goal Digger — Anti-Spam Rule Enforcement
// Implements business rules from Contract 4 (AGENT_CONTRACTS.md Section 7).
// Max 2 notifications/day (rolling 24h), min 3 hours between (skip for matchday),
// quiet hours 22:00-08:00 GMT.

import { getSupabaseClient } from "./supabase-client.ts";

export interface SpamCheckResult {
  allowed: boolean;
  reason?: string;
}

/** Check all anti-spam rules for a team. Contract 4 enforcement. */
export async function checkAntiSpam(
  teamId: string,
  contentType: "news" | "matchday" = "news",
): Promise<SpamCheckResult> {
  const supabase = getSupabaseClient();

  // Rule 1: Quiet hours (22:00-08:00 GMT)
  const now = new Date();
  const hour = now.getUTCHours();
  if (hour < 8 || hour >= 22) {
    return { allowed: false, reason: "Outside active hours (08:00-22:00 GMT)" };
  }

  // Rule 2: Max 2 notifications per day per team (rolling 24h window)
  const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count: dailyCount } = await supabase
    .from("content_items")
    .select("*", { count: "exact", head: true })
    .eq("team_id", teamId)
    .eq("status", "published")
    .gte("published_at", twentyFourHoursAgo);

  if ((dailyCount ?? 0) >= 2) {
    return { allowed: false, reason: "Max 2 notifications per day reached" };
  }

  // Rule 3: Min 3 hours between notifications (skip for matchday per Contract 4)
  if (contentType !== "matchday") {
    const { data: lastPublished } = await supabase
      .from("content_items")
      .select("published_at")
      .eq("team_id", teamId)
      .eq("status", "published")
      .order("published_at", { ascending: false })
      .limit(1);

    if (lastPublished?.[0]?.published_at) {
      const hoursSinceLast =
        (Date.now() - new Date(lastPublished[0].published_at).getTime()) / (1000 * 60 * 60);
      if (hoursSinceLast < 3) {
        return { allowed: false, reason: "Min 3 hours between notifications not met" };
      }
    }
  }

  return { allowed: true };
}

/** Check if a similar headline was recently published (deduplication). */
export async function isDuplicateContent(
  teamId: string,
  headline: string,
): Promise<boolean> {
  const supabase = getSupabaseClient();
  const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();

  const { data } = await supabase
    .from("content_items")
    .select("headline")
    .eq("team_id", teamId)
    .in("status", ["draft", "approved", "published"])
    .gte("created_at", sixHoursAgo);

  if (!data || data.length === 0) return false;

  // Simple keyword overlap check for deduplication
  const newWords = new Set(
    headline.toLowerCase().split(/\s+/).filter((w) => w.length > 3),
  );

  for (const item of data) {
    const existingWords = new Set(
      (item.headline as string).toLowerCase().split(/\s+/).filter((w: string) => w.length > 3),
    );

    // Count overlapping words
    let overlap = 0;
    for (const word of newWords) {
      if (existingWords.has(word)) overlap++;
    }

    // If more than 60% of words overlap, consider it a duplicate
    const overlapRatio = overlap / Math.max(newWords.size, 1);
    if (overlapRatio > 0.6) return true;
  }

  return false;
}
