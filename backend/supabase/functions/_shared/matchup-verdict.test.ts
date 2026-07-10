import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  CLUB_FAVORITE_GAP,
  preMatchVerdict,
  resultFraming,
  WC_FAVORITE_GAP,
} from "./matchup-verdict.ts";

Deno.test("preMatchVerdict: clear favorite when I'm >= gap places stronger", () => {
  // Spain (2) vs Cape Verde (67): diff 65 => clear favorite.
  assertEquals(preMatchVerdict(2, 67)?.tag, "likely_win");
  // England (4) vs Iran (20): diff 16 (>= 12) => favorite.
  assertEquals(preMatchVerdict(4, 20)?.tag, "likely_win");
});

Deno.test("preMatchVerdict: clear underdog when I'm >= gap places weaker", () => {
  // Sweden (38) vs USA (17): diff -21 => likely loss.
  assertEquals(preMatchVerdict(38, 17)?.tag, "likely_loss");
});

Deno.test("preMatchVerdict: close ranks => could go either way", () => {
  // Argentina (1) vs Germany (10): diff 9 (< 12) => even.
  assertEquals(preMatchVerdict(1, 10)?.tag, "even");
  // Sweden (38) vs Norway (31): diff -7 => even.
  assertEquals(preMatchVerdict(38, 31)?.tag, "even");
});

Deno.test("preMatchVerdict: boundary is inclusive at exactly the gap", () => {
  assertEquals(preMatchVerdict(10, 22)?.tag, "likely_win"); // diff 12
  assertEquals(preMatchVerdict(22, 10)?.tag, "likely_loss"); // diff -12
  assertEquals(preMatchVerdict(10, 21)?.tag, "even"); // diff 11
});

Deno.test("preMatchVerdict: unknown rank => no tag", () => {
  assertEquals(preMatchVerdict(null, 10), null);
  assertEquals(preMatchVerdict(10, undefined), null);
});

Deno.test("preMatchVerdict: clubs use the smaller league-position gap", () => {
  // 1st vs 7th: diff 6 (>= 5) => favorite on the club scale.
  assertEquals(preMatchVerdict(1, 7, CLUB_FAVORITE_GAP)?.tag, "likely_win");
  // 8th vs 11th: diff 3 (< 5) => even.
  assertEquals(preMatchVerdict(8, 11, CLUB_FAVORITE_GAP)?.tag, "even");
});

Deno.test("resultFraming: favourite winning is as expected", () => {
  assertEquals(resultFraming(2, 67, 3, 0)?.framing, "as_expected");
});

Deno.test("resultFraming: favourite only drawing is a dropped-points surprise", () => {
  // Spain (2) 0-0 a much lower side => dropped points.
  assertEquals(resultFraming(2, 67, 0, 0)?.framing, "dropped_points");
});

Deno.test("resultFraming: favourite losing is an upset", () => {
  assertEquals(resultFraming(4, 20, 0, 1)?.framing, "upset");
});

Deno.test("resultFraming: underdog winning is an upset", () => {
  assertEquals(resultFraming(38, 17, 2, 1)?.framing, "upset");
});

Deno.test("resultFraming: underdog drawing earns a good point", () => {
  assertEquals(resultFraming(38, 17, 1, 1)?.framing, "good_point");
});

Deno.test("resultFraming: underdog losing is as expected", () => {
  assertEquals(resultFraming(38, 17, 0, 2)?.framing, "as_expected");
});

Deno.test("resultFraming: even matchup => even_result regardless of score", () => {
  assertEquals(resultFraming(1, 10, 3, 0)?.framing, "even_result");
  assertEquals(resultFraming(1, 10, 0, 0)?.framing, "even_result");
});

Deno.test("resultFraming: unknown rank => null", () => {
  assertEquals(resultFraming(null, 10, 1, 0), null);
});

Deno.test("WC and CLUB gap constants are distinct and sane", () => {
  assertEquals(WC_FAVORITE_GAP > CLUB_FAVORITE_GAP, true);
});
