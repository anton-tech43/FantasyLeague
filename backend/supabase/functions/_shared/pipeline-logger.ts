// _shared/pipeline-logger.ts
// Goal Digger — Logs pipeline events to pipeline_health table

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
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
