// Deno tests for the WC goal-push helpers.
//   deno test backend/supabase/functions/_shared/goal-push.test.ts

import {
  attachScorerPhotos,
  detectGoal,
  formatMinute,
  formatScorerLine,
  formatScorers,
  ftSituation,
  type GoalEvent,
  htSituation,
  interpolate,
  pickLatestGoalForTeam,
  renderFullTimePush,
  renderGoalPush,
  renderExtraTimePush,
  renderHalfTimePush,
  shootoutNote,
  tableLine,
  withDeepLine,
  renderKickoffSoonPush,
  seededRng,
  type StoredGoalEvent,
  withSaying,
  toStoredGoalEvents,
  hasUnresolvedScorer,
  reconcileGoalEvents,
} from "./goal-push.ts";
import {
  FT_COPY,
  GOAL_BOTH,
  GOAL_CONCEDED,
  GOAL_SCORED,
  HT_COPY,
  KICKOFF_SOON,
} from "./goal-push-copy.ts";
import { WC_COUNTRY_META } from "./wc-countries.ts";

/// What withSaying makes of a body with rng zero: the first line to say.
const said = (body: string, pool: readonly string[]) => `${body} Say: \u201C${pool[0]}\u201D`;

const MEX = { id: "mexico", name: "Mexico", flag: "🇲🇽" };
const RSA = { id: "south_africa", name: "S. Africa", flag: "🇿🇦" };
const JPN = { id: "japan", name: "Japan", flag: "🇯🇵" };
const NED = { id: "netherlands", name: "Netherlands", flag: "🇳🇱" };

// Deterministic rng so a test knows which pool entry was chosen (index 0).
const zero = () => 0;

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

// ============================================================
// detectGoal (unchanged behavior)
// ============================================================

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
  eq(detectGoal(1, 0, 0, 1), "away", "swap: disallowed home + scored away");
});

// ============================================================
// interpolate
// ============================================================

Deno.test("interpolate: fills present tokens, drops absent ones, tidies spacing", () => {
  eq(
    interpolate("{flag} {team} score! {score}.", { flag: "🇲🇽", team: "Mexico", score: "2-0" }),
    "🇲🇽 Mexico score! 2-0.",
    "all tokens",
  );
  // An absent token leaves no double space behind.
  eq(interpolate("{team} score, {score}.", { score: "2-0" }), "score, 2-0.", "absent {team} tidied");
});

Deno.test("renderGoalPush: PL club with empty flag renders clean copy (no leading space)", () => {
  // Clubs have no emoji flag (match-watcher liveMeta → flag ""); every body
  // must still start with a letter, never a space or a stray "{flag}".
  const ARS = { id: "arsenal", name: "Arsenal", flag: "" };
  const CHE = { id: "chelsea", name: "Chelsea", flag: "" };
  const copy = renderGoalPush({ home: ARS, away: CHE, homeGoals: 1, awayGoals: 0, side: "home", rng: zero });
  for (const slug of ["arsenal", "chelsea"]) {
    const body = copy.bodies[slug];
    assert(body.length > 0 && /^[A-Za-z0-9]/.test(body), `${slug} body starts clean: ${JSON.stringify(body)}`);
    assert(!body.includes("{flag}") && !body.includes("  "), `${slug} body tidy: ${body}`);
    assert(body.includes("Arsenal"), `${slug} body names the scorer: ${body}`);
  }
});

// ============================================================
// renderGoalPush perspective routing (rng:zero pins pool index 0)
// ============================================================

Deno.test("renderGoalPush: each side gets its own title and fact, her club first", () => {
  const copy = renderGoalPush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0, side: "home", rng: zero });
  eq(copy.title, "GOAL: Mexico 2-0 S. Africa", "neutral title stays home-away");
  eq(copy.titles?.mexico, "GOAL: Mexico 2-0 S. Africa", "scorer's title");
  eq(copy.titles?.south_africa, "GOAL: S. Africa 0-2 Mexico", "conceder's title, her club first");
  eq(copy.bodies.mexico, "Mexico lead 2-0.", "scored, ahead");
  eq(copy.bodies.south_africa, "Mexico score. S. Africa trail 0-2.", "conceded, behind");
});

