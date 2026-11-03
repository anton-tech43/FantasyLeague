// One push per club per three hours, counted per device tier (bug hunt
// 2026-11-03 P-C5). A push whose tier floor is F reached every follower at
// tier F and up. So after pushes with floors [F1, F2, ...] in the window, the
// tiers still unpushed are the ones below min(F). A new item with floor M
// goes only to tiers in [M, min(F)): a Light phone (tier 1) still gets the
// first big story (floor 1) after a Match-fit push (floor 2) earlier that
// morning, and the Match-fit phones that already had theirs get nothing.
//
// Returns the exclusive tier ceiling to send to (Infinity: nobody pushed
// yet), or null when every tier this item reaches was already pushed.
export function unpushedTierCeiling(minTier: number, earlierMinTiers: number[]): number | null {
  const pushedFrom = Math.min(Infinity, ...earlierMinTiers);
  return minTier < pushedFrom ? pushedFrom : null;
}
