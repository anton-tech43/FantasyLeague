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
  /// Headline for the immersive feed card: 2-3 `\n`-separated lines, each
  /// <=22 chars, all lowercase. ImmersiveCard renders every line as its own
  /// bold row and truncates mid-word above 22. Without this the card falls
  /// back to `headline.lowercased()` and renders as one long grey sentence —
  /// which is what all 412 edge-generated World Cup cards did.
  immersive_headline: string;
  /// The "girl ref" line under the headline. Deterministic here, so it speaks
  /// to the shape of the event rather than the specific story.
  immersive_context: string;
  /// Prompts for the feed item's "Your move" section. Empty for consequence
  /// types that define none (only WC_RIVAL_RESULT does today).
  talking_points: string[];
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
    shortName: team.short_name || team.display_name,
    trigger: c.trigger_summary,
  };

  const variantIdx = pickVariant(tmpl.body.length);
  const talkingPoints = tmpl.talking_points && tmpl.talking_points.length > 0
    ? [tmpl.talking_points[pickVariant(tmpl.talking_points.length)](ctx)]
    : [];

  return {
    push_title: tmpl.push_title(ctx),
    push_text: fitPushText(tmpl.push_text(ctx)),
    headline: tmpl.headline(ctx),
    body: tmpl.body[variantIdx](ctx),
    everyone_talking_headline: tmpl.everyone_talking_headline(ctx),
    immersive_headline: tmpl.immersive_headline(ctx),
    immersive_context: tmpl.immersive_context(ctx),
    talking_points: talkingPoints,
  };
}

// ============================================================
// Internal — template shape + per-type entries
// ============================================================

interface TemplateContext {
  /// Full club name — safe in headline/body, which have no tight cap.
  teamName: string;
  /// Short name for the lock screen and the card. `content_items.push_title`
  /// has a 35-char CHECK constraint, and "Brighton & Hove Albion" alone is 22,
  /// which took TITLE_WON to 38 chars — the insert would have been rejected by
  /// the database and the card would simply never have appeared.
  shortName: string;
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
  immersive_headline: Render;
  immersive_context: Render;
  // Optional rotating "Your move" prompts. Safe, open conversation openers
  // only — never a qualification claim (the live table + tiebreakers live
  // in-app; this layer has no fresh standings).
  talking_points?: Render[];
}

function pickVariant(n: number): number {
  return Math.floor(Math.random() * n);
}

/// The immersive card gives each `\n`-separated line its own bold row and
/// truncates mid-word past 22 characters. Building headlines through this
/// helper makes the cap impossible to break by hand — a club with a long
/// display name can't quietly push a line over the edge.
export const IH_LINE_MAX = 22;

function ihLine(raw: string): string {
  const t = raw.trim().toLowerCase();
  if (t.length <= IH_LINE_MAX) return t;
  return t.slice(0, IH_LINE_MAX - 1).replace(/[\s,.;:]+$/, "") + ".";
}

function immersiveHeadline(...lines: string[]): string {
  return lines.map(ihLine).filter((l) => l.length > 0).slice(0, 3).join("\n");
}

/// `push_text` interpolates `trigger_summary`, which the detector builds from
/// whatever fixture just finished — so its length is not ours to control. A
/// long trigger took EUROPE_CLINCHED to 102 characters against a CHECK of 100,
/// which means the INSERT is rejected and the card never exists. Drop whole
/// trailing sentences until it fits, so the lock screen keeps the fact and
/// loses only the detail.
export const PUSH_TEXT_TARGET = 90;

function fitPushText(text: string): string {
  if (text.length <= PUSH_TEXT_TARGET) return text;
  const sentences = text.match(/[^.!?]+[.!?]+/g) ?? [text];
  let out = "";
  for (const sentence of sentences) {
    if ((out + sentence).trim().length > PUSH_TEXT_TARGET) break;
    out += sentence;
  }
  out = out.trim();
  if (out.length > 0) return out;
  // A single sentence longer than the target: cut on a word boundary.
  return text.slice(0, PUSH_TEXT_TARGET - 1).replace(/\s+\S*$/, "") + ".";
}

