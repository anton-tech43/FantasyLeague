// Live takes (docs/LIVE_TAKES_PLAN.md): match statistics turned into one line
// she can say at 30', half-time, 70' and full time, plus a back-up line for
// when someone pushes back. Pure and deterministic: the rules decide, in code,
// with no model call. Phase 0 only logs what it would say (match-watcher,
// LIVE_TAKES_MODE = "dry_run").
//
// Every rule is one situation from the 2026-10-29 brainstorm and needs at
// least two stats that agree. A missing input means that rule stays silent,
// never a default of 0. Nothing standing out means null, and silence.
//
// Lines are plain pub talk: an opinion about what should happen, never a
// verdict on what the squad can do, no word she could not explain in one
// sentence, at most 60 characters with the club's name in it.

import type { SideGoal, SideStats } from "./last-match.ts";

export type TakeMoment = "30" | "ht" | "70" | "ft";
export type TakeKind =
  | "red_card"
  | "turned_it_round"
  | "stopped_playing"
  | "sitting_back"
  | "done_all_but_score"
  | "their_keeper"
  | "our_keeper"
  | "one_way_traffic"
  | "riding_luck"
  | "second_best"
  | "all_ball_behind"
  | "all_ball_no_bite"
  | "shooting_blanks"
  | "deserved_more"
  | "wasted_corners"
  | "scrap";

export interface Take {
  kind: TakeKind;
  line: string;
  backup: string;
}

// ─── Thresholds ────────────────────────────────────────────────────────────
// Counts are per 90 minutes and scaled to the moment (MINUTES), so "15 shots"
// is 5 at 30' and 7.5 at half-time. Possession is a percent.
export const MINUTES: Record<TakeMoment, number> = { "30": 30, ht: 45, "70": 70, ft: 90 };
export const BALL = 60; // "all the ball"
export const LITTLE_BALL = 42; // "barely got out of their own half"
export const SECOND_HALF_LOW_BALL = 35; // sitting back since the break
export const SECOND_HALF_BALL = 58; // one-way traffic since the break
export const SHOT_GAP_90 = 9; // more shots than the other side
export const SHOTS_90 = 15; // a side that is shooting a lot
export const FEW_ON_TARGET_90 = 4; // "not hurting them"
export const POOR_AIM = 0.25; // on target / shots at or below this
export const ON_TARGET_GAP_90 = 4; // more shots on target than the other side
export const KEEPER_SAVES_90 = 5; // a keeper having a busy day (4 by 70')...
export const KEEPER_SAVES_MIN = 4; // ...but never fewer than this
export const CORNERS_90 = 9;
export const CORNERS_MIN = 5;
export const FOULS_90 = 26; // both sides together
export const YELLOWS_90 = 7; // both sides together
export const YELLOWS_MIN = 3;
export const LATE_GOAL_MINUTE = 80;
export const MAX_LINE = 60;

/// Words she could not explain in one sentence, or numbers dressed as words.
export const BANNED = [
  "xg", "expected", "low block", "high line", "possession", "%", "stats", "statistic",
  "clinical", "underlying", "metrics", "transition", "–", "—",
];

export interface TakeSide {
  name: string;
  stats: SideStats;
}

export interface TakeScore {
  mine: number;
  theirs: number;
  /// Half-time score, ours first. Needed for "turned it round".
  ht?: { mine: number; theirs: number } | null;
  /// Every goal in order (sideGoals), full time only. Needed for "stopped
  /// playing after the goal".
  goals?: readonly SideGoal[] | null;
}

interface Ctx {
  moment: TakeMoment;
  m: SideStats;
  t: SideStats;
  s: TakeScore;
  lead: number;
  /// Stats since half-time; undefined when there is no half-time snapshot or
  /// a number is missing from either end.
  m2: SideStats;
  t2: SideStats;
  per: (per90: number) => number;
}

interface Rule {
  kind: TakeKind;
  moments: TakeMoment[];
  when: (c: Ctx) => boolean;
  /// Lines for 30', HT and 70' (present tense) and for full time (past).
  live?: string[];
  ft?: string[];
  backup: string[];
  ftBackup?: string[];
}

const def = (...v: (number | undefined)[]): boolean => v.every((x) => typeof x === "number" && Number.isFinite(x));

