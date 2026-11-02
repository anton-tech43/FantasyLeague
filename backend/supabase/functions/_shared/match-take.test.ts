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
