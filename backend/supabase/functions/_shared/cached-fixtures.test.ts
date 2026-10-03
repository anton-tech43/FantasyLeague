// deno test backend/supabase/functions/_shared/cached-fixtures.test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { latestFixtures } from "./cached-fixtures.ts";

const fx = (id: number) => ({
  fixture: { id, date: "2026-10-04T14:00:00+00:00" },
  league: { id: 39 },
  teams: { home: { id: 1, name: "A" }, away: { id: 2, name: "B" } },
});

Deno.test("latestFixtures: newest non-empty snapshot per entity, deduped by fixture (QA-06)", () => {
  const rows = [
    { team_id: "coventry", data: { response: [] } }, // nightly-refresh blank
    { team_id: "coventry", data: { response: [fx(10), fx(11)] } },
    { team_id: "newcastle", data: { response: [fx(10), fx(12)] } }, // same derby
    { team_id: "coventry", data: { response: [fx(99)] } }, // older, ignored
    { team_id: "bad", data: null },
  ];
  assertEquals(latestFixtures(rows).map((f) => f.fixture.id), [10, 11, 12]);
});