Deno.test("renderGoalPush: an away equaliser reads level for both, never '1-1 to' anyone", () => {
  const copy = renderGoalPush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 1, side: "away", rng: zero });
  eq(copy.bodies.south_africa, "S. Africa equalise. 1-1.", "away scorer");
  eq(copy.bodies.mexico, "S. Africa equalise. 1-1.", "home conceder");
  const pull = renderGoalPush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 1, side: "away", rng: zero });
  eq(pull.bodies.south_africa, "S. Africa pull one back. 1-2.", "still behind, score her-first");
  eq(pull.bodies.mexico, "S. Africa pull one back. Mexico still lead 2-1.", "still ahead");
  for (const b of [...Object.values(copy.bodies), ...Object.values(pull.bodies)]) {
    assert(!/\d+-\d+ to\b/.test(b), `no "x-y to Team": ${b}`);
  }
});

Deno.test("renderGoalPush: 'both' reads from each side's own state", () => {
  const copy = renderGoalPush({ home: JPN, away: NED, homeGoals: 2, awayGoals: 1, side: "both", rng: zero });
  eq(copy.bodies.japan, "Goals at both ends. Japan lead 2-1.", "leader");
  eq(copy.bodies.netherlands, "Goals at both ends. Netherlands trail 1-2.", "trailer");
});

// ============================================================
// Half-time and full-time: situation, then a line to say
// ============================================================

/// A stored goal: side, minute, optional stoppage.
const g = (side: "home" | "away", minute: number, extra: number | null = null): StoredGoalEvent =>
  ({ side, player: null, minute, extra, isOwnGoal: false, isPenalty: false });

Deno.test("renderHalfTimePush: each side gets its own situation, score follower-first", () => {
  const copy = renderHalfTimePush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0, rng: zero });
  eq(copy.title, "Half-time: Mexico 2-0 S. Africa", "title carries home-away scoreline");
  eq(copy.titles?.south_africa, "Half-time: S. Africa 0-2 Mexico", "her club first");
  eq(copy.bodies.mexico, said("Mexico are 2-0 up at the break.", HT_COPY.ahead_big.say), "leader");
  eq(copy.bodies.south_africa, said("S. Africa are 0-2 down at the break.", HT_COPY.behind_big.say), "trailer");
});

Deno.test("htSituation: by goal difference, and 0-0 is not a 1-1", () => {
  eq(htSituation(2, 0), "ahead_big", "2-0");
  eq(htSituation(1, 0), "ahead_one", "1-0");
  eq(htSituation(0, 0), "nil_nil", "0-0");
  eq(htSituation(1, 1), "level_goals", "1-1");
  eq(htSituation(0, 1), "behind_one", "0-1");
  eq(htSituation(1, 4), "behind_big", "1-4");
});

Deno.test("ftSituation: plain results by margin", () => {
  eq(ftSituation({ mine: 3, theirs: 1 }).situation, "win_plain", "3-1, not known when it was decided");
  eq(ftSituation({ mine: 2, theirs: 0, goals: [g("home", 20), g("home", 60)], ctx: { side: "home" } }).situation,
    "win_big", "decided in the 20th minute");
  eq(ftSituation({ mine: 2, theirs: 0, goals: [g("home", 86), g("home", 90, 2)], ctx: { side: "home" } }).situation,
    "win_late", "decided in the 86th: never 'easy in the end'");
  eq(ftSituation({ mine: 3, theirs: 1, goals: [g("home", 10), g("away", 50), g("home", 118), g("home", 120)], ctx: { side: "home" }, extraTime: true }).situation,
    "win_plain", "after extra time");
  eq(ftSituation({ mine: 1, theirs: 0 }).situation, "win_narrow", "1-0");
  eq(ftSituation({ mine: 0, theirs: 0 }).situation, "draw_nil", "0-0");
  eq(ftSituation({ mine: 2, theirs: 2 }).situation, "draw_goals", "2-2");
  eq(ftSituation({ mine: 1, theirs: 2 }).situation, "loss_narrow", "1-2");
  eq(ftSituation({ mine: 0, theirs: 2 }).situation, "loss_big", "0-2");
});

