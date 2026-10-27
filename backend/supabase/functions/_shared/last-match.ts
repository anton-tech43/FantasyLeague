// The Matchday tab's "After {opponent}" card, written once per side at full
// time by match-watcher (2026-10-07). Pure and deterministic: every input is
// in hand at the whistle (score, half-time score, goal events, one
// /fixtures/statistics call, the players table), so there is no Claude here
// and nothing to bill.
//
// The card lives at team_pages.content.cards.last_match, which the app can
// already read, so no grant, view or RPC was added for it.

import type { StoredGoalEvent } from "./goal-push.ts";

export type LastMatchState = "win" | "loss" | "draw";

/// The few numbers we use from /fixtures/statistics, for one side. Every field
/// is optional: the endpoint omits types it has not got, and a cup tie at a
/// small ground can come back with nothing at all.
export interface SideStats {
  shots?: number;
  onTarget?: number;
  possession?: number; // percent, 0-100
  xg?: number;
}

/// /fixtures/statistics → stats per API team id. Unusable input → empty map.
export function parseFixtureStats(raw: unknown): Map<number, SideStats> {
  const out = new Map<number, SideStats>();
  if (!Array.isArray(raw)) return out;
  for (const row of raw) {
    const id = (row as { team?: { id?: unknown } })?.team?.id;
    const list = (row as { statistics?: unknown })?.statistics;
    if (typeof id !== "number" || !Array.isArray(list)) continue;
    const s: SideStats = {};
    for (const st of list) {
      const type = (st as { type?: unknown })?.type;
      const v = num((st as { value?: unknown })?.value);
      if (v === null) continue;
      if (type === "Total Shots") s.shots = v;
      else if (type === "Shots on Goal") s.onTarget = v;
      else if (type === "Ball Possession") s.possession = v;
      else if (type === "expected_goals") s.xg = v;
    }
    out.set(id, s);
  }
  return out;
}

