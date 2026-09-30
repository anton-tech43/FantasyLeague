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
 * played a single minute all season, and Arsenal's on a striker with two
 * starts and no goals. A weekly regeneration never corrected any of it,
 * because every Monday re-asked the same question with the same blind spot.
 *
 * So the pick stops being a judgement call. This is the same move the coach
 * pre-filter in team-page-generator already makes for the same reason: hand
 * Claude the answer, not the question, and leave it the part it is actually
 * good at — the voice of the one-liner.
 *
 * The ranking is deliberately dull. Among players who are genuinely in the
 * side, order by attacking contribution, then by rating, then by minutes.
 * Goals and assists put forwards and creators ahead of defenders without
 * ever naming a position, which is what this card wants: the players she
 * will actually hear shouted about.
 */

/** One squad member's season to date, as `players` holds it. */
export interface PlayerStatRow {
  name: string;
  position?: string | null;
  minutes?: number | null;
  appearances?: number | null;
  starts?: number | null;
  goals?: number | null;
  assists?: number | null;
  rating?: number | null;
  captain?: boolean | null;
  photo_url?: string | null;
}

/**
 * A player must have this many minutes before he can carry the card at all,
 * whatever the rest of the squad has managed. Roughly one full match: below
 * it there is nothing to write a truthful present-tense sentence about.
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
 * Below this many eligible players we do not trust the data enough to
 * override Claude. That covers a season rollover (every row reset to zero),
 * a club whose stats sync has not run yet, and every World Championship
 * country — `players` holds all 48 squads but no minutes for any of them,
 * because a club-season column cannot describe a tournament. In each case
 * the caller keeps the old behaviour rather than emitting a confident
 * ranking of nothing.
 */
export const MIN_ELIGIBLE = 5;

const num = (v: number | null | undefined): number => (typeof v === "number" ? v : 0);

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
  const threshold = Math.max(MIN_REGULAR_MINUTES, maxMinutes * REGULAR_SHARE);
  const eligible = played.filter((p) => num(p.minutes) >= threshold);
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
 * The squad's season as a compact table for the prompt. Handed over even when
 * the pick is pre-selected, because the one-liner should be able to say "four
 * goals in eight games" instead of reaching for a player's reputation — the
 * tense slip that left Arsenal's card describing a signing fans were
 * "quietly excited about this season" in the last week of September.
 *
 * Ordered by minutes so a truncated tail loses the players who matter least.
 */
export function formatSquadStats(squad: PlayerStatRow[]): string {
  const played = squad.filter((p) => typeof p.minutes === "number" && p.minutes > 0);
  if (played.length === 0) return "";

  const rows = [...played]
    .sort((a, b) => num(b.minutes) - num(a.minutes))
    .map((p) =>
      [
        p.name,
        p.position ?? "?",
        `${num(p.appearances)} apps`,
        `${num(p.starts)} starts`,
        `${num(p.minutes)} mins`,
        `${num(p.goals)}G`,
        `${num(p.assists)}A`,
        p.rating ? `rating ${p.rating}` : "unrated",
        p.captain ? "captain" : "",
      ].filter(Boolean).join(", ")
    );

  return rows.join("\n");
}
