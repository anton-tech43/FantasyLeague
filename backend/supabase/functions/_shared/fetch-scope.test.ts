import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  ALL_SCOPES,
  parseFetchScope,
  StandingsCache,
  wants,
} from "./fetch-scope.ts";

// ─── parseFetchScope ────────────────────────────────────────────────────────

Deno.test("no body means today's behaviour: every entity, every endpoint", () => {
  for (const empty of [null, undefined, {}]) {
    const r = parseFetchScope(empty);
    assertEquals(r.ok, true);
    if (r.ok) assertEquals(r.scope, ALL_SCOPES);
  }
});

Deno.test("team_ids narrows the run and dedupes", () => {
  const r = parseFetchScope({ team_ids: ["arsenal", "chelsea", "arsenal"] });
  assertEquals(r.ok, true);
  if (r.ok) {
    assertEquals(r.scope.teamIds, ["arsenal", "chelsea"]);
    assertEquals(r.scope.only, null);
  }
});

Deno.test("the full-time body: two clubs, standings + fixtures only", () => {
  const r = parseFetchScope({
    team_ids: ["arsenal", "champions_league"],
    only: ["standings", "fixtures"],
  });
  assertEquals(r.ok, true);
  if (!r.ok) return;
  assertEquals(r.scope.teamIds, ["arsenal", "champions_league"]);
  assertEquals(wants(r.scope, "standings"), true);
  assertEquals(wants(r.scope, "fixtures"), true);
  // The expensive ones stay unbought: twelve RSS feeds, squad, transfers.
  assertEquals(wants(r.scope, "rss"), false);
  assertEquals(wants(r.scope, "squad"), false);
  assertEquals(wants(r.scope, "player_stats"), false);
});

Deno.test("legacy single team_id still works and merges with team_ids", () => {
  const r = parseFetchScope({ team_id: "spurs" });
  assertEquals(r.ok, true);
  if (r.ok) assertEquals(r.scope.teamIds, ["spurs"]);

  const both = parseFetchScope({ team_ids: ["spurs"], team_id: "spurs" });
  assertEquals(both.ok, true);
  if (both.ok) assertEquals(both.scope.teamIds, ["spurs"]);
});

Deno.test("an unscoped scope wants everything", () => {
  assertEquals(wants(ALL_SCOPES, "rss"), true);
  assertEquals(wants(ALL_SCOPES, "coachs"), true);
});

Deno.test("bad input is rejected, not guessed at", () => {
  const bad: unknown[] = [
    ["arsenal"], // a bare array, not an object
    "arsenal", // a string
    { team_ids: [] }, // empty
    { team_ids: "arsenal" }, // not an array
    { team_ids: [42] }, // not strings
    { team_ids: ["Arsenal"] }, // uppercase is not one of our slugs
    { team_ids: ["arsenal; drop table teams"] },
    { team_ids: ["../../etc/passwd"] },
    { team_ids: ["a"] }, // too short to be a slug
    { team_ids: new Array(101).fill("arsenal") },
    { team_id: 7 },
    { only: [] },
    { only: "standings" },
    { only: ["standings", "everything"] },
  ];
  for (const b of bad) {
    const r = parseFetchScope(b);
    assertEquals(r.ok, false, `should have rejected ${JSON.stringify(b)}`);
  }
});

// ─── StandingsCache ─────────────────────────────────────────────────────────

Deno.test("one league table is bought once and handed to every club in it", async () => {
  const cache = new StandingsCache();
  let apiCalls = 0;
  const fetcher = () => {
    apiCalls++;
    return Promise.resolve({ table: "PL" });
  };

  const twentyClubs = await Promise.all(
    new Array(20).fill(0).map(() => cache.get(39, 2026, fetcher)),
  );

  assertEquals(apiCalls, 1);
  assertEquals(cache.calls, 1);
  assertEquals(cache.saved, 19); // 19 calls the cron no longer makes
  // Every club still gets the payload, so every raw_fetch_logs row is written.
  assertEquals(twentyClubs.length, 20);
  for (const t of twentyClubs) assertEquals(t, { table: "PL" });
});

Deno.test("the cache key is league AND season", async () => {
  const cache = new StandingsCache();
  let apiCalls = 0;
  const f = (tag: string) => () => {
    apiCalls++;
    return Promise.resolve({ tag });
  };

  assertEquals(await cache.get(39, 2026, f("pl-26")), { tag: "pl-26" });
  assertEquals(await cache.get(39, 2025, f("pl-25")), { tag: "pl-25" });
  assertEquals(await cache.get(2, 2026, f("ucl-26")), { tag: "ucl-26" });
  assertEquals(await cache.get(39, 2026, f("never")), { tag: "pl-26" });

  assertEquals(apiCalls, 3);
  assertEquals(cache.calls, 3);
  assertEquals(cache.saved, 1);
  assertEquals(StandingsCache.key(39, 2026), "39:2026");
});

Deno.test("a league that fails costs one call a run, not twenty", async () => {
  const cache = new StandingsCache();
  let apiCalls = 0;
  const failing = () => {
    apiCalls++;
    return Promise.reject(new Error("API-Football 500"));
  };

  const results = await Promise.all([
    cache.get(39, 2026, failing),
    cache.get(39, 2026, failing),
    cache.get(39, 2026, failing),
  ]);

  assertEquals(apiCalls, 1);
  for (const r of results) assertEquals(r, null); // callers skip, nothing throws
});

Deno.test("concurrent callers share the one in-flight request", async () => {
  const cache = new StandingsCache();
  let started = 0;
  const slow = () => {
    started++;
    return new Promise((resolve) => setTimeout(() => resolve({ ok: true }), 5));
  };

  const [a, b] = await Promise.all([
    cache.get(39, 2026, slow),
    cache.get(39, 2026, slow),
  ]);

  assertEquals(started, 1);
  assertEquals(a, b);
});
