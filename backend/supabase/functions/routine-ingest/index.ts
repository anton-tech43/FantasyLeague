// routine-ingest — the claude.ai routines' only credential to the database.
// Everything is in ingest.ts (pure, tested by ingest.test.ts); this file only
// wires the environment. Deployed with --no-verify-jwt: the caller presents
// ROUTINE_INGEST_KEY in x-routine-key, which is a random secret, not a JWT.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { handle } from "./ingest.ts";

serve((req) =>
  handle(req, {
    ingestKey: Deno.env.get("ROUTINE_INGEST_KEY"),
    supabaseUrl: Deno.env.get("SUPABASE_URL"),
    serviceKey: Deno.env.get("SERVICE_KEY"),
  })
);
