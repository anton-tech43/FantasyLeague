// cup-coverage.test.ts
// The pure half of cup coverage (CUP_COVERAGE_PLAN.md, 2026-09-08): what gets
// polled, how big a night is, what a push says, and who receives it.
//
//   deno test --allow-none backend/supabase/functions/_shared/cup-coverage.test.ts

import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  competitionName,
  fixtureImportance,
  fixtureLabel,
  parseRound,
  roundLabel,
  seasonForLeague,
  isSingleLegTie,
} from "./league-helpers.ts";
import { buildPollPairs } from "./poll-plan.ts";
import { competitionSuffix, knockoutOutcome } from "./goal-push.ts";
import { minTierForLiveEvent, TIER_NOBODY, tierReceives } from "./push-tiers.ts";
import { renderMatchdayReminder } from "./matchday-reminder-copy.ts";

// ── Rounds ────────────────────────────────────────────────────────────────────

Deno.test("parseRound: the shapes API-Football actually sends", () => {
  assertEquals(parseRound("Round of 32").label, "last 32");
  assertEquals(parseRound("Round of 16").stage, 8);
  assertEquals(parseRound("Quarter-finals").stage, 4);
  assertEquals(parseRound("Semi-finals").stage, 2);
  assertEquals(parseRound("Final").stage, 1);
  assertEquals(parseRound("League Stage - 3").stage, 0);
  assertEquals(parseRound("Regular Season - 4").stage, 0);
  assertEquals(parseRound("3rd Round").label, "3rd round");
  assertEquals(parseRound("Playoff round").label, "play-off");
  assertEquals(parseRound(undefined).stage, 0);
});

Deno.test("parseRound: a third-place final is not a final", () => {
  assertEquals(parseRound("3rd Place Final").stage, 0);
  assertEquals(parseRound("Semi-finals").label, "semi-final");
});

Deno.test("parseRound: two-legged ties carry the leg", () => {
  assertEquals(parseRound("Quarter-finals - 1st Leg").leg, 1);
  assertEquals(parseRound("Semi-finals - 2nd Leg").leg, 2);
  assertEquals(parseRound("Final").leg, undefined);
});

// ── Season ───────────────────────────────────────────────────────────────────

Deno.test("seasonForLeague: cups follow the club season, not the calendar", () => {
  // The default branch returned the calendar year, which is right in December
  // and wrong in January — the 2026-27 FA Cup is season 2026 in API-Football,
  // and the third round is in January.
  const cases: Array<[string, number]> = [
    ["2026-08-01T12:00:00Z", 2026],
    ["2026-12-31T12:00:00Z", 2026],
    ["2027-01-02T12:00:00Z", 2026],
    ["2027-06-30T12:00:00Z", 2026],
    ["2027-07-01T12:00:00Z", 2027],
  ];
  for (const leagueId of [39, 2, 3, 848, 48, 45]) {
    for (const [iso, expected] of cases) {
      assertEquals(seasonForLeague(leagueId, new Date(iso)), expected, `league ${leagueId} at ${iso}`);
    }
  }
});

// ── Calendar dots and labels ─────────────────────────────────────────────────

Deno.test("fixtureImportance: the table from CUP_COVERAGE_PLAN.md", () => {
  const rows: Array<[number, string, number]> = [
    // Champions League
    [2, "Final", 5], [2, "Semi-finals", 5], [2, "Quarter-finals", 5],
    [2, "Round of 16", 4], [2, "League Stage - 3", 4],
    // Europa League
    [3, "Final", 5], [3, "Semi-finals", 4], [3, "Quarter-finals", 4],
    [3, "Round of 16", 3], [3, "League Stage - 1", 3],
    // Conference League
    [848, "Final", 4], [848, "Semi-finals", 3], [848, "League Stage - 1", 2],
    // FA Cup
    [45, "Final", 5], [45, "Semi-finals", 5], [45, "Quarter-finals", 4],
    [45, "Round of 16", 3], [45, "3rd Round", 2],
    // League Cup
    [48, "Final", 5], [48, "Semi-finals", 4], [48, "Quarter-finals", 3],
    [48, "Round of 16", 2], [48, "Round of 32", 2],
    // League
    [39, "Regular Season - 4", 3],
  ];
  for (const [leagueId, round, expected] of rows) {
    assertEquals(fixtureImportance(leagueId, round), expected, `${leagueId} ${round}`);
  }
});