/// Second-half share of the ball from two cumulative readings, assuming the
/// moment's nominal minute. Undefined when either reading is missing.
function possessionSince(now: number | undefined, atHt: number | undefined, minute: number): number | undefined {
  if (!def(now, atHt) || minute <= 45) return undefined;
  return Math.max(0, Math.min(100, (now! * minute - atHt! * 45) / (minute - 45)));
}

function since(now: SideStats, atHt: SideStats | undefined, minute: number): SideStats {
  if (!atHt) return {};
  const out: SideStats = {};
  for (const k of ["shots", "onTarget", "corners", "fouls", "yellow", "red", "saves"] as const) {
    if (def(now[k], atHt[k]) && now[k]! >= atHt[k]!) out[k] = now[k]! - atHt[k]!;
  }
  const p = possessionSince(now.possession, atHt.possession, minute);
  if (p !== undefined) out.possession = p;
  return out;
}

const RULES: Rule[] = [
  // 9. A red card changes the game: they are down to ten and we have the
  // ball and the shots.
  {
    kind: "red_card",
    moments: ["ht", "70", "ft"],
    when: ({ m, t, per }) =>
      def(t.red, m.red, m.possession, m.shots, t.shots) &&
      t.red! >= 1 && m.red === 0 && m.possession! >= BALL && m.shots! - t.shots! >= per(SHOT_GAP_90),
    live: ["The red card's changed everything for {team}.", "{team} need to make the extra man count now."],
    ft: ["The red card changed the whole game.", "After the red card it was all {team}."],
    backup: ["Eleven against ten. They have to make that count.", "They need to move the ball quicker and use the space."],
    ftBackup: ["Once they had the extra man it was one-way traffic."],
  },
  // 4. Behind at half-time, ahead now, and nearly every shot since the break.
  {
    kind: "turned_it_round",
    moments: ["70", "ft"],
    when: ({ s, lead, m2, t2, moment }) =>
      !!s.ht && s.ht.mine < s.ht.theirs && lead > 0 && def(m2.shots, t2.shots) &&
      m2.shots! >= (moment === "ft" ? 6 : 4) && m2.shots! >= 2 * Math.max(t2.shots!, 1),
    live: ["Completely different {team} since half-time.", "It's a different {team} since the break."],
    ft: ["Completely different {team} in the second half.", "{team} were a different side after the break."],
    backup: ["They were so much braver going forward after the break.", "They've had nearly all the shots since half-time."],
    ftBackup: ["They were so much braver going forward after the break.", "They had nearly all the shots after half-time."],
  },
  // 10. Led, then sat back and conceded late.
  {
    kind: "stopped_playing",
    moments: ["ft"],
    when: ({ s, lead, m2, t2 }) => {
      const last = s.goals && s.goals.length > 0 ? s.goals[s.goals.length - 1] : null;
      return !!last && !last.ours && last.minute >= LATE_GOAL_MINUTE && last.mine >= last.theirs && lead <= 0 &&
        def(m2.shots, t2.shots, m2.possession) && t2.shots! - m2.shots! >= 4 && m2.possession! <= 40;
    },
    ft: ["{team} sat back and got punished for it.", "{team} dropped too deep and paid for it."],
    backup: ["They sat too deep for the last twenty minutes.", "They stopped playing after the goal. Never works."],
  },
  // 5. Defending a lead deep since the break.
  {
    kind: "sitting_back",
    moments: ["70"],
    when: ({ lead, m2, t2 }) =>
      lead >= 1 && def(m2.possession, m2.shots, t2.shots) &&
      m2.possession! <= SECOND_HALF_LOW_BALL && t2.shots! - m2.shots! >= 3,
    live: ["{team} are just sitting back now. Nervy finish.", "{team} have dropped deep. This could get nervy."],
    backup: ["They need to keep the ball and take the pressure off.", "They need to get out and keep the ball for a bit."],
  },
  // The Arsenal-Brighton 70': not one shot from them since the break.
  {
    kind: "one_way_traffic",
    moments: ["70", "ft"],
    when: ({ m2, t2, moment }) =>
      def(m2.shots, t2.shots, m2.possession) &&
      t2.shots === 0 && m2.shots! >= (moment === "ft" ? 8 : 5) && m2.possession! >= SECOND_HALF_BALL,
    live: ["{opp} haven't had a shot since half-time.", "It's been all {team} since half-time."],
    ft: ["{opp} didn't have a shot after the break.", "It was all {team} after half-time."],
    backup: ["{opp} are just camped in their own box.", "One-way traffic. {team} need to keep at it."],
    ftBackup: ["{opp} sat in their own box all second half."],
  },
  // The Arsenal-Brighton half-time: they scored with almost nothing, we have
  // had all the shots.
  {
    kind: "done_all_but_score",
    moments: ["ht", "70", "ft"],
    when: ({ s, lead, m, t, per }) =>
      s.theirs >= 1 && lead <= 0 && def(t.onTarget, m.shots, t.shots) &&
      t.onTarget! <= Math.min(3, s.theirs + 1) && m.shots! - t.shots! >= per(SHOT_GAP_90) && m.shots! >= 2 * t.shots!,
    live: ["{team} have done everything but finish.", "{team} are all over them. It just won't go in."],
    ft: ["{team} did everything but finish.", "{team} had the chances. It just wouldn't go in."],
    backup: ["Keep going like that and the goal will come.", "{opp} have hardly had a shot. That's football."],
    ftBackup: ["{opp} hardly had a shot. That's football.", "{shots} shots to {theirShots}. Some days it just won't go in."],
  },
  // 6, the other way round. Their keeper keeping it close.
  {
    kind: "their_keeper",
    moments: ["ht", "70", "ft"],
    when: ({ lead, m, t, per }) =>
      lead <= 1 && def(t.saves, m.onTarget, t.onTarget, m.shots, t.shots) &&
      t.saves! >= Math.max(KEEPER_SAVES_MIN, per(KEEPER_SAVES_90)) &&
      (m.shots! - t.shots! >= per(SHOT_GAP_90) / 2 || m.onTarget! - t.onTarget! >= per(ON_TARGET_GAP_90)),
    live: ["The {opp} keeper is keeping them in this.", "The {opp} keeper is having a blinder."],
    ft: ["The {opp} keeper was man of the match.", "Without the {opp} keeper, it wasn't close."],
    backup: ["{saves} saves already. They need to keep testing him."],
    ftBackup: ["{saves} saves. Without him it's a different result."],
  },
  // 6. Our keeper is the only reason it is still level (or still ours).
  {
    kind: "our_keeper",
    moments: ["30", "ht", "70", "ft"],
    when: ({ lead, m, t, per }) =>
      lead >= 0 && def(m.saves, m.onTarget, t.onTarget, m.shots, t.shots) &&
      m.saves! >= Math.max(KEEPER_SAVES_MIN, per(KEEPER_SAVES_90)) &&
      (t.shots! - m.shots! >= per(SHOT_GAP_90) / 2 || t.onTarget! - m.onTarget! >= per(ON_TARGET_GAP_90)),
    live: ["The {team} keeper is keeping them in this.", "The {team} keeper is having a blinder."],
    ft: ["The {team} keeper was man of the match.", "The {team} keeper saved them today."],
    backup: ["{saves} saves already. He's having a blinder.", "They need to keep the ball more and give him a rest."],
    ftBackup: ["{saves} saves. Without him it's a different result."],
  },
  // 3. Winning but riding their luck.
  {
    kind: "riding_luck",
    moments: ["ht", "70", "ft"],
    when: ({ lead, m, t, per }) =>
      lead >= 1 && def(m.shots, t.shots, m.onTarget, t.onTarget) &&
      t.shots! - m.shots! >= per(SHOT_GAP_90) && t.onTarget! >= m.onTarget! + 2,
    live: ["{team} are winning, but riding their luck.", "{team} are ahead, but it's backs to the wall."],
    ft: ["{team} won it, but they rode their luck.", "{team} got away with one there."],
    backup: ["They've been under the cosh. They need to keep the ball.", "{theirShots} shots against them. They need the ball more."],
    ftBackup: ["{theirShots} shots against. Could've gone either way.", "They were under the cosh for most of it."],
  },
  // 2. Behind and outplayed.
  {
    kind: "second_best",
    moments: ["ht", "70", "ft"],
    when: ({ lead, m, t, per }) =>
      lead < 0 && def(m.shots, t.shots, m.possession) &&
      t.shots! - m.shots! >= per(SHOT_GAP_90) && m.possession! <= LITTLE_BALL,
    live: ["Honestly, {team} have been second best.", "{team} have been second best. No complaints."],
    ft: ["Honestly, {team} were second best all game.", "No complaints. {team} were second best today."],
    backup: ["They've barely got out of their own half.", "They need to keep the ball better and get up the pitch."],
    ftBackup: ["They barely got out of their own half.", "{theirShots} shots against. It could've been worse."],
  },
  // 1. Most of the ball and behind.
  {
    kind: "all_ball_behind",
    moments: ["ht", "70", "ft"],
    when: ({ lead, m, per }) =>
      lead < 0 && def(m.possession, m.onTarget) && m.possession! >= BALL && m.onTarget! <= per(FEW_ON_TARGET_90),
    live: ["{team} have had all the ball and done nothing.", "{team} have the ball and nothing to show."],
    ft: ["{team} had all the ball and did nothing.", "{team} barely made the keeper work."],
    backup: ["{onTarget} shots on target. That's not enough.", "They need someone to shoot from the edge of the box more."],
    ftBackup: ["{onTarget} shots on target all game. That's not enough."],
  },
  // The Arsenal-Brighton 30': all the ball, plenty of shots, nothing on target.
  {
    kind: "all_ball_no_bite",
    moments: ["30", "ht", "70"],
    when: ({ lead, m, t, per }) =>
      lead === 0 && def(m.possession, m.shots, m.onTarget, t.shots) &&
      m.possession! >= BALL && m.shots! >= per(SHOTS_90) && m.shots! > t.shots! &&
      m.onTarget! <= m.shots! * POOR_AIM,
    live: ["{team} have the ball but aren't hurting anyone.", "{team} have the ball, but no real chances."],
    backup: ["{shots} shots and the keeper's barely had to move.", "They need someone to shoot from the edge of the box more."],
  },
  // Newcastle v Everton, 70' (2026-11-02): thirteen shots, none on target,
  // without needing the ball. Anton: "skjuter mycket men träffar inte målet".
  {
    kind: "shooting_blanks",
    moments: ["ht", "70", "ft"],
    when: ({ lead, m, per }) =>
      lead <= 0 && def(m.shots, m.onTarget) &&
      m.shots! >= per(SHOTS_90) && m.onTarget! <= 1,
    live: ["{team} keep shooting but can't hit the target.", "Loads of {team} shots, hardly any on target."],
    ft: ["{team} kept shooting but missed the target.", "So many {team} shots, hardly any on target."],
    backup: ["{shots} shots and the keeper's barely had to move.", "They need to take a touch and pick their spot."],
    ftBackup: ["{shots} shots and the keeper barely had to move."],
  },
  // The Arsenal-Brighton full time: won, and should have won by more.
  {
    kind: "deserved_more",
    moments: ["ft"],
    when: ({ lead, m, t }) =>
      lead >= 1 && lead <= 2 && def(m.shots, t.shots, m.onTarget, t.onTarget) &&
      m.shots! - t.shots! >= 10 && m.shots! >= 2 * t.shots! && m.onTarget! - t.onTarget! >= 4,
    ft: ["Deserved. On chances it should've been three or four.", "{team} deserved that. Should've been more."],
    backup: ["{shots} shots to {theirShots}. It was one-way traffic."],
  },
  // 7. Corner after corner, nothing from them.
  {
    kind: "wasted_corners",
    moments: ["ht", "70", "ft"],
    when: ({ lead, m, per }) =>
      lead <= 0 && def(m.corners, m.onTarget) &&
      m.corners! >= Math.max(CORNERS_MIN, per(CORNERS_90)) && m.onTarget! <= per(FEW_ON_TARGET_90),
    live: ["All those {team} corners. Nothing from them.", "{team} have had loads of corners, all wasted."],
    ft: ["All those {team} corners. Nothing from them.", "Corner after corner for {team}, and nothing."],
    backup: ["They need to mix it up, try something short."],
    ftBackup: ["They needed to mix it up, try something short."],
  },
  // 8. A scrap: fouls and cards, both sides together.
  {
    kind: "scrap",
    moments: ["30", "ht", "70", "ft"],
    when: ({ m, t, per }) =>
      def(m.fouls, t.fouls, m.yellow, t.yellow) &&
      m.fouls! + t.fouls! >= per(FOULS_90) && m.yellow! + t.yellow! >= Math.max(YELLOWS_MIN, per(YELLOWS_90)),
    live: ["This has turned into a scrap. Nobody's playing football.", "It's a scrap. Barely any football being played."],
    ft: ["That was a scrap. Hardly any football in it.", "More fouls than football in that one."],
    backup: ["There's a foul every couple of minutes. It never gets going."],
    ftBackup: ["A foul every couple of minutes. It never got going."],
  },
];

