// deno test backend/supabase/functions/routine-ingest/ingest.test.ts
//
// routine-ingest against a fake PostgREST: no network, every request recorded,
// so each case can say both what came back and what reached the database.
import { assert, assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { handle, HOURLY, mergeTeamPage, validateReadPath } from "./ingest.ts";

const KEY = "k".repeat(64);
const ENV = { ingestKey: KEY, supabaseUrl: "https://db.test", serviceKey: "svc" };
const NOW = new Date("2026-11-04T12:00:00Z");

type Call = { method: string; url: string; body: unknown; headers: Record<string, string> };
interface World {
  team?: Record<string, unknown> | null; // teams lookup row, null = no active team
  count?: number; // what every rate-limit HEAD answers
  item?: Record<string, unknown> | null; // content_items row by id
  page?: Record<string, unknown> | null; // team_pages content
  tokens?: { team_ids: string[] }[];
  sources?: Record<string, unknown>[];
}

function fake(w: World = {}) {
  const calls: Call[] = [];
  const f = (url: string, init: RequestInit = {}) => {
    const method = init.method ?? "GET";
    const body = init.body ? JSON.parse(init.body as string) : undefined;
    calls.push({ method, url, body, headers: init.headers as Record<string, string> });
    const ok = (b: unknown, status = 200, h: Record<string, string> = {}) =>
      Promise.resolve(new Response(b === null ? null : JSON.stringify(b), { status, headers: { "Content-Type": "application/json", ...h } }));
    if (method === "HEAD") return ok(null, 200, { "content-range": `*/${w.count ?? 0}` });
    const path = url.replace("https://db.test/rest/v1/", "");
    if (method === "GET" && path.startsWith("teams?id=eq.")) {
      const t = w.team === undefined ? { id: "arsenal", entity_type: "club", league_id: 39, manager_name: "Mikel Arteta" } : w.team;
      return ok(t ? [t] : []);
    }
    if (method === "GET" && path.startsWith("content_items?id=eq.")) return ok(w.item ? [w.item] : []);
    if (method === "GET" && path.startsWith("team_pages?team_id=eq.")) return ok(w.page ? [{ content: w.page }] : []);
    if (method === "GET" && path.startsWith("device_tokens?")) {
      const off = Number(/offset=(\d+)/.exec(path)![1]);
      return ok((w.tokens ?? []).slice(off, off + 1000));
    }
    if (method === "GET" && path.startsWith("team_news_sources?")) return ok(w.sources ?? []);
    if (method === "GET") return ok([{ id: 1 }]);
    if (method === "PATCH") return ok([{ id: "patched" }]);
    return ok([{ id: "new" }], 201);
  };
  return { f, calls, writes: () => calls.filter((c) => c.method !== "GET" && c.method !== "HEAD") };
}

const req = (action: string, data: unknown, key: string | null = KEY, method = "POST") =>
  new Request("https://fn.test/routine-ingest", {
    method,
    headers: key === null ? {} : { "x-routine-key": key },
    body: method === "GET" ? undefined : JSON.stringify({ action, data }),
  });
async function call(action: string, data: unknown, w: World = {}, key: string | null = KEY, env = ENV) {
  const fk = fake(w);
  const r = await handle(req(action, data, key), env, fk.f, () => NOW);
  const text = await r.text();
  return { status: r.status, body: text ? JSON.parse(text) : null, ...fk, headers: r.headers };
}

const ID = "11111111-2222-3333-4444-555555555555";
const card = { team_id: "arsenal", type: "news", headline: "Saka is back in training", body: "b", talking_points: ["t"] };

// ── the key ─────────────────────────────────────────────────────────────────
Deno.test("no key, a wrong key, or a key the function does not have: 401 and nothing reaches the database", async () => {
  for (const [key, env] of [
    [null, ENV], ["", ENV], ["k".repeat(63), ENV], ["x".repeat(64), ENV],
    [KEY, { ...ENV, ingestKey: undefined }], // deployed before the secret exists
    ["", { ...ENV, ingestKey: "" }],
    ["short", { ...ENV, ingestKey: "short" }], // a weak secret is no secret
  ] as const) {
    const r = await call("read", "teams?select=id", {}, key, env as typeof ENV);
    assertEquals(r.status, 401, `key=${key} env=${env.ingestKey}`);
    assertEquals(r.calls.length, 0);
  }
});

Deno.test("the service key never travels to the caller and only POST is accepted", async () => {
  const fk = fake();
  const r = await handle(req("read", null, KEY, "GET"), ENV, fk.f, () => NOW);
  assertEquals(r.status, 405);
  const ok = await call("read", "teams?select=id&limit=1");
  assertEquals(ok.status, 200);
  assertEquals(ok.calls[0].headers.Authorization, "Bearer svc");
  assert(!JSON.stringify(ok.body).includes("svc"));
  assertEquals((await call("delete", { id: ID })).status, 400);
  assertEquals((await call("rpc", { fn: "get_insights" })).status, 400);
});

// ── reads ───────────────────────────────────────────────────────────────────
Deno.test("read: what the scripts and prompts read today passes", () => {
  for (const p of [
    "content_items?team_id=eq.arsenal&select=id,headline&created_at=gte.2026-11-01T00:00:00Z",
    "team_pages?select=team_id,ran:content->>last_routine_run",
    "content_items?team_id=in.(champions_league,europa_league)&select=team_id,headline",
    "teams?select=id&entity_type=in.(club,country)&is_active=eq.true&order=id.asc",
    "team_pages?select=team_id,content->cards->basics,content->cards->next_fixture",
    "team_pages?team_id=eq.arsenal&select=last_title:content->cards->basics->>last_title,opponent:content->cards->next_fixture->>opponent",
    "players?team_id=eq.arsenal&select=name,minutes,league_starts&order=minutes.desc.nullslast",
    "raw_fetch_logs?team_id=eq.arsenal&source=in.(api_football_fixtures_next,api_football_fixtures_last)&order=fetched_at.desc&limit=2&select=data",
    "pipeline_health?select=target,response_excerpt,error_class&stage=eq.routine_post&status=eq.failure&created_at=gte.2026-11-03T12:00:00Z&limit=200",
    "content_items?created_at=gte.2026-10-28T00:00:00Z&select=id,team_id,type&limit=5000",
    "match_status_state?fixture_id=eq.1234&select=league_id",
    "teams",
  ]) validateReadPath(p);
});

Deno.test("read: device tokens, embedding, unknown tables and columns, encodings, or=(), big limits refused", async () => {
  for (const p of [
    "device_tokens?select=team_ids&is_active=eq.true", "device_tokens?select=apns_token",
    "teams?select=id,device_tokens!team_id(apns_token)", "teams?select=id,device_tokens(apns_token)",
    "content_items?select=id,analogy_rejections(*)", "users?select=*", "dev_alert_devices?select=*",
    "teams?sel%65ct=apns_token", "teams?select=id&or=(id.eq.a,id.eq.b)", "teams?select=secret_col",
    "teams?apns_token=eq.x", "teams?select=id&order=secret.desc", "teams?select=id&limit=100000",
    "teams?select=id&select=manager_name", "teams?select=id&columns=id", "teams?a=https://evil.example",
    "content_items?id=eq.1 -X DELETE", "teams?is_active=true", "teams?select=count()",
  ]) {
    const r = await call("read", p);
    assertEquals(r.status, 400, p);
    assertEquals(r.calls.length, 0, p);
  }
});

Deno.test("read: select=* is the allowlist, not the table", () => {
  const out = validateReadPath("live_match_briefs?select=*&team_id=eq.arsenal");
  assertEquals(out, "live_match_briefs?select=id,team_id,match_id,headline,body,minute,trigger_label,generated_at&team_id=eq.arsenal");
});

Deno.test("followers: counts per club across pages, never a token", async () => {
  const tokens = [...Array(1500)].map((_, i) => ({ team_ids: i % 3 ? ["arsenal"] : ["arsenal", "spurs"] }));
  const r = await call("followers", null, { tokens });
  assertEquals(r.status, 200);
  assertEquals(r.body, [{ team_id: "arsenal", followers: 1500 }, { team_id: "spurs", followers: 500 }]);
  assert(r.calls.every((c) => c.url.includes("select=team_ids&")));
});

// ── content_items ───────────────────────────────────────────────────────────
Deno.test("insert_content: provenance forced, unknown and server-owned fields dropped", async () => {
  const r = await call("insert_content", { ...card, pushed_at: "2026-01-01", pipeline_source: "edge_function",
    status: "draft", consequence_type: "title_won", review_notes: {}, id: ID });
  assertEquals(r.status, 201);
  const w = r.writes();
  assertEquals(w.length, 1);
  assertEquals(w[0].url, "https://db.test/rest/v1/content_items");
  const row = w[0].body as Record<string, unknown>;
  assertEquals([row.pipeline_source, row.status, row.published_at], ["routine", "published", "2026-11-04T12:00:00Z"]);
  for (const k of ["pushed_at", "consequence_type", "review_notes", "id"]) assert(!(k in row), k);
  assertEquals(r.headers.get("x-routine-dropped"), "pushed_at,consequence_type,review_notes");
});

Deno.test("insert_content: caps, types and the club are checked before anything is written", async () => {
  for (const [why, data, w] of [
    ["push_title over 35", { ...card, push_title: "x".repeat(36) }, {}],
    ["body over the cap", { ...card, body: "x".repeat(5001) }, {}],
    ["a type routines do not write", { ...card, type: "starting_xi" }, {}],
    ["talking points not strings", { ...card, talking_points: [{ a: 1 }] }, {}],
    ["significance 3", { ...card, significance: 3 }, {}],
    ["a team the app does not follow", { ...card, team_id: "world_championship" }, { team: null }],
    ["a malformed team id", { ...card, team_id: "Arsenal FC" }, {}],
  ] as const) {
    const r = await call("insert_content", data, w as World);
    assertEquals(r.status, 400, why);
    assertEquals(r.writes().length, 0, why);
  }
  // 35 characters with an accent and a pound sign is 35, not 37.
  assertEquals((await call("insert_content", { ...card, push_title: "é£" + "x".repeat(33) })).status, 201);
});

Deno.test("insert_content and update_content: hourly rate limit", async () => {
  const r = await call("insert_content", card, { count: HOURLY.content });
  assertEquals(r.status, 429);
  assertEquals(r.writes().length, 0);
  assertEquals((await call("insert_content", card, { count: HOURLY.content - 1 })).status, 201);
});

const routineCard = { id: ID, team_id: "arsenal", type: "news", status: "published", pipeline_source: "routine",
  published_at: "2026-11-03T12:00:00Z" };
Deno.test("update_content: own rows only, the same club, under 72 h, and never re-arms a push", async () => {
  const patch = { headline: "Saka is fit", push_eligible: true, team_id: "spurs", pushed_at: null, status: "archived" };
  const ok = await call("update_content", { id: ID, team_id: "arsenal", patch }, { item: routineCard });
  assertEquals(ok.status, 200);
  const w = ok.writes()[0];
  assertEquals(w.method, "PATCH");
  assert(w.url.includes(`id=eq.${ID}&pipeline_source=eq.routine&status=eq.published&type=eq.news`));
  assertEquals(w.body, { headline: "Saka is fit", published_at: "2026-11-04T12:00:00Z" });
  const off = await call("update_content", { id: ID, team_id: "arsenal", patch: { push_eligible: false } }, { item: routineCard });
  assertEquals((off.writes()[0].body as Record<string, unknown>).push_eligible, false);

  for (const [why, item, team] of [
    ["an Edge-function card", { ...routineCard, pipeline_source: "edge_function" }, "arsenal"],
    ["another club's card", routineCard, "spurs"],
    ["an archived card", { ...routineCard, status: "archived" }, "arsenal"],
    ["a matchday card", { ...routineCard, type: "matchday" }, "arsenal"],
    ["a card four days old", { ...routineCard, published_at: "2026-10-31T11:00:00Z" }, "arsenal"],
    ["no such card", null, "arsenal"],
  ] as const) {
    const r = await call("update_content", { id: ID, team_id: team, patch }, { item: item as Record<string, unknown> | null });
    assertEquals(r.status, 403, why);
    assertEquals(r.writes().length, 0, why);
  }
  assertEquals((await call("update_content", { id: "1 or 1=1", team_id: "arsenal", patch })).status, 400);
});

Deno.test("notify: only a routine card published in the last hour that has not pushed", async () => {
  const ok = await call("notify", { content_item_id: ID }, { item: routineCard });
  assertEquals(ok.status, 201);
  const lookup = ok.calls[0].url;
  for (const f of ["pipeline_source=eq.routine", "status=eq.published", "pushed_at=is.null", "published_at=gte.2026-11-04T11:00:00Z"]) {
    assert(lookup.includes(f), f);
  }
  const sent = ok.writes()[0];
  assertEquals([sent.url, sent.body], ["https://db.test/functions/v1/notification-sender", { content_item_id: ID }]);
  const no = await call("notify", { content_item_id: ID }, { item: null });
  assertEquals(no.status, 403);
  assertEquals(no.writes().length, 0);
  assertEquals((await call("notify", {}, {})).status, 400);
});

// ── the other tables ────────────────────────────────────────────────────────
Deno.test("each insert/upsert goes to its own table with its own conflict key", async () => {
  const cases: [string, unknown, string][] = [
    ["insert_insider", { team_id: "arsenal", type: "stat", title: "Five clean sheets", body: "b" }, "team_insider_items"],
    ["insert_quiz", { team_id: "arsenal", match_id: "123", headline: "h", questions: [1, 2, 3, 4, 5], share_template: "s" }, "saturday_quiz_items"],
    ["insert_live_brief", { team_id: "arsenal", match_id: "123", headline: "h", body: "b", minute: 45, trigger_label: "ht" }, "live_match_briefs"],
    ["upsert_player_card", { team_id: "arsenal", player_name: "B. Saka", summary: "s" }, "player_cards?on_conflict=team_id,player_name"],
    ["upsert_season_state", { team_id: "arsenal", state_line: "s", feeling_line: "f" }, "team_season_state?on_conflict=team_id"],
    ["upsert_content_review", { week_of: "2026-11-02", metrics: { a: 1 }, findings: [], actions: [], verdict: "v" }, "content_reviews?on_conflict=week_of"],
    ["log", { team_id: null, stage: "routine_post", status: "failure", target: "post_x:guard", error_class: "guard_integrity" }, "pipeline_health"],
  ];
  for (const [action, data, path] of cases) {
    const r = await call(action, data);
    assert(r.status < 300, `${action}: ${r.status} ${JSON.stringify(r.body)}`);
    assertEquals(r.writes().map((c) => c.url), [`https://db.test/rest/v1/${path}`], action);
  }
});

Deno.test("the other tables: rules, timestamps and limits", async () => {
  // insider: a type outside the enum, a non-URL source, a team that is not a club or country
  assertEquals((await call("insert_insider", { team_id: "arsenal", type: "rumour", title: "t", body: "b" })).status, 400);
  assertEquals((await call("insert_insider", { team_id: "arsenal", type: "history", title: "t", body: "b", source_url: "javascript:x" })).status, 400);
  assertEquals((await call("insert_insider", { team_id: "arsenal", type: "stat", title: "t", body: "b" }, { count: HOURLY.insider })).status, 429);
  // quiz is exactly five questions
  assertEquals((await call("insert_quiz", { team_id: "arsenal", questions: [1, 2] })).status, 400);
  // season state stamps generated_at only with the prose (post_season_state.sh)
  const fx = await call("upsert_season_state", { team_id: "arsenal", next_fixture: { a: 1 }, generated_at: "2020-01-01" });
  assert(!("generated_at" in (fx.writes()[0].body as Record<string, unknown>)));
  const pr = await call("upsert_season_state", { team_id: "arsenal", summary: "s" });
  assertEquals((pr.writes()[0].body as Record<string, unknown>).generated_at, "2026-11-04T12:00:00Z");
  // a content review only for the week just gone
  assertEquals((await call("upsert_content_review", { week_of: "2026-01-05", metrics: { a: 1 } })).status, 400);
  // log: only the routines' own stages
  assertEquals((await call("log", { stage: "apns_send", status: "success" })).status, 400);
  assertEquals((await call("log", { stage: "routine_post", status: "success" }, { count: HOURLY.log })).status, 429);
  // player card with a stray column the table has (api_player_id) is still the card, minus it
  const pc = await call("upsert_player_card", { team_id: "arsenal", player_name: "B. Saka", api_player_id: 1 });
  assertEquals(pc.headers.get("x-routine-dropped"), "api_player_id");
});

Deno.test("feed_status: only last_status/last_ok_at of sources that exist; trust comes from the table", async () => {
  const sources = [
    { url: "https://a.test/rss", team_id: "arsenal", name: "A", kind: "sky", trust: "record" },
    { url: "https://b.test/rss", team_id: "arsenal", name: "B", kind: "local", trust: "colour" },
  ];
  const r = await call("feed_status", [
    { url: "https://a.test/rss", trust: "colour", last_status: 200, last_ok_at: "1999-01-01T00:00:00Z" },
    { url: "https://b.test/rss", last_status: 404 },
    { url: "https://evil.test/rss", team_id: "arsenal", trust: "record", last_status: 200 },
  ], { sources });
  assertEquals(r.status, 201);
  const [ok, notOk] = r.writes().map((c) => c.body as Record<string, unknown>[]);
  assertEquals(ok, [{ ...sources[0], last_status: 200, last_ok_at: "2026-11-04T12:00:00Z" }]);
  assertEquals(notOk, [{ ...sources[1], last_status: 404 }]);
});

// ── team pages ──────────────────────────────────────────────────────────────
Deno.test("upsert_team_page: the merge, the verified manager, creation rules", async () => {
  const page = { schema_version: 1, cards: { basics: { nickname: "Gunners" }, injuries: { players: ["x"] },
    ones_to_know: { players: [], talking_point: "old", out: ["y"] }, next_fixture: { opponent: "Spurs", preview: "p" } } };
  const r = await call("upsert_team_page", { team_id: "arsenal", basics: { nickname: "Arse" }, form_summary: "f",
    top_players: [{ name: "B. Saka" }], next_fixture_preview: "colour", manager_name: "Mikel Arteta",
    content: { cards: {} } }, { page });
  assertEquals(r.status, 201);
  const body = r.writes()[0].body as { content: { cards: Record<string, Record<string, unknown>>; last_routine_run: string } };
  const c = body.content.cards;
  assertEquals(c.basics, { nickname: "Gunners" }); // curated seed never overwritten
  assertEquals(c.injuries, { players: ["x"] }); // the generator's numbers survive
  assertEquals(c.ones_to_know, { players: [{ name: "B. Saka" }], updated_at: "2026-11-04T12:00:00Z" });
  assertEquals(c.next_fixture, { opponent: "Spurs", preview: "p", preview_colour: "colour", preview_fixture_id: null });
  assertEquals(body.content.last_routine_run, "2026-11-04T12:00:00Z");
  assertEquals(r.headers.get("x-routine-dropped"), "content");

  const wrongMgr = await call("upsert_team_page", { team_id: "arsenal", manager_name: "Albert Stuivenberg" }, { page });
  assertEquals([wrongMgr.status, wrongMgr.writes().length], [400, 0]);
  const notPl = await call("upsert_team_page", { team_id: "barcelona", form_summary: "f" }, { team: null });
  assertEquals([notPl.status, notPl.writes().length], [400, 0]);
  const create = await call("upsert_team_page", { team_id: "arsenal", form_summary: "f" }, { page: null });
  assertEquals([create.status, create.writes().length], [400, 0]);
  const limited = await call("upsert_team_page", { team_id: "arsenal", form_summary: "f" }, { page, count: HOURLY.team_pages });
  assertEquals(limited.status, 429);
});

Deno.test("mergeTeamPage drops ones_to_know.talking_point even with no new players (TEAM-01-51)", () => {
  const m = mergeTeamPage({ cards: { ones_to_know: { players: [], talking_point: "old line" } } }, { form_summary: "f" }, "T");
  assertEquals((m.cards as Record<string, Record<string, unknown>>).ones_to_know, { players: [] });
});
