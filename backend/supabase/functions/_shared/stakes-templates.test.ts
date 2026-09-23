// Deno tests for post_match best-third tone branches.
//   deno test backend/supabase/functions/_shared/stakes-templates.test.ts

import {
  renderClubPostMatch,
  renderClubPreMatch,
  renderClubThisWeek,
  renderNextFixturePreview,
  renderOpponentDetail,
  renderPostMatch,
  renderThisWeek,
} from "./stakes-templates.ts";
import { type FixtureStakes, groupSituation, type GroupStanding } from "./stakes-engine.ts";
import { CLUB_FAVORITE_GAP, clubPreMatchVerdict, preMatchVerdict } from "./matchup-verdict.ts";

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

// ---- live / just-finished copy (team-page live-game bug) ----

function liveStakes(reason: "in_progress" | "just_finished"): FixtureStakes {
  const live = reason === "in_progress";
  return {
    date: "2026-06-17T20:00:00+00:00",
    opponent: "Croatia",
    venue: "home",
    importance_dots: live ? 4 : 2,
    importance_label: live ? "Live now" : "Full time",
    stakes_level: live ? "decisive" : "qualified_already",
    reason,
    certainty: "soft",
  };
}

const noDashes = (s: string) => !/[—–]/.test(s);

Deno.test("next_fixture preview: in_progress names the live game, no opener framing, no dashes", () => {
  const t = renderNextFixturePreview({
    teamName: "England",
    opponentName: "Croatia",
    groupLabel: "Group L",
    stakes: liveStakes("in_progress"),
  });
  assert(/playing Croatia/i.test(t), "names the live game");
  assert(!/first game|open Group/i.test(t), "no opener framing");
  assert(noDashes(t), "no em/en dashes");
});

Deno.test("this_week: in_progress is present-tense about the live game, not the next one", () => {
  const r = renderThisWeek({
    teamName: "England",
    opponentName: "Croatia",
    groupLabel: "Group L",
    stakes: liveStakes("in_progress"),
  });
  assert(/playing Croatia right now/i.test(r.text), "present-tense live framing");
  assert(!/first game/i.test(r.text), "no false 'first game' claim (the bug)");
  assert(/Croatia/.test(r.talking_point), "talking point is about the live game");
  assert(noDashes(r.text + r.talking_point), "no em/en dashes");
});

Deno.test("just_finished: result-just-in framing, never claims 'first game'", () => {
  const preview = renderNextFixturePreview({
    teamName: "England",
    opponentName: "Croatia",
    groupLabel: "Group L",
    stakes: liveStakes("just_finished"),
  });
  const week = renderThisWeek({
    teamName: "England",
    opponentName: "Croatia",
    groupLabel: "Group L",
    stakes: liveStakes("just_finished"),
  });
  assert(/just finished|just played/i.test(preview + week.text), "just-finished framing");
  assert(!/first game/i.test(preview + week.text), "no opener claim");
  assert(noDashes(preview + week.text + week.talking_point), "no em/en dashes");
});

Deno.test("the open-group branch no longer says one thing to everybody", () => {
  // 111 of 158 World Cup matchday cards carried the same sentence because this
  // branch ignored the result it was handed.
  const base = {
    teamName: "Sweden",
    opponentName: "Japan",
    situation: { state: "in_contention", stakes_level: "decisive", reason: "in_contention", certainty: "soft" },
  } as unknown as Parameters<typeof renderPostMatch>[0];
  const seen = new Set<string>();
  for (const [ts, os, st] of [[3, 0, "win"], [2, 1, "win"], [0, 3, "loss"], [1, 2, "loss"], [1, 1, "draw"]] as const) {
    seen.add(
      renderPostMatch({ ...base, teamScore: ts, oppScore: os, state: st }).talking_point,
    );
  }
  assert(seen.size >= 4, `only ${seen.size} distinct talking points across 5 different results`);
  for (const tp of seen) {
    assert(tp !== "Ask him what they need from their next game.", "the old catch-all is back");
  }
});

// ============================================================
// CLUB pre game talk (renderClubPreMatch / renderClubThisWeek)
// ============================================================

function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

