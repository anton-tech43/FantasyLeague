// matchup-card.test.ts
//
//   deno test --allow-none backend/supabase/functions/_shared/matchup-card.test.ts

import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  buildMatchupCard,
  type ClubStyleRow,
  nextFixtureIdForPredictions,
} from "./matchup-card.ts";

const ARSENAL = 42;
const SPURS = 47;

const meeting = (id: number, date: string, homeName: string, awayName: string, h: number, a: number) => ({
  fixture: { id, date },
  teams: { home: { name: homeName }, away: { name: awayName } },
  goals: { home: h, away: a },
});

const payload = {
  response: [{
    predictions: {
      winner: { id: ARSENAL, name: "Arsenal", comment: "Win or draw" },
      percent: { home: "62%", draw: "23%", away: "15%" },
      advice: "Double chance : draw or Arsenal",
    },
    teams: {
      home: {
        id: ARSENAL,
        name: "Arsenal",
        league: {
          form: "LWWWDLWWDLW",
          clean_sheet: { home: 3, away: 1, total: 4 },
          lineups: [
            { formation: "4-3-3", played: 9 },
            { formation: "3-4-3", played: 2 },
            { formation: "4-4-2", played: 1 },
          ],
        },
      },
      away: {
        id: SPURS,
        name: "Tottenham",
        league: {
          form: "WWLLDWWL",
          clean_sheet: { home: 1, away: 1, total: 2 },
          lineups: [
            { formation: "4-3-3", played: 3 },
            { formation: "4-2-3-1", played: 7 },
            { formation: null, played: 2 },
            { formation: "5-3-2", played: 0 },
          ],
        },
      },
    },
    // Deliberately out of date order, as the feed serves it, and with one
    // unplayed meeting that has no score.
    h2h: [
      meeting(1, "2025-10-18T14:00:00+00:00", "Arsenal", "Tottenham", 2, 1),
      meeting(2, "2018-05-06T11:30:00+00:00", "Tottenham", "Arsenal", 0, 0),
      meeting(3, "2026-03-01T16:30:00+00:00", "Arsenal", "Tottenham", 2, 1),
      meeting(4, "2024-04-28T13:00:00+00:00", "Tottenham", "Arsenal", 3, 2),
      meeting(5, "2023-09-24T13:00:00+00:00", "Arsenal", "Tottenham", 2, 2),
      meeting(6, "2023-01-15T16:30:00+00:00", "Tottenham", "Arsenal", 0, 2),
      { fixture: { id: 7, date: "2026-12-01T15:00:00+00:00" }, teams: { home: {}, away: {} }, goals: { home: null, away: null } },
    ],
  }],
};

const spursStyle: ClubStyleRow = {
  set_piece: true,
  counter: false,
  aerial: null,
  long_range: null,
  close_range: null,
  attacks_side: "right",
  verified_at: "2026-09-23",
};

Deno.test("buildMatchupCard: the frozen shape, from the focal club's side", () => {
  const card = buildMatchupCard({
    payload,
    fixtureId: 1387422,
    ourApiId: ARSENAL,
    opponentName: "Tottenham",
    style: spursStyle,
    updatedAt: "2026-09-23T10:00:00Z",
  })!;

  assertEquals(card.fixture_id, 1387422);
  assertEquals(card.opponent, "Tottenham");
  // Last five of a season-long form string, not the whole thing.
  assertEquals(card.our_form, "WWDLW");
  assertEquals(card.their_form, "LDWWL");
  assertEquals(card.our_clean_sheets, 4);
  assertEquals(card.their_clean_sheets, 2);
  // Most-used first, nulls and never-used dropped, capped at two.
  assertEquals(card.their_formations, ["4-2-3-1", "4-3-3"]);
  assertEquals(card.favourite, "us");
  assertEquals(card.style, {
    set_piece: true,
    counter: false,
    aerial: false,
    long_range: false,
    close_range: false,
    attacks_side: "right",
    verified_at: "2026-09-23",
  });
});

Deno.test("buildMatchupCard: h2h is newest-first, five at most, scored only", () => {
  const card = buildMatchupCard({
    payload,
    fixtureId: 1,
    ourApiId: ARSENAL,
    opponentName: "Tottenham",
    style: null,
    updatedAt: "2026-09-23T10:00:00Z",
  })!;
  assertEquals(card.h2h.length, 5);
  assertEquals(card.h2h.map((m) => m.date), [
    "2026-03-01",
    "2025-10-18",
    "2024-04-28",
    "2023-09-24",
    "2023-01-15",
  ]);
  assertEquals(card.h2h[0], {
    date: "2026-03-01",
    home: "Arsenal",
    away: "Tottenham",
    score: "2-1",
  });
});

