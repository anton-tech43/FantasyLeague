// _shared/matchday-reminder-copy.ts
//
// Deterministic copy for the "his team plays" matchday reminder push. The
// reminder fires the MORNING of the match (09:00 Stockholm); for after-midnight
// kickoffs the morning-of would land after the game, so it fires the morning
// BEFORE (the fixture falls into the previous day's 24h window). The copy must
// therefore read correctly whether the game is "today" or "tomorrow".
//
// Times are rendered in the READER's timezone when known (device_tokens.timezone,
// mig 082), defaulting to Europe/London: the app is marketed and paid for in the
// UK (Anton, 2026-09-06). Devices on builds that predate mig 082 send no zone and
// therefore read London time until they update. DST-correct via Intl. No
// em-dashes (campaign rule).

export const DEFAULT_TZ = "Europe/London";

/// Return `tz` if Intl accepts it as an IANA zone, else the market default. A
/// device can report anything; a bad zone must never break a push.
export function safeTz(tz: string | null | undefined): string {
  if (!tz) return DEFAULT_TZ;
  try {
    new Intl.DateTimeFormat("en-GB", { timeZone: tz });
    return tz;
  } catch {
    return DEFAULT_TZ;
  }
}

/** Zone-local calendar date as "YYYY-MM-DD". */
function ymd(d: Date, tz: string = DEFAULT_TZ): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz }).format(d);
}

/** Zone-local 24h clock time as "HH:MM". */
export function hhmm(d: Date, tz: string = DEFAULT_TZ): string {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: tz,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(d);
}

/// "today" / "tomorrow" relative to `now`, both in the zone's local date. The
/// 24h reminder window guarantees the kickoff is one of these two.
export function dayWord(kickoff: Date, now: Date, tz: string = DEFAULT_TZ): string {
  const k = ymd(kickoff, tz);
  if (k === ymd(now, tz)) return "today";
  if (k === ymd(new Date(now.getTime() + 24 * 60 * 60 * 1000), tz)) return "tomorrow";
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
/// `tz` is the reader's zone (device_tokens.timezone); defaults to London.
export function renderMatchdayReminder(args: {
  teamName: string;
  opponent: string;
  kickoffUtc: Date;
  now: Date;
  tz?: string | null;
  rng?: () => number;
}): MatchdayReminderCopy {
  const { teamName, opponent, kickoffUtc, now, rng = Math.random } = args;
  const tz = safeTz(args.tz);
  const when = dayWord(kickoffUtc, now, tz);
  const whenAt = `${when} at ${hhmm(kickoffUtc, tz)}`;
  return {
    title: `${teamName} play ${when}`,
    body: pick(BODY_VARIANTS, rng)(teamName, opponent, whenAt),
  };
}

// ── Pre-match build-up FEED item (A1: the "feed is never empty" floor) ──────
// Deterministic content_item written ~24h before a WC match so a country's feed
// is never empty in the run-up, even for RSS-starved nations. No em-dashes.

const BUILDUP_TPS: Array<(team: string, opp: string) => string> = [
  (_t, opp) => `Ask him how he's feeling about the ${opp} game.`,
  (_t, _o) => `Text him "big one coming up?" and let him run with it.`,
  (_t, opp) => `Ask him who he wants to see start against ${opp}.`,
  (_t, opp) => `Ask him if he's quietly nervous about ${opp}.`,
  (team, _o) => `Ask him what ${team} need to do to get a result here.`,
];

export interface PreMatchBuildup {
  headline: string;
  body: string;
  talkingPoint: string;
}

/// Render the deterministic build-up feed item. `verdict` is the FIFA-rank
/// favorite tag from preMatchVerdict (or null when either rank is unknown).
export function renderPreMatchBuildup(args: {
  teamName: string;
  opponent: string;
  kickoffUtc: Date;
  now: Date;
  verdict?: "likely_win" | "even" | "likely_loss" | null;
  rng?: () => number;
}): PreMatchBuildup {
  const { teamName, opponent, kickoffUtc, now, verdict = null, rng = Math.random } = args;
  const whenAt = `${dayWord(kickoffUtc, now)} at ${hhmm(kickoffUtc)}`;
  const verdictLine = verdict === "likely_win"
    ? `On the world rankings ${teamName} are the favourites, but tournament football writes its own scripts.`
    : verdict === "likely_loss"
    ? `${opponent} sit higher in the world rankings, so ${teamName} go in as underdogs. Upsets happen.`
    : verdict === "even"
    ? `The rankings call this one close, it could go either way.`
    : `One to keep half an eye on.`;
  return {
    headline: `${teamName} face ${opponent} ${whenAt}`,
    body: `${teamName} face ${opponent} ${whenAt}. ${verdictLine}`,
    talkingPoint: pick(BUILDUP_TPS, rng)(teamName, opponent),
  };
}