Deno.test("ftSituation: late goals from the goal list, minute in words", () => {
  const winLate = ftSituation({ mine: 2, theirs: 1, goals: [g("home", 10), g("away", 50), g("home", 88)], ctx: { side: "home" } });
  eq(winLate.situation, "win_late", "88' winner");
  eq(winLate.when, "in the 88th minute", "minute in words");
  const stoppage = ftSituation({ mine: 1, theirs: 0, goals: [g("home", 90, 4)], ctx: { side: "home" } });
  eq(stoppage.when, "in stoppage time", "90+4 is stoppage time");
  // Away side of the same game: lost it late.
  eq(ftSituation({ mine: 1, theirs: 2, goals: [g("home", 10), g("away", 50), g("home", 88)], ctx: { side: "away" } }).situation,
    "loss_late", "the other side lost it late");
  // A late goal that only padded the lead decides nothing.
  eq(ftSituation({ mine: 3, theirs: 1, goals: [g("home", 10), g("away", 20), g("home", 60), g("home", 89)], ctx: { side: "home" } }).situation,
    "win_big", "late third goal is not a late winner");
  eq(ftSituation({ mine: 1, theirs: 1, goals: [g("home", 10), g("away", 87)], ctx: { side: "home" } }).situation,
    "draw_late_against", "pegged back late");
  eq(ftSituation({ mine: 1, theirs: 1, goals: [g("home", 10), g("away", 87)], ctx: { side: "away" } }).situation,
    "draw_late_for", "rescued it late");
});

Deno.test("ftSituation: no late claim without a complete goal list or after extra time", () => {
  eq(ftSituation({ mine: 2, theirs: 1, goals: [g("home", 88)], ctx: { side: "home" } }).situation,
    "win_narrow", "one goal missing from the list: plain result");
  eq(ftSituation({ mine: 2, theirs: 1, goals: null, ctx: { side: "home" } }).situation, "win_narrow", "no list");
  eq(ftSituation({ mine: 2, theirs: 1, goals: [g("home", 10), g("away", 50), g("home", 118)], ctx: { side: "home" }, extraTime: true }).situation,
    "win_narrow", "a 118' winner after extra time is not 'late' in this sense");
});

Deno.test("ftSituation: comeback needs a half-time deficit; a late winner reads first", () => {
  eq(ftSituation({ mine: 2, theirs: 1, ctx: { side: "home", ht: { mine: 0, theirs: 1 } } }).situation, "win_comeback", "behind at HT");
  eq(ftSituation({ mine: 2, theirs: 1, ctx: { side: "home", ht: { mine: 1, theirs: 1 } } }).situation, "win_narrow", "level at HT");
  eq(ftSituation({ mine: 2, theirs: 1, ctx: { side: "home", ht: null } }).situation, "win_narrow", "unknown HT");
  eq(ftSituation({
    mine: 2, theirs: 1, goals: [g("away", 30), g("home", 60), g("home", 89)], ctx: { side: "home", ht: { mine: 0, theirs: 1 } },
  }).situation, "win_late", "late winner beats comeback");
});

Deno.test("ftSituation: a settled tie wins over the scoreline, and a shootout settles one", () => {
  eq(ftSituation({ mine: 1, theirs: 0, ctx: { side: "home", cup: "through" } }).situation, "cup_through", "through");
  eq(ftSituation({ mine: 0, theirs: 1, ctx: { side: "home", cup: "out" } }).situation, "cup_out", "out");
  eq(ftSituation({ mine: 2, theirs: 1, ctx: { side: "home", cup: "won" } }).situation, "cup_won", "final");
  eq(ftSituation({ mine: 1, theirs: 1, pens: { mine: 4, theirs: 2 } }).situation, "cup_through", "shootout won");
  eq(ftSituation({ mine: 1, theirs: 1, pens: { mine: 2, theirs: 4 } }).situation, "cup_out", "shootout lost");
});

Deno.test("renderFullTimePush: comeback and cup bodies, clause before the line to say", () => {
  const comeback = renderFullTimePush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 1, ht: { home: 0, away: 1 }, rng: zero });
  eq(comeback.bodies.mexico, said("Behind at the break and won it 2-1.", FT_COPY.win_comeback.say), "comeback");
  eq(comeback.bodies.south_africa, said("Lost 1-2.", FT_COPY.loss_narrow.say), "the other side");
  const cup = renderFullTimePush({
    home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, rng: zero,
    cupBySide: { mexico: "through", south_africa: "out" },
    competitionBySide: { mexico: "Through to the last 16.", south_africa: "Out of the League Cup." },
  });
  eq(cup.bodies.mexico, said("Won 1-0. Through to the last 16.", FT_COPY.cup_through.say), "through");
  eq(cup.bodies.south_africa, said("Lost 0-1. Out of the League Cup.", FT_COPY.cup_out.say), "out");
});

