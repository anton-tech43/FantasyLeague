// data-fetcher/index.ts
// Goal Digger — Fetches RSS feeds + API-Football data, stores in raw_fetch_logs
// Schedule: Every 30 min, 08:00-23:00 GMT via pg_cron

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { logPipelineEvent } from "../_shared/pipeline-logger.ts";
import { triggerFunction } from "../_shared/trigger.ts";
import { sanitizeText, wrapExternalData } from "../_shared/input-sanitizer.ts";
import { seasonForLeague } from "../_shared/league-helpers.ts";
import {
  type FetchOnlyKey,
  type FetchScope,
  parseFetchScope,
  StandingsCache,
  wants,
} from "../_shared/fetch-scope.ts";
import {
  isPlayerStatsDue,
  mergePlayerStatPages,
  pagesToFetch,
  PLAYER_STATS_SOURCE,
  type PlayerStatsPage,
} from "../_shared/player-stats.ts";

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
  /// 'club' | 'country' | 'tournament'. A tournament has no squad, so it takes
  /// the league-level fetch branch instead of the team-scoped endpoints.
  entity_type?: string;
  /// API-Football league id. Null only for entities we deliberately skip.
  league_id?: number | null;
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

/** How many API-Football requests this run actually put on the wire. */
interface RunCounters {
  apiCalls: number;
}

async function fetchAPIFootball(
  team: Team,
  apiKey: string,
  scope: FetchScope,
  standings: StandingsCache,
  counters: RunCounters,
): Promise<Array<{ source: string; data: unknown }>> {
  const results: Array<{ source: string; data: unknown }> = [];
  const headers = {
    "x-rapidapi-key": apiKey,
    "x-rapidapi-host": "v3.football.api-sports.io",
  };

  /** One GET, with the run's call counter and a timeout. null on any failure. */
  const get = async (path: string, label: string): Promise<unknown | null> => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15_000);
    counters.apiCalls++;
    try {
      const response = await fetch(`${API_FOOTBALL_BASE}${path}`, {
        headers,
        signal: controller.signal,
      });
      if (!response.ok) {
        console.warn(`API-Football ${label} returned ${response.status}`);
        return null;
      }
      return await response.json();
    } catch (e) {
      console.warn(`API-Football ${label} failed:`, e instanceof Error ? e.message : e);
      return null;
    } finally {
      clearTimeout(timeout);
    }
  };

  /**
   * The league table, bought once per (league, season) per run and shared.
   * Every entity still gets its own raw_fetch_logs row from this payload —
   * the dedupe is invisible to every consumer downstream.
   */
  const getStandings = (leagueId: number, season: number) =>
    standings.get(
      leagueId,
      season,
      () => get(`/standings?league=${leagueId}&season=${season}`, "standings"),
    );

  // V2.0: parameterise league_id + season per team.
  // PL teams (league_id=39) use season=2025 (the 2025-26 season).
  // WC countries (league_id=1) use season=2026 (the 2026 tournament).
  // Any new league added in future just slots into seasonForLeague().
  //
  // Skip teams with no league_id — pre-V2.0 there was a `?? 39` fallback
  // that silently fetched PL data for any country that lost its league_id.
  // Better to fail loud + log so any future regression is observable.
  // A tournament entity (champions_league) is a competition, not a squad, so
  // the team-scoped endpoints are meaningless for it — `?team=2` would ask for
  // the club whose id happens to be 2. It gets the league-level view instead:
  // the table, what is coming, and what just happened. That is the data the
  // tournament content routine reads, and it is the only way the app can say
  // "Real Madrid went out on Tuesday" for a competition our clubs may not even
  // be in any more.
  if (team.entity_type === "tournament") {
    const tLeague = team.api_football_id; // for a tournament this IS the league id
    const tSeason = seasonForLeague(tLeague);
    // A knockout cup has no table, and asking for one logs an empty response
    // every two hours. A knockout ROUND, on the other hand, is played in a
    // single evening — the League Cup last 32 is sixteen ties — so 20 fixtures
    // does not reach the end of it.
    const isKnockoutCup = tLeague === 48 || tLeague === 45;
    const window = isKnockoutCup ? 40 : 20;

    if (!isKnockoutCup && wants(scope, "standings")) {
      const table = await getStandings(tLeague, tSeason);
      if (table !== null) results.push({ source: "api_football_standings", data: table });
    }
    if (wants(scope, "fixtures")) {
      for (const ep of [
        { name: "fixtures_next", path: `/fixtures?league=${tLeague}&season=${tSeason}&next=${window}` },
        { name: "fixtures_last", path: `/fixtures?league=${tLeague}&season=${tSeason}&last=${window}` },
      ]) {
        const json = await get(ep.path, `${team.id} ${ep.name}`);
        if (json !== null) results.push({ source: `api_football_${ep.name}`, data: json });
      }
    }
    return results;
  }

  if (!team.league_id) {
    console.warn(`data-fetcher: skipping ${team.id} — no league_id`);
    return results;
  }
  const leagueId = team.league_id;
  const season = seasonForLeague(leagueId);

  // Each endpoint carries the scope key that buys it, so a narrow full-time
  // refresh (`only: ["standings","fixtures"]`) skips squad, transfers, injuries
  // and coachs without a second list to keep in step.
  const endpoints: Array<{ name: string; path: string; scope: FetchOnlyKey }> = [
    // next=10 — gives team-season-state-generator enough fixtures to populate
    // the `next_fixtures` array consumed by the onboarding CalendarOptInView
    // (one-tap calendar sync). Pre-V1.2 this was next=5.
    { name: "fixtures_next", path: `/fixtures?team=${team.api_football_id}&next=10`, scope: "fixtures" },
    { name: "fixtures_last", path: `/fixtures?team=${team.api_football_id}&last=3`, scope: "fixtures" },
    { name: "injuries", path: `/injuries?team=${team.api_football_id}&season=${season}`, scope: "injuries" },
    { name: "transfers", path: `/transfers?team=${team.api_football_id}`, scope: "transfers" },
    { name: "squad", path: `/players/squads?team=${team.api_football_id}`, scope: "squad" },
    // Coaches: API-Football's authoritative manager source. Added 2026-05-11
    // after the team-page-generator was caught producing `<UNKNOWN>` for the
    // three promoted teams' MANAGER card — it had no source for the name
    // and (correctly) refused to confabulate. Now feeds Claude with the
    // real current head coach + their career history.
    { name: "coachs", path: `/coachs?team=${team.api_football_id}`, scope: "coachs" },
  ];

  // Standings first, and through the cache: twenty PL clubs, one table.
  if (wants(scope, "standings")) {
    const table = await getStandings(leagueId, season);
    if (table !== null) results.push({ source: "api_football_standings", data: table });
  }

  for (const endpoint of endpoints) {
    if (!wants(scope, endpoint.scope)) continue;
    const data = await get(endpoint.path, endpoint.name);
    if (data !== null) results.push({ source: `api_football_${endpoint.name}`, data });
  }

  return results;
}

