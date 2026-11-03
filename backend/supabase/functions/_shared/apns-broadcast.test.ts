// Broadcast-channel Live Activities: the request shapes Apple documents, and
// who gets a channel start under each LA_CHANNELS mode.
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  buildBroadcastRequest,
  buildLiveActivityAps,
  channelManagementBase,
  LA_CHANNEL_STORAGE_POLICY,
} from "./apns-client.ts";
import { channelList, channelRetireDue, laChannelMode, laChannelPrefixes, parseLaChannels, wantsChannel } from "./la-channels.ts";

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
  assertEquals((aps["attributes"] as Record<string, unknown>).viaChannel, true);
});

Deno.test("a token start has no input-push-channel; an update never does", () => {
  const start = buildLiveActivityAps({ event: "start", contentState: cs,
    attributes: { fixtureId: 1, homeName: "A", awayName: "B", homeFlag: "", awayFlag: "" } }, 1);
  assertEquals("input-push-channel" in start, false);
  assertEquals("viaChannel" in (start["attributes"] as Record<string, unknown>), false);
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
});

Deno.test("la_channels: up to three per environment, junk ignored, listed flat", () => {
  const ch = parseLaChannels({
    production: { home: "H", away: "A", neutral: "N", other: "x" },
    development: { home: 5, away: "" },
    staging: { home: "S" },
  });
  assertEquals(ch, { production: { home: "H", away: "A", neutral: "N" } });
  assertEquals(channelList(ch).map((c) => `${c.env}:${c.audience}:${c.channelId}`), [
    "production:home:H", "production:away:A", "production:neutral:N",
  ]);
  assertEquals(parseLaChannels(null), {});
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

Deno.test("on: Darwin 24+ on build 16+ only, unknown iOS or build stays on the token path", () => {
  const t = "ab".repeat(40);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 24, app_build: 16 }), true);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 27, app_build: 18 }), true);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 23, app_build: 16 }), false);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: null, app_build: 16 }), false);
  // P-C4 (bug hunt 2026-11-03): only build 16 has been shown a channel start.
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 25, app_build: 12 }), false);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 25, app_build: null }), false);
  assertEquals(wantsChannel("on", new Set(), { token: t, darwin_major: 25 }), false);
});

// P-C7 (bug hunt 2026-11-03): a no-storage channel cannot hold the end for a
// phone offline at full time, so a finished match keeps its channel for the
// sweep's second end, three hours past kickoff.
Deno.test("channelRetireDue: a finished match keeps its channels until kickoff + 3 h", () => {
  const ko = Date.parse("2026-11-03T20:00:00Z");
  const at = (h: number) => ko + h * 3600_000;
  const ft = { ended: true, finished: true, live: false, kickoffMs: ko };
  assertEquals(channelRetireDue({ ...ft, nowMs: at(2) }), false, "just after the whistle: kept");
  assertEquals(channelRetireDue({ ...ft, nowMs: at(2.9) }), false, "still inside the hour");
  assertEquals(channelRetireDue({ ...ft, nowMs: at(3.1) }), true, "then the last end and delete");
  const abd = { ended: true, finished: false, live: false, kickoffMs: ko };
  assertEquals(channelRetireDue({ ...abd, nowMs: at(0.5) }), true, "abandoned: at once");
  const live = { ended: false, finished: false, live: true, kickoffMs: ko };
  assertEquals(channelRetireDue({ ...live, nowMs: at(3.5) }), false, "extra time still being played");
  assertEquals(channelRetireDue({ ...live, nowMs: at(6.1) }), true, "six hours: always");
});
