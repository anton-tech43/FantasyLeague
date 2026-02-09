// Goal Digger — Content Reviewer Edge Function
// Quality gate: every draft content item goes through 3 AI review bots in
// parallel. All 3 must pass for approval. See PROMPTS.md Sections 3-5.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ReviewResult {
  pass: boolean;
  confidence: number;
  notes: string;
  issues?: string[];
  suggestions?: string[];
  errors?: Array<{
    claim: string;
    issue: string;
    source_says: string;
    severity: string;
  }>;
  // Brevity-specific
  headline_chars?: number;
  talking_point_count?: number;
  body_paragraph_count?: number;
  estimated_read_seconds?: number;
  suggested_cuts?: string[];
}

interface ContentItem {
  id: string;
  team_id: string;
  type: string;
  headline: string;
  body: string;
  talking_points: string[];
  emotional_context: string;
  status: string;
  review_notes: unknown[];
}

// ---------------------------------------------------------------------------
// Review Bot Prompts (from PROMPTS.md)
// ---------------------------------------------------------------------------

const TONE_SYSTEM_PROMPT = `You are a tone reviewer for Goal Digger, an app that explains Premier League football
to girlfriends who don't care about football.

You are reviewing a generated content item. Your ONLY job is to evaluate the tone
and voice. You are not checking facts or length — other reviewers handle that.

THE IDEAL VOICE:
- Sounds like a fun, warm best friend texting her about her partner's hobby
- Conspiratorial and slightly gossipy — like sharing inside info
- Empathetic — understands she's doing this out of love, not interest
- Playful — uses humour naturally, never forced
- Confident — explains things simply without hedging or apologizing

PASS THE CONTENT IF:
- A 27-year-old woman with zero football knowledge would enjoy reading it
- She would screenshot it and send it to a friend because it's that good
- It sounds like a real person texting, not a brand or a journalist
- Football terms are explained naturally when used
- The talking points are things she'd actually say out loud

FAIL THE CONTENT IF:
- It reads like BBC Sport, Sky Sports, or any sports news outlet
- It uses unexplained jargon: "clean sheet", "set piece", "counter-attack",
  "pressing", "back four", "holding midfielder", "xG", "progressive passes"
- It's condescending
- It's too formal
- The talking points sound like quiz answers, not conversation starters
- The emotional context is wrong
- It uses passive voice extensively
- It includes stats without explaining why they matter to her

You MUST respond with valid JSON matching this schema:
{
    "pass": true/false,
    "confidence": 0.0-1.0,
    "notes": "Explanation",
    "issues": ["specific issues"],
    "suggestions": ["specific rewording suggestions"]
}`;

const ACCURACY_SYSTEM_PROMPT = `You are a fact-checker for Goal Digger. The app generates football content using AI,
and your job is to make sure every claim is accurate before it reaches the user.

This is CRITICAL. The user will repeat this information to her partner, who is a
passionate football fan. If she says something wrong, it's embarrassing.

YOU WILL RECEIVE:
1. The generated content (headline, talking points, body)
2. The raw source data it was based on

YOUR JOB:
Cross-reference every factual claim in the content against the raw source data.

CHECK FOR:
- Player names: correct spelling, correct team attribution
- Match dates and times: correct day, correct kickoff time
- Scores and results: correct scoreline, correct teams
- League positions and points: current and accurate
- Injury/transfer information: matches source data
- Quotes: must be from the source data (never fabricated)

PASS IF: Every factual claim can be traced to the provided source data.
FAIL IF: ANY factual error exists, no matter how small.

NOTE: You are NOT checking tone or length. Only facts.

You MUST respond with valid JSON matching this schema:
{
    "pass": true/false,
    "confidence": 0.0-1.0,
    "notes": "Summary of fact-check",
    "errors": [
        {
            "claim": "exact text that is wrong",
            "issue": "what is wrong",
            "source_says": "what the source actually says",
            "severity": "critical/minor"
        }
    ],
    "unverifiable_claims": ["claims that can't be confirmed from source data"]
}`;