Deno.test("renderFullTimePush: shootout reads the pens, never 'drew'", () => {
  const copy = renderFullTimePush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 1, pens: { home: 4, away: 2 }, rng: zero });
  eq(copy.title, "Full-time: Mexico 1-1 S. Africa (4-2 on pens)", "title carries goals + shootout");
  eq(copy.titles?.south_africa, "Full-time: S. Africa 1-1 Mexico (2-4 on pens)", "her club and her shootout score first");
  eq(copy.bodies.mexico, said("Won 4-2 on penalties.", FT_COPY.cup_through.say), "shootout winner");
  eq(copy.bodies.south_africa, said("Lost 2-4 on penalties.", FT_COPY.cup_out.say), "shootout loser");
  const nullPens = renderFullTimePush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 1, pens: null, rng: zero });
  eq(nullPens.title, "Full-time: Mexico 1-1 S. Africa", "null pens = unchanged title");
  eq(nullPens.bodies.mexico, said("Finished 1-1.", FT_COPY.draw_goals.say), "null pens = draw");
});

// ============================================================
// renderKickoffSoonPush (30-min nudge) — names each follower's own team
// ============================================================

Deno.test("renderKickoffSoonPush: each side's body names its own team + opponent", () => {
  const copy = renderKickoffSoonPush({ home: MEX, away: RSA, rng: zero });
  eq(copy.title, "Kickoff soon: Mexico v S. Africa", "title is the factual fixture");
  eq(copy.bodies.mexico, interpolate(KICKOFF_SOON[0], { team: "Mexico", opp: "S. Africa" }), "home names Mexico");
  eq(copy.bodies.south_africa, interpolate(KICKOFF_SOON[0], { team: "S. Africa", opp: "Mexico" }), "away names S. Africa");
});

Deno.test("KICKOFF_SOON pool: unique, <=90 chars, no em/en dashes, names team + opp", () => {
  assert(new Set(KICKOFF_SOON).size === KICKOFF_SOON.length, "no duplicate lines");
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const longest = [...names].sort((a, b) => b.length - a.length)[0];
  for (const template of KICKOFF_SOON) {
    const body = interpolate(template, { team: longest, opp: longest });
    assert(body.length > 0, `non-empty: ${template}`);
    assert(body.length <= 90, `<=90 chars (got ${body.length}): ${body}`);
    assert(!body.includes("—") && !body.includes("–"), `no em/en dash: ${body}`);
  }
});

// ============================================================
// Goal pools: one fact, room for the scorer lead, nothing about him
// ============================================================

Deno.test("GOAL pools: every line fits behind the longest scorer lead, carries the score, no him", () => {
  for (const [name, pools] of [["GOAL_SCORED", GOAL_SCORED], ["GOAL_CONCEDED", GOAL_CONCEDED], ["GOAL_BOTH", GOAL_BOTH]] as const) {
    for (const [state, pool] of Object.entries(pools)) {
      assert(pool.length >= 1 && new Set(pool).size === pool.length, `${name}.${state}: unique lines`);
      for (const line of pool) {
        // Longest lead "Calvert-Lewin 90+3' (pen). " is 27 chars; 27 + 63 = 90.
        const body = interpolate(line, { team: "Nottm Forest", opp: "Crystal Palace", score: "10-10" });
        assert(body.length <= 63, `${name}: ${body.length} chars is too long for a lead: ${body}`);
        assert(body.includes("10-10"), `${name}: carries the score: ${body}`);
        assert(!/[\u2013\u2014]/.test(body), `${name}: no dashes: ${body}`);
        assert(!/\b(he|his|him)\b/i.test(body), `${name}: about him: ${body}`);
      }
    }
  }
});

// ============================================================
// Titles stay factual + bounded, no em/en dashes
// ============================================================

