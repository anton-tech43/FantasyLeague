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
    case "in_progress":
      return `${teamName} are playing ${opp} in ${grp} right now.`;
    case "just_finished":
      return `${teamName} have just finished their ${grp} game against ${opp}.`;
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
  // Live / just-finished games get their own present-tense framing rather than
  // the future-tense "face" sentence (the game is happening now, or just ended).
  if (stakes.reason === "in_progress") {
    return {
      text: `${grp} this week: ${teamName} are playing ${opp} right now.`,
      talking_point: `Ask him how the ${opp} game is going.`,
    };
  }
  if (stakes.reason === "just_finished") {
    return {
      text: `${grp} this week: ${teamName} have just played ${opp}.`,
      talking_point: `Ask him what he made of the ${opp} game.`,
    };
  }
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
    default: {
      // The group is still open. This is by far the most common branch, and it
      // used to return one fixed sentence — "Ask him what they need from their
      // next game." — which covered 111 of the 158 matchday cards the 2026
      // World Cup produced. On the day of the match, to almost everybody.
      //
      // It was never a writing problem: the branch already receives the result,
      // the opponent, the margin and how settled the group is, and used none of
      // it. No new data, no LLM call — just stop throwing the inputs away.
      const margin = Math.abs(teamScore - oppScore);
      const talking_point = state === "win"
        ? (margin >= 3
          ? `A win by that margin moves a group. Ask him who he would rather avoid now.`
          : `Ask him whether that felt comfortable, or closer than the scoreline makes it look.`)
        : state === "loss"
        ? (margin >= 3
          ? `Give him a minute with that one. Then ask what has to change before the next game.`
          : `A goal in it. Ask him what he would have done differently.`)
        : (situation.certainty === "soft"
          ? `A point keeps them alive. Ask him what they need from the last group game.`
          : `Ask him whether that was a decent night's work or two points dropped.`);
      return {
        state,
        text: `${teamName} ${resultPhrase}. It is still all to play for in the group.`,
        talking_point,
      };
    }
  }
}

// ============================================================
// CLUB pre game talk — deterministic, league vocabulary
//
// The WC templates above speak group-stage ("Group D", "the last 16"). A
// Premier League Saturday has no group and no qualification maths, so the
// facts that matter are different: which competition, home or away, where the
// two clubs sit in the table and how far apart, how each has been playing,
// who is favoured, and for a cup tie what a win actually wins.
//
// Until September 2026 nothing wrote any of this for a club: `next_fixture`
// carried the Monday routine's one sentence, verbatim, for up to six days
// after that fixture had been played (Sunderland's card named Arsenal above a
// sentence about Hull City). This runs on every 2-hourly dynamic_only refresh,
// costs nothing, and cannot go stale by more than two hours.
//
// House rules: no em-dashes, UK English, and the preview never says "he" or
// "him" (it is about the two clubs). The talking point is the opposite: it is
// addressed to her, about him, and is the one line she can use before kickoff.
// ============================================================

import type { PreMatchVerdict } from "./matchup-verdict.ts";

export interface ClubPreMatchContext {
  teamName: string;
  opponentName: string;
  venue: "home" | "away";
  /** The competition, already in prose ("Premier League", "League Cup (Carabao Cup)"). */
  competition?: string;
  /** The round in words ("last 32"), empty/absent for a league or league-phase game. */
  round?: string;
  /** League positions. Both set ONLY when both clubs are in the same table. */
  myPosition?: number | null;
  oppPosition?: number | null;
  myPoints?: number | null;
  oppPoints?: number | null;
  /** Last-five form strings ("WWDLW"); either may be missing. */
  myForm?: string | null;
  oppForm?: string | null;
  favorite?: PreMatchVerdict | null;
  /** For a covered cup tie: `knockoutOutcome(...)`, e.g. "Through to the last 16." */
  knockoutLine?: string | null;
}

