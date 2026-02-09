// Goal Digger — Shared Type Definitions
// Used by all Edge Functions for type safety.

export interface Team {
  id: string;
  display_name: string;
  api_football_id: number;
  short_name: string;
  created_at: string;
}

export interface ContentItem {
  id: string;
  team_id: string;
  type: "news" | "matchday";
  headline: string;
  body: string;
  talking_points: string[];
  source_urls: string[];
  match_id: string | null;
  kickoff_time: string | null;
  emotional_context: "exciting" | "bad_news" | "drama" | "informational" | "funny" | null;
  status: "draft" | "approved" | "rejected" | "published";
  review_notes: ReviewNote[];
  created_at: string;
  published_at: string | null;
}

export interface DeviceToken {
  id: string;
  team_id: string;
  apns_token: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface RawFetchLog {
  id: string;
  team_id: string;
  source: string;
  data: Record<string, unknown>;
  fetched_at: string;
}

export interface PipelineHealth {
  id: string;
  team_id: string;
  stage: "fetch" | "generate" | "review" | "publish";
  status: "success" | "failure" | "skipped";
  duration_ms: number;
  message: string | null;
  content_item_id: string | null;
  created_at: string;
}

export interface ReviewNote {
  attempt: number;
  results: {
    tone: ReviewResult;
    accuracy: ReviewResult;
    brevity: ReviewResult;
  };
  timestamp: string;
}

export interface ReviewResult {
  pass: boolean;
  confidence: number;
  notes: string;
  issues?: string[];
  suggestions?: string[];
  errors?: AccuracyError[];
  unverifiable_claims?: string[];
  headline_chars?: number;
  headline_sentences?: number;
  talking_point_count?: number;
  body_paragraph_count?: number;
  estimated_read_seconds?: number;
  suggested_cuts?: string[];
}

export interface AccuracyError {
  claim: string;
  issue: string;
  source_says: string;
  severity: "critical" | "minor";
}

export interface GeneratedContent {
  is_newsworthy: boolean;
  skip_reason?: string;
  newsworthiness_score: number;
  headline?: string;
  body?: string;
  talking_points?: string[];
  emotional_context?: string;
  source_summary?: string;
}

export interface MatchdayContent {
  headline: string;
  body: string;
  talking_points: string[];
  pre_match_mood: "confident" | "nervous" | "excited" | "meh";
  rivalry_level: "derby" | "big_game" | "normal" | "dead_rubber";
  if_they_win: string;
  if_they_lose: string;
  bold_prediction?: string;
  emotional_context?: string;
  source_summary?: string;
}

export interface RSSItem {
  title: string;
  link: string;
  description: string;
  pubDate: string;
}

export interface FixtureData {
  fixture_id: string;
  kickoff_time: string;
  venue: string;
  referee: string;
  competition: string;
  opponent_name: string;
  is_home: boolean;
  home_team: string;
  away_team: string;
}
