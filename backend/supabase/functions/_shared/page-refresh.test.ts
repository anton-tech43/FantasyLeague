import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  mergeRefreshTargets,
  PAGE_REFRESH_FAIL_PREFIX,
  PAGE_REFRESH_MARKER,
  pageRefreshMarker,
  planPageRefresh,
  TOURNAMENTS_WITH_A_TABLE,
} from "./page-refresh.ts";

const OURS = new Set([
  "arsenal",
  "chelsea",
  "liverpool",
  "champions_league",
  "europa_league",
  "conference_league",
]);

const base = {
  status: "FT",
  priorStatus: "2H",
  briefsFired: [] as string[],
  homeTeamId: "arsenal",
  awayTeamId: "chelsea",
  activeTeamIds: OURS,
  leagueId: 39,
};

Deno.test("a finished league game refreshes both clubs", () => {
  assertEquals(planPageRefresh(base), ["arsenal", "chelsea"]);
});

Deno.test("extra time and penalties are full time too", () => {
  for (const status of ["FT", "AET", "PEN"]) {
    assertEquals(planPageRefresh({ ...base, status }).length, 2, status);
  }
});

Deno.test("a match still being played refreshes nothing", () => {
  for (const status of ["1H", "HT", "2H", "ET", "P", "BT", "NS", "PST"]) {
    assertEquals(planPageRefresh({ ...base, status }), [], status);
  }
});

Deno.test("it fires exactly once per fixture", () => {
  const first = planPageRefresh(base);
  assertEquals(first, ["arsenal", "chelsea"]);
  // match-watcher persists the marker in briefs_fired; the next tick sees the
  // same finished fixture and must not buy the table again.
  const second = planPageRefresh({ ...base, briefsFired: [PAGE_REFRESH_MARKER] });
  assertEquals(second, []);
});

Deno.test("an unrelated marker does not suppress the refresh", () => {
  assertEquals(
    planPageRefresh({ ...base, briefsFired: ["HT", "FT_PUSH", "HT_PUSH"] }),
    ["arsenal", "chelsea"],
  );
});

Deno.test("first observation never fires", () => {
  assertEquals(planPageRefresh({ ...base, priorStatus: null }), []);
});

Deno.test("a re-observed full time still fires once, unlike the FT push", () => {
  // Deploy or replay mid-evening: prior.status is already FT. A late push would
  // be wrong; a late table repair is the whole point.
  assertEquals(planPageRefresh({ ...base, priorStatus: "FT" }), ["arsenal", "chelsea"]);
});

Deno.test("only our clubs", () => {
  // Napoli v Bayern is a Champions League night, but neither side is ours.
  assertEquals(
    planPageRefresh({
      ...base,
      homeTeamId: "napoli",
      awayTeamId: "bayern",
      leagueId: 2,
    }),
    [],
  );
  // Napoli v Arsenal is Arsenal's night: refresh Arsenal, never Napoli.
  assertEquals(
    planPageRefresh({
      ...base,
      homeTeamId: "napoli",
      awayTeamId: "arsenal",
      leagueId: 2,
    }),
    ["arsenal", "champions_league"],
  );
});

Deno.test("a European tie moves europe_standings too", () => {
  assertEquals(planPageRefresh({ ...base, leagueId: 2 }), [
    "arsenal",
    "chelsea",
    "champions_league",
  ]);
  assertEquals(planPageRefresh({ ...base, leagueId: 3 }).at(-1), "europa_league");
  assertEquals(planPageRefresh({ ...base, leagueId: 848 }).at(-1), "conference_league");
});

Deno.test("a knockout cup with no table brings no tournament along", () => {
  for (const leagueId of [39, 45, 48]) {
    assertEquals(planPageRefresh({ ...base, leagueId }), ["arsenal", "chelsea"], String(leagueId));
    assertEquals(TOURNAMENTS_WITH_A_TABLE[leagueId], undefined);
  }
});

Deno.test("a Saturday of finishes collapses into one call", () => {
  const targets = mergeRefreshTargets([
    { teamIds: ["arsenal", "chelsea"] },
    { teamIds: ["liverpool", "everton"] },
    { teamIds: ["arsenal", "champions_league"] }, // impossible, but must dedupe
  ]);
  assertEquals(targets, ["arsenal", "chelsea", "liverpool", "everton", "champions_league"]);
  assertEquals(mergeRefreshTargets([]), []);
});

Deno.test("a failed refresh is retried next tick, up to three times", () => {
  assertEquals(pageRefreshMarker([], false), `${PAGE_REFRESH_FAIL_PREFIX}1`);
  assertEquals(pageRefreshMarker([`${PAGE_REFRESH_FAIL_PREFIX}1`], false), `${PAGE_REFRESH_FAIL_PREFIX}2`);
  assertEquals(pageRefreshMarker([`${PAGE_REFRESH_FAIL_PREFIX}1`], true), PAGE_REFRESH_MARKER);
  // Two failures: still asks.
  assertEquals(
    planPageRefresh({ ...base, briefsFired: [`${PAGE_REFRESH_FAIL_PREFIX}1`, `${PAGE_REFRESH_FAIL_PREFIX}2`] }).length,
    2,
  );
  // Three: gives up until the two-hourly cron.
  assertEquals(
    planPageRefresh({
      ...base,
      briefsFired: [`${PAGE_REFRESH_FAIL_PREFIX}1`, `${PAGE_REFRESH_FAIL_PREFIX}2`, `${PAGE_REFRESH_FAIL_PREFIX}3`],
    }),
    [],
  );
  // A success after failures is final.
  assertEquals(planPageRefresh({ ...base, briefsFired: [`${PAGE_REFRESH_FAIL_PREFIX}2`, PAGE_REFRESH_MARKER] }), []);
});
