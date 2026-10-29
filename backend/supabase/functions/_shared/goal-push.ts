// _shared/goal-push.ts
// Deterministic goal-push helpers for the WC (zero Claude). match-watcher
// polls API-Football every minute and observes score changes against
// match_status_state; when a goal lands, followers of BOTH countries get an
// APNs alert within ~a minute, with perspective-aware copy (his team scored
// vs conceded). Pure functions, unit-tested.
//
// Copy variety: each event-and-perspective bucket draws from a 40-deep pool in
// goal-push-copy.ts, picked at fire-time, so the same goal/win/draw line never
// repeats across a long tournament. Perspective stays correct by construction:
// the scorer pool is only ever keyed to the scoring country's slug (see
// renderGoalPush), and match-watcher delivers bodies[token.country_id] per
// device. No em-dashes (campaign rule).

import { competitionName, parseRound, roundLabel } from "./league-helpers.ts";
import {
  FT_COPY,
  type FtSituation,
  GOAL_BOTH,
  GOAL_CONCEDED,
  GOAL_SCORED,
  HT_COPY,
  type HtSituation,
  KICKOFF_SOON,
} from "./goal-push-copy.ts";
import { decidingGoal, ordinal, sideGoals } from "./last-match.ts";

export type GoalSide = "home" | "away" | "both";

/// Which side scored since the last observed state. Null when nothing
/// pushed-worthy happened: no change, or a score DECREASE (VAR overturn — the
/// Live Activity silently corrects; a "goal disallowed" push would be noise).
/// Null prior goals (pre-kickoff rows) count as 0.
export function detectGoal(
  prevHome: number | null | undefined,
  prevAway: number | null | undefined,
  home: number | null | undefined,
  away: number | null | undefined,
): GoalSide | null {
  const ph = prevHome ?? 0;
  const pa = prevAway ?? 0;
  const h = home ?? 0;
  const a = away ?? 0;
  const homeScored = h > ph;
  const awayScored = a > pa;
  if (homeScored && awayScored) return "both";
  if (homeScored) return "home";
  if (awayScored) return "away";
  return null;
}

export interface GoalPushTeam {
  id: string; // country slug, e.g. "mexico"
  name: string; // short display name
  flag: string; // emoji
}

/// One scoring event as returned by API-Football's /fixtures/events endpoint,
/// already narrowed to the fields we surface. `teamApiId` is the API-Football
/// team id the goal is CREDITED to (for own goals this is the BENEFITING team,
/// not the scorer's own team — see formatScorerLine). `minute` is time.elapsed;
/// `extra` is time.extra (stoppage time) when present. `isOwnGoal` flags an
/// own goal so the line never misattributes the player to the wrong country.
export interface GoalEvent {
  teamApiId: number;
  playerName: string | null;
  /// API-Football player.id — the ONLY key we join scorer photos on (076/077).
  /// Never name-matched.
  playerApiId?: number | null;
  minute: number | null;
  extra: number | null;
  isOwnGoal: boolean;
  isPenalty: boolean;
}

/// Render the human minute string: "47'" or, in stoppage, "45+2'". Returns ""
/// when the minute is unknown (events lagging / malformed) so callers can drop
/// the segment cleanly rather than print a stray apostrophe.
export function formatMinute(minute: number | null, extra: number | null): string {
  if (minute == null || !Number.isFinite(minute)) return "";
  const base = Math.trunc(minute);
  const add = extra != null && Number.isFinite(extra) && extra > 0 ? `+${Math.trunc(extra)}` : "";
  return `${base}${add}'`;
}

