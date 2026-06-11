// _shared/stakes-templates.ts
//
// Deterministic, LLM-free copy for the WC group-stage stakes surfaces:
// next_fixture.preview, the this_week card, and the post_match card.
// Every string is templated from the stakes engine output — no Anthropic
// call, no token cost. Mirrors consequence-templates.ts.
//
// Voice: the routines' gf-to-bf older-sister tone — declarative, dry, a
// knowing aside. Two rules baked in:
//   1. TONE FOLLOWS THE REASON. A dead rubber because they're already
//      through reads positive ("free hit"); a game where the top-two hope
//      has gone reads MUTED and respectful, never "enjoy it" (the user's
//      explicit note: a team out of it probably just got knocked out).
//   2. TRUTH. Only `certainty: "certain"` stakes assert a guaranteed
//      outcome ("they're through"). Soft stakes hedge ("keep hopes alive",
//      "in their own hands") and NEVER claim through/out.
//
// De-FIFA: app-visible copy says "knockouts" / "last 16" / "the
// tournament", never "World Cup". No em-dashes (campaign-copy rule).

import type { FixtureStakes, GroupSituation } from "./stakes-engine.ts";
import type { BestThirdResult } from "./best-third.ts";

// ============================================================
// next_fixture.preview — one factual sentence, tone by reason
// ============================================================

export interface NextFixtureContext {
  teamName: string;
  opponentName: string;
  groupLabel: string; // e.g. "Group D"
  stakes: FixtureStakes;
}

export function renderNextFixturePreview(ctx: NextFixtureContext): string {
  const { teamName, opponentName: opp, groupLabel: grp, stakes } = ctx;
  switch (stakes.reason) {
    case "avoid_defeat_through":
      return `A point against ${opp} sends ${teamName} into the knockouts.`;
    case "win_through":
      return `Beat ${opp} and ${teamName} are through to the last 16.`;
    case "seeding_top_spot":
      return `${teamName} are already through; beat ${opp} to finish top of ${grp}.`;
    case "group_won_dead_rubber":
      return `${teamName} have already won ${grp}, so the ${opp} game is a free hit.`;
    case "through_dead_rubber":
      return `${teamName} are already through; the ${opp} result will not change that.`;
    case "must_not_lose":
      return `${teamName} need a win over ${opp} to keep their last-16 hopes in their own hands.`;
    case "third_place_longshot":
      return `The top-two route has gone, but beating ${opp} keeps a best-third place alive for ${teamName}.`;
    case "at_worst_second":
      return `${teamName} are guaranteed at least 2nd in ${grp} and through to the last 16; the ${opp} game is about finishing top.`;
    case "third_place_through":
      return `${teamName} have done enough to go through as one of the best third-placed teams.`;
    case "third_place_out":
      return `${teamName} cannot reach the knockouts; their tournament ends in the group.`;
    case "group_opener":
      return `${teamName} open ${grp} against ${opp}.`;
    case "contention_generic":
      return `A big ${grp} game against ${opp}, with a knockout place on the line.`;
    case "non_group":
      return `${teamName} face ${opp} in a tune-up before the tournament.`;
    default:
      return `${teamName} face ${opp} in ${grp}.`;
  }
}

// ============================================================
// Opponent detail — appended to next_fixture.preview so the
// "Coming up" card, when expanded, shows the upcoming OPPONENT's
// full ones-to-know (manager + each player's position + the
// opponent's own descriptive text). ALWAYS names the opponent
// (never "your"/"his") so it reads unmistakably as the away side.
// Text only (no-build); the pictured version is the 2.0.1 in-card
// block. No em-dashes; de-FIFA.
// ============================================================

export interface OpponentDetail {
  manager?: string;
  players: Array<{ name: string; position?: string; oneLiner?: string }>;
}

/**
 * Multi-line summary of the upcoming OPPONENT (their manager + each key
 * player's position and the opponent's own one-liner), copied from the
 * opponent's curated ones-to-know. Returns "" when there is nothing to say
 * (e.g. a non-WC friendly opponent with no page), so the caller can append
 * unconditionally. One-liners are already token-stripped upstream, so they
 * never read in the opponent's-own-fan voice here.
 */
export function renderOpponentDetail(opponentName: string, info: OpponentDetail | null): string {
  if (!info) return "";
  const players = info.players.filter((p) => p.name && p.name.trim().length > 0);
  // Sections separated by a blank line for breathing room; players within the
  // ones-to-watch list also get a blank line between each (the user's "row
  // skip"). PLAIN text only — the current build renders the preview as a
  // verbatim Text, so bold (markdown) would show literal asterisks; bolding
  // is done natively by the structured Coming-up rendering in the 2.0.1 build.
  const sections: string[] = [];
  if (info.manager) sections.push(`${opponentName} are managed by ${info.manager}.`);
  if (players.length > 0) {
    const rows = players.map((p) => {
      const pos = p.position ? ` (${p.position})` : "";
      const desc = p.oneLiner ? `: ${p.oneLiner}` : "";
      return `${p.name}${pos}${desc}`;
    });
    sections.push(`Their ones to watch:\n\n${rows.join("\n\n")}`);
  }
  return sections.join("\n\n");
}

// ============================================================
// this_week card — group context + a light aside
// ============================================================

