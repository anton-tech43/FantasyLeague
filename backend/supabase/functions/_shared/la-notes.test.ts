// deno test backend/supabase/functions/_shared/la-notes.test.ts
//
// Live takes phase 1: the per-side note on the Live Activity
// (docs/LIVE_TAKES_PLAN.md traps 1-4, 9, 10).

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { buildLiveActivityAps, type LiveActivityContentState } from "./apns-client.ts";
import {
  audienceFor,
  carryNotes,
  MAX_NOTE,
  noteSig,
  parseNoteSig,
  parseTakeNotes,
  planUpdate,
  stateFor,
  type TakeNotes,
  takesRow,
} from "./la-notes.ts";

const HOME = "arsenal", AWAY = "liverpool";
const base: LiveActivityContentState = { homeScore: 0, awayScore: 0, statusLabel: "1H", elapsed: 31, clockStart: 1 };
const notes: TakeNotes = { home: "Arsenal have had all the ball", away: "Liverpool need to shoot more" };

/// What each kind of device receives from a plan, as the note it sees
/// (undefined = no note, "-" = nothing sent).
function received(plan: ReturnType<typeof planUpdate>, teamIds: string[]): string | undefined {
  const aud = audienceFor(teamIds, HOME, AWAY);
  const send = plan?.sends.find((s) => s.audiences.includes(aud));
  return send ? (send.opts.contentState.note ?? undefined) : "-";
}

function plan(o: Partial<Parameters<typeof planUpdate>[0]> = {}) {
  return planUpdate({
    contentState: base,
    notes,
    status: "1H",
    sig: "0-0-1H-31",
    sigCore: "0-0-1H",
    laSig: "0-0-1H-31",
    laNoteSig: null,
    staleSeconds: 1200,
    ...o,
  });
}

Deno.test("audience (update tokens and channel start): exactly one side followed gets that side; both or neither is neutral", () => {
  assertEquals(audienceFor(["arsenal"], HOME, AWAY), "home");
  assertEquals(audienceFor(["chelsea", "liverpool"], HOME, AWAY), "away");
  assertEquals(audienceFor(["arsenal", "liverpool"], HOME, AWAY), "neutral");
  assertEquals(audienceFor(["chelsea"], HOME, AWAY), "neutral");
  assertEquals(audienceFor([], HOME, AWAY), "neutral");
  assertEquals(audienceFor(null, HOME, AWAY), "neutral");
});

Deno.test("per side: home follower gets the home note, away the away note, both/neither none", () => {
  const p = plan({ sig: "0-0-1H-32" }); // a minute tick: everyone, note rides along
  assertEquals(received(p, ["arsenal"]), notes.home);
  assertEquals(received(p, ["liverpool", "spurs"]), notes.away);
  assertEquals(received(p, ["arsenal", "liverpool"]), undefined);
  assertEquals(received(p, ["chelsea"]), undefined);
  assertEquals(received(p, []), undefined);
  assertEquals(p!.priority, 5);
  assertEquals(p!.noteOnly, false);
});

Deno.test("a side with no take gets no note, and the other side's note never leaks", () => {
  const p = plan({ notes: { home: notes.home }, sig: "1-0-1H-33", sigCore: "1-0-1H" });
  assertEquals(received(p, ["arsenal"]), notes.home);
  assertEquals(received(p, ["liverpool"]), undefined);
  for (const s of p!.sends) {
    if (s.opts.contentState.note) assertEquals(s.audiences, ["home"]);
  }
});

Deno.test("note-only change: priority 5, only the side whose note changed, no alert", () => {
  const p = plan({ notes: { home: notes.home } });
  assertEquals(p!.priority, 5);
  assertEquals(p!.noteOnly, true);
  assertEquals(p!.sends.length, 1);
  assertEquals(p!.sends[0].audiences, ["home"]);
  assertEquals(received(p, ["liverpool"]), "-");
  assertEquals(received(p, ["chelsea"]), "-");
  const aps = buildLiveActivityAps(p!.sends[0].opts, 1000);
  assertEquals("alert" in aps, false);
  assertEquals((aps["content-state"] as LiveActivityContentState).note, notes.home);
});

Deno.test("no update that carries a note has an alert, at any priority", () => {
  for (const p of [plan(), plan({ sig: "0-0-1H-32" }), plan({ sig: "1-0-1H-32", sigCore: "1-0-1H" }), plan({ status: "HT", sig: "0-0-HT-", sigCore: "0-0-HT" })]) {
    for (const s of p!.sends) {
      const aps = buildLiveActivityAps(s.opts, 1000);
      assertEquals("alert" in aps, false);
      assertEquals(aps.event, "update");
    }
  }
});