/// Factual scorer line for the goal that just landed, e.g. "⚽ Pedri 47'",
/// "⚽ Kane 90+3' (pen)", or "⚽ Own goal 23'" (player omitted on purpose — the
/// API names the OWN-goal scorer from the conceding side, so naming them would
/// mislead the celebrating followers). Returns null when there is nothing
/// trustworthy to show (no player AND no minute), letting the push fall back to
/// the existing rotating copy with no extra line. Never throws.
export function formatScorerLine(ev: GoalEvent | null | undefined): string | null {
  if (!ev) return null;
  const minute = formatMinute(ev.minute, ev.extra);
  if (ev.isOwnGoal) {
    // Player belongs to the OTHER team; omit the name, keep it honest.
    return minute ? `Own goal ${minute}.` : "Own goal.";
  }
  const name = (ev.playerName ?? "").trim();
  const suffix = ev.isPenalty ? " (pen)" : "";
  if (name && minute) return `${name} ${minute}${suffix}.`;
  if (name) return `${name}${suffix}.`;
  if (minute) return `Goal ${minute}${suffix}.`;
  return null;
}

/// A deterministic rng (mulberry32) so a fixture's goals draw DIFFERENT lines
/// from the pool without two ticks ever disagreeing about which: seed on
/// fixture id and score. Math.random gave the same "he's buzzing" twice in one
/// evening and could not be reproduced in a test.
export function seededRng(seed: number): () => number {
  let a = (seed >>> 0) || 1;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/// One goal as persisted on match_status_state.goal_events for the live box.
/// `side` is which PLAYING side the goal counts for (home/away), resolved from
/// the API team id at fetch time so the read path (live-brief-current) never
/// needs the API ids. For own goals `side` is the BENEFITING side (matches how
/// the API credits the goal); the player name is dropped on display, never here.
export interface StoredGoalEvent {
  side: "home" | "away";
  player: string | null;
  playerApiId?: number | null;
  /// Scorer photo URL from the players table, stamped by attachScorerPhotos at
  /// fetch time (null/absent when the lookup missed). Key name `photo` is the
  /// iOS contract.
  photo?: string | null;
  minute: number | null;
  extra: number | null;
  isOwnGoal: boolean;
  isPenalty: boolean;
}

/// Project a fixture's parsed goal events into the live-box storage shape,
/// tagging each with the playing side (home/away) from the API team ids and
/// dropping any event that belongs to neither side (defensive). Sorted
/// chronologically (minute, then stoppage) so the live box lists goals in
/// the order they happened. Empty/malformed input → []. Never throws.
export function toStoredGoalEvents(
  events: readonly GoalEvent[] | null | undefined,
  homeApiId: number,
  awayApiId: number,
): StoredGoalEvent[] {
  if (!Array.isArray(events)) return [];
  const out: StoredGoalEvent[] = [];
  for (const ev of events) {
    const side = ev.teamApiId === homeApiId
      ? "home"
      : ev.teamApiId === awayApiId
      ? "away"
      : null;
    if (!side) continue;
    out.push({
      side,
      player: ev.playerName,
      playerApiId: ev.playerApiId ?? null,
      minute: ev.minute,
      extra: ev.extra,
      isOwnGoal: ev.isOwnGoal,
      isPenalty: ev.isPenalty,
    });
  }
  out.sort((a, b) => (a.minute ?? 0) - (b.minute ?? 0) || (a.extra ?? 0) - (b.extra ?? 0));
  return out;
}

/// API-Football player headshots are addressed deterministically by player id
/// (`.../players/<id>.png`) — the same value the `players` table stores. So a
/// valid player id is enough to build a face URL even when the players backfill
/// missed that player. A player with no photo just 404s and iOS shows nothing,
/// same as null — never a broken image.
export function scorerPhotoUrl(playerApiId: number): string {
  return `https://media.api-sports.io/football/players/${playerApiId}.png`;
}

/// Stamp scorer photo URLs onto stored goal events, joined STRICTLY on the
/// provider player id (never the name). Prefer the players-table value; fall
/// back to the deterministic CDN URL when the table has no row for that id, so
/// any scorer we have an id for always gets a face. No id → photo null. Pure;
/// never throws.
export function attachScorerPhotos(
  events: readonly StoredGoalEvent[] | null | undefined,
  photoByApiId: ReadonlyMap<number, string | null>,
): StoredGoalEvent[] {
  if (!Array.isArray(events)) return [];
  return events.map((e) => ({
    ...e,
    photo: e.playerApiId != null
      ? photoByApiId.get(e.playerApiId) ?? scorerPhotoUrl(e.playerApiId)
      : null,
  }));
}

/// A display-ready scorer line for the live box AND the post-game news article.
/// `minute` is the formatted string ("23'" / "45+2'"); `player` is the name (or
/// "Own goal"); `team` is the scoring side's name. `penalty` flags a spot-kick.
export interface DisplayScorer {
  side: "home" | "away";
  team: string;
  player: string;
  minute: string;
  penalty: boolean;
  photo: string | null;
}

/// Project stored goal events into display scorers, resolving each side's team
/// name. Chronological (stored already sorted). Empty/missing → []. Never throws.
export function formatScorers(
  events: readonly StoredGoalEvent[] | null | undefined,
  homeName: string,
  awayName: string,
): DisplayScorer[] {
  if (!Array.isArray(events)) return [];
  return events
    .filter((e) => e.side === "home" || e.side === "away")
    .map((e) => ({
      side: e.side,
      team: e.side === "home" ? homeName : awayName,
      player: e.isOwnGoal ? "Own goal" : ((e.player ?? "").trim() || "Goal"),
      minute: formatMinute(e.minute, e.extra),
      penalty: e.isPenalty && !e.isOwnGoal,
      // Own-goal photos are the WRONG side's face (API names the conceding
      // player) — drop them alongside the name.
      photo: e.isOwnGoal ? null : e.photo ?? null,
    }));
}

/// From a fixture's goal events, pick the one for the side that just scored,
/// preferring the LATEST (highest minute, then highest extra) — that is the
/// goal that triggered this tick's detectGoal. `scoringTeamApiId` is the
/// API-Football id of the side detectGoal reported. Tolerant of an empty or
/// malformed events array (returns null → caller surfaces no scorer line).
export function pickLatestGoalForTeam(
  events: readonly GoalEvent[] | null | undefined,
  scoringTeamApiId: number,
): GoalEvent | null {
  if (!Array.isArray(events) || events.length === 0) return null;
  let best: GoalEvent | null = null;
  for (const ev of events) {
    if (ev.teamApiId !== scoringTeamApiId) continue;
    if (best === null) {
      best = ev;
      continue;
    }
    const bm = best.minute ?? -1;
    const em = ev.minute ?? -1;
    const bx = best.extra ?? 0;
    const ex = ev.extra ?? 0;
    if (em > bm || (em === bm && ex > bx)) best = ev;
  }
  return best;
}

/// A short competition clause for a push body. Empty for the Premier League and
/// the World Championship, whose pushes already read unambiguously; a cup tie
/// does not, because "Sunderland 2-0 Hull" in September is a competition she has
/// not been told about. "League Cup, last 32." No sponsor name in a push.
export function competitionSuffix(leagueId: number | undefined, round: string | undefined): string {
  if (leagueId === undefined || leagueId === 39 || leagueId === 1) return "";
  const name = competitionName(leagueId);
  const rl = roundLabel(round, leagueId);
  return rl ? `${name}, ${rl}.` : `${name}.`;
}

/// What a finished knockout tie means for one side. `through` is null when the
/// tie is not decided by this match (a first leg), and the clause falls back to
/// naming the competition. Never guesses: match-watcher passes null unless it
/// can see the result settled it.
export function knockoutOutcome(
  leagueId: number | undefined,
  round: string | undefined,
  through: boolean | null,
): string {
  const suffix = competitionSuffix(leagueId, round);
  if (through === null) return suffix;
  const { stage } = parseRound(round, leagueId);
  if (stage === 0) return suffix;
  const name = competitionName(leagueId);
  if (!through) return `Out of the ${name}.`;
  if (stage === 1) return `${name} winners.`;
  // The FA Cup counts rounds, so "the fourth round" rather than "the last 32".
  const nextRound: Record<number, string> = leagueId === 45
    ? { 2: "the final", 4: "the semi-finals", 8: "the quarter-finals", 16: "the fifth round", 32: "the fourth round", 40: "the next round" }
    : { 2: "the final", 4: "the semi-finals", 8: "the quarter-finals", 16: "the last 16", 32: "the last 32", 64: "the second round" };
  return `Through to ${nextRound[stage] ?? "the next round"}.`;
}

/// Append a clause as its own sentence, skipping empties and double spaces.
function appendClause(body: string, clause: string | null | undefined): string {
  const c = (clause ?? "").trim();
  return c ? `${body} ${c}` : body;
}

export interface GoalPushCopy {
  title: string;
  /// Push body per follower country (keyed by country slug).
  bodies: Record<string, string>;
}

/// Pick a pool entry. rng defaults to Math.random (Deno-safe in the edge
/// runtime); tests inject a deterministic rng (e.g. () => 0) to assert which
/// variant is chosen.
export function pick<T>(pool: readonly T[], rng: () => number = Math.random): T {
  return pool[Math.floor(rng() * pool.length)];
}

/// Fill {flag} {team} {score} {home} {away} placeholders, drop any the template
/// does not use, and tidy the spacing left behind.
export function interpolate(template: string, vars: Record<string, string>): string {
  return template
    .replace(/\{(\w+)\}/g, (_, key) => vars[key] ?? "")
    .replace(/ {2,}/g, " ")
    .trim();
}

/// Append a factual scorer line (e.g. "⚽ Pedri 47'") to a rotating-copy body
/// as a distinct trailing sentence. Additive and conservative: the existing
/// pool line is untouched; a blank/absent line is a no-op. The scorer line is
/// the SAME factual fact for both perspectives (who scored, when), so it is
/// appended identically to the scorer's and conceder's bodies.
/// The scorer and minute LEAD the body: "Ødegaard 71'. Arsenal lead 0-1 and he
/// knows it." A push is read in one glance, and who and when is the fact she
/// wants; the reaction is the colour.
function appendScorerLine(body: string, scorerLine: string | null | undefined): string {
  const line = (scorerLine ?? "").trim();
  if (!line) return body;
  return `${line} ${body}`;
}

/// Goal push for the two PLAYING countries' followers. Title carries the
/// home-away scoreline; the body flips perspective by routing the scorer pool
/// to the scoring country's slug and the conceder pool to the other. {flag} and
/// {team} both refer to the SCORER (so the conceding side's body reads "Mexico
/// score, he's not loving this"). No em-dashes (campaign rule).
///
/// `scorerLine` (optional) is a pre-formatted factual line like "⚽ Pedri 47'"
/// (see formatScorerLine). When present it is appended to BOTH bodies as a
/// distinct trailing fact; when absent the copy is unchanged (clean fallback
/// when the events endpoint is empty / lagging).
export function renderGoalPush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  side: GoalSide;
  scorerLine?: string | null;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, side, scorerLine, rng = Math.random } = args;
  const score = `${homeGoals}-${awayGoals}`;
  const title = `GOAL: ${home.name} ${score} ${away.name}`;

  if (side === "both") {
    const body = appendScorerLine(
      interpolate(pick(GOAL_BOTH, rng), { home: home.name, away: away.name, score }),
      scorerLine,
    );
    return { title, bodies: { [home.id]: body, [away.id]: body } };
  }

  const scorer = side === "home" ? home : away;
  const conceder = side === "home" ? away : home;
  const vars = { flag: scorer.flag, team: scorer.name, score };
  return {
    title,
    bodies: {
      [scorer.id]: appendScorerLine(interpolate(pick(GOAL_SCORED, rng), vars), scorerLine),
      [conceder.id]: appendScorerLine(interpolate(pick(GOAL_CONCEDED, rng), vars), scorerLine),
    },
  };
}

