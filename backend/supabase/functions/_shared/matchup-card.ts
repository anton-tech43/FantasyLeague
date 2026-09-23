// _shared/matchup-card.ts
// The `cards.matchup` card: what we can say about the specific club she is
// playing on Saturday, as opposed to what is true of a generic opponent.
//
// Two sources, both already ours by the time this runs:
//   * one `/predictions?fixture=<id>` payload, stored by data-fetcher as
//     `api_football_predictions` and WRAPPED with the fixture id it was bought
//     for (the feed's own response does not name it back).
//   * the opponent's `club_style` row (migration 112), which is hand-verified
//     and the only style-of-play data we have at all.
//
// Pure — no I/O, no Claude. The caller reads the two rows and hands them in.
//
// WHAT NEVER LEAVES THIS FILE: `predictions.percent` and `predictions.advice`.
// The advice string is literally betting copy ("Double chance : draw or
// Sunderland") and the percentages are the feed's own model, which
// DATA_SOURCES.md says is reported as the feed's opinion and never as fact.
// The app uses the verdict to pick a tone. It does not show a number.

export const PREDICTIONS_SOURCE = "api_football_predictions";

/** How many previous meetings the card carries. Newest first. */
export const H2H_LIMIT = 5;
/** How many of the opponent's formations the card carries, most-used first. */
export const FORMATION_LIMIT = 2;

/** One club_style row. NULL columns mean "not verified", never "false". */
export interface ClubStyleRow {
  set_piece: boolean | null;
  counter: boolean | null;
  aerial: boolean | null;
  long_range: boolean | null;
  close_range: boolean | null;
  attacks_side: string | null;
  verified_at: string | null;
}

export interface MatchupStyle {
  set_piece: boolean;
  counter: boolean;
  aerial: boolean;
  long_range: boolean;
  close_range: boolean;
  attacks_side: string | null;
  verified_at: string | null;
}

export interface MatchupH2H {
  date: string;
  home: string;
  away: string;
  score: string;
}

export interface MatchupCard {
  updated_at: string;
  fixture_id: number;
  opponent: string;
  our_form: string | null;
  their_form: string | null;
  our_clean_sheets: number | null;
  their_clean_sheets: number | null;
  their_formations: string[];
  h2h: MatchupH2H[];
  favourite: "us" | "them" | "even";
  style: MatchupStyle;
}

// deno-lint-ignore no-explicit-any
type Any = any;

/**
 * The fixture id `/predictions` should be bought for, out of a fresh
 * `/fixtures?team=&next=N` payload: the first one that has not kicked off.
 *
 * `?next=` is chronological and upcoming-only, so this is almost always
 * `response[0]`. The date check is for the 2-hour window in which response[0]
 * is a game that has already started — buying predictions for that one would
 * cost a call and then be skipped by the team page, which wants the NEXT one.
 */
export function nextFixtureIdForPredictions(payload: unknown, now: Date): number | null {
  const response = (payload as Any)?.response;
  if (!Array.isArray(response)) return null;
  for (const item of response) {
    const fixture = (item as Any)?.fixture;
    const id = fixture?.id;
    if (typeof id !== "number") continue;
    const t = Date.parse(fixture?.date ?? "");
    if (Number.isNaN(t) || t >= now.getTime()) return id;
  }
  return null;
}

/** The last five results of a season-long form string ("LLDWWDLW" → "DLW..."). */
function last5(form: unknown): string | null {
  return typeof form === "string" && form.length > 0 ? form.slice(-5) : null;
}

/** NULL (unverified) and false (verified untrue) both mean "claim nothing". */
function flag(v: boolean | null | undefined): boolean {
  return v === true;
}

/** The all-quiet style block, for an opponent with no row in the bank. */
function styleOf(row: ClubStyleRow | null | undefined): MatchupStyle {
  return {
    set_piece: flag(row?.set_piece),
    counter: flag(row?.counter),
    aerial: flag(row?.aerial),
    long_range: flag(row?.long_range),
    close_range: flag(row?.close_range),
    attacks_side: row?.attacks_side ?? null,
    verified_at: row?.verified_at ?? null,
  };
}

/**
 * Build the card, or null when the payload cannot support one.
 *
 * `opponentName` is passed in rather than taken from the feed so the card
 * names the club the way every other card on the page names it ("AFC
 * Bournemouth", not "Bournemouth").
 */
export function buildMatchupCard(args: {
  /** raw_fetch_logs.data for `api_football_predictions`. */
  payload: unknown;
  fixtureId: number;
  ourApiId: number;
  opponentName: string;
  style: ClubStyleRow | null;
  updatedAt: string;
}): MatchupCard | null {
  const resp = (args.payload as Any)?.response?.[0];
  const home = resp?.teams?.home;
  const away = resp?.teams?.away;
  if (!home || !away) return null;

  // Which side of the payload is ours. A payload that names neither of us is
  // the wrong fixture's, and a card built from it would describe two other
  // clubs entirely.
  const weAreHome = home.id === args.ourApiId;
  if (!weAreHome && away.id !== args.ourApiId) return null;
  const us = weAreHome ? home : away;
  const them = weAreHome ? away : home;

  const formations: string[] = (Array.isArray(them.league?.lineups) ? them.league.lineups : [])
    .filter((l: Any) => typeof l?.formation === "string" && (l?.played ?? 0) > 0)
    .sort((a: Any, b: Any) => (b.played ?? 0) - (a.played ?? 0))
    .slice(0, FORMATION_LIMIT)
    .map((l: Any) => l.formation as string);

  // The feed's h2h is the whole history and is NOT in date order (a 2025 tie
  // came back ahead of a 2018 one). Sort it ourselves, and keep only meetings
  // that actually have a score.
  const h2h: MatchupH2H[] = (Array.isArray(resp.h2h) ? resp.h2h : [])
    .filter((m: Any) =>
      typeof m?.goals?.home === "number" && typeof m?.goals?.away === "number" &&
      typeof m?.fixture?.date === "string" && !Number.isNaN(Date.parse(m.fixture.date))
    )
    .sort((a: Any, b: Any) => Date.parse(b.fixture.date) - Date.parse(a.fixture.date))
    .slice(0, H2H_LIMIT)
    .map((m: Any) => ({
      date: String(m.fixture.date).slice(0, 10),
      home: String(m.teams?.home?.name ?? ""),
      away: String(m.teams?.away?.name ?? ""),
      score: `${m.goals.home}-${m.goals.away}`,
    }));

  // The verdict, and only the verdict. No percentage, no advice string.
  const winnerId = resp.predictions?.winner?.id;
  const favourite: MatchupCard["favourite"] = winnerId === args.ourApiId
    ? "us"
    : winnerId === them.id
    ? "them"
    : "even";

  return {
    updated_at: args.updatedAt,
    fixture_id: args.fixtureId,
    opponent: args.opponentName,
    our_form: last5(us.league?.form),
    their_form: last5(them.league?.form),
    our_clean_sheets: typeof us.league?.clean_sheet?.total === "number"
      ? us.league.clean_sheet.total
      : null,
    their_clean_sheets: typeof them.league?.clean_sheet?.total === "number"
      ? them.league.clean_sheet.total
      : null,
    their_formations: formations,
    h2h,
    favourite,
    style: styleOf(args.style),
  };
}
