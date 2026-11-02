// _shared/la-notes.ts
//
// Live takes phase 1 (docs/LIVE_TAKES_PLAN.md): the take as the `note` line
// under the score on the Live Activity. Pure, so every trap the plan lists is
// a test (la-notes.test.ts), and match-watcher only wires it up.
//
// - Trap 1/9: "they" needs an owner. A device following exactly one side of
//   the match gets that side's note; both sides or neither gets none.
// - Trap 2: every update replaces the whole content-state, so the note per
//   side is stored (match_status_state.la_takes) and carried in every update
//   until a score change, the change to HT, or anything but 1H/HT/2H up to
//   90' clears it. The end never carries a take.
// - Trap 3: a note change has its own signature (la_note_sig). Alone it goes
//   at priority 5; on a tick with another update it rides along.
// - Trap 4: no update carries an alert (asserted in the tests).

import type { LiveActivityContentState, sendLiveActivityPush } from "./apns-client.ts";

export type NoteSide = "home" | "away";
export type LaAudience = NoteSide | "neutral";
export const LA_AUDIENCES: readonly LaAudience[] = ["home", "away", "neutral"];

/// The take note each side's followers see now. A missing side has none.
export interface TakeNotes {
  home?: string;
  away?: string;
}

/// Which side's note a device gets: the one side of this match it follows.
/// Following both (a derby between her two clubs) or neither (a WC-era row,
/// a knockout start for everyone) is neutral, which never gets a note.
export function audienceFor(
  teamIds: readonly string[] | null | undefined,
  home: string,
  away: string,
): LaAudience {
  const ids = teamIds ?? [];
  const h = ids.includes(home), a = ids.includes(away);
  return h === a ? "neutral" : h ? "home" : "away";
}

/// The statuses a take may show in. Nothing in extra time, the shootout, a
/// stopped match (INT/SUSP) or the end.
const NOTE_STATUSES = new Set(["1H", "HT", "2H"]);
const LAST_NOTE_MINUTE = 90;

export interface TickScore {
  status: string;
  home: number | null | undefined;
  away: number | null | undefined;
  elapsed?: number | null;
}

/// Two lines at 12 pt on a narrow phone (trap 10). decideTake already keeps
/// to it; this is the last check before a phone.
export const MAX_NOTE = 60;

/// Read la_takes off the row: non-empty strings within MAX_NOTE only.
export function parseTakeNotes(raw: unknown): TakeNotes {
  const o = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const out: TakeNotes = {};
  for (const s of ["home", "away"] as const) {
    const v = o[s];
    if (typeof v === "string" && v.length > 0 && v.length <= MAX_NOTE) out[s] = v;
  }
  return out;
}

/// The notes to carry on this tick: the stored ones, unless the score
/// changed, the match went to half-time, it is past 90' or not in 1H/HT/2H.
export function carryNotes(stored: unknown, prev: TickScore | null, now: TickScore): TakeNotes {
  if (!NOTE_STATUSES.has(now.status)) return {};
  if (now.status === "2H" && typeof now.elapsed === "number" && now.elapsed > LAST_NOTE_MINUTE) return {};
  if (prev && (prev.home !== now.home || prev.away !== now.away)) return {};
  if (prev && now.status === "HT" && prev.status !== "HT") return {};
  return parseTakeNotes(stored);
}

/// la_note_sig for a set of notes; null when there is none, so a row that
/// never had a note compares equal. JSON, so a line may hold any character.
export function noteSig(notes: TakeNotes): string | null {
  return notes.home || notes.away ? JSON.stringify([notes.home ?? null, notes.away ?? null]) : null;
}

/// The notes a la_note_sig says were last sent.
export function parseNoteSig(sig: string | null | undefined): TakeNotes {
  if (!sig) return {};
  try {
    const [home, away] = JSON.parse(sig);
    return parseTakeNotes({ home, away });
  } catch {
    return {};
  }
}

/// The content-state one audience gets. A note already in the state (the
/// shootout score) is never replaced; neutral gets the state as it is.
export function stateFor(
  base: LiveActivityContentState,
  notes: TakeNotes,
  audience: LaAudience,
): LiveActivityContentState {
  if (base.note || audience === "neutral") return base;
  const note = notes[audience];
  return note ? { ...base, note } : base;
}

export type LaPushOptions = Parameters<typeof sendLiveActivityPush>[1];

export interface UpdatePlan {
  priority: number;
  /// Only the note changed: the audiences whose note did, at priority 5.
  noteOnly: boolean;
  /// One send per distinct content-state, with the audiences that get it.
  /// Never an alert.
  sends: Array<{ audiences: LaAudience[]; take: boolean; opts: LaPushOptions }>;
}

/// The update for this tick, or null when nothing changed. `sig`/`laSig` are
/// the score-status-minute signatures (match-watcher), `sigCore` the same
/// without the minute. A minute-only change and the shootout go at 5, a goal
/// or status change at 10; on those every audience gets the update and the
/// note rides along. A note-only change goes at 5, to the sides whose note
/// changed and nobody else.
export function planUpdate(a: {
  contentState: LiveActivityContentState;
  notes: TakeNotes;
  status: string;
  sig: string;
  sigCore: string;
  laSig: string | null;
  laNoteSig: string | null;
  staleSeconds: number;
}): UpdatePlan | null {
  const sigChanged = a.sig !== a.laSig;
  const sent = parseNoteSig(a.laNoteSig);
  const changed = (["home", "away"] as const).filter((s) => (a.notes[s] ?? null) !== (sent[s] ?? null));
  if (!sigChanged && changed.length === 0) return null;
  const minuteOnly = a.laSig !== null && a.laSig.replace(/-[^-]*$/, "") === a.sigCore;
  const priority = !sigChanged || minuteOnly || a.status === "P" ? 5 : 10;
  const audiences: readonly LaAudience[] = sigChanged ? LA_AUDIENCES : changed;
  const groups = new Map<string, UpdatePlan["sends"][number]>();
  for (const aud of audiences) {
    const contentState = stateFor(a.contentState, a.notes, aud);
    const key = contentState.note ?? "";
    const g = groups.get(key);
    if (g) g.audiences.push(aud);
    else {
      groups.set(key, {
        audiences: [aud],
        take: contentState !== a.contentState,
        opts: { event: "update", contentState, staleSeconds: a.staleSeconds, priority },
      });
    }
  }
  return { priority, noteOnly: !sigChanged, sends: [...groups.values()] };
}
