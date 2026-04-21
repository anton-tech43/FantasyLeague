// content-reviewer/index.ts
// Goal Digger — Single Claude call with tool_use that returns 4 verdicts at once.
// Replaces the old 4-separate-call flow. No more JSON parse errors (tool_use
// returns structured data), 4× cheaper, 4× faster.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { callClaude } from "../_shared/claude-client.ts";
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";
import { triggerFunction } from "../_shared/trigger.ts";
import { buildSourceSummary } from "../_shared/source-summarizer.ts";
import type { ReviewNote } from "../_shared/types.ts";

// ============================================================
// COMBINED SYSTEM PROMPT — one Claude call, four verdicts
// ============================================================

const REVIEW_SYSTEM_PROMPT = `You are a content reviewer for Goal Digger — an app that explains Premier League
football to girlfriends who don't follow football. You'll score ONE piece of
generated content across 4 dimensions: TONE, ACCURACY, BREVITY, SAFETY.

CALL the review_content tool with all 4 verdicts. Be LENIENT by default — your
job is to catch real problems, not to find reasons to reject. Only ACCURACY
should be strict.

══════════════════════════════════════════════════════════════════════════════
UNIVERSAL CONTEXT — applies to ALL dimensions
══════════════════════════════════════════════════════════════════════════════

1. "[his name]", "[her name]", "[his team]" are TEMPLATE PLACEHOLDERS. iOS
   substitutes them at display time. DO NOT flag as bugs, fourth-wall breaks,
   or meta-commentary. They are correct.

2. Empathetic commentary about HIS mood ("he'll be buzzing", "he might be
   grumpy tonight", "give him space") is THE CORE PRODUCT. It's why users open
   this app. NEVER flag as "patronizing", "meta", or "assumes emotional state".

3. Practical conversation advice for her ("ask him about X", "expect him
   to be frustrated") is on-voice. Never flag.

══════════════════════════════════════════════════════════════════════════════
TONE — how it reads
══════════════════════════════════════════════════════════════════════════════

PASS by default. Slight formality or a match-report-ish sentence here or
there is FINE. Real writing isn't maximally conversational every line.

ONLY fail if:
- Contains banned jargon phrases: "Additionally", "Furthermore", "Moreover",
  "It's worth noting", "Interestingly", "In conclusion", "As mentioned",
  "It should be noted", "At the end of the day", "That being said".
- Contains semicolons or em dashes anywhere.
- Reads like raw BBC Sport copy end-to-end (zero warmth, pure reporter voice).
- Condescending to the reader ("even if you don't follow football...").

══════════════════════════════════════════════════════════════════════════════
ACCURACY — strict on hard facts, lenient on phrasing
══════════════════════════════════════════════════════════════════════════════

You'll be given structured source data (RECENT RESULTS, LEAGUE TABLE, LAST
MATCH EVENTS, etc.) and news headlines. Verify every specific factual claim.

IMPORTANT — these are NOT errors, do NOT flag them:
- Placeholders: "[his name]", "[her name]", "[his team]" — iOS replaces at display.
- Paraphrasing: source says "2-1 defeat", content says "lost 2-1" — same thing.
- Characterization: "huge blow to title hopes" if source says title race got harder.
- News vs stale API data: when news headlines clearly describe a recent event
  (manager change, new signing, injury) but the structured API data is outdated
  and still shows the old state, TRUST THE NEWS. APIs lag behind news cycles
  by 1-2 days, sometimes longer.

  EXAMPLE: News headlines say "Bournemouth confirm Marco Rose as new manager."
  Structured API data still shows "current manager: J. Woodgate (since 2021)."
  Content says "Bournemouth just announced their new manager. Marco Rose is
  taking over." → This is CORRECT. PASS. Do NOT flag the API/content mismatch.
  The API is stale, the news is fresh, the content follows the news.

  Rule: for CURRENT-STATE facts (current manager, current squad, injuries),
  news headlines are authoritative. Only flag if content invents something
  that appears nowhere in news OR API.
- Stoppage-time minute variations: the API reports "elapsed: 90" for ANY second-half
  stoppage goal; news headlines call them "95th minute", "100th minute", etc. All
  correct for the same goal. Do NOT flag minute discrepancies on stoppage goals.
- Relative timings: "just before halftime", "moments later", "two minutes after" —
  fine if they're approximately right. Do the math before claiming a mismatch.
- Possession percentages within 5% of source (59% vs 60% is fine).
- Home/away framing: only fail this if it genuinely reverses which team was the host
  AND that mistake affects the headline's emotional angle. Otherwise let it slide.
- Ordinal/cardinal: "third in the table" vs "3rd place" — same thing.

HARD fails (reject the content):
- Wrong SCORE (content says 2-1, source says 3-1).
- Wrong SCORER named (content says "Saka scored", source says it was Havertz).
- Wrong DATE for a specific match (off by more than a day).
- Completely INVENTED stats with specific numbers not in source.
- Quotes attributed to a person that aren't in any source article.
- Wrong standings by more than one position.

When failing, cite the EXACT contradiction in the errors array. Don't fail on
minor wording if the underlying fact is correct.

══════════════════════════════════════════════════════════════════════════════
BREVITY — format check (evidence required)
══════════════════════════════════════════════════════════════════════════════

Count BEFORE judging. The tool requires you to fill in the actual counts.
Do NOT hallucinate — use the real numbers you can count.

Rules (lenient):
- HEADLINE: up to 200 characters, up to 2 sentences.
- TALKING POINTS: 3 items total. Each must be either a question (ending with ?)
  OR a short statement she can say verbatim. Instructions to the user
  ("Ask him about...", "Don't bring up...", "Maybe wait...") are the one
  hard fail — those are commentary, not talking points.
- BODY: up to 3 paragraphs, under 180 words total.

PASS by default when content is within these loose bounds.
FAIL only on clear violations, and cite the actual count + offending text.

══════════════════════════════════════════════════════════════════════════════
SAFETY — block truly unsafe content
══════════════════════════════════════════════════════════════════════════════

PASS unless it contains:
1. Personal life of a player (partner, family, religion, politics). Exception:
   officially announced retirements.
2. Defamation — unverified accusations or medical speculation stated as fact.
3. Discrimination — stereotypes based on race, nationality, gender, religion.
4. Sexual content or inappropriate intimacy references.
5. Excessive violence beyond normal football context.
6. Copyright violations — verbatim quotes >2 sentences from one article.

"He'll be grumpy tonight" and "ask him about X" are the VOICE. Not safety issues.

══════════════════════════════════════════════════════════════════════════════

AUTO-CORRECT PATH (SAVES TIME):
If any dimension fails but the problem is SMALL and fixable (wrong minute,
wrong home/away, small numeric error, typo, banned phrase swap) — set
can_autocorrect=true and fill corrected_content with the FULL fixed version
of headline, body, and talking_points. We'll apply the patch and approve
instead of a full regeneration.

Only use auto-correct when:
- ALL failures are truly minor edits (no deep rewrites needed)
- None of them are safety issues
- You can confidently produce the fixed text

Do NOT use auto-correct for tone overhauls, wrong scorer/score, invented
facts, missing source support, or safety problems. Those need a full regen.

Now call review_content with all 4 verdicts based on the content + source data
below. Remember: PASS by default except for accuracy.`;

