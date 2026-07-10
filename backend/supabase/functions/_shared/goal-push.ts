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

import {
  FT_DRAW,
  FT_LOSS,
  FT_WIN,
  GOAL_BOTH,
  GOAL_CONCEDED,
  GOAL_SCORED,
  HT_AHEAD,
  HT_BEHIND,
  HT_LEVEL,
  KICKOFF_SOON,
} from "./goal-push-copy.ts";

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
    return minute ? `⚽ Own goal ${minute}` : "⚽ Own goal";
  }
  const name = (ev.playerName ?? "").trim();
  const suffix = ev.isPenalty ? " (pen)" : "";
  if (name && minute) return `⚽ ${name} ${minute}${suffix}`;
  if (name) return `⚽ ${name}${suffix}`;
  if (minute) return `⚽ Goal ${minute}${suffix}`;
  return null;
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

/// Stamp scorer photo URLs onto stored goal events, joined STRICTLY on the
/// provider player id (never the name). Missing id or missing lookup row →
/// photo null (iOS falls back to no face). Pure; never throws.
export function attachScorerPhotos(
  events: readonly StoredGoalEvent[] | null | undefined,
  photoByApiId: ReadonlyMap<number, string | null>,
): StoredGoalEvent[] {
  if (!Array.isArray(events)) return [];
  return events.map((e) => ({
    ...e,
    photo: e.playerApiId != null ? photoByApiId.get(e.playerApiId) ?? null : null,
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
function appendScorerLine(body: string, scorerLine: string | null | undefined): string {
  const line = (scorerLine ?? "").trim();
  if (!line) return body;
  return `${body} ${line}`;
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
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, rng = Math.random } = args;
  return {
    title: `Kickoff soon: ${home.name} v ${away.name}`,
    bodies: {
      [home.id]: interpolate(pick(KICKOFF_SOON, rng), { team: home.name, opp: away.name }),
      [away.id]: interpolate(pick(KICKOFF_SOON, rng), { team: away.name, opp: home.name }),
    },
  };
}

/// Half-time push for the two PLAYING countries' followers. Title carries the
/// home-away scoreline; each side's body is drawn from the ahead / behind /
/// level pool by its own perspective, score shown their-team-first.
export function renderHalfTimePush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, rng = Math.random } = args;
  return {
    title: `Half-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name}`,
    bodies: {
      [home.id]: periodBody(HT_AHEAD, HT_BEHIND, HT_LEVEL, homeGoals, awayGoals, home.name, rng),
      [away.id]: periodBody(HT_AHEAD, HT_BEHIND, HT_LEVEL, awayGoals, homeGoals, away.name, rng),
    },
  };
}

/// Full-time own-result push for the two PLAYING countries' followers. Title
/// carries the scoreline; each side's body is drawn from the win / loss / draw
/// pool by its own perspective.
///
/// `pens` (optional): shootout score when the match ended on penalties. Level
/// goals are then NOT a draw — the title appends "(4-2 on pens)" and both the
/// pool selection and the {score} placeholder use the shootout numbers, so the
/// winner's followers get win copy reading "4-2", never "drew 1-1".
export function renderFullTimePush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  pens?: { home: number; away: number } | null;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, pens, rng = Math.random } = args;
  const title = pens
    ? `Full-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name} (${pens.home}-${pens.away} on pens)`
    : `Full-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name}`;
  const [h, a] = pens ? [pens.home, pens.away] : [homeGoals, awayGoals];
  return {
    title,
    bodies: {
      [home.id]: periodBody(FT_WIN, FT_LOSS, FT_DRAW, h, a, home.name, rng),
      [away.id]: periodBody(FT_WIN, FT_LOSS, FT_DRAW, a, h, away.name, rng),
    },
  };
}

/// Shared body builder for the HT and FT pushes: picks from the leading /
/// trailing / level pool (or win / loss / draw) by the follower's own
/// perspective, score rendered their-team-first.
function periodBody(
  leadPool: readonly string[],
  trailPool: readonly string[],
  levelPool: readonly string[],
  mine: number,
  theirs: number,
  team: string,
  rng: () => number,
): string {
  const score = `${mine}-${theirs}`;
  const pool = mine > theirs ? leadPool : mine < theirs ? trailPool : levelPool;
  return interpolate(pick(pool, rng), { score, team });
}
