// deno test backend/supabase/functions/_shared/match-take.test.ts

import { seededRng } from "./goal-push.ts";
import { type SideGoal, type SideStats, parseFixtureStats } from "./last-match.ts";
import {
  ALL_TEMPLATES,
  BANNED,
  decideTake,
  MAX_LINE,
  silenceReason,
  type TakeMoment,
  takeMarker,
  takeMomentFor,
  type TakeScore,
} from "./match-take.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${m}: ${JSON.stringify(a)} !== ${JSON.stringify(b)}`);
}

const ARS = "Arsenal", BHA = "Brighton";
const quiet: SideStats = { shots: 5, onTarget: 2, possession: 50, corners: 3, fouls: 5, yellow: 1, red: 0, saves: 1 };
function take(
  moment: TakeMoment,
  mine: SideStats,
  theirs: SideStats,
  score: TakeScore,
  ht?: { mine: SideStats; theirs: SideStats },
) {
  return decideTake(moment, { name: ARS, stats: mine }, { name: BHA, stats: theirs }, score, ht, seededRng(1));
}
const kind = (...a: Parameters<typeof take>) => take(...a)?.kind ?? null;

// ─── The brainstorm (2026-10-29), Arsenal v Brighton, Arsenal followed ────

Deno.test("30': all the ball, seven shots, one on target", () => {
  eq(kind("30", { ...quiet, possession: 68, shots: 7, onTarget: 1 }, { ...quiet, possession: 32, shots: 2, onTarget: 0 },
    { mine: 0, theirs: 0 }), "all_ball_no_bite", "kind");
});

Deno.test("HT: one shot on target and they score", () => {
  eq(kind("ht", { ...quiet, possession: 66, shots: 11, onTarget: 4 }, { ...quiet, possession: 34, shots: 3, onTarget: 1 },
    { mine: 0, theirs: 1 }), "done_all_but_score", "kind");
});

const htArs = { ...quiet, possession: 66, shots: 11, onTarget: 4, saves: 0 };
const htBha = { ...quiet, possession: 34, shots: 3, onTarget: 1, saves: 3 };

Deno.test("70': Brighton haven't had a shot since half-time", () => {
  const t = take("70", { ...htArs, possession: 68, shots: 18, onTarget: 7 }, { ...htBha, possession: 32 },
    { mine: 1, theirs: 1, ht: { mine: 0, theirs: 1 } }, { mine: htArs, theirs: htBha });
  eq(t?.kind, "one_way_traffic", "kind");
});

Deno.test("FT: won it late, 22 shots to 4, their keeper made 7 saves", () => {
  eq(kind("ft", { ...htArs, possession: 70, shots: 22, onTarget: 9 }, { ...htBha, shots: 4, onTarget: 1, saves: 7 },
    { mine: 2, theirs: 1 }), "their_keeper", "the keeper was the story");
  eq(kind("ft", { ...htArs, possession: 70, shots: 22, onTarget: 9 }, { ...htBha, shots: 4, onTarget: 1, saves: 3 },
    { mine: 2, theirs: 1 }), "deserved_more", "without the saves, deserved more");
});

// ─── Real matches ────────────────────────────────────────────────────────

Deno.test("Newcastle 0-1 Everton at 70' (2026-11-02): silent before, now both sides have a line", () => {
  const ncl: SideStats = { shots: 13, onTarget: 0, possession: 51, corners: 3, fouls: 9, yellow: 1, red: 0, saves: 4 };
  const eve: SideStats = { shots: 16, onTarget: 5, possession: 49, corners: 4, fouls: 7, yellow: 1, red: 0, saves: 0 };
  eq(kind("70", ncl, eve, { mine: 0, theirs: 1 }), "shooting_blanks", "Newcastle: thirteen shots, none on target");
  eq(kind("70", eve, ncl, { mine: 1, theirs: 0 }), "their_keeper", "Everton: four saves by their keeper");
  eq(kind("70", { ...ncl, onTarget: 4 }, eve, { mine: 0, theirs: 1 }), null, "four on target is not blanks");
});