function num(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const n = parseFloat(v.replace("%", ""));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

export function ordinal(n: number): string {
  const t = n % 100;
  if (t >= 11 && t <= 13) return `${n}th`;
  return `${n}${({ 1: "st", 2: "nd", 3: "rd" } as Record<number, string>)[n % 10] ?? "th"}`;
}

/// One goal from this side's point of view, in the order they went in.
export interface SideGoal {
  ours: boolean;
  player: string | null;
  playerApiId: number | null;
  minute: number; // with stoppage folded in for ordering only
  shownMinute: string; // "88'" or "90+3'"
  isOwnGoal: boolean;
  isPenalty: boolean;
  mine: number; // the score after it, ours first
  theirs: number;
}

/// Goal events in time order, with the running score after each one. Own
/// goals are already credited to the side that benefits (`side` on the stored
/// event), so the count is just "whose side".
export function sideGoals(events: readonly StoredGoalEvent[] | null | undefined, mySide: "home" | "away"): SideGoal[] {
  if (!Array.isArray(events)) return [];
  const sorted = events
    .filter((e) => e && typeof e.minute === "number")
    .slice()
    .sort((a, b) => (a.minute! - b.minute!) || ((a.extra ?? 0) - (b.extra ?? 0)));
  let mine = 0, theirs = 0;
  return sorted.map((e) => {
    const ours = e.side === mySide;
    if (ours) mine++; else theirs++;
    return {
      ours,
      player: e.player ?? null,
      playerApiId: e.playerApiId ?? null,
      minute: e.minute! + (e.extra ?? 0) / 100,
      shownMinute: e.extra ? `${e.minute}+${e.extra}'` : `${e.minute}'`,
      isOwnGoal: !!e.isOwnGoal,
      isPenalty: !!e.isPenalty,
      mine,
      theirs,
    };
  });
}

export interface VerdictInput {
  teamName: string;
  opponentName: string;
  state: LastMatchState;
  teamScore: number;
  oppScore: number;
  ht: { mine: number; theirs: number } | null;
  goals: SideGoal[];
  mine: SideStats;
  theirs: SideStats;
  /// Extra time or a shootout: the verdict falls back to the plain sentence,
  /// which already says how it ended.
  unusualFinish: boolean;
  fallback: string;
}

/// The serif line under the score: what kind of game it was, in one sentence
/// that fits two rows on the card. Facts only, from the score, the half-time
/// score, the goal minutes and the shot counts.
export function renderVerdict(v: VerdictInput): string {
  if (v.unusualFinish) return v.fallback;
  const { teamScore: gf, oppScore: ga, opponentName: opp } = v;
  const deciding = decidingGoal(v.goals, gf, ga);
  const shots = (s: SideStats) => s.shots ?? null;
  const onT = (s: SideStats) => s.onTarget ?? null;

  if (v.state === "win") {
    if (deciding && deciding.minute >= 85) {
      const theyPushed = (shots(v.theirs) ?? 0) > (shots(v.mine) ?? 0);
      return `Won it in the ${ordinal(Math.floor(deciding.minute))} minute` +
        (theyPushed ? ` after ${opp} had more of the chances.` : `.`);
    }
    if (v.ht && v.ht.mine < v.ht.theirs) return `Behind at half-time, and still won it.`;
    if (gf - ga >= 3) {
      if (onT(v.theirs) === 0) return `Over long before the end. ${opp} never had a shot on target.`;
      if (v.ht && v.ht.mine - v.ht.theirs >= 2) return `Over by half-time. The second half was a lap of honour.`;
      return `A proper hammering. ${opp} will want to forget this one.`;
    }
    if (ga === 0) return `A clean sheet, and ${opp} hardly got a look in.`;
    return `Won it, without ever making it comfortable.`;
  }

  if (v.state === "draw") {
    const lateLeveller = deciding === null && v.goals.length > 0
      ? v.goals[v.goals.length - 1]
      : null;
    if (lateLeveller && lateLeveller.minute >= 85 && lateLeveller.mine === lateLeveller.theirs) {
      return lateLeveller.ours
        ? `Saved a point in the ${ordinal(Math.floor(lateLeveller.minute))} minute.`
        : `Let it slip in the ${ordinal(Math.floor(lateLeveller.minute))} minute.`;
    }
    if (gf === 0) {
      const total = (onT(v.mine) ?? 0) + (onT(v.theirs) ?? 0);
      return v.mine.onTarget !== undefined && v.theirs.onTarget !== undefined && total <= 4
        ? `Ninety minutes, ${total} shot${total === 1 ? "" : "s"} on target between them.`
        : `No goals, and not much to remember it by.`;
    }
    return `Honours even. Neither side could put it away.`;
  }

  // loss
  const more = (shots(v.mine) ?? 0) - (shots(v.theirs) ?? 0);
  if (more >= 5) return `${v.teamName} had the chances, ${opp} had the goal${ga === 1 ? "" : "s"}.`;
  if (deciding && deciding.minute >= 85) return `Lost it in the ${ordinal(Math.floor(deciding.minute))} minute. Cruel.`;
  if (ga - gf >= 3) return `A night to forget. Best not to replay it this evening.`;
  return `Not their day. ${opp} were the better side.`;
}

/// The goal that decided a game that has a winner: the winning side's goal
/// that put them one ahead for the last time.
function decidingGoal(goals: SideGoal[], gf: number, ga: number): SideGoal | null {
  if (gf === ga) return null;
  const winnerOurs = gf > ga;
  const loserTotal = winnerOurs ? ga : gf;
  return goals.find((g) => g.ours === winnerOurs && (winnerOurs ? g.mine : g.theirs) === loserTotal + 1) ?? null;
}

export interface NumberRow {
  value: string;
  caption: string;
}

/// "Three numbers that matter": three facts, each with a caption that says
/// why it matters. Picked by a fixed priority so the same game always gets
/// the same three; fewer than three is fine when the stats are missing.
export function pickThreeNumbers(v: VerdictInput): NumberRow[] {
  const out: (NumberRow & { rank: number })[] = [];
  const { mine, theirs, teamName: team, opponentName: opp } = v;

  if (theirs.onTarget === 0) {
    out.push({ rank: 10, value: "0", caption: `${opp} shots on target. In the whole game.` });
  } else if (mine.onTarget === 0) {
    out.push({ rank: 10, value: "0", caption: `${team} shots on target. Not one.` });
  }
  if (mine.shots !== undefined && theirs.shots !== undefined) {
    const gap = mine.shots - theirs.shots;
    const caption = gap >= 6
      ? (v.state === "loss" ? `shots. One of those nights.` : `shots. ${team} were all over them.`)
      : gap <= -6
      ? (v.state === "win" ? `shots. ${opp} had more of it, ${team} had the goals.` : `shots. ${opp} were on top.`)
      : `shots. Not much in it.`;
    out.push({ rank: Math.abs(gap) >= 6 ? 8 : 3, value: `${mine.shots}–${theirs.shots}`, caption });
  }
  if (v.ht && Math.abs(v.ht.mine - v.ht.theirs) >= 2) {
    out.push({
      rank: 7,
      value: `${v.ht.mine}–${v.ht.theirs}`,
      caption: v.state === "win" && v.ht.mine > v.ht.theirs
        ? `at half-time. The second half was a formality.`
        : `at half-time.`,
    });
  } else if (v.ht && v.ht.mine < v.ht.theirs && v.state !== "loss") {
    out.push({ rank: 9, value: `${v.ht.mine}–${v.ht.theirs}`, caption: `at half-time. They came from behind.` });
  }
  const deciding = decidingGoal(v.goals, v.teamScore, v.oppScore);
  if (deciding && deciding.minute >= 85) {
    out.push({
      rank: 9,
      value: deciding.shownMinute,
      caption: deciding.ours ? `when the winner went in.` : `when ${opp} won it.`,
    });
  }
  if (v.state === "loss" && mine.xg !== undefined && theirs.xg !== undefined && mine.xg - theirs.xg >= 1) {
    out.push({
      rank: 8,
      value: mine.xg.toFixed(1),
      caption: `expected goals for ${team}. On a normal night, that's ${Math.round(mine.xg)} goals.`,
    });
  }
  if (mine.possession !== undefined) {
    const p = Math.round(mine.possession);
    const caption = p >= 65 && v.state !== "win"
      ? `possession, and nothing to show for it.`
      : p <= 35 && v.state === "win"
      ? `possession. They didn't need the ball.`
      : `possession.`;
    out.push({ rank: p >= 65 || p <= 35 ? 6 : 2, value: `${p}%`, caption });
  }
  if (mine.onTarget !== undefined && theirs.onTarget !== undefined && mine.onTarget > 0 && theirs.onTarget > 0) {
    out.push({ rank: 1, value: `${mine.onTarget}–${theirs.onTarget}`, caption: `shots on target.` });
  }
  return out
    .sort((a, b) => b.rank - a.rank)
    .slice(0, 3)
    .map(({ value, caption }) => ({ value, caption }));
}

export interface ScorerInfo {
  /// players.name; may be abbreviated by the feed ("B. Saka").
  name?: string | null;
  /// The official shirt number (players.number after official-squads).
  number?: number | null;
  /// Season goals, all competitions, as of the last stats sync.
  goals?: number | null;
  /// When that sync ran. Only a sync from before kickoff can be counted on.
  statsUpdatedAt?: string | null;
}

export interface LastMatchGoal {
  /// His side's goal, or theirs. Every goal of the game is on the card, in
  /// the order they went in (Anton, 2026-10-07): "Only Leeds scored" told her
  /// nothing she could repeat.
  ours: boolean;
  team: string;
  player: string;
  api_player_id: number | null;
  number: number | null;
  minute: string;
  score: string; // "2–1 Arsenal": the scoring side's score first, then its name
  line: string;
}

/// Every goal, for the carousel: who, which number, the score it made, and
/// one line about it. Both sides, in time order.
export function renderGoals(
  goals: SideGoal[],
  teamName: string,
  opponentName: string,
  kickoff: string,
  info: Map<number, ScorerInfo>,
): LastMatchGoal[] {
  const seen = new Map<number, number>();
  return goals.map((g) => {
    const i = g.playerApiId !== null ? info.get(g.playerApiId) : undefined;
    const name = g.isOwnGoal ? "Own goal" : (i?.name ?? g.player ?? "Goal");
    let line: string;
    if (g.isOwnGoal) {
      line = g.player ? `${g.player} put it in his own net.` : `Put in by one of theirs.`;
    } else {
      // ponytail: "his Nth" trusts players.goals only when the sync ran before
      // kickoff, so today's goals are not in it yet. A sync during the game
      // would double count, so then there is no count at all. Upgrade: stamp
      // the season tally at kickoff.
      const k = g.playerApiId !== null ? (seen.get(g.playerApiId) ?? 0) + 1 : 1;
      if (g.playerApiId !== null) seen.set(g.playerApiId, k);
      const fresh = i?.statsUpdatedAt && Date.parse(i.statsUpdatedAt) < Date.parse(kickoff);
      const nth = fresh && typeof i?.goals === "number" ? i.goals + k : null;
      const first = nth === 1 ? `His first goal of the season` : nth ? `His ${ordinal(nth)} goal of the season` : null;
      const how = g.isPenalty ? `from the penalty spot` : null;
      line = first ? `${first}${how ? `, ${how}` : ""}.` : how ? `Scored ${how}.` : `${scoreMeaning(g)}`;
    }
    const [forS, againstS] = g.ours ? [g.mine, g.theirs] : [g.theirs, g.mine];
    return {
      ours: g.ours,
      team: g.ours ? teamName : opponentName,
      player: name,
      api_player_id: g.playerApiId,
      number: g.isOwnGoal ? null : (i?.number ?? null),
      minute: g.shownMinute,
      score: `${forS}–${againstS} ${g.ours ? teamName : opponentName}`,
      line,
    };
  });
}

/// What a goal did to the score, from the scoring side, for a scorer with no
/// season count to quote.
function scoreMeaning(g: SideGoal): string {
  const [f, a] = g.ours ? [g.mine, g.theirs] : [g.theirs, g.mine];
  if (f === a) return `The equaliser.`;
  if (f === a + 1 && f === 1) return `The opener.`;
  if (f === a + 1) return `Put them back in front.`;
  if (f < a) return `A goal back.`;
  return `Made it ${f}–${a}.`;
}
