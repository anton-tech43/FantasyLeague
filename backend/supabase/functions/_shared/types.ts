// _shared/types.ts
// Goal Digger — Shared TypeScript type definitions for all Edge Functions

export interface ContentItem {
  id: string;
  team_id: string;
  type: "news" | "matchday";
  headline: string;
  body: string;
  talking_points: string[] | MatchdayTalkingPoints;
  kickoff_time: string | null;
  emotional_context:
    | "exciting"
    | "bad_news"
    | "drama"
    | "informational"
    | "funny"
    | null;
  status: "draft" | "approved" | "rejected" | "published";
  review_notes: ReviewNote[];
  source_urls: string[];
  match_id: string | null;
  created_at: string;
  published_at: string | null;

  // Everyone's talking about — cross-team feed
  everyone_talking: boolean;
  everyone_talking_headline: string | null;
  everyone_talking_body: string | null;
  everyone_talking_talking_points: string[] | null;
  worth_knowing: boolean;

  // Immersive card fields
  immersive_headline: string | null;
  immersive_context: string | null;
  immersive_context_fallback: string | null;

  // Analogy review pipeline
  analogy_reviewed: boolean;
  analogy_approved: boolean;
  analogy_auto_published: boolean;
  analogy_critic_score: AnalogyScore | null;
}

export interface AnalogyScore {
  naturalness: number;
  relevance: number;
  audience_fit: number;
  cringe_risk: number;
  total: number;
  verdict: "approve" | "reject";
  reason: string;
}

export interface MatchdayTalkingPoints {
  regular: string[];
  post_match: {
    if_they_win: string;
    if_they_lose: string;
    bold_prediction: string;
  };
  metadata: {
    pre_match_mood: "confident" | "nervous" | "excited" | "meh";
    rivalry_level: "derby" | "big_game" | "normal" | "dead_rubber";
  };
}

export interface ReviewNote {
  bot: "tone" | "accuracy" | "brevity" | "safety";
  pass: boolean;
  confidence: number;
  notes: string;
  reviewed_at: string;
}

export interface PipelineHealthLog {
  // team_id is now optional for system-level rows (cron_invoke heartbeat,
  // global SLA checks). Set when the event is per-team.
  team_id?: string | null;
  stage:
    | "fetch"
    | "generate"
    | "review"
    | "safety_review"
    | "publish"
    | "live_brief_fire"   // match-watcher firing gd-live-brief via routine API
    | "matchday_fire"     // match-watcher firing gd-matchday via routine API
    | "apns_send"         // notification-sender sending a single APNs push
    | "routine_post"      // routine post_*.sh POSTing to Supabase REST
    | "cron_invoke";      // pg_cron invoking an Edge Function
  // 'partial' for aggregated hop results where some children succeeded and
  // others failed (e.g., notification-sender batching to multiple tokens).
  status: "success" | "failure" | "skipped" | "partial";
  duration_ms?: number;
  message?: string | null;
  content_item_id?: string | null;
  // V2.x observability columns added by migration 038. All optional.
  target?: string | null;
  http_status?: number | null;
  response_excerpt?: string | null;
  error_class?: string | null;
}

export interface TriggerPayload {
  team_id: string;
  trigger: "new_data" | "matchday" | "review_complete" | "approved";
  content_item_id?: string;
  fetch_log_ids?: string[];
  fixture_id?: string;
  kickoff_time?: string;
  opponent?: string;
}

export interface SpamCheckResult {
  canSend: boolean;
  reason?: string;
}

export interface Team {
  id: string;
  display_name: string;
  api_football_id: number;
  short_name: string;
  /// 'club' for Premier League sides, 'country' for World Cup national
  /// teams. Added in migration 032. Defaults to 'club' for back-compat.
  entity_type?: "club" | "country";
  /// API-Football league_id: 39 = Premier League, 1 = FIFA World Cup.
  /// Added in migration 032 to drive per-league data fetches without
  /// hardcoded constants in Edge Functions.
  league_id?: number;
}

export interface DeviceToken {
  id: string;
  team_id: string;
  apns_token: string;
  is_active: boolean;
  tier: number;
  created_at: string;
  updated_at: string;
}

export interface ReviewBotResult {
  pass: boolean;
  confidence: number;
  notes: string;
  [key: string]: unknown;
}

export interface TeamContext {
  team_id: string;
  flags: string[];
  updated_at: string;
}
