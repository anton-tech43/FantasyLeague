// Deno tests for the WC goal-push helpers.
//   deno test backend/supabase/functions/_shared/goal-push.test.ts

import {
  detectGoal,
  renderFullTimePush,
  renderGoalPush,
  renderHalfTimePush,
} from "./goal-push.ts";
import { WC_COUNTRY_META } from "./wc-countries.ts";

const MEX = { id: "mexico", name: "Mexico", flag: "🇲🇽" };
const RSA = { id: "south_africa", name: "S. Africa", flag: "🇿🇦" };

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

Deno.test("detectGoal: home / away / both / none", () => {
  eq(detectGoal(0, 0, 1, 0), "home", "home goal");
  eq(detectGoal(1, 0, 1, 1), "away", "away goal");
  eq(detectGoal(0, 0, 1, 1), "both", "two goals between ticks");
  eq(detectGoal(2, 1, 2, 1), null, "no change");
});

Deno.test("detectGoal: null prior (pre-kickoff row) counts as 0", () => {
  eq(detectGoal(null, null, 1, 0), "home", "first goal vs null prior");
  eq(detectGoal(undefined, undefined, 0, 0), null, "0-0 vs null prior is no goal");
});

Deno.test("detectGoal: VAR overturn (decrease) never pushes", () => {
  eq(detectGoal(1, 0, 0, 0), null, "home goal disallowed");
  eq(detectGoal(2, 1, 2, 0), null, "away goal disallowed");
  // decrease one side + increase other in the same tick → only the increase counts
  eq(detectGoal(1, 0, 0, 1), "away", "swap: disallowed home + scored away");
});

Deno.test("renderGoalPush: perspective bodies keyed by country slug", () => {
  const copy = renderGoalPush({
    home: { id: "mexico", name: "Mexico", flag: "🇲🇽" },
    away: { id: "south_africa", name: "S. Africa", flag: "🇿🇦" },
    homeGoals: 2,
    awayGoals: 0,
    side: "home",
  });
  eq(copy.title, "GOAL: Mexico 2-0 S. Africa", "unified title");
  assert(copy.bodies.mexico.includes("score!"), "scorer side celebrates");
  assert(copy.bodies.south_africa.includes("just scored"), "conceding side is muted");
  assert(copy.bodies.mexico.length <= 90 && copy.bodies.south_africa.length <= 90, "bodies ≤90 chars");
});

Deno.test("renderGoalPush: 'both' gives the same neutral body to both sides", () => {
  const copy = renderGoalPush({
    home: { id: "japan", name: "Japan", flag: "🇯🇵" },
    away: { id: "netherlands", name: "Netherlands", flag: "🇳🇱" },
    homeGoals: 1,
    awayGoals: 1,
    side: "both",
  });
  eq(copy.bodies.japan, copy.bodies.netherlands, "same body both sides");
  assert(copy.bodies.japan.includes("1-1"), "score present");
});

Deno.test("renderGoalPush: title ≤35 chars for the longest META names; no em-dashes anywhere", () => {
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const longest = [...names].sort((a, b) => b.length - a.length).slice(0, 2);
  const copy = renderGoalPush({
    home: { id: "a", name: longest[0], flag: "🏳️" },
    away: { id: "b", name: longest[1], flag: "🏳️" },
    homeGoals: 10, // worst-case score width
    awayGoals: 10,
    side: "home",
  });
  assert(copy.title.length <= 35, `title fits 35 chars (got ${copy.title.length}: ${copy.title})`);
  const all = copy.title + Object.values(copy.bodies).join(" ");
  assert(!all.includes("—") && !all.includes("–"), "no em/en dashes");
});

Deno.test("renderHalfTimePush: perspective flips leading / trailing, score follower-first", () => {
  const copy = renderHalfTimePush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0 });
  eq(copy.title, "Half-time: Mexico 2-0 S. Africa", "title carries home-away scoreline");
  assert(copy.bodies.mexico.startsWith("Up 2-0"), "leader sees 'Up 2-0'");
  assert(copy.bodies.south_africa.startsWith("Down 0-2"), "trailer sees their score first");
});

Deno.test("renderHalfTimePush: level scoreline gives both sides the same body", () => {
  const copy = renderHalfTimePush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 1 });
  eq(copy.bodies.mexico, copy.bodies.south_africa, "level: identical body");
  assert(copy.bodies.mexico.startsWith("Level 1-1"), "level framing");
});

Deno.test("renderFullTimePush: win / loss flip by follower perspective", () => {
  const copy = renderFullTimePush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0 });
  eq(copy.title, "Full-time: Mexico 2-0 S. Africa", "title carries the scoreline");
  assert(copy.bodies.mexico.startsWith("Win! 2-0"), "winner sees a win");
  assert(copy.bodies.south_africa.includes("lost 0-2"), "loser sees their score first");
});

Deno.test("renderFullTimePush: draw gives both sides the same body", () => {
  const copy = renderFullTimePush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 1 });
  eq(copy.bodies.mexico, copy.bodies.south_africa, "draw: identical body");
  assert(copy.bodies.mexico.includes("draw"), "draw framing");
});

Deno.test("HT/FT pushes: bodies ≤90 chars, titles bounded, no em/en dashes", () => {
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const longest = [...names].sort((a, b) => b.length - a.length).slice(0, 2);
  const home = { id: "a", name: longest[0], flag: "🏳️" };
  const away = { id: "b", name: longest[1], flag: "🏳️" };
  for (const copy of [
    renderHalfTimePush({ home, away, homeGoals: 3, awayGoals: 1 }),
    renderFullTimePush({ home, away, homeGoals: 3, awayGoals: 1 }),
  ]) {
    assert(copy.title.length <= 45, `title bounded (got ${copy.title.length}: ${copy.title})`);
    for (const b of Object.values(copy.bodies)) {
      assert(b.length <= 90, `body ≤90 chars (got ${b.length}: ${b})`);
    }
    const all = copy.title + Object.values(copy.bodies).join(" ");
    assert(!all.includes("—") && !all.includes("–"), "no em/en dashes");
  }
});
