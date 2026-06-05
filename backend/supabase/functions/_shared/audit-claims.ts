// _shared/audit-claims.ts
//
// Deterministic content auditor. Given a content_item's text and the
// team's ACTUAL final league rank, flags claims that contradict the
// table. ZERO LLM calls — pure regex + integer comparison, so it's free
// to run on every item and it can't itself hallucinate.
//
// WHY THIS EXISTS
// On 2026-05-31 a Sunday-brief item said West Ham "stay up" while they
// finished 18th (relegated — PL drops the bottom THREE). The routine had
// the correct standings; it reasoned wrongly about them. An LLM
// re-reading the same data can repeat the mistake, so the robust check
// is deterministic: compare the CLAIM to the RANK.
//
// PRECISION OVER RECALL. A noisy auditor gets ignored, so we only flag a
// claim when ALL of these hold:
//   1. It's TERMINAL phrasing (past/settled), not a fight/conditional.
//   2. Its SUBJECT is the tagged team — the team's name/alias is the
//      nearest one to the claim (a club's feed constantly references
//      OTHER clubs: "Arsenal are champions" inside Man City's feed must
//      NOT flag City).
//   3. No competition escape ("Europa League champions") or temporal
//      escape ("won the league last season", "the title in 2012").
// Missing a real bug is acceptable; crying wolf is not. Scope: PL only
// (20 teams, bottom 3 down, 1st = champions). WC group math is a follow-up.

export interface RankInfo {
  teamId: string;
  rank: number; // 1-based final/current league position
  totalTeams: number; // e.g. 20 for the PL
  leagueId: number; // 39 PL, 1 WC
}

export interface AuditFinding {
  code:
    | "safe_but_relegated"
    | "relegated_but_safe"
    | "champions_but_not_first"
    | "ucl_but_outside_top_five";
  severity: "contradiction" | "warning";
  claim: string;
  detail: string;
}

// Safe, SPECIFIC aliases. Deliberately no bare "City"/"United"/"Town" —
// they collide across Manchester City, the four "* United" clubs, etc.
// Missing an alias only costs recall (claim left unattributed → skipped),
// never precision.
const PL_ALIASES: Record<string, string[]> = {
  arsenal: ["Arsenal", "Gunners"],
  aston_villa: ["Aston Villa", "Villa"],
  bournemouth: ["Bournemouth"],
  brentford: ["Brentford"],
  brighton: ["Brighton"],
  burnley: ["Burnley"],
  chelsea: ["Chelsea"],
  crystal_palace: ["Crystal Palace", "Palace"],
  everton: ["Everton"],
  fulham: ["Fulham"],
  leeds: ["Leeds"],
  liverpool: ["Liverpool"],
  man_city: ["Manchester City", "Man City"],
  man_utd: ["Manchester United", "Man Utd", "Man United"],
  newcastle: ["Newcastle"],
  nottm_forest: ["Nottingham Forest", "Nottm Forest", "Forest"],
  spurs: ["Tottenham", "Spurs"],
  sunderland: ["Sunderland"],
  west_ham: ["West Ham"],
  wolves: ["Wolves", "Wolverhampton"],
};

