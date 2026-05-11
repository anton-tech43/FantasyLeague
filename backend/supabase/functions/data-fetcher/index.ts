// data-fetcher/index.ts
// Goal Digger — Fetches RSS feeds + API-Football data, stores in raw_fetch_logs
// Schedule: Every 30 min, 08:00-23:00 GMT via pg_cron

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";
import { triggerFunction } from "../_shared/trigger.ts";
import { sanitizeText, wrapExternalData } from "../_shared/input-sanitizer.ts";

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
  { name: "espn_fc", url: "https://www.espn.com/espn/rss/soccer/news" },
  { name: "goal_com", url: "https://www.goal.com/feeds/en/news" },
  { name: "football365", url: "https://www.football365.com/feed" },
  { name: "teamtalk", url: "https://www.teamtalk.com/feed" },
];

// Key player surnames per team for RSS filtering
const TEAM_PLAYERS: Record<string, string[]> = {
  arsenal: [
    "Saka", "Saliba", "Rice", "Odegaard", "Havertz", "Raya", "Timber",
    "Trossard", "Zinchenko", "Gabriel", "White", "Jorginho", "Nketiah",
    "Partey", "Ramsdale", "Tomiyasu", "Kiwior", "Nelson", "Vieira",
  ],
  man_utd: [
    "Fernandes", "Rashford", "Hojlund", "Mainoo", "Martinez", "Onana",
    "Garnacho", "Mount", "Shaw", "Dalot", "Casemiro", "Antony",
    "Eriksen", "Varane", "Amrabat", "Diallo", "McTominay", "Weghorst",
  ],
  west_ham: [
    "Bowen", "Paqueta", "Kudus", "Antonio", "Areola", "Soler",
    "Ward-Prowse", "Mavropanos", "Zouma", "Emerson", "Alvarez",
    "Aguerd", "Cresswell", "Soucek", "Coufal", "Summerville",
  ],
};

// API-Football endpoints per team
const API_FOOTBALL_BASE = "https://v3.football.api-sports.io";

interface Team {
  id: string;
  api_football_id: number;
  display_name: string;
  short_name: string;
}

// Simple XML RSS parser (extracts title, link, description from items)
function parseRSS(xml: string): Array<{ title: string; link: string; description: string }> {
  const items: Array<{ title: string; link: string; description: string }> = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  let match;

  while ((match = itemRegex.exec(xml)) !== null) {
    const itemXml = match[1];
    const title = itemXml.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/)?.[1] ??
      itemXml.match(/<title>(.*?)<\/title>/)?.[1] ?? "";
    const link = itemXml.match(/<link>(.*?)<\/link>/)?.[1] ?? "";
    const desc = itemXml.match(
      /<description><!\[CDATA\[([\s\S]*?)\]\]>|<description>([\s\S]*?)<\/description>/
    )?.[1] ?? itemXml.match(/<description>([\s\S]*?)<\/description>/)?.[1] ?? "";

    items.push({ title, link, description: desc });
  }

  return items;
}

function articleMatchesTeam(
  article: { title: string; description: string },
  team: Team
): boolean {
  const text = `${article.title} ${article.description}`.toLowerCase();
  const teamNames = [
    team.display_name.toLowerCase(),
    team.short_name.toLowerCase(),
    team.id.replace("_", " "),
  ];

  // Check team name match
  if (teamNames.some((name) => text.includes(name))) return true;

  // Check player name match
  const players = TEAM_PLAYERS[team.id] ?? [];
  return players.some((player) => text.toLowerCase().includes(player.toLowerCase()));
}

