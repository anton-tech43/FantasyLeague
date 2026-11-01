// _shared/pipeline-logger.ts
// Goal Digger — Logs pipeline events to pipeline_health table

import { SupabaseClient } from "npm:@supabase/supabase-js@2.117.0";
import { PipelineHealthLog } from "./types.ts";

export async function logPipelineEvent(
  supabase: SupabaseClient,
  event: PipelineHealthLog
): Promise<void> {
  const { error } = await supabase.from("pipeline_health").insert(event);
  if (error) {
    console.error("Failed to log pipeline event:", error.message);
  }
}

/// One fan-out of pushes as one pipeline_health row, without the stage and
/// target: "<n> sent, <m> failed of <t>" (the digest reads the "sent"
/// count), the first failure's HTTP status, and every failure reason counted.
/// Shared by the Live Activity sends and the matchday reminder.
export function fanOutRow(label: string, results: Array<{ success: boolean; status?: number; reason?: string }>) {
  const ok = results.filter((r) => r.success).length;
  const failed = results.length - ok;
  const reasons: Record<string, number> = {};
  for (const r of results) {
    if (r.success) continue;
    const k = `${r.status ?? "?"} ${r.reason ?? ""}`.trim();
    reasons[k] = (reasons[k] ?? 0) + 1;
  }
  return {
    status: results.length === 0 ? "skipped" : failed === 0 ? "success" : ok === 0 ? "failure" : "partial",
    http_status: results.find((r) => !r.success)?.status ?? null,
    response_excerpt: failed > 0 ? JSON.stringify(reasons).slice(0, 200) : null,
    error_class: failed === 0 ? "success" : "apns_error",
    message: `${label}: ${ok} sent, ${failed} failed of ${results.length}`,
  } as const;
}
