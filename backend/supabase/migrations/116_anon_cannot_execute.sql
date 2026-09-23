-- 116_anon_cannot_execute.sql
-- Close the functions that four earlier migrations already believed they had
-- closed.
--
-- Migration 115 took the write privileges off `anon` on 23 tables. Functions
-- were left, and the hole there is sharper, because a SECURITY DEFINER
-- function bypasses RLS by design — 115 does not protect it at all.
--
-- Seven SECURITY DEFINER functions are callable with the publishable key that
-- ships in the App Store binary. Two are meant to be. Five are not:
--
--   claim_match_watcher_tick  takes the minute's lease. match-watcher runs
--                             every minute and skips when it loses, so one
--                             caller a minute silently stops kickoff, goal,
--                             half-time and full-time pushes and Live
--                             Activity. Nothing looks wrong: match-watcher
--                             reports its ordinary "tick already claimed".
--   claim_fixture_marker      the same per push. Claim FT_PUSH for a fixture
--                             and that push never goes out.
--   prune_departed_players    DELETEs from players.
--   sync_players_from_squads  a full upsert over 1 819 players.
--   sync_player_stats_from_raw  likewise. Both callable in a loop against the
--                             smallest instance — the compute that fell over
--                             on 30 August.
--
-- THIS IS NOT A MISSING DECISION. Migrations 084, 095, 096 and 103 each wrote
-- exactly what they wanted:
--
--     REVOKE EXECUTE ON FUNCTION public.claim_match_watcher_tick(timestamptz)
--       FROM PUBLIC;
--     GRANT  EXECUTE ON FUNCTION public.claim_match_watcher_tick(timestamptz)
--       TO service_role;
--
-- `FROM PUBLIC` removes the implicit privilege. But `anon` and `authenticated`
-- hold an EXPLICIT grant from Supabase's ALTER DEFAULT PRIVILEGES, and
-- `FROM PUBLIC` does not touch it. All four read as though they locked the
-- function and none of them did — the same shape as 072's wrong policy names
-- and the same as 115's inherited table grants. Migration 108 is the only one
-- that got it right, because it wrote `FROM PUBLIC, anon, authenticated`.
--
-- Verified against production on 2026-09-23:
--   POST /rest/v1/rpc/sync_players_from_squads with the shipped key -> HTTP 200.
--
-- Every caller was inventoried first, and none of the eleven below is called
-- with the anon key. The two claim_* functions are the only ones of the five
-- that travel over PostgREST at all, from match-watcher, whose client resolves
-- SERVICE_KEY ?? SUPABASE_SERVICE_ROLE_KEY (_shared/supabase-client.ts:19-37)
-- and so runs as service_role. The three player-sync functions never touch
-- PostgREST: they are called from pg_cron job bodies and manual psql, both as
-- postgres. The routines repo contains no RPC calls at all.
--
-- Written out one function at a time rather than ON ALL FUNCTIONS, so the file
-- reads as the list of what is closed — and because ALL FUNCTIONS would strip
-- the two RPCs and then grant them back, which is exactly the shape that makes
-- a revoke hard to review.

BEGIN;

-- SECURITY DEFINER, and therefore not covered by RLS or by migration 115.
REVOKE EXECUTE ON FUNCTION public.claim_fixture_marker(p_fixture_id integer, p_marker text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.claim_match_watcher_tick(at timestamp with time zone)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prune_departed_players()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_player_stats_from_raw()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_players_from_squads()
  FROM PUBLIC, anon, authenticated;

-- SECURITY INVOKER, so harmless after 115 (they run AS anon, and anon can no
-- longer write). Service tooling all the same, with no business on the public
-- surface.
REVOKE EXECUTE ON FUNCTION public.check_pipeline_heartbeat()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.poll_leagues(at timestamp with time zone)
  FROM PUBLIC, anon, authenticated;

-- The name-matching helpers added by 110 and 113. Pure functions; taken off
-- the public surface so what is left is the two RPCs and nothing else.
REVOKE EXECUTE ON FUNCTION public.decode_feed_entities(txt text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fold_name(txt text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.player_name_tokens(txt text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.resolve_player_id(p_team_id text, p_name text)
  FROM PUBLIC, anon, authenticated;

-- NOT touched, deliberately: check_token_rate_limit, player_cards_link_player,
-- suppress_wc_result_recap_push and touch_la_tokens_updated_at all return
-- `trigger`. PostgREST cannot expose them, so revoking buys nothing and would
-- raise a question about whether a trigger function needs the invoking role's
-- EXECUTE when it fires — a question worth not having to answer.
--
-- NOT touched either: register_device_token and register_la_token. They are
-- the app's only write path, granted correctly by 082 and 083.

-- And for every function written from here on. Only the `postgres` default ACL
-- is ours to change, and it is the one that applies: every function in `public`
-- is owned by postgres and migrations run as postgres.
--
-- CONSEQUENCE, for whoever adds the next RPC: a new function will NOT come out
-- callable from the app. Say so explicitly, next to the CREATE FUNCTION:
--     GRANT EXECUTE ON FUNCTION public.<name>(<args>) TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

COMMIT;

-- Verification — the query that would have caught 084, 095, 096 and 103:
--   SELECT p.proname, has_function_privilege('anon', p.oid, 'EXECUTE')
--     FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
--      AND has_function_privilege('anon', p.oid, 'EXECUTE') ORDER BY 1;
-- Expect exactly register_device_token, register_la_token and the four
-- trigger functions.
