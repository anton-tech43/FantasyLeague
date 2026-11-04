// routine-ingest/ingest.ts — the narrow door between the claude.ai routines and
// the database (bug hunt 2026-11-03, R-1).
//
// WHY: the routines held SUPABASE_SERVICE_KEY in the same shell where a model
// reads ~30 third-party RSS feeds. That key reads every APNs token, rewrites the
// human-verified columns, archives any card and opens every server-only Edge
// function (Anthropic credit, the API-Football quota). This function holds the
// service key server-side and does, for a caller presenting ROUTINE_INGEST_KEY,
// exactly what the routine scripts did with it and nothing more:
//
//   read                   GET on an allowlisted table, allowlisted columns, no
//                          embedding; device_tokens is not readable at all
//   followers              active devices per club (what the dossier run orders by)
//   cron_health            get_cron_startup_health() (the heartbeat's check 5)
//   insert_content         one routine card into content_items (post_news.sh)
//   update_content         the same-story update of a routine news card < 72 h old
//   notify                 notification-sender for a routine card published < 1 h ago
//   insert_insider / insert_quiz / insert_live_brief
//   upsert_player_card / upsert_season_state / upsert_content_review
//   upsert_team_page       the prose merge of post_team_page.sh, done here
//   feed_status            last_status / last_ok_at of existing team_news_sources rows
//   log                    one pipeline_health row, stage routine_post or news_feeds
//
// No delete, no generic RPC, no PATCH of a row the routines did not write. Every
// write forces its own provenance (pipeline_source, status, timestamps), drops
// fields the action does not own, caps sizes, and is rate-limited per hour from
// the table itself. Unset ROUTINE_INGEST_KEY = every call is refused, so the
// function is safe to deploy before the secret exists.
//
// Pure logic, fetch injected, so ingest.test.ts runs it without a network.

import { timingSafeEqual } from "../_shared/require-service-auth.ts";

export interface Env {
  ingestKey?: string; // ROUTINE_INGEST_KEY
  supabaseUrl?: string; // SUPABASE_URL
  serviceKey?: string; // SERVICE_KEY (sb_secret_*), never leaves this function
}
type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

const MAX_BODY_BYTES = 300_000;

