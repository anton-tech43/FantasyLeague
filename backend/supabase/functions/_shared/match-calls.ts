// _shared/match-calls.ts
//
// "Called it" — she picks up to three lines before kickoff, and the push that
// was going out anyway tells her when one of them landed. The app never asks
// whether she actually said it; the feed already knows what happened.
//
// Pure, no I/O, no Claude. Two jobs:
//   matchedCalls()  which of her stored picks this moment satisfies
//   withCallLine()  the push body when one landed: the scorer lead plus HER
//                   line, with the rotating pool line dropped
//
// The trigger vocabulary is FIXED by tools/myturn/CALLED_IT_CONTRACT.md and its
// semantics by tools/myturn/call_vectors.json, which this file's test reads and
// LingoCalls' Swift self-check reads too. Neither side may add a case without
// the other going red. Nothing here may be "improved" without a vector.
//
// Reading rule where the vectors are silent: an ABSENT trigger field means
// "don't care"; a trigger field that IS present is never satisfied by an
// unknown (null / non-finite) outcome field. The feed publishes a score a beat
// before it publishes the scorer, and a pick must not land on a goal we cannot
// attribute.
//
// No em-dashes (campaign rule).

/// The four values `players.position` actually holds (PlayerSlots refuses to
/// invent a fifth).
export type ScorerRole = "Goalkeeper" | "Defender" | "Midfielder" | "Attacker";

/// What just happened, FROM ONE DEVICE'S PERSPECTIVE: "us" is the team that
/// device follows. match-watcher builds one of these per playing side, exactly
/// as it builds one push body per playing side.
///
/// `side` on a goal follows API-Football and parseGoalEvents: an own goal is
/// credited to the side that BENEFITED, so `side: "us", ownGoal: true` is our
/// goal, scored by one of theirs.
export type Outcome =
  | {
    kind: "goal";
    side: "us" | "them";
    scorerRole: ScorerRole | null;
    penalty: boolean;
    ownGoal: boolean;
    minute: number | null;
  }
  | { kind: "halftime"; state: "ahead" | "level" | "behind"; conceded: number | null }
  | { kind: "fulltime"; state: "win" | "draw" | "loss"; cleanSheet: boolean; comeback: boolean };

/// A pick's trigger, as authored in lingo.json and stored verbatim on the
/// device row. Every field except `kind` is optional and means "don't care"
/// when absent. `any` is the explicit spelling of the same thing for `side`
/// and `scorerRole`.
export interface CallTrigger {
  kind: "goal" | "halftime" | "fulltime";
  side?: "us" | "them" | "any";
  scorerRole?: ScorerRole | "any";
  penalty?: boolean;
  ownGoal?: boolean;
  minuteFrom?: number;
  minuteTo?: number;
  state?: string;
  conceded?: number;
  cleanSheet?: boolean;
  comeback?: boolean;
}

/// One stored pick. It carries its OWN text: the content bundle ships in the
/// binary and the server has no copy of lingo.json, so the push line must be
/// reconstructable from the device row alone.
export interface CallPick {
  id: string;
  line: string;
  trigger: CallTrigger;
}

/// Longest rendered push body, the same ceiling goal-push-copy.ts holds its
/// pools to and goal-push.test.ts sweeps for.
export const PUSH_BODY_BUDGET = 90;

/// Longest scorer lead goal-push.ts can put in front of a body, INCLUDING the
/// space after it: "Calvert-Lewin 90+3' (pen). " is 27, the worst case
/// goal-push.test.ts derives its own 63-char pool ceiling from.
export const MAX_SCORER_LEAD = 27;

/// What wraps her line: `Called it: "` plus the closing quote.
const CALL_WRAPPER = 'Called it: ""'.length;

/// The hard cap on an authored call line, and the number the content side has
/// to build against: the worst-case scorer lead plus the wrapper plus a line of
/// this length is exactly PUSH_BODY_BUDGET. A line longer than this is not
/// truncated, it is DROPPED, so this is a ceiling to author under, not a hint.
/// Enforced from both sides in match-calls.test.ts.
export const MAX_CALL_LINE = PUSH_BODY_BUDGET - MAX_SCORER_LEAD - CALL_WRAPPER;

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function isFiniteNumber(v: unknown): v is number {
  return typeof v === "number" && Number.isFinite(v);
}

/// A trigger constraint that is present must be satisfied; absent is
/// "don't care". `actual` of an unexpected type never satisfies a present
/// constraint.
function wants<T>(expected: T | undefined, actual: unknown): boolean {
  return expected === undefined || expected === actual;
}

