// content-audit/index.ts
//
// Deterministic news/push auditor. Cross-checks every recent content_item
// against the ACTUAL league table and logs any claim that contradicts the
// standings to pipeline_health (stage='content_audit'). NO Claude calls,
// NO API-Football calls, NO pushes — pure read + integer comparison, so
// it costs nothing to run and can't itself fabricate.
//
// Catches the class of bug behind the 2026-05-31 West Ham brief
// ("stayed up" while 18th = relegated). See _shared/audit-claims.ts.
//
// Call: POST /functions/v1/content-audit  (service-role / cron key)
//   body: { "days": 30, "dryRun": false }   (both optional)
// Returns: { audited, findings: [...] }
//
// This function NEVER mutates content_items and NEVER sends a push. It
// only writes observability rows. Correcting a flagged item (silently in
// the feed, or with a correction push) stays a human decision for now.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import {
  auditContentClaims,
  itemAuditText,
  type RankInfo,
} from "../_shared/audit-claims.ts";

const PL_LEAGUE_ID = 39;

interface StandingsRow {
  rank: number;
  team: { id: number; name: string };
}

serve(async (req) => {
  const denied = requireServiceAuth(req);
  if (denied) return denied;

  let days = 30;
  let dryRun = false;
  try {
    const body = await req.json();
    if (typeof body?.days === "number" && body.days > 0) days = body.days;
    if (body?.dryRun === true) dryRun = true;
  } catch {
    // empty/invalid body — defaults are fine
  }

  const supabase = getSupabaseClient();

  // 1. Build slug -> rank from the latest PL standings snapshot. Every
  //    PL team's snapshot carries the full 20-team table; read one.
  const { data: plTeams } = await supabase
    .from("teams")
    .select("id, api_football_id")
    .eq("league_id", PL_LEAGUE_ID)
    .eq("is_active", true);

  const plSlugs = (plTeams ?? []).map((t) => t.id as string);
  const apiIdToSlug = new Map<number, string>();
  for (const t of plTeams ?? []) {
    const apiId = (t as { api_football_id: number }).api_football_id;
    if (apiId) apiIdToSlug.set(apiId, (t as { id: string }).id);
  }

  const { data: log } = await supabase
    .from("raw_fetch_logs")
    .select("data, fetched_at, team_id")
    .eq("source", "api_football_standings")
    .in("team_id", plSlugs)
    .order("fetched_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!log?.data) {
    return jsonResponse({ error: "no PL standings snapshot found" }, 200);
  }

  const data = log.data as Record<string, unknown>;
  const response = (data.response as Array<Record<string, unknown>> | undefined) ?? [];
  const leagueBlock = response[0]?.league as Record<string, unknown> | undefined;
  const standings = leagueBlock?.standings as StandingsRow[][] | undefined;
  const table = standings?.[0];
  if (!Array.isArray(table) || table.length === 0) {
    return jsonResponse({ error: "PL standings array empty" }, 200);
  }

  const totalTeams = table.length;
  const rankBySlug = new Map<string, number>();
  for (const row of table) {
    const slug = apiIdToSlug.get(row.team?.id);
    if (slug && typeof row.rank === "number") rankBySlug.set(slug, row.rank);
  }

  // 2. Pull recent content for PL teams.
  const sinceIso = new Date(Date.now() - days * 86_400_000).toISOString();
  const { data: items } = await supabase
    .from("content_items")
    .select(
      "id, team_id, type, headline, body, push_title, push_text, " +
        "immersive_headline, immersive_context, everyone_talking_headline, " +
        "everyone_talking_body, pushed_at, created_at",
    )
    .in("team_id", plSlugs)
    .gte("created_at", sinceIso)
    .order("created_at", { ascending: false });

  // 3. Audit each item.
  const findings: Array<Record<string, unknown>> = [];
  for (const item of items ?? []) {
    const rank = rankBySlug.get(item.team_id as string);
    if (rank === undefined) continue;
    const info: RankInfo = {
      teamId: item.team_id as string,
      rank,
      totalTeams,
      leagueId: PL_LEAGUE_ID,
    };
    const itemFindings = auditContentClaims(itemAuditText(item), info);
    for (const f of itemFindings) {
      findings.push({
        content_item_id: item.id,
        team_id: item.team_id,
        type: item.type,
        pushed: item.pushed_at !== null,
        created_at: item.created_at,
        ...f,
      });
    }
  }

  // 4. Log to pipeline_health (unless dry run).
  if (!dryRun) {
    const rows = findings.map((f) => ({
      stage: "content_audit",
      status: f.severity === "contradiction" ? "failure" : "partial",
      team_id: f.team_id,
      content_item_id: f.content_item_id,
      error_class: f.code,
      message: `${f.detail} [claim: "${f.claim}"]`,
    }));
    // Always log a run summary so a clean sweep is observable too.
    rows.push({
      stage: "content_audit",
      status: "success",
      team_id: null as unknown as string,
      content_item_id: null as unknown as string,
      error_class: null as unknown as string,
      message:
        `Audited ${items?.length ?? 0} PL items over ${days}d: ` +
        `${findings.filter((f) => f.severity === "contradiction").length} contradictions, ` +
        `${findings.filter((f) => f.severity === "warning").length} warnings.`,
    });
    if (rows.length > 0) await supabase.from("pipeline_health").insert(rows);
  }

  return jsonResponse({
    audited: items?.length ?? 0,
    days,
    dryRun,
    contradictions: findings.filter((f) => f.severity === "contradiction").length,
    warnings: findings.filter((f) => f.severity === "warning").length,
    findings,
  });
});

function jsonResponse(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj, null, 2), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
