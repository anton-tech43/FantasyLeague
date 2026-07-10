-- 076_world_championship_entity.sql
-- Adds a pseudo-entity row to `teams` representing the World Championship
-- tournament itself (not a participating country), so content_items can hold
-- a tournament-wide feed item (e.g. "WC Final today") with a real team_id FK
-- instead of NULL or a made-up country slug.
--
-- Why the row exists:
--   - content_items.team_id is `NOT NULL REFERENCES teams(id)` (001_initial_
--     schema.sql). Tournament-wide news ("Group stage draw", "Final kicks off
--     tonight") has no single country to attach to, so it needs a team_id
--     that legitimately means "the whole tournament".
--   - Every user who follows ANY WC country (or none) should see this feed,
--     the same way everyone sees it regardless of which of the 48 countries
--     they picked.
--
-- Why it's invisible to the iterators that walk `teams` expecting real clubs
-- or countries (so this row can't accidentally get "fetched" or "pushed" like
-- a participant):
--   - data-fetcher (functions/data-fetcher/index.ts) skips any team with no
--     league_id: `if (!team.league_id) { ...skip... }`. This row's league_id
--     is NULL, so it's never sent to API-Football.
--   - match-watcher's team-iteration queries require league_id IS NOT NULL
--     (it fetches fixtures per league_id/season) — NULL league_id excludes it
--     the same way.
--   - matchday-reminder / morning-push filter `WHERE entity_type = 'country'`
--     when fanning out WC push content (see 063_matchday_reminder.sql,
--     065_suppress_result_recap_push.sql). entity_type='tournament' fails
--     that filter, so this row is never picked up for per-country push.
--
-- Net effect: the row exists purely as a valid FK target for tournament-wide
-- content_items rows; every per-team pipeline (fetch, push, live activity)
-- ignores it by construction, not by a special-cased exclusion list.

-- ---------------------------------------------------------------------------
-- 1. Widen the entity_type CHECK to allow 'tournament'.
-- ---------------------------------------------------------------------------
-- The constraint was added inline via `ALTER TABLE teams ADD COLUMN
-- entity_type TEXT NOT NULL DEFAULT 'club' CHECK (entity_type IN ('club',
-- 'country'))` in 032_wc_entity_type.sql. Postgres auto-names a column CHECK
-- added this way `<table>_<column>_check` — verified against this DB's
-- naming for other inline-added CHECKs in this migration set (e.g.
-- `valid_apns_token`/`valid_la_token` are named explicitly via CONSTRAINT,
-- but unnamed ones like this follow the default `teams_entity_type_check`
-- convention). Confirm before applying:
--   SELECT conname FROM pg_constraint
--    WHERE conrelid = 'teams'::regclass AND contype = 'c'
--      AND pg_get_constraintdef(oid) ILIKE '%entity_type%';
-- Expected: teams_entity_type_check

ALTER TABLE teams DROP CONSTRAINT teams_entity_type_check;

ALTER TABLE teams
  ADD CONSTRAINT teams_entity_type_check
    CHECK (entity_type IN ('club', 'country', 'tournament'));

-- ---------------------------------------------------------------------------
-- 2. Insert the pseudo-entity row (idempotent).
-- ---------------------------------------------------------------------------

INSERT INTO teams (id, display_name, short_name, api_football_id, entity_type, league_id)
VALUES ('world_championship', 'World Championship', 'World Championship', 0, 'tournament', NULL)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Verification:
-- ---------------------------------------------------------------------------
-- SELECT id, display_name, entity_type, league_id, api_football_id
--   FROM teams WHERE id = 'world_championship';
-- Expected: one row, entity_type='tournament', league_id IS NULL, api_football_id=0.
