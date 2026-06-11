// Deno tests for post_match best-third tone branches.
//   deno test backend/supabase/functions/_shared/stakes-templates.test.ts

import { renderOpponentBlurb, renderPostMatch } from "./stakes-templates.ts";
import { groupSituation, type GroupStanding } from "./stakes-engine.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}

// A group where focal (id 1) is top-2 gone (0 pts, two rivals on 6/4 etc.).
const gone: GroupStanding[] = [
  { teamApiId: 1, teamName: "A", points: 0, played: 3 },
  { teamApiId: 2, teamName: "B", points: 9, played: 3 },
  { teamApiId: 3, teamName: "C", points: 6, played: 3 },
  { teamApiId: 4, teamName: "D", points: 3, played: 3 },
];
const situation = groupSituation(gone, 1); // state: top2_gone

function pm(bestThird?: { status: "guaranteed_in" | "out" | "soft"; reason: string }) {
  return renderPostMatch({
    teamName: "Sweden", opponentName: "Tunisia", teamScore: 0, oppScore: 2,
    state: "loss", situation, bestThird,
  });
}

Deno.test("post_match: best-third guaranteed_in → upbeat 'through as a best third'", () => {
  const r = pm({ status: "guaranteed_in", reason: "points_locked_in" });
  assert(/best third-placed teams/i.test(r.text), "upbeat through copy");
  assert(!/out of the tournament/i.test(r.text), "not 'out'");
});

Deno.test("post_match: best-third out → definitive 'out of the tournament' (muted)", () => {
  const r = pm({ status: "out", reason: "points_locked_out" });
  assert(/out of the tournament/i.test(r.text), "definitive out");
  assert(/over/i.test(r.talking_point), "kind sign-off");
});

Deno.test("post_match: best-third pending (soft/undefined) → honest 'still in play'", () => {
  const soft = pm({ status: "soft", reason: "gd_bubble" });
  assert(/still in play/i.test(soft.text), "soft → still in play");
  const none = pm(undefined);
  assert(/still in play/i.test(none.text), "undefined → still in play");
  assert(!/enjoy/i.test(none.text + none.talking_point), "never says 'enjoy it'");
});

Deno.test("opponent blurb: manager + two danger men, names the away side", () => {
  const r = renderOpponentBlurb("Tunisia", { manager: "Sami Trabelsi", dangerMen: ["Hannibal Mejbri", "Ellyes Skhiri"] });
  assert(/Tunisia are managed by Sami Trabelsi/.test(r), "names opponent + manager");
  assert(/Hannibal Mejbri and Ellyes Skhiri the ones to watch/.test(r), "both danger men");
  assert(!/—|–/.test(r), "no em/en dashes");
});

Deno.test("opponent blurb: degrades (one man, manager-only, players-only, none)", () => {
  assert(/Arda Güler the one to watch/.test(
    renderOpponentBlurb("Türkiye", { manager: "V. Montella", dangerMen: ["Arda Güler"] }),
  ), "singular 'one to watch'");
  assert(renderOpponentBlurb("Panama", { dangerMen: [] }) === "", "manager+players empty → empty string");
  assert(/Keep an eye on Pulisic for USA\./.test(
    renderOpponentBlurb("USA", { dangerMen: ["Pulisic"] }),
  ), "players-only branch");
  assert(renderOpponentBlurb("X", null) === "", "null info → empty string (caller appends unconditionally)");
});