Deno.test("fixtureImportance: an early FA Cup tie against a top-flight club is a proper afternoon", () => {
  assertEquals(fixtureImportance(45, "3rd Round", true), 3);
  assertEquals(fixtureImportance(45, "3rd Round", false), 2);
});

Deno.test("fixtureLabel: names the round, fits 30 chars", () => {
  assertEquals(fixtureLabel("UEFA Champions League", 2, "Semi-finals"), "Champions League semi-final");
  assertEquals(fixtureLabel("League Cup", 48, "Round of 32"), "League Cup last 32");
  assertEquals(fixtureLabel("FA Cup", 45, "Final"), "FA Cup final");
  assertEquals(fixtureLabel("Premier League", 39, "Regular Season - 4"), "Premier League");
  assertEquals(fixtureLabel("UEFA Europa League", 3, "League Stage - 2"), "Europa League");
  // The leg is dropped when it does not fit; the competition never is.
  assertEquals(fixtureLabel("UEFA Europa League", 3, "Quarter-finals - 2nd Leg"), "Europa League quarter-final");
  assertEquals(fixtureLabel("League Cup", 48, "Semi-finals - 2nd Leg"), "League Cup semi-final, leg 2");
  for (const [name, id, round] of [
    ["UEFA Champions League", 2, "Semi-finals - 1st Leg"],
    ["UEFA Europa Conference League", 848, "Quarter-finals - 2nd Leg"],
    ["League Cup", 48, "Round of 32"],
    ["FA Cup", 45, "Semi-finals"],
  ] as Array<[string, number, string]>) {
    const label = fixtureLabel(name, id, round);
    assertEquals(label.length <= 30, true, `${label} is ${label.length} chars`);
  }
});

Deno.test("fixtureLabel: a two-legged tie never loses the competition", () => {
  // The competition is the point of the label; the leg is the bonus. Dropping
  // the competition left "quarter-final, leg 2", which does not say whether
  // that is a Champions League night or a Europa League one.
  for (const [name, id, round] of [
    ["UEFA Europa League", 3, "Quarter-finals - 2nd Leg"],
    ["UEFA Champions League", 2, "Semi-finals - 1st Leg"],
    ["UEFA Champions League", 2, "Round of 16 - 2nd Leg"],
    ["UEFA Europa Conference League", 848, "Quarter-finals - 2nd Leg"],
    ["League Cup", 48, "Semi-finals - 2nd Leg"],
  ] as Array<[string, number, string]>) {
    const label = fixtureLabel(name, id, round);
    assertEquals(label.length <= 30, true, `${label} is ${label.length} chars`);
    assertEquals(label.startsWith(competitionName(id)), true, `"${label}" lost the competition`);
  }
});

Deno.test("competitionName: every covered competition, and a stranger", () => {
  assertEquals(competitionName(48), "League Cup");
  assertEquals(competitionName(45), "FA Cup");
  assertEquals(competitionName(3), "Europa League");
  assertEquals(competitionName(848), "Conference League");
  assertEquals(competitionName(9999), "Cup");
  assertEquals(competitionName(undefined), "Cup");
});

// ── Poll plan ────────────────────────────────────────────────────────────────

Deno.test("buildPollPairs: normal tick uses the RPC rows", () => {
  const pairs = buildPollPairs({
    rpcRows: [
      { league_id: 48, poll_date: "2026-09-08" },
      { league_id: 2, poll_date: "2026-09-08" },
      { league_id: 48, poll_date: "2026-09-08" }, // duplicate
    ],
    rpcFailed: false,
    dateOverride: null,
    today: "2026-09-08",
    homeLeagues: [39],
  });
  assertEquals(pairs, [
    { leagueId: 48, date: "2026-09-08" },
    { leagueId: 2, date: "2026-09-08" },
  ]);
});

Deno.test("buildPollPairs: a quiet minute polls nothing", () => {
  assertEquals(
    buildPollPairs({ rpcRows: [], rpcFailed: false, dateOverride: null, today: "2026-09-08", homeLeagues: [39] }),
    [],
  );
});

Deno.test("buildPollPairs: an RPC failure degrades to always-on home leagues", () => {
  assertEquals(
    buildPollPairs({ rpcRows: null, rpcFailed: true, dateOverride: null, today: "2026-09-08", homeLeagues: [39, 1] }),
    [{ leagueId: 39, date: "2026-09-08" }, { leagueId: 1, date: "2026-09-08" }],
  );
});