Deno.test("titles carry the scoreline, stay bounded, no em/en dashes", () => {
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const [a, b] = [...names].sort((x, y) => y.length - x.length).slice(0, 2);
  const home = { id: "a", name: a, flag: "🏳️" };
  const away = { id: "b", name: b, flag: "🏳️" };
  const titles = [
    renderGoalPush({ home, away, homeGoals: 10, awayGoals: 10, side: "home", rng: zero }),
    renderHalfTimePush({ home, away, homeGoals: 10, awayGoals: 10, rng: zero }),
    renderFullTimePush({ home, away, homeGoals: 10, awayGoals: 10, rng: zero }),
  ].flatMap((c) => [c.title, ...Object.values(c.titles ?? {})]);
  for (const t of titles) {
    assert(t.length <= 50, `title bounded (got ${t.length}): ${t}`);
    assert(t.includes("10-10"), `title carries the score: ${t}`);
    assert(!t.includes("—") && !t.includes("–"), `no em/en dash: ${t}`);
  }
});

// ============================================================
// A2: scorer + minute enrichment (formatMinute / formatScorerLine /
// pickLatestGoalForTeam / renderGoalPush scorerLine weaving)
// ============================================================

function ev(p: Partial<GoalEvent>): GoalEvent {
  return {
    teamApiId: 1,
    playerName: null,
    minute: null,
    extra: null,
    isOwnGoal: false,
    isPenalty: false,
    ...p,
  };
}

Deno.test("formatMinute: plain, stoppage, and unknown", () => {
  eq(formatMinute(47, null), "47'", "plain minute");
  eq(formatMinute(45, 2), "45+2'", "stoppage time");
  eq(formatMinute(90, 0), "90'", "extra 0 is not shown");
  eq(formatMinute(null, null), "", "unknown minute → empty");
  eq(formatMinute(90, null), "90'", "no extra");
});

Deno.test("formatScorerLine: normal goal names player + minute", () => {
  eq(formatScorerLine(ev({ playerName: "Pedri", minute: 47 })), "Pedri 47'.", "normal goal");
});

Deno.test("formatScorerLine: penalty tagged (pen)", () => {
  eq(
    formatScorerLine(ev({ playerName: "H. Kane", minute: 90, extra: 3, isPenalty: true })),
    "H. Kane 90+3' (pen).",
    "penalty in stoppage",
  );
});

Deno.test("formatScorerLine: own goal omits the (opposing-team) player name", () => {
  // API names the own-goal scorer from the CONCEDING side; surfacing that name
  // on the celebrating side's push would mislead. Label only.
  eq(
    formatScorerLine(ev({ playerName: "J. Stones", minute: 23, isOwnGoal: true })),
    "Own goal 23'.",
    "own goal labelled, player dropped",
  );
  eq(formatScorerLine(ev({ minute: null, isOwnGoal: true })), "Own goal.", "own goal, no minute");
});

Deno.test("formatScorerLine: graceful partials and null", () => {
  eq(formatScorerLine(ev({ playerName: "Vinicius", minute: null })), "Vinicius.", "name only");
  eq(formatScorerLine(ev({ playerName: null, minute: 60 })), "Goal 60'.", "minute only");
  eq(formatScorerLine(ev({ playerName: "  ", minute: null })), null, "no fact → null");
  eq(formatScorerLine(null), null, "null event → null");
});

Deno.test("pickLatestGoalForTeam: latest goal of the scoring side", () => {
  const events: GoalEvent[] = [
    ev({ teamApiId: 10, playerName: "Early", minute: 12 }),
    ev({ teamApiId: 20, playerName: "OtherTeam", minute: 80 }),
    ev({ teamApiId: 10, playerName: "Latest", minute: 67 }),
    ev({ teamApiId: 10, playerName: "Stoppage", minute: 67, extra: 2 }),
  ];
  const picked = pickLatestGoalForTeam(events, 10);
  eq(picked?.playerName, "Stoppage", "highest minute+extra for team 10");
  eq(pickLatestGoalForTeam(events, 99)?.playerName ?? null, null, "no goal for absent team");
  eq(pickLatestGoalForTeam([], 10), null, "empty array → null");
  eq(pickLatestGoalForTeam(null, 10), null, "null events → null");
});

