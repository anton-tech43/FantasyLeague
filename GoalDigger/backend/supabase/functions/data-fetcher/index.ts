// Goal Digger — Data Fetcher Edge Function
// Runs every 30 minutes (08:00-23:00 GMT). Pulls data from API-Football and
// RSS feeds for each team. Stores raw data in raw_fetch_logs. Triggers
// content-generator if new data found.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Team {
  id: string;
  display_name: string;
  api_football_id: number;
  short_name: string;
}

interface RSSItem {
  title: string;
  link: string;
  description: string;
  pubDate: string;
}

// Player name lookup for RSS filtering — update each transfer window
const TEAM_PLAYERS: Record<string, string[]> = {
  arsenal: [
    "Saka", "Saliba", "Rice", "Odegaard", "Havertz", "Raya", "Timber",
    "Zinchenko", "White", "Gabriel", "Trossard", "Martinelli", "Jorginho",
    "Partey", "Nketiah", "Ramsdale", "Kiwior", "Tomiyasu", "Vieira",
    "Jesus", "Nelson", "Smith Rowe", "Calafiori", "Merino", "Sterling",
  ],
  man_utd: [
    "Fernandes", "Rashford", "Hojlund", "Mainoo", "Martinez", "Onana",
    "Garnacho", "Mount", "Dalot", "Shaw", "Varane", "Casemiro",
    "Antony", "Eriksen", "Wan-Bissaka", "Maguire", "McTominay",
    "Amrabat", "Diallo", "Lindelof", "Malacia", "Heaton", "Zirkzee",
    "Ugarte", "De Ligt", "Mazraoui",
  ],
  west_ham: [
    "Bowen", "Paqueta", "Kudus", "Antonio", "Areola", "Soler",
    "Ward-Prowse", "Alvarez", "Soucek", "Coufal", "Cresswell",
    "Zouma", "Fabianski", "Mavropanos", "Emerson", "Ings",
    "Aguerd", "Todibo", "Summerville", "Kilman", "Wan-Bissaka",
    "Rodriguez", "Guilherme", "Fullkrug",
  ],
};

// RSS feed sources
const RSS_FEEDS = [
  { name: "bbc_sport", url: "https://feeds.bbci.co.uk/sport/football/rss.xml" },
  { name: "sky_sports", url: "https://www.skysports.com/rss/12040" },
  { name: "guardian", url: "https://www.theguardian.com/football/rss" },
  { name: "mirror", url: "https://www.mirror.co.uk/sport/football/rss.xml" },
  { name: "daily_mail", url: "https://www.dailymail.co.uk/sport/football/index.rss" },
  { name: "evening_standard", url: "https://www.standard.co.uk/sport/football.rss" },
  { name: "independent", url: "https://www.independent.co.uk/sport/football/rss" },
  { name: "telegraph", url: "https://www.telegraph.co.uk/football/rss.xml" },
  { name: "espn", url: "https://www.espn.com/espn/rss/soccer/news" },
  { name: "goal_com", url: "https://www.goal.com/feeds/en/news" },
  { name: "football365", url: "https://www.football365.com/feed" },
  { name: "teamtalk", url: "https://www.teamtalk.com/feed" },
];

// API-Football endpoints per team
const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";
const PREMIER_LEAGUE_ID = 39;
const CURRENT_SEASON = 2025;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/** Fetch API-Football endpoints for a single team. */
async function fetchApiFootball(
  teamId: number,
  apiKey: string,
): Promise<Record<string, unknown>> {
  const headers = {
    "x-rapidapi-key": apiKey,
    "x-rapidapi-host": "v3.football.api-sports.io",
  };

  const endpoints = [
    { key: "next_fixtures", path: `/fixtures?team=${teamId}&next=5` },
    { key: "last_fixtures", path: `/fixtures?team=${teamId}&last=3` },
    { key: "injuries", path: `/injuries?team=${teamId}&season=${CURRENT_SEASON}` },
    { key: "standings", path: `/standings?league=${PREMIER_LEAGUE_ID}&season=${CURRENT_SEASON}` },
    { key: "transfers", path: `/transfers?team=${teamId}` },
    { key: "squad", path: `/players/squads?team=${teamId}` },
  ];

  const results: Record<string, unknown> = {};

  // Fetch all endpoints concurrently
  const fetches = endpoints.map(async (ep) => {
    try {
      const res = await fetch(`${API_FOOTBALL_BASE}${ep.path}`, { headers });
      if (!res.ok) {
        console.error(`API-Football ${ep.key} returned ${res.status}`);
        return { key: ep.key, data: null, error: `HTTP ${res.status}` };
      }
      const json = await res.json();
      return { key: ep.key, data: json, error: null };
    } catch (err) {
      console.error(`API-Football ${ep.key} failed:`, err);
      return { key: ep.key, data: null, error: String(err) };
    }
  });

  const settled = await Promise.all(fetches);
  for (const result of settled) {
    results[result.key] = result.data ?? { error: result.error };
  }
  return results;
}

/** Parse RSS XML into a list of items. Simple regex-based parser for Deno. */
function parseRSS(xml: string): RSSItem[] {
  const items: RSSItem[] = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  let match: RegExpExecArray | null;

  while ((match = itemRegex.exec(xml)) !== null) {
    const block = match[1];
    const title = block.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/)?.[1] ??
      block.match(/<title>(.*?)<\/title>/)?.[1] ?? "";
    const link = block.match(/<link>(.*?)<\/link>/)?.[1] ?? "";
    const description =
      block.match(/<description><!\[CDATA\[(.*?)\]\]>/)?.[1] ??
      block.match(/<description>(.*?)<\/description>/)?.[1] ?? "";
    const pubDate = block.match(/<pubDate>(.*?)<\/pubDate>/)?.[1] ?? "";

    items.push({ title, link, description, pubDate });
  }
  return items;
}