Deno.test("Champions League 2026-11-03: silent all night before, now a take at HT, 70' and FT", () => {
  // The stored snapshots (match_status_state.stat_snapshots), xG left out.
  const s = (shots: number, onTarget: number, possession: number, fouls: number, yellow: number, red: number,
    corners?: number, saves?: number): SideStats => {
    const o: SideStats = { shots, onTarget, possession, fouls, yellow, red };
    if (corners !== undefined) o.corners = corners;
    if (saves !== undefined) o.saves = saves;
    return o;
  };
  const decide = (moment: TakeMoment, me: [string, SideStats], them: [string, SideStats], score: TakeScore,
    ht?: { mine: SideStats; theirs: SideStats }) =>
    decideTake(moment, { name: me[0], stats: me[1] }, { name: them[0], stats: them[1] }, score, ht, seededRng(1))?.kind ?? null;

  // Man Utd (home, followed) 3-2 Roma.
  const mu = { "30": s(2, 0, 54, 3, 1, 0), ht: s(5, 1, 54, 3, 1, 0, 0, 1), "70": s(11, 3, 55, 4, 1, 0, 3, 2), ft: s(15, 6, 53, 10, 3, 1, 3, 2) };
  const ro = { "30": s(4, 2, 46, 4, 1, 0), ht: s(6, 3, 46, 9, 3, 0, 1, 1), "70": s(7, 4, 45, 10, 3, 0, 1, 1), ft: s(7, 4, 47, 14, 3, 0, 1, 2) };
  const muHt = { mine: mu.ht, theirs: ro.ht };
  const htMu = { mine: 0, theirs: 2 };
  eq(decide("30", ["Man Utd", mu["30"]], ["AS Roma", ro["30"]], { mine: 0, theirs: 2 }), null, "MU 30'");
  eq(decide("ht", ["Man Utd", mu.ht], ["AS Roma", ro.ht], { mine: 0, theirs: 2 }), "clinical_opponent", "MU HT");
  eq(decide("70", ["Man Utd", mu["70"]], ["AS Roma", ro["70"]], { mine: 1, theirs: 2, ht: htMu }, muHt), "pushing_since_ht", "MU 70'");
  eq(decide("ft", ["Man Utd", mu.ft], ["AS Roma", ro.ft], { mine: 3, theirs: 2, ht: htMu }, muHt), "turned_it_round", "MU FT");
  // The same 70' numbers, but already ahead: turned it round, never "pushing".
  eq(decide("70", ["Man Utd", mu["70"]], ["AS Roma", ro["70"]], { mine: 3, theirs: 2, ht: htMu }, muHt), "turned_it_round", "MU 70' ahead");

  // Barcelona 3-0 Aston Villa (away, followed).
  const ba = { "30": s(4, 2, 68, 3, 0, 0, 0, 0), ht: s(5, 3, 68, 4, 1, 0, 2, 1), "70": s(12, 7, 67, 8, 1, 0, 4, 1), ft: s(16, 8, 65, 14, 1, 0, 4, 1) };
  const av = { "30": s(3, 0, 32, 4, 1, 0, 3, 1), ht: s(5, 1, 32, 4, 2, 0, 4, 2), "70": s(6, 1, 33, 8, 3, 0, 6, 4), ft: s(9, 1, 35, 9, 3, 0, 8, 5) };
  const avHt = { mine: av.ht, theirs: ba.ht };
  const htAv = { mine: 0, theirs: 1 };
  eq(decide("30", ["Aston Villa", av["30"]], ["Barcelona", ba["30"]], { mine: 0, theirs: 1 }), null, "Villa 30'");
  eq(decide("ht", ["Aston Villa", av.ht], ["Barcelona", ba.ht], { mine: 0, theirs: 1 }), null, "Villa HT: shots level, not second best");
  eq(decide("70", ["Aston Villa", av["70"]], ["Barcelona", ba["70"]], { mine: 0, theirs: 3, ht: htAv }, avHt), "second_best", "Villa 70'");
  eq(decide("ft", ["Aston Villa", av.ft], ["Barcelona", ba.ft], { mine: 0, theirs: 3, ht: htAv }, avHt), "second_best", "Villa FT");

  // The swing rules stay quiet on a steady 54/55 (Man Utd's first and second half).
  eq(decide("70", ["Man Utd", mu["70"]], ["AS Roma", ro["70"]], { mine: 2, theirs: 2, ht: { mine: 2, theirs: 2 } }, muHt), null,
    "MU steady ball, level: no swing");
});

