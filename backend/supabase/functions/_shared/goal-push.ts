// _shared/goal-push.ts
// Deterministic goal-push helpers for the WC (zero Claude). match-watcher
// polls API-Football every minute and observes score changes against
// match_status_state; when a goal lands, followers of BOTH countries get an
// APNs alert within ~a minute, with perspective-aware copy (his team scored
// vs conceded). Pure functions, unit-tested.

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

/// Sister-voice, fact-first copy. No em-dashes (campaign rule). Title is
/// shared (≤35 chars with the META short names); the body flips perspective
/// for the scoring vs conceding side's followers.
export function renderGoalPush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
  side: GoalSide;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals, side } = args;
  const score = `${homeGoals}-${awayGoals}`;
  const title = `GOAL: ${home.name} ${score} ${away.name}`;

  if (side === "both") {
    const body = `It's ${score} between ${home.name} and ${away.name}. Goals flying in.`;
    return { title, bodies: { [home.id]: body, [away.id]: body } };
  }

  const scorer = side === "home" ? home : away;
  const conceder = side === "home" ? away : home;
  return {
    title,
    bodies: {
      [scorer.id]:
        `${scorer.flag} ${scorer.name} score! ${score}. He's celebrating, good moment to text him.`,
      [conceder.id]:
        `${scorer.flag} ${scorer.name} just scored. ${score}. He's not loving this one.`,
    },
  };
}

/// Deterministic half-time push for the two PLAYING countries' followers. The
/// title carries the scoreline (home-away order, names attached so it reads
/// unambiguously); the body flips to the follower's own perspective (leading /
/// trailing / level), score shown their-team-first. No em-dashes (campaign rule).
export function renderHalfTimePush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals } = args;
  return {
    title: `Half-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name}`,
    bodies: {
      [home.id]: halfTimeBody(homeGoals, awayGoals),
      [away.id]: halfTimeBody(awayGoals, homeGoals),
    },
  };
}

function halfTimeBody(mine: number, theirs: number): string {
  const score = `${mine}-${theirs}`;
  if (mine > theirs) return `Up ${score} at the break. He's enjoying this one.`;
  if (mine < theirs) return `Down ${score} at the break. Plenty of time left.`;
  return `Level ${score} at the break. All to play for.`;
}

/// Deterministic full-time own-result push for the two PLAYING countries'
/// followers, the gap that left tonight silent. Title carries the scoreline;
/// body flips to win / loss / draw from the follower's perspective. No
/// em-dashes (campaign rule).
export function renderFullTimePush(args: {
  home: GoalPushTeam;
  away: GoalPushTeam;
  homeGoals: number;
  awayGoals: number;
}): GoalPushCopy {
  const { home, away, homeGoals, awayGoals } = args;
  return {
    title: `Full-time: ${home.name} ${homeGoals}-${awayGoals} ${away.name}`,
    bodies: {
      [home.id]: fullTimeBody(homeGoals, awayGoals),
      [away.id]: fullTimeBody(awayGoals, homeGoals),
    },
  };
}

function fullTimeBody(mine: number, theirs: number): string {
  const score = `${mine}-${theirs}`;
  if (mine > theirs) return `Win! ${score} at full-time. He'll be buzzing, good time to text him.`;
  if (mine < theirs) return `Full-time, lost ${score}. He'll need a minute on this one.`;
  return `Full-time, ${score} draw. Honours even.`;
}
