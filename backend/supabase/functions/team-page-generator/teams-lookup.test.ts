// teams-lookup.test.ts
//
//   deno test --allow-read backend/supabase/functions/team-page-generator/teams-lookup.test.ts
//
// A tournament row's api_football_id is a LEAGUE id, and four of them collide
// with a club or country (45 Everton/FA Cup, 48 West Ham/League Cup, 2 France/
// Champions League, 3 Croatia/Europa League). Every `teams` query in this
// function that filters on api_football_id must exclude tournaments, or
// maybeSingle() errors and the opponent card disappears (bug hunt 2026-11-03
// D-C1: Coventry had no "their ones to watch" for Everton).

import { assert } from "https://deno.land/std@0.208.0/assert/mod.ts";

Deno.test("every teams lookup by api_football_id excludes tournament rows", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const chains = src.split('.from("teams")').slice(1).map((rest) => rest.slice(0, rest.indexOf(";")));
  const byApiId = chains.filter((c) => /\.eq\("api_football_id"|api_football_id\.eq\.|vOrParts/.test(c));
  assert(byApiId.length >= 3, `expected the three opponent lookups, found ${byApiId.length}`);
  for (const c of byApiId) {
    assert(c.includes('.neq("entity_type", "tournament")'), `unfiltered teams lookup:\n${c}`);
  }
});
