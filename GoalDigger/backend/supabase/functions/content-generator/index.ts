// Goal Digger — Content Generator Edge Function
// Triggered by data-fetcher when new data is found for a team.
// Uses Claude API to determine newsworthiness and generate content.
// See PROMPTS.md for all prompt definitions.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ContentGeneratorInput {
  team_id: string;
  trigger?: "new_data" | "matchday";
  fetch_log_ids?: string[];
  // Matchday fields (Contract 1)
  fixture_id?: string;
  kickoff_time?: string;
  opponent?: string;
  // Legacy fields
  type?: "news" | "matchday";
  fixture_data?: Record<string, unknown>;
}

interface GeneratedContent {
  is_newsworthy: boolean;
  skip_reason?: string;
  newsworthiness_score: number;
  headline?: string;
  body?: string;
  talking_points?: string[];
  emotional_context?: string;
  source_summary?: string;
  // Matchday-specific
  pre_match_mood?: string;
  rivalry_level?: string;
  if_they_win?: string;
  if_they_lose?: string;
  bold_prediction?: string;
}

// ---------------------------------------------------------------------------
// Prompt templates (from PROMPTS.md)
// ---------------------------------------------------------------------------

const NEWS_SYSTEM_PROMPT = `You are the voice of Goal Digger — an app that helps girlfriends (and anyone) stay
in the loop about their partner's favourite Premier League team.

Your user is a woman in her mid-20s to early 30s. She does NOT care about football.
She's doing this because she loves her partner and wants to connect with him over
something he's passionate about. That's the emotional context for everything you write.

THE TEAM: {{team_display_name}} (her partner's team)

YOUR JOB:
Take the raw football news below and decide: is this worth telling her about?
If yes, turn it into a short, fun, useful update she can actually use in conversation.

WRITING RULES:

1. VOICE: Write like you're her best friend who happens to know about football. Warm,
   funny, a little conspiratorial — like you're giving her inside info so she can
   impress him. Never sound like a sports journalist, commentator, or pundit.

2. JARGON: Assume she knows NOTHING about football. If a term is unavoidable, explain
   it instantly and naturally:
   - BAD: "He picked up a yellow card for simulation."
   - GOOD: "He got a yellow card (basically a warning from the referee) for diving
     — which means he faked being fouled. Cheeky."
   - BAD: "Their xG was 2.3 but they only scored once."
   - GOOD: Just don't use xG. Ever. She doesn't need it.

3. CONVERSATION FRAMING: Every talking point should be something she can naturally
   say or ask. Frame them as conversation starters, not facts to memorize:
   - BAD: "Saka has 7 assists this season."
   - GOOD: "If Saka comes up, you could say 'He's been setting up goals all
     season, right?' — your partner will be impressed you noticed."

4. EMOTIONAL INTELLIGENCE: Connect the football to something she'd understand:
   - Transfer = like someone quitting their job and joining a rival company
   - Derby match = like when your ex shows up at the same party
   - League standings = like a leaderboard at work
   - Injury = like a star actor pulling out of a movie right before filming

5. TONE CALIBRATION:
   - Exciting news (big win, new signing) → match his energy, be enthusiastic
   - Bad news (loss, injury) → be empathetic — "He might be grumpy tonight"
   - Drama (controversy, red card) → lean into the gossip angle
   - Boring admin (fixture rescheduled) → probably not worth a notification

6. HONESTY: If the news is genuinely boring or too niche, say so. Return
   is_newsworthy: false. We NEVER spam. A quiet day with no notification is
   better than a forced one.

7. ACCURACY: Never make up facts, stats, or quotes. Only use information from
   the provided source data. If you're unsure about something, leave it out.

8. LENGTH:
   - Headline: 1-2 sentences. Max 200 characters. This is the push notification —
     it needs to hook her in 3 seconds.
   - Talking points: 3-5 items. Each 1-2 sentences. These are conversation scripts.
   - Body: 3-5 short paragraphs. Scannable in 60 seconds. This is for users who
     want the full story before talking to their partner.`;