export interface ThisWeekContext {
  teamName: string;
  opponentName: string;
  groupLabel: string;
  stakes: FixtureStakes;
  /** Optional "the other game" framing, e.g. "Brazil meet Serbia". */
  otherFixtureLabel?: string;
}

export function renderThisWeek(ctx: ThisWeekContext): { text: string; talking_point: string } {
  const { teamName, opponentName: opp, groupLabel: grp, stakes, otherFixtureLabel } = ctx;
  const other = otherFixtureLabel ? ` ${otherFixtureLabel} in the other game.` : "";
  const stakeClause = stakeClauseFor(stakes, teamName);
  return {
    text: `${grp} this week: ${teamName} face ${opp}.${other} ${stakeClause}`.trim(),
    talking_point: talkingPointFor(stakes, teamName, opp),
  };
}

function stakeClauseFor(stakes: FixtureStakes, teamName: string): string {
  switch (stakes.reason) {
    case "avoid_defeat_through":
      return `A draw is enough to go through.`;
    case "win_through":
      return `A win books their place in the last 16.`;
    case "seeding_top_spot":
      return `Already through; this one is about topping the group.`;
    case "group_won_dead_rubber":
    case "through_dead_rubber":
      return `Their knockout spot is already secured.`;
    case "must_not_lose":
      return `They cannot afford to lose this one.`;
    case "third_place_longshot":
      return `It is a long shot now, but not over.`;
    case "at_worst_second":
      return `Already through; this one decides whether they finish top.`;
    case "third_place_through":
      return `Through as one of the best third-placed teams.`;
    case "third_place_out":
      return `Out of the tournament.`;
    case "group_opener":
      return `First game, everything still to play for.`;
    default:
      return `A knockout place is on the line.`;
  }
}

function talkingPointFor(stakes: FixtureStakes, teamName: string, opp: string): string {
  switch (stakes.reason) {
    case "group_won_dead_rubber":
    case "through_dead_rubber":
      return `Tell him the hard work is done and he can watch this one with his feet up.`;
    case "third_place_longshot":
      return `Worth a gentle "they need a big one and a favour elsewhere" rather than false hope.`;
    case "at_worst_second":
    case "third_place_through":
      return `They're safe. Ask him who he wants to avoid in the next round.`;
    case "third_place_out":
      return `Keep it kind, their tournament is over.`;
    case "avoid_defeat_through":
    case "win_through":
      return `Ask him what a result here would mean for who they meet next.`;
    default:
      return `Ask him how he is feeling about the ${opp} game.`;
  }
}

// ============================================================
// post_match card — written by match-watcher at FT, tone by outcome
// ============================================================

export type PostMatchState = "win" | "loss" | "draw";

export interface PostMatchContext {
  teamName: string;
  opponentName: string;
  teamScore: number; // goals the followed team scored
  oppScore: number; // goals conceded
  state: PostMatchState;
  /** The team's group situation AFTER this result. */
  situation: GroupSituation;
  /** Cross-group best-third verdict, when top-2 is closed (else undefined). */
  bestThird?: BestThirdResult;
}

export function renderPostMatch(
  ctx: PostMatchContext,
): { state: PostMatchState; text: string; talking_point: string } {
  const { teamName, opponentName: opp, teamScore, oppScore, state, situation } = ctx;
  const scoreline = `${teamScore}-${oppScore}`;
  const resultPhrase = state === "win"
    ? `beat ${opp} ${scoreline}`
    : state === "loss"
    ? `lost ${scoreline} to ${opp}`
    : `drew ${scoreline} with ${opp}`;

  // Tone is driven by the NEW situation, not just the result.
  switch (situation.state) {
    case "group_won":
      return {
        state,
        text: `${teamName} ${resultPhrase} and have won their group. Top seeds going into the knockouts.`,
        talking_point: `He gets to enjoy this one. Ask him who he wants to avoid in the draw.`,
      };
    case "through":
      return {
        state,
        text: `${teamName} ${resultPhrase} and are through to the last 16.`,
        talking_point: `Knockout football next. Worth asking him how far he thinks they can go.`,
      };
    case "top2_gone": {
      // Top-2 is gone. The best-third verdict (across the other groups)
      // decides the tone: in = upbeat; out = definitive but kind; pending =
      // honest "out of their hands". Never "enjoy it".
      const bt = ctx.bestThird?.status;
      if (bt === "guaranteed_in") {
        return {
          state,
          text: `${teamName} ${resultPhrase}, but they are through as one of the best third-placed teams.`,
          talking_point: `Through the side door. Worth asking him who they might meet next.`,
        };
      }
      if (bt === "out") {
        return {
          state,
          text: `${teamName} ${resultPhrase} and are out of the tournament.`,
          talking_point: `Keep it kind, their World Championship is over.`,
        };
      }
      return {
        state,
        text: `${teamName} ${resultPhrase}. The top-two route has gone; a best-third place is still in play, decided by the other groups.`,
        talking_point: `Keep it gentle. It is out of their hands now.`,
      };
    }
    default:
      return {
        state,
        text: `${teamName} ${resultPhrase}. It is still all to play for in the group.`,
        talking_point: `Ask him what they need from their next game.`,
      };
  }
}