/// 30-minutes-to-kickoff push for the two PLAYING countries' followers. The
/// "it's about to start" nudge. No score (not started); each side's body names
/// the follower's own team. Title is the shared factual fixture.
export function renderKickoffSoonPush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  /// Competition clause, from competitionSuffix(). Empty for the league.
  competition?: string;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, competition, rng = Math.random } = args;
  return {
    title: `Kickoff soon: ${home.name} v ${away.name}`,
    bodies: {
      [home.id]: appendClause(interpolate(pick(KICKOFF_SOON, rng), { team: home.name, opp: away.name }), competition),
      [away.id]: appendClause(interpolate(pick(KICKOFF_SOON, rng), { team: away.name, opp: home.name }), competition),
    },
  };
}

/// Half-time push for the two PLAYING teams' followers. Title carries the
/// home-away scoreline; each side's body says what kind of half it was from
/// its own perspective, score shown their-team-first, then a line to say.
export function renderHalfTimePush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  competition?: string;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, competition, rng = Math.random } = args;
  const body = (team: GoalPushTeam, mine: number, theirs: number) => {
    const c = HT_COPY[htSituation(mine, theirs)];
    const line = interpolate(pick(c.body, rng), { score: `${mine}-${theirs}`, team: team.name });
    return withSaying(appendClause(line, competition), c.say, rng);
  };
  return {
    title: `Half-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name}`,
    bodies: { [home.id]: body(home, homeGoals, awayGoals), [away.id]: body(away, awayGoals, homeGoals) },
  };
}

