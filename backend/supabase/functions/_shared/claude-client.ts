// _shared/claude-client.ts
// Goal Digger — Anthropic Claude API client with retry logic

const CLAUDE_MODEL = "claude-sonnet-4-5-20250929";
const MAX_RETRIES = 3;
const RETRY_DELAYS = [30_000, 120_000, 600_000]; // 30s, 2min, 10min

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
    model: CLAUDE_MODEL,
    max_tokens: request.max_tokens ?? 2000,
    system: request.system,
    messages: request.messages,
    ...(request.tools && { tools: request.tools }),
    ...(request.tool_choice && { tool_choice: request.tool_choice }),
  };

  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify(body),
      });

      if (response.ok) {
        return await response.json() as ClaudeResponse;
      }

      const status = response.status;
      // Don't retry on client errors (except rate limits)
      if (status >= 400 && status < 500 && status !== 429) {
        const errorBody = await response.text();
        throw new Error(`Claude API error ${status}: ${errorBody}`);
      }

      // Retryable error (5xx or 429)
      lastError = new Error(`Claude API error ${status}`);
    } catch (e) {
      lastError = e instanceof Error ? e : new Error(String(e));
    }

    if (attempt < MAX_RETRIES) {
      await new Promise((r) => setTimeout(r, RETRY_DELAYS[attempt]));
    }
  }

  throw lastError ?? new Error("Claude API call failed after retries");
}

export { CLAUDE_MODEL };