/**
 * Per-player season stats for one club: appearances and minutes, which are the
 * only measure we have of who actually plays. Feeds `players.minutes` via
 * sync_player_stats_from_raw() (mig 095), which is what picks the starting XI
 * for the Quiz's squad pack and the dossier routine.
 *
 * Two pages a club, once a day (see _shared/player-stats.ts for the gate and
 * why the pages are merged into one row).
 */
async function fetchPlayerStats(
  team: Team,
  apiKey: string,
  season: number,
  counters: RunCounters,
): Promise<Array<{ source: string; data: unknown }>> {
  const headers = {
    "x-rapidapi-key": apiKey,
    "x-rapidapi-host": "v3.football.api-sports.io",
  };

  const getPage = async (page: number): Promise<PlayerStatsPage | null> => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15_000);
    counters.apiCalls++;
    try {
      const url =
        `${API_FOOTBALL_BASE}/players?team=${team.api_football_id}&season=${season}&page=${page}`;
      const response = await fetch(url, { headers, signal: controller.signal });
      if (!response.ok) {
        console.warn(`API-Football players page ${page} returned ${response.status}`);
        return null;
      }
      return await response.json() as PlayerStatsPage;
    } catch (e) {
      console.warn(
        `API-Football players page ${page} failed:`,
        e instanceof Error ? e.message : e,
      );
      return null;
    } finally {
      clearTimeout(timeout);
    }
  };

  const first = await getPage(1);
  if (!first) return [];

  const pages: PlayerStatsPage[] = [first];
  for (let page = 2; page <= pagesToFetch(first); page++) {
    const next = await getPage(page);
    if (!next) break; // partial beats nothing; tomorrow's run refetches
    pages.push(next);
  }

  const merged = mergePlayerStatPages(pages);
  if (merged.results === 0) return [];
  return [{ source: PLAYER_STATS_SOURCE, data: merged }];
}

/** Newest stored stats fetch for a club, or null. Drives the once-a-day gate. */
async function lastPlayerStatsFetch(
  supabase: ReturnType<typeof getSupabaseClient>,
  teamId: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("raw_fetch_logs")
    .select("fetched_at")
    .eq("team_id", teamId)
    .eq("source", PLAYER_STATS_SOURCE)
    .order("fetched_at", { ascending: false })
    .limit(1);

  if (error) {
    // Can't tell how old it is → don't fetch. A missed day costs nothing; a
    // failing query that reads as "never fetched" costs 40 calls every 2 hours.
    console.warn(`player stats gate query failed for ${teamId}:`, error.message);
    return new Date().toISOString();
  }
  return data?.[0]?.fetched_at ?? null;
}