// alias (lowercase) -> slug, longest-first regex for nearest-team lookup.
const ALIAS_TO_SLUG = new Map<string, string>();
for (const [slug, names] of Object.entries(PL_ALIASES)) {
  for (const n of names) ALIAS_TO_SLUG.set(n.toLowerCase(), slug);
}
const ALIAS_REGEX = new RegExp(
  "\\b(" +
    [...ALIAS_TO_SLUG.keys()]
      .sort((a, b) => b.length - a.length)
      .map((a) => a.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
      .join("|") +
    ")\\b",
  "gi",
);

// --- claim patterns (TERMINAL phrasing only) ---------------------------

const SAFE_CLAIMS = [
  /stay(?:ed)?\s+up\b/i,
  /(?:are|is|now|mathematically)\s+safe\b/i,
  /avoided\s+relegation/i, // past tense — "avoid relegation" is a goal, not a result
  /beat\s+the\s+drop/i,
  /survived\s+(?:relegation|the\s+drop|the\s+final\s+day|the\s+season)/i,
  /secur(?:ed|ing)\s+(?:their\s+)?(?:premier\s+league\s+)?(?:safety|survival|status)/i,
  /pulled\s+clear\s+of\s+the\s+drop/i,
];

const RELEGATED_CLAIMS = [
  /(?:are|were|have\s+been|is|been)\s+relegated/i,
  /relegated\s+to\s+the\s+championship/i,
  /(?:dropped|drop)\s+(?:in)?to\s+the\s+championship/i,
  /\bare\s+down\b/i,
  /(?:relegation|the\s+drop)\s+(?:is\s+)?confirmed/i,
  /(?:go|gone|going)\s+down\b/i,
];

const CHAMPIONS_CLAIMS = [
  /(?:are|crowned)\s+(?:the\s+)?champions(?!\s+league)/i,
  /champions\s+of\s+england/i,
  /premier\s+league\s+champions/i,
  /won\s+the\s+(?:premier\s+)?league\b/i,
  /(?:clinched|won|sealed)\s+the\s+title\b/i,
  /title\s+winners/i,
];

// Positive QUALIFICATION claims only. Bare "in/into the Champions League"
// is dropped — it matched "denied a spot in the CL" (missed out) and
// "PSG win the CL" (another club). A team finishing >5 that genuinely
// "qualified for the Champions League" is the only thing worth a verify.
const UCL_CLAIMS = [
  /qualified\s+for\s+(?:the\s+)?champions\s+league/i,
  /(?:secured|sealed|clinched)\s+(?:a\s+)?(?:champions\s+league\s+(?:spot|place|football|berth)|top[\s-]?(?:four|4)(?:\s+(?:spot|place|finish))?)/i,
  /(?:made|finished\s+in)\s+(?:the\s+)?top\s*(?:four|4)/i,
];

// If a claim's SENTENCE contains any of these, it's hypothetical,
// predicted, historical, or negative — not a settled assertion. Checked
// across the whole sentence because the qualifier is often far from the
// claim ("If both happen, West Ham stay up"; "Sky's calling it: Spurs go
// down"; "Last season's Premier League champions Liverpool").
const SENTENCE_BLOCKER =
  /(?:\bif\b|unless|in\s+case|could|would|should|might|\bmay\b|predict|calling\s+it|reckons?|expect|tipped|forecast|scenario|hop(?:e|ing)|fear|on\s+the\s+brink|in\s+danger|\brisk\b|fight(?:ing)?|battl(?:e|ing)|race\s+(?:to|for)|chas(?:e|ing)|to\s+avoid|to\s+survive|to\s+stay|drop\s+points|would\s+mean|could\s+see|need(?:s|ed)?\s+to|\bmust\b|contingency|last\s+season|defending|reigning|defen[cs]e|years?\s+ago|\b(?:19|20)\d\d\b|finalists?|\bcost\b|denied|miss(?:ed)?\b|dream|(?:went|fell|dropped|gone|slipped|tumbled)\s+from)/i;

const NEGATORS =
  /(?:not|n't|never|didn't|couldn't|wouldn't|won't|aren't|isn't|no\s+longer)\s*$/i;
const CONDITIONALS =
  /(?:need(?:s|ed)?\s+to|fight(?:ing)?\s+(?:to|for)|battl(?:e|ing)\s+(?:to|for)|trying\s+to|hop(?:e|ing)\s+to|must|race\s+(?:to|for)|chance\s+(?:to|of)|desperate\s+to|in\s+order\s+to|risk\s+of|in\s+danger\s+of|could\s+(?:be|still)|on\s+the\s+brink\s+of|threat(?:ened)?\s+with|facing|to\s+avoid|chasing|push\s+(?:to|for)|predict(?:ing|ed)?|will|if\s+they|fear)\s*$/i;
const RELEGATION_NONCLAIM_SUFFIX =
  /^\s*(?:rivals?|fight|battle|zone|scrap|threat|trouble|candidates?|six-pointer|places?|spots?|worries|dogfight|defining|-defining|picture)/i;
// PAST / different-competition escapes near champions & relegation claims.
const TEMPORAL_PAST =
  /(?:last\s+season|defending|reigning|title\s+defen[cs]e|years?\s+ago|\b(?:19|20)\d\d\b|back\s+in\b)/i;
const COMPETITION_BEFORE = /(?:europa|conference|champions)\s+league\s*$/i;

function before(text: string, idx: number, n = 30): string {
  return text.slice(Math.max(0, idx - n), idx);
}
function after(text: string, idx: number, n = 26): string {
  return text.slice(idx, idx + n);
}
function sentenceBounds(text: string, idx: number): [number, number] {
  const s = text.lastIndexOf(".", idx - 1);
  const nl = text.lastIndexOf("\n", idx - 1);
  const q1 = text.lastIndexOf("!", idx - 1);
  const q2 = text.lastIndexOf("?", idx - 1);
  const start = Math.max(s, nl, q1, q2) + 1;
  let end = text.length;
  for (const ch of [".", "\n", "!", "?"]) {
    const e = text.indexOf(ch, idx);
    if (e >= 0 && e < end) end = e;
  }
  return [start, end];
}

// The team whose alias sits NEAREST the claim span within its sentence
// (before or after). null if no team is named in that sentence.
function nearestTeam(text: string, claimStart: number, claimEnd: number): string | null {
  const [sStart, sEnd] = sentenceBounds(text, claimStart);
  const sentence = text.slice(sStart, sEnd);
  ALIAS_REGEX.lastIndex = 0;
  let best: { slug: string; dist: number } | null = null;
  let m: RegExpExecArray | null;
  while ((m = ALIAS_REGEX.exec(sentence)) !== null) {
    const mStart = sStart + m.index;
    const mEnd = mStart + m[0].length;
    const dist = mEnd <= claimStart ? claimStart - mEnd : mStart >= claimEnd ? mStart - claimEnd : 0;
    const slug = ALIAS_TO_SLUG.get(m[0].toLowerCase());
    if (slug && (best === null || dist < best.dist)) best = { slug, dist };
  }
  return best?.slug ?? null;
}

function findClaim(
  text: string,
  patterns: RegExp[],
  teamId: string,
  opts: { relegationSense?: boolean; temporalGuard?: boolean } = {},
): string | null {
  for (const base of patterns) {
    const p = new RegExp(base.source, base.flags.includes("g") ? base.flags : base.flags + "g");
    let m: RegExpExecArray | null;
    while ((m = p.exec(text)) !== null) {
      const b = before(text, m.index);
      const a = after(text, m.index + m[0].length);
      if (NEGATORS.test(b) || CONDITIONALS.test(b)) continue;
      if (opts.relegationSense && RELEGATION_NONCLAIM_SUFFIX.test(a)) continue;
      if (opts.temporalGuard && (TEMPORAL_PAST.test(b) || TEMPORAL_PAST.test(a))) continue;
      if (COMPETITION_BEFORE.test(b)) continue; // "Europa League champions" etc.
      const [sStart, sEnd] = sentenceBounds(text, m.index);
      if (SENTENCE_BLOCKER.test(text.slice(sStart, sEnd))) continue; // hypothetical/predicted/historical/negative
      if (nearestTeam(text, m.index, m.index + m[0].length) !== teamId) continue; // subject gate
      return m[0];
    }
  }
  return null;
}

export function auditContentClaims(text: string, info: RankInfo): AuditFinding[] {
  if (info.leagueId !== 39) return []; // PL only for now
  if (!text || info.rank < 1) return [];

  const findings: AuditFinding[] = [];
  const cutoff = info.totalTeams - 2; // 20 -> 18 (18,19,20 relegated)

  const safe = findClaim(text, SAFE_CLAIMS, info.teamId);
  if (safe && info.rank >= cutoff) {
    findings.push({
      code: "safe_but_relegated",
      severity: "contradiction",
      claim: safe,
      detail: `Claims survival ("${safe}") but ${info.teamId} finished ${info.rank}/${info.totalTeams} — bottom ${info.totalTeams - cutoff + 1} go down, so they were RELEGATED.`,
    });
  }

  const releg = findClaim(text, RELEGATED_CLAIMS, info.teamId, {
    relegationSense: true,
    temporalGuard: true,
  });
  if (releg && info.rank < cutoff) {
    findings.push({
      code: "relegated_but_safe",
      severity: "contradiction",
      claim: releg,
      detail: `Claims relegation ("${releg}") but ${info.teamId} finished ${info.rank}/${info.totalTeams} — above the drop zone (${cutoff}+).`,
    });
  }

  const champs = findClaim(text, CHAMPIONS_CLAIMS, info.teamId, { temporalGuard: true });
  if (champs && info.rank !== 1) {
    findings.push({
      code: "champions_but_not_first",
      severity: "contradiction",
      claim: champs,
      detail: `Claims the title ("${champs}") but ${info.teamId} finished ${info.rank}, not 1st.`,
    });
  }

  const ucl = findClaim(text, UCL_CLAIMS, info.teamId);
  if (ucl && info.rank > 5) {
    findings.push({
      code: "ucl_but_outside_top_five",
      severity: "warning",
      claim: ucl,
      detail: `Claims Champions League / top-four ("${ucl}") but ${info.teamId} finished ${info.rank}. Verify (cup/coefficient routes exist).`,
    });
  }

  return findings;
}

/** Concatenate the user-visible text fields of a content_item for audit. */
export function itemAuditText(item: Record<string, unknown>): string {
  const parts = [
    item.headline,
    item.body,
    item.push_title,
    item.push_text,
    item.immersive_headline,
    item.immersive_context,
    item.everyone_talking_headline,
    item.everyone_talking_body,
  ];
  return parts.filter((p): p is string => typeof p === "string").join("\n");
}