// ── response helpers ────────────────────────────────────────────────────────
const json = (status: number, body: unknown, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
const bad = (msg: string) => json(400, { error: msg });

class Refusal extends Error {
  constructor(public status: number, msg: string) {
    super(msg);
  }
}
const refuse = (msg: string, status = 400): never => {
  throw new Refusal(status, msg);
};

// ── read allowlist ──────────────────────────────────────────────────────────
// The tables the routine scripts and prompts read, and every column each has
// today (information_schema, 2026-11-04). A column added later is not readable
// until it is added here; `select=*` expands to this list, never to the table.
// device_tokens is absent on purpose: `followers` answers the one question a
// routine has about it, and the tokens are never read.
export const READ_COLUMNS: Record<string, string[]> = {
  teams: ["id", "display_name", "api_football_id", "short_name", "created_at", "entity_type", "league_id",
    "strength_rank", "is_active", "manager_name", "manager_photo_url", "manager_started_on",
    "manager_verified_at", "pl_squad_id", "fan_name", "fan_name_verified_at"],
  content_items: ["id", "team_id", "type", "headline", "body", "talking_points", "source_urls", "match_id",
    "kickoff_time", "emotional_context", "status", "review_notes", "created_at", "published_at",
    "everyone_talking", "everyone_talking_headline", "everyone_talking_body",
    "everyone_talking_talking_points", "worth_knowing", "immersive_headline", "immersive_context",
    "immersive_context_fallback", "analogy_reviewed", "analogy_approved", "analogy_auto_published",
    "analogy_critic_score", "match_result", "pipeline_source", "push_text", "push_title", "pushed_at",
    "affected_team_ids", "consequence_type", "push_eligible", "preview_fixture_id", "goal_events",
    "significance", "info_cards", "league_id"],
  team_pages: ["team_id", "content", "updated_at"],
  player_cards: ["id", "team_id", "player_name", "position", "age", "summary", "vibe", "form", "updated_at",
    "api_player_id"],
  players: ["api_player_id", "team_id", "name", "position", "photo_url", "updated_at", "number", "appearances",
    "minutes", "stats_updated_at", "goals", "assists", "starts", "sub_appearances", "yellow_cards",
    "red_cards", "saves", "conceded", "rating", "captain", "nationality", "age", "league_goals",
    "league_starts", "official_number", "in_official_squad", "official_checked_at", "known_as",
    "known_as_verified_at"],
  saturday_quiz_items: ["id", "team_id", "match_id", "headline", "questions", "share_template", "published_at"],
  team_insider_items: ["id", "team_id", "type", "title", "body", "source_url", "published_at", "created_at"],
  team_season_state: ["team_id", "phase", "summary", "key_fact", "welcome_lines", "next_fixture",
    "generated_at", "state_line", "feeling_line", "next_fixtures"],
  live_match_briefs: ["id", "team_id", "match_id", "headline", "body", "minute", "trigger_label",
    "generated_at"],
  match_status_state: ["fixture_id", "league_id", "home_team_id", "away_team_id", "status", "home_goals",
    "away_goals", "kickoff_time", "last_checked", "fired_finished_at", "briefs_fired",
    "matchday_fire_capped", "la_started", "la_sig", "la_ended", "elapsed", "goal_events", "ht_home",
    "ht_away", "la_note", "live_changed_at", "stat_snapshots", "la_channel_id", "la_channel_id_dev",
    "la_takes", "la_note_sig", "la_channels"],
  pipeline_health: ["id", "team_id", "stage", "status", "duration_ms", "message", "content_item_id",
    "created_at", "target", "http_status", "response_excerpt", "error_class"],
  content_reviews: ["id", "week_of", "generated_at", "window_days", "metrics", "findings", "actions",
    "verdict"],
  raw_fetch_logs: ["id", "team_id", "source", "data", "fetched_at"],
  team_news_sources: ["id", "team_id", "name", "kind", "trust", "url", "reject_link_contains",
    "require_keyword", "verified_at", "last_ok_at", "last_status", "is_active"],
};

const IDENT = "[a-z_][a-z0-9_]*";
const JSON_PATH = "(?:->>?[A-Za-z0-9_]+)*";
const SELECT_ITEM = new RegExp(`^(?:[A-Za-z_][A-Za-z0-9_]*:)?(${IDENT})${JSON_PATH}(?:::[a-z]+)?$`);
const ORDER_ITEM = new RegExp(`^(${IDENT})${JSON_PATH}(?:\\.(?:asc|desc))?(?:\\.(?:nullsfirst|nullslast))?$`);
const FILTER_KEY = new RegExp(`^(${IDENT})${JSON_PATH}$`);
const FILTER_OP =
  /^(?:not\.)?(?:eq|neq|gt|gte|lt|lte|like|ilike|is|in|cs|cd|ov|fts|plfts|phfts|wfts|match|imatch)\./;
const MAX_LIMIT = 5000;

/// Validate a PostgREST `table?query` path. Returns the path to forward (with
/// `select=*` expanded), or throws a Refusal naming what was wrong. The
/// character rules are sb_read.sh's (R2S2 #5): no %-encoding, no `!` hints, no
/// brackets except an in.(...) list, so no embedded resource and no or=(...).
export function validateReadPath(path: unknown): string {
  if (typeof path !== "string" || path.length === 0 || path.length > 2000) refuse("read: data must be a '<table>?<query>' string");
  const p = path as string;
  if (!/^[a-z_]+(\?[A-Za-z0-9_.,:()*=&>+~-]*)?$/.test(p) || p.includes("//")) refuse(`read: not a table?query path: ${p}`);
  if (p.replaceAll("in.(", "").includes("(")) refuse(`read: no embedded resources; only in.(...) lists use brackets: ${p}`);
  const [table, query = ""] = p.split(/\?(.*)/s, 2);
  if (table === "device_tokens") refuse("read: device_tokens is never read from a routine; use the followers action");
  const cols = READ_COLUMNS[table];
  if (!cols) refuse(`read: table not readable from a routine: ${table}`);
  const allowed = new Set(cols);
  const col = (name: string, where: string) => {
    if (!allowed.has(name)) refuse(`read: column ${table}.${name} is not readable (${where})`);
  };
  const out: string[] = [];
  const seen = new Set<string>();
  for (const pair of query.split("&")) {
    if (pair === "") continue;
    const eq = pair.indexOf("=");
    if (eq <= 0) refuse(`read: malformed query parameter: ${pair}`);
    const k = pair.slice(0, eq), v = pair.slice(eq + 1);
    if (k === "select" || k === "order" || k === "limit" || k === "offset") {
      if (seen.has(k)) refuse(`read: ${k} given twice`);
      seen.add(k);
    }
    if (k === "select") {
      const items = v.split(",");
      if (items.length === 1 && items[0] === "*") {
        out.push(`select=${cols.join(",")}`);
        continue;
      }
      for (const it of items) {
        const m = SELECT_ITEM.exec(it);
        if (!m) refuse(`read: select item not allowed: ${it}`);
        col(m![1], "select");
      }
    } else if (k === "order") {
      for (const it of v.split(",")) {
        const m = ORDER_ITEM.exec(it);
        if (!m) refuse(`read: order item not allowed: ${it}`);
        col(m![1], "order");
      }
    } else if (k === "limit" || k === "offset") {
      if (!/^\d{1,6}$/.test(v)) refuse(`read: ${k} must be a number`);
      if (k === "limit" && Number(v) > MAX_LIMIT) refuse(`read: limit is at most ${MAX_LIMIT}`);
    } else {
      const m = FILTER_KEY.exec(k);
      if (!m) refuse(`read: parameter not allowed: ${k}`);
      col(m![1], "filter");
      if (!FILTER_OP.test(v)) refuse(`read: filter ${k} needs an operator (eq., in., gte., ...)`);
    }
    out.push(pair);
  }
  return out.length ? `${table}?${out.join("&")}` : table;
}

// ── PostgREST, server-side, with the service key ────────────────────────────
class Rest {
  constructor(private env: Required<Env>, private f: Fetch) {}
  private headers(extra: Record<string, string> = {}) {
    return {
      apikey: this.env.serviceKey,
      Authorization: `Bearer ${this.env.serviceKey}`,
      "Content-Type": "application/json",
      ...extra,
    };
  }
  async call(method: string, path: string, body?: unknown, prefer?: string): Promise<Response> {
    return await this.f(`${this.env.supabaseUrl}/rest/v1/${path}`, {
      method,
      headers: this.headers(prefer ? { Prefer: prefer } : {}),
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  }
  async rows(path: string): Promise<Record<string, unknown>[]> {
    const r = await this.call("GET", path);
    if (!r.ok) refuse(`lookup failed (HTTP ${r.status})`, 502);
    const b = await r.json();
    return Array.isArray(b) ? b : [];
  }
  async count(path: string): Promise<number> {
    const r = await this.f(`${this.env.supabaseUrl}/rest/v1/${path}`, {
      method: "HEAD",
      headers: this.headers({ Prefer: "count=exact" }),
    });
    const total = Number((r.headers.get("content-range") ?? "").split("/")[1]);
    // Not knowing is not the same as under the limit.
    if (!r.ok || !Number.isFinite(total)) refuse(`rate-limit count failed (HTTP ${r.status})`, 502);
    return total;
  }
  fn(name: string, body: unknown): Promise<Response> {
    return this.f(`${this.env.supabaseUrl}/functions/v1/${name}`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(body),
    });
  }
}

// Pass PostgREST's answer through unchanged, so the scripts' existing parsing
// (`.[0].id`, the HTTP code, curl -f) behaves exactly as it did.
async function relay(r: Response, extra: Record<string, string> = {}): Promise<Response> {
  const text = await r.text();
  return new Response(text, {
    status: r.status,
    headers: { "Content-Type": r.headers.get("Content-Type") ?? "application/json", ...extra },
  });
}

// ── field rules ─────────────────────────────────────────────────────────────
// Caps are several times the largest value in production on 2026-11-04; they
// stop a runaway or injected payload, not a long card.
type Rule =
  | { t: "str"; max: number; re?: RegExp }
  | { t: "int"; min: number; max: number }
  | { t: "bool" }
  | { t: "json"; maxBytes: number; array?: number }
  | { t: "strs"; max: number; each: number };

function check(field: string, v: unknown, r: Rule): void {
  if (v === null) return;
  const no = (why: string) => refuse(`${field}: ${why}`);
  switch (r.t) {
    case "str":
      if (typeof v !== "string") no("must be a string");
      // Characters, not UTF-16 units: the database's length() and the push caps count code points.
      if ([...(v as string)].length > r.max) no(`longer than ${r.max} characters`);
      if (r.re && !r.re.test(v as string)) no("has the wrong shape");
      return;
    case "int":
      if (typeof v !== "number" || !Number.isInteger(v) || v < r.min || v > r.max) no(`must be an integer ${r.min}-${r.max}`);
      return;
    case "bool":
      if (typeof v !== "boolean") no("must be true or false");
      return;
    case "json":
      if (r.array !== undefined && (!Array.isArray(v) || v.length > r.array)) no(`must be an array of at most ${r.array}`);
      if (JSON.stringify(v).length > r.maxBytes) no(`larger than ${r.maxBytes} bytes`);
      return;
    case "strs":
      if (!Array.isArray(v) || v.length > r.max || v.some((s) => typeof s !== "string" || s.length > r.each)) {
        no(`must be at most ${r.max} strings of at most ${r.each} characters`);
      }
      return;
  }
}

// Provenance and timestamps this function sets itself; a script that still
// sends them is not told they were dropped.
const SERVER_SET = new Set(["id", "pipeline_source", "status", "published_at", "generated_at", "updated_at", "created_at"]);

/// Keep only the fields `rules` names, checking each. Returns the row and the
/// names it dropped (a stray key costs the field, not the row: whitelist.sh).
function project(row: unknown, rules: Record<string, Rule>): { row: Record<string, unknown>; dropped: string[] } {
  if (!row || typeof row !== "object" || Array.isArray(row)) refuse("data must be a JSON object");
  const out: Record<string, unknown> = {};
  const dropped: string[] = [];
  for (const [k, v] of Object.entries(row as Record<string, unknown>)) {
    const r = rules[k];
    if (!r) {
      if (!SERVER_SET.has(k)) dropped.push(k);
      continue;
    }
    check(k, v, r);
    out[k] = v;
  }
  return { row: out, dropped };
}

const TEAM_ID = /^[a-z_]{2,40}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const URLISH = /^https?:\/\/[^\s]+$/;
const FIXTURE = /^\d{1,12}$/;

const CONTENT_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  type: { t: "str", max: 20, re: /^(news|matchday|sunday_brief)$/ },
  headline: { t: "str", max: 300 },
  body: { t: "str", max: 5000 },
  talking_points: { t: "strs", max: 10, each: 600 },
  source_urls: { t: "strs", max: 30, each: 600 },
  match_id: { t: "str", max: 20, re: FIXTURE },
  kickoff_time: { t: "str", max: 40 },
  emotional_context: { t: "str", max: 20 },
  everyone_talking: { t: "bool" },
  everyone_talking_headline: { t: "str", max: 600 },
  everyone_talking_body: { t: "str", max: 3000 },
  everyone_talking_talking_points: { t: "strs", max: 10, each: 600 },
  worth_knowing: { t: "bool" },
  immersive_headline: { t: "str", max: 300 },
  immersive_context: { t: "str", max: 1000 },
  immersive_context_fallback: { t: "str", max: 1000 },
  match_result: { t: "str", max: 200 },
  push_text: { t: "str", max: 100 },
  push_title: { t: "str", max: 35 },
  affected_team_ids: { t: "strs", max: 30, each: 40 },
  push_eligible: { t: "bool" },
  preview_fixture_id: { t: "str", max: 60 },
  significance: { t: "int", min: 0, max: 2 },
  info_cards: { t: "json", maxBytes: 8000, array: 3 },
  league_id: { t: "int", min: 1, max: 100000 },
};
// What the same-story PATCH in post_news.sh may change, and nothing else.
const UPDATE_FIELDS = ["headline", "body", "talking_points", "push_title", "push_text", "immersive_headline",
  "immersive_context", "immersive_context_fallback", "info_cards", "emotional_context", "everyone_talking",
  "everyone_talking_headline", "everyone_talking_body", "everyone_talking_talking_points", "worth_knowing",
  "affected_team_ids", "source_urls", "significance", "push_eligible"];

const INSIDER_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  type: { t: "str", max: 20, re: /^(stat|anecdote|history|oddity)$/ },
  title: { t: "str", max: 200 },
  body: { t: "str", max: 2000 },
  source_url: { t: "str", max: 1000, re: URLISH },
};
const QUIZ_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  match_id: { t: "str", max: 20, re: FIXTURE },
  headline: { t: "str", max: 200 },
  questions: { t: "json", maxBytes: 20000, array: 5 },
  share_template: { t: "str", max: 300 },
};
const LIVE_BRIEF_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  match_id: { t: "str", max: 20, re: FIXTURE },
  headline: { t: "str", max: 300 },
  body: { t: "str", max: 1500 },
  minute: { t: "int", min: 0, max: 150 },
  trigger_label: { t: "str", max: 40 },
};
const PLAYER_CARD_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  player_name: { t: "str", max: 100 },
  position: { t: "str", max: 60 },
  age: { t: "int", min: 10, max: 60 },
  summary: { t: "str", max: 2500 },
  vibe: { t: "str", max: 500 },
  form: { t: "str", max: 500 },
};
const SEASON_STATE_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  phase: { t: "str", max: 40 },
  summary: { t: "str", max: 2000 },
  key_fact: { t: "str", max: 1000 },
  welcome_lines: { t: "json", maxBytes: 5000 },
  next_fixture: { t: "json", maxBytes: 3000 },
  next_fixtures: { t: "json", maxBytes: 5000 },
  state_line: { t: "str", max: 300 },
  feeling_line: { t: "str", max: 600 },
};
const REVIEW_RULES: Record<string, Rule> = {
  week_of: { t: "str", max: 10, re: /^\d{4}-\d{2}-\d{2}$/ },
  window_days: { t: "int", min: 1, max: 60 },
  metrics: { t: "json", maxBytes: 60000 },
  findings: { t: "json", maxBytes: 60000, array: 100 },
  actions: { t: "json", maxBytes: 30000, array: 50 },
  verdict: { t: "str", max: 10000 },
};
const TEAM_PAGE_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  basics: { t: "json", maxBytes: 4000 },
  rivalry: { t: "json", maxBytes: 4000 },
  manager_name: { t: "str", max: 100 },
  manager_photo_url: { t: "str", max: 1000 },
  manager_summary: { t: "str", max: 2000 },
  manager_talking_point: { t: "str", max: 1000 },
  form_summary: { t: "str", max: 2000 },
  season_summary: { t: "str", max: 3000 },
  next_fixture_preview: { t: "str", max: 1500 },
  next_fixture_preview_fixture_id: { t: "str", max: 20, re: FIXTURE },
  top_players: { t: "json", maxBytes: 8000, array: 6 },
};
const LOG_RULES: Record<string, Rule> = {
  team_id: { t: "str", max: 40, re: TEAM_ID },
  stage: { t: "str", max: 20, re: /^(routine_post|news_feeds)$/ },
  status: { t: "str", max: 10, re: /^(success|failure|skipped|partial)$/ },
  target: { t: "str", max: 200 },
  http_status: { t: "int", min: 0, max: 999 },
  response_excerpt: { t: "str", max: 1000 },
  error_class: { t: "str", max: 64 },
  message: { t: "str", max: 4000 },
};

