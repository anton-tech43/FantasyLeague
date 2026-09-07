// _shared/build-content-item.ts
//
// One gate every Edge-side `content_items` insert goes through.
//
// Why this exists: across the 2026 World Cup, 412 of 412 cards written by Edge
// Functions shipped with no `immersive_headline` and no `immersive_context`.
// They rendered as a lowercased grey sentence with nothing under it — half a
// card. 150 of them were pushed. Nobody noticed for six weeks, because the
// routine path has `post_news.sh` validating every field and the Edge path had
// nothing at all. Seven of those cards had no talking points either, and they
// were both semi-finals, the third-place match and the final.
//
// The rules here are the same ones `post_news.sh` enforces on the routine side,
// so a card looks the same whoever wrote it.

export interface ContentItemDraft {
  team_id: string;
  type: "news" | "matchday" | "sunday_brief" | "starting_xi";
  headline: string;
  body: string;
  immersive_headline: string;
  immersive_context: string;
  talking_points: string[];
  push_title?: string | null;
  push_text?: string | null;
  // Anything else the caller wants to pass straight through.
  [key: string]: unknown;
}

/// Each `\n`-separated line of `immersive_headline` renders as its own bold row
/// on the card and truncates mid-word past this. Matches PROMPT.md's title spec
/// and the check in post_news.sh.
export const IH_LINE_MAX = 22;
/// `content_items` CHECK constraints. Exceeding these is not a style problem —
/// the INSERT is rejected and the card silently never exists.
export const PUSH_TITLE_MAX = 35;
export const PUSH_TEXT_MAX = 100;
/// PROMPT.md ANALOGY RULES.
export const GIRL_REF_MAX_WORDS = 16;

export class ContentItemInvalid extends Error {
  constructor(readonly field: string, message: string) {
    super(`content_items.${field}: ${message}`);
    this.name = "ContentItemInvalid";
  }
}

