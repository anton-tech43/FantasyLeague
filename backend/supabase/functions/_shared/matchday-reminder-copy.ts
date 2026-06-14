// _shared/matchday-reminder-copy.ts
//
// Deterministic copy for the "his team plays" matchday reminder push. The
// reminder fires the MORNING of the match (09:00 Stockholm); for after-midnight
// kickoffs the morning-of would land after the game, so it fires the morning
// BEFORE (the fixture falls into the previous day's 24h window). The copy must
// therefore read correctly whether the game is "today" or "tomorrow".
//
// Times are rendered in Europe/Stockholm (the audience market), DST-correct via
// Intl. No em-dashes (campaign rule).

const TZ = "Europe/Stockholm";

/** Stockholm-local calendar date as "YYYY-MM-DD". */
function ymd(d: Date): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(d);
}

/** Stockholm-local 24h clock time as "HH:MM". */
function hhmm(d: Date): string {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: TZ,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(d);
}

/// "today" / "tomorrow" relative to `now`, both in Stockholm-local date. The
/// 24h reminder window guarantees the kickoff is one of these two.
export function dayWord(kickoff: Date, now: Date): string {
  const k = ymd(kickoff);
  if (k === ymd(now)) return "today";
  if (k === ymd(new Date(now.getTime() + 24 * 60 * 60 * 1000))) return "tomorrow";
  return "soon"; // outside the window — defensive, shouldn't be reached
}

const BODY_VARIANTS: Array<(team: string, opp: string, whenAt: string) => string> = [
  (team, opp, whenAt) => `${team} face ${opp} ${whenAt}. Good day to ask how he's feeling about it.`,
  (team, opp, whenAt) => `${team} vs ${opp} ${whenAt}. Get him talking, ask how he thinks they'll do.`,
  (team, opp, whenAt) => `${team} play ${opp} ${whenAt}. Worth a "big one today?" text to set the tone.`,
  (team, opp, whenAt) => `${team} are up against ${opp} ${whenAt}. Ask him what he needs to see from them.`,
  (team, opp, whenAt) => `${team} take on ${opp} ${whenAt}. Drop him a line, he'll be thinking about it.`,
  (team, opp, whenAt) => `It's ${team} vs ${opp} ${whenAt}. He'll have one eye on it all day.`,
];

function pick<T>(arr: readonly T[], rng: () => number): T {
  return arr[Math.floor(rng() * arr.length)];
}

export interface MatchdayReminderCopy {
  title: string;
  body: string;
}

/// Render the reminder push for a single fixture. `now` is the moment the
/// reminder fires (the cron run), used only to decide "today" vs "tomorrow".
export function renderMatchdayReminder(args: {
  teamName: string;
  opponent: string;
  kickoffUtc: Date;
  now: Date;
  rng?: () => number;
}): MatchdayReminderCopy {
  const { teamName, opponent, kickoffUtc, now, rng = Math.random } = args;
  const when = dayWord(kickoffUtc, now);
  const whenAt = `${when} at ${hhmm(kickoffUtc)}`;
  return {
    title: `${teamName} play ${when}`,
    body: pick(BODY_VARIANTS, rng)(teamName, opponent, whenAt),
  };
}