/// Does this trigger describe the moment that just happened? Total: any shape
/// of garbage answers false rather than throwing.
export function triggerMatches(trigger: unknown, outcome: Outcome): boolean {
  if (!isObject(trigger)) return false;
  const t = trigger as unknown as CallTrigger;
  if (t.kind !== outcome.kind) return false;

  if (outcome.kind === "goal") {
    if (t.side !== undefined && t.side !== "any" && t.side !== outcome.side) return false;
    if (t.scorerRole !== undefined && t.scorerRole !== "any") {
      // Unknown scorer never satisfies a role trigger.
      if (outcome.scorerRole === null || t.scorerRole !== outcome.scorerRole) return false;
    }
    if (!wants(t.penalty, outcome.penalty)) return false;
    if (!wants(t.ownGoal, outcome.ownGoal)) return false;
    if (t.minuteFrom !== undefined || t.minuteTo !== undefined) {
      // Unknown minute never satisfies a minute window.
      if (!isFiniteNumber(outcome.minute)) return false;
      if (isFiniteNumber(t.minuteFrom) && outcome.minute < t.minuteFrom) return false;
      if (isFiniteNumber(t.minuteTo) && outcome.minute > t.minuteTo) return false;
    }
    return true;
  }

  if (outcome.kind === "halftime") {
    if (!wants(t.state, outcome.state)) return false;
    if (t.conceded !== undefined && !(isFiniteNumber(outcome.conceded) && t.conceded === outcome.conceded)) {
      return false;
    }
    return true;
  }

  if (!wants(t.state, outcome.state)) return false;
  if (!wants(t.cleanSheet, outcome.cleanSheet)) return false;
  if (!wants(t.comeback, outcome.comeback)) return false;
  return true;
}

/// Narrow one element of the stored `picks` array. Anything that is not
/// `{ id: string, line: string, trigger: object }` is dropped, not repaired:
/// the column is written by a validating RPC, so a bad shape here means either
/// a client we do not control or corruption, and neither deserves a push line.
function toPick(v: unknown): CallPick | null {
  if (!isObject(v)) return null;
  const { id, line, trigger } = v;
  if (typeof id !== "string" || !id) return null;
  if (typeof line !== "string" || !line.trim()) return null;
  if (!isObject(trigger)) return null;
  return { id, line, trigger: trigger as unknown as CallTrigger };
}

/// Her picks that this moment satisfies, in the order she picked them.
///
/// `stored` is `device_tokens.match_calls` straight off the row:
/// `{ fixture_id, picks, picked_at }`. Anything else, including null, a string,
/// a stale fixture or a half-written blob, resolves to nothing. A STALE FIXTURE
/// ID RESOLVES TO NOTHING is the load-bearing one: last week's slip must not
/// land on tonight's goal.
///
/// More than one pick may land on a single event; all of them come back and the
/// caller decides how many it has room for.
export function matchedCalls(stored: unknown, fixtureId: number, outcome: Outcome): CallPick[] {
  if (!isObject(stored)) return [];
  if (!isFiniteNumber(stored.fixture_id) || stored.fixture_id !== fixtureId) return [];
  const picks = stored.picks;
  if (!Array.isArray(picks)) return [];
  const out: CallPick[] = [];
  for (const raw of picks) {
    const pick = toPick(raw);
    if (pick && triggerMatches(pick.trigger, outcome)) out.push(pick);
  }
  return out;
}

/// The push body for a device whose pick just landed. Her line REPLACES the
/// rotating pool line rather than following it.
///
/// That is the whole point of the feature. The pool line is random colour,
/// drawn from forty interchangeable variants; her line is the one thing in the
/// push she wrote. Appending both never fit inside PUSH_BODY_BUDGET, and it was
/// the wrong one that was giving way.
///
/// `scorerLead` survives, because it names the player and the minute and she
/// cannot get that anywhere else in a glance. Everything else in `body` goes.
/// At half-time and full-time there is no lead and her line is the whole body.
///
/// The drop-rather-than-truncate rule stays as the backstop: measure the
/// RENDERED result, and hand back `body` untouched if it would overflow. With
/// a line inside MAX_CALL_LINE that backstop never fires, which is the point of
/// publishing that number. Half a sentence of hers is worse than none of it.
///
/// Pure; never throws.
export function withCallLine(
  args: { body: string; scorerLead?: string | null; pick: CallPick },
): string {
  const line = (args.pick?.line ?? "").trim();
  if (!line) return args.body;
  const lead = (args.scorerLead ?? "").trim();
  const segment = `Called it: "${line}"`;
  const rendered = lead ? `${lead} ${segment}` : segment;
  return rendered.length <= PUSH_BODY_BUDGET ? rendered : args.body;
}

/// Goals each side had scored by half-time, counted off a stored `goal_events`
/// list (minute <= 45, so a 45+2 goal counts to the first half). This exists to
/// answer one question, "were we behind at the break", which is the `comeback`
/// trigger at full-time. The half-time score is not in the fixture payload
/// match-watcher fetches, and this is derivable from a list we already hold, so
/// it costs no call.
///
/// Tolerant of a missing, partial or malformed list, and biased to the safe
/// answer: nothing readable counts as 0-0, which means no comeback, which means
/// her longshot simply does not land. A false negative costs one line; a false
/// positive would tell her she called something she did not.
export function halfTimeGoals(events: unknown): { home: number; away: number } {
  const out = { home: 0, away: 0 };
  if (!Array.isArray(events)) return out;
  for (const e of events) {
    if (!isObject(e)) continue;
    if (!isFiniteNumber(e.minute) || e.minute > 45) continue;
    if (e.side === "home") out.home++;
    else if (e.side === "away") out.away++;
  }
  return out;
}
