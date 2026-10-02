/**
 * Who goes on the "ones to know" card.
 *
 * Until 2026-09-30 this was Claude's judgement call from a prompt that asked
 * for "the 3 most relevant right now" and then handed over the API-Football
 * squad payload — a roster of names, ages, shirt numbers and photos with no
 * appearances, minutes, goals or rating anywhere in it. Asked a form question
 * with no form data, the model answered from reputation. Across the 20 active
 * clubs that put 20 of 60 picks outside their own squad's top fifteen by
 * minutes, including Newcastle's card leading on a goalkeeper who had not
 * played a single minute all season.
 *
 * So the pick stops being a judgement call. Same move the coach pre-filter in
 * team-page-generator already makes, for the same reason: hand Claude the
 * answer, not the question, and leave it the voice of the one-liner.
 *
 * REVISED 2026-10-02 after an adversarial review found three live defects in
 * the first version:
 *
 *   1. It ranked on all-competition goals while the card is a league card.
 *      Coventry's top pick was V. Torp — two goals, both in cup football, and
 *      ZERO league starts — on a page whose own context line reads "Premier
 *      League". Thirty-one of the sixty picks had `goals <> league_goals`.
 *      There is no `league_assists` column, so a league-correct ranking is not
 *      computable; the fix is therefore in ELIGIBILITY, not in the ordering —
 *      a player must have started at least one league game to appear on a
 *      league page. That removes Torp and leaves every club a full trio.
 *   2. `MIN_ELIGIBLE` did not protect a season rollover the way its comment
 *      claimed. On matchday one `maxMinutes` is 90, so the share term goes
 *      inert, the floor becomes the bar, and a whole starting XI qualifies —
 *      goalkeeper included, which is the exact Newcastle failure. It also
 *      excluded everyone who was substituted. Guarded now on how much season
 *      has actually happened.
 *   3. `sameName` compared whitespace and case only. The model writes names
 *      out in full where the feed abbreviates them, so the guard would have
 *      reported 46 of 60 CORRECT names as substitutions on the first real run.
 */

/** One squad member's season to date, as `players` holds it. */
export interface PlayerStatRow {
  name: string;
  position?: string | null;
  minutes?: number | null;
  appearances?: number | null;
  starts?: number | null;
  goals?: number | null;
  /** League only. `goals` counts every competition — the two differ often. */
  league_goals?: number | null;
  league_starts?: number | null;
  /** All competitions. There is no league-only assists column upstream. */
  assists?: number | null;
  rating?: number | null;
  captain?: boolean | null;
  photo_url?: string | null;
}

/**
 * A player must have this many minutes before he can carry the card at all,
 * whatever the rest of the squad has managed. Roughly one full match: below it
 * there is nothing to write a truthful present-tense sentence about.
 */
export const MIN_REGULAR_MINUTES = 90;

/**
 * ...and this share of whatever the most-used player in the squad has. The
 * absolute floor alone would let a fringe player through in May, when 90
 * minutes is a rounding error; the share alone would let everyone through in
 * August, when the leader has 180. Both, and the bar tracks the season.
 */
export const REGULAR_SHARE = 0.4;

/**
 * And the season has to have happened. Until the squad's most-used player has
 * this many appearances, every ranking is noise: after one match the leaders
 * are simply whoever was not substituted, which on 2026-10-02 was shown to
 * produce a goalkeeper-led trio. Three games is the same bar `audit-claims.ts`
 * reaches for before it will believe a table.
 */
export const MIN_LEADER_APPEARANCES = 3;

/**
 * Below this many eligible players we do not trust the data enough to override
 * Claude. Covers a club whose stats sync has not run, and every World
 * Championship country — `players` holds their squads but no minutes for any
 * of them, because a club-season column cannot describe a tournament.
 */
export const MIN_ELIGIBLE = 5;

const num = (v: number | null | undefined): number => (typeof v === "number" ? v : 0);

/** Strip accents, punctuation and case so two spellings can be compared. */
const fold = (s: string): string =>
  s.normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/ß/g, "ss").replace(/ø/gi, "o").replace(/đ/gi, "d")
    .toLowerCase().replace(/[^a-z\s]/g, " ").replace(/\s+/g, " ").trim();

/**
 * Compare two spellings of the same player.
 *
 * The feed abbreviates forenames and the cards write them out — `B. Saka` and
 * `Bukayo Saka` are one man — so a comparison that insists on the same string
 * reports almost every correct pick as a substitution. It also has to survive
 * accents (`P. Groß` / `P. Gross`, `Gabriel Magalhães` / `Magalhaes`) and the
 * doubled space the feed has sent more than once.
 *
 * Surnames must match. Forenames match when they are equal, or when one is the
 * initial of the other, or when either side has no forename at all.
 */