// Writes per hour, counted from the table. Production peaks 2026-09..11:
// content_items 46, insider 130, player_cards 60, quiz 20, live briefs 10,
// routine pipeline_health rows 136.
export const HOURLY = {
  content: 120,
  insider: 300,
  player_cards: 150,
  quiz: 60,
  live_briefs: 60,
  season_state: 80,
  team_pages: 80,
  log: 800,
};

// ── the handler ─────────────────────────────────────────────────────────────
export async function handle(req: Request, env: Env, f: Fetch = fetch, now: () => Date = () => new Date()) {
  // Auth first, before reading anything the caller sent. An unset or short
  // secret refuses everything: deploying this before the key exists is safe.
  const want = env.ingestKey ?? "";
  const got = req.headers.get("x-routine-key") ?? "";
  if (want.length < 32 || !timingSafeEqual(got, want)) return json(401, { error: "unauthorized" });
  if (req.method !== "POST") return json(405, { error: "POST only" });
  if (!env.supabaseUrl || !env.serviceKey) return json(500, { error: "routine-ingest is not configured" });

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return json(413, { error: `body larger than ${MAX_BODY_BYTES} bytes` });
  let msg: { action?: unknown; data?: unknown };
  try {
    msg = JSON.parse(raw);
  } catch {
    return bad("body is not JSON");
  }
  if (!msg || typeof msg !== "object") return bad("body must be {action, data}");

  const db = new Rest(env as Required<Env>, f);
  const t = now();
  const iso = (d: Date) => d.toISOString().replace(/\.\d{3}Z$/, "Z");
  const ago = (ms: number) => iso(new Date(t.getTime() - ms));
  const HOUR = 3600_000;
  const limit = async (what: keyof typeof HOURLY, countPath: string) => {
    if ((await db.count(countPath)) >= HOURLY[what]) {
      refuse(`rate limit: ${HOURLY[what]} ${what} writes an hour from the routines`, 429);
    }
  };
  const activeTeam = async (teamId: unknown, extra = "") => {
    if (typeof teamId !== "string" || !TEAM_ID.test(teamId)) refuse("team_id missing or malformed");
    const r = await db.rows(`teams?id=eq.${teamId}&is_active=eq.true${extra}&select=id,entity_type,league_id,manager_name`);
    if (r.length !== 1) refuse(`${teamId} is not a team the app follows`);
    return r[0];
  };
  const dropHeader = (d: string[]): Record<string, string> =>
    d.length ? { "x-routine-dropped": d.join(",").slice(0, 500) } : {};

  try {
    switch (msg.action) {
      case "read":
        return relay(await db.call("GET", validateReadPath(msg.data)));

      case "followers": {
        // Followers per club, never a token. Pages past PostgREST's 1,000-row cap.
        const counts: Record<string, number> = {};
        for (let off = 0; off < 1_000_000; off += 1000) {
          const page = await db.rows(`device_tokens?select=team_ids&is_active=eq.true&order=id&limit=1000&offset=${off}`);
          for (const p of page) for (const id of (p.team_ids as string[] | null) ?? []) counts[id] = (counts[id] ?? 0) + 1;
          if (page.length < 1000) break;
        }
        const out = Object.entries(counts).map(([team_id, followers]) => ({ team_id, followers }))
          .sort((a, b) => b.followers - a.followers || a.team_id.localeCompare(b.team_id));
        return json(200, out);
      }

      case "cron_health":
        return relay(await db.call("POST", "rpc/get_cron_startup_health", {}));

      case "insert_content": {
        const { row, dropped } = project(msg.data, CONTENT_RULES);
        if (!row.type || !row.headline) refuse("type and headline are required");
        await activeTeam(row.team_id);
        await limit("content", `content_items?select=id&pipeline_source=eq.routine&published_at=gte.${ago(HOUR)}`);
        Object.assign(row, { pipeline_source: "routine", status: "published", published_at: iso(t) });
        if (!("source_urls" in row) || row.source_urls === null) row.source_urls = [];
        return relay(await db.call("POST", "content_items", row, "return=representation"), dropHeader(dropped));
      }

      case "update_content": {
        const d = (msg.data ?? {}) as { id?: unknown; team_id?: unknown; patch?: unknown };
        if (typeof d.id !== "string" || !UUID.test(d.id)) refuse("update_content: id must be a uuid");
        const rules = Object.fromEntries(UPDATE_FIELDS.map((k) => [k, CONTENT_RULES[k]]));
        const { row: patch, dropped } = project(d.patch, rules);
        // An update never makes a card push: it may only take push away.
        if (patch.push_eligible !== undefined && patch.push_eligible !== false) {
          delete patch.push_eligible;
          dropped.push("push_eligible");
        }
        const old = await db.rows(`content_items?id=eq.${d.id}&select=id,team_id,type,status,pipeline_source,published_at`);
        const o = old[0];
        const fresh = o && typeof o.published_at === "string" && Date.parse(o.published_at) >= t.getTime() - 73 * HOUR;
        if (!o || o.pipeline_source !== "routine" || o.status !== "published" || o.type !== "news" ||
            o.team_id !== d.team_id || !fresh) {
          refuse("update_content: only a published routine news card of the same club, under 72 h old", 403);
        }
        await limit("content", `content_items?select=id&pipeline_source=eq.routine&published_at=gte.${ago(HOUR)}`);
        patch.published_at = iso(t);
        return relay(
          await db.call("PATCH",
            `content_items?id=eq.${d.id}&pipeline_source=eq.routine&status=eq.published&type=eq.news`,
            patch, "return=representation"),
          dropHeader(dropped),
        );
      }

      case "notify": {
        const id = (msg.data as { content_item_id?: unknown } | null)?.content_item_id;
        if (typeof id !== "string" || !UUID.test(id)) refuse("notify: content_item_id must be a uuid");
        // Only a routine card this path published within the hour and that has
        // not pushed. notification-sender still decides everything else
        // (push_eligible, tiers, throttle, quiet hours: PUSH_RULES.md).
        const r = await db.rows(
          `content_items?id=eq.${id}&pipeline_source=eq.routine&status=eq.published&pushed_at=is.null&published_at=gte.${ago(HOUR)}&select=id`,
        );
        if (r.length !== 1) refuse("notify: not a routine card published in the last hour that has yet to push", 403);
        return relay(await db.fn("notification-sender", { content_item_id: id }));
      }

      case "insert_insider": {
        const { row, dropped } = project(msg.data, INSIDER_RULES);
        if (!row.type || !row.title || !row.body) refuse("type, title and body are required");
        await activeTeam(row.team_id, "&entity_type=in.(club,country)");
        await limit("insider", `team_insider_items?select=id&created_at=gte.${ago(HOUR)}`);
        row.published_at = iso(t);
        return relay(await db.call("POST", "team_insider_items", row, "return=representation"), dropHeader(dropped));
      }

      case "insert_quiz": {
        const { row, dropped } = project(msg.data, QUIZ_RULES);
        if (!Array.isArray(row.questions) || row.questions.length !== 5) refuse("questions must be exactly 5");
        await activeTeam(row.team_id);
        await limit("quiz", `saturday_quiz_items?select=id&published_at=gte.${ago(HOUR)}`);
        row.published_at = iso(t);
        return relay(await db.call("POST", "saturday_quiz_items", row, "return=representation"), dropHeader(dropped));
      }

      case "insert_live_brief": {
        const { row, dropped } = project(msg.data, LIVE_BRIEF_RULES);
        if (!row.match_id || !row.body) refuse("match_id and body are required");
        await activeTeam(row.team_id);
        await limit("live_briefs", `live_match_briefs?select=id&generated_at=gte.${ago(HOUR)}`);
        row.generated_at = iso(t);
        return relay(await db.call("POST", "live_match_briefs", row, "return=representation"), dropHeader(dropped));
      }

      case "upsert_player_card": {
        const { row, dropped } = project(msg.data, PLAYER_CARD_RULES);
        if (!row.player_name) refuse("player_name is required");
        await activeTeam(row.team_id);
        await limit("player_cards", `player_cards?select=id&updated_at=gte.${ago(HOUR)}`);
        row.updated_at = iso(t);
        return relay(
          await db.call("POST", "player_cards?on_conflict=team_id,player_name", row,
            "return=representation,resolution=merge-duplicates"),
          dropHeader(dropped),
        );
      }

      case "upsert_season_state": {
        const { row, dropped } = project(msg.data, SEASON_STATE_RULES);
        await activeTeam(row.team_id);
        // generated_at is the freshness of the PROSE (post_season_state.sh):
        // stamped only when the prose is in this payload.
        const s = (k: string) => typeof row[k] === "string" && row[k] !== "";
        if (s("summary") || (s("state_line") && s("feeling_line"))) {
          await limit("season_state", `team_season_state?select=team_id&generated_at=gte.${ago(HOUR)}`);
          row.generated_at = iso(t);
        }
        return relay(
          await db.call("POST", "team_season_state?on_conflict=team_id", row,
            "resolution=merge-duplicates,return=representation"),
          dropHeader(dropped),
        );
      }

      case "upsert_content_review": {
        const { row, dropped } = project(msg.data, REVIEW_RULES);
        // The weekly review of the week just gone: never rewrites an old one.
        const wk = Date.parse(`${row.week_of}T00:00:00Z`);
        if (!Number.isFinite(wk) || Math.abs(t.getTime() - wk) > 15 * 24 * HOUR) {
          refuse("week_of must be within 15 days of today");
        }
        if (!row.metrics || typeof row.metrics !== "object" || Array.isArray(row.metrics)) refuse("metrics must be an object");
        return relay(
          await db.call("POST", "content_reviews?on_conflict=week_of", row, "resolution=merge-duplicates,return=minimal"),
          dropHeader(dropped),
        );
      }

      case "upsert_team_page": {
        const { row: p, dropped } = project(msg.data, TEAM_PAGE_RULES);
        const team = await activeTeam(p.team_id, "&league_id=eq.39");
        if (p.manager_name && team.manager_name && p.manager_name !== team.manager_name) {
          refuse(`manager_name does not match the verified manager for ${p.team_id}`);
        }
        await limit("team_pages", `team_pages?select=team_id&content->>last_routine_run=gte.${ago(HOUR)}`);
        const ex = await db.rows(`team_pages?team_id=eq.${p.team_id}&select=content`);
        const merged = mergeTeamPage((ex[0]?.content as Record<string, unknown> | undefined) ?? null, p, iso(t));
        return relay(
          await db.call("POST", "team_pages?on_conflict=team_id",
            { team_id: p.team_id, content: merged, updated_at: iso(t) }, "resolution=merge-duplicates,return=minimal"),
          dropHeader(dropped),
        );
      }

      case "feed_status": {
        // Two columns of rows that already exist. The routine cannot add a
        // source, change its trust tier or its URL: those come from the table.
        const rows = msg.data;
        if (!Array.isArray(rows) || rows.length > 300) refuse("feed_status: data must be an array of at most 300 rows");
        const known = new Map(
          (await db.rows("team_news_sources?select=url,team_id,name,kind,trust&limit=2000"))
            .map((r) => [r.url as string, r]),
        );
        const ok: Record<string, unknown>[] = [], notOk: Record<string, unknown>[] = [];
        for (const r of rows as Record<string, unknown>[]) {
          const s = known.get(r?.url as string);
          if (!s) continue;
          check("last_status", r.last_status, { t: "int", min: 0, max: 999 });
          const base = { url: s.url, team_id: s.team_id, name: s.name, kind: s.kind, trust: s.trust,
            last_status: r.last_status ?? null };
          // One shape per request: a bulk upsert takes its columns from the rows.
          if (r.last_ok_at) ok.push({ ...base, last_ok_at: iso(t) });
          else notOk.push(base);
        }
        let last: Response | null = null;
        for (const group of [ok, notOk]) {
          if (!group.length) continue;
          last = await db.call("POST", "team_news_sources?on_conflict=url", group, "resolution=merge-duplicates,return=minimal");
          if (!last.ok) return relay(last);
        }
        return last ? relay(last) : new Response(null, { status: 204 });
      }

      case "log": {
        const { row, dropped } = project(msg.data, LOG_RULES);
        if (!row.stage || !row.status) refuse("stage and status are required");
        await limit("log", `pipeline_health?select=id&stage=in.(routine_post,news_feeds)&created_at=gte.${ago(HOUR)}`);
        return relay(await db.call("POST", "pipeline_health", row, "return=minimal"), dropHeader(dropped));
      }

      default:
        return bad("unknown action");
    }
  } catch (e) {
    if (e instanceof Refusal) return json(e.status, { error: e.message });
    console.error("routine-ingest:", e);
    return json(500, { error: "internal error" });
  }
}

