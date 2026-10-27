// lineup-notable.ts — is this lineup worth a line to her? Pure, no model.
//
// Anton (2026-10-26): a talking point when the lineups drop, but only when a
// player of substance is out, an unexpected one starts, or the side is heavily
// rotated. Not full-backs. Decided in code, never in a prompt (PUSH_RULES.md,
// lesson 77). Runs as a dry run (match-watcher logs the line it would have
// sent) until Anton has read real cases and turns on LINEUP_PUSH_ENABLED.
//
// Thresholds are here so tuning them is one edit.
export const REGULAR_SHARE = 0.6;   // started ≥ 60% of league games played
export const OUTSIDER_SHARE = 0.2;  // started ≤ 20%
export const MIN_PLAYED = 3;        // too early in the season to call anyone regular
export const ROTATION_CHANGES = 5;  // changes from the previous league XI

export interface LineupPlayer {
  id: number;
  name: string;
  pos?: string | null;   // "G" | "D" | "M" | "F"
  grid?: string | null;  // "row:col", row 1 is the goalkeeper
}

export interface SquadRow {
  api_player_id: number;
  name: string;
  known_as?: string | null;
  league_starts?: number | null;
  captain?: boolean | null;
  /// API-Football's four-way position. Only a fallback for a man we have no
  /// stored lineup role for: "Defender" cannot tell a full-back from a
  /// centre-back, so it stays unknown and silent.
  position?: string | null;
}

const ROLE_BY_POSITION: Record<string, Role> = { Goalkeeper: "gk", Midfielder: "mid", Attacker: "att" };

export interface NotableInput {
  xi: LineupPlayer[];
  squad: SquadRow[];
  /// League games the club has played. match-watcher uses the squad's highest
  /// league_starts, which is the goalkeeper's and so the club's, near enough.
  leaguePlayed: number;
  /// The previous league XI's ids, or null when none is stored yet.
  previousXI: number[] | null;
  /// Each player's role in the last lineup we stored, for men not in this one.
  lastRole: Map<number, Role>;
  opponent: string;
}

export type Role = "gk" | "cb" | "fb" | "mid" | "att";

export interface Notable {
  kind: "regular_out" | "outsider_in" | "rotation";
  players: string[];
  line: string;
}

/// Role from the formation grid. In a back four the outer two are full-backs;
/// in a back five, the wing-backs; a back three has none.
export function rolesFromGrid(xi: LineupPlayer[]): Map<number, Role> {
  const roles = new Map<number, Role>();
  const parsed = xi.map((p) => {
    const [row, col] = (p.grid ?? "").split(":").map(Number);
    return { p, row, col };
  });
  const maxRow = Math.max(...parsed.map((x) => x.row).filter(Number.isFinite), 0);
  const backs = parsed.filter((x) => x.row === 2);
  const outer = backs.length >= 4 ? new Set([1, backs.length]) : new Set<number>();
  for (const { p, row, col } of parsed) {
    if (!Number.isFinite(row)) continue;
    if (row === 1) roles.set(p.id, "gk");
    else if (row === 2) roles.set(p.id, outer.has(col) ? "fb" : "cb");
    else if (row === maxRow) roles.set(p.id, "att");
    else roles.set(p.id, "mid");
  }
  return roles;
}

/// The name she would know him by: the league's own, else the surname.
export function shownName(row: SquadRow | undefined, fallback: string): string {
  if (row?.known_as) return row.known_as;
  const parts = (row?.name ?? fallback).split(" ");
  return parts[parts.length - 1];
}

function list(names: string[]): string {
  return names.length === 1 ? names[0] : `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}

export function notableLineup(input: NotableInput): Notable | null {
  const { xi, squad, leaguePlayed, previousXI, lastRole, opponent } = input;
  if (xi.length !== 11) return null;
  const inXI = new Set(xi.map((p) => p.id));
  const roles = rolesFromGrid(xi);
  const byId = new Map(squad.map((r) => [r.api_player_id, r]));
  const substance = (role: Role | undefined) => role !== undefined && role !== "fb";

  if (leaguePlayed >= MIN_PLAYED) {
    // A regular of substance not starting. His role is the last one we saw
    // him play; never seen means we cannot rule out a full-back, so silent.
    const out = squad.filter((r) =>
      !inXI.has(r.api_player_id) &&
      ((r.league_starts ?? 0) >= REGULAR_SHARE * leaguePlayed || r.captain === true) &&
      substance(lastRole.get(r.api_player_id) ?? ROLE_BY_POSITION[r.position ?? ""])
    );
    if (out.length > 0) {
      const names = out.slice(0, 2).map((r) => shownName(r, r.name));
      const verb = names.length === 1 ? "isn't" : "aren't";
      return {
        kind: "regular_out",
        players: names,
        line: `${list(names)} ${verb} starting against ${opponent}. Ask him why.`,
      };
    }

    const outsiders = xi.filter((p) => {
      const r = byId.get(p.id);
      return r !== undefined && (r.league_starts ?? 0) <= OUTSIDER_SHARE * leaguePlayed &&
        substance(roles.get(p.id)) && roles.get(p.id) !== "gk";
    });
    if (outsiders.length > 0) {
      const names = outsiders.slice(0, 2).map((p) => shownName(byId.get(p.id), p.name));
      const verb = names.length === 1 ? "starts" : "start";
      return {
        kind: "outsider_in",
        players: names,
        line: `${list(names)} ${verb} against ${opponent}, which is new. Ask him if that's a gamble.`,
      };
    }
  }

  if (previousXI && previousXI.length === 11) {
    const changes = previousXI.filter((id) => !inXI.has(id)).length;
    if (changes >= ROTATION_CHANGES) {
      return {
        kind: "rotation",
        players: [],
        line: `${changes} changes from the last league game against ${opponent}. Ask him if that's a risk.`,
      };
    }
  }
  return null;
}
