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
  renderKickoffSoonPush,
  seededRng,
  type StoredGoalEvent,
  withSaying,
  toStoredGoalEvents,
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

Deno.test("renderGoalPush: scorer pool to scorer slug, conceder pool to conceder slug", () => {
  const copy = renderGoalPush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0, side: "home", rng: zero });
  eq(copy.title, "GOAL: Mexico 2-0 S. Africa", "title carries home-away scoreline");
  const vars = { flag: MEX.flag, team: MEX.name, score: "2-0" };
  eq(copy.bodies.mexico, interpolate(GOAL_SCORED[0], vars), "scorer body from GOAL_SCORED");
  eq(copy.bodies.south_africa, interpolate(GOAL_CONCEDED[0], vars), "conceder body from GOAL_CONCEDED");
});

Deno.test("renderGoalPush: side away flips which slug gets the scorer pool", () => {
  const copy = renderGoalPush({ home: MEX, away: RSA, homeGoals: 0, awayGoals: 1, side: "away", rng: zero });
  const vars = { flag: RSA.flag, team: RSA.name, score: "0-1" };
  eq(copy.bodies.south_africa, interpolate(GOAL_SCORED[0], vars), "away scorer body");
  eq(copy.bodies.mexico, interpolate(GOAL_CONCEDED[0], vars), "home conceder body references the scorer");
});

Deno.test("renderGoalPush: 'both' shares one neutral body across both slugs", () => {
  const copy = renderGoalPush({ home: JPN, away: NED, homeGoals: 1, awayGoals: 1, side: "both", rng: zero });
  const body = interpolate(GOAL_BOTH[0], { home: "Japan", away: "Netherlands", score: "1-1" });
  eq(copy.bodies.japan, body, "japan body from GOAL_BOTH");
  eq(copy.bodies.netherlands, body, "same neutral body both sides");
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
  eq(ftSituation({ mine: 3, theirs: 1 }).situation, "win_big", "3-1");
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
// Pool integrity + safety sweep across all 360 variants
// ============================================================

const POOLS: Record<string, readonly string[]> = {
  GOAL_SCORED,
  GOAL_CONCEDED,
  GOAL_BOTH,
};

Deno.test("every pool has exactly 40 unique variants", () => {
  for (const [name, pool] of Object.entries(POOLS)) {
    eq(pool.length, 40, `${name} length`);
    eq(new Set(pool).size, 40, `${name} has no duplicate lines`);
  }
});

Deno.test("every variant: non-empty, <=90 chars, no em/en dashes, contains the score", () => {
  const names = Object.values(WC_COUNTRY_META).map((m) => m.name);
  const longestName = [...names].sort((a, b) => b.length - a.length)[0];
  const longestFlag = [...Object.values(WC_COUNTRY_META).map((m) => m.flag)]
    .sort((a, b) => b.length - a.length)[0]; // England/Scotland tag-flags are the widest
  const score = "10-10"; // worst-case width

  const goalVars = { flag: longestFlag, team: longestName, score };
  const bothVars = { home: longestName, away: longestName, score };

  const groups: Array<[readonly string[], Record<string, string>]> = [
    [GOAL_SCORED, goalVars],
    [GOAL_CONCEDED, goalVars],
    [GOAL_BOTH, bothVars],
  ];

  for (const [pool, vars] of groups) {
    for (const template of pool) {
      const body = interpolate(template, vars);
      assert(body.length > 0, `non-empty: ${template}`);
      assert(body.length <= 90, `<=90 chars (got ${body.length}): ${body}`);
      assert(!body.includes("—") && !body.includes("–"), `no em/en dash: ${body}`);
      assert(body.includes(score), `contains score: ${body}`);
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
    renderGoalPush({ home, away, homeGoals: 10, awayGoals: 10, side: "home", rng: zero }).title,
    renderHalfTimePush({ home, away, homeGoals: 10, awayGoals: 10, rng: zero }).title,
    renderFullTimePush({ home, away, homeGoals: 10, awayGoals: 10, rng: zero }).title,
  ];
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

// ============================================================
// 2026-09-09: eight pushes, one phone; "he's buzzing" three times a night
// ============================================================

Deno.test("GOAL pools: no phrase repeats, every line leaves room for the scorer lead", () => {
  for (const [name, pool] of [["GOAL_SCORED", GOAL_SCORED], ["GOAL_CONCEDED", GOAL_CONCEDED]] as const) {
    assert(pool.length >= 40, `${name} has 40+ lines`);
    const seen = new Set<string>();
    for (const line of pool) {
      assert(!seen.has(line), `${name}: duplicate line ${line}`);
      seen.add(line);
      // Longest realistic lead: "Calvert-Lewin 90+3' (pen). " is 27 chars, so a
      // 60-char reaction plus the longest club name and a two-digit score fits 90.
      // The longest active club short_name is 13 chars ("Nottm Forest" class);
      // the longest lead is "Calvert-Lewin 90+3' (pen). " at 27, and 27 + 63 = 90.
      const rendered = interpolate(line, { team: "Crystal Palace", score: "10-9" });
      assert(rendered.length <= 63, `${name}: ${rendered.length} chars is too long for a lead: ${line}`);
    }
    const buzzing = pool.filter((l) => /buzzing/i.test(l)).length;
    assert(buzzing <= 1, `${name}: "buzzing" appears ${buzzing} times`);
    const textHim = pool.filter((l) => /text him|drop him a/i.test(l)).length;
    assert(textHim <= 2, `${name}: the text-him nudge appears ${textHim} times`);
  }
});

Deno.test("seededRng: the same fixture and score draw the same line, the next goal draws another", () => {
  const a = renderGoalPush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", rng: seededRng(4200 * 100 + 10) });
  const b = renderGoalPush({ home: MEX, away: RSA, homeGoals: 1, awayGoals: 0, side: "home", rng: seededRng(4200 * 100 + 10) });
  const c = renderGoalPush({ home: MEX, away: RSA, homeGoals: 2, awayGoals: 0, side: "home", rng: seededRng(4200 * 100 + 20) });
  eq(a.bodies.mexico, b.bodies.mexico, "deterministic for one (fixture, score)");
  assert(a.bodies.mexico.replace("1-0", "") !== c.bodies.mexico.replace("2-0", ""), "the second goal reads differently");
  const r = seededRng(7);
  for (let i = 0; i < 1000; i++) {
    const x = r();
    assert(x >= 0 && x < 1, "in [0,1)");
  }
});

Deno.test("HT/FT copy: house rules on every line, and every body fits with its line to say", () => {
  const all = [...Object.values(HT_COPY), ...Object.values(FT_COPY)];
  for (const c of all) {
    assert(c.say.length >= 8, `a situation with fewer than 8 lines to say: "${c.say[0]}"`);
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
