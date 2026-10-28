-- 139_players_known_as_verified.sql
-- The Premier League's own list has no mononyms: its display name for
-- Gabriel Magalhães is "Gabriel Magalhães", and the article said "Gabriel".
-- So the name a player goes by is ours, human-verified, like
-- teams.manager_name (DATA_SOURCES.md). official-squads fills known_as only
-- while known_as_verified_at is NULL; a hand-set name is never overwritten.
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS known_as_verified_at timestamptz;

UPDATE public.players
   SET known_as = 'Gabriel', known_as_verified_at = now()
 WHERE team_id = 'arsenal' AND name = 'Gabriel Magalhães';