/** Check if an RSS item is relevant to a team by checking title/description. */
function isRelevantToTeam(
  item: RSSItem,
  team: Team,
  players: string[],
): boolean {
  const text = `${item.title} ${item.description}`.toLowerCase();
  const teamNames = [
    team.display_name.toLowerCase(),
    team.short_name.toLowerCase(),
    team.id.replace("_", " "),
  ];

  // Check team name match
  if (teamNames.some((name) => text.includes(name))) return true;

  // Check player surname match
  if (players.some((p) => text.includes(p.toLowerCase()))) return true;

  return false;
}

/** Fetch and filter RSS feeds for a team. */
async function fetchRSSForTeam(
  team: Team,
): Promise<{ source: string; articles: RSSItem[] }[]> {
  const players = TEAM_PLAYERS[team.id] ?? [];
  const results: { source: string; articles: RSSItem[] }[] = [];

  const fetches = RSS_FEEDS.map(async (feed) => {
    try {
      const res = await fetch(feed.url, {
        signal: AbortSignal.timeout(10_000), // 10s timeout per feed
      });
      if (!res.ok) {
        console.warn(`RSS ${feed.name} returned ${res.status}`);
        return { source: feed.name, articles: [] as RSSItem[] };
      }
      const xml = await res.text();
      const items = parseRSS(xml);
      const relevant = items.filter((item) =>
        isRelevantToTeam(item, team, players)
      );
      return { source: feed.name, articles: relevant };
    } catch (err) {
      console.warn(`RSS ${feed.name} failed:`, err);
      return { source: feed.name, articles: [] as RSSItem[] };
    }
  });

  const settled = await Promise.all(fetches);
  for (const result of settled) {
    if (result.articles.length > 0) {
      results.push(result);
    }
  }
  return results;
}

/** Check if a URL already exists in raw_fetch_logs from the last 48 hours. */
async function isDuplicate(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
  url: string,
): Promise<boolean> {
  const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
  const { data } = await supabase
    .from("raw_fetch_logs")
    .select("id")
    .eq("team_id", teamId)
    .gte("fetched_at", since)
    .limit(1)
    // Search for URL in the JSONB data
    .filter("data->url", "eq", url);

  return (data?.length ?? 0) > 0;
}

/** Log a pipeline health entry. */
async function logHealth(
  supabase: ReturnType<typeof createClient>,
  teamId: string,
  stage: string,
  status: string,
  durationMs: number,
  message?: string,
) {
  await supabase.from("pipeline_health").insert({
    team_id: teamId,
    stage,
    status,
    duration_ms: durationMs,
    message,
  });
}

/** Trigger the content-generator function for a team. */
async function triggerContentGenerator(
  teamId: string,
  hasNewData: boolean,
) {
  if (!hasNewData) return;

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  try {
    await fetch(`${supabaseUrl}/functions/v1/content-generator`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ team_id: teamId }),
    });
  } catch (err) {
    console.error(`Failed to trigger content-generator for ${teamId}:`, err);
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  try {
    const supabase = getSupabaseClient();
    const rapidApiKey = Deno.env.get("RAPIDAPI_KEY");

    if (!rapidApiKey) {
      return new Response(
        JSON.stringify({ error: "RAPIDAPI_KEY not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // Check if this is a matchday-only check
    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch {
      // No body — normal fetch run
    }
    const isMatchdayCheck = body.matchday_check === true;

    // Get all teams
    const { data: teams, error: teamsErr } = await supabase
      .from("teams")
      .select("*");

    if (teamsErr || !teams) {
      return new Response(
        JSON.stringify({ error: "Failed to load teams", details: teamsErr }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const results: Record<string, { api_football: boolean; rss_articles: number; new_data: boolean }> = {};

    for (const team of teams as Team[]) {
      const startTime = Date.now();
      let hasNewData = false;

      try {
        // 1. Fetch API-Football data
        const apiData = await fetchApiFootball(team.api_football_id, rapidApiKey);
        await supabase.from("raw_fetch_logs").insert({
          team_id: team.id,
          source: "api_football",
          data: apiData,
        });

        // 2. Fetch and filter RSS feeds
        const rssResults = await fetchRSSForTeam(team);
        let newArticleCount = 0;

        for (const feedResult of rssResults) {
          for (const article of feedResult.articles) {
            // Deduplicate by URL
            const alreadySeen = await isDuplicate(supabase, team.id, article.link);
            if (alreadySeen) continue;

            newArticleCount++;
            await supabase.from("raw_fetch_logs").insert({
              team_id: team.id,
              source: feedResult.source,
              data: {
                url: article.link,
                title: article.title,
                description: article.description,
                pub_date: article.pubDate,
              },
            });
          }
        }

        hasNewData = newArticleCount > 0 || isMatchdayCheck;

        results[team.id] = {
          api_football: true,
          rss_articles: newArticleCount,
          new_data: hasNewData,
        };

        await logHealth(
          supabase,
          team.id,
          "fetch",
          "success",
          Date.now() - startTime,
          `Fetched ${newArticleCount} new articles`,
        );

        // 3. Trigger content generator if new data found
        if (hasNewData) {
          await triggerContentGenerator(team.id, true);
        }
      } catch (err) {
        console.error(`Error processing team ${team.id}:`, err);
        results[team.id] = {
          api_football: false,
          rss_articles: 0,
          new_data: false,
        };
        await logHealth(
          supabase,
          team.id,
          "fetch",
          "failure",
          Date.now() - startTime,
          String(err),
        );
      }
    }

    return new Response(
      JSON.stringify({ success: true, results }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Data fetcher error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
