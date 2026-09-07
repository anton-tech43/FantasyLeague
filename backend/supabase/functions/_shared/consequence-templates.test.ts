// Deno tests for the consequence card templates.
//
// Why these exist: every one of the 412 edge-generated cards in the 2026 World
// Cup shipped with no immersive_headline and no immersive_context, so they
// rendered as a lowercased grey sentence with nothing underneath — half a card,
// 150 of them pushed, unnoticed for six weeks. Nothing on the Edge side
// validated anything. These tests are that validation.
//
//   deno test _shared/consequence-templates.test.ts

import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { buildContentItem, ContentItemInvalid } from "./build-content-item.ts";
import { IH_LINE_MAX, renderConsequence } from "./consequence-templates.ts";
import type { Consequence, ConsequenceType } from "./detect-consequences.ts";
import type { Team } from "./types.ts";

const ALL_TYPES: ConsequenceType[] = [
  "TITLE_WON",
  "UCL_CLINCHED",
  "EUROPE_CLINCHED",
  "RELEGATED",
  "WC_GROUP_WON",
  "WC_KNOCKOUT_QUALIFIED",
  "WC_KNOCKOUT_ELIMINATED",
  "WC_RIVAL_RESULT",
  "WC_BEST_THIRD_QUALIFIED",
];

function team(display_name: string, short_name = display_name): Team {
  return { id: "x", display_name, short_name } as unknown as Team;
}

function consequence(t: ConsequenceType): Consequence {
  return {
    team_id: "x",
    consequence_type: t,
    trigger_summary: "Chelsea losing 2-1 at Sunderland",
  } as unknown as Consequence;
}

// Real (display_name, short_name) pairs, longest first. A template that only
// behaves for "Arsenal" is a template that breaks in May.
const NAMES: Array<[string, string]> = [
  ["Arsenal", "Arsenal"],
  ["Nottingham Forest", "Nottm Forest"],
  ["Brighton & Hove Albion", "Brighton"],
  ["Crystal Palace", "Crystal Palace"], // longest short_name we carry, 14 chars
];

Deno.test("every consequence type renders both immersive fields", () => {
  for (const t of ALL_TYPES) {
    const c = renderConsequence(consequence(t), team("Arsenal"));
    assert(c.immersive_headline.length > 0, `${t}: empty immersive_headline`);
    assert(c.immersive_context.length > 0, `${t}: empty immersive_context`);
  }
});

Deno.test("immersive_headline is 2-3 lines, each within the card's 22-char row", () => {
  for (const t of ALL_TYPES) {
    for (const [name, short] of NAMES) {
      const c = renderConsequence(consequence(t), team(name, short));
      const lines = c.immersive_headline.split("\n");
      assert(
        lines.length >= 2 && lines.length <= 3,
        `${t}/${name}: ${lines.length} lines, card wants 2-3`,
      );
      for (const l of lines) {
        assert(
          l.length <= IH_LINE_MAX,
          `${t}/${name}: line ${l.length} chars truncates on the card: "${l}"`,
        );
      }
    }
  }
});

Deno.test("immersive_headline is all lowercase and never shouts", () => {
  for (const t of ALL_TYPES) {
    for (const [name, short] of NAMES) {
      const h = renderConsequence(consequence(t), team(name, short)).immersive_headline;
      assertEquals(h, h.toLowerCase(), `${t}/${name}: not lowercase`);
      assert(!/[?!]/.test(h), `${t}/${name}: contains ? or !`);
    }
  }
});

Deno.test("immersive_context stays inside the 16-word girl-ref cap", () => {
  for (const t of ALL_TYPES) {
    const ctx = renderConsequence(consequence(t), team("Arsenal")).immersive_context;
    const words = ctx.trim().split(/\s+/).length;
    assert(words <= 16, `${t}: girl ref is ${words} words (cap 16): "${ctx}"`);
  }
});

Deno.test("no banned register anywhere in the rendered card", () => {
  // PROMPT.md "What the older sister NEVER sounds like" — the crisis-counsellor
  // and indulgent-eye-roll lists. TITLE_WON shipped "Just nod and let the moment
  // land" until the 2026-09 review.
  const banned =
    /(just nod|let him\.|be ready for a long one|brace yourself|he'?ll be unbearable|pretend you didn'?t see|bad mood loading|watch him spiral)/i;
  for (const t of ALL_TYPES) {
    for (let i = 0; i < 20; i++) { // body picks a random variant
      const c = renderConsequence(consequence(t), team("Arsenal"));
      const all = [c.push_title, c.push_text, c.headline, c.body, c.immersive_context, ...c.talking_points]
        .join("\n");
      const m = all.match(banned);
      assert(!m, `${t}: banned register "${m?.[0]}"`);
    }
  }
});

Deno.test("push copy respects the lock-screen caps", () => {
  for (const t of ALL_TYPES) {
    for (const [name, short] of NAMES) {
      const c = renderConsequence(consequence(t), team(name, short));
      assert(c.push_title.length <= 35, `${t}/${name}: push_title ${c.push_title.length} chars`);
      assert(c.push_text.length <= 90, `${t}/${name}: push_text ${c.push_text.length} chars`);
    }
  }
});

Deno.test("buildContentItem accepts every consequence card and rejects a broken one", () => {
  for (const t of ALL_TYPES) {
    for (const [name, short] of NAMES) {
      const c = renderConsequence(consequence(t), team(name, short));
      // Consequence cards other than WC_RIVAL_RESULT render no talking points
      // by design, so supply one the way match-watcher does.
      buildContentItem({
        team_id: "x",
        type: "news",
        headline: c.headline,
        body: c.body,
        immersive_headline: c.immersive_headline,
        immersive_context: c.immersive_context,
        talking_points: c.talking_points.length ? c.talking_points : ["Ask him what that changes."],
        push_title: c.push_title,
        push_text: c.push_text,
      });
    }
  }
  // and the shape that shipped 412 times: no immersive fields at all
  assertThrows(
    () =>
      buildContentItem({
        team_id: "x",
        type: "news",
        headline: "Mexico beat South Africa 2-0",
        body: "A result in the group.",
        immersive_headline: "",
        immersive_context: "",
        talking_points: ["Ask him what that result does to the group."],
      }),
    ContentItemInvalid,
  );
});

Deno.test("buildContentItem repairs a fixable card instead of losing it", () => {
  // The whole point: an over-long title, a Title Case headline and a stray "!"
  // are things we fix, not reasons a card never exists.
  const out = buildContentItem({
    team_id: "brighton",
    type: "news",
    headline: "Brighton break their transfer record",
    body: "Brighton have signed a defender for a club record fee.",
    immersive_headline: "Brighton!\nCLUB RECORD SIGNING CONFIRMED TODAY\nforty-six million.",
    immersive_context: "The friend who never splurges turning up in something expensive.",
    talking_points: ["Tell him Brighton broke their record."],
    push_title: "Brighton have broken their club transfer record today",
  });
  const rows = out.immersive_headline.split("\n");
  assertEquals(rows.length, 3);
  for (const r of rows) assert(r.length <= IH_LINE_MAX, `row too long: "${r}"`);
  assertEquals(out.immersive_headline, out.immersive_headline.toLowerCase());
  assert(!/[?!]/.test(out.immersive_headline));
  assert(out.push_title!.length <= 35, `push_title ${out.push_title!.length}`);
  assert(out.push_title!.length > 0, "push_title must survive, not vanish");
});