export function htSituation(mine: number, theirs: number): HtSituation {
  const d = mine - theirs;
  if (d >= 2) return "ahead_big";
  if (d === 1) return "ahead_one";
  if (d <= -2) return "behind_big";
  if (d === -1) return "behind_one";
  return mine === 0 ? "nil_nil" : "level_goals";
}

/// How a settled knockout tie ended for one side; null when the game settled
/// nothing (a league game, a first leg).
export type CupResult = "through" | "out" | "won";

export interface FtSideContext {
  side: "home" | "away";
  /// Half-time score, this side first. Null when unknown: no comeback claim.
  ht?: { mine: number; theirs: number } | null;
  cup?: CupResult | null;
}

/// What kind of game it was for one side, plus the {when} of a late goal.
/// Late (85'+) and comeback claims need the goal list to account for every
/// goal, and are never made after extra time, where the minutes mean
/// something else. Anything uncertain falls back to the plain result.
export function ftSituation(a: {
  mine: number;
  theirs: number;
  ctx?: FtSideContext;
  goals?: readonly StoredGoalEvent[] | null;
  pens?: { mine: number; theirs: number } | null;
  extraTime?: boolean;
}): { situation: FtSituation; when?: string } {
  const { mine, theirs, ctx, pens } = a;
  if (ctx?.cup) return { situation: ctx.cup === "won" ? "cup_won" : ctx.cup === "out" ? "cup_out" : "cup_through" };
  // A shootout settles a tie even when we could not say which round it was.
  if (pens) return { situation: pens.mine > pens.theirs ? "cup_through" : "cup_out" };

  const goals = ctx && !a.extraTime ? sideGoals(a.goals, ctx.side) : [];
  const trusted = goals.length > 0 && goals.length === mine + theirs;
  const late = (g: { minute: number; shownMinute: string }) =>
    g.minute >= 85 ? (g.shownMinute.includes("+") ? "in stoppage time" : `in the ${ordinal(Math.floor(g.minute))} minute`) : null;

  if (mine === theirs) {
    const last = trusted ? goals[goals.length - 1] : null;
    const when = last ? late(last) : null;
    if (last && when) return { situation: last.ours ? "draw_late_for" : "draw_late_against", when };
    return { situation: mine === 0 ? "draw_nil" : "draw_goals" };
  }
  const deciding = trusted ? decidingGoal(goals, mine, theirs) : null;
  const when = deciding ? late(deciding) : null;
  if (mine > theirs) {
    if (when) return { situation: "win_late", when };
    if (!a.extraTime && ctx?.ht && ctx.ht.mine < ctx.ht.theirs) return { situation: "win_comeback" };
    return { situation: mine - theirs >= 2 ? "win_big" : "win_narrow" };
  }
  if (when) return { situation: "loss_late", when };
  return { situation: theirs - mine >= 2 ? "loss_big" : "loss_narrow" };
}