async function computeTeamContext(
  supabase: ReturnType<typeof getSupabaseClient>,
  team: Team,
  standingsData: unknown
): Promise<void> {
  // Concepts below — title_race, cl_spot, relegation — are PL-league-table
  // semantics. WC group stage standings have 4 teams per group and a
  // completely different shape (group_position, advancing_to_knockouts,
  // eliminated). Skip for countries; team-season-state-generator handles
  // their context separately.
  if (team.entity_type === "country") return;

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
  // Caller-auth gate (see _shared/require-service-auth.ts). Server-only
  // function — rejects anon-key / no-auth callers; accepts the service
  // key that triggerFunction + pg_cron present.
  const denied = requireServiceAuth(req);
  if (denied) return denied;
  const startTime = Date.now();
  const supabase = getSupabaseClient();

  try {
    // Optional scope. Lets us fan out per-team in parallel from the outside
    // (curl × N concurrent invocations) when the 60-second Edge Function CPU
    // cap stops the full-batch run from completing, and lets match-watcher ask
    // for the cheap full-time refresh: the two clubs that just played, their
    // table and their fixtures, nothing else. Empty body = today's behaviour.
    let rawBody: unknown = null;
    try {
      rawBody = await req.json();
    } catch {
      /* no body or invalid JSON — proceed in all-teams mode */
    }

    const parsed = parseFetchScope(rawBody);
    if (!parsed.ok) {
      return new Response(JSON.stringify({ error: parsed.error }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    const scope = parsed.scope;

    // Get teams. is_active=false excludes relegated clubs (mig 074) so we don't
    // burn RSS/API-Football fetches on clubs no longer in the league. An explicit
    // team_ids override still works (e.g. a one-off for a specific club, or a
    // cup opponent that is deliberately inactive).
    let query = supabase.from("teams").select("*");
    if (scope.teamIds) {
      query = query.in("id", scope.teamIds);
    } else {
      query = query.eq("is_active", true);
    }
    const { data: teams, error: teamError } = await query;

    if (teamError || !teams) {
      throw new Error(`Failed to fetch teams: ${teamError?.message}`);
    }

    // The id whitelist is the `teams` table itself — a caller naming something
    // that isn't an entity has a bug, and silently fetching the subset that did
    // resolve would hide it. 400 with the names, so the caller can see which.
    if (scope.teamIds) {
      const found = new Set((teams as Team[]).map((t) => t.id));
      const unknown = scope.teamIds.filter((id) => !found.has(id));
      if (unknown.length > 0) {
        return new Response(
          JSON.stringify({ error: `unknown team ids: ${unknown.join(", ")}` }),
          { status: 400, headers: { "Content-Type": "application/json" } },
        );
      }
    }

    // One league table per run, shared across every entity in that league.
    const standingsCache = new StandingsCache();
    const counters: RunCounters = { apiCalls: 0 };
    let logsWritten = 0;

    const apiFootballKey = Deno.env.get("API_FOOTBALL_KEY");
    if (!apiFootballKey) {
      throw new Error("Missing API_FOOTBALL_KEY");
    }

    for (const team of teams as Team[]) {
      const teamStart = Date.now();
      const fetchLogIds: string[] = [];

      // Per-player minutes: clubs only (the `players` table is the PL squads),
      // and only when today's fetch has not landed yet. ~40 calls a day rather
      // than 360 — see _shared/player-stats.ts.
      const wantsPlayerStats = wants(scope, "player_stats") &&
        team.entity_type !== "country" &&
        team.entity_type !== "tournament" &&
        !!team.league_id &&
        isPlayerStatsDue(await lastPlayerStatsFetch(supabase, team.id));

      // Fetch RSS and API-Football in parallel
      const [rssResults, apiResults, statsResults] = await Promise.all([
        wants(scope, "rss") ? fetchRSSFeeds(team) : Promise.resolve([]),
        fetchAPIFootball(team, apiFootballKey, scope, standingsCache, counters),
        wantsPlayerStats
          ? fetchPlayerStats(team, apiFootballKey, seasonForLeague(team.league_id!), counters)
          : Promise.resolve([]),
      ]);

      const allResults = [...rssResults, ...apiResults, ...statsResults];

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
        logsWritten++;
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

    // `standings_calls_saved` is the whole point of the cache and the budget
    // line that pays for the full-time refreshes: what the run WOULD have spent
    // is api_calls + standings_calls_saved.
    const summary = {
      success: true,
      teams: teams.length,
      scope: {
        team_ids: scope.teamIds,
        only: scope.only,
      },
      api_calls: counters.apiCalls,
      logs_written: logsWritten,
      standings_calls: standingsCache.calls,
      standings_calls_saved: standingsCache.saved,
      duration_ms: Date.now() - startTime,
    };
    console.log("data-fetcher run:", JSON.stringify(summary));

    return new Response(JSON.stringify(summary), {
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