Deno.test("buildPollPairs: ?date= looks at every covered league for that date", () => {
  const pairs = buildPollPairs({
    rpcRows: [{ league_id: 48, poll_date: "2026-09-08" }],
    rpcFailed: false,
    dateOverride: "2026-01-10",
    today: "2026-09-08",
    homeLeagues: [39],
  });
  assertEquals(pairs.every((p) => p.date === "2026-01-10"), true);
  assertEquals(pairs.map((p) => p.leagueId).sort((a, b) => a - b), [2, 3, 39, 45, 48, 848]);
});

Deno.test("buildPollPairs: a malformed row is dropped, not crashed on", () => {
  const pairs = buildPollPairs({
    // deno-lint-ignore no-explicit-any
    rpcRows: [{ league_id: 48, poll_date: "2026-09-08" }, { league_id: NaN, poll_date: "x" } as any],
    rpcFailed: false,
    dateOverride: null,
    today: "2026-09-08",
    homeLeagues: [39],
  });
  assertEquals(pairs, [{ leagueId: 48, date: "2026-09-08" }]);
});

// ── Push copy ────────────────────────────────────────────────────────────────

Deno.test("competitionSuffix: silent for the league, explicit for a cup", () => {
  assertEquals(competitionSuffix(39, "Regular Season - 4"), "");
  assertEquals(competitionSuffix(1, "Group A - 1"), "");
  assertEquals(competitionSuffix(48, "Round of 32"), "League Cup, last 32.");
  assertEquals(competitionSuffix(2, "League Stage - 1"), "Champions League.");
  assertEquals(competitionSuffix(45, "Semi-finals"), "FA Cup, semi-final.");
});

Deno.test("knockoutOutcome: only says through or out when the tie is settled", () => {
  assertEquals(knockoutOutcome(48, "Round of 32", true), "Through to the last 16.");
  assertEquals(knockoutOutcome(48, "Round of 32", false), "Out of the League Cup.");
  assertEquals(knockoutOutcome(48, "Semi-finals", true), "Through to the final.");
  assertEquals(knockoutOutcome(48, "Final", true), "League Cup winners.");
  assertEquals(knockoutOutcome(45, "Quarter-finals", true), "Through to the semi-finals.");
  // Undecided (a first leg, or a league-phase night): name the competition only.
  assertEquals(knockoutOutcome(48, "Round of 32", null), "League Cup, last 32.");
  assertEquals(knockoutOutcome(3, "League Stage - 2", null), "Europa League.");
  // The league says nothing at all.
  assertEquals(knockoutOutcome(39, "Regular Season - 4", true), "");
});

Deno.test("push bodies stay inside the 100-char content CHECK with the longest clause", () => {
  // The body pools are ~70 chars at their longest; the clause is additive, and
  // an over-long push_text is the failure that killed every UCL card.
  const longest = knockoutOutcome(848, "Quarter-finals", true); // "Through to the semi-finals."
  assertEquals(longest.length <= 30, true, `${longest} is ${longest.length}`);
});

// ── Tiers ────────────────────────────────────────────────────────────────────

Deno.test("minTierForLiveEvent: the base table", () => {
  assertEquals(minTierForLiveEvent("kickoff", 39, "Regular Season - 4"), 2);
  assertEquals(minTierForLiveEvent("ht", 39, "Regular Season - 4"), 2);
  assertEquals(minTierForLiveEvent("ft", 39, "Regular Season - 4"), 1);
});

Deno.test("minTierForLiveEvent: a goal is never gated (Anton, 2026-09-08)", () => {
  // The Live Activity runs for every match a followed club plays and scores as
  // it goes; a goal push is the same fact by another route. Gating one and not
  // the other made no sense.
  const rounds: Array<[number, string]> = [
    [39, "Regular Season - 4"], [2, "League Stage - 1"], [3, "Quarter-finals"],
    [848, "League Stage - 2"], [48, "Round of 32"], [48, "Round of 64"],
    [45, "3rd Round"], [45, "Final"], [1, "Group A - 1"],
  ];
  for (const [leagueId, round] of rounds) {
    assertEquals(minTierForLiveEvent("goal", leagueId, round), 1, `${leagueId} ${round}`);
  }
});

