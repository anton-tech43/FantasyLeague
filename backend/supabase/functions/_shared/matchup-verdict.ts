// _shared/matchup-verdict.ts
// Deterministic "who's favoured" verdict from two teams' strength_rank, plus
// post-result framing ("as expected" vs "upset" vs "surprise"). Pure, no I/O,
// no Claude — feeds both the pre-game favorite tag (B2, team-page Coming-up
// card) and the post-FT framing (B3, match-watcher result content).
//
// strength_rank semantics: LOWER = STRONGER. For WC countries it's the FIFA
// world ranking (migration 067); for clubs it's the league standings position.
// The caller compares like with like (two FIFA ranks, or two league positions)
// and passes the gap threshold for that scale.

export type FavoriteTag = "likely_win" | "even" | "likely_loss";

export interface PreMatchVerdict {
  tag: FavoriteTag;
  label: string; // user-facing, e.g. "Likely win"
}

// How many rank places apart before we call a CLEAR favorite (rather than
// "could go either way"). FIFA ranks span ~1-100 across the WC field, so a
// 12-place edge is meaningful while still calling genuinely-close ties even.
// League positions only span 1-20, so clubs use a smaller gap. Both tunable.
export const WC_FAVORITE_GAP = 12;
export const CLUB_FAVORITE_GAP = 5;

/// Pre-game verdict from MY rank vs the OPPONENT's. Returns null when either
/// rank is unknown (so the caller simply shows no tag rather than guessing).
export function preMatchVerdict(
  myRank: number | null | undefined,
  oppRank: number | null | undefined,
  gap: number = WC_FAVORITE_GAP,
): PreMatchVerdict | null {
  if (myRank == null || oppRank == null) return null;
  const diff = oppRank - myRank; // positive => I'm stronger (lower rank)
  if (diff >= gap) return { tag: "likely_win", label: "Likely win" };
  if (diff <= -gap) return { tag: "likely_loss", label: "Likely loss" };
  return { tag: "even", label: "Could go either way" };
}

export type ResultFraming =
  | "as_expected" // favourite won / underdog lost — the ranking held
  | "upset" // the lower-ranked side won
  | "dropped_points" // clear favourite only drew
  | "good_point" // clear underdog earned a draw
  | "even_result"; // close on paper, any result

export interface ResultVerdict {
  framing: ResultFraming;
  // A short factual clause, MY-team perspective, ready to weave into FT copy.
  note: string;
}

/// Post-FT framing from MY perspective. myGoals/oppGoals are this team's and
/// the opponent's final goals. Returns null when either rank is unknown.
export function resultFraming(
  myRank: number | null | undefined,
  oppRank: number | null | undefined,
  myGoals: number,
  oppGoals: number,
  gap: number = WC_FAVORITE_GAP,
): ResultVerdict | null {
  const verdict = preMatchVerdict(myRank, oppRank, gap);
  if (!verdict) return null;
  const outcome: "win" | "loss" | "draw" = myGoals > oppGoals
    ? "win"
    : myGoals < oppGoals
    ? "loss"
    : "draw";

  if (verdict.tag === "even") {
    return { framing: "even_result", note: "An even matchup on paper." };
  }

  const favoured = verdict.tag === "likely_win";
  if (favoured) {
    if (outcome === "win") return { framing: "as_expected", note: "The win the rankings expected." };
    if (outcome === "draw") {
      return { framing: "dropped_points", note: "A surprise: the lower-ranked side held them." };
    }
    return { framing: "upset", note: "A genuine upset against the higher-ranked side." };
  }
  // underdog
  if (outcome === "win") return { framing: "upset", note: "An upset win over the higher-ranked side." };
  if (outcome === "draw") return { framing: "good_point", note: "A creditable draw with the higher-ranked side." };
  return { framing: "as_expected", note: "The result the rankings expected." };
}
