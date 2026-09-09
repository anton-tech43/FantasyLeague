-- 100_players_season_stats.sql
-- The stats we already download, stored (2026-09-09).
--
-- data-fetcher pulls /players?team=&season= once a day (source
-- api_football_players_stats, ~40 calls). The payload carries goals, assists,
-- starts, cards, saves, rating, captaincy, nationality and age per player per
-- competition; sync_player_stats_from_raw() (095) kept only appearances and
-- minutes. The Quiz's "His squad" therefore had nothing to say about a player
-- beyond his face and his position ("When the camera finds him: There's
-- Moore."), and a star read exactly like a fourth-choice keeper.
--
-- Season totals for THE CLUB across competitions, plus league-only goals and
-- starts (league 39) so "started every league game" can be checked against the
-- table's games played. `rating` is API-Football's own model: a minutes-weighted
-- mean, shown as the feed's rating, never as a fact of form (DATA_SOURCES.md).
-- Same payload, same cadence, $0.

ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS goals            integer,
  ADD COLUMN IF NOT EXISTS assists          integer,
  ADD COLUMN IF NOT EXISTS starts           integer,
  ADD COLUMN IF NOT EXISTS sub_appearances  integer,
  ADD COLUMN IF NOT EXISTS yellow_cards     integer,
  ADD COLUMN IF NOT EXISTS red_cards        integer,
  ADD COLUMN IF NOT EXISTS saves            integer,
  ADD COLUMN IF NOT EXISTS conceded         integer,
  ADD COLUMN IF NOT EXISTS rating           numeric(4,2),
  ADD COLUMN IF NOT EXISTS captain          boolean,
  ADD COLUMN IF NOT EXISTS nationality      text,
  ADD COLUMN IF NOT EXISTS age              integer,
  ADD COLUMN IF NOT EXISTS league_goals     integer,
  ADD COLUMN IF NOT EXISTS league_starts    integer;

CREATE OR REPLACE FUNCTION public.sync_player_stats_from_raw()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  n integer;
BEGIN
  WITH latest AS (
    SELECT DISTINCT ON (r.team_id) r.team_id, t.api_football_id, r.data
    FROM public.raw_fetch_logs r
    JOIN public.teams t ON t.id = r.team_id
    WHERE r.source = 'api_football_players_stats'
      AND t.is_active
      AND jsonb_array_length(COALESCE(r.data->'response', '[]'::jsonb)) > 0
    ORDER BY r.team_id, r.fetched_at DESC
  ),
  rows_ AS (
    -- One row per player per competition, for THIS club only.
    SELECT (e->'player'->>'id')::int AS api_player_id,
           l.team_id,
           e->'player'->>'nationality'            AS nationality,
           NULLIF(e->'player'->>'age', '')::int    AS age,
           (s->'league'->>'id')::int               AS league_id,
           COALESCE(NULLIF(s->'games'->>'appearences', '')::int, 0) AS apps,
           COALESCE(NULLIF(s->'games'->>'minutes', '')::int, 0)     AS minutes,
           COALESCE(NULLIF(s->'games'->>'lineups', '')::int, 0)     AS starts,
           NULLIF(s->'games'->>'rating', '')::numeric               AS rating,
           COALESCE((s->'games'->>'captain')::boolean, false)       AS captain,
           COALESCE(NULLIF(s->'substitutes'->>'in', '')::int, 0)    AS sub_in,
           COALESCE(NULLIF(s->'goals'->>'total', '')::int, 0)       AS goals,
           COALESCE(NULLIF(s->'goals'->>'assists', '')::int, 0)     AS assists,
           COALESCE(NULLIF(s->'goals'->>'saves', '')::int, 0)       AS saves,
           COALESCE(NULLIF(s->'goals'->>'conceded', '')::int, 0)    AS conceded,
           COALESCE(NULLIF(s->'cards'->>'yellow', '')::int, 0)      AS yellow,
           COALESCE(NULLIF(s->'cards'->>'red', '')::int, 0)         AS red
    FROM latest l,
         jsonb_array_elements(l.data->'response') e,
         jsonb_array_elements(e->'statistics') s
    WHERE e->'player'->>'id' ~ '^[0-9]+$'
      AND (s->'team'->>'id')::int = l.api_football_id
  ),
  per_club AS (
    SELECT api_player_id, team_id,
           MAX(nationality) AS nationality,
           MAX(age)         AS age,
           SUM(apps)        AS appearances,
           SUM(minutes)     AS minutes,
           SUM(starts)      AS starts,
           SUM(sub_in)      AS sub_appearances,
           SUM(goals)       AS goals,
           SUM(assists)     AS assists,
           SUM(saves)       AS saves,
           SUM(conceded)    AS conceded,
           SUM(yellow)      AS yellow_cards,
           SUM(red)         AS red_cards,
           BOOL_OR(captain) AS captain,
           -- Minutes-weighted mean of the feed's per-competition rating.
           CASE WHEN SUM(CASE WHEN rating IS NOT NULL THEN minutes ELSE 0 END) > 0
                THEN ROUND(SUM(rating * minutes) FILTER (WHERE rating IS NOT NULL)
                           / SUM(minutes) FILTER (WHERE rating IS NOT NULL), 2)
                ELSE NULL END AS rating,
           SUM(goals)  FILTER (WHERE league_id = 39) AS league_goals,
           SUM(starts) FILTER (WHERE league_id = 39) AS league_starts
    FROM rows_
    GROUP BY 1, 2
  ),
  best AS (
    SELECT DISTINCT ON (api_player_id) *
    FROM per_club
    ORDER BY api_player_id, minutes DESC, appearances DESC
  ),
  upd AS (
    UPDATE public.players p
       SET appearances      = b.appearances,
           minutes          = b.minutes,
           starts           = b.starts,
           sub_appearances  = b.sub_appearances,
           goals            = b.goals,
           assists          = b.assists,
           saves            = b.saves,
           conceded         = b.conceded,
           yellow_cards     = b.yellow_cards,
           red_cards        = b.red_cards,
           rating           = b.rating,
           captain          = b.captain,
           nationality      = COALESCE(b.nationality, p.nationality),
           age              = COALESCE(b.age, p.age),
           league_goals     = COALESCE(b.league_goals, 0),
           league_starts    = COALESCE(b.league_starts, 0),
           stats_updated_at = now()
      FROM best b
     WHERE p.api_player_id = b.api_player_id
    RETURNING 1
  )
  SELECT count(*) INTO n FROM upd;
  RETURN n;
END;
$$;

COMMENT ON FUNCTION public.sync_player_stats_from_raw() IS
  'Copies each active club''s newest /players season payload into players: '
  'appearances, minutes, starts, goals, assists, cards, saves, conceded, a '
  'minutes-weighted rating, captaincy, nationality and age, plus league-only '
  'goals and starts. Runs daily at 06:40 after the data-fetcher''s morning run.';

-- Run once now so the app has numbers today.
SELECT public.sync_player_stats_from_raw() AS synced_now;
