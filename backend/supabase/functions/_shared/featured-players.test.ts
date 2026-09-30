import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  formatSquadStats,
  pickFeaturedPlayers,
  sameName,
  type PlayerStatRow,
} from "./featured-players.ts";

/**
 * Arsenal's real season as `players` held it on 2026-09-29 — the squad that
 * produced the card this module exists to fix. Trimmed to the fifteen most
 * used, which is every player who can clear the bar plus the four who must
 * not.
 */
const ARSENAL: PlayerStatRow[] = [
  { name: "Gabriel Magalhães", position: "Defender", appearances: 8, starts: 8, minutes: 679, goals: 0, assists: 0, rating: 6.94 },
  { name: "David Raya", position: "Goalkeeper", appearances: 7, starts: 7, minutes: 634, goals: 0, assists: 0, rating: 7.15 },
  { name: "M. Ødegaard", position: "Midfielder", appearances: 8, starts: 7, league_starts: 5, minutes: 570, goals: 4, league_goals: 2, assists: 0, rating: 7.79, captain: true },
  { name: "D. Rice", position: "Midfielder", appearances: 7, starts: 6, minutes: 553, goals: 0, assists: 2, rating: 7.27 },
  { name: "K. Havertz", position: "Attacker", appearances: 7, starts: 6, minutes: 530, goals: 3, assists: 0, rating: 6.93 },
  { name: "B. Saka", position: "Midfielder", appearances: 7, starts: 6, minutes: 525, goals: 3, assists: 0, rating: 7.23 },
  { name: "C. Tzolis", position: "Midfielder", appearances: 8, starts: 6, minutes: 497, goals: 0, assists: 4, rating: 7.08 },
  { name: "B. White", position: "Defender", appearances: 6, starts: 6, minutes: 491, goals: 0, assists: 1, rating: 7.42 },
  { name: "R. Calafiori", position: "Defender", appearances: 6, starts: 6, minutes: 478, goals: 1, assists: 2, rating: 6.90 },
  { name: "M. Lewis-Skelly", position: "Defender", appearances: 6, starts: 6, minutes: 438, goals: 0, assists: 1, rating: 5.94 },
  { name: "E. Konsa", position: "Defender", appearances: 6, starts: 4, minutes: 416, goals: 0, assists: 0, rating: 6.76 },
  { name: "Cristhian Mosquera", position: "Defender", appearances: 3, starts: 3, minutes: 263, goals: 0, assists: 0, rating: 6.90 },
  { name: "Bruno Guimarães", position: "Midfielder", appearances: 6, starts: 3, minutes: 258, goals: 1, assists: 0, rating: 6.60 },
  { name: "Mikel Merino", position: "Midfielder", appearances: 7, starts: 2, minutes: 245, goals: 1, assists: 0, rating: 6.97 },
  { name: "V. Gyökeres", position: "Attacker", appearances: 5, starts: 2, minutes: 211, goals: 0, assists: 0, rating: 6.43 },
];

Deno.test("picks the players actually carrying the season", () => {
  const picked = pickFeaturedPlayers(ARSENAL)!;
  assertEquals(picked.map((p) => p.name), ["M. Ødegaard", "C. Tzolis", "B. Saka"]);
});

Deno.test("the marquee signing who is not playing cannot be picked", () => {
  // Two starts, no goals, 211 minutes — the pick this module was written for.
  const picked = pickFeaturedPlayers(ARSENAL)!;
  assertEquals(picked.some((p) => p.name === "V. Gyökeres"), false);
});

Deno.test("a player with no minutes at all cannot be picked", () => {
  // Newcastle's card led on a goalkeeper with 0 minutes. Even at the top of
  // the roster and with a flattering rating, he must not survive the filter.
  const withBenchKeeper = [
    { name: "N. Pope", position: "Goalkeeper", appearances: 0, starts: 0, minutes: 0, goals: 0, assists: 0, rating: 9.9 },
    ...ARSENAL,
  ];
  const picked = pickFeaturedPlayers(withBenchKeeper)!;
  assertEquals(picked.some((p) => p.name === "N. Pope"), false);
});

Deno.test("defers to Claude when the squad has no minutes (every WC country)", () => {
  // `players` holds all 48 country squads and zero minutes for any of them.
  // Returning null is what keeps the tournament path exactly as it was.
  const country = ARSENAL.map((p) => ({ ...p, minutes: 0, goals: 0, assists: 0, rating: null }));
  assertEquals(pickFeaturedPlayers(country), null);
});

Deno.test("defers to Claude at a season rollover, when too few have played", () => {
  // Four players with a game each is not a basis for ranking a season.
  const augustFirstWeek = ARSENAL.slice(0, 4).map((p) => ({ ...p, minutes: 90, appearances: 1, starts: 1 }))
    .concat(ARSENAL.slice(4).map((p) => ({ ...p, minutes: 0, appearances: 0, starts: 0 })));
  assertEquals(pickFeaturedPlayers(augustFirstWeek), null);
});

Deno.test("the bar rises with the season rather than staying at one match", () => {
  // In May a fringe player can pass 90 minutes and still be a fringe player,
  // so the share of the leader's minutes is what excludes him.
  const late = ARSENAL.map((p) => ({ ...p, minutes: (p.minutes ?? 0) * 4 }));
  const fringe: PlayerStatRow = {
    name: "Academy Debutant", position: "Attacker",
    appearances: 2, starts: 1, minutes: 120, goals: 2, assists: 2, rating: 9.5,
  };
  const picked = pickFeaturedPlayers([...late, fringe])!;
  // Two goals and two assists would top the ranking on involvement alone.
  assertEquals(picked.some((p) => p.name === "Academy Debutant"), false);
});

Deno.test("the stats table carries what a truthful one-liner needs", () => {
  const table = formatSquadStats(ARSENAL);
  const first = table.split("\n")[0];
  // Ordered by minutes, so a truncated tail loses the least important players.
  assertEquals(first.startsWith("Gabriel Magalhães"), true);
  assertEquals(first.includes("679 mins"), true);
  // The competition must be on the face of the number, not inferred.
  assertEquals(table.includes("4G all comps (2 league)"), true);
  assertEquals(table.includes("M. Ødegaard"), true);
  assertEquals(table.includes("captain"), true);
  // A player who has not played is not described at all.
  assertEquals(formatSquadStats([{ name: "Unused", minutes: 0 }]), "");
});

Deno.test("a doubled space is not a substitution", () => {
  // API-Football sent `J.  McGinn` and `Ilyas  Ansah`; migration 122 squeezes
  // them on ingest, but the guard compares free text and must not report a
  // correct pick as the model ignoring it.
  assertEquals(sameName("J.  McGinn", "J. McGinn"), true);
  assertEquals(sameName(" B. Saka ", "b. saka"), true);
  assertEquals(sameName("B. Saka", "B. Sako"), false);
});
