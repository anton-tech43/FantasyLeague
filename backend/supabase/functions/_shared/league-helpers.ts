// _shared/league-helpers.ts
// V2.0: shared league/season mapping. Used by data-fetcher, match-watcher,
// and matchday-scheduler so all three agree on which season to fetch for
// each league. Single source of truth — bump here when a new season starts.

/**
 * Map an API-Football league_id to the current season we should fetch.
 *
 *   - 39 (Premier League): date-aware. PL seasons start in early August.
 *     From July onwards we should fetch the next season's number, otherwise
 *     the previous (= current) season. The `getUTCMonth()` cutoff at >=6
 *     (July) gives a 1-month buffer before kickoff. Without this the old
 *     hardcoded `return 2025` would silently return empty fixtures from
 *     August 2026 onwards (when PL switches to season 2026).
 *   - 1  (World Championship): season 2026 = the 2026 tournament.
 *     Stays 2026 until WC 2030 enters API-Football.
 *
 * For any unknown league, defaults to the current calendar year — safe-ish
 * fallback for cup competitions but the table should explicitly map every
 * league we actually run.
 */
export function seasonForLeague(leagueId: number, at: Date = new Date()): number {
  const now = at;
  const year = now.getUTCFullYear();
  switch (leagueId) {
    // Every club competition follows the August-to-May season, so the cups
    // share the PL's July cutoff. The `default` branch below returns the
    // calendar year, which is right for a cup until 31 December and wrong
    // from 1 January — the 2026-27 FA Cup is season 2026 in API-Football.
    case 39:
    case 2:   // Champions League
    case 3:   // Europa League
    case 848: // Conference League
    case 45:  // FA Cup
    case 48:  // League Cup
      return now.getUTCMonth() >= 6 ? year : year - 1;
    case 1:  return 2026;
    default: return year;
  }
}

/**
 * Active leagues we currently fetch data for. Used by match-watcher and
 * matchday-scheduler to decide which leagues to poll fixtures for.
 *
 * The DB-authoritative version is `SELECT DISTINCT league_id FROM teams
 * WHERE league_id IS NOT NULL` — Edge Functions should prefer that query
 * over this hardcoded list when possible. This constant exists as a
 * fallback / sanity check when the DB query fails.
 */
export const FALLBACK_ACTIVE_LEAGUES: number[] = [39, 2, 1];

/**
 * Competitions we cover beyond a club's home league (CUP_COVERAGE_PLAN.md,
 * 2026-09-08). Mirrored in the `active_competition_ids()` / `poll_leagues()`
 * SQL functions, which decide what match-watcher polls. Which of OUR clubs is
 * in which cup is never stored — it is derived from the fixture feed.
 */
export const COVERED_CUP_LEAGUES: number[] = [
  2,   // UEFA Champions League
  3,   // UEFA Europa League
  848, // UEFA Europa Conference League
  48,  // League Cup (Carabao Cup)
  45,  // FA Cup
];

/** Competition names, keyed by API-Football league id. One table, many callers. */
export const COMPETITION_NAMES: Record<number, string> = {
  39: "Premier League",
  2: "Champions League",
  3: "Europa League",
  848: "Conference League",
  48: "League Cup",
  45: "FA Cup",
  1: "World Championship",
};

/** Human name for a competition id, for card copy, badges and calendar labels. */
export function competitionName(leagueId: number | undefined): string {
  return (leagueId !== undefined && COMPETITION_NAMES[leagueId]) || "Cup";
}

/**
 * The competition as it reads in a sentence. House copy (Anton, 2026-09-08):
 * "League Cup (Carabao Cup)" in prose, plain "League Cup" in a badge.
 */
export function competitionProse(leagueId: number | undefined): string {
  return leagueId === 48 ? "League Cup (Carabao Cup)" : competitionName(leagueId);
}