/// House rules every club string has to pass: no em-dashes, and the preview
/// talks about two clubs, never about "him".
function assertHouseRules(preview: string, label: string): void {
  assert(!/[–—―−]/.test(preview), `${label}: no em/en dashes`);
  assert(preview.length < 700, `${label}: under 700 chars (was ${preview.length})`);
  assert(!/\b(he|him|his)\b/i.test(preview), `${label}: the preview never says he/him/his`);
  assert(preview.trim().endsWith("."), `${label}: ends in a full stop`);
  const sentences = preview.split(". ").length;
  assert(sentences >= 2 && sentences <= 4, `${label}: two to four sentences (was ${sentences})`);
}

Deno.test("renderClubPreMatch: league game, both clubs in the table", () => {
  const out = renderClubPreMatch({
    teamName: "Arsenal",
    opponentName: "Sunderland",
    venue: "home",
    competition: "Premier League",
    round: "",
    myPosition: 3,
    oppPosition: 12,
    myPoints: 20,
    oppPoints: 11,
    myForm: "WWDLW",
    oppForm: "LDLLW",
    favorite: preMatchVerdict(3, 12, CLUB_FAVORITE_GAP),
  });
  assertHouseRules(out.preview, "league");
  assert(out.preview.includes("in the Premier League"), "names the competition");
  assert(out.preview.includes("at home to Sunderland"), "names the venue and opponent");
  assert(
    out.preview.includes("3rd against 12th in the table, nine points between them"),
    `positions and the gap in words: ${out.preview}`,
  );
  assert(out.preview.includes("Arsenal go into it as the favourites"), "the verdict in words");
  assert(
    out.talking_point.includes("3rd against 12th"),
    `the talking point uses the same fact: ${out.talking_point}`,
  );
  assert(/\bhim\b/.test(out.talking_point), "the talking point is addressed to her about him");
});

Deno.test("renderClubPreMatch: cup tie against a club with no rank", () => {
  const out = renderClubPreMatch({
    teamName: "Sunderland",
    opponentName: "Hull City",
    venue: "home",
    competition: "League Cup (Carabao Cup)",
    round: "last 32",
    // A club outside the division has no league position and no strength_rank,
    // so there is no favourite to name and the card must not invent one.
    myPosition: null,
    oppPosition: null,
    myForm: "WWD",
    favorite: null,
    knockoutLine: "Through to the last 16.",
  });
  assertHouseRules(out.preview, "cup");
  assert(
    out.preview.includes("League Cup (Carabao Cup), last 32"),
    `competition and round: ${out.preview}`,
  );
  assert(!/favourite/.test(out.preview), "no favourite claimed without ranks");
  assert(
    out.preview.includes("A win takes Sunderland through to the last 16."),
    `what a win wins: ${out.preview}`,
  );
  assert(out.preview.includes("their last three"), "form counts only the games played");
  assert(
    out.talking_point.includes("reaching the last 16"),
    `talking point follows the stake: ${out.talking_point}`,
  );
});

Deno.test("renderClubPreMatch: European night, opponent from another league", () => {
  const out = renderClubPreMatch({
    teamName: "Arsenal",
    opponentName: "Napoli",
    venue: "away",
    competition: "Champions League",
    // A league-phase round has no label, and nothing is settled on the night.
    round: "",
    myPosition: null,
    oppPosition: null,
    myForm: "WWDLW",
    oppForm: null,
    favorite: null,
    knockoutLine: "Champions League.",
  });
  assertHouseRules(out.preview, "europe");
  assert(out.preview.includes("away at Napoli in the Champions League."), out.preview);
  assert(!/takes them through/.test(out.preview), "a league phase settles nothing");
  eq(out.talking_point, "Ask him how he is feeling about the Napoli game.", "neutral fallback");
});

Deno.test("renderClubPreMatch: level on points, and a lone win reads singular", () => {
  const out = renderClubPreMatch({
    teamName: "Everton",
    opponentName: "Brentford",
    venue: "away",
    competition: "Premier League",
    myPosition: 9,
    oppPosition: 10,
    myPoints: 14,
    oppPoints: 14,
    myForm: "LDLLW",
    oppForm: "LLLLL",
    favorite: preMatchVerdict(9, 10, CLUB_FAVORITE_GAP),
  });
  assertHouseRules(out.preview, "level");
  assert(out.preview.includes("level on points"), out.preview);
  assert(out.preview.includes("with one win in their last five"), out.preview);
  assert(out.preview.includes("Brentford without a win in their last five"), out.preview);
  assert(out.preview.includes("close enough to go either way"), out.preview);
});

