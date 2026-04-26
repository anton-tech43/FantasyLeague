// backfill-analogies/index.ts
// Goal Digger — One-shot backfill for content_items that had their analogy
// rejected by the AI critic before we shipped the rewrite-on-reject path.
//
// For each published item where immersive_context IS NULL, we look up the
// original rejection record to get the previously-generated analogy + the
// critic's reason, run the new rewrite path, and save the result if approved.
//
// Invoke from CLI:
//   curl -X POST -H "Authorization: Bearer $SERVICE_KEY" \
//     https://<project>.supabase.co/functions/v1/backfill-analogies

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { callClaude } from "../_shared/claude-client.ts";
import type { AnalogyScore } from "../_shared/types.ts";

const ANALOGY_CRITIC_TOOL = {
  name: "score_analogy",
  description: "Score a cultural analogy for quality and appropriateness",
  input_schema: {
    type: "object",
    properties: {
      naturalness: { type: "integer", minimum: 1, maximum: 5 },
      relevance: { type: "integer", minimum: 1, maximum: 5 },
      audience_fit: { type: "integer", minimum: 1, maximum: 5 },
      cringe_risk: { type: "integer", minimum: 1, maximum: 5 },
      verdict: { type: "string", enum: ["approve", "reject"] },
      reason: { type: "string" },
    },
    required: ["naturalness", "relevance", "audience_fit", "cringe_risk", "verdict", "reason"],
  },
};

const ANALOGY_REWRITE_TOOL = {
  name: "rewrite_analogy",
  description: "Rewrite a cultural analogy that the reviewer rejected, addressing their feedback",
  input_schema: {
    type: "object",
    properties: {
      analogy: {
        type: "string",
        description: "The new analogy. Cultural reference (pop culture, fashion, dating, work, social media). Max 2 sentences. Sounds like something her funniest friend would WhatsApp her.",
      },
    },
    required: ["analogy"],
  },
};

async function scoreAnalogy(
  analogy: string,
  headline: string,
  fallback: string,
): Promise<AnalogyScore | null> {
  const criticResponse = await callClaude({
    system: `You are a quality gate for cultural analogies used in a football app for women aged 25-35.
Score the analogy on these 4 dimensions (1-5 each):
- Naturalness: Does it flow like something a real person would say?
- Relevance: Does the analogy map accurately onto the football situation?
- Audience fit: Would a 25-35 year old woman immediately get this?
- Cringe risk: 5 = zero cringe, 1 = maximum cringe.

Approve if total >= 16/20 AND no single dimension <= 2.
Reject otherwise. Be honest but not harsh — and when you reject, your reason
must be SPECIFIC and ACTIONABLE so a writer can rework the analogy.`,
    messages: [{
      role: "user",
      content: `Headline: "${headline}"
Analogy: "${analogy}"
Fallback (for context): "${fallback}"

Score this analogy.`,
    }],
    tools: [ANALOGY_CRITIC_TOOL],
    tool_choice: { type: "tool", name: "score_analogy" },
  });

  const toolUse = criticResponse.content.find((c) => c.type === "tool_use");
  if (!toolUse?.input) return null;

  const scores = toolUse.input as Record<string, unknown>;
  const total = (scores.naturalness as number) + (scores.relevance as number) +
    (scores.audience_fit as number) + (scores.cringe_risk as number);
  const minScore = Math.min(
    scores.naturalness as number, scores.relevance as number,
    scores.audience_fit as number, scores.cringe_risk as number,
  );

  return {
    naturalness: scores.naturalness as number,
    relevance: scores.relevance as number,
    audience_fit: scores.audience_fit as number,
    cringe_risk: scores.cringe_risk as number,
    total,
    verdict: (total >= 16 && minScore > 2) ? "approve" : "reject",
    reason: scores.reason as string,
  };
}

