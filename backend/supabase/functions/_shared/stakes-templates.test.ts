// Deno tests for post_match best-third tone branches.
//   deno test backend/supabase/functions/_shared/stakes-templates.test.ts

import { renderOpponentDetail, renderPostMatch } from "./stakes-templates.ts";
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

Deno.test("opponent detail: manager + players with positions + descriptions, names the away side", () => {
  const r = renderOpponentDetail("Tunisia", {
    manager: "Sabri Lamouchi",
    players: [
      { name: "Hannibal Mejbri", position: "midfielder", oneLiner: "Man Utd academy playmaker." },
      { name: "Ellyes Skhiri", position: "midfielder", oneLiner: "Captain and engine room." },
    ],
  });
  assert(/Tunisia are managed by Sabri Lamouchi\./.test(r), "names opponent + manager");
  assert(/Their ones to watch:/.test(r), "ones-to-watch header");
  assert(/Hannibal Mejbri \(midfielder\): Man Utd academy playmaker\./.test(r), "player has position + description");
  assert(/Ellyes Skhiri \(midfielder\): Captain and engine room\./.test(r), "second player too");
  assert(!/—|–/.test(r), "no em/en dashes");
});

Deno.test("opponent detail: degrades (no description, no position, no manager, none)", () => {
  // No one-liner (token-stripped upstream) → name + position only.
  assert(/Arda Güler \(midfielder\)$/m.test(
    renderOpponentDetail("Türkiye", { manager: "V. Montella", players: [{ name: "Arda Güler", position: "midfielder" }] }),
  ), "player line is name + position when no description");
  // No position → bare name.
  assert(/^Kane$/m.test(
    renderOpponentDetail("England", { players: [{ name: "Kane" }] }),
  ), "bare name when no position/description/manager");
  assert(renderOpponentDetail("X", null) === "", "null info → empty string (caller appends unconditionally)");
  assert(renderOpponentDetail("Y", { players: [] }) === "", "no manager + no players → empty string");
});