/**
 * The pre game talk for a club: two to four sentences of fact, plus the one
 * line she can say before kickoff. Pure — every input is already-fetched data,
 * no Claude, no I/O. The caller appends the Monday routine's colour sentence
 * after a blank line, and only while its fixture id still matches.
 */
export function renderClubPreMatch(
  ctx: ClubPreMatchContext,
): { preview: string; talking_point: string } {
  const { teamName: team, opponentName: opp, venue } = ctx;
  const where = venue === "home" ? `are at home to ${opp}` : `are away at ${opp}`;
  const comp = ctx.competition
    ? ` in the ${ctx.competition}${ctx.round ? `, ${ctx.round}` : ""}`
    : "";
  const opening = `${team} ${where}${comp}.`;

  const table = tableSentence(ctx);
  const form = formSentence(ctx);
  const verdict = verdictSentence(ctx);
  const stake = stakeSentence(ctx.knockoutLine, team);

  // Two to four sentences. The opening always earns its place and the stake is
  // the only thing she cannot work out from the rest of the card, so when a
  // cup tie between two table clubs would run to five, the form goes.
  let parts = [opening, table, form, verdict, stake].filter((s): s is string => !!s);
  if (parts.length > 4) parts = parts.filter((s) => s !== form);

  return { preview: parts.join(" "), talking_point: clubTalkingPoint(ctx) };
}

/** The this_week card in league vocabulary. Mirrors renderThisWeek's shape. */
export function renderClubThisWeek(
  ctx: ClubPreMatchContext,
): { text: string; talking_point: string } {
  const { teamName: team, opponentName: opp, venue } = ctx;
  const where = venue === "home" ? `are at home to ${opp}` : `are away at ${opp}`;
  const head = ctx.competition ? `${ctx.competition} this week` : "This week";
  const context = tableSentence(ctx) ?? verdictSentence(ctx) ??
    stakeSentence(ctx.knockoutLine, team);
  return {
    text: `${head}: ${team} ${where}.${context ? ` ${context}` : ""}`,
    // Deliberately not the pre-game talking point: both cards render on the
    // same tab, and the same sentence twice reads like a bug.
    talking_point: thisWeekTalkingPoint(ctx),
  };
}

function tableSentence(ctx: ClubPreMatchContext): string | null {
  const { myPosition: mine, oppPosition: theirs } = ctx;
  if (mine == null || theirs == null) return null;
  const heads = `${ordinal(mine)} against ${ordinal(theirs)} in the table`;
  if (ctx.myPoints == null || ctx.oppPoints == null) return `${heads}.`;
  const gap = Math.abs(ctx.myPoints - ctx.oppPoints);
  if (gap === 0) return `${heads}, level on points.`;
  if (gap === 1) return `${heads}, a point between them.`;
  return `${heads}, ${numberWord(gap)} points between them.`;
}

function formSentence(ctx: ClubPreMatchContext): string | null {
  const mine = formClause(ctx.myForm);
  const theirs = formClause(ctx.oppForm);
  if (!mine && !theirs) return null;
  if (mine && theirs) return `${ctx.teamName} come in ${mine}, ${ctx.opponentName} ${theirs}.`;
  if (mine) return `${ctx.teamName} come in ${mine}.`;
  return `${ctx.opponentName} come in ${theirs}.`;
}

/// "with three wins in their last five" from a W/D/L form string. Counts over
/// however many games there are, so an August page says "last three" rather
/// than claiming five that have not been played.
function formClause(form: string | null | undefined): string | null {
  const letters = (form ?? "").toUpperCase().replace(/[^WDL]/g, "").slice(-5);
  if (letters.length === 0) return null;
  const wins = letters.split("").filter((c) => c === "W").length;
  const played = `their last ${numberWord(letters.length)}`;
  if (wins === 0) return `without a win in ${played}`;
  if (wins === letters.length) return `having won all ${numberWord(wins)}`;
  return `with ${numberWord(wins)} ${wins === 1 ? "win" : "wins"} in ${played}`;
}

