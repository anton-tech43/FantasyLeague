-- 136_players_known_as.sql
-- The name a club's player is known by, from the Premier League's own squad
-- list (official-squads writes it, name.display): "Gabriel" for Gabriel
-- Magalhães, "Rodri", "Casemiro". Every app matcher keyed on API-Football's
-- surname, so a headline naming "Gabriel" linked to nobody (Anton,
-- 2026-10-27). Filled on official-squads' next run; NULL until then and for
-- clubs without pl_squad_id.
-- The app reads players with the anon key through PostgREST; a new column on
-- an existing table inherits the table's grants, so nothing to grant here.
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS known_as text;