Deno.test("minTierForLiveEvent: an early domestic cup round drops the framing pushes only", () => {
  for (const ev of ["kickoff", "ht"] as const) {
    assertEquals(minTierForLiveEvent(ev, 48, "Round of 32"), TIER_NOBODY, `league cup ${ev}`);
    assertEquals(minTierForLiveEvent(ev, 45, "3rd Round"), TIER_NOBODY, `fa cup ${ev}`);
  }
  // The match still reaches her: every goal, and the result.
  assertEquals(minTierForLiveEvent("goal", 48, "Round of 32"), 1);
  assertEquals(minTierForLiveEvent("goal", 45, "3rd Round"), 1);
  assertEquals(minTierForLiveEvent("ft", 48, "Round of 32"), 1);
  assertEquals(minTierForLiveEvent("ft", 45, "3rd Round"), 1);
});

Deno.test("minTierForLiveEvent: quarter-finals behave like the league, semis and finals are everyone's", () => {
  assertEquals(minTierForLiveEvent("goal", 48, "Quarter-finals"), 1);
  assertEquals(minTierForLiveEvent("kickoff", 48, "Quarter-finals"), 2);
  for (const ev of ["kickoff", "goal", "ht", "ft"] as const) {
    assertEquals(minTierForLiveEvent(ev, 48, "Semi-finals"), 1, `semi ${ev}`);
    assertEquals(minTierForLiveEvent(ev, 45, "Final"), 1, `final ${ev}`);
    assertEquals(minTierForLiveEvent(ev, 2, "Final"), 1, `cl final ${ev}`);
  }
});

Deno.test("minTierForLiveEvent: European league phases are not gated as early cup rounds", () => {
  assertEquals(minTierForLiveEvent("kickoff", 2, "League Stage - 1"), 2);
  assertEquals(minTierForLiveEvent("goal", 3, "League Stage - 2"), 1);
  assertEquals(minTierForLiveEvent("kickoff", 848, "League Stage - 1"), 2);
});

Deno.test("tierReceives: an unset tier is treated as Match-fit", () => {
  assertEquals(tierReceives(null, 2), true);
  assertEquals(tierReceives(null, 3), false);
  assertEquals(tierReceives(1, 1), true);
  assertEquals(tierReceives(1, 2), false);
  assertEquals(tierReceives(3, 3), true);
  assertEquals(tierReceives(3, TIER_NOBODY), false);
});

// ── The 07:00 reminder ───────────────────────────────────────────────────────

Deno.test("renderMatchdayReminder: silent about the league, explicit about a cup", () => {
  const kickoff = new Date("2026-09-15T19:00:00Z");
  const now = new Date("2026-09-15T07:00:00Z");

  const league = renderMatchdayReminder({
    teamName: "Arsenal", opponent: "Chelsea", kickoffUtc: kickoff, now, rng: () => 0,
  });
  assertEquals(league.title, "Arsenal play today");
  assertEquals(league.body.includes("League Cup"), false);

  const cup = renderMatchdayReminder({
    teamName: "Leeds United", opponent: "Chelsea", kickoffUtc: kickoff, now,
    competition: "League Cup (Carabao Cup), last 32", rng: () => 0,
  });
  // The title carries the competition without the round; the body opens with
  // the full prose form, because a cup morning read like any other Tuesday.
  assertEquals(cup.title, "Leeds United: League Cup (Carabao Cup) today");
  assertEquals(cup.body.startsWith("League Cup (Carabao Cup), last 32. "), true);
  assertEquals(cup.body.includes("Chelsea"), true);
});

Deno.test("renderMatchdayReminder: an empty competition changes nothing", () => {
  const args = {
    teamName: "Arsenal", opponent: "Chelsea",
    kickoffUtc: new Date("2026-09-15T19:00:00Z"), now: new Date("2026-09-15T07:00:00Z"),
    rng: () => 0,
  };
  assertEquals(
    renderMatchdayReminder({ ...args, competition: "" }),
    renderMatchdayReminder(args),
  );
  assertEquals(
    renderMatchdayReminder({ ...args, competition: null }),
    renderMatchdayReminder(args),
  );
});

Deno.test("roundLabel: the words a card uses", () => {
  assertEquals(roundLabel("Round of 32"), "last 32");
  assertEquals(roundLabel("League Stage - 1"), "");
});

// ── 2026-09-09 review: what the feed really sends ────────────────────────────

