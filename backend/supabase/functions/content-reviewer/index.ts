// content-reviewer/index.ts
// Goal Digger — 4 review bots: Tone, Accuracy, Brevity, Safety
// All 4 must pass. JSON.parse failures = FAIL. One retry on single-bot failure.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { callClaude } from "../_shared/claude-client.ts";
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";
import { triggerFunction } from "../_shared/trigger.ts";
import type { ReviewBotResult, ReviewNote } from "../_shared/types.ts";

// ============================================================
// REVIEW BOT SYSTEM PROMPTS (from PROMPTS.md Sections 3-6)
// ============================================================

const TONE_SYSTEM_PROMPT = `You are a tone reviewer for Goal Digger, an app that explains Premier League football
to girlfriends who don't care about football.

You are reviewing a generated content item. Your ONLY job is to evaluate the tone and voice.

THE IDEAL VOICE:
- Sounds like a fun, warm best friend texting her about her partner's hobby
- Conspiratorial and slightly gossipy
- Empathetic — understands she's doing this out of love, not interest
- Playful — uses humour naturally, never forced
- Confident — explains things simply without hedging

PASS IF: A 27-year-old woman with zero football knowledge would enjoy reading it. It sounds like a real person texting.

FAIL IF: It reads like BBC Sport. Uses unexplained jargon. Condescending. Too formal.
Uses passive voice extensively. Uses ANY banned phrases: "Additionally", "Furthermore",
"Moreover", "It's worth noting", "Interestingly", "In conclusion", "As mentioned",
"It should be noted", "At the end of the day", "That being said". Uses semicolons or em dashes.

RESPONSE FORMAT:
{
    "pass": true/false,
    "confidence": 0.0-1.0,
    "notes": "Explanation of your decision",
    "issues": ["Specific lines or phrases that need fixing"],
    "suggestions": ["Specific rewording suggestions"]
}`;

const ACCURACY_SYSTEM_PROMPT = `You are a fact-checker for Goal Digger. The app generates football content using AI,
and your job is to make sure every claim is accurate.

This is CRITICAL. The user will repeat this information to her partner, who is a
passionate football fan. One wrong fact can lose a user forever.

CHECK FOR: Player names (correct spelling, correct team), match dates/times, scores,
league positions, injury/transfer info, quotes (must be from source data).

PASS IF: Every factual claim traces to the provided source data. No misspellings.

FAIL IF: ANY factual error, ANY unverifiable claim, ANY misspelled name.

RESPONSE FORMAT:
{
    "pass": true/false,
    "confidence": 0.0-1.0,
    "notes": "Summary of fact-check",
    "errors": [{"claim": "...", "issue": "...", "source_says": "...", "severity": "critical/minor"}],
    "unverifiable_claims": ["Claims not verifiable from source data"]
}`;

const BREVITY_SYSTEM_PROMPT = `You are an editor for Goal Digger. Ensure content is concise, scannable, respects time.

HEADLINE: 1-2 sentences, under 200 chars. Must NOT start with team name.
TALKING POINTS: 3-5 items, each 1-2 sentences. Must be conversation starters.
BODY: 3-5 paragraphs, each 2-4 sentences. Scannable in under 60 seconds.
No repetition across sections. No filler phrases.

PASS IF: All length requirements met, scannable in 60s, no repetition.
FAIL IF: Any length rule broken, significant repetition, takes >60s to scan.

RESPONSE FORMAT:
{
    "pass": true/false,
    "confidence": 0.0-1.0,
    "notes": "Summary",
    "headline_chars": 142,
    "headline_sentences": 2,
    "talking_point_count": 4,
    "body_paragraph_count": 4,
    "estimated_read_seconds": 45,
    "issues": ["Specific issues"],
    "suggested_cuts": ["Sentences to remove or shorten"]
}`;

const SAFETY_SYSTEM_PROMPT = `You are a content safety reviewer for Goal Digger. Content goes directly to users as
push notifications — there is no human review step after you. You are the last line of defense.

FAIL IF IT CONTAINS:
1. PERSONAL LIFE / OFF-PITCH: Comments about a player's partner, family, children,
   relationships, religion, politics. Exception: officially announced retirements.
2. DEFAMATION: Unverified accusations, speculation presented as fact, medical speculation.
3. DISCRIMINATION: Stereotypes based on race, nationality, gender, religion.
4. INAPPROPRIATE: Violence beyond normal football context, sexual content, excessive negativity.
5. COPYRIGHT: Verbatim quotes >2 sentences, close paraphrases of single articles.

PASS IF: Football-focused, warm, universally appropriate.

RESPONSE FORMAT:
{
    "pass": true/false,
    "confidence": 0.0-1.0,
    "notes": "Summary of safety review",
    "flags": [{"text": "...", "category": "personal_life|defamation|discrimination|inappropriate|copyright", "severity": "block|warn", "suggestion": "..."}]
}`;

interface ReviewRequest {
  content_item_id: string;
  team_id: string;
}

