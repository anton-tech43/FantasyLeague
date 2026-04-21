// Shared source-data summarizer used by content-generator AND content-reviewer.
// Extracts clean, citable facts from raw_fetch_logs (RSS + API-Football).
// Both functions MUST see the same summary so the reviewer can verify the
// generator's claims against the same source material.

import { sanitizeText } from "./input-sanitizer.ts";

export interface RawFetchLog {
  source: string;
  // deno-lint-ignore no-explicit-any
  data: any;
}

/**
 * Extract a clean, one-liner summary from a single API-Football endpoint response.
 * Returns "" if nothing useful. Skips metadata, logos, pagination.
 */
// deno-lint-ignore no-explicit-any
export function summarizeAPIFootball(source: string, raw: any, teamApiId?: number): string {
  const resp = raw?.response;
  if (!resp) return "";
  const kind = source.replace(/^api_football_/, "");

  try {
    switch (kind) {
      case "fixtures_next": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.slice(0, 3).map((f) => {
          const home = f.teams?.home?.name ?? "?";
          const away = f.teams?.away?.name ?? "?";
          const date = f.fixture?.date ?? "";
          const venue = f.fixture?.venue?.name ?? "";
          return `  ${home} vs ${away} — ${date.slice(0, 16)} at ${venue}`;
        });
        return `UPCOMING FIXTURES:\n${lines.join("\n")}`;
      }
      case "fixtures_last": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.slice(0, 3).map((f) => {
          const home = f.teams?.home?.name ?? "?";
          const away = f.teams?.away?.name ?? "?";
          const hg = f.goals?.home ?? "?";
          const ag = f.goals?.away ?? "?";
          const date = (f.fixture?.date ?? "").slice(0, 10);
          const status = f.fixture?.status?.short ?? "";
          return `  ${date}: ${home} ${hg}-${ag} ${away} (${status})`;
        });
        return `RECENT RESULTS:\n${lines.join("\n")}`;
      }
      case "fixtures_events": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.slice(0, 20).map((e) => {
          const min = e.time?.elapsed ?? "?";
          const team = e.team?.name ?? "?";
          const player = e.player?.name ?? "?";
          const type = e.type ?? "";
          const detail = e.detail ?? "";
          const assist = e.assist?.name ? ` (assist: ${e.assist.name})` : "";
          return `  ${min}' ${team} — ${player}: ${type} ${detail}${assist}`;
        });
        return `LAST MATCH EVENTS:\n${lines.join("\n")}`;
      }
      case "fixtures_statistics": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.map((t) => {
          const team = t.team?.name ?? "?";
          const keyStats = (t.statistics ?? [])
            .filter((s: { type: string }) =>
              ["Ball Possession", "Total Shots", "Shots on Goal", "Corner Kicks", "Fouls", "Yellow Cards", "Red Cards"].includes(s.type)
            )
            .map((s: { type: string; value: unknown }) => `${s.type}: ${s.value}`)
            .join(", ");
          return `  ${team} — ${keyStats}`;
        });
        return `LAST MATCH STATS:\n${lines.join("\n")}`;
      }
      case "fixtures_lineups": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.map((t) => {
          const team = t.team?.name ?? "?";
          const formation = t.formation ?? "?";
          const coach = t.coach?.name ?? "?";
          const starters = (t.startXI ?? [])
            .map((p: { player?: { name?: string } }) => p.player?.name)
            .filter(Boolean)
            .join(", ");
          return `  ${team} (${coach}, ${formation}): ${starters}`;
        });
        return `LAST MATCH LINEUPS:\n${lines.join("\n")}`;
      }
      case "fixtures_headtohead": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.slice(0, 5).map((f) => {
          const home = f.teams?.home?.name ?? "?";
          const away = f.teams?.away?.name ?? "?";
          const hg = f.goals?.home ?? "?";
          const ag = f.goals?.away ?? "?";
          const date = (f.fixture?.date ?? "").slice(0, 10);
          return `  ${date}: ${home} ${hg}-${ag} ${away}`;
        });
        return `HEAD-TO-HEAD (last 5 vs next opponent):\n${lines.join("\n")}`;
      }
      case "standings": {
        const table = resp?.[0]?.league?.standings?.[0];
        if (!Array.isArray(table)) return "";
        const lines = table.slice(0, 8).map((s: { rank: number; team: { name: string }; points: number; form?: string }) => {
          const form = s.form ? ` form=${s.form}` : "";
          return `  #${s.rank} ${s.team?.name}: ${s.points}pts${form}`;
        });
        return `LEAGUE TABLE (top 8):\n${lines.join("\n")}`;
      }
      case "injuries": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        // For the main team, prioritise their own players
        const teamInjuries = teamApiId
          ? resp.filter((i) => i.team?.id === teamApiId)
          : resp;
        const lines = (teamInjuries.length ? teamInjuries : resp).slice(0, 10).map((i) => {
          const name = i.player?.name ?? "?";
          const reason = i.player?.reason ?? "unknown";
          const type = i.player?.type ?? "";
          return `  ${name}: ${reason} (${type})`;
        });
        return `INJURIES:\n${lines.join("\n")}`;
      }
      case "teams_statistics": {
        const s = resp;
        if (!s) return "";
        const fx = s.fixtures;
        const g = s.goals;
        const cs = s.clean_sheet?.total;
        const form = s.form ? s.form.slice(-10) : "";
        return `SEASON STATS: P${fx?.played?.total} W${fx?.wins?.total} D${fx?.draws?.total} L${fx?.loses?.total}, GF${g?.for?.total?.total} GA${g?.against?.total?.total}, clean sheets: ${cs}, form(last 10): ${form}`;
      }
      case "coachs": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const current = resp[0];
        const name = current?.name ?? "?";
        const age = current?.age ?? "?";
        const nationality = current?.nationality ?? "";
        const careerThisTeam = (current?.career ?? []).find(
          (c: { team?: { id?: number } }) => c.team?.id
        );
        const startDate = careerThisTeam?.start ?? "";
        return `MANAGER: ${name} (${nationality}, age ${age}), since ${startDate}`;
      }
      case "predictions": {
        const p = resp?.[0]?.predictions;
        if (!p) return "";
        const advice = p.advice ?? "";
        const percent = p.percent ? `home ${p.percent.home}, draw ${p.percent.draw}, away ${p.percent.away}` : "";
        const winner = p.winner?.name ?? "";
        return `NEXT MATCH PREDICTION: ${winner ? `favored: ${winner}. ` : ""}${percent}. ${advice}`;
      }
      case "topscorers": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.slice(0, 8).map((p) => {
          const name = p.player?.name ?? "?";
          const team = p.statistics?.[0]?.team?.name ?? "?";
          const goals = p.statistics?.[0]?.goals?.total ?? 0;
          return `  ${name} (${team}): ${goals} goals`;
        });
        return `LEAGUE TOP SCORERS:\n${lines.join("\n")}`;
      }
      case "topassists": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const lines = resp.slice(0, 5).map((p) => {
          const name = p.player?.name ?? "?";
          const team = p.statistics?.[0]?.team?.name ?? "?";
          const assists = p.statistics?.[0]?.goals?.assists ?? 0;
          return `  ${name} (${team}): ${assists} assists`;
        });
        return `LEAGUE TOP ASSISTS:\n${lines.join("\n")}`;
      }
      case "transfers": {
        if (!Array.isArray(resp) || resp.length === 0) return "";
        const sixMonthsAgo = new Date(Date.now() - 180 * 24 * 60 * 60 * 1000);
        const recent: string[] = [];
        for (const p of resp.slice(0, 20)) {
          for (const t of p.transfers ?? []) {
            const date = new Date(t.date ?? 0);
            if (date > sixMonthsAgo) {
              const name = p.player?.name ?? "?";
              const from = t.teams?.out?.name ?? "?";
              const to = t.teams?.in?.name ?? "?";
              recent.push(`  ${t.date}: ${name} ${from} → ${to}`);
              if (recent.length >= 8) break;
            }
          }
          if (recent.length >= 8) break;
        }
        return recent.length ? `RECENT TRANSFERS (last 6mo):\n${recent.join("\n")}` : "";
      }
      case "squad":
        return ""; // too large, not useful as news input
      default:
        return "";
    }
  } catch (e) {
    console.warn(`summarizeAPIFootball failed for ${source}:`, e instanceof Error ? e.message : e);
    return "";
  }
}

/**
 * Build a combined RSS + API-Football summary from a batch of raw_fetch_logs.
 * Both generator and reviewer use this to see the SAME source data.
 */
export function buildSourceSummary(logs: RawFetchLog[], teamApiId?: number): {
  articles: string;
  stats: string;
} {
  let articles = "";
  let stats = "";

  for (const log of logs) {
    const src = log.source ?? "";
    if (src.startsWith("api_football_")) {
      const summary = summarizeAPIFootball(src, log.data, teamApiId);
      if (summary) stats += `\n${summary}`;
    } else {
      const items = Array.isArray(log.data) ? log.data : [log.data];
      for (const article of items) {
        if (!article) continue;
        const sanitized = sanitizeText(`${article.title ?? ""}: ${article.description ?? ""}`);
        articles += `\n- [${src}] ${sanitized.text}`;
      }
    }
  }

  return { articles, stats };
}