Deno.test("toStoredGoalEvents: tags side from API ids, sorts chronologically", () => {
  const events: GoalEvent[] = [
    ev({ teamApiId: 20, playerName: "Away2", minute: 80 }),
    ev({ teamApiId: 10, playerName: "Home1", minute: 12, isPenalty: true }),
    ev({ teamApiId: 10, playerName: "HomeStoppage", minute: 45, extra: 2 }),
    ev({ teamApiId: 10, playerName: "HomeLevel", minute: 45 }),
  ];
  const stored = toStoredGoalEvents(events, 10, 20);
  eq(stored.length, 4, "all events for the two sides kept");
  eq(stored[0].player, "Home1", "min 12 first");
  eq(stored[0].side, "home", "home id → home side");
  eq(stored[0].isPenalty, true, "penalty preserved");
  eq(stored[1].player, "HomeLevel", "min 45 (no stoppage) before 45+2");
  eq(stored[2].player, "HomeStoppage", "45+2 after 45");
  eq(stored[3].side, "away", "away id → away side");
});

Deno.test("toStoredGoalEvents: drops events for neither side; tolerant of empty", () => {
  const events: GoalEvent[] = [
    ev({ teamApiId: 99, playerName: "Ghost", minute: 10 }),
    ev({ teamApiId: 10, playerName: "Real", minute: 20 }),
  ];
  const stored = toStoredGoalEvents(events, 10, 20);
  eq(stored.length, 1, "event for an unrelated team id is dropped");
  eq(stored[0].player, "Real", "only the matching-side event survives");
  eq(toStoredGoalEvents([], 10, 20).length, 0, "empty array → []");
  eq(toStoredGoalEvents(null, 10, 20).length, 0, "null → []");
});

Deno.test("attachScorerPhotos: table value wins, id-only falls back to CDN URL, no id → null", () => {
  const stored = toStoredGoalEvents(
    [
      ev({ teamApiId: 10, playerName: "Pedri", playerApiId: 777, minute: 47 }),
      ev({ teamApiId: 20, playerName: "NoRow", playerApiId: 888, minute: 60 }),
      ev({ teamApiId: 20, playerName: "NoId", minute: 70 }),
    ],
    10,
    20,
  );
  eq(stored[0].playerApiId, 777, "playerApiId carried into stored events");
  const enriched = attachScorerPhotos(stored, new Map([[777, "https://cdn/pedri.png"]]));
  eq(enriched[0].photo, "https://cdn/pedri.png", "matched id gets the table photo");
  // id present but no players row → deterministic CDN URL (the players backfill
  // can miss a player; a valid id still yields a valid face URL).
  eq(enriched[1].photo, "https://media.api-sports.io/football/players/888.png", "id-only → CDN fallback");
  eq(enriched[2].photo, null, "event without a player id → null");
  eq(attachScorerPhotos(null, new Map()).length, 0, "null events → []");
  // Photo survives into the display scorers iOS reads (key name `photo`).
  const scorers = formatScorers(enriched, "Spain", "France");
  eq(scorers[0].photo, "https://cdn/pedri.png", "photo flows into DisplayScorer");
  eq(scorers[1].photo, "https://media.api-sports.io/football/players/888.png", "fallback flows into DisplayScorer");
});

Deno.test("formatScorers: own goal drops the (wrong-side) photo with the name", () => {
  const enriched = attachScorerPhotos(
    toStoredGoalEvents(
      [ev({ teamApiId: 10, playerName: "Wrong Side", playerApiId: 5, minute: 23, isOwnGoal: true })],
      10,
      20,
    ),
    new Map([[5, "https://cdn/wrong.png"]]),
  );
  const scorers = formatScorers(enriched, "Spain", "France");
  eq(scorers[0].player, "Own goal", "name dropped for own goal");
  eq(scorers[0].photo, null, "photo dropped for own goal");
});

Deno.test("renderGoalPush: scorerLine LEADS both bodies, additive", () => {
  const withScorer = renderGoalPush({
    home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", scorerLine: "Pedri 47'.", rng: zero,
  });
  const without = renderGoalPush({
    home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", rng: zero,
  });
  // The scorer line leads; the rotating-copy body follows unchanged.
  assert(withScorer.bodies.mexico.endsWith(without.bodies.mexico), "scorer body keeps rotating copy");
  assert(withScorer.bodies.mexico.startsWith("Pedri 47'. "), "scorer body opens with the fact");
  assert(withScorer.bodies.south_africa.startsWith("Pedri 47'. "), "conceder body also opens with the fact");
  // Null / empty scorerLine is a clean no-op (fallback path).
  eq(
    renderGoalPush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", scorerLine: null, rng: zero }).bodies.mexico,
    without.bodies.mexico,
    "null scorerLine = unchanged copy",
  );
});

