// deno test --allow-run --allow-net=127.0.0.1 --allow-read --allow-env backend/supabase/functions/match-watcher/secrets.test.ts
//
// Bug hunt 2026-11-03 (E-C1): with MATCHDAY_ROUTINE_URL/TOKEN unset the
// handler returned 500 before polling anything, which stopped every live push
// and Live Activity. Runs the real handler in a subprocess with only the feed
// key set and a database that refuses connections: it must get past the
// secret check to the teams query. Nothing leaves 127.0.0.1.

const PORT = 8000; // std serve's default

Deno.test("match-watcher runs a tick without the matchday routine secrets", async () => {
  const index = new URL("./index.ts", import.meta.url).pathname;
  const child = new Deno.Command(Deno.execPath(), {
    args: ["run", "--quiet", "--allow-net", "--allow-env", "--allow-read", index],
    clearEnv: true,
    env: {
      PATH: Deno.env.get("PATH") ?? "",
      HOME: Deno.env.get("HOME") ?? "",
      SUPABASE_URL: "http://127.0.0.1:9", // nothing listens: every query fails fast
      SERVICE_KEY: "secrets-test-key",
      API_FOOTBALL_KEY: "x",
    },
    stdout: "null",
    stderr: "null",
  }).spawn();
  try {
    let body = "";
    let status = 0;
    for (let i = 0; i < 120 && !status; i++) {
      try {
        const r = await fetch(`http://127.0.0.1:${PORT}/`, {
          method: "POST",
          headers: { Authorization: "Bearer secrets-test-key" },
        });
        status = r.status;
        body = await r.text();
      } catch {
        await new Promise((r) => setTimeout(r, 500));
      }
    }
    if (body.includes("MATCHDAY_ROUTINE")) throw new Error(`still gated on the routine secrets: ${body}`);
    if (!body.includes("teams query failed")) throw new Error(`expected to reach the teams query, got ${status} ${body}`);
  } finally {
    child.kill();
    await child.status;
  }
});