Deno.test("renderClubPreMatch: never runs past four sentences", () => {
  // A cup tie between two clubs in the same table has an opening, a table
  // sentence, a form sentence, a verdict AND a stake. The form goes.
  const out = renderClubPreMatch({
    teamName: "Arsenal",
    opponentName: "Sunderland",
    venue: "home",
    competition: "FA Cup",
    round: "quarter-final",
    myPosition: 1,
    oppPosition: 14,
    myPoints: 40,
    oppPoints: 18,
    myForm: "WWWWW",
    oppForm: "LLDLL",
    favorite: preMatchVerdict(1, 14, CLUB_FAVORITE_GAP),
    knockoutLine: "Through to the semi-finals.",
  });
  assertHouseRules(out.preview, "five-fact");
  assert(!/come in with/.test(out.preview), `form dropped, not the stake: ${out.preview}`);
  assert(out.preview.includes("A win takes Arsenal through to the semi-finals."), out.preview);
});

Deno.test("renderClubThisWeek: league vocabulary, its own talking point", () => {
  const ctx = {
    teamName: "Arsenal",
    opponentName: "Sunderland",
    venue: "home" as const,
    competition: "Premier League",
    myPosition: 3,
    oppPosition: 12,
    myPoints: 20,
    oppPoints: 11,
    favorite: preMatchVerdict(3, 12, CLUB_FAVORITE_GAP),
  };
  const week = renderClubThisWeek(ctx);
  const talk = renderClubPreMatch(ctx);
  assert(week.text.startsWith("Premier League this week: Arsenal are at home to Sunderland."), week.text);
  assert(!/[–—―−]/.test(week.text + week.talking_point), "no em dashes");
  assert(
    week.talking_point !== talk.talking_point,
    "the two cards render together, so they must not say the same line twice",
  );
});

Deno.test("renderClubPreMatch: a domestic cup tie says which table, and one point is no favourite", () => {
  // Chelsea v Leeds, League Cup last 32, 2026-09-09: the live card read "4th
  // against 9th in the table, a point between them. Chelsea go into it as the
  // favourites." Two errors in two sentences.
  const out = renderClubPreMatch({
    teamName: "Chelsea",
    opponentName: "Leeds United",
    venue: "home",
    competition: "League Cup (Carabao Cup)",
    round: "last 32",
    tableLabel: "in the league",
    myPosition: 4,
    oppPosition: 9,
    myPoints: 6,
    oppPoints: 5,
    myForm: "WDL",
    oppForm: "LWD",
    favorite: clubPreMatchVerdict(4, 9, 6, 5),
    knockoutLine: "Through to the last 16.",
  });
  assertHouseRules(out.preview, "cup-two-tables");
  assert(out.preview.includes("4th against 9th in the league, a point between them"), out.preview);
  assert(!/favourite/.test(out.preview), `no favourite on one point: ${out.preview}`);
  assert(out.preview.includes("close enough to go either way"), out.preview);
});

Deno.test("renderClubPreMatch: form is labelled as league form", () => {
  // Bournemouth, 2026-09-09: PL form DDL, a 4-0 League Cup win the night before.
  const out = renderClubPreMatch({
    teamName: "AFC Bournemouth",
    opponentName: "Brentford",
    venue: "home",
    competition: "Premier League",
    myPosition: 15,
    oppPosition: 5,
    myPoints: 2,
    oppPoints: 5,
    myForm: "DDL",
    oppForm: "WWD",
    favorite: clubPreMatchVerdict(15, 5, 2, 5),
  });
  assert(
    out.preview.includes("without a win in their last three league games"),
    `the window is named: ${out.preview}`,
  );
  assert(!/favourite/.test(out.preview), `three points, ten places: still no favourite: ${out.preview}`);
});


// ============================================================
// renderClubPostMatch — the club after-match card
// ============================================================

function cpm(over: Partial<Parameters<typeof renderClubPostMatch>[0]> = {}) {
  return renderClubPostMatch({
    teamName: "Arsenal", opponentName: "Tottenham", venue: "home",
    teamScore: 2, oppScore: 1, state: "win",
    competition: "Premier League",
    ...over,
  });
}

Deno.test("club post_match: a league win is the result, the ground and nothing invented", () => {
  const r = cpm();
  assert(r.text === "Arsenal beat Tottenham 2-1 at home in the Premier League.", r.text);
  assert(r.state === "win", "state passes through");
});