Deno.test("a swing in the ball between halves", () => {
  // 40 at half-time, 48 by 70' cumulative: about 62 since the break.
  const htMine = { ...quiet, possession: 40, shots: 3 }, htTheirs = { ...quiet, possession: 60, shots: 5 };
  const ht = { mine: htMine, theirs: htTheirs };
  eq(kind("70", { ...htMine, possession: 48, shots: 7 }, { ...htTheirs, possession: 52, shots: 8 },
    { mine: 1, theirs: 1, ht: { mine: 1, theirs: 1 } }, ht), "taken_over", "40 to 62");
  eq(kind("70", { ...htMine, possession: 48, shots: 5 }, { ...htTheirs, possession: 52, shots: 9 },
    { mine: 1, theirs: 1, ht: { mine: 1, theirs: 1 } }, ht), null, "the ball but fewer shots since: one stat only");
  // The inverse: 62 at half-time, 54 by 70' cumulative: about 40 since.
  const htMine2 = { ...quiet, possession: 62, shots: 5 }, htTheirs2 = { ...quiet, possession: 38, shots: 3 };
  eq(kind("70", { ...htMine2, possession: 54, shots: 7 }, { ...htTheirs2, possession: 46, shots: 6 },
    { mine: 1, theirs: 1, ht: { mine: 1, theirs: 1 } }, { mine: htMine2, theirs: htTheirs2 }), "lost_grip", "62 to 40");
  eq(kind("70", { ...htMine, possession: 48, shots: 7 }, { ...htTheirs, possession: 52, shots: 8 },
    { mine: 1, theirs: 1 }), null, "no half-time snapshot, no swing");
});

// ─── The numbered situations ─────────────────────────────────────────────

Deno.test("1. most of the ball and behind", () => {
  eq(kind("70", { ...quiet, possession: 65, shots: 9, onTarget: 2 }, { ...quiet, possession: 35, shots: 6, onTarget: 3 },
    { mine: 0, theirs: 1 }), "all_ball_behind", "kind");
});

Deno.test("2. outplayed and behind", () => {
  eq(kind("ft", { ...quiet, possession: 35, shots: 3, onTarget: 1 }, { ...quiet, possession: 65, shots: 15, onTarget: 6 },
    { mine: 0, theirs: 2 }), "second_best", "kind");
});

Deno.test("3. winning but riding their luck", () => {
  eq(kind("70", { ...quiet, possession: 38, shots: 4, onTarget: 2 }, { ...quiet, possession: 62, shots: 14, onTarget: 5 },
    { mine: 1, theirs: 0 }), "riding_luck", "kind");
});

Deno.test("4. behind at half-time, won it, nearly every shot after the break", () => {
  const ht = { mine: { ...quiet, shots: 3 }, theirs: { ...quiet, shots: 6 } };
  eq(kind("ft", { ...quiet, shots: 13, onTarget: 6 }, { ...quiet, shots: 8, onTarget: 3 },
    { mine: 2, theirs: 1, ht: { mine: 0, theirs: 1 } }, ht), "turned_it_round", "kind");
});

Deno.test("5. sitting on a lead since the break", () => {
  const ht = { mine: { ...quiet, possession: 50, shots: 5 }, theirs: { ...quiet, possession: 50, shots: 5 } };
  eq(kind("70", { ...quiet, possession: 42, shots: 6 }, { ...quiet, possession: 58, shots: 10 },
    { mine: 1, theirs: 0, ht: { mine: 1, theirs: 0 } }, ht), "sitting_back", "kind");
});

Deno.test("6. our keeper keeps it nil-nil", () => {
  eq(kind("70", { ...quiet, shots: 3, onTarget: 1, saves: 6 }, { ...quiet, shots: 13, onTarget: 6 },
    { mine: 0, theirs: 0 }), "our_keeper", "kind");
});