export const sameName = (a: string, b: string): boolean => {
  const fa = fold(a).split(" ").filter(Boolean);
  const fb = fold(b).split(" ").filter(Boolean);
  if (fa.length === 0 || fb.length === 0) return false;
  if (fa[fa.length - 1] !== fb[fb.length - 1]) return false;   // surname decides
  if (fa.length === 1 || fb.length === 1) return true;         // one side is bare
  const [ga, gb] = [fa[0], fb[0]];
  return ga === gb || ga.startsWith(gb) || gb.startsWith(ga);  // "b" vs "bukayo"
};

/** Attacking contribution: the single number this card is really about. */
const involvement = (p: PlayerStatRow): number => num(p.goals) + num(p.assists);

/**
 * The three to feature, or `null` when the squad's data cannot support a
 * confident pick — in which case the caller must fall back to letting Claude
 * choose, exactly as it did before this module existed.
 */
export function pickFeaturedPlayers(squad: PlayerStatRow[]): PlayerStatRow[] | null {
  const played = squad.filter((p) => typeof p.minutes === "number" && p.minutes > 0);
  if (played.length === 0) return null;

  const maxMinutes = Math.max(...played.map((p) => num(p.minutes)));
  const leaderApps = Math.max(...played.map((p) => num(p.appearances)));
  if (leaderApps < MIN_LEADER_APPEARANCES) return null;

  const threshold = Math.max(MIN_REGULAR_MINUTES, maxMinutes * REGULAR_SHARE);
  const eligible = played.filter((p) =>
    num(p.minutes) >= threshold &&
    // The page is a league page. A player who has never started a league game
    // does not belong on it, however good his cup record.
    num(p.league_starts) >= 1
  );
  if (eligible.length < MIN_ELIGIBLE) return null;

  return [...eligible]
    .sort((a, b) =>
      involvement(b) - involvement(a) ||
      num(b.rating) - num(a.rating) ||
      num(b.minutes) - num(a.minutes) ||
      a.name.localeCompare(b.name)
    )
    .slice(0, 3);
}

/**
 * Did Claude return the three it was given? Compares as a SEQUENCE, not as a
 * membership test: the first version filtered for returned names absent from
 * the featured list, which flagged nothing when the model returned two players
 * instead of three, the same player three times, or the right three in the
 * wrong order — and the prompt asks for a specific order.
 *
 * Returns a human-readable complaint, or null when it matched.
 */
export function describeSubstitution(
  featured: PlayerStatRow[],
  returned: Array<{ name?: string }>,
): string | null {
  const got = returned.map((p) => (p.name ?? "").trim());
  if (got.length !== featured.length) {
    return `returned ${got.length} players, expected ${featured.length}`;
  }
  const wrong = featured
    .map((f, i) => (sameName(f.name, got[i]) ? null : `${got[i] || "(blank)"} where ${f.name} was given`))
    .filter((x): x is string => x !== null);
  return wrong.length ? wrong.join("; ") : null;
}

/**
 * The squad's season as a compact table for the prompt. Handed over even when
 * the pick is pre-selected, because the one-liner should be able to say "four
 * goals in eight games" instead of reaching for a player's reputation.
 *
 * Every figure carries its competition on its face. An unlabelled number
 * beside a league table reads as a league number, which is how Ødegaard's card
 * came to claim four league goals over a league tally of two, and how a later
 * one claimed "the most appearances of any outfield player" for a man tied
 * with three team-mates.
 *
 * Ordered by minutes so a truncated tail loses the players who matter least.
 */
export function formatSquadStats(squad: PlayerStatRow[]): string {
  const played = squad.filter((p) => typeof p.minutes === "number" && p.minutes > 0);
  if (played.length === 0) return "";

  return [...played]
    .sort((a, b) => num(b.minutes) - num(a.minutes))
    .map((p) =>
      [
        p.name,
        p.position ?? "?",
        `${num(p.appearances)} apps all comps`,
        `${num(p.starts)} starts all comps (${num(p.league_starts)} league)`,
        `${num(p.minutes)} mins all comps`,
        `${num(p.goals)}G all comps (${num(p.league_goals)} league)`,
        `${num(p.assists)}A all comps`,
        typeof p.rating === "number" ? `rating ${p.rating}` : "unrated",
        p.captain ? "captain" : "",
      ].filter(Boolean).join(", ")
    )
    .join("\n");
}