async function fetchRSSFeeds(team: Team): Promise<Array<{ source: string; data: unknown }>> {
  const results: Array<{ source: string; data: unknown }> = [];

  for (const feed of RSS_FEEDS) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 10_000);

      const response = await fetch(feed.url, { signal: controller.signal });
      clearTimeout(timeout);

      if (!response.ok) {
        console.warn(`RSS ${feed.name} returned ${response.status}`);
        continue;
      }

      const xml = await response.text();
      const articles = parseRSS(xml);

      // Filter articles relevant to this team
      const relevant = articles
        .filter((a) => articleMatchesTeam(a, team))
        .map((a) => ({
          title: sanitizeText(a.title).text,
          link: a.link,
          description: sanitizeText(a.description).text,
        }));

      if (relevant.length > 0) {
        results.push({ source: feed.name, data: relevant });
      }
    } catch (e) {
      // Individual feed failure — log and continue (Runbook Scenario 3)
      console.warn(`RSS ${feed.name} failed:`, e instanceof Error ? e.message : e);
    }
  }

  return results;
}

async function fetchAPIFootball(
  team: Team,
  apiKey: string
): Promise<Array<{ source: string; data: unknown }>> {
  const results: Array<{ source: string; data: unknown }> = [];
  const headers = {
    "x-rapidapi-key": apiKey,
    "x-rapidapi-host": "v3.football.api-sports.io",
  };

  const endpoints = [
    { name: "fixtures_next", path: `/fixtures?team=${team.api_football_id}&next=5` },
    { name: "fixtures_last", path: `/fixtures?team=${team.api_football_id}&last=3` },
    { name: "injuries", path: `/injuries?team=${team.api_football_id}&season=2025` },
    { name: "standings", path: `/standings?league=39&season=2025` },
    { name: "transfers", path: `/transfers?team=${team.api_football_id}` },
    { name: "squad", path: `/players/squads?team=${team.api_football_id}` },
    // Coaches: API-Football's authoritative manager source. Added 2026-05-11
    // after the team-page-generator was caught producing `<UNKNOWN>` for the
    // three promoted teams' MANAGER card — it had no source for the name
    // and (correctly) refused to confabulate. Now feeds Claude with the
    // real current head coach + their career history.
    { name: "coachs", path: `/coachs?team=${team.api_football_id}` },
  ];

  for (const endpoint of endpoints) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 15_000);

      const response = await fetch(`${API_FOOTBALL_BASE}${endpoint.path}`, {
        headers,
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (!response.ok) {
        console.warn(`API-Football ${endpoint.name} returned ${response.status}`);
        continue;
      }

      const data = await response.json();
      results.push({ source: `api_football_${endpoint.name}`, data });
    } catch (e) {
      console.warn(
        `API-Football ${endpoint.name} failed:`,
        e instanceof Error ? e.message : e
      );
    }
  }

  return results;
}

async function computeTeamContext(
  supabase: ReturnType<typeof getSupabaseClient>,
  team: Team,
  standingsData: unknown
): Promise<void> {
  const flags: string[] = [];

  try {
    // deno-lint-ignore no-explicit-any
    const standings = (standingsData as any)?.response?.[0]?.league?.standings?.[0];
    if (!Array.isArray(standings)) return;

    const teamStanding = standings.find(
      // deno-lint-ignore no-explicit-any
      (s: any) => s.team?.id === team.api_football_id
    );
    if (!teamStanding) return;

    const rank = teamStanding.rank;
    const points = teamStanding.points;
    const leaderPoints = standings[0]?.points ?? 0;
    const fourthPoints = standings[3]?.points ?? 0;
    const eighteenthPoints = standings[17]?.points ?? 0;
    const form = teamStanding.form ?? "";

    // title_race: Top 3, within 5 points of leader
    if (rank <= 3 && leaderPoints - points <= 5) flags.push("title_race");

    // cl_spot: 3rd-5th, within 3 points of 4th
    if (rank >= 3 && rank <= 5 && Math.abs(points - fourthPoints) <= 3) {
      flags.push("cl_spot");
    }

    // europa_spot: 5th or 6th place battle
    if (rank === 5 || rank === 6) flags.push("europa_spot");

    // relegation: Bottom 3 or within 3 points of 18th
    if (rank >= 18 || (rank >= 15 && eighteenthPoints - points <= 3)) {
      flags.push("relegation");
    }

    // bad_form: last 5 without a win
    const recentForm = form.slice(-5);
    if (recentForm.length >= 5 && !recentForm.includes("W")) {
      flags.push("bad_form");
    }

    // Update team_context table
    await supabase.from("team_context").upsert({
      team_id: team.id,
      flags,
      updated_at: new Date().toISOString(),
    });
  } catch (e) {
    console.warn("Failed to compute team context:", e);
  }
}