/// Full-time own-result push for the two PLAYING teams' followers. Title
/// carries the scoreline; each side's body says what kind of game it was
/// (ftSituation), then the competition clause, then a line to say.
///
/// `pens` (optional): shootout score when the match ended on penalties. Level
/// goals are then NOT a draw: the title appends "(4-2 on pens)" and the body
/// reads "Won 4-2 on penalties.", never "drew 1-1".
export function renderFullTimePush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  pens?: { home: number; away: number } | null;
  /// Per-side closing clause: "Through to the last 16." for one, "Out of the
  /// League Cup." for the other. Keyed by team slug; missing means no clause.
  competitionBySide?: Record<string, string>;
  /// Half-time score (home-away), for the comeback line.
  ht?: { home: number; away: number } | null;
  /// Goal events in stored shape, for the late-goal lines.
  goals?: readonly StoredGoalEvent[] | null;
  /// How a settled knockout tie ended, keyed by team slug.
  cupBySide?: Record<string, CupResult | null>;
  extraTime?: boolean;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, pens, competitionBySide, rng = Math.random } = args;
  const title = pens
    ? `Full-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name} (${pens.home}-${pens.away} on pens)`
    : `Full-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name}`;
  const body = (team: GoalPushTeam, side: "home" | "away") => {
    const [mine, theirs] = side === "home" ? [homeGoals, awayGoals] : [awayGoals, homeGoals];
    const sidePens = pens ? (side === "home" ? { mine: pens.home, theirs: pens.away } : { mine: pens.away, theirs: pens.home }) : null;
    const ht = args.ht ? (side === "home" ? { mine: args.ht.home, theirs: args.ht.away } : { mine: args.ht.away, theirs: args.ht.home }) : null;
    const { situation, when } = ftSituation({
      mine, theirs, pens: sidePens, goals: args.goals, extraTime: args.extraTime,
      ctx: { side, ht, cup: args.cupBySide?.[team.id] ?? null },
    });
    const c = FT_COPY[situation];
    const score = sidePens ? `${sidePens.mine}-${sidePens.theirs}` : `${mine}-${theirs}`;
    const how = sidePens ? " on penalties" : args.extraTime ? " after extra time" : "";
    const line = interpolate(pick(c.body, rng), { score, team: team.name, when: when ?? "", how });
    return withSaying(appendClause(line, competitionBySide?.[team.id]), c.say, rng);
  };
  return { title, bodies: { [home.id]: body(home, "home"), [away.id]: body(away, "away") } };
}

/// What a lock-screen notification shows before it truncates, near enough.
export const SAYING_BODY_BUDGET = 178;

/// The HT/FT body with one line for her to say on the end. If both will not
/// fit what the lock screen shows, the line to say is kept and the situation
/// line goes: it is the reason this push carries anything at all.
export function withSaying(body: string, pool: readonly string[], rng: () => number): string {
  const say = `Say: \u201C${pick(pool, rng)}\u201D`;
  const both = `${body} ${say}`;
  return both.length <= SAYING_BODY_BUDGET ? both : say;
}

