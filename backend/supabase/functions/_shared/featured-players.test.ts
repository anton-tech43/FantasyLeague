import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  formatSquadStats,
  pickFeaturedPlayers,
  sameName,
  describeSubstitution,
  type PlayerStatRow,
} from "./featured-players.ts";

/**
 * Arsenal's real season as `players` held it on 2026-10-02, copied from the
 * table rather than retyped — an earlier version of this fixture had Tzolis as
 * a midfielder where the DB says attacker, omitted Zubimendi, and carried no
 * league columns at all, which is how a league-start rule could be added
 * without a single test noticing.
 *
 * Sixteen most-used: everyone who can clear the bar, plus the ones who must not.
 */
const ARSENAL: PlayerStatRow[] = [
  { name: "Gabriel Magalhães", position: "Defender", appearances: 8, starts: 8, league_starts: 5, minutes: 679, goals: 0, league_goals: 0, assists: 0, rating: 6.94 },
  { name: "David Raya", position: "Goalkeeper", appearances: 7, starts: 7, league_starts: 5, minutes: 634, goals: 0, league_goals: 0, assists: 0, rating: 7.15 },
  { name: "M. Ødegaard", position: "Midfielder", appearances: 8, starts: 7, league_starts: 5, minutes: 570, goals: 4, league_goals: 2, assists: 0, rating: 7.79, captain: true },
  { name: "D. Rice", position: "Midfielder", appearances: 7, starts: 6, league_starts: 5, minutes: 553, goals: 0, league_goals: 0, assists: 2, rating: 7.27 },
  { name: "K. Havertz", position: "Attacker", appearances: 7, starts: 6, league_starts: 5, minutes: 530, goals: 3, league_goals: 2, assists: 0, rating: 6.93 },
  { name: "B. Saka", position: "Attacker", appearances: 7, starts: 6, league_starts: 5, minutes: 525, goals: 3, league_goals: 3, assists: 0, rating: 7.23 },
  { name: "C. Tzolis", position: "Attacker", appearances: 8, starts: 6, league_starts: 5, minutes: 497, goals: 0, league_goals: 0, assists: 4, rating: 7.08 },
  { name: "B. White", position: "Defender", appearances: 6, starts: 6, league_starts: 4, minutes: 491, goals: 0, league_goals: 0, assists: 1, rating: 7.42 },
  { name: "R. Calafiori", position: "Defender", appearances: 6, starts: 6, league_starts: 5, minutes: 478, goals: 1, league_goals: 0, assists: 2, rating: 6.90 },
  { name: "M. Lewis-Skelly", position: "Defender", appearances: 6, starts: 6, league_starts: 4, minutes: 438, goals: 0, league_goals: 0, assists: 1, rating: 5.94 },
  { name: "E. Konsa", position: "Defender", appearances: 6, starts: 4, league_starts: 3, minutes: 416, goals: 0, league_goals: 0, assists: 0, rating: 6.76 },
  { name: "Cristhian Mosquera", position: "Defender", appearances: 3, starts: 3, league_starts: 2, minutes: 263, goals: 0, league_goals: 0, assists: 0, rating: 6.90 },
  { name: "Bruno Guimarães", position: "Midfielder", appearances: 6, starts: 3, league_starts: 1, minutes: 258, goals: 1, league_goals: 1, assists: 0, rating: 6.60 },
  { name: "Mikel Merino", position: "Midfielder", appearances: 7, starts: 2, league_starts: 0, minutes: 245, goals: 1, league_goals: 0, assists: 0, rating: 6.97 },
  { name: "Martín Zubimendi", position: "Midfielder", appearances: 8, starts: 1, league_starts: 0, minutes: 211, goals: 0, league_goals: 0, assists: 1, rating: 6.73 },
  { name: "V. Gyökeres", position: "Attacker", appearances: 5, starts: 2, league_starts: 0, minutes: 211, goals: 0, league_goals: 0, assists: 0, rating: 6.43 },
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

// ── Added 2026-10-02 after a mutation review: 7 of 22 mutants survived the
// suite above. Both eligibility constants could be halved or raised by half,
// the minutes floor halved, the `>=` boundary moved, and the two tie-breaks
// flipped, with everything still green. These pin them.

const squadOf = (n: number, mins: number, apps = 5): PlayerStatRow[] =>
  Array.from({ length: n }, (_, i) => ({
    name: `P${String(i).padStart(2, "0")}`, position: "Midfielder",
    minutes: mins, appearances: apps, starts: apps, league_starts: apps,
    goals: 0, assists: 0, rating: 7,
  }));

Deno.test("REGULAR_SHARE is 0.4, not 0.2 and not 0.6", () => {
  // Leader on 1000. A player on 300 sits above 0.2*1000 and below 0.4*1000,
  // so he is in if the share drops and out at the real value. A player on 500
  // is in at 0.4 and out at 0.6.
  const squad: PlayerStatRow[] = [
    ...squadOf(6, 1000),
    { name: "At300", position: "Attacker", minutes: 300, appearances: 5, starts: 5, league_starts: 5, goals: 9, assists: 0, rating: 9 },
    { name: "At500", position: "Attacker", minutes: 500, appearances: 5, starts: 5, league_starts: 5, goals: 8, assists: 0, rating: 9 },
  ];
  const names = pickFeaturedPlayers(squad)!.map((p) => p.name);
  assertEquals(names.includes("At300"), false);  // fails if share drops to 0.2
  assertEquals(names.includes("At500"), true);   // fails if share rises to 0.6
});

Deno.test("MIN_REGULAR_MINUTES is 90, not 45", () => {
  // Everyone on 100 so the share term is inert and only the floor decides.
  const squad: PlayerStatRow[] = [
    ...squadOf(6, 100),
    { name: "Sub60", position: "Attacker", minutes: 60, appearances: 5, starts: 0, league_starts: 1, goals: 9, assists: 9, rating: 9 },
  ];
  assertEquals(pickFeaturedPlayers(squad)!.some((p) => p.name === "Sub60"), false);
});

Deno.test("the minutes bar is inclusive at exactly the threshold", () => {
  // Leader 1000, bar 400. A player on exactly 400 is in; `>` would drop him.
  const squad: PlayerStatRow[] = [
    ...squadOf(6, 1000),
    { name: "Exactly400", position: "Attacker", minutes: 400, appearances: 5, starts: 5, league_starts: 5, goals: 9, assists: 0, rating: 9 },
  ];
  assertEquals(pickFeaturedPlayers(squad)![0].name, "Exactly400");
});

Deno.test("MIN_ELIGIBLE binds at five, not four", () => {
  assertEquals(pickFeaturedPlayers(squadOf(5, 500)) === null, false);
  assertEquals(pickFeaturedPlayers(squadOf(4, 500)), null);
});

Deno.test("ties break on minutes descending, then on name", () => {
  const even = (name: string, minutes: number): PlayerStatRow =>
    ({ name, position: "Midfielder", minutes, appearances: 5, starts: 5, league_starts: 5, goals: 1, assists: 0, rating: 7 });
  const picked = pickFeaturedPlayers([...squadOf(5, 300), even("More", 600), even("Less", 500)])!;
  assertEquals(picked.slice(0, 2).map((p) => p.name), ["More", "Less"]);
  // Fully level: name ascending, so a flipped localeCompare fails here.
  const level = pickFeaturedPlayers([even("Zeta", 500), even("Alpha", 500), ...squadOf(4, 500)])!;
  assertEquals(level[0].name, "Alpha");
});

Deno.test("a cup record does not qualify a man for a league page", () => {
  // Coventry's V. Torp on 2026-10-02: two goals, both in cups, no league start,
  // and the top pick on a Premier League card.
  const torp: PlayerStatRow = {
    name: "V. Torp", position: "Midfielder", minutes: 240, appearances: 5,
    starts: 2, league_starts: 0, goals: 2, league_goals: 0, assists: 1, rating: 7.44,
  };
  assertEquals(pickFeaturedPlayers([torp, ...squadOf(6, 400)])!.some((p) => p.name === "V. Torp"), false);
});

Deno.test("one matchday is not a season, whatever the minutes say", () => {
  // The old MIN_ELIGIBLE could not see this: on matchday one the leader has 90,
  // so the share term goes inert, the floor becomes the bar, and a whole XI
  // qualifies — goalkeeper included, which is the Newcastle failure again.
  const xi = squadOf(11, 90, 1).map((p, i) =>
    i === 0 ? { ...p, name: "Keeper", position: "Goalkeeper" } : p);
  assertEquals(pickFeaturedPlayers(xi), null);
});

Deno.test("an expanded first name is not a substitution", () => {
  // The model writes names out where the feed abbreviates them. Comparing
  // strings would have reported 46 of 60 correct names as substitutions.
  assertEquals(sameName("B. Saka", "Bukayo Saka"), true);
  assertEquals(sameName("M. Ødegaard", "Martin Ødegaard"), true);
  assertEquals(sameName("P. Groß", "P. Gross"), true);
  assertEquals(sameName("Gabriel Magalhães", "Gabriel Magalhaes"), true);
  assertEquals(sameName("B. Saka", "Bukayo Sako"), false);
  assertEquals(sameName("J. Clarke", "Omari Clarke"), false);  // invented forename
});

Deno.test("the guard reads a sequence, not a bag of names", () => {
  const f = squadOf(3, 500).map((p, i) => ({ ...p, name: ["A", "B", "C"][i] }));
  assertEquals(describeSubstitution(f, [{ name: "A" }, { name: "B" }, { name: "C" }]), null);
  // Each of these flagged nothing under the old membership filter.
  assertEquals(describeSubstitution(f, [{ name: "A" }]) !== null, true);
  assertEquals(describeSubstitution(f, [{ name: "A" }, { name: "A" }, { name: "A" }]) !== null, true);
  assertEquals(describeSubstitution(f, [{ name: "C" }, { name: "B" }, { name: "A" }]) !== null, true);
  assertEquals(describeSubstitution(f, [{}, {}, {}]) !== null, true);
});
