-- 115_anon_is_read_only.sql
-- Take the write privileges off the key that ships in the App Store binary.
--
-- Found while checking `players` during the stale-data audit on 2026-09-23:
-- `anon` held INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER on 23
-- tables, `players` and `teams` and `content_items` and `team_pages` among
-- them. Only RLS stood between the publishable key and the whole content
-- model. RLS does hold — a write probe with the shipped key is refused with
-- 42501 — so this was not exploitable, and that is exactly why it is worth
-- fixing now rather than after somebody adds a table and forgets a policy.
--
-- It was never a decision. Supabase's ALTER DEFAULT PRIVILEGES on `public`
-- grants `arwdDxtm` to anon and authenticated for every new table, so every
-- migration we have ever written inherited the lot. Revoking table by table
-- without changing that would last until the next CREATE TABLE, so both are
-- here.
--
-- What the app actually needs, checked rather than assumed: it makes **no**
-- POST, PATCH or DELETE at all. Every REST call is a GET against
-- content_items, team_pages, team_season_state, team_insider_items,
-- player_cards, players, teams and my_turn_content, and both writes go through
-- `register_device_token` and `register_la_token`, which are SECURITY DEFINER
-- and run as their owner rather than as anon. So anon needs SELECT, and
-- nothing else.
--
-- THE ONE EXCEPTION is `device_tokens`. Version 2.2 is in the App Store and
-- still PATCHes the tier directly; 2.3 removes that call. Its INSERT and UPDATE
-- are therefore re-granted below and stay until
-- `107_drop_anon_token_write.sql.PENDING_APP_RELEASE` is applied, which is the
-- migration that finishes this job. Do not fold the two together.

BEGIN;

-- MAINTAIN is in the list because it is not in `information_schema`'s grant
-- view, so it survives a revoke you thought was complete: anon held it on 22 of
-- the 25 tables here. It carries VACUUM, ANALYZE, REINDEX, CLUSTER and REFRESH
-- MATERIALIZED VIEW — no data, but work anybody could ask a small instance to
-- do, on the compute that ran out in August.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
    ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- 2.2's tier PATCH. Remove with migration 107, not before.
GRANT INSERT, UPDATE ON public.device_tokens TO anon, authenticated;

-- And for everything created from here on. Only the `postgres` default is ours
-- to change; migrations run as postgres, so that is the one that matters.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
  ON TABLES FROM anon, authenticated;

COMMIT;

-- Verification:
--   -- nothing but device_tokens may be written by anon (expect one row)
--   SELECT c.relname, string_agg(DISTINCT g.privilege_type, ',' ORDER BY g.privilege_type)
--     FROM information_schema.role_table_grants g
--     JOIN pg_class c ON c.relname = g.table_name AND c.relnamespace = 'public'::regnamespace
--    WHERE g.grantee = 'anon' AND g.privilege_type <> 'SELECT'
--    GROUP BY 1;
--   -- and the app's reads still answer 200