/// Repairs what can be repaired, then asserts what cannot.
///
/// The ordering matters and is deliberate. A card that never publishes is the
/// worst outcome we have — two consequence templates built push titles a few
/// characters over the DB CHECK, so every Champions League qualification card
/// and every knockout-elimination card was rejected by Postgres and silently
/// never existed. So: trim, lowercase, split and truncate first, and throw only
/// when a field is absent entirely and there is nothing to repair from.
///
/// A throw here is a bug in OUR code, not in a model's output — every caller is
/// a deterministic template covered by tests — so failing loudly is right.
export function buildContentItem(draft: ContentItemDraft): ContentItemDraft {
  const repairs: string[] = [];

  // --- Repair pass -------------------------------------------------------
  const trimWords = (v: string, limit: number): string => {
    if (v.length <= limit) return v;
    const cut = v.slice(0, limit).trimEnd();
    const out = cut.includes(" ") ? cut.slice(0, cut.lastIndexOf(" ")) : cut;
    return out.replace(/[\s,;:-]+$/, "");
  };

  if (typeof draft.immersive_headline === "string" && draft.immersive_headline.trim()) {
    let ih = draft.immersive_headline;
    if (ih !== ih.toLowerCase()) {
      ih = ih.toLowerCase();
      repairs.push("immersive_headline lowercased");
    }
    if (/[?!]/.test(ih)) {
      ih = ih.replace(/\s*[?!]+/g, ".");
      repairs.push("immersive_headline: stripped ? / !");
    }
    let rows = ih.split("\n").map((l) => l.trim()).filter(Boolean);
    if (rows.length === 1 && rows[0].length > IH_LINE_MAX) {
      const parts = rows[0].match(/[^.!?]+[.!?]*/g)?.map((x) => x.trim()).filter(Boolean) ?? rows;
      if (parts.length > 1) {
        rows = parts;
        repairs.push("immersive_headline: split one long row");
      }
    }
    if (rows.length > 3) {
      rows = rows.slice(0, 3);
      repairs.push("immersive_headline: kept 3 rows");
    }
    rows = rows.map((l) => {
      if (l.length <= IH_LINE_MAX) return l;
      repairs.push(`immersive_headline row trimmed from ${l.length}`);
      return trimWords(l, IH_LINE_MAX - 1).replace(/[\s,.;:]+$/, "") + ".";
    });
    draft.immersive_headline = rows.join("\n");
  }

  if (typeof draft.push_title === "string" && draft.push_title.length > PUSH_TITLE_MAX) {
    repairs.push(`push_title trimmed from ${draft.push_title.length}`);
    draft.push_title = trimWords(draft.push_title, PUSH_TITLE_MAX);
  }
  if (typeof draft.push_text === "string" && draft.push_text.length > PUSH_TEXT_MAX) {
    repairs.push(`push_text trimmed from ${draft.push_text.length}`);
    draft.push_text = trimWords(draft.push_text, PUSH_TEXT_MAX);
  }

  if (repairs.length > 0) {
    console.warn(`buildContentItem repaired ${draft.team_id}: ${repairs.join("; ")}`);
  }

  // --- Assertions: nothing left to repair from ---------------------------
  const req = (field: string, v: unknown) => {
    if (typeof v !== "string" || v.trim().length === 0) {
      throw new ContentItemInvalid(field, "is required and was empty");
    }
  };

  req("team_id", draft.team_id);
  req("headline", draft.headline);
  req("body", draft.body);

  // --- The immersive card ------------------------------------------------
  req("immersive_headline", draft.immersive_headline);
  req("immersive_context", draft.immersive_context);

  const lines = draft.immersive_headline.split("\n");
  if (lines.length > 3) {
    throw new ContentItemInvalid("immersive_headline", `${lines.length} rows after repair, card renders 3`);
  }
  // A single row is flat rather than broken — it still renders, so it is not
  // worth losing the card over.
  for (const l of lines) {
    if (l.length > IH_LINE_MAX) {
      throw new ContentItemInvalid(
        "immersive_headline",
        `line is ${l.length} chars and truncates mid-word on the card: "${l}"`,
      );
    }
  }
  if (draft.immersive_headline !== draft.immersive_headline.toLowerCase()) {
    throw new ContentItemInvalid("immersive_headline", "must be all lowercase (card style)");
  }
  if (/[?!]/.test(draft.immersive_headline)) {
    throw new ContentItemInvalid("immersive_headline", "contains ? or ! — the voice states, it does not shout");
  }

  const words = draft.immersive_context.trim().split(/\s+/).length;
  if (words > GIRL_REF_MAX_WORDS) {
    throw new ContentItemInvalid(
      "immersive_context",
      `${words} words (cap ${GIRL_REF_MAX_WORDS}) — cut it, sharper beats longer`,
    );
  }

  // --- Zone 2 of the card ------------------------------------------------
  if (!Array.isArray(draft.talking_points) || draft.talking_points.length === 0) {
    throw new ContentItemInvalid("talking_points", "is empty, which renders a blank zone on the card");
  }

  // --- Lock screen: these are DB CHECK constraints, not preferences -------
  // Tripwires. The repair pass above should make these unreachable; if one
  // fires, the repair is broken and the DB would have rejected the insert.
  if (draft.push_title && draft.push_title.length > PUSH_TITLE_MAX) {
    throw new ContentItemInvalid("push_title", `${draft.push_title.length} chars after repair, CHECK allows ${PUSH_TITLE_MAX}`);
  }
  if (draft.push_text && draft.push_text.length > PUSH_TEXT_MAX) {
    throw new ContentItemInvalid("push_text", `${draft.push_text.length} chars after repair, CHECK allows ${PUSH_TEXT_MAX}`);
  }

  // --- Voice -------------------------------------------------------------
  // PROMPT.md "What the older sister NEVER sounds like": the crisis-counsellor
  // and indulgent-eye-roll registers. He is a boy who cares too much, not a
  // threat to survive or a bore to endure.
  const banned =
    /(just nod|let him\.|be ready for a long one|brace yourself|he'?ll be unbearable|pretend you didn'?t see|bad mood loading|heavy sigh incoming|watch him spiral)/i;
  const rendered = [
    draft.push_title,
    draft.push_text,
    draft.headline,
    draft.body,
    draft.immersive_context,
    ...draft.talking_points,
  ].filter((s): s is string => typeof s === "string").join("\n");
  const hit = rendered.match(banned);
  if (hit) {
    throw new ContentItemInvalid("voice", `banned register "${hit[0]}"`);
  }

  return draft;
}