const TEMPLATES: Record<ConsequenceType, ConsequenceTemplate> = {
  TITLE_WON: {
    push_title: ({ shortName }) => `🏆 ${shortName} are champions`,
    push_text: ({ trigger }) => `${trigger}. This one is worth celebrating together.`,
    headline: ({ teamName }) => `${teamName} are champions of England.`,
    body: [
      ({ teamName, trigger }) =>
        `Done. ${trigger} means it's mathematically impossible for anyone to catch them. Trophy presentation comes Sunday, and so does the chat about how long it's been. He has earned every minute of it.`,
      ({ teamName, trigger }) =>
        `${teamName} have won the Premier League. ${trigger}, and the maths now says no one else can reach them. Expect a quiet kind of happy this week, the kind that's earned.`,
    ],
    everyone_talking_headline: ({ teamName, trigger }) =>
      `${teamName} crowned Premier League champions after ${trigger}.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("champions.", `${shortName}.`, "the maths says so."),
    immersive_context: () => "The friend who planned the entire wedding finally sitting down at her own reception.",
  },

  UCL_CLINCHED: {
    push_title: ({ shortName }) => `🌟 ${shortName}: top four`,
    push_text: ({ teamName, trigger }) =>
      `${teamName} are guaranteed a top-4 spot. ${trigger}.`,
    headline: ({ teamName }) =>
      `${teamName} are in next season's Champions League.`,
    body: [
      ({ teamName, trigger }) =>
        `Top-4 sewn up. ${trigger} pushed ${teamName} into a position no one below them can reach. European nights at the stadium next season — and a budget to match.`,
      ({ teamName, trigger }) =>
        `${teamName} have clinched a Champions League spot. After ${trigger}, the maths is settled — they can't drop out of the top four. Big midweek nights are back.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} clinch top-4 and a Champions League return.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("top four.", `${shortName}.`, "europe is booked."),
    immersive_context: () => "The colleague who quietly hit every target and got the corner office in May.",
  },

  EUROPE_CLINCHED: {
    push_title: ({ shortName }) => `✈️ ${shortName}: Europe is on`,
    push_text: ({ teamName, trigger }) =>
      `${teamName} are guaranteed European football next season. ${trigger}.`,
    headline: ({ teamName }) =>
      `${teamName} have qualified for European football.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger}. ${teamName} are now mathematically in the European places — could be Champions League, Europa, or Conference, depending on where they finish. Either way, Thursday or Tuesday nights are about to get more interesting.`,
      ({ teamName, trigger }) =>
        `Europe confirmed for ${teamName}. After ${trigger}, no one in the bottom half can catch them. The exact competition gets decided in the final round, but the trip itself is booked.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} secure European football for next season.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("europe confirmed.", `${shortName}.`, "thursday nights back."),
    immersive_context: () => "Getting the group holiday booked before anyone else has checked their annual leave.",
  },

  RELEGATED: {
    push_title: ({ shortName }) => `📉 ${shortName} relegated`,
    push_text: ({ trigger }) => `${trigger}. The Premier League ride is over.`,
    headline: ({ teamName }) => `${teamName} are down.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger} confirmed it — ${teamName} can't escape the bottom three even if they win every remaining game. Next stop: the Championship, where Saturdays get a lot less prime-time. Be gentle this week.`,
      ({ teamName, trigger }) =>
        `${teamName} have been relegated. After ${trigger}, the maths is final. A season of struggle ends with a drop to the second tier — and a summer of rebuilding. It will come up in conversation, eventually.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} relegated from the Premier League.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("down.", `${shortName}.`, "championship next."),
    immersive_context: () => "The flatmate whose lease ends and everyone carries boxes down in silence.",
  },

  // ---------- World Championship ----------

  WC_GROUP_WON: {
    push_title: ({ shortName }) => `🥇 ${shortName} win the group`,
    push_text: ({ teamName, trigger }) => {
      const full = `${teamName} have topped their group. ${trigger}.`;
      return full.length <= 90 ? full : `${teamName} have topped their group.`;
    },
    headline: ({ teamName }) =>
      `${teamName} finish top of their World Championship group.`,
    body: [
      ({ teamName, trigger }) =>
        `${teamName} are through as group winners. ${trigger}, and that puts them mathematically clear of second place. Top of the group usually means a slightly kinder knockout bracket — small advantages stack up at a World Championship.`,
      ({ teamName, trigger }) =>
        `Group topped. After ${trigger}, ${teamName} can't be overtaken in their group. They go into the knockouts as a top seed, which is exactly where you want to be.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} clinch top spot in their World Championship group.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("group winners.", `${shortName}.`, "knockouts next."),
    immersive_context: () => "Topping a group chat poll you did not know you had entered.",
  },

  WC_KNOCKOUT_QUALIFIED: {
    push_title: ({ shortName }) => `✅ ${shortName} are through`,
    push_text: ({ teamName, trigger }) => {
      const full = `${teamName} are into the knockouts. ${trigger}.`;
      return full.length <= 90 ? full : `${teamName} are into the knockouts.`;
    },
    headline: ({ teamName }) =>
      `${teamName} are through to the knockout stage.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger} sealed it. ${teamName} are guaranteed a knockout spot. Group placement might still move, but the round-of-32 trip is locked in. From here it's win or go home.`,
      ({ teamName, trigger }) =>
        `${teamName} into the knockouts. After ${trigger}, the maths confirms they can't be caught for at least second in their group. Knockout football arrives next week.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} reach the World Championship knockout stage.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("through.", `${shortName}.`, "knockouts next."),
    immersive_context: () => "Squeaking onto the guest list at 2am as the door was closing.",
  },

  WC_KNOCKOUT_ELIMINATED: {
    push_title: ({ shortName }) => `⚠️ The end for ${shortName}`,
    push_text: ({ trigger }) =>
      `${trigger}. The group-stage exit is confirmed.`,
    headline: ({ teamName }) =>
      `${teamName} are out of the World Championship.`,
    body: [
      ({ teamName, trigger }) =>
        `${trigger} ended it. ${teamName} can no longer reach the knockout stage. One game left, but the tournament is effectively over for them — the focus shifts to whoever's still in.`,
      ({ teamName, trigger }) =>
        `World Championship over for ${teamName}. After ${trigger}, the qualification maths is closed — they can't reach the top two. Time to pick a new team to root for in the knockouts.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} eliminated from the World Championship group stage.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("out.", `${shortName}.`, "that is the run."),
    immersive_context: () => "The last night of a holiday nobody was ready to end.",
  },

  // Informational rival result for a NON-playing team in the same group.
  // Factual only — states what happened, never derives "what you need"
  // (that depends on a refreshed table + tiebreakers and lives in-app).
  WC_RIVAL_RESULT: {
    push_title: ({ shortName }) => `${shortName}'s group`,
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
    // Safe open prompts only — they never assert what the result MEANS for
    // qualification (that needs the live table, which is on the team page).
    immersive_headline: ({ shortName }) => immersiveHeadline("a result.", `${shortName}\u0027s group.`, "the table moved."),
    immersive_context: () => "Someone else\u0027s change of plan redrawing the seating chart at a wedding you are already at.",
    talking_points: [
      ({ teamName }) => `Ask what that result does to ${teamName}'s group.`,
      ({ teamName }) => `Worth asking how that shifts things for ${teamName}.`,
      ({ teamName }) => `Ask if that one helps or hurts ${teamName}.`,
      ({ teamName }) => `Good moment to ask where that leaves ${teamName}.`,
      ({ teamName }) => `Ask what ${teamName} need from their own game now.`,
    ],
  },

  // Good news: through as one of the 8 best third-placed teams.
  WC_BEST_THIRD_QUALIFIED: {
    push_title: ({ shortName }) => `✅ ${shortName} sneak through`,
    push_text: ({ teamName, trigger }) => {
      const full = `${teamName} are through as one of the best third-placed teams. ${trigger}.`;
      return full.length <= 90 ? full : `${teamName} are through as one of the best third-placed teams.`;
    },
    headline: ({ teamName }) => `${teamName} are through as a best third-placed team.`,
    body: [
      ({ teamName, trigger }) =>
        `${teamName} have done just enough. ${trigger}, and the maths across the other groups confirms they are one of the eight best third-placed teams. The back door to the Round of 32, but a place is a place.`,
      ({ teamName, trigger }) =>
        `Through the side door. After ${trigger}, ${teamName} are mathematically safe as one of the best third-placed sides. Knockout football, just about.`,
    ],
    everyone_talking_headline: ({ teamName }) =>
      `${teamName} qualify as one of the best third-placed teams.`,
    immersive_headline: ({ shortName }) => immersiveHeadline("through.", `${shortName}.`, "best third place."),
    immersive_context: () => "Getting the cancellation slot you had already given up refreshing for.",
  },
};