serve(async (req) => {
  const startTime = Date.now();
  const supabase = getSupabaseClient();

  try {
    // Get all teams
    const { data: teams, error: teamError } = await supabase
      .from("teams")
      .select("*");

    if (teamError || !teams) {
      throw new Error(`Failed to fetch teams: ${teamError?.message}`);
    }

    const apiFootballKey = Deno.env.get("API_FOOTBALL_KEY");
    if (!apiFootballKey) {
      throw new Error("Missing API_FOOTBALL_KEY");
    }

    for (const team of teams as Team[]) {
      const teamStart = Date.now();
      const fetchLogIds: string[] = [];

      // Fetch RSS and API-Football in parallel
      const [rssResults, apiResults] = await Promise.all([
        fetchRSSFeeds(team),
        fetchAPIFootball(team, apiFootballKey),
      ]);

      const allResults = [...rssResults, ...apiResults];

      for (const result of allResults) {
        // Store raw data unconditionally — keeps an auditable history of every fetch.
        const { data: insertedLog, error: insertError } = await supabase
          .from("raw_fetch_logs")
          .insert({
            team_id: team.id,
            source: result.source,
            data: result.data,
          })
          .select("id")
          .single();

        if (insertError) {
          console.warn(`Failed to insert log for ${team.id}/${result.source}:`, insertError.message);
          continue;
        }

        fetchLogIds.push(insertedLog.id);
      }

      // Compute team context from standings data
      const standingsResult = apiResults.find((r) =>
        r.source === "api_football_standings"
      );
      if (standingsResult) {
        await computeTeamContext(supabase, team, standingsResult.data);
      }

      // Edge-function content-generator trigger is gated on CONTENT_GENERATOR_ENABLED.
      // The Claude Code Routine pipeline is now primary (writes pipeline_source='routine'
      // every 6h). To prevent duplicate items in the user feed, we don't fire the
      // edge-function content path by default. data-fetcher still runs to populate
      // raw_fetch_logs (used by other functions, and as a fallback if the Routine
      // ever needs to read from DB-cached RSS).
      //
      // To re-enable as a fallback, set CONTENT_GENERATOR_ENABLED=true in Supabase secrets.
      const contentGenEnabled = Deno.env.get("CONTENT_GENERATOR_ENABLED") === "true";
      if (contentGenEnabled && fetchLogIds.length > 0) {
        try {
          await triggerFunction("content-generator", {
            team_id: team.id,
            fetch_log_ids: fetchLogIds,
            trigger: "new_data",
          });
        } catch (e) {
          console.error(`Failed to trigger content-generator for ${team.id}:`, e);
        }
      }

      // If standings or fixtures data changed, update team page dynamic fields
      // (league position, form, next fixture — no Claude call needed)
      const hasStandings = apiResults.some((r) => r.source === "api_football_standings");
      const hasFixtures = apiResults.some(
        (r) => r.source === "api_football_fixtures_next" || r.source === "api_football_fixtures_last"
      );
      if (hasStandings || hasFixtures) {
        try {
          await triggerFunction("team-page-generator", {
            mode: "dynamic_only",
            team_id: team.id,
          });
        } catch (e) {
          console.error(`Failed to trigger team-page-generator (dynamic) for ${team.id}:`, e);
        }
      }

      await logPipelineEvent(supabase, {
        team_id: team.id,
        stage: "fetch",
        status: allResults.length > 0 ? "success" : "failure",
        duration_ms: Date.now() - teamStart,
        message: `Fetched ${allResults.length} sources, ${fetchLogIds.length} logs stored`,
        content_item_id: null,
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("data-fetcher error:", message);

    await logPipelineEvent(supabase, {
      team_id: "unknown",
      stage: "fetch",
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