const BREVITY_SYSTEM_PROMPT = `You are an editor for Goal Digger. Your job is to ensure every piece of content is
concise, scannable, and respects the user's time.

The user paid $10 for this app. She doesn't want to read an essay. She wants to
glance at her phone, absorb the key info in under a minute, and feel prepared.

HEADLINE CHECK:
- Must be 1-2 sentences maximum
- Must be under 200 characters
- Should NOT start with the team name
- Should NOT read like a news alert

TALKING POINTS CHECK:
- Must have exactly 3-5 talking points
- Each must be 1-2 sentences maximum
- Each must be a conversation starter (not a fact dump)
- No two talking points should cover the same topic

BODY CHECK:
- Must be 3-5 paragraphs
- Each paragraph should be 2-4 sentences
- Must be scannable in under 60 seconds

OVERALL CHECK:
- No information should appear in both the headline AND talking points AND body
- Remove filler phrases
- Every sentence should earn its place

PASS IF all length constraints are met and content is scannable.
FAIL IF any constraint is violated.

You MUST respond with valid JSON matching this schema:
{
    "pass": true/false,
    "confidence": 0.0-1.0,
    "notes": "Summary",
    "headline_chars": 142,
    "headline_sentences": 2,
    "talking_point_count": 4,
    "body_paragraph_count": 4,
    "estimated_read_seconds": 45,
    "issues": ["specific issues"],
    "suggested_cuts": ["sentences to remove or shorten"]
}`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/** Call Claude API for a review bot. */
async function runReviewBot(
  systemPrompt: string,
  contentToReview: string,
): Promise<ReviewResult> {
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) throw new Error("ANTHROPIC_API_KEY not configured");

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": anthropicKey,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 1500,
      system: systemPrompt,
      messages: [{ role: "user", content: contentToReview }],
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Claude API error ${res.status}: ${errText}`);
  }

  const json = await res.json();
  const textBlock = json.content?.find(
    (block: Record<string, unknown>) => block.type === "text",
  );

  if (!textBlock) throw new Error("No text in Claude review response");

  // Parse JSON from the response text
  const text = textBlock.text as string;
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error("No JSON found in review response");

  return JSON.parse(jsonMatch[0]) as ReviewResult;
}

/** Format content item for review input. */
function formatContentForReview(item: ContentItem): string {
  const talkingPointsFormatted = item.talking_points
    .map((tp: string, i: number) => `${i + 1}. ${tp}`)
    .join("\n");

  return `CONTENT TO REVIEW:

Headline: ${item.headline}

Talking Points:
${talkingPointsFormatted}

Body:
${item.body}

Emotional Context: ${item.emotional_context ?? "not specified"}
Team: ${item.team_id}`;
}

/** Format content + raw source data for accuracy review. */
async function formatForAccuracyReview(
  supabase: ReturnType<typeof createClient>,
  item: ContentItem,
): Promise<string> {
  const contentPart = formatContentForReview(item);

  // Get raw source data from last 4 hours
  const since = new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString();
  const { data: rawLogs } = await supabase
    .from("raw_fetch_logs")
    .select("source, data")
    .eq("team_id", item.team_id)
    .gte("fetched_at", since)
    .limit(20);

  const rawDataFormatted = rawLogs
    ?.map((log: { source: string; data: unknown }) =>
      `[${log.source}]: ${JSON.stringify(log.data).substring(0, 2000)}`
    )
    .join("\n\n") ?? "(No raw data available)";

  return `GENERATED CONTENT:

${contentPart}

---

RAW SOURCE DATA THIS CONTENT WAS BASED ON:

${rawDataFormatted}`;
}

/** Log pipeline health. */
async function logHealth(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
  status: string,
  durationMs: number,
  message: string,
  contentItemId: string,
) {
  await supabase.from("pipeline_health").insert({
    team_id: teamId,
    stage: "review",
    status,
    duration_ms: durationMs,
    message,
    content_item_id: contentItemId,
  });
}

/** Trigger notification sender for approved content. */
async function triggerNotificationSender(contentItemId: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  try {
    await fetch(`${supabaseUrl}/functions/v1/notification-sender`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ content_item_id: contentItemId }),
    });
  } catch (err) {
    console.error("Failed to trigger notification-sender:", err);
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  try {
    const supabase = getSupabaseClient();
    const { content_item_id } = await req.json();

    if (!content_item_id) {
      return new Response(
        JSON.stringify({ error: "content_item_id required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const startTime = Date.now();

    // Fetch the content item
    const { data: item, error: fetchErr } = await supabase
      .from("content_items")
      .select("*")
      .eq("id", content_item_id)
      .single();

    if (fetchErr || !item) {
      return new Response(
        JSON.stringify({ error: "Content item not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } },
      );
    }

    if (item.status !== "draft") {
      return new Response(
        JSON.stringify({ skipped: true, reason: `Item status is '${item.status}', not 'draft'` }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Prepare review inputs
    const contentForReview = formatContentForReview(item as ContentItem);
    const contentForAccuracy = await formatForAccuracyReview(supabase, item as ContentItem);

    // Run all 3 review bots IN PARALLEL
    const [toneResult, accuracyResult, brevityResult] = await Promise.all([
      runReviewBot(TONE_SYSTEM_PROMPT, contentForReview),
      runReviewBot(ACCURACY_SYSTEM_PROMPT, contentForAccuracy),
      runReviewBot(BREVITY_SYSTEM_PROMPT, contentForReview),
    ]);

    const allResults = {
      tone: toneResult,
      accuracy: accuracyResult,
      brevity: brevityResult,
    };

    const allPassed = toneResult.pass && accuracyResult.pass && brevityResult.pass;
    const failedBots = [
      !toneResult.pass ? "tone" : null,
      !accuracyResult.pass ? "accuracy" : null,
      !brevityResult.pass ? "brevity" : null,
    ].filter(Boolean);

    // Store review notes
    const reviewNotes = [
      ...(item.review_notes as unknown[] ?? []),
      { attempt: 1, results: allResults, timestamp: new Date().toISOString() },
    ];

    if (allPassed) {
      // All passed — approve
      await supabase
        .from("content_items")
        .update({
          status: "approved",
          review_notes: reviewNotes,
        })
        .eq("id", content_item_id);

      await logHealth(
        supabase,
        item.team_id,
        "success",
        Date.now() - startTime,
        "All 3 review bots passed",
        content_item_id,
      );

      // Trigger notification sender
      await triggerNotificationSender(content_item_id);

      return new Response(
        JSON.stringify({ approved: true, reviews: allResults }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Not all passed — check if only 1 failed (retry eligible)
    if (failedBots.length === 1) {
      // Retry: send content + failure feedback back to content-generator
      console.log(`Retry: only ${failedBots[0]} failed. Requesting revision.`);

      const failedBot = failedBots[0]!;
      const failedResult = allResults[failedBot as keyof typeof allResults];

      // Call content-generator with revision instructions
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

      try {
        const revisionRes = await fetch(
          `${supabaseUrl}/functions/v1/content-generator`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${serviceKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              team_id: item.team_id,
              revision: {
                original_content_id: content_item_id,
                failed_review: failedBot,
                feedback: failedResult.notes,
                issues: failedResult.issues ?? failedResult.suggested_cuts ?? [],
              },
            }),
          },
        );

        if (revisionRes.ok) {
          // Update the original item with review notes (keep as draft for now)
          await supabase
            .from("content_items")
            .update({ review_notes: reviewNotes })
            .eq("id", content_item_id);

          return new Response(
            JSON.stringify({
              approved: false,
              retry: true,
              failed_bot: failedBot,
              reviews: allResults,
            }),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
      } catch (err) {
        console.error("Revision request failed:", err);
      }
    }

    // Multiple bots failed or retry failed — reject
    await supabase
      .from("content_items")
      .update({
        status: "rejected",
        review_notes: reviewNotes,
      })
      .eq("id", content_item_id);

    await logHealth(
      supabase,
      item.team_id,
      "failure",
      Date.now() - startTime,
      `Rejected: ${failedBots.join(", ")} failed`,
      content_item_id,
    );

    return new Response(
      JSON.stringify({
        approved: false,
        retry: false,
        failed_bots: failedBots,
        reviews: allResults,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Content reviewer error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