const REVIEW_TOOL = {
  name: "review_content",
  description: "Review generated football content across 4 dimensions. When a dimension fails with something small and fixable (wrong minute, wrong home/away, wrong percentage, typo, banned phrase), set can_autocorrect=true and return the corrected_content block — we'll patch and approve without a full regen.",
  input_schema: {
    type: "object",
    properties: {
      tone: {
        type: "object",
        properties: {
          pass: { type: "boolean" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          notes: { type: "string", description: "Brief explanation. If fail, quote the exact offending phrase." },
        },
        required: ["pass", "confidence", "notes"],
      },
      accuracy: {
        type: "object",
        properties: {
          pass: { type: "boolean" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          notes: { type: "string", description: "Summary of fact-check. If fail, name the specific contradictions." },
          errors: {
            type: "array",
            items: {
              type: "object",
              properties: {
                claim: { type: "string", description: "What the content says" },
                source_says: { type: "string", description: "What the source data actually says" },
              },
              required: ["claim", "source_says"],
            },
          },
        },
        required: ["pass", "confidence", "notes"],
      },
      brevity: {
        type: "object",
        properties: {
          pass: { type: "boolean" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          notes: { type: "string", description: "If fail, cite actual counts and offending text." },
          headline_char_count: { type: "integer", description: "Count the characters in the headline. MUST be actual count." },
          body_word_count: { type: "integer", description: "Actual word count of body." },
          body_paragraph_count: { type: "integer", description: "Actual paragraph count (by blank lines)." },
          talking_point_count: { type: "integer", description: "Number of talking_points items." },
        },
        required: ["pass", "confidence", "notes", "headline_char_count", "body_word_count", "body_paragraph_count", "talking_point_count"],
      },
      safety: {
        type: "object",
        properties: {
          pass: { type: "boolean" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          notes: { type: "string" },
        },
        required: ["pass", "confidence", "notes"],
      },
      // Inline auto-correct: if ALL fails are minor fixes (wrong minute, wrong
      // home/away, possession off by a few %, typo, banned phrase swap), set
      // can_autocorrect=true and fill corrected_content. We'll apply and approve.
      // Do NOT set this if failures involve tone overhaul, wrong scorer/score,
      // completely invented facts, or safety issues — those need a full regen.
      can_autocorrect: {
        type: "boolean",
        description: "True if the failures can be fixed with the corrected_content below (no need to regenerate). False if a full regen is needed.",
      },
      corrected_content: {
        type: "object",
        description: "Required when can_autocorrect=true. The complete corrected version of whatever was wrong. Copy unchanged fields verbatim from the original.",
        properties: {
          headline: { type: "string" },
          body: { type: "string" },
          talking_points: { type: "array", items: { type: "string" } },
          immersive_headline: { type: "string" },
          immersive_context_fallback: { type: "string" },
        },
        required: ["headline", "body", "talking_points"],
      },
    },
    required: ["tone", "accuracy", "brevity", "safety", "can_autocorrect"],
  },
};

interface ReviewRequest {
  content_item_id: string;
  team_id?: string;
}

interface CombinedReviewResult {
  tone: { pass: boolean; confidence: number; notes: string };
  accuracy: { pass: boolean; confidence: number; notes: string; errors?: Array<{ claim: string; source_says: string }> };
  brevity: {
    pass: boolean;
    confidence: number;
    notes: string;
    headline_char_count: number;
    body_word_count: number;
    body_paragraph_count: number;
    talking_point_count: number;
  };
  safety: { pass: boolean; confidence: number; notes: string };
  can_autocorrect: boolean;
  corrected_content?: {
    headline: string;
    body: string;
    talking_points: string[];
    immersive_headline?: string;
    immersive_context_fallback?: string;
  };
}

// ============================================================
// MAIN HANDLER
// ============================================================

serve(async (req) => {
  const startTime = Date.now();
  const supabase = getSupabaseClient();

  try {
    const { content_item_id }: ReviewRequest = await req.json();

    // Fetch the draft content item
    const { data: item, error: itemErr } = await supabase
      .from("content_items")
      .select("*")
      .eq("id", content_item_id)
      .single();

    if (itemErr || !item) throw new Error(`Content item not found: ${content_item_id}`);

    const teamId = item.team_id as string;

    // Fetch the team's api_football_id (for injury filtering)
    const { data: teamRow } = await supabase
      .from("teams")
      .select("api_football_id")
      .eq("id", teamId)
      .single();
    const teamApiId = teamRow?.api_football_id as number | undefined;

    // Fetch raw source data — same clean summary the generator saw.
    const { data: rawLogs } = await supabase
      .from("raw_fetch_logs")
      .select("source, data, fetched_at")
      .eq("team_id", teamId)
      .order("fetched_at", { ascending: false })
      .limit(50);

    const { articles, stats } = buildSourceSummary(
      (rawLogs ?? []) as Array<{ source: string; data: unknown }>,
      teamApiId
    );

    // Find most recent news date for context
    const newsLogs = (rawLogs ?? []).filter((l) => !l.source.startsWith("api_football_"));
    const apiLogs = (rawLogs ?? []).filter((l) => l.source.startsWith("api_football_"));
    const newestNews = newsLogs[0]?.fetched_at?.slice(0, 10) ?? "unknown";
    const newestApi = apiLogs[0]?.fetched_at?.slice(0, 10) ?? "unknown";

    // News first — it's the current truth. Structured API data second — may lag
    // behind real events by 1-2 days and should NOT override news on conflicts.
    const sourceSummary = [
      articles
        ? `=== NEWS HEADLINES (current truth, fetched ${newestNews}) ===${articles}`
        : "",
      stats
        ? `=== STRUCTURED API DATA (fetched ${newestApi}, may lag behind news) ===\n${stats}`
        : "",
    ]
      .filter(Boolean)
      .join("\n\n")
      .trim();

    // Format talking points for display
    const talkingPoints = Array.isArray(item.talking_points)
      ? (item.talking_points as string[]).map((tp, i) => `${i + 1}. ${tp}`).join("\n")
      : JSON.stringify(item.talking_points);

    const fullInput = `GENERATED CONTENT TO REVIEW:

Headline: ${item.headline}

Talking Points:
${talkingPoints}

Body:
${item.body}

Emotional Context: ${item.emotional_context ?? "none"}
Team: ${teamId}

══════════════════════════════════════════════════════════════════════════

SOURCE DATA (for ACCURACY check):

${sourceSummary}`;

    // Single Claude call with tool_use — all 4 verdicts at once
    const response = await callClaude({
      system: REVIEW_SYSTEM_PROMPT,
      messages: [{ role: "user", content: fullInput }],
      tools: [REVIEW_TOOL],
      tool_choice: { type: "tool", name: "review_content" },
      max_tokens: 2500,
    });

    const toolUse = response.content.find((c) => c.type === "tool_use");
    if (!toolUse?.input) {
      throw new Error("Review bot did not return tool_use output");
    }

    const result = toolUse.input as unknown as CombinedReviewResult;
    const reviewedAt = new Date().toISOString();

    // Build the ReviewNote[] for storage/retry
    const allResults: ReviewNote[] = [
      {
        bot: "tone",
        pass: result.tone.pass,
        confidence: result.tone.confidence,
        notes: result.tone.notes,
        reviewed_at: reviewedAt,
      },
      {
        bot: "accuracy",
        pass: result.accuracy.pass,
        confidence: result.accuracy.confidence,
        notes: result.accuracy.errors?.length
          ? `${result.accuracy.notes}\nSpecific errors: ${JSON.stringify(result.accuracy.errors)}`
          : result.accuracy.notes,
        reviewed_at: reviewedAt,
      },
      {
        bot: "brevity",
        pass: result.brevity.pass,
        confidence: result.brevity.confidence,
        notes: `${result.brevity.notes} [headline=${result.brevity.headline_char_count}ch, body=${result.brevity.body_word_count}w/${result.brevity.body_paragraph_count}p, tps=${result.brevity.talking_point_count}]`,
        reviewed_at: reviewedAt,
      },
      {
        bot: "safety",
        pass: result.safety.pass,
        confidence: result.safety.confidence,
        notes: result.safety.notes,
        reviewed_at: reviewedAt,
      },
    ];

    const allPassed = allResults.every((r) => r.pass);
    const failedBots = allResults.filter((r) => !r.pass);

    await logPipelineEvent(supabase, {
      team_id: teamId,
      stage: "safety_review",
      status: result.safety.pass ? "success" : "failure",
      duration_ms: Date.now() - startTime,
      message: result.safety.notes,
      content_item_id,
    });

    // Build feedback notes for possible retry
    const failureNotes = failedBots
      .map((r) => `- ${r.bot.toUpperCase()}: ${r.notes}`)
      .join("\n");

    if (allPassed) {
      // All 4 pass → approve + notify
      await supabase
        .from("content_items")
        .update({
          status: "approved",
          review_notes: allResults,
        })
        .eq("id", content_item_id);

      await triggerFunction("notification-sender", {
        content_item_id,
        team_id: teamId,
      });

      await logPipelineEvent(supabase, {
        team_id: teamId,
        stage: "review",
        status: "success",
        duration_ms: Date.now() - startTime,
        message: `Approved — all 4 dimensions passed`,
        content_item_id,
      });
    } else if (result.can_autocorrect && result.corrected_content && !failedBots.some((b) => b.bot === "safety")) {
      // INLINE AUTO-CORRECT: reviewer provided a fixed version and failures are
      // minor. Apply the patch and approve without a full regen.
      const patch: Record<string, unknown> = {
        status: "approved",
        review_notes: allResults,
        headline: result.corrected_content.headline,
        body: result.corrected_content.body,
        talking_points: result.corrected_content.talking_points,
      };
      if (result.corrected_content.immersive_headline) {
        patch.immersive_headline = result.corrected_content.immersive_headline;
      }
      if (result.corrected_content.immersive_context_fallback) {
        patch.immersive_context_fallback = result.corrected_content.immersive_context_fallback;
      }

      await supabase
        .from("content_items")
        .update(patch)
        .eq("id", content_item_id);

      await triggerFunction("notification-sender", {
        content_item_id,
        team_id: teamId,
      });

      await logPipelineEvent(supabase, {
        team_id: teamId,
        stage: "review",
        status: "success",
        duration_ms: Date.now() - startTime,
        message: `Auto-corrected ${failedBots.length} minor issue(s) (${failedBots.map((b) => b.bot).join(", ")}) and approved`,
        content_item_id,
      });
    } else if (
      failedBots.length <= 2 &&
      item.status === "draft" &&
      // Only retry on FIRST review — if review_notes already has entries,
      // this is a re-review after a previous retry, so reject instead of
      // looping forever.
      (!item.review_notes || (Array.isArray(item.review_notes) && item.review_notes.length === 0))
    ) {
      // Up to 2 dimensions failed on first attempt → retry with feedback
      await supabase
        .from("content_items")
        .update({
          status: "retrying",
          review_notes: allResults,
        })
        .eq("id", content_item_id);

      await triggerFunction("content-generator", {
        team_id: teamId,
        trigger: "reviewer_retry",
        content_item_id,
        previous_failure_notes: failureNotes,
        fetch_log_ids: [],
      });

      await logPipelineEvent(supabase, {
        team_id: teamId,
        stage: "review",
        status: "failure",
        duration_ms: Date.now() - startTime,
        message: `${failedBots.length} dimension(s) failed (${failedBots.map((b) => b.bot).join(", ")}). Retrying with feedback.`,
        content_item_id,
      });
    } else {
      // 3+ dimensions failed OR this was already a retry → reject
      await supabase
        .from("content_items")
        .update({
          status: "rejected",
          review_notes: allResults,
        })
        .eq("id", content_item_id);

      await logPipelineEvent(supabase, {
        team_id: teamId,
        stage: "review",
        status: "failure",
        duration_ms: Date.now() - startTime,
        message: `Rejected — ${failedBots.length} dimensions failed: ${failedBots.map((b) => b.bot).join(", ")}`,
        content_item_id,
      });
    }

    return new Response(
      JSON.stringify({ success: true, passed: allPassed, results: allResults }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("content-reviewer error:", message);

    await logPipelineEvent(supabase, {
      team_id: "unknown",
      stage: "review",
      status: "failure",
      duration_ms: Date.now() - startTime,
      message,
      content_item_id: null,
    });

    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
