// Broadcast-channel Live Activities: the request shapes Apple documents, and
// who gets a channel start under each LA_CHANNELS mode.
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  buildBroadcastRequest,
  buildLiveActivityAps,
  channelManagementBase,
  LA_CHANNEL_STORAGE_POLICY,
} from "./apns-client.ts";
import { channelColumn, laChannelMode, laChannelPrefixes, wantsChannel } from "./la-channels.ts";

const cs = { homeScore: 1, awayScore: 0, statusLabel: "2H", elapsed: 60, clockStart: null };

Deno.test("start with a channel carries input-push-channel next to the attributes", () => {
  const aps = buildLiveActivityAps({
    event: "start",
    contentState: cs,
    attributes: { fixtureId: 1, homeName: "A", awayName: "B", homeFlag: "", awayFlag: "" },
    alert: { title: "A v B", body: "It's kicked off." },
    inputPushChannel: "dHN0LXNyY2gtY2hubA==",
    staleSeconds: 1200,
  }, 1000);
  assertEquals(aps["input-push-channel"], "dHN0LXNyY2gtY2hubA==");
  assertEquals(aps["attributes-type"], "MatchActivityAttributes");
  assertEquals(aps["stale-date"], 2200);
  assertEquals(aps["timestamp"], 1000);
});

Deno.test("a token start has no input-push-channel; an update never does", () => {
  const start = buildLiveActivityAps({ event: "start", contentState: cs }, 1);
  assertEquals("input-push-channel" in start, false);
  const upd = buildLiveActivityAps({ event: "update", contentState: cs, inputPushChannel: "x" }, 1);
  assertEquals("input-push-channel" in upd, false);
  assertEquals("attributes-type" in upd, false);
});

Deno.test("end carries the dismissal date", () => {
  const aps = buildLiveActivityAps({ event: "end", contentState: cs, dismissalSeconds: 1800 }, 100);
  assertEquals(aps["dismissal-date"], 1900);
});

Deno.test("broadcast request: path, headers, expiration 0 on a no-storage channel", () => {
  assertEquals(LA_CHANNEL_STORAGE_POLICY, 0);
  const r = buildBroadcastRequest("com.goaldigger.app", "production", "Y2g=", { event: "update" }, 5);
  assertEquals(r.url, "https://api.push.apple.com/4/broadcasts/apps/com.goaldigger.app");
  assertEquals(r.headers["apns-push-type"], "liveactivity");
  assertEquals(r.headers["apns-channel-id"], "Y2g=");
  assertEquals(r.headers["apns-priority"], "5");
  assertEquals(r.headers["apns-expiration"], "0");
  assertEquals("apns-topic" in r.headers, false);
  assertEquals("Authorization" in r.headers, false);
  assertEquals(JSON.parse(r.body), { aps: { event: "update" } });
  const dev = buildBroadcastRequest("com.goaldigger.app", "development", "Y2g=", {}, 10);
  assertEquals(dev.url, "https://api.sandbox.push.apple.com/4/broadcasts/apps/com.goaldigger.app");
});

Deno.test("channel management hosts and ports per environment", () => {
  assertEquals(channelManagementBase("production"), "https://api-manage-broadcast.push.apple.com:2196");
  assertEquals(channelManagementBase("development"), "https://api-manage-broadcast.sandbox.push.apple.com:2195");
  assertEquals(channelColumn("production"), "la_channel_id");
  assertEquals(channelColumn("development"), "la_channel_id_dev");
});

Deno.test("LA_CHANNELS: unset or unknown is off, and off reaches nobody", () => {
  assertEquals(laChannelMode(undefined), "off");
  assertEquals(laChannelMode("yes"), "off");
  assertEquals(laChannelMode(" ON "), "on");
  assertEquals(wantsChannel("off", new Set(), { token: "ab".repeat(40), darwin_major: 25 }), false);
});

Deno.test("allowlist matches the first 16 hex chars, case-insensitive, ignoring iOS", () => {
  const p = laChannelPrefixes(" ABCDEF0123456789 , short, 0000000000000000ffff");
  assertEquals([...p].sort(), ["0000000000000000", "abcdef0123456789"]);
  assertEquals(wantsChannel("allowlist", p, { token: "abcdef0123456789" + "00".repeat(40), darwin_major: 23 }), true);
  assertEquals(wantsChannel("allowlist", p, { token: "abcdef012345678a" + "00".repeat(40), darwin_major: 25 }), false);
});

Deno.test("on: Darwin 24+ only, unknown iOS stays on the token path", () => {
  const t = "ab".repeat(40);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 24 }), true);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 23 }), false);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: null }), false);
});
