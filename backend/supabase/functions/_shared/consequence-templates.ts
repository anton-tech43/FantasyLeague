// _shared/consequence-templates.ts
//
// Templated copy for cross-team consequence content_items. Every string
// here is deterministic — no LLM call, no token cost. The trigger
// summary embedded in each template comes from the detector
// (`detect-consequences.ts`), built mechanically from the just-finished
// fixture.
//
// Voice matches the routines' gf-to-bf older-sister tone — declarative,
// dry, the occasional knowing aside. Each consequence has 2 randomised
// body variants so the same kind of event in different seasons reads
// slightly differently. The push title + headline stay fixed for
// muscle-memory recognition on the lock screen.
//
// See: detect-consequences.ts (the math), IMPLEMENTATION_PROGRESS
// Lesson 74 (the May 19 Arsenal moment that prompted this layer).

import type { Consequence, ConsequenceType } from "./detect-consequences.ts";
import type { Team } from "./types.ts";

export interface ConsequenceContent {
  push_title: string;
  push_text: string;
  headline: string;
  body: string;
  everyone_talking_headline: string;
}

export function renderConsequence(
  c: Consequence,
  team: Team,
): ConsequenceContent {
  // Non-Partial Record below — TS guarantees every ConsequenceType has
  // a template, so this lookup is total.
  const tmpl = TEMPLATES[c.consequence_type];

  const ctx: TemplateContext = {
    teamName: team.display_name,
    trigger: c.trigger_summary,
  };

  const variantIdx = pickVariant(tmpl.body.length);

  return {
    push_title: tmpl.push_title(ctx),
    push_text: tmpl.push_text(ctx),
    headline: tmpl.headline(ctx),
    body: tmpl.body[variantIdx](ctx),
    everyone_talking_headline: tmpl.everyone_talking_headline(ctx),
  };
}

// ============================================================
// Internal — template shape + per-type entries
// ============================================================

interface TemplateContext {
  teamName: string;
  trigger: string;
}

type Render = (ctx: TemplateContext) => string;

interface ConsequenceTemplate {
  push_title: Render;
  push_text: Render;
  headline: Render;
  // Multiple body variants — random pick at render time. Keeps the
  // copy from feeling robotic across the season.
  body: Render[];
  everyone_talking_headline: Render;
}

function pickVariant(n: number): number {
  return Math.floor(Math.random() * n);
}

