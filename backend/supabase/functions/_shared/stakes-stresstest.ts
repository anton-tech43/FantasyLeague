// Stress-test harness for the WC group-stage notification copy.
// Drives the REAL engine + templates through a battery of scenarios and
// prints exactly what would be generated. Pure functions — no DB, no APNs.
//   deno run backend/supabase/functions/_shared/stakes-stresstest.ts

import {
  annotateFixtures,
  groupSituation,
  type GroupStanding,
  type UpcomingGroupFixture,
} from "./stakes-engine.ts";
import { renderNextFixturePreview, renderThisWeek, renderPostMatch } from "./stakes-templates.ts";
import { renderConsequence } from "./consequence-templates.ts";
import type { Consequence, ConsequenceType } from "./detect-consequences.ts";
import type { Team } from "./types.ts";

const ids: Record<string, number> = { Sweden: 1, Tunisia: 2, Croatia: 3, Panama: 4 };
function grp(pts: Record<string, [number, number]>): GroupStanding[] {
  return Object.entries(pts).map(([name, [points, played]]) => ({
    teamApiId: ids[name], teamName: name, points, played,
  }));
}
function fxAgainst(name: string, date = "2026-06-20T17:00:00+00:00"): UpcomingGroupFixture {
  return { date, opponentApiId: ids[name], opponentName: name, venue: "home" };
}
const line = (s = "") => console.log(s);
const rule = () => line("─".repeat(78));

// ════════════════════════════════════════════════════════════════
line("\n████ SECTION 1 — Per-fixture stakes, next_fixture preview, this_week ████");
line("(followed team = SWEDEN, group with Tunisia / Croatia / Panama)\n");

type S1 = { name: string; group: GroupStanding[]; next: string };
const s1: S1[] = [
  { name: "Pre-tournament (no games played)",
    group: grp({ Sweden: [0,0], Tunisia: [0,0], Croatia: [0,0], Panama: [0,0] }), next: "Tunisia" },
  { name: "MD3 decider — a DRAW sends Sweden through",
    group: grp({ Sweden: [4,2], Tunisia: [1,2], Croatia: [4,2], Panama: [1,2] }), next: "Tunisia" },
  { name: "MD3 — only a WIN sends Sweden through",
    group: grp({ Sweden: [4,2], Tunisia: [1,2], Croatia: [2,2], Panama: [2,2] }), next: "Tunisia" },
  { name: "MD3 — must not lose (a loss kills top-2, win not yet guaranteed)",
    group: grp({ Sweden: [3,2], Tunisia: [0,2], Croatia: [4,2], Panama: [4,2] }), next: "Tunisia" },
  { name: "Already THROUGH, win can top the group",
    group: grp({ Sweden: [6,2], Tunisia: [1,2], Croatia: [4,2], Panama: [1,2] }), next: "Tunisia" },
  { name: "Already THROUGH, dead rubber (placement fixed)",
    group: grp({ Sweden: [6,2], Tunisia: [6,2], Croatia: [1,2], Panama: [1,2] }), next: "Croatia" },
  { name: "GROUP WON already (1st locked)",
    group: grp({ Sweden: [6,2], Tunisia: [0,2], Croatia: [0,2], Panama: [0,2] }), next: "Tunisia" },
  { name: "Top-2 GONE (best-third long shot — soft, never asserts 'out')",
    group: grp({ Sweden: [0,2], Tunisia: [6,2], Croatia: [4,2], Panama: [4,2] }), next: "Tunisia" },
];

for (const sc of s1) {
  rule();
  line("▶ " + sc.name);
  line("  table: " + sc.group.map((t) => `${t.teamName} ${t.points}pt/${t.played}`).join("  "));
  const [stk] = annotateFixtures(sc.group, ids.Sweden, [fxAgainst(sc.next)]);
  line(`  fixture stakes : ${"●".repeat(stk.importance_dots)}${"○".repeat(5 - stk.importance_dots)} "${stk.importance_label}"  [${stk.stakes_level}/${stk.reason}/${stk.certainty}]`);
  line(`  next_fixture   : ${renderNextFixturePreview({ teamName: "Sweden", opponentName: sc.next, groupLabel: "Group F", stakes: stk })}`);
  const tw = renderThisWeek({ teamName: "Sweden", opponentName: sc.next, groupLabel: "Group F", stakes: stk, otherFixtureLabel: "Croatia meet Panama" });
  line(`  this_week      : ${tw.text}`);
  line(`  talking_point  : ${tw.talking_point}`);
}