/**
 * How far into a knockout competition a round is. API-Football gives the round
 * verbatim ("Round of 32", "Quarter-finals", "Semi-finals", "Final", and for
 * league phases "League Stage - 3" / "Regular Season - 4").
 *
 * `stage` is the sortable part: 0 = league phase or an early round, then 16, 8,
 * 4, 2, 1 for the last 16 down to the final. Callers weight nights and gate
 * pushes off it rather than each re-parsing the string.
 */
export interface RoundInfo {
  stage: number;
  /** Two-legged European knockout ties: which leg, when the round says. */
  leg?: 1 | 2;
  label: string;
}

export function parseRound(round: string | undefined, leagueId?: number): RoundInfo {
  const r = (round ?? "").toLowerCase();
  const leg = /2nd leg|second leg/.test(r) ? 2 : /1st leg|first leg/.test(r) ? 1 : undefined;

  // The FA Cup names its rounds by number and API-Football sends them that way
  // ("3rd Round", "5th Round"). The 5th round IS the last 16, so it takes the
  // last-16 stage rather than the generic numbered-round one: the tier floor
  // and the calendar weight both key off stage, and before this a "5th Round"
  // tie was gated as an early round while a hypothetical "Round of 16" was not.
  if (leagueId === 45) {
    const n = r.match(/(\d+)(?:st|nd|rd|th)?\s+round/);
    if (n && !/qualifying|replay/.test(r)) {
      const k = Number(n[1]);
      const stage = k === 5 ? 8 : k === 4 ? 16 : k === 3 ? 32 : 40;
      return { stage, leg, label: `${k}${ordinalSuffix(k)} round` };
    }
  }

  // "3rd Place Final" is not a final. Neither is "Semi-finals".
  const isFinal = /\bfinal\b/.test(r) && !/semi|quarter|3rd|third/.test(r);
  if (isFinal) return { stage: 1, leg, label: "final" };
  if (/semi/.test(r)) return { stage: 2, leg, label: "semi-final" };
  if (/quarter/.test(r)) return { stage: 4, leg, label: "quarter-final" };
  if (/round of 16|1\/8|last 16/.test(r)) return { stage: 8, leg, label: "last 16" };
  if (/round of 32|1\/16|last 32/.test(r)) return { stage: 16, leg, label: "last 32" };
  if (/round of 64|last 64/.test(r)) return { stage: 32, leg, label: "last 64" };
  // League Cup first round (August, 70 clubs, none of ours until round two
  // and only the non-European ones then). Unmapped, this fell through to stage
  // 0 and was pushed like a league phase: the smallest tie of the season sent
  // the most pushes.
  if (/round of 128|last 128/.test(r)) return { stage: 64, leg, label: "first round" };
  if (/play-?off|playoff/.test(r)) return { stage: 24, leg, label: "play-off" };

  // Numbered domestic-cup rounds ("3rd Round", "4th Round") and league phases.
  const numbered = r.match(/(\d+)(?:st|nd|rd|th)?\s+round/);
  if (numbered) return { stage: 40, leg, label: `${numbered[1]}${ordinalSuffix(Number(numbered[1]))} round` };
  return { stage: 0, leg, label: "" };
}

function ordinalSuffix(n: number): string {
  if (n % 100 >= 11 && n % 100 <= 13) return "th";
  return ["th", "st", "nd", "rd"][n % 10] ?? "th";
}

/** The round in words, for copy: "last 32", "quarter-final", "" for a league phase. */
export function roundLabel(round: string | undefined, leagueId?: number): string {
  return parseRound(round, leagueId).label;
}

/**
 * Is this cup tie decided on the night? The FT push says "Through to the last
 * 16" or "Out of the League Cup" only when it is. API-Football's round strings
 * never carry a leg marker in practice ("Play-offs", "Semi-finals" — checked
 * against three days of raw logs on 2026-09-09), so this is an allowlist of
 * rounds KNOWN to be one match, never the absence of the word "leg":
 *
 *   - FA Cup: every round (replays were abolished from the first round proper
 *     in 2024-25; a drawn qualifying-round tie is not ours to cover).
 *   - League Cup: every round except the semi-finals, which are two legs.
 *   - European competitions: the final only. The league phase settles nothing
 *     on the night and every knockout round is two-legged.
 *
 * Anything else — unknown competition, unparsed round — returns false and the
 * push names the competition without claiming a result.
 */