Deno.test("isSingleLegTie: only rounds known to be one match settle a tie", () => {
  // The strings API-Football actually sent for leagues 2/3/45/48/848 over three
  // days: none carries "leg", so absence of the word proves nothing.
  assertEquals(isSingleLegTie(2, "Play-offs"), false);
  assertEquals(isSingleLegTie(2, "Round of 16"), false);
  assertEquals(isSingleLegTie(2, "League Stage - 1"), false);
  assertEquals(isSingleLegTie(2, "Final"), true);
  assertEquals(isSingleLegTie(3, "Quarter-finals"), false);
  assertEquals(isSingleLegTie(48, "Round of 32"), true);
  assertEquals(isSingleLegTie(48, "Quarter-finals"), true);
  assertEquals(isSingleLegTie(48, "Semi-finals"), false);
  assertEquals(isSingleLegTie(48, "Final"), true);
  assertEquals(isSingleLegTie(45, "3rd Round"), true);
  assertEquals(isSingleLegTie(45, "Semi-finals"), true);
  assertEquals(isSingleLegTie(45, "Quarter-finals - 1st Leg"), false);
  assertEquals(isSingleLegTie(39, "Regular Season - 4"), false);
  assertEquals(isSingleLegTie(undefined, "Final"), false);
});

Deno.test("parseRound: the League Cup first round and the FA Cup's numbered rounds", () => {
  assertEquals(parseRound("Round of 128", 48).stage, 64);
  assertEquals(parseRound("Round of 128", 48).label, "first round");
  // FA Cup: 3rd round is the last 64, 4th the last 32, 5th the last 16.
  assertEquals(parseRound("3rd Round", 45).stage, 32);
  assertEquals(parseRound("4th Round", 45).stage, 16);
  assertEquals(parseRound("5th Round", 45).stage, 8);
  assertEquals(parseRound("5th Round", 45).label, "5th round");
  assertEquals(parseRound("1st Round Qualifying", 45).stage, 40);
  // Without the league the generic numbered-round stage still applies.
  assertEquals(parseRound("3rd Round").stage, 40);
});

Deno.test("minTierForLiveEvent: the first round is quieter than the last 32, not louder", () => {
  assertEquals(minTierForLiveEvent("kickoff", 48, "Round of 128"), TIER_NOBODY);
  assertEquals(minTierForLiveEvent("ht", 48, "Round of 64"), TIER_NOBODY);
  assertEquals(minTierForLiveEvent("goal", 48, "Round of 128"), 1);
  assertEquals(minTierForLiveEvent("ft", 48, "Round of 128"), 1);
  // An unparsed domestic cup round is treated as early, never as a league phase.
  assertEquals(minTierForLiveEvent("kickoff", 45, "Something New"), TIER_NOBODY);
  // The FA Cup 5th round is the last 16 and gets the framing pushes back.
  assertEquals(minTierForLiveEvent("kickoff", 45, "5th Round"), 2);
  assertEquals(minTierForLiveEvent("kickoff", 45, "4th Round"), TIER_NOBODY);
});

Deno.test("knockoutOutcome: the FA Cup counts rounds, the League Cup has a second round", () => {
  assertEquals(knockoutOutcome(45, "3rd Round", true), "Through to the fourth round.");
  assertEquals(knockoutOutcome(45, "4th Round", true), "Through to the fifth round.");
  assertEquals(knockoutOutcome(45, "5th Round", true), "Through to the quarter-finals.");
  assertEquals(knockoutOutcome(48, "Round of 128", true), "Through to the second round.");
  assertEquals(knockoutOutcome(48, "Round of 64", true), "Through to the last 32.");
});

Deno.test("fixtureImportance: FA Cup 5th round is the last 16, and a top-flight opponent lifts the 3rd", () => {
  assertEquals(fixtureImportance(45, "5th Round"), 3);
  assertEquals(fixtureImportance(45, "4th Round"), 2);
  assertEquals(fixtureImportance(45, "4th Round", true), 3);
});

Deno.test("seasonForLeague: the season of the date asked about, not of today", () => {
  assertEquals(seasonForLeague(45, new Date("2026-01-10T15:00:00Z")), 2025);
  assertEquals(seasonForLeague(45, new Date("2026-08-10T15:00:00Z")), 2026);
  assertEquals(seasonForLeague(39, new Date("2027-05-20T15:00:00Z")), 2026);
});
