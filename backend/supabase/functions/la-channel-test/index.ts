// la-channel-test/index.ts
//
// Test harness for broadcast-channel Live Activities (docs/LIVE_ACTIVITY_PLAN.md,
// "Channel test procedure"). Reaches exactly one phone: the push-to-start
// token whose first 16 hex chars the caller names. A fake fixture
// (999000xxx, Arsenal v Liverpool) that exists nowhere else; nothing is
// written to match_status_state.
//
// Server-only, same gate as every cron/internal function (service key or the
// cron key, never the anon key). Trigger from SQL with net.http_post and
// get_cron_service_key(), as pg_cron does; the procedure has the statement.
//
// Body:
//   { token_prefix, step: "run" }      start (0-0) → wait → update (1-0) →
//                                      wait → end (FT 2-0) → delete channel
//   { token_prefix, step: "probe" }    create a channel in the token's
//                                      environment, broadcast one update to it
//                                      (nobody subscribed), delete it; no phone
//   { token_prefix, step: "start" }    create a channel, push-to-start on it;
//                                      returns channel_id and fixture_id
//   { token_prefix, step: "update" | "end", channel_id, fixture_id }
//                                      one broadcast; "end" deletes the channel
//   wait_seconds (run only): default 20, at most 60.
//
// Every APNs response (status + reason) goes to pipeline_health stage la_send
// and back in the HTTP response.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireServiceAuth } from "../_shared/require-service-auth.ts";
import { getSupabaseClient } from "../_shared/supabase-client.ts";
import { fanOutRow } from "../_shared/pipeline-logger.ts";
import {
  type APNsEnvironment,
  createChannel,
  deleteChannel,
  type LiveActivityContentState,
  sendBroadcast,
  sendLiveActivityPush,
} from "../_shared/apns-client.ts";

type Step = "run" | "probe" | "start" | "update" | "end";
interface Outcome {
  step: string;
  target: string;
  success: boolean;
  status?: number;
  reason?: string;
  channel_id?: string;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body, null, 2), { status, headers: { "Content-Type": "application/json" } });

serve(async (req) => {
  const denied = requireServiceAuth(req);
  if (denied) return denied;
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const prefix = String(body?.token_prefix ?? "").toLowerCase();
  const step = String(body?.step ?? "run") as Step;
  if (!/^[0-9a-f]{16}$/.test(prefix)) return json({ error: "token_prefix must be 16 hex chars" }, 400);
  if (!["run", "probe", "start", "update", "end"].includes(step)) return json({ error: "unknown step" }, 400);

  const supabase = getSupabaseClient();
  const { data: rows, error } = await supabase.from("live_activity_tokens")
    .select("token, apns_environment, app_build, darwin_major, updated_at")
    .eq("kind", "push_to_start").ilike("token", `${prefix}%`)
    .order("updated_at", { ascending: false }).limit(2);
  if (error) return json({ error: `token lookup failed: ${error.message}` }, 500);
  if (!rows || rows.length === 0) return json({ error: "no push_to_start token with that prefix" }, 404);
  if (rows.length > 1) return json({ error: "prefix matches more than one token; use a longer one" }, 409);
  const row = rows[0];
  const env: APNsEnvironment = row.apns_environment === "production" ? "production" : "development";

  const fixtureId = Number(body?.fixture_id) || 999000000 + Math.floor(Math.random() * 1000);
  const outcomes: Outcome[] = [];
  const log = async (o: Outcome) => {
    outcomes.push(o);
    try {
      await supabase.from("pipeline_health").insert({
        stage: "la_send",
        target: o.target,
        ...fanOutRow(`la-channel-test ${o.step} ${env}`, [o]),
      });
    } catch (e) {
      console.warn("la-channel-test log failed:", e instanceof Error ? e.message : String(e));
    }
  };

  const state = (home: number, away: number, statusLabel: string, minute: number | null): LiveActivityContentState => ({
    homeScore: home,
    awayScore: away,
    statusLabel,
    elapsed: minute,
    clockStart: minute != null ? Math.round(Date.now() / 1000 - minute * 60) : null,
  });

  const create = async (): Promise<string | null> => {
    const r = await createChannel(env);
    await log({ step: "create", target: `la:${fixtureId}:create:channel:${env}`, ...r });
    return r.success && r.channelId ? r.channelId : null;
  };
  const remove = async (channelId: string) => {
    const r = await deleteChannel(env, channelId);
    await log({ step: "delete", target: `la:${fixtureId}:delete:channel:${env}`, ...r });
  };
  const start = async (channelId: string) => {
    const r = await sendLiveActivityPush(row.token, {
      event: "start",
      attributes: {
        fixtureId,
        homeName: "Arsenal",
        awayName: "Liverpool",
        homeFlag: "",
        awayFlag: "",
        groupLabel: "CHANNEL TEST",
      },
      contentState: state(0, 0, "1H", 1),
      alert: { title: "Arsenal v Liverpool", body: "Channel test: kicked off." },
      staleSeconds: 1200,
      inputPushChannel: channelId,
      environment: env,
      priority: 10,
    });
    await log({ step: "start", target: `la:${fixtureId}:start:p10:channel`, success: r.success, status: r.status, reason: r.reason });
  };
  const update = async (channelId: string) => {
    const r = await sendBroadcast(channelId, {
      event: "update", contentState: state(1, 0, "1H", 2), staleSeconds: 1200, environment: env, priority: 10,
    });
    await log({ step: "update", target: `la:${fixtureId}:update:p10:channel`, success: r.success, status: r.status, reason: r.reason });
  };
  const end = async (channelId: string) => {
    // Gone two minutes after the end, so the test card does not linger.
    const r = await sendBroadcast(channelId, {
      event: "end", contentState: state(2, 0, "FT", null), dismissalSeconds: 120, environment: env, priority: 10,
    });
    await log({ step: "end", target: `la:${fixtureId}:end:p10:channel`, success: r.success, status: r.status, reason: r.reason });
  };
  const sleep = (s: number) => new Promise((r) => setTimeout(r, s * 1000));

  const token = { prefix, environment: env, app_build: row.app_build, darwin_major: row.darwin_major, updated_at: row.updated_at };

  if (step === "probe") {
    // A broadcast to a channel nobody has subscribed to yet: checks the
    // headers and the endpoint without reaching any phone.
    const id = await create();
    if (id) {
      await update(id);
      await remove(id);
    }
    return json({ step, fixture_id: fixtureId, token, outcomes });
  }

  if (step === "update" || step === "end") {
    const channelId = String(body?.channel_id ?? "");
    if (!channelId || !body?.fixture_id) return json({ error: "channel_id and fixture_id from the start step are required" }, 400);
    if (step === "update") await update(channelId);
    else {
      await end(channelId);
      await remove(channelId);
    }
    return json({ step, fixture_id: fixtureId, channel_id: channelId, token, outcomes });
  }

  const channelId = await create();
  if (!channelId) return json({ step, fixture_id: fixtureId, token, outcomes }, 502);
  await start(channelId);
  if (step === "start") return json({ step, fixture_id: fixtureId, channel_id: channelId, token, outcomes });

  // run
  const wait = Math.min(Math.max(Number(body?.wait_seconds) || 20, 1), 60);
  await sleep(wait);
  await update(channelId);
  await sleep(wait);
  await end(channelId);
  await remove(channelId);
  return json({ step, fixture_id: fixtureId, channel_id: channelId, token, outcomes });
});