Deno.test("a note that is cleared by silence reaches that side without the note", () => {
  const sent = noteSig({ home: notes.home });
  const p = plan({ notes: {}, laNoteSig: sent });
  assertEquals(p!.noteOnly, true);
  assertEquals(p!.sends.map((s) => s.audiences), [["home"]]);
  assertEquals(p!.sends[0].opts.contentState.note, undefined);
});

Deno.test("nothing changed, nothing sent; the same note is not sent twice", () => {
  assertEquals(plan({ laNoteSig: noteSig(notes) }), null);
  assertEquals(plan({ notes: {}, laNoteSig: null }), null);
});

Deno.test("a goal or a status change goes at 10 and carries the notes", () => {
  const p = plan({ sig: "0-0-HT-", sigCore: "0-0-HT", status: "HT", laNoteSig: noteSig(notes) });
  assertEquals(p!.priority, 10);
  assertEquals(received(p, ["arsenal"]), notes.home);
  // No note at all: one send to everyone, as before phase 1.
  const q = plan({ notes: {}, sig: "1-0-1H-40", sigCore: "1-0-1H" });
  assertEquals(q!.priority, 10);
  assertEquals(q!.sends.length, 1);
  assertEquals(q!.sends[0].audiences, ["home", "away", "neutral"]);
  assertEquals(q!.sends[0].take, false);
});

Deno.test("a goal clears the note; so do half-time, extra time, the shootout, a stop and the end", () => {
  const stored = { home: notes.home, away: notes.away };
  const prev = { status: "1H", home: 0, away: 0 };
  assertEquals(carryNotes(stored, prev, { status: "1H", home: 0, away: 0, elapsed: 33 }), stored);
  assertEquals(carryNotes(stored, prev, { status: "1H", home: 1, away: 0, elapsed: 33 }), {});
  assertEquals(carryNotes(stored, prev, { status: "1H", home: 0, away: 1, elapsed: 33 }), {});
  assertEquals(carryNotes(stored, prev, { status: "HT", home: 0, away: 0 }), {});
  // The HT take itself (written on the HT tick) survives the break and 2H.
  assertEquals(carryNotes(stored, { status: "HT", home: 0, away: 0 }, { status: "HT", home: 0, away: 0 }), stored);
  assertEquals(carryNotes(stored, { status: "HT", home: 0, away: 0 }, { status: "2H", home: 0, away: 0, elapsed: 46 }), stored);
  const p2 = { status: "2H", home: 0, away: 0 };
  assertEquals(carryNotes(stored, p2, { status: "2H", home: 0, away: 0, elapsed: 91 }), {});
  for (const status of ["ET", "BT", "P", "INT", "SUSP", "FT", "AET", "PEN"]) {
    assertEquals(carryNotes(stored, p2, { status, home: 0, away: 0 }), {}, status);
  }
});

Deno.test("the end and the shootout never carry a take note", () => {
  const shootout = { ...base, statusLabel: "Penalties", note: "Shootout: 3-2" };
  assertEquals(stateFor(shootout, notes, "home").note, "Shootout: 3-2");
  assertEquals(stateFor(base, notes, "neutral").note, undefined);
});

Deno.test("la_takes and la_note_sig round-trip; junk and over-long lines are dropped", () => {
  assertEquals(parseNoteSig(noteSig(notes)), notes);
  assertEquals(parseNoteSig(noteSig({ away: 'Say "they|re" fine' })), { away: 'Say "they|re" fine' });
  assertEquals(noteSig({}), null);
  assertEquals(parseNoteSig("not json"), {});
  assertEquals(parseTakeNotes({ home: 5, away: "" }), {});
  assertEquals(parseTakeNotes({ home: "x".repeat(MAX_NOTE + 1), away: "ok" }), { away: "ok" });
  assertEquals(parseTakeNotes(null), {});
});

Deno.test("a stored take never outlives its score or its period, even if a clear was missed", () => {
  // Two overlapping ticks: the goal tick read the row before the take was
  // written, so it cleared nothing; the stored score still catches it.
  const row = takesRow({ home: notes.home }, "0-0", "30");
  const same = { status: "1H", home: 1, away: 0 };
  assertEquals(carryNotes(row, same, { status: "1H", home: 1, away: 0, elapsed: 34 }), {});
  assertEquals(carryNotes(row, { status: "1H", home: 0, away: 0 }, { status: "1H", home: 0, away: 0, elapsed: 34 }), { home: notes.home });
  // A 30' take never shows at half-time; the HT take does, into 2H; 70' only in 2H.
  assertEquals(carryNotes(row, { status: "HT", home: 0, away: 0 }, { status: "HT", home: 0, away: 0 }), {});
  const ht = takesRow({ away: notes.away }, "0-0", "ht");
  assertEquals(carryNotes(ht, { status: "HT", home: 0, away: 0 }, { status: "2H", home: 0, away: 0, elapsed: 50 }), { away: notes.away });
  assertEquals(takesRow({}, "0-0", "70"), null);
});