Deno.test("seededRng: the same fixture and score draw the same line", () => {
  const a = renderGoalPush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", rng: seededRng(4200 * 100 + 10) });
  const b = renderGoalPush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", rng: seededRng(4200 * 100 + 10) });
  eq(a.bodies.mexico, b.bodies.mexico, "deterministic for one (fixture, score)");
  const r = seededRng(7);
  for (let i = 0; i < 1000; i++) {
    const x = r();
    assert(x >= 0 && x < 1, "in [0,1)");
  }
});

Deno.test("HT/FT copy: house rules on every line, and every body fits with its line to say", () => {
  const all = [...Object.values(HT_COPY), ...Object.values(FT_COPY)];
  for (const c of all) {
    assert(c.say.length >= 4, `a situation with fewer than 4 lines to say: "${c.say[0]}"`);
    assert(c.body.length >= 2, `a situation with one body: "${c.body[0]}"`);
    for (const line of [...c.say, ...c.body]) {
      assert(!line.includes("\u2014") && !line.includes("\u2013"), `dash in "${line}"`);
      // The pools serve cup ties too, where there are no points.
      assert(!/\bpoints?\b/i.test(line), `"${line}" talks about points`);
      // His mood was the old body; it is gone on purpose (2026-10-29).
      assert(!/\b(he|him|his)\b/i.test(line), `"${line}" is about him`);
    }
    for (const line of c.say) assert(line.length <= 60, `"${line}" is too long to sit behind a situation line`);
  }
  // An opinion about the game, never comfort or an order (LOCK-02-05).
  for (const c of Object.values(FT_COPY)) {
    for (const line of c.say) {
      assert(!/forget|move on|never mind|enjoy (every|that)|shake it off|happy for you|champagne|easy in the end|next one\b/i.test(line),
        `"${line}" consoles or steers`);
    }
  }
  // Worst case: longest body, longest names, a two-digit score, a long clause.
  const clause = "Through to the quarter-finals.";
  for (const c of all) {
    const body = [...c.body].sort((x, y) => y.length - x.length)[0]
      .replace("{team}", "Nottingham Forest").replace("{score}", "10-10")
      .replace("{when}", "in the 88th minute").replace("{how}", " after extra time");
    const longestSay = [...c.say].sort((x, y) => y.length - x.length)[0];
    assert(`${body} ${clause} Say: \u201C${longestSay}\u201D`.length <= 178, `"${body}" + "${longestSay}" overflow the lock screen`);
  }
  const long = "x".repeat(200);
  eq(withSaying(long, HT_COPY.level_goals.say, zero), `Say: \u201C${HT_COPY.level_goals.say[0]}\u201D`, "the situation line goes first");
});

Deno.test("renderExtraTimePush: the same plain fact for both sides, within budget", () => {
  const home = { id: "nottingham_forest", name: "Nottingham Forest", flag: "" };
  const away = { id: "wolves", name: "Wolves", flag: "" };
  const c = renderExtraTimePush({ home, away, goals: 1 });
  eq(c.title, "Extra time: Nottingham Forest 1-1 Wolves", "");
  eq(c.bodies.nottingham_forest, "1-1 after 90, so another 30 minutes. Penalties if it's still level.", "");
  eq(c.bodies.wolves, c.bodies.nottingham_forest, "");
  assert(c.bodies.wolves.length <= 178, "fits the lock screen");
  assert(!/[\u2013\u2014]/.test(c.bodies.wolves + c.title), "no dashes");
});

Deno.test("shootoutNote: running score during, the winner named after, nothing without data", () => {
  eq(shootoutNote("P", { home: 4, away: 3 }, "Fleetwood Town", "Arsenal"), "Shootout: 4-3", "");
  eq(shootoutNote("PEN", { home: 5, away: 3 }, "Fleetwood Town", "Arsenal"), "Fleetwood Town win 5-3 on penalties", "");
  eq(shootoutNote("PEN", { home: 2, away: 4 }, "Fleetwood Town", "Arsenal"), "Arsenal win 4-2 on penalties", "");
  eq(shootoutNote("P", { home: null, away: null }, "A", "B"), null, "");
  eq(shootoutNote("FT", { home: 5, away: 3 }, "A", "B"), null, "");
  eq(shootoutNote("P", null, "A", "B"), null, "");
});