Deno.test("club post_match: never claims a run, however tempting", () => {
  // cards.form.recent_form has no defined order (it is partly a Claude
  // tool-call field), so a run folded in from it could be false. The card
  // states what it saw.
  for (const r of [cpm(), cpm({ state: "loss", teamScore: 0, oppScore: 3 })]) {
    assert(!/(in their last|straight|without a win)/i.test(r.text), `no run claim: ${r.text}`);
  }
});

Deno.test("club post_match: never says he or him in the body, always in the talking point", () => {
  for (const r of [cpm(), cpm({ state: "loss", teamScore: 0, oppScore: 3 }),
                   cpm({ state: "draw", teamScore: 1, oppScore: 1 })]) {
    assert(!/\b(he|him|his)\b/i.test(r.text), `body addresses the clubs: ${r.text}`);
    assert(/\b(he|him|his)\b/i.test(r.talking_point), `talking point is about him: ${r.talking_point}`);
    assert(!/—/.test(r.text + r.talking_point), "no em-dashes");
  }
});

Deno.test("club post_match: an away draw and a home draw read differently", () => {
  const home = cpm({ state: "draw", teamScore: 1, oppScore: 1, venue: "home" });
  const away = cpm({ state: "draw", teamScore: 1, oppScore: 1, venue: "away" });
  assert(/drew 1-1 with Tottenham at home/.test(home.text), home.text);
  assert(/drew 1-1 with Tottenham away/.test(away.text), away.text);
  assert(/two dropped/.test(home.talking_point), home.talking_point);
  assert(/would have taken that/.test(away.talking_point), away.talking_point);
});

Deno.test("club post_match: a heavy defeat is given room, a one-goal defeat is not", () => {
  const heavy = cpm({ state: "loss", teamScore: 0, oppScore: 4 });
  const narrow = cpm({ state: "loss", teamScore: 1, oppScore: 2 });
  assert(/Give him a minute/.test(heavy.talking_point), heavy.talking_point);
  assert(/A goal in it/.test(narrow.talking_point), narrow.talking_point);
});

Deno.test("club post_match: a settled cup tie states what it settled", () => {
  const through = cpm({
    competition: "League Cup (Carabao Cup)", round: "last 32",
    knockoutLine: "Through to the last 16.",
  });
  assert(/in the League Cup \(Carabao Cup\), last 32\./.test(through.text), through.text);
  assert(/Through to the last 16\./.test(through.text), through.text);
  assert(/who he wants to draw in the last 16/.test(through.talking_point), through.talking_point);

  const out = cpm({
    state: "loss", teamScore: 0, oppScore: 1,
    competition: "FA Cup", round: "3rd round", knockoutLine: "Out of the FA Cup.",
  });
  assert(/Out of the FA Cup\./.test(out.text), out.text);
  assert(/run is over/.test(out.talking_point), out.talking_point);
});

Deno.test("club post_match: a first leg settles nothing and says nothing", () => {
  // match-watcher passes knockoutLine only when isSingleLegTie says the night
  // decides it. Absent, the card must not imply progression either way.
  const leg1 = cpm({
    competition: "Champions League", round: "last 16",
    knockoutLine: null,
  });
  assert(!/(through|out of)/i.test(leg1.text), `no progression claim: ${leg1.text}`);
});

Deno.test("club post_match: a shootout win is a win, not a draw", () => {
  const pens = cpm({
    state: "win", teamScore: 1, oppScore: 1,
    competition: "FA Cup", round: "4th round",
    shootout: { mine: 4, theirs: 3 }, knockoutLine: "Through to the fifth round.",
  });
  assert(/beat Tottenham 4-3 on penalties after a 1-1 draw/.test(pens.text), pens.text);
  assert(!/drew/.test(pens.text), "never 'drew' after a shootout");

  const lost = cpm({
    state: "loss", teamScore: 1, oppScore: 1,
    competition: "FA Cup", shootout: { mine: 3, theirs: 4 }, knockoutLine: "Out of the FA Cup.",
  });
  assert(/lost to Tottenham 4-3 on penalties/.test(lost.text), lost.text);
});

Deno.test("club post_match: extra time is named", () => {
  const aet = cpm({ afterExtraTime: true, competition: "FA Cup" });
  assert(/after extra time\./.test(aet.text), aet.text);
});