// ════════════════════════════════════════════════════════════════
line("\n\n████ SECTION 2 — post_match cards (tone follows the RESULT + situation) ████\n");
type S2 = { name: string; group: GroupStanding[]; tg: number; tn: number; opp: string };
const s2: S2[] = [
  { name: "Win → through to the knockouts", group: grp({ Sweden: [6,3], Tunisia: [3,3], Croatia: [3,2], Panama: [1,3] }), tg: 2, tn: 0, opp: "Panama" },
  { name: "Win → group WON", group: grp({ Sweden: [9,3], Tunisia: [4,3], Croatia: [4,3], Panama: [0,3] }), tg: 2, tn: 1, opp: "Croatia" },
  { name: "Loss → top-2 gone (MUTED, never 'enjoy it')", group: grp({ Sweden: [1,3], Tunisia: [7,3], Croatia: [6,3], Panama: [4,3] }), tg: 0, tn: 2, opp: "Tunisia" },
  { name: "Draw → still in contention", group: grp({ Sweden: [2,2], Tunisia: [2,2], Croatia: [2,2], Panama: [2,2] }), tg: 1, tn: 1, opp: "Croatia" },
];
for (const sc of s2) {
  const state = sc.tg > sc.tn ? "win" : sc.tg < sc.tn ? "loss" : "draw";
  const pm = renderPostMatch({ teamName: "Sweden", opponentName: sc.opp, teamScore: sc.tg, oppScore: sc.tn, state, situation: groupSituation(sc.group, ids.Sweden) });
  rule();
  line(`▶ ${sc.name}  (Sweden ${sc.tg}-${sc.tn} ${sc.opp}, state=${pm.state})`);
  line(`  text          : ${pm.text}`);
  line(`  talking_point : ${pm.talking_point}`);
}

// ════════════════════════════════════════════════════════════════
line("\n\n████ SECTION 3 — push notifications (rival-result + cross-team consequences) ████");
line("(this is the actual lock-screen copy; lengths checked against caps push_title≤35 / push_text≤90)\n");
function team(name: string): Team {
  return { id: name.toLowerCase(), display_name: name, api_football_id: 0, short_name: name };
}
function showPush(label: string, type: ConsequenceType, teamName: string, trigger: string) {
  const c: Consequence = { team_id: teamName.toLowerCase(), consequence_type: type, trigger_summary: trigger };
  const r = renderConsequence(c, team(teamName));
  const tFlag = r.push_title.length > 35 ? "  ⚠️OVER35" : "";
  const xFlag = r.push_text.length > 90 ? "  ⚠️OVER90" : "";
  rule();
  line(`▶ ${label}  [${type}]`);
  line(`  push_title (${r.push_title.length}): ${r.push_title}${tFlag}`);
  line(`  push_text  (${r.push_text.length}): ${r.push_text}${xFlag}`);
  line(`  body       : ${r.body}`);
}
showPush("Rival result — decisive win", "WC_RIVAL_RESULT", "Sweden", "Croatia beat Panama 3-0");
showPush("Rival result — draw", "WC_RIVAL_RESULT", "Sweden", "Tunisia could only draw 1-1 at Panama");
showPush("Rival result — long team name", "WC_RIVAL_RESULT", "South Korea", "Germany beat Switzerland 2-1");
showPush("Rival result — longest name", "WC_RIVAL_RESULT", "Bosnia and Herzegovina", "Brazil beat Serbia 4-0");
showPush("Group won", "WC_GROUP_WON", "Sweden", "Croatia could only draw 1-1 at Panama");
showPush("Knockout qualified", "WC_KNOCKOUT_QUALIFIED", "Brazil", "Brazil beat Cameroon 2-0");
line("\n--- worst case: longest country name + longest (draw) trigger ---");
showPush("Group won (worst case)", "WC_GROUP_WON", "Bosnia and Herzegovina", "Switzerland could only draw 1-1 at Cameroon");
showPush("Knockout qualified (worst case)", "WC_KNOCKOUT_QUALIFIED", "Bosnia and Herzegovina", "Switzerland could only draw 1-1 at Cameroon");
showPush("Rival result (worst case)", "WC_RIVAL_RESULT", "Bosnia and Herzegovina", "Switzerland could only draw 1-1 at Cameroon");

line("\n✅ stress test complete\n");