export function isSingleLegTie(leagueId: number | undefined, round: string | undefined): boolean {
  const { stage, leg } = parseRound(round, leagueId);
  if (leg !== undefined) return false;
  switch (leagueId) {
    case 45:
      return stage !== 0;
    case 48:
      return stage !== 0 && stage !== 2;
    case 2:
    case 3:
    case 848:
      return stage === 1;
    default:
      return false;
  }
}

/**
 * How much a fixture matters, 1-5, for the Calendar tab's dots.
 *
 * Everything used to be a flat 3, so a Champions League away leg in Naples read
 * exactly like a League Cup tie at Ipswich. The whole point of the calendar is
 * that she can see which night is the big one without knowing football, and a
 * cup makes that sharper still: a League Cup Tuesday in September and the
 * League Cup final are the same competition and nothing like the same evening.
 *
 * `opponentIsTopFlight` lifts an early FA Cup round — a third-round tie against
 * a Premier League club is a proper afternoon, one against a League Two side is
 * a formality until it is not.
 */
export function fixtureImportance(
  leagueId: number | undefined,
  round: string | undefined,
  opponentIsTopFlight?: boolean,
): number {
  const { stage } = parseRound(round, leagueId);
  const isFinal = stage === 1;
  const isSemi = stage === 2;
  const isQuarter = stage === 4;
  const isLast16 = stage === 8;

  switch (leagueId) {
    case 2: // Champions League — the knockouts are the biggest nights of his year.
      if (isFinal || isSemi || isQuarter) return 5;
      return 4; // last 16 and league phase both beat a midtable Saturday
    case 3: // Europa League
      if (isFinal) return 5;
      if (isSemi || isQuarter) return 4;
      return 3;
    case 848: // Conference League
      if (isFinal) return 4;
      if (isSemi || isQuarter) return 3;
      return 2;
    case 45: // FA Cup — semi-finals and the final are at Wembley.
      if (isFinal || isSemi) return 5;
      if (isQuarter) return 4;
      if (isLast16) return 3;
      return opponentIsTopFlight ? 3 : 2;
    case 48: // League Cup — a two-dot Tuesday until it is Wembley.
      if (isFinal) return 5;
      if (isSemi) return 4;
      if (isQuarter) return 3;
      return 2;
    case 39:
      return 3; // Premier League
    case 1:
      if (isFinal || isSemi || isQuarter) return 5;
      return 4;
    default:
      return 2;
  }
}

/**
 * Calendar label, capped at 30 chars by the caller. Trims the sponsor prefix
 * off the competition name and names the round — "Champions League semi-final"
 * tells her more than "UEFA Champions League". Two-legged European ties say
 * which leg, because "why are they playing them again" is the actual question.
 */
export function fixtureLabel(
  leagueName: string | undefined,
  leagueId: number | undefined,
  round: string | undefined,
): string {
  const base = leagueId !== undefined && leagueId in COMPETITION_NAMES
    ? COMPETITION_NAMES[leagueId]
    : (leagueName ?? "Fixture").replace(/^UEFA\s+/i, "").replace(/^FIFA\s+/i, "");
  const { stage, leg, label } = parseRound(round, leagueId);
  if (stage === 0 || !label) return base;
  if (stage === 1) return `${base} final`;
  const withRound = `${base} ${label}`;
  // The caller trims to 30 chars, and "Europa League quarter-final, leg 2" is
  // 34. Drop the LEG first, never the competition: a calendar row saying
  // "quarter-final, leg 2" does not tell her whether that is the Champions
  // League or the Europa League, which is the whole job of the label.
  if (leg) {
    const withLeg = `${withRound}, leg ${leg}`;
    if (withLeg.length <= 30) return withLeg;
    const shortLeg = `${base}, leg ${leg}`;
    if (withRound.length > 30 && shortLeg.length <= 30) return shortLeg;
  }
  return withRound;
}