const WORDS = [
  "no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
];
const say = (n: number | undefined): string => n === undefined ? "" : (WORDS[n] ?? String(n));

function render(tpl: string, team: string, opp: string, m: SideStats, t: SideStats): string {
  const out = tpl
    .replaceAll("{team}", team)
    .replaceAll("{opp}", opp)
    .replaceAll("{shots}", say(m.shots))
    .replaceAll("{theirShots}", say(t.shots))
    .replaceAll("{onTarget}", say(m.onTarget))
    .replaceAll("{saves}", say(m.saves ?? t.saves))
    .replace(/\b([Oo]ne) shots\b/g, "$1 shot");
  return out.charAt(0).toUpperCase() + out.slice(1);
}

/// Every template, for the tests (length, banned words).
export const ALL_TEMPLATES: string[] = RULES.flatMap((r) => [
  ...(r.live ?? []), ...(r.ft ?? []), ...r.backup, ...(r.ftBackup ?? []),
]);

/// The take for one side at one moment, or null for silence. `htSnapshot` is
/// the half-time statistics (ours, theirs), for the "since half-time" rules.
export function decideTake(
  moment: TakeMoment,
  mine: TakeSide,
  theirs: TakeSide,
  score: TakeScore,
  htSnapshot?: { mine: SideStats; theirs: SideStats } | null,
  rng: () => number = () => 0,
): Take | null {
  const minute = MINUTES[moment];
  const c: Ctx = {
    moment,
    m: mine.stats,
    t: theirs.stats,
    s: score,
    lead: score.mine - score.theirs,
    m2: since(mine.stats, htSnapshot?.mine, minute),
    t2: since(theirs.stats, htSnapshot?.theirs, minute),
    per: (per90) => per90 * minute / 90,
  };
  for (const r of RULES) {
    if (!r.moments.includes(moment) || !r.when(c)) continue;
    const lines = moment === "ft" ? r.ft : r.live;
    const backups = moment === "ft" ? (r.ftBackup ?? r.backup) : r.backup;
    if (!lines) continue;
    // In the backup, {saves} is the keeper the line is about.
    const [bm, bt] = r.kind === "their_keeper" ? [{ ...c.m, saves: c.t.saves }, c.t] : [c.m, c.t];
    const fit = (list: string[], a: SideStats, b: SideStats) =>
      list.map((l) => render(l, mine.name, theirs.name, a, b)).filter((l) => l.length <= MAX_LINE);
    const ls = fit(lines, c.m, c.t);
    const bs = fit(backups, bm, bt);
    if (ls.length === 0 || bs.length === 0) continue;
    return { kind: r.kind, line: ls[Math.floor(rng() * ls.length)], backup: bs[Math.floor(rng() * bs.length)] };
  }
  return null;
}