const TEMPLATES: Record<ConsequenceType, ConsequenceTemplate> = {
  TITLE_WON: {
    push_title: ({ teamName }) => `🏆 ${teamName} are champions`,
    push_text: ({ trigger }) => `${trigger}. He gets to enjoy this one.`,
    headline: ({ teamName }) => `${teamName} are champions of England.`,
    body: [
      ({ teamName, trigger }) =>
        `Done. ${trigger} means it's mathematically impossible for anyone to catch them. Trophy presentation comes Sunday — and so does the chat about how long it's been. Just nod and let him have the moment.`,
      ({ teamName, trigger }) =>
        `${teamName} have won the Premier League. ${trigger}, and the maths now says no one else can reach them. Expect a quiet kind of happy from him this week — the kind that's earned.`,
    ],
    everyone_talking_headline: ({ teamName, trigger }) =>
      `${teamName} crowned Premier League champions after ${trigger.toLowerCase()}.`,
  },

  UCL_CLINCHED: {
    push_title: ({ teamName }) => `🌟 ${teamName}: Champions League locked in`,
    push_text: ({ teamName, trigger }) =>
      `${teamName} are guaranteed a top-4 spot. ${trigger}.`,
    headline: ({ teamName }) =>
      `${teamName} are in next season's Champions League.`,
    body: [
      ({ teamName, trigger }) =>
        `Top-4 sewn up. ${trigger} pushed ${teamName} into a position no one below them can reach. European nights at the stadium next season — and a budget to match.`,
      ({ teamName, trigger }) =>
        `${teamName} have clinched a Champions League spot. After ${trigger.toLowerCase()}, the maths is settled — they can't drop out of the top four. Big midweek nights are back.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} clinch top-4 and a Champions League return.`,
  },

  EUROPE_CLINCHED: {
    push_title: ({ teamName }) => `✈️ ${teamName}: Europe is on`,
    push_text: ({ teamName, trigger }) =>
      `${teamName} are guaranteed European football next season. ${trigger}.`,
    headline: ({ teamName }) =>
      `${teamName} have qualified for European football.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger}. ${teamName} are now mathematically in the European places — could be Champions League, Europa, or Conference, depending on where they finish. Either way, Thursday or Tuesday nights are about to get more interesting.`,
      ({ teamName, trigger }) =>
        `Europe confirmed for ${teamName}. After ${trigger.toLowerCase()}, no one in the bottom half can catch them. The exact competition gets decided in the final round, but the trip itself is booked.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} secure European football for next season.`,
  },

  RELEGATED: {
    push_title: ({ teamName }) => `📉 ${teamName} relegated`,
    push_text: ({ trigger }) => `${trigger}. The Premier League ride is over.`,
    headline: ({ teamName }) => `${teamName} are down.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger} confirmed it — ${teamName} can't escape the bottom three even if they win every remaining game. Next stop: the Championship, where his Saturdays get a lot less prime-time. Be gentle this week.`,
      ({ teamName, trigger }) =>
        `${teamName} have been relegated. After ${trigger.toLowerCase()}, the maths is final. A season of struggle ends with a drop to the second tier — and a summer of rebuilding. He'll want to talk about it, eventually.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} relegated from the Premier League.`,
  },

  // ---------- World Championship ----------

  WC_GROUP_WON: {
    push_title: ({ teamName }) => `🥇 ${teamName} win the group`,
    push_text: ({ teamName, trigger }) =>
      `${teamName} have topped their World Championship group. ${trigger}.`,
    headline: ({ teamName }) =>
      `${teamName} finish top of their World Championship group.`,
    body: [
      ({ teamName, trigger }) =>
        `${teamName} are through as group winners. ${trigger}, and that puts them mathematically clear of second place. Top of the group usually means a slightly kinder knockout bracket — small advantages stack up at a World Championship.`,
      ({ teamName, trigger }) =>
        `Group topped. After ${trigger.toLowerCase()}, ${teamName} can't be overtaken in their group. They go into the knockouts as a top seed, which is exactly where you want to be.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} clinch top spot in their World Championship group.`,
  },

  WC_KNOCKOUT_QUALIFIED: {
    push_title: ({ teamName }) => `✅ ${teamName} into the knockouts`,
    push_text: ({ teamName, trigger }) =>
      `${teamName} have qualified for the World Championship knockouts. ${trigger}.`,
    headline: ({ teamName }) =>
      `${teamName} are through to the knockout stage.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger} sealed it. ${teamName} are guaranteed a knockout spot. Group placement might still move, but the round-of-32 trip is locked in. From here it's win or go home.`,
      ({ teamName, trigger }) =>
        `${teamName} into the knockouts. After ${trigger.toLowerCase()}, the maths confirms they can't be caught for at least second in their group. Knockout football arrives next week.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} reach the World Championship knockout stage.`,
  },

  WC_KNOCKOUT_ELIMINATED: {
    push_title: ({ teamName }) => `⚠️ ${teamName} out of the World Championship`,
    push_text: ({ trigger }) =>
      `${trigger}. The group-stage exit is confirmed.`,
    headline: ({ teamName }) =>
      `${teamName} are out of the World Championship.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger} ended it. ${teamName} can no longer reach the knockout stage. One game left, but the tournament is effectively over for them — and for him, the focus shifts to whoever's still in.`,
      ({ teamName, trigger }) =>
        `World Championship over for ${teamName}. After ${trigger.toLowerCase()}, the qualification maths is closed — they can't reach the top two. He'll need a new team to root for in the knockouts.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} eliminated from the World Championship group stage.`,
  },

  // Informational rival result for a NON-playing team in the same group.
  // Factual only — states what happened, never derives "what you need"
  // (that depends on a refreshed table + tiebreakers and lives in-app).
  WC_RIVAL_RESULT: {
    push_title: ({ teamName }) => `${teamName}'s group`,
    push_text: ({ teamName, trigger }) => `${trigger} in ${teamName}'s group.`,
    headline: ({ trigger }) => `${trigger}.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger}. A result in ${teamName}'s group. The table and what it means for them is on the team page.`,
      ({ teamName, trigger }) =>
        `${trigger}. That shifts things in ${teamName}'s group. Check the team page for where it leaves them.`,
    ],
    everyone_talking_headline: ({ teamName, trigger }) =>
      `${trigger}, in ${teamName}'s group.`,
  },
};