function verdictSentence(ctx: ClubPreMatchContext): string | null {
  switch (ctx.favorite?.tag) {
    case "likely_win":
      return `${ctx.teamName} go into it as the favourites.`;
    case "likely_loss":
      return `${ctx.opponentName} go into it as the favourites.`;
    case "even":
      return `It is close enough to go either way.`;
    default:
      return null;
  }
}

/// What a win wins, from `knockoutOutcome`. Null for a league game (empty
/// line), a league phase, or a first leg the tie does not settle.
///
/// Names the club rather than saying "them": in a cup tie between two clubs in
/// the same table, the sentence before this one has just named the FAVOURITE,
/// which may be the other side ("Chelsea go into it as the favourites. A win
/// takes them through" read as Chelsea on Leeds's own page).
function stakeSentence(
  knockoutLine: string | null | undefined,
  teamName: string,
): string | null {
  const line = (knockoutLine ?? "").trim();
  if (!line) return null;
  const through = line.match(/^Through to (.+)\.$/);
  if (through) return `A win takes ${teamName} through to ${through[1]}.`;
  const winners = line.match(/^(.+) winners\.$/);
  if (winners) return `Win it and ${teamName} are ${winners[1]} winners.`;
  return null;
}

/// The round a win reaches ("the last 16"), for the talking point.
function knockoutTarget(knockoutLine: string | null | undefined): string | null {
  const m = (knockoutLine ?? "").trim().match(/^Through to (.+)\.$/);
  return m ? m[1] : null;
}

function clubTalkingPoint(ctx: ClubPreMatchContext): string {
  const target = knockoutTarget(ctx.knockoutLine);
  if (target) return `Ask him what reaching ${target} would mean to them.`;
  if ((ctx.knockoutLine ?? "").trim().endsWith(" winners.")) {
    return `Ask him what winning it would mean to him.`;
  }
  const bothPlaced = ctx.myPosition != null && ctx.oppPosition != null;
  switch (ctx.favorite?.tag) {
    case "likely_win":
      return bothPlaced
        ? `Ask him whether ${ordinal(ctx.myPosition!)} against ${ordinal(ctx.oppPosition!)} is as easy as it sounds.`
        : `Ask him whether this is one they are supposed to win.`;
    case "likely_loss":
      return `Ask him what he would settle for against ${ctx.opponentName}.`;
    case "even":
      return `Ask him where he thinks the ${ctx.opponentName} game gets decided.`;
    default:
      return `Ask him how he is feeling about the ${ctx.opponentName} game.`;
  }
}

function thisWeekTalkingPoint(ctx: ClubPreMatchContext): string {
  if (knockoutTarget(ctx.knockoutLine)) {
    return `Worth asking him how far he thinks they can go in this one.`;
  }
  switch (ctx.favorite?.tag) {
    case "likely_win":
      return `Tell him you have seen the table and you fancy them for this one.`;
    case "likely_loss":
      return `Tell him you know this is the hard one, then ask what he would take from it.`;
    case "even":
      return `Ask him if he has a feeling about this one either way.`;
    default:
      return `Ask him what he makes of the ${ctx.opponentName} game.`;
  }
}

const NUMBER_WORDS = [
  "no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
  "eighteen", "nineteen", "twenty",
];

/// Small numbers read better as words in a sentence she is about to say out
/// loud ("nine points between them"). Anything past twenty stays a numeral.
export function numberWord(n: number): string {
  return NUMBER_WORDS[n] ?? String(n);
}

/// "3rd", "12th". Local copy: the team-page generator's own getOrdinal is not
/// exported and this module has no other reason to import it.
function ordinal(n: number): string {
  const s = ["th", "st", "nd", "rd"];
  const v = n % 100;
  return n + (s[(v - 20) % 10] || s[v] || s[0]);
}