async function runReviewBot(
  botName: string,
  systemPrompt: string,
  contentInput: string
): Promise<ReviewNote> {
  const reviewedAt = new Date().toISOString();

  try {
    const response = await callClaude({
      system: systemPrompt,
      messages: [{ role: "user", content: contentInput }],
      max_tokens: 1000,
    });

    const text = response.content[0]?.text ?? "";

    // SECURITY: JSON.parse must be wrapped in try/catch — parse failure = FAIL
    let result: ReviewBotResult;
    try {
      result = JSON.parse(text);
    } catch {
      console.error(`${botName} returned invalid JSON:`, text.slice(0, 200));
      return {
        bot: botName as ReviewNote["bot"],
        pass: false,
        confidence: 0,
        notes: `JSON parse failure — treating as FAIL. Raw: ${text.slice(0, 100)}`,
        reviewed_at: reviewedAt,
      };
    }

    // Validate required fields exist
    if (typeof result.pass !== "boolean" || typeof result.confidence !== "number") {
      return {
        bot: botName as ReviewNote["bot"],
        pass: false,
        confidence: 0,
        notes: `Missing required fields (pass, confidence) — treating as FAIL`,
        reviewed_at: reviewedAt,
      };
    }

    return {
      bot: botName as ReviewNote["bot"],
      pass: result.pass,
      confidence: result.confidence,
      notes: result.notes ?? "",
      reviewed_at: reviewedAt,
    };
  } catch (e) {
    return {
      bot: botName as ReviewNote["bot"],
      pass: false,
      confidence: 0,
      notes: `Bot error: ${e instanceof Error ? e.message : String(e)}`,
      reviewed_at: reviewedAt,
    };
  }
}

serve(async (req) => {
  // Caller-auth gate (see _shared/require-service-auth.ts). Server-only
  // function — rejects anon-key / no-auth callers; accepts the service
  // key that triggerFunction + pg_cron present.
  const denied = requireServiceAuth(req);
  if (denied) return denied;
  const startTime = Date.now();
  const supabase = getSupabaseClient();

  try {
    const { content_item_id, team_id }: ReviewRequest = await req.json();

    // Fetch the draft content item
    const { data: item, error: itemErr } = await supabase
      .from("content_items")
      .select("*")
      .eq("id", content_item_id)
      .single();

    if (itemErr || !item) throw new Error(`Content item not found: ${content_item_id}`);

    // Fetch raw source data for accuracy review
    const { data: rawLogs } = await supabase
      .from("raw_fetch_logs")
      .select("source, data")
      .eq("team_id", team_id)
      .order("fetched_at", { ascending: false })
      .limit(10);

    const rawSourceData = (rawLogs ?? [])
      .map((l) => `${l.source}: ${JSON.stringify(l.data).slice(0, 500)}`)
      .join("\n\n");

    // Format talking points for display
    const talkingPoints = Array.isArray(item.talking_points)
      ? (item.talking_points as string[]).map((tp, i) => `${i + 1}. ${tp}`).join("\n")
      : JSON.stringify(item.talking_points);

    // Build review input
    const contentInput = `CONTENT TO REVIEW:

Headline: ${item.headline}

Talking Points:
${talkingPoints}

Body:
${item.body}

Emotional Context: ${item.emotional_context ?? "none"}
Team: ${team_id}`;

    const accuracyInput = `GENERATED CONTENT:

Headline: ${item.headline}

Talking Points:
${talkingPoints}

Body:
${item.body}

---

RAW SOURCE DATA THIS CONTENT WAS BASED ON:

${rawSourceData}`;

    // Run all 4 review bots: Tone → Accuracy → Brevity → Safety
    // First 3 run in parallel, Safety runs after
    const [toneResult, accuracyResult, brevityResult] = await Promise.all([
      runReviewBot("tone", TONE_SYSTEM_PROMPT, contentInput),
      runReviewBot("accuracy", ACCURACY_SYSTEM_PROMPT, accuracyInput),
      runReviewBot("brevity", BREVITY_SYSTEM_PROMPT, contentInput),
    ]);

    // Safety bot runs after the first 3
    const safetyResult = await runReviewBot("safety", SAFETY_SYSTEM_PROMPT, contentInput);

    const allResults = [toneResult, accuracyResult, brevityResult, safetyResult];
    const allPassed = allResults.every((r) => r.pass);
    const failedBots = allResults.filter((r) => !r.pass);

    // Log safety review separately
    await logPipelineEvent(supabase, {
      team_id,
      stage: "safety_review",
      status: safetyResult.pass ? "success" : "failure",
      duration_ms: Date.now() - startTime,
      message: safetyResult.notes,
      content_item_id,
    });

    if (allPassed) {
      // All 4 pass → approve
      await supabase
        .from("content_items")
        .update({
          status: "approved",
          review_notes: allResults,
        })
        .eq("id", content_item_id);

      // Trigger notification sender
      await triggerFunction("notification-sender", {
        content_item_id,
        team_id,
      });

      await logPipelineEvent(supabase, {
        team_id,
        stage: "review",
        status: "success",
        duration_ms: Date.now() - startTime,
        message: `Approved — all 4 bots passed`,
        content_item_id,
      });
    } else if (failedBots.length === 1 && item.status === "draft") {
      // Only 1 bot failed on first attempt → retry once
      // (Skip retry if this is already a retry)
      await supabase
        .from("content_items")
        .update({
          status: "draft",
          review_notes: allResults,
        })
        .eq("id", content_item_id);

      // Trigger content-generator with revision feedback
      const failedBot = failedBots[0];
      await triggerFunction("content-generator", {
        team_id,
        trigger: "new_data",
        content_item_id,
        fetch_log_ids: [],
      });

      await logPipelineEvent(supabase, {
        team_id,
        stage: "review",
        status: "failure",
        duration_ms: Date.now() - startTime,
        message: `1 bot failed (${failedBot.bot}): ${failedBot.notes}. Retrying.`,
        content_item_id,
      });
    } else {
      // Multiple bots failed or retry also failed → reject
      await supabase
        .from("content_items")
        .update({
          status: "rejected",
          review_notes: allResults,
        })
        .eq("id", content_item_id);

      await logPipelineEvent(supabase, {
        team_id,
        stage: "review",
        status: "failure",
        duration_ms: Date.now() - startTime,
        message: `Rejected — ${failedBots.length} bots failed: ${failedBots.map((b) => b.bot).join(", ")}`,
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
