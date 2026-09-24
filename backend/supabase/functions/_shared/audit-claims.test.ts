// deno test backend/supabase/functions/_shared/audit-claims.test.ts
//
// The season-verdict rules read a FINAL table. Fed a live one they compared a
// claim about last season against this season's standings and reported the
// actual reigning champions as a contradiction, twice a night (2026-09-24).
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { auditContentClaims, type RankInfo } from "./audit-claims.ts";

const TEXT = "Brighton put on a show, beating Premier League champions Arsenal 3-0 at home.";
const base: RankInfo = { teamId: "arsenal", rank: 2, totalTeams: 20, leagueId: 39 };

Deno.test("silent while the season is still being played", () => {
  assertEquals(auditContentClaims(TEXT, { ...base, seasonComplete: false }), []);
});

Deno.test("silent when completeness is unknown — fail closed", () => {
  assertEquals(auditContentClaims(TEXT, base), []);
});

Deno.test("still flags the same sentence against a finished table", () => {
  const f = auditContentClaims(TEXT, { ...base, seasonComplete: true });
  assertEquals(f.map((x) => x.code), ["champions_but_not_first"]);
});
