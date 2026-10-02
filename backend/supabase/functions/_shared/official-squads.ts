// Name matching between our players rows (API-Football: "M. Ødegaard",
// "Gabriel Magalhães", "Kepa") and the Premier League's official squad
// ("Martin Ødegaard", "Gabriel", "Kepa Arrizabalaga"). Pure, so it is tested.

export interface OfficialPlayer { display: string; first: string; last: string; number: number | null }
export interface OurRow { api_player_id: number; name: string; number: number | null }

export function fold(s: string): string {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/ø/g, "o").replace(/æ/g, "ae").replace(/ı/g, "i").replace(/ł/g, "l").replace(/đ/g, "d")
    .replace(/[^a-z0-9 ]+/g, " ").split(/\s+/).filter(Boolean).join(" ");
}

/// The one official man this row is, or null. A surname shared inside the
/// official squad needs the initial or the first name to agree too.
export function matchOne(row: OurRow, official: OfficialPlayer[]): OfficialPlayer | null {
  const ours = fold(row.name).split(" ");
  if (ours.length === 0) return null;
  const initial = /^[a-z]$/.test(ours[0]) ? ours[0] : null;
  const tokensOf = (o: OfficialPlayer) => new Set([...fold(o.display).split(" "), ...fold(o.first).split(" "), ...fold(o.last).split(" ")].filter(Boolean));
  const whole = official.filter((o) => fold(o.display) === ours.join(" "));
  if (whole.length === 1) return whole[0];
  const last = ours[ours.length - 1];
  let hits = official.filter((o) => tokensOf(o).has(last));
  if (hits.length > 1 && initial) hits = hits.filter((o) => fold(o.first).startsWith(initial) || fold(o.display).startsWith(initial));
  if (hits.length > 1 && !initial && ours.length > 1) hits = hits.filter((o) => ours.every((t) => tokensOf(o).has(t)));
  if (hits.length === 1) return hits[0];
  // A one-word name ("Kepa", "Thiago") is a first name in the official list.
  if (ours.length === 1) {
    const firsts = official.filter((o) => fold(o.first) === last || fold(o.display).split(" ")[0] === last);
    if (firsts.length === 1) return firsts[0];
  }
  return null;
}

export function matchOfficial(rows: OurRow[], official: OfficialPlayer[]) {
  return rows.map((row) => ({ row, official: matchOne(row, official) }));
}