async function rewriteAnalogy(
  rejectedAnalogy: string,
  criticReason: string,
  headline: string,
  fallback: string,
): Promise<string | null> {
  try {
    const response = await callClaude({
      system: `You are rewriting a cultural analogy for a football app whose readers are women aged 25-35.

THE ANALOGY MUST:
- Map a football situation onto her world: pop culture, fashion, dating, social media, friend group dynamics, work
- Read like something her funniest friend would WhatsApp her
- Land specifically — "imagine if X" or "this is the equivalent of Y" — not vague
- Max 2 sentences
- Be edgy and current. Reference 2024–2026 culture only.

NEVER:
- Use clichés or generic comparisons ("like a rollercoaster", "like a movie")
- Write factual summaries pretending to be analogies ("Chelsea has had a hard season..." — that's NOT an analogy)
- Be condescending or address her relationship with football
- Use outdated references (anything pre-2020 culture)

GOOD EXAMPLE:
- Headline: "Gyökeres signs for Arsenal in record deal"
- Analogy: "It's like Zendaya quietly leaving her label and joining Chanel after a stupid offer. Arsenal just bought the moment of the year."

You will be given the analogy that was rejected and the reviewer's specific feedback. Write a NEW analogy that addresses that feedback.`,
      messages: [{
        role: "user",
        content: `Headline: "${headline}"
Factual context: "${fallback}"

REJECTED analogy: "${rejectedAnalogy}"
Reviewer's reason: "${criticReason}"

Write a better analogy that addresses the reviewer's feedback.`,
      }],
      tools: [ANALOGY_REWRITE_TOOL],
      tool_choice: { type: "tool", name: "rewrite_analogy" },
    });

    const toolUse = response.content.find((c) => c.type === "tool_use");
    const input = toolUse?.input as { analogy?: string } | undefined;
    return input?.analogy ?? null;
  } catch (err) {
    console.error("Analogy rewrite failed:", err);
    return null;
  }
}

interface BackfillResult {
  contentItemId: string;
  outcome: "rescued" | "still_rejected" | "no_rejection_record" | "rewrite_failed";
  newAnalogy?: string;
  reason?: string;
}

serve(async (_req) => {
  const supabase = getSupabaseClient();
  const startedAt = Date.now();

  // 1. Find published items where the analogy is null (rejected)
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const { data: items, error: itemsError } = await supabase
    .from("content_items")
    .select("id, headline, immersive_context_fallback, published_at")
    .eq("status", "published")
    .is("immersive_context", null)
    .gte("published_at", sevenDaysAgo)
    .order("published_at", { ascending: false });

  if (itemsError || !items) {
    return new Response(
      JSON.stringify({ error: "Failed to fetch items", details: itemsError }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  console.log(`Backfill candidates: ${items.length}`);

  const results: BackfillResult[] = [];

  for (const item of items) {
    // 2. Look up the original rejection record
    const { data: rejections } = await supabase
      .from("analogy_rejections")
      .select("rejected_analogy, critic_reason")
      .eq("content_item_id", item.id)
      .order("created_at", { ascending: false })
      .limit(1);

    const rejection = rejections?.[0];
    if (!rejection?.rejected_analogy) {
      results.push({ contentItemId: item.id, outcome: "no_rejection_record" });
      continue;
    }

    const headline = item.headline as string;
    const fallback = (item.immersive_context_fallback ?? "") as string;
    const criticReason = (rejection.critic_reason ?? "") as string;
    const rejectedAnalogy = rejection.rejected_analogy as string;

    // 3. Rewrite using the critic's old feedback
    const rewritten = await rewriteAnalogy(rejectedAnalogy, criticReason, headline, fallback);
    if (!rewritten || rewritten.trim().length === 0) {
      results.push({ contentItemId: item.id, outcome: "rewrite_failed" });
      continue;
    }

    // 4. Score the rewrite
    const score = await scoreAnalogy(rewritten, headline, fallback);
    if (!score) {
      results.push({ contentItemId: item.id, outcome: "rewrite_failed" });
      continue;
    }

    if (score.verdict === "approve") {
      await supabase
        .from("content_items")
        .update({
          immersive_context: rewritten,
          analogy_critic_score: score,
        })
        .eq("id", item.id);

      // Tag the rejection record so we can audit which were rescued by backfill
      await supabase.from("analogy_rejections").insert({
        content_item_id: item.id,
        rejected_analogy: rejectedAnalogy,
        critic_scores: score,
        critic_reason: `BACKFILL: rewrote with reason "${criticReason}"`,
        rejected_by: "ai_critic_then_rewritten_backfill",
      });

      results.push({
        contentItemId: item.id,
        outcome: "rescued",
        newAnalogy: rewritten,
      });
      console.log(`✓ Rescued ${item.id}: ${rewritten.substring(0, 80)}...`);
    } else {
      results.push({
        contentItemId: item.id,
        outcome: "still_rejected",
        reason: score.reason,
      });
      console.log(`✗ Rewrite still rejected for ${item.id}: ${score.reason}`);
    }
  }

  const summary = {
    durationMs: Date.now() - startedAt,
    totalCandidates: items.length,
    rescued: results.filter((r) => r.outcome === "rescued").length,
    stillRejected: results.filter((r) => r.outcome === "still_rejected").length,
    noRejectionRecord: results.filter((r) => r.outcome === "no_rejection_record").length,
    rewriteFailed: results.filter((r) => r.outcome === "rewrite_failed").length,
    results,
  };

  return new Response(JSON.stringify(summary, null, 2), {
    headers: { "Content-Type": "application/json" },
  });
});