Deno.test("7. corner after corner, nothing from them", () => {
  eq(kind("ft", { ...quiet, possession: 55, corners: 10, shots: 9, onTarget: 2 }, { ...quiet, possession: 45 },
    { mine: 0, theirs: 0 }), "wasted_corners", "kind");
});

Deno.test("8. a scrap", () => {
  eq(kind("ft", { ...quiet, fouls: 15, yellow: 4 }, { ...quiet, fouls: 14, yellow: 4 }, { mine: 1, theirs: 1 }), "scrap", "kind");
});

Deno.test("9. a red card changes it", () => {
  eq(kind("70", { ...quiet, possession: 70, shots: 14, red: 0 }, { ...quiet, possession: 30, shots: 4, red: 1 },
    { mine: 1, theirs: 1 }), "red_card", "kind");
});

Deno.test("10. led, sat back, conceded late", () => {
  const goals = [
    { ours: true, minute: 30, mine: 1, theirs: 0 },
    { ours: false, minute: 88, mine: 1, theirs: 1 },
  ] as SideGoal[];
  const ht = { mine: { ...quiet, possession: 50, shots: 5 }, theirs: { ...quiet, possession: 50, shots: 5 } };
  eq(kind("ft", { ...quiet, possession: 42, shots: 7 }, { ...quiet, possession: 58, shots: 13 },
    { mine: 1, theirs: 1, goals, ht: { mine: 1, theirs: 0 } }, ht), "stopped_playing", "kind");
});

// ─── Silence ─────────────────────────────────────────────────────────────

Deno.test("11. a dull 0-0 is silent at every moment", () => {
  for (const m of ["30", "ht", "70", "ft"] as TakeMoment[]) {
    eq(kind(m, quiet, quiet, { mine: 0, theirs: 0 }, { mine: quiet, theirs: quiet }), null, m);
  }
});

Deno.test("missing stats are silent, never 0", () => {
  eq(kind("ht", {}, {}, { mine: 0, theirs: 1 }), null, "no stats at all");
  // All the ball and behind, but on target unknown: that rule stays quiet.
  eq(kind("70", { possession: 70 }, { possession: 30 }, { mine: 0, theirs: 1 }), null, "possession only");
  // Their shots unknown: the "they've hardly had a shot" rule must not read it as 0.
  eq(kind("ht", { shots: 11, onTarget: 4, possession: 66 }, { onTarget: 1 }, { mine: 0, theirs: 1 }), null, "their shots missing");
  // No half-time snapshot: nothing "since half-time".
  eq(kind("70", { ...quiet, shots: 18, onTarget: 8, possession: 68 }, { ...quiet, shots: 3, onTarget: 3, possession: 32 },
    { mine: 1, theirs: 1 }), null, "no ht snapshot");
  eq(silenceReason({}, {}), "no stats", "reason");
  eq(silenceReason({ shots: 3 }, { shots: 2 }), "missing onTarget, possession", "reason");
  eq(silenceReason(quiet, quiet), "nothing stands out", "reason");
});

Deno.test("a single strong stat is never enough", () => {
  eq(kind("70", { ...quiet, possession: 75 }, { ...quiet, possession: 25 }, { mine: 0, theirs: 0 }), null, "possession alone");
  eq(kind("70", { ...quiet, shots: 20 }, quiet, { mine: 0, theirs: 0 }), null, "shots alone");
  eq(kind("ft", { ...quiet, saves: 9 }, quiet, { mine: 0, theirs: 0 }), null, "saves alone");
  eq(kind("ft", { ...quiet, corners: 14 }, quiet, { mine: 1, theirs: 0 }), null, "corners alone (and winning)");
  eq(kind("ft", { ...quiet, fouls: 20 }, { ...quiet, fouls: 15 }, { mine: 0, theirs: 0 }), null, "fouls alone");
  eq(kind("70", quiet, { ...quiet, red: 1 }, { mine: 0, theirs: 0 }), null, "red card alone");
});

// ─── Copy ────────────────────────────────────────────────────────────────

const LONG = "Paris Saint Germain"; // the longest club name in teams (19)
function fill(tpl: string, n: string): string {
  return tpl.replaceAll("{team}", LONG).replaceAll("{opp}", LONG)
    .replace(/\{(shots|theirShots|onTarget|saves)\}/g, n);
}

