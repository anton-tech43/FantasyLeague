// _shared/input-sanitizer.ts
// Goal Digger — Input sanitization for RSS/API content (PROMPTS.md 6 rules)
// Defends against prompt injection from untrusted external data

const MAX_ARTICLE_LENGTH = 2000;
const MAX_ARTICLES_PER_PROMPT = 10;

// Rule 5: Adversarial patterns to detect and strip
const ADVERSARIAL_PATTERNS = [
  /^(SYSTEM|INSTRUCTION|IMPORTANT|OVERRIDE|IGNORE PREVIOUS):/im,
  /ignore previous instructions/i,
  /disregard above/i,
  /new instructions/i,
  /forget (all |your |the )?(previous |prior )?instructions/i,
  /you are now/i,
  /act as/i,
  /pretend to be/i,
];

// Rule 5: Detect excessive repetition (same phrase >5 times)
function hasExcessiveRepetition(text: string): boolean {
  const words = text.toLowerCase().split(/\s+/);
  const phrases: Record<string, number> = {};
  for (let i = 0; i < words.length - 2; i++) {
    const phrase = words.slice(i, i + 3).join(" ");
    phrases[phrase] = (phrases[phrase] ?? 0) + 1;
    if (phrases[phrase] > 5) return true;
  }
  return false;
}

// Rule 5: Detect base64 blocks >100 chars
function hasLargeBase64Blocks(text: string): boolean {
  const base64Pattern = /[A-Za-z0-9+/=]{100,}/;
  return base64Pattern.test(text);
}

// Rule 1: Strip all HTML tags
function stripHtml(text: string): string {
  return text.replace(/<[^>]*>/g, "");
}

// Rule 4: Remove control characters except \n and \t
function stripControlChars(text: string): string {
  return text.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "");
}

export interface SanitizeResult {
  text: string;
  flagged: boolean;
  flags: string[];
}

/**
 * Sanitize a single article/text from an external source.
 * Applies all 6 rules from PROMPTS.md input sanitization section.
 */
export function sanitizeText(raw: string): SanitizeResult {
  const flags: string[] = [];

  // Rule 1: Strip HTML
  let text = stripHtml(raw);

  // Rule 4: Strip control characters
  text = stripControlChars(text);

  // Rule 5: Detect adversarial patterns
  for (const pattern of ADVERSARIAL_PATTERNS) {
    if (pattern.test(text)) {
      flags.push(`adversarial_pattern: ${pattern.source}`);
      text = text.replace(pattern, "[REMOVED]");
    }
  }

  // Rule 5: Detect excessive repetition
  if (hasExcessiveRepetition(text)) {
    flags.push("excessive_repetition");
  }

  // Rule 5: Detect large base64 blocks
  if (hasLargeBase64Blocks(text)) {
    flags.push("large_base64_block");
    text = text.replace(/[A-Za-z0-9+/=]{100,}/g, "[BASE64_REMOVED]");
  }

  // Rule 2: Truncate to max length
  if (text.length > MAX_ARTICLE_LENGTH) {
    text = text.slice(0, MAX_ARTICLE_LENGTH) + " [truncated]";
    flags.push("truncated");
  }

  return {
    text: text.trim(),
    flagged: flags.length > 0,
    flags,
  };
}

/**
 * Sanitize an array of articles for prompt use.
 * Rule 3: Max 10 articles per prompt — takes top N.
 */
export function sanitizeArticles(articles: string[]): SanitizeResult[] {
  return articles
    .slice(0, MAX_ARTICLES_PER_PROMPT)
    .map((article) => sanitizeText(article));
}

/**
 * Wrap external data in XML tags for prompt-level defense.
 * Rule 6: External content is wrapped in <external_data> tags.
 */
export function wrapExternalData(
  data: string,
  source: string
): string {
  return `<external_data source="${source}" trust_level="untrusted">\n${data}\n</external_data>`;
}
