// Goal Digger — Shared Claude API Client
// Wraps Anthropic Claude API calls for content generation and review.

/** Call Claude API with a system prompt, user message, and optional tool. */
export async function callClaude(options: {
  systemPrompt: string;
  userMessage: string;
  tool?: Record<string, unknown>;
  toolName?: string;
  maxTokens?: number;
}): Promise<Record<string, unknown>> {
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) {
    throw new Error("ANTHROPIC_API_KEY not configured");
  }

  const body: Record<string, unknown> = {
    model: "claude-sonnet-4-5-20250929",
    max_tokens: options.maxTokens ?? 2000,
    system: options.systemPrompt,
    messages: [{ role: "user", content: options.userMessage }],
  };

  // If a tool is provided, use tool_choice to force it
  if (options.tool && options.toolName) {
    body.tools = [options.tool];
    body.tool_choice = { type: "tool", name: options.toolName };
  }

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": anthropicKey,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Claude API error ${res.status}: ${errText}`);
  }

  const json = await res.json();

  // If tool was used, extract tool_use result
  if (options.tool) {
    const toolUse = json.content?.find(
      (block: Record<string, unknown>) => block.type === "tool_use",
    );
    if (!toolUse) {
      throw new Error("No tool_use block in Claude response");
    }
    return toolUse.input as Record<string, unknown>;
  }

  // Otherwise return the text content
  const textBlock = json.content?.find(
    (block: Record<string, unknown>) => block.type === "text",
  );
  if (!textBlock) {
    throw new Error("No text block in Claude response");
  }

  // Try to parse as JSON (for review bots that return JSON in text)
  const text = textBlock.text as string;
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[0]);
    } catch {
      // Not valid JSON, return as-is
    }
  }

  return { text };
}
