// A device that follows both clubs of a derby gets ONE reminder for the match
// (QA-18), across hourly runs too (bug hunt 2026-11-03 P-C6). Within a run the
// home side goes first and the away side skips tokens it already sent to; a
// later run cannot see that set, so if the other side's reminder was already
// claimed (matchday_reminders_sent), its followers are skipped here.
export interface ReminderToken {
  apns_token: string;
  team_id?: string | null;
  team_ids?: string[] | null;
  country_id?: string | null;
  country_ids?: string[] | null;
}

export function followsEntity(t: ReminderToken, id: string): boolean {
  return t.team_id === id || t.country_id === id ||
    (t.team_ids ?? []).includes(id) || (t.country_ids ?? []).includes(id);
}

export function tokensStillToRemind<T extends ReminderToken>(
  tokens: T[],
  remindedThisRun: Set<string>,
  opponentId: string | null,
  opponentAlreadyClaimed: boolean,
): T[] {
  return tokens.filter((t) =>
    !remindedThisRun.has(t.apns_token) &&
    !(opponentAlreadyClaimed && opponentId !== null && followsEntity(t, opponentId))
  );
}
