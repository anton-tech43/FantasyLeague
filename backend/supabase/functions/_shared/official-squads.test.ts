import { matchOne } from "./official-squads.ts";
const off = [
  { display: "Martin Ødegaard", first: "Martin", last: "Ødegaard", number: 8 },
  { display: "Gabriel", first: "Gabriel", last: "dos Santos Magalhães", number: 6 },
  { display: "Kepa Arrizabalaga", first: "Kepa", last: "Arrizabalaga", number: 13 },
  { display: "Bukayo Saka", first: "Bukayo", last: "Saka", number: 7 },
  { display: "Jack Fletcher", first: "Jack", last: "Fletcher", number: 38 },
  { display: "Tyler Fletcher", first: "Tyler", last: "Fletcher", number: 39 },
  { display: "Myles Lewis-Skelly", first: "Myles", last: "Lewis-Skelly", number: 49 },
];
const n = (name: string) => matchOne({ api_player_id: 1, name, number: null }, off)?.number ?? null;
Deno.test("official squad name matching", () => {
  const cases: [string, number | null][] = [["M. Ødegaard", 8], ["Gabriel Magalhães", 6], ["Kepa", 13], ["B. Saka", 7],
    ["J. Fletcher", 38], ["T. Fletcher", 39], ["M. Lewis-Skelly", 49], ["Luka Bentt", null], ["K. Ranson", null]];
  for (const [name, want] of cases) {
    if (n(name) !== want) throw new Error(`${name}: got ${n(name)}, want ${want}`);
  }
});
