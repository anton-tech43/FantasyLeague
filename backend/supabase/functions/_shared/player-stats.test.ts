// player-stats.test.ts
// The two things that decide what the daily player-stats fetch costs and
// whether the squad it stores is complete.
//
//   deno test --allow-none backend/supabase/functions/_shared/player-stats.test.ts

import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  isPlayerStatsDue,
  mergePlayerStatPages,
  pagesToFetch,
  PLAYER_STATS_MAX_PAGES,
} from "./player-stats.ts";

const at = (iso: string) => new Date(iso);

// ── The once-a-day gate ───────────────────────────────────────────────────────

Deno.test("isPlayerStatsDue: never fetched", () => {
  assertEquals(isPlayerStatsDue(null, at("2026-09-09T06:00:00Z")), true);
  assertEquals(isPlayerStatsDue(undefined, at("2026-09-09T06:00:00Z")), true);
});

Deno.test("isPlayerStatsDue: the eight other runs of the day are skipped", () => {
  const fetched = "2026-09-09T06:00:30Z";
  for (const hour of [8, 10, 12, 14, 16, 18, 20, 22]) {
    const now = at(`2026-09-09T${String(hour).padStart(2, "0")}:00:00Z`);
    assertEquals(isPlayerStatsDue(fetched, now), false, `hour ${hour}`);
  }
});

Deno.test("isPlayerStatsDue: due again the next morning", () => {
  // 20h, not 24h, so a run that starts slightly late still fires at 06:00.
  assertEquals(isPlayerStatsDue("2026-09-09T06:12:00Z", at("2026-09-10T06:00:00Z")), true);
  assertEquals(isPlayerStatsDue("2026-09-09T06:00:00Z", at("2026-09-10T01:59:00Z")), false);
});

Deno.test("isPlayerStatsDue: an unparseable timestamp fetches rather than stalls", () => {
  assertEquals(isPlayerStatsDue("not a date", at("2026-09-09T06:00:00Z")), true);
});

// ── Paging ────────────────────────────────────────────────────────────────────

Deno.test("pagesToFetch: a PL squad is two pages", () => {
  assertEquals(pagesToFetch({ paging: { current: 1, total: 2 } }), 2);
  assertEquals(pagesToFetch({ paging: { current: 1, total: 1 } }), 1);
});

Deno.test("pagesToFetch: a missing or nonsense total costs one call, never the quota", () => {
  assertEquals(pagesToFetch({}), 1);
  assertEquals(pagesToFetch({ paging: {} }), 1);
  assertEquals(pagesToFetch({ paging: { total: 0 } }), 1);
  assertEquals(pagesToFetch({ paging: { total: 900 } }), PLAYER_STATS_MAX_PAGES);
});

// ── Merging ───────────────────────────────────────────────────────────────────

const p = (id: number) => ({ player: { id }, statistics: [] });

Deno.test("mergePlayerStatPages: pages become one payload the sync can read", () => {
  const merged = mergePlayerStatPages([
    { paging: { current: 1, total: 2 }, response: [p(1), p(2)] },
    { paging: { current: 2, total: 2 }, response: [p(3)] },
  ]);
  assertEquals(merged.results, 3);
  assertEquals(merged.paging, { current: 1, total: 2 });
  const ids = merged.response.map((e) => (e as { player: { id: number } }).player.id);
  assertEquals(ids, [1, 2, 3]);
});

Deno.test("mergePlayerStatPages: a player served on both pages is not counted twice", () => {
  // The squad can shift between two calls, which slides the page boundary and
  // re-serves a player. Left in, his minutes would be summed twice.
  const merged = mergePlayerStatPages([
    { response: [p(1), p(2)] },
    { response: [p(2), p(3)] },
  ]);
  assertEquals(merged.results, 3);
});

Deno.test("mergePlayerStatPages: an empty or failed page does not break the merge", () => {
  assertEquals(mergePlayerStatPages([]).results, 0);
  assertEquals(mergePlayerStatPages([{ response: [] }, { response: [p(7)] }]).results, 1);
  assertEquals(mergePlayerStatPages([{}, { response: [p(7)] }]).results, 1);
});