/// Why a moment was silent, for the dry-run log.
export function silenceReason(mine: SideStats, theirs: SideStats): string {
  const core = ["shots", "onTarget", "possession"] as const;
  const missing = core.filter((k) => mine[k] === undefined || theirs[k] === undefined);
  if (Object.keys(mine).length === 0 && Object.keys(theirs).length === 0) return "no stats";
  return missing.length > 0 ? `missing ${missing.join(", ")}` : "nothing stands out";
}

/// match_status_state.briefs_fired marker for a moment.
export const takeMarker = (m: TakeMoment): string => `TAKE_${m.toUpperCase()}`;

/// Which take moment this tick is, or null. Windows are 30'-36' in 1H and
/// 70'-76' in 2H, half-time on the observed 1H→HT change, full time on the
/// observed 2H→FT change (never after extra time or penalties). A first
/// observation (no prior status) is never a moment, and a missed window is
/// skipped, not caught up.
export function takeMomentFor(
  status: string,
  elapsed: number | null | undefined,
  priorStatus: string | null | undefined,
  fired: readonly string[],
): TakeMoment | null {
  if (!priorStatus) return null;
  const inWindow = (from: number) => typeof elapsed === "number" && elapsed >= from && elapsed <= from + 6;
  const m: TakeMoment | null = status === "1H" && priorStatus === "1H" && inWindow(30)
    ? "30"
    : status === "HT" && priorStatus === "1H"
    ? "ht"
    : status === "2H" && priorStatus === "2H" && inWindow(70)
    ? "70"
    : status === "FT" && priorStatus === "2H"
    ? "ft"
    : null;
  return m && !fired.includes(takeMarker(m)) ? m : null;
}