/// post_team_page.sh's jq merge, here so the routine sends prose and never a
/// whole `content`: it cannot overwrite the numbers team-page-generator writes.
export function mergeTeamPage(
  existing: Record<string, unknown> | null,
  p: Record<string, unknown>,
  now: string,
): Record<string, unknown> {
  type O = Record<string, unknown>;
  const has = (v: unknown) => v !== null && v !== undefined && v !== false; // jq truthiness
  if (!existing) {
    const b = (p.basics ?? {}) as O, r = (p.rivalry ?? {}) as O;
    if (!has(b.nickname) || !has(b.fun_fact) || !has(b.talking_point) || !has(r.text)) {
      refuse(`${p.team_id} has no team page yet; basics{nickname,fun_fact,talking_point} and rivalry{text} are required to create one`);
    }
    existing = { schema_version: 1, cards: {} };
  }
  const obj = (v: unknown, what: string): O => {
    if (v === null || v === undefined) return {};
    if (typeof v !== "object" || Array.isArray(v)) refuse(`${what} must be an object`);
    return v as O;
  };
  const c: O = { ...obj(existing.cards, "content.cards") };
  if (c.basics == null && p.basics != null) c.basics = { ...obj(p.basics, "basics"), updated_at: now };
  if (c.rivalry == null && p.rivalry != null) c.rivalry = { ...obj(p.rivalry, "rivalry"), updated_at: now };
  if (p.manager_name != null) {
    const m: O = { ...obj(c.manager, "manager"), updated_at: now, name: p.manager_name };
    if (has(p.manager_photo_url)) m.photo_url = p.manager_photo_url;
    if (has(p.manager_summary)) m.summary = p.manager_summary;
    if (has(p.manager_talking_point)) m.talking_point = p.manager_talking_point;
    delete m.summary_stale;
    c.manager = m;
  }
  if (p.form_summary != null) c.form = { ...obj(c.form, "form"), form_summary: p.form_summary, updated_at: now };
  if (p.season_summary != null) c.season = { ...obj(c.season, "season"), summary: p.season_summary, updated_at: now };
  if (p.next_fixture_preview != null && c.next_fixture != null) {
    c.next_fixture = {
      ...obj(c.next_fixture, "next_fixture"),
      preview_colour: p.next_fixture_preview,
      preview_fixture_id: p.next_fixture_preview_fixture_id ?? null,
    };
  }
  if (p.top_players != null) {
    const o = { ...obj(c.ones_to_know, "ones_to_know") };
    delete o.out;
    c.ones_to_know = { ...o, updated_at: now, players: p.top_players };
  }
  if (c.ones_to_know != null) {
    const o = { ...obj(c.ones_to_know, "ones_to_know") };
    delete o.talking_point;
    c.ones_to_know = o;
  }
  return { ...existing, cards: c, last_routine_run: now };
}
