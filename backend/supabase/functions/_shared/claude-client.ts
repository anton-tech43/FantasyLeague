// _shared/claude-client.ts
// Goal Digger — Anthropic Claude API client with retry logic
//
// ⚠️ COST WARNING — read BEFORE looping this across teams ⚠️
// Every callClaude() invocation bills your Anthropic API CREDIT BALANCE
// (pay-per-token). This is SEPARATE from the claude.ai subscription
// quota that the routines pipeline uses for free. On 2026-05-20 a
// 50-team backfill via team-page-generator burned ~$4-5 and bottomed
// the balance. Before firing this in any bulk pattern, read:
//   /BACKFILL_RULES.md  (the decision tree — SQL > routine > this)
//   IMPLEMENTATION_PROGRESS.md Lesson 73 (the incident narrative)
// If you're considering N>1 calls in a script, the answer is almost
// always "use a one-off claude.ai routine, not this function".

// Default model is Sonnet. Haiku 4.5 (the previous default) consistently
// drifted on tone — fan voice instead of the gf-to-bf older-sister voice the
// product needs — and was caught hallucinating CL semis for Arsenal on the
// first A1 generation when only PL data was in the prompt input. Sonnet 4.5
// is the model docs/archive/BUILD_PLAN.md / docs/archive/PROMPTS.md originally specified.
const CLAUDE_MODEL = "claude-sonnet-4-5-20250929";
// Retry only what can succeed on a second try: 429, 5xx, and a network error.
// A 4xx is the request's fault (bad key, bad body) and is thrown at once.
// Total sleep 2+8+20 = 30 s, well inside the Edge wall clock; the old
// 30 s/2 min/10 min schedule outlived the isolate (bug hunt 2026-11-03 O-C5).
const RETRY_DELAYS = [2_000, 8_000, 20_000];
const MAX_RETRIES = RETRY_DELAYS.length;

export function isRetryableStatus(status: number): boolean {
  return status === 429 || status >= 500;
}

/**
 * COST-1 for the dormant Claude callers (team-season-state-generator,
 * matchday-scheduler, content-generator, content-reviewer). Each one used to
 * loop callClaude over every team or fixture when called with an empty body,
 * guarded only by a comment (bug hunt 2026-11-03 E-C2/O-C1). Refuse unless
 * the function's own flag is exactly "true" AND the request names exactly
 * one target. Returns the refusal, or null to go ahead.
 */
export function refuseDormantPaidCall(fn: string, flag: string, target: string | null): Response | null {
  const refuse = (status: number, error: string) =>
    new Response(JSON.stringify({ error }), { status, headers: { "Content-Type": "application/json" } });
  if (Deno.env.get(flag) !== "true") {
    return refuse(403, `Refused: ${fn} is dormant and calls Claude (paid API credit). It runs only with ${flag}=true. Live content comes from the claude.ai routines; see BACKFILL_RULES.md / CLAUDE.md.`);
  }
  if (!target) {
    return refuse(400, `Refused: ${fn} needs exactly one explicit target in the body. It never loops teams or fixtures (CLAUDE.md hard rule).`);
  }
  return null;
}

/** One team id or null: a string shaped like teams.id, never an array or empty. */
export function singleTeamId(v: unknown): string | null {
  return typeof v === "string" && /^[a-z0-9_]{2,40}$/.test(v) ? v : null;
}

interface ClaudeMessage {
  role: "user" | "assistant";
  content: string;
}

interface ClaudeTool {
  name: string;
  description?: string;
  input_schema: Record<string, unknown>;
}

interface ClaudeRequest {
  system: string;
  messages: ClaudeMessage[];
  tools?: ClaudeTool[];
  tool_choice?: { type: string; name?: string };
  max_tokens?: number;
  /** Optional per-call model override. Defaults to CLAUDE_MODEL (Sonnet). */
  model?: string;
}

interface ClaudeResponse {
  content: Array<{
    type: "text" | "tool_use";
    text?: string;
    name?: string;
    input?: Record<string, unknown>;
  }>;
  stop_reason: string;
}

export async function callClaude(request: ClaudeRequest): Promise<ClaudeResponse> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) throw new Error("Missing ANTHROPIC_API_KEY");

  const body = {
    model: request.model ?? CLAUDE_MODEL,
    max_tokens: request.max_tokens ?? 2000,
    system: request.system,
    messages: request.messages,
    ...(request.tools && { tools: request.tools }),
    ...(request.tool_choice && { tool_choice: request.tool_choice }),
  };

  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    let response: Response | null = null;
    try {
      response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify(body),
      });
    } catch (e) {
      // Network error: retryable.
      lastError = e instanceof Error ? e : new Error(String(e));
    }

    if (response) {
      if (response.ok) return await response.json() as ClaudeResponse;
      const errorBody = await response.text().catch(() => "");
      lastError = new Error(`Claude API error ${response.status}: ${errorBody.slice(0, 500)}`);
      if (!isRetryableStatus(response.status)) throw lastError;
    }

    if (attempt < MAX_RETRIES) {
      await new Promise((r) => setTimeout(r, RETRY_DELAYS[attempt]));
    }
  }

  throw lastError ?? new Error("Claude API call failed after retries");
}

export { CLAUDE_MODEL };
