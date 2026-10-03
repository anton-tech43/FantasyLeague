// deno test --allow-env backend/supabase/functions/_shared/require-service-auth.test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { requireServiceAuth, timingSafeEqual } from "./require-service-auth.ts";

Deno.test("timingSafeEqual", () => {
  assertEquals(timingSafeEqual("sb_secret_abc", "sb_secret_abc"), true);
  assertEquals(timingSafeEqual("sb_secret_abc", "sb_secret_abd"), false);
  assertEquals(timingSafeEqual("sb_secret_abc", "sb_secret_ab"), false);
  assertEquals(timingSafeEqual("", ""), true);
});

Deno.test("requireServiceAuth accepts any configured service key, nothing else (QA-14)", () => {
  Deno.env.set("SERVICE_KEY", "svc-key");
  Deno.env.set("CRON_AUTH_KEY", "cron-key");
  Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
  const req = (auth?: string) =>
    new Request("http://x", auth === undefined ? {} : { headers: { Authorization: auth } });
  assertEquals(requireServiceAuth(req("Bearer svc-key")), null);
  assertEquals(requireServiceAuth(req("Bearer cron-key")), null);
  assertEquals(requireServiceAuth(req("Bearer anon-key"))?.status, 401);
  assertEquals(requireServiceAuth(req("Bearer "))?.status, 401);
  assertEquals(requireServiceAuth(req())?.status, 401);
});