Deno.test("tableLine: where the results leave a club, silent when it cannot know", () => {
  const rows = [
    { apiId: 1, rank: 1, points: 20, gd: 10, gf: 20 },
    { apiId: 2, rank: 2, points: 18, gd: 8, gf: 15 },
    { apiId: 3, rank: 3, points: 17, gd: 5, gf: 12 },
    { apiId: 4, rank: 4, points: 15, gd: 2, gf: 10 },
  ];
  eq(tableLine(rows, [{ home: 4, away: 3, hg: 2, ag: 0 }], 4), "Up to 3rd.", "a win lifts them");
  eq(tableLine(rows, [{ home: 4, away: 3, hg: 2, ag: 0 }], 3), "Down to 4th.", "the loser drops");
  eq(tableLine(rows, [{ home: 1, away: 2, hg: 1, ag: 1 }], 1), "Still 1st.", "a draw at the top");
  // Two games at once: both applied.
  eq(tableLine(rows, [{ home: 4, away: 1, hg: 3, ag: 0 }, { home: 3, away: 2, hg: 2, ag: 0 }], 2), "Down to 3rd.", "");
  eq(tableLine(rows, [{ home: 4, away: 99, hg: 1, ag: 0 }], 4), null, "a club not in the table");
  eq(tableLine(rows, [], 99), null, "not in the table");
  // Level on points, goal difference and goals with a neighbour: no claim.
  const tied = [{ apiId: 1, rank: 1, points: 10, gd: 2, gf: 5 }, { apiId: 2, rank: 2, points: 10, gd: 2, gf: 5 }];
  eq(tableLine(tied, [], 2), null, "head-to-head decides it");
});

Deno.test("withDeepLine: before the line to say, and only if it fits", () => {
  eq(withDeepLine("Won 2-0. Say: \u201CJob done.\u201D", "Up to 4th."), "Won 2-0. Up to 4th. Say: \u201CJob done.\u201D", "");
  eq(withDeepLine("Won 2-0.", "Up to 4th."), "Won 2-0. Up to 4th.", "no line to say");
  eq(withDeepLine("Won 2-0.", undefined), "Won 2-0.", "nothing to add");
  const long = "x".repeat(170);
  eq(withDeepLine(long, "Up to 4th."), long, "never past the lock screen");
});

// Bug hunt 2026-11-03, P-C1: Chelsea 2-0 Man Utd (1557450). Estêvão's 71' was
// ruled out after its scorer was stored; the list kept three goals and the
// After card showed "3–0 Chelsea" under a 2-0.
Deno.test("reconcileGoalEvents: a ruled-out goal leaves the stored list", () => {
  const ev = (side: "home" | "away", minute: number, playerApiId: number) =>
    ({ side, player: "x", playerApiId, minute, extra: null, isOwnGoal: false, isPenalty: false });
  const stored = [ev("home", 50, 19170), ev("home", 64, 152982), ev("home", 71, 425733)];
  assert(hasUnresolvedScorer(stored, 2), "a list longer than the score is re-fetched");
  eq(reconcileGoalEvents(stored, 2, 0).map((e) => e.minute).join(), "50,64", "the latest goal of that side goes");
  eq(reconcileGoalEvents(stored, 3, 0).length, 3, "a list that fits is unchanged");
  eq(reconcileGoalEvents(stored, 0, 0).length, 0, "every goal ruled out");
  // Per side: an away goal never pays for a home goal ruled out.
  const mixed = [ev("home", 10, 1), ev("away", 20, 2), ev("home", 30, 3)];
  eq(reconcileGoalEvents(mixed, 1, 1).map((e) => e.minute).join(), "10,20", "home's second goes, away's stays");
  // Short lists stay short: the feed lags, the re-fetch fills them in.
  eq(reconcileGoalEvents([ev("home", 10, 1)], 2, 1).length, 1, "short list kept");
  assert(hasUnresolvedScorer([ev("home", 10, 1)], 2), "short list re-fetched");
  assert(!hasUnresolvedScorer([ev("home", 10, 1)], 1), "exact list with ids is resolved");
  assert(hasUnresolvedScorer([{ ...ev("home", 10, 1), playerApiId: null }], 1), "anonymous scorer re-fetched");
  assert(hasUnresolvedScorer(null, 1) && !hasUnresolvedScorer(null, 0), "no list");
});
