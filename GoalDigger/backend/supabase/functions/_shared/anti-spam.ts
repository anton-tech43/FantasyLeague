// Goal Digger — Anti-Spam Rule Enforcement
// Implements business rules from PROMPTS.md Section 6.
// Max 2 notifications/day, min 3 hours between, quiet hours 08:00-22:00 GMT.

import { getSupabaseClient } from "./supabase-client.ts";

export interface SpamCheckResult {
  allowed: boolean;
  reason?: string;
}

/** Check all anti-spam rules for a team. */
export async function checkAntiSpam(teamId: string): Promise<SpamCheckResult> {
  const supabase = getSupabaseClient();

  // Rule 1: Max 2 notifications per day per team
  const todayStart = new Date();
  todayStart.setUTCHours(0, 0, 0, 0);

  const { data: todayItems } = await supabase
    .from("content_items")
    .select("id, created_at")
    .eq("team_id", teamId)
    .in("status", ["approved", "published"])
    .gte("created_at", todayStart.toISOString());

  if ((todayItems?.length ?? 0) >= 2) {
    return { allowed: false, reason: "Max 2 notifications per day reached" };
  }

  // Rule 2: Min 3 hours between notifications for the same team
  const threeHoursAgo = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString();
  const { data: recentItems } = await supabase
    .from("content_items")
    .select("id")
    .eq("team_id", teamId)
    .in("status", ["approved", "published"])
    .gte("created_at", threeHoursAgo);

  if ((recentItems?.length ?? 0) > 0) {
    return { allowed: false, reason: "Min 3 hours between notifications not met" };
  }

  // Rule 3: Quiet hours (08:00-22:00 GMT)
  const now = new Date();
  const hour = now.getUTCHours();
  if (hour < 8 || hour >= 22) {
    return { allowed: false, reason: "Outside active hours (08:00-22:00 GMT)" };
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