const MATCHDAY_SYSTEM_PROMPT = `You are the voice of Goal Digger — an app that helps girlfriends stay in the loop
about their partner's favourite Premier League team.

THE TEAM: {{team_display_name}} (her partner's team)
TODAY'S MATCH: {{team_display_name}} vs {{opponent_name}}
KICKOFF: {{kickoff_time}} ({{kickoff_day}})
VENUE: {{venue}}
COMPETITION: {{competition}}

YOUR JOB:
Create a match day briefing that gives her everything she needs to sound like she
knows what's going on — and maybe even start a conversation about the game.

Think of this as a cheat sheet. She's cramming 5 minutes before the "exam" (her
partner talking about the match all evening).

WRITING RULES:

1. START WITH CONTEXT: Why does this match matter? Is it a rivalry? A title decider?
   A relegation battle? A meaningless mid-table game? Be honest about the stakes.

2. RIVALRY EXPLAINERS: If this is a derby or a rivalry match, explain the rivalry
   in relatable terms.

3. KEY PLAYERS: Mention 2-3 players maximum. Only the ones most likely to come up
   in conversation.

4. FORM & MOOD: How are the team doing lately? This tells her what mood he'll be in.

5. PREDICTION ANGLE: Give her a light prediction she can use.

6. AFTER THE MATCH: Give her one line about what to say depending on the result.

7. Same rules as news content: no jargon, no condescension, explain everything,
   conversation framing, max 200 char headline, 3-5 talking points, 3-5 paragraph body.`;

const NEWS_TOOL = {
  name: "generate_content",
  description: "Generate a content item for the Goal Digger app, or decide to skip if nothing is newsworthy",
  input_schema: {
    type: "object",
    properties: {
      is_newsworthy: {
        type: "boolean",
        description: "Is this genuinely worth notifying her about? Be honest. When in doubt, skip.",
      },
      skip_reason: {
        type: "string",
        description: "If not newsworthy: explain why in one sentence (for internal logging only)",
      },
      newsworthiness_score: {
        type: "integer",
        description: "1-10 scale. 1 = routine/boring, 5 = mildly interesting, 8 = definitely tell her, 10 = huge breaking news. Only publish if 6+.",
        minimum: 1,
        maximum: 10,
      },
      headline: {
        type: "string",
        description: "1-2 sentence push notification text. Max 200 characters.",
        maxLength: 200,
      },
      body: {
        type: "string",
        description: "Full detail view content in markdown. 3-5 short paragraphs.",
      },
      talking_points: {
        type: "array",
        items: { type: "string" },
        description: "3-5 conversation starters.",
        minItems: 3,
        maxItems: 5,
      },
      emotional_context: {
        type: "string",
        enum: ["exciting", "bad_news", "drama", "informational", "funny"],
      },
      source_summary: {
        type: "string",
        description: "One-line summary of which source(s) this content is based on",
      },
    },
    required: ["is_newsworthy", "newsworthiness_score"],
  },
};

