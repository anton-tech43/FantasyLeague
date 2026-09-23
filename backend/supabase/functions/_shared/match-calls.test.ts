// Deno tests for the "Called it" resolver.
//   cd backend/supabase/functions && deno test --allow-read _shared/match-calls.test.ts
//
// The first test reads tools/myturn/call_vectors.json off disk and asserts
// every vector BY NAME. That file is the shared truth between this resolver and
// LingoCalls' Swift self-check, so a case added on one side must go green on
// the other or this test fails with the vector's name in the message.

import {
  appendCallLine,
  type CallPick,
  halfTimeGoals,
  matchedCalls,
  type Outcome,
  PUSH_BODY_BUDGET,
  triggerMatches,
} from "./match-calls.ts";

function assert(c: boolean, m: string): void {
  if (!c) throw new Error("assertion failed: " + m);
}
function eq<T>(a: T, b: T, m: string): void {
  if (a !== b) throw new Error(`${m}: expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

const VECTORS_PATH = new URL("../../../../tools/myturn/call_vectors.json", import.meta.url);

interface Vector {
  name: string;
  outcome: Outcome;
  trigger: Record<string, unknown>;
  matches: boolean;
}

function loadVectors(): Vector[] {
  const raw = JSON.parse(Deno.readTextFileSync(VECTORS_PATH)) as { vectors: Vector[] };
  assert(Array.isArray(raw.vectors) && raw.vectors.length > 0, "call_vectors.json has vectors");
  return raw.vectors;
}

Deno.test("call_vectors.json: every vector resolves as written", () => {
  const vectors = loadVectors();
  const seen = new Set<string>();
  for (const v of vectors) {
    assert(!seen.has(v.name), `vector names are unique: ${v.name}`);
    seen.add(v.name);
    eq(triggerMatches(v.trigger, v.outcome), v.matches, `vector ${v.name}`);
    // Same answer through the public entry point, so the two cannot drift.
    const pick = { id: v.name, line: "She said this.", trigger: v.trigger } as unknown as CallPick;
    eq(
      matchedCalls({ fixture_id: 42, picks: [pick], picked_at: "x" }, 42, v.outcome).length,
      v.matches ? 1 : 0,
      `vector ${v.name} through matchedCalls`,
    );
  }
});

// The vectors cover the trigger table; these cover the storage envelope around
// it, which no vector can express because it is not shared with Swift.

const GOAL: Outcome = {
  kind: "goal",
  side: "us",
  scorerRole: "Attacker",
  penalty: false,
  ownGoal: false,
  minute: 88,
};

const pick = (id: string, trigger: unknown): unknown => ({ id, line: `${id} line.`, trigger });

Deno.test("malformed stored blob never throws and never matches", () => {
  const junk: unknown[] = [
    null,
    undefined,
    "",
    "not json",
    42,
    [],
    {},
    { picks: [] },
    { fixture_id: 42 },
    { fixture_id: "42", picks: [pick("a", { kind: "goal" })] }, // id as a string
    { fixture_id: 42, picks: "nope" },
    { fixture_id: 42, picks: [null, 7, "x", [], { id: "a" }] },
    { fixture_id: 42, picks: [{ id: "a", line: "   ", trigger: { kind: "goal" } }] }, // blank line
    { fixture_id: 42, picks: [{ id: "a", line: "ok.", trigger: "goal" }] }, // trigger not an object
    { fixture_id: 42, picks: [{ id: "", line: "ok.", trigger: { kind: "goal" } }] },
  ];
  for (const stored of junk) {
    eq(matchedCalls(stored, 42, GOAL).length, 0, `junk resolves to nothing: ${JSON.stringify(stored)}`);
  }
  // A good pick alongside bad siblings still lands; the bad ones are dropped,
  // not repaired.
  const mixed = {
    fixture_id: 42,
    picks: [null, pick("good", { kind: "goal", side: "us" }), { id: "bad" }],
  };
  const got = matchedCalls(mixed, 42, GOAL);
  eq(got.length, 1, "one survivor");
  eq(got[0].id, "good", "the well-formed pick");
});

Deno.test("a stale fixture id resolves to nothing", () => {
  const stored = { fixture_id: 41, picks: [pick("a", { kind: "goal", side: "us" })], picked_at: "x" };
  eq(matchedCalls(stored, 42, GOAL).length, 0, "last week's slip does not land on tonight's goal");
  eq(matchedCalls({ ...stored, fixture_id: 42 }, 42, GOAL).length, 1, "same slip on the right fixture does");
});

Deno.test("more than one pick can land on one event, in pick order", () => {
  const stored = {
    fixture_id: 42,
    picks: [
      pick("late", { kind: "goal", side: "us", minuteFrom: 85 }),
      pick("halftime", { kind: "halftime", state: "level" }), // wrong kind
      pick("forward", { kind: "goal", side: "us", scorerRole: "Attacker" }),
    ],
    picked_at: "x",
  };
  const got = matchedCalls(stored, 42, GOAL);
  eq(got.length, 2, "both goal picks land");
  eq(got.map((p) => p.id).join(","), "late,forward", "order preserved");
});

Deno.test("appendCallLine refuses to overflow the body budget", () => {
  const short = "0-1. He is up." as const;
  const p = (line: string): CallPick => ({ id: "x", line, trigger: { kind: "goal" } });

  const fits = appendCallLine(short, p("Told you."));
  assert(fits !== short, "a short body plus a short line is appended");
  assert(fits.includes("Told you."), "her words are quoted back");
  assert(fits.length <= PUSH_BODY_BUDGET, `rendered stays within budget (got ${fits.length}): ${fits}`);

  // One char over is dropped whole, never truncated: half a sentence of hers
  // is worse than none of it.
  const long = "x".repeat(PUSH_BODY_BUDGET - 20);
  eq(appendCallLine(long, p("A line that will not fit.")), long, "overflow returns the body unchanged");

  // The 120-char ceiling the RPC allows can never fit; it must not throw or
  // truncate.
  eq(appendCallLine(short, p("y".repeat(120))), short, "a max-length line drops cleanly");

  // Nothing to say is a no-op rather than a trailing fragment.
  eq(appendCallLine(short, p("   ")), short, "a blank line is a no-op");
  eq(appendCallLine(short, { id: "x", trigger: {} } as unknown as CallPick), short, "a missing line is a no-op");

  // Campaign rule: the segment we add carries no em/en dash.
  assert(!/[–—]/.test(fits), `no em/en dashes: ${fits}`);
});

Deno.test("halfTimeGoals counts the first half only, and fails safe", () => {
  const ev = (side: string, minute: number | null) => ({ side, minute, player: null });
  const ht = (events: unknown) => {
    const g = halfTimeGoals(events);
    return `${g.home}-${g.away}`;
  };
  eq(ht([ev("home", 12), ev("away", 45), ev("home", 67)]), "1-1", "45+ counts to the first half, 67 does not");
  eq(ht([ev("home", 3), ev("home", 44)]), "2-0", "both before the break");
  eq(ht([ev("away", 46), ev("away", 90)]), "0-0", "a second half of goals is still 0-0 at the break");
  // Fails safe rather than throwing, and an unreadable event is never counted:
  // a wrong 0-0 costs her a line, a wrong lead would tell her she called
  // something she did not.
  for (const junk of [null, undefined, "x", 7, {}, [null], [{ side: "home" }], [ev("home", null)], [ev("nobody", 10)]]) {
    eq(ht(junk), "0-0", `junk is 0-0: ${JSON.stringify(junk)}`);
  }
});