Deno.test("buildMatchupCard: the betting numbers never come through", () => {
  const card = buildMatchupCard({
    payload,
    fixtureId: 1,
    ourApiId: ARSENAL,
    opponentName: "Tottenham",
    style: null,
    updatedAt: "2026-09-23T10:00:00Z",
  })!;
  const json = JSON.stringify(card);
  assertEquals(json.includes("62%"), false);
  assertEquals(json.includes("Double chance"), false);
  assertEquals(Object.keys(card).sort(), [
    "favourite",
    "fixture_id",
    "h2h",
    "opponent",
    "our_clean_sheets",
    "our_form",
    "style",
    "their_clean_sheets",
    "their_form",
    "their_formations",
    "updated_at",
  ]);
});

Deno.test("buildMatchupCard: read from the other club's page, everything flips", () => {
  const card = buildMatchupCard({
    payload,
    fixtureId: 1,
    ourApiId: SPURS,
    opponentName: "Arsenal",
    style: null,
    updatedAt: "2026-09-23T10:00:00Z",
  })!;
  assertEquals(card.our_form, "LDWWL");
  assertEquals(card.their_form, "WWDLW");
  assertEquals(card.our_clean_sheets, 2);
  assertEquals(card.favourite, "them");
});

Deno.test("buildMatchupCard: no style row claims nothing", () => {
  const card = buildMatchupCard({
    payload,
    fixtureId: 1,
    ourApiId: ARSENAL,
    opponentName: "Tottenham",
    style: null,
    updatedAt: "2026-09-23T10:00:00Z",
  })!;
  assertEquals(card.style, {
    set_piece: false,
    counter: false,
    aerial: false,
    long_range: false,
    close_range: false,
    attacks_side: null,
    verified_at: null,
  });
});

Deno.test("buildMatchupCard: a payload naming neither of us builds nothing", () => {
  assertEquals(
    buildMatchupCard({
      payload,
      fixtureId: 1,
      ourApiId: 999,
      opponentName: "Someone",
      style: null,
      updatedAt: "2026-09-23T10:00:00Z",
    }),
    null,
  );
  assertEquals(
    buildMatchupCard({
      payload: { response: [] },
      fixtureId: 1,
      ourApiId: ARSENAL,
      opponentName: "Tottenham",
      style: null,
      updatedAt: "2026-09-23T10:00:00Z",
    }),
    null,
  );
});

Deno.test("buildMatchupCard: no named winner is even", () => {
  const noWinner = JSON.parse(JSON.stringify(payload));
  noWinner.response[0].predictions.winner = null;
  assertEquals(
    buildMatchupCard({
      payload: noWinner,
      fixtureId: 1,
      ourApiId: ARSENAL,
      opponentName: "Tottenham",
      style: null,
      updatedAt: "2026-09-23T10:00:00Z",
    })!.favourite,
    "even",
  );
});

// ── Which fixture the predictions call is bought for ────────────────────────

const fixtures = (...rows: Array<[number, string]>) => ({
  response: rows.map(([id, date]) => ({ fixture: { id, date } })),
});

Deno.test("nextFixtureIdForPredictions: the first one that has not kicked off", () => {
  const now = new Date("2026-09-23T10:00:00Z");
  assertEquals(
    nextFixtureIdForPredictions(
      fixtures([1, "2026-09-27T15:00:00+00:00"], [2, "2026-10-04T15:00:00+00:00"]),
      now,
    ),
    1,
  );
  // response[0] already under way: the page wants the next one, so buy that.
  assertEquals(
    nextFixtureIdForPredictions(
      fixtures([1, "2026-09-23T09:00:00+00:00"], [2, "2026-09-27T15:00:00+00:00"]),
      now,
    ),
    2,
  );
});

Deno.test("nextFixtureIdForPredictions: nothing to buy", () => {
  const now = new Date("2026-09-23T10:00:00Z");
  assertEquals(nextFixtureIdForPredictions({ response: [] }, now), null);
  assertEquals(nextFixtureIdForPredictions(null, now), null);
  assertEquals(nextFixtureIdForPredictions({}, now), null);
  assertEquals(
    nextFixtureIdForPredictions(fixtures([1, "2026-09-20T15:00:00+00:00"]), now),
    null,
  );
});