const MATCHDAY_TOOL = {
  name: "generate_matchday_content",
  input_schema: {
    type: "object",
    properties: {
      headline: { type: "string", maxLength: 200 },
      body: { type: "string" },
      talking_points: {
        type: "array",
        items: { type: "string" },
        minItems: 3,
        maxItems: 5,
      },
      pre_match_mood: {
        type: "string",
        enum: ["confident", "nervous", "excited", "meh"],
      },
      rivalry_level: {
        type: "string",
        enum: ["derby", "big_game", "normal", "dead_rubber"],
      },
      if_they_win: { type: "string" },
      if_they_lose: { type: "string" },
      bold_prediction: { type: "string" },
      emotional_context: {
        type: "string",
        enum: ["exciting", "bad_news", "drama", "informational", "funny"],
      },
      source_summary: { type: "string" },
    },
    required: [
      "headline", "body", "talking_points", "pre_match_mood",
      "rivalry_level", "if_they_win", "if_they_lose",
    ],
  },
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/** Get raw source data for a team from the last 2 hours. */
async function getRawData(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
): Promise<Record<string, unknown>[]> {
  const since = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
  const { data } = await supabase
    .from("raw_fetch_logs")
    .select("source, data, fetched_at")
    .eq("team_id", teamId)
    .gte("fetched_at", since)
    .order("fetched_at", { ascending: false });

  return data ?? [];
}

/** Get recent published headlines for deduplication. */
async function getRecentHeadlines(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
): Promise<string[]> {
  const since = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
  const { data } = await supabase
    .from("content_items")
    .select("headline")
    .eq("team_id", teamId)
    .in("status", ["draft", "approved", "published"])
    .gte("created_at", since);

  return data?.map((d: { headline: string }) => d.headline) ?? [];
}

/** Get team info. */
async function getTeam(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
) {
  const { data } = await supabase
    .from("teams")
    .select("*")
    .eq("id", teamId)
    .single();
  return data;
}

/** Check anti-spam rules: max 2 notifications per day (rolling 24h), min 3 hours between.
 *  Matchday content bypasses the 3h gap rule per Contract 4. */
async function checkAntiSpam(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
  contentType: "news" | "matchday" = "news",
): Promise<{ allowed: boolean; reason?: string }> {
  // Rolling 24h daily limit
  const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const { count: dailyCount } = await supabase
    .from("content_items")
    .select("*", { count: "exact", head: true })
    .eq("team_id", teamId)
    .eq("status", "published")
    .gte("published_at", twentyFourHoursAgo);

  if ((dailyCount ?? 0) >= 2) {
    return { allowed: false, reason: "Max 2 notifications per day reached" };
  }

  // 3-hour gap (skip for matchday per Contract 4)
  if (contentType !== "matchday") {
    const { data: lastPublished } = await supabase
      .from("content_items")
      .select("published_at")
      .eq("team_id", teamId)
      .eq("status", "published")
      .order("published_at", { ascending: false })
      .limit(1);

    if (lastPublished?.[0]?.published_at) {
      const hoursSinceLast =
        (Date.now() - new Date(lastPublished[0].published_at).getTime()) / (1000 * 60 * 60);
      if (hoursSinceLast < 3) {
        return { allowed: false, reason: "Min 3 hours between notifications not met" };
      }
    }
  }

  return { allowed: true };
}

/** Call Claude API with the given prompt and tool. */
async function callClaude(
  systemPrompt: string,
  userMessage: string,
  tool: Record<string, unknown>,
  toolName: string,
): Promise<GeneratedContent> {
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
      model: "claude-sonnet-4-6",
      max_tokens: 2000,
      system: systemPrompt,
      messages: [{ role: "user", content: userMessage }],
      tools: [tool],
      tool_choice: { type: "tool", name: toolName },
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Claude API error ${res.status}: ${errText}`);
  }

  const json = await res.json();

  // Extract tool use result
  const toolUse = json.content?.find(
    (block: Record<string, unknown>) => block.type === "tool_use",
  );
  if (!toolUse) throw new Error("No tool_use in Claude response");

  return toolUse.input as GeneratedContent;
}

/** Format raw data into a user message for the news prompt. */
function formatNewsUserMessage(
  teamDisplayName: string,
  rawData: Record<string, unknown>[],
  recentHeadlines: string[],
): string {
  // Separate API-Football data and RSS articles
  const apiData = rawData.filter((d: Record<string, unknown>) => d.source === "api_football");
  const rssData = rawData.filter((d: Record<string, unknown>) => d.source !== "api_football");

  // Format articles
  const articles = rssData.map((d: Record<string, unknown>) => {
    const data = d.data as Record<string, string>;
    return `- [${data.title}] ${data.description ?? ""} (Source: ${d.source})`;
  }).join("\n");

  // Extract standings if available
  let leaguePosition = "Unknown";
  let recentForm = "Unknown";
  let nextFixture = "Unknown";

  if (apiData.length > 0) {
    const latestApi = apiData[0].data as Record<string, unknown>;
    if (latestApi.standings) {
      try {
        const standings = latestApi.standings as Record<string, unknown>[];
        const response = standings as unknown as { response: Array<{ league: { standings: Array<Array<{ team: { name: string }; rank: number; points: number; form: string }>> } }> };
        if (response.response?.[0]?.league?.standings?.[0]) {
          const table = response.response[0].league.standings[0];
          const teamEntry = table.find((t) =>
            t.team.name.toLowerCase().includes(teamDisplayName.toLowerCase())
          );
          if (teamEntry) {
            leaguePosition = `${teamEntry.rank}th (${teamEntry.points} points)`;
            recentForm = teamEntry.form ?? "Unknown";
          }
        }
      } catch {
        // Standings parsing failed — use defaults
      }
    }

    if (latestApi.next_fixtures) {
      try {
        const fixtures = latestApi.next_fixtures as { response: Array<{ fixture: { date: string }; teams: { home: { name: string }; away: { name: string } } }> };
        if (fixtures.response?.[0]) {
          const f = fixtures.response[0];
          nextFixture = `${f.teams.home.name} vs ${f.teams.away.name} (${new Date(f.fixture.date).toLocaleDateString()})`;
        }
      } catch {
        // Fixtures parsing failed
      }
    }
  }

  const recentPublished = recentHeadlines.length > 0
    ? recentHeadlines.map((h) => `- ${h}`).join("\n")
    : "(No recent content)";

  return `Here is the latest data for ${teamDisplayName}:

--- RAW NEWS ARTICLES ---
${articles || "(No new articles)"}

--- TEAM STATS ---
League position: ${leaguePosition}
Recent form: ${recentForm}
Next match: ${nextFixture}

--- RECENT CONTENT ---
(These are items we already published recently — DO NOT duplicate them)
${recentPublished}

---

Analyze the news and decide if anything is worth telling our user about.
If multiple stories are newsworthy, pick the SINGLE most interesting one.
One notification at a time — never overwhelm her.`;
}

/** Log pipeline health. */
async function logHealth(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
  status: string,
  durationMs: number,
  message: string,
  contentItemId?: string,
) {
  await supabase.from("pipeline_health").insert({
    team_id: teamId,
    stage: "generate",
    status,
    duration_ms: durationMs,
    message,
    content_item_id: contentItemId,
  });
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

/** Format matchday user message with fixture data. */
function formatMatchdayUserMessage(
  teamDisplayName: string,
  fixtureData: Record<string, unknown>,
  rawData: Record<string, unknown>[],
  recentHeadlines: string[],
): string {
  // Extract recent form from API-Football data
  const apiData = rawData.filter((d: Record<string, unknown>) => d.source === "api_football");
  let recentForm = "Unknown";
  let leaguePosition = "Unknown";
  let injuries = "None reported";

  if (apiData.length > 0) {
    const latestApi = apiData[0].data as Record<string, unknown>;
    try {
      if (latestApi.standings) {
        const response = latestApi.standings as unknown as { response: Array<{ league: { standings: Array<Array<{ team: { name: string }; rank: number; points: number; form: string }>> } }> };
        if (response.response?.[0]?.league?.standings?.[0]) {
          const table = response.response[0].league.standings[0];
          const teamEntry = table.find((t) =>
            t.team.name.toLowerCase().includes(teamDisplayName.toLowerCase())
          );
          if (teamEntry) {
            leaguePosition = `${teamEntry.rank}th (${teamEntry.points} points)`;
            recentForm = teamEntry.form ?? "Unknown";
          }
        }
      }
      if (latestApi.injuries) {
        const injResponse = latestApi.injuries as { response: Array<{ player: { name: string }; player_injury: { type: string } }> };
        if (injResponse.response?.length > 0) {
          injuries = injResponse.response
            .slice(0, 5)
            .map((i) => `${i.player.name} (${i.player_injury?.type ?? "unknown"})`)
            .join(", ");
        }
      }
    } catch {
      // Parsing failed — use defaults
    }
  }

  const recentPublished = recentHeadlines.length > 0
    ? recentHeadlines.map((h) => `- ${h}`).join("\n")
    : "(No recent content)";

  return `Here is today's match information for ${teamDisplayName}:

--- MATCH DETAILS ---
Opponent: ${fixtureData.opponent_name ?? fixtureData.opponent ?? "TBD"}
Kickoff: ${fixtureData.kickoff_time ?? "TBD"}
Venue: ${fixtureData.venue ?? "TBD"}
Competition: ${fixtureData.competition ?? "Premier League"}
Home/Away: ${fixtureData.is_home ? "HOME" : "AWAY"}

--- TEAM CONTEXT ---
League position: ${leaguePosition}
Recent form: ${recentForm}
Key injuries: ${injuries}

--- RECENT CONTENT ---
(These are items we already published recently — DO NOT duplicate them)
${recentPublished}

---

Create a matchday briefing that helps her understand what's happening today.
Give her everything she needs to sound knowledgeable when he talks about this match.`;
}

serve(async (req) => {
  try {
    const supabase = getSupabaseClient();
    const input: ContentGeneratorInput = await req.json();
    const { team_id: teamId } = input;

    if (!teamId) {
      return new Response(
        JSON.stringify({ error: "team_id required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const startTime = Date.now();

    // Determine content type from trigger (Contract 1)
    const isMatchday = input.trigger === "matchday" || input.type === "matchday";

    // Get team info
    const team = await getTeam(supabase, teamId);
    if (!team) {
      return new Response(
        JSON.stringify({ error: `Team not found: ${teamId}` }),
        { status: 404, headers: { "Content-Type": "application/json" } },
      );
    }

    // Check anti-spam rules (Contract 4: matchday bypasses 3h gap)
    const spamCheck = await checkAntiSpam(supabase, teamId, isMatchday ? "matchday" : "news");
    if (!spamCheck.allowed) {
      await logHealth(supabase, teamId, "skipped", Date.now() - startTime, spamCheck.reason!);
      return new Response(
        JSON.stringify({ skipped: true, reason: spamCheck.reason }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Get raw data and recent headlines
    const rawData = await getRawData(supabase, teamId);
    const recentHeadlines = await getRecentHeadlines(supabase, teamId);

    if (rawData.length === 0 && !isMatchday) {
      await logHealth(supabase, teamId, "skipped", Date.now() - startTime, "No raw data available");
      return new Response(
        JSON.stringify({ skipped: true, reason: "No raw data" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    if (isMatchday) {
      // ---- MATCHDAY CONTENT PATH ----
      // Build fixture data from Contract 1 payload or legacy format
      const fixtureData: Record<string, unknown> = input.fixture_data ?? {
        fixture_id: input.fixture_id,
        kickoff_time: input.kickoff_time,
        opponent_name: input.opponent,
      };

      const systemPrompt = MATCHDAY_SYSTEM_PROMPT
        .replace(/\{\{team_display_name\}\}/g, team.display_name)
        .replace(/\{\{opponent_name\}\}/g, String(fixtureData.opponent_name ?? fixtureData.opponent ?? "TBD"))
        .replace(/\{\{kickoff_time\}\}/g, String(fixtureData.kickoff_time ?? "TBD"))
        .replace(/\{\{kickoff_day\}\}/g, fixtureData.kickoff_time
          ? new Date(String(fixtureData.kickoff_time)).toLocaleDateString("en-GB", { weekday: "long" })
          : "TBD")
        .replace(/\{\{venue\}\}/g, String(fixtureData.venue ?? "TBD"))
        .replace(/\{\{competition\}\}/g, String(fixtureData.competition ?? "Premier League"));

      const userMessage = formatMatchdayUserMessage(
        team.display_name,
        fixtureData,
        rawData,
        recentHeadlines,
      );

      const result = await callClaude(
        systemPrompt,
        userMessage,
        MATCHDAY_TOOL,
        "generate_matchday_content",
      );

      // Build Contract 3 JSONB format for talking_points
      const talkingPointsJsonb = {
        regular: result.talking_points ?? [],
        post_match: {
          if_they_win: result.if_they_win ?? "",
          if_they_lose: result.if_they_lose ?? "",
          bold_prediction: result.bold_prediction ?? "",
        },
        metadata: {
          pre_match_mood: result.pre_match_mood ?? "meh",
          rivalry_level: result.rivalry_level ?? "normal",
        },
      };

      // Save as draft content item
      const { data: contentItem, error: insertErr } = await supabase
        .from("content_items")
        .insert({
          team_id: teamId,
          type: "matchday",
          headline: result.headline,
          body: result.body,
          talking_points: talkingPointsJsonb,
          emotional_context: result.emotional_context ?? "exciting",
          source_urls: [],
          match_id: String(fixtureData.fixture_id ?? ""),
          kickoff_time: fixtureData.kickoff_time ?? null,
          status: "draft",
        })
        .select()
        .single();

      if (insertErr) {
        throw new Error(`Failed to insert matchday content: ${insertErr.message}`);
      }

      await logHealth(
        supabase,
        teamId,
        "success",
        Date.now() - startTime,
        `Generated matchday content vs ${fixtureData.opponent_name ?? fixtureData.opponent}`,
        contentItem.id,
      );

      // Trigger content reviewer (Contract 1: include team_id)
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

      try {
        await fetch(`${supabaseUrl}/functions/v1/content-reviewer`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            content_item_id: contentItem.id,
            team_id: teamId,
          }),
        });
      } catch (err) {
        console.error("Failed to trigger content-reviewer:", err);
      }

      return new Response(
        JSON.stringify({
          published: true,
          content_id: contentItem.id,
          type: "matchday",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // ---- NEWS CONTENT PATH ----
    const systemPrompt = NEWS_SYSTEM_PROMPT.replace(
      /\{\{team_display_name\}\}/g,
      team.display_name,
    );
    const userMessage = formatNewsUserMessage(
      team.display_name,
      rawData,
      recentHeadlines,
    );

    const result = await callClaude(
      systemPrompt,
      userMessage,
      NEWS_TOOL,
      "generate_content",
    );

    // Decision: is it newsworthy enough?
    if (!result.is_newsworthy || result.newsworthiness_score < 6) {
      await logHealth(
        supabase,
        teamId,
        "skipped",
        Date.now() - startTime,
        `Not newsworthy (score: ${result.newsworthiness_score}). Reason: ${result.skip_reason ?? "N/A"}`,
      );
      return new Response(
        JSON.stringify({
          published: false,
          score: result.newsworthiness_score,
          reason: result.skip_reason,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // Save as draft content item
    const { data: contentItem, error: insertErr } = await supabase
      .from("content_items")
      .insert({
        team_id: teamId,
        type: "news",
        headline: result.headline,
        body: result.body,
        talking_points: result.talking_points,
        emotional_context: result.emotional_context,
        source_urls: [],
        status: "draft",
      })
      .select()
      .single();

    if (insertErr) {
      throw new Error(`Failed to insert content: ${insertErr.message}`);
    }

    await logHealth(
      supabase,
      teamId,
      "success",
      Date.now() - startTime,
      `Generated news content (score: ${result.newsworthiness_score})`,
      contentItem.id,
    );

    // Trigger content reviewer (Contract 1: include team_id)
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    try {
      await fetch(`${supabaseUrl}/functions/v1/content-reviewer`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          content_item_id: contentItem.id,
          team_id: teamId,
        }),
      });
    } catch (err) {
      console.error("Failed to trigger content-reviewer:", err);
    }

    return new Response(
      JSON.stringify({
        published: true,
        content_id: contentItem.id,
        score: result.newsworthiness_score,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Content generator error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
