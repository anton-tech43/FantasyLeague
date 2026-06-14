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

/// Goal push for the two PLAYING countries' followers. Title carries the
/// home-away scoreline; the body flips perspective by routing the scorer pool
/// to the scoring country's slug and the conceder pool to the other. {flag} and
/// {team} both refer to the SCORER (so the conceding side's body reads "Mexico
/// score, he's not loving this"). No em-dashes (campaign rule).
export function renderGoalPush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  side: GoalSide;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, side, rng = Math.random } = args;
  const score = `${homeGoals}-${awayGoals}`;
  const title = `GOAL: ${home.name} ${score} ${away.name}`;

  if (side === "both") {
    const body = interpolate(pick(GOAL_BOTH, rng), { home: home.name, away: away.name, score });
    return { title, bodies: { [home.id]: body, [away.id]: body } };
  }

  const scorer = side === "home" ? home : away;
  const conceder = side === "home" ? away : home;
  const vars = { flag: scorer.flag, team: scorer.name, score };
  return {
    title,
    bodies: {
      [scorer.id]: interpolate(pick(GOAL_SCORED, rng), vars),
      [conceder.id]: interpolate(pick(GOAL_CONCEDED, rng), vars),
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
export function renderFullTimePush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  rng?: () => number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, rng = Math.random } = args;
  return {
    title: `Full-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name}`,
    bodies: {
      [home.id]: periodBody(FT_WIN, FT_LOSS, FT_DRAW, homeGoals, awayGoals, home.name, rng),
      [away.id]: periodBody(FT_WIN, FT_LOSS, FT_DRAW, awayGoals, homeGoals, away.name, rng),
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