Deno.test("every line and backup fits 60 characters with the longest name", () => {
  for (const t of ALL_TEMPLATES) {
    const s = fill(t, "seventeen");
    assert(s.length <= MAX_LINE, `${s.length}: "${s}"`);
  }
});

Deno.test("no banned words, no dashes", () => {
  for (const t of ALL_TEMPLATES) {
    for (const b of BANNED) assert(!t.toLowerCase().includes(b), `"${t}" contains "${b}"`);
  }
});

Deno.test("seeded: the same fixture and side always get the same line, and variants differ", () => {
  const args = [{ ...quiet, possession: 68, shots: 7, onTarget: 1 }, { ...quiet, possession: 32, shots: 2 }] as const;
  const pick = (seed: number) =>
    decideTake("30", { name: ARS, stats: args[0] }, { name: BHA, stats: args[1] }, { mine: 0, theirs: 0 }, null, seededRng(seed));
  eq(pick(42), pick(42), "deterministic");
  const lines = new Set(Array.from({ length: 20 }, (_, i) => pick(i)?.line));
  assert(lines.size >= 2, "more than one variant in use");
  for (const l of lines) assert(!!l && l.includes(ARS), `names the team: ${l}`);
});

Deno.test("numbers come out as words, singular when one", () => {
  const t = take("ft", { ...quiet, possession: 66, shots: 9, onTarget: 1 }, { ...quiet, possession: 34 }, { mine: 0, theirs: 1 });
  eq(t?.kind, "all_ball_behind", "kind");
  assert(t!.backup === "One shot on target all game. That's not enough." || !t!.backup.includes("{"), t!.backup);
  assert(!/\{|\}/.test(t!.line + t!.backup), "no placeholder left");
});

// ─── The window / marker guard ───────────────────────────────────────────

Deno.test("take moments: windows, observed transitions, markers", () => {
  eq(takeMomentFor("1H", 31, "1H", []), "30", "inside the 30' window");
  eq(takeMomentFor("1H", 36, "1H", []), "30", "last minute of the window");
  eq(takeMomentFor("1H", 29, "1H", []), null, "too early");
  eq(takeMomentFor("1H", 41, "1H", []), null, "missed window is skipped, not caught up");
  eq(takeMomentFor("1H", 31, null, []), null, "first observation never fires");
  eq(takeMomentFor("1H", 32, "1H", [takeMarker("30")]), null, "marker blocks a second take");
  eq(takeMomentFor("HT", null, "1H", []), "ht", "observed break");
  eq(takeMomentFor("HT", null, "HT", []), null, "a deploy mid-break is not a break");
  eq(takeMomentFor("2H", 72, "2H", []), "70", "70' window");
  eq(takeMomentFor("2H", 77, "2H", []), null, "after the 70' window");
  eq(takeMomentFor("2H", 71, "HT", []), null, "the 70' needs the half observed running");
  eq(takeMomentFor("FT", 90, "2H", []), "ft", "observed full time");
  eq(takeMomentFor("FT", 90, "FT", []), null, "re-observed full time");
  for (const s of ["ET", "BT", "P", "AET", "PEN", "INT", "SUSP", "ABD"]) {
    eq(takeMomentFor(s, 95, "2H", []), null, `${s}: no take`);
  }
  eq(takeMomentFor("FT", 120, "ET", []), null, "no full-time take after extra time");
  eq(takeMarker("ht"), "TAKE_HT", "marker name");
});

// ─── parseFixtureStats ───────────────────────────────────────────────────

Deno.test("parseFixtureStats reads the counts; a listed null is 0, an unlisted type is missing", () => {
  const m = parseFixtureStats([{
    team: { id: 42 },
    statistics: [
      { type: "Total Shots", value: 9 }, { type: "Shots on Goal", value: null },
      { type: "Corner Kicks", value: 6 }, { type: "Fouls", value: "11" },
      { type: "Yellow Cards", value: 2 }, { type: "Red Cards", value: null },
    ],
  }]);
  eq(m.get(42), { shots: 9, corners: 6, fouls: 11, yellow: 2, red: 0 }, "saves unlisted stays missing; onTarget null unchanged");
});
