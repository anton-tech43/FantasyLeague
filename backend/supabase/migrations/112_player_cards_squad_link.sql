-- 112_player_cards_squad_link.sql
-- Give player_cards an exact link to the squad, so a departed player leaves the
-- app on his own.
--
-- Migration 111 deleted 27 dossiers for players who had left, and said in its
-- own header that it would happen again: `APIClient.fetchPlayerCards` asks for
-- every row with `team_id=eq.<club>` and nothing filters by squad, while
-- `gd-player-dossier` only ever writes. This is the durable half.
--
-- The link is `api_player_id`, not the name. Name matching is exactly where
-- this goes wrong — a last-token match called Alisson departed because the
-- squad spells him "Alisson Becker" — so it is done ONCE here, by a function
-- that has to find exactly one candidate, and the app then joins on an integer.
--
-- `players.team_id` follows a transfer (sync_players_from_squads upserts it
-- nightly from the squad payload), so an inner join on it answers "is he still
-- there?" with no extra state to maintain and nothing to keep in step. A player
-- who leaves the leagues we track is pruned from `players` (mig 096/099) and
-- the FK nulls the link. Either way the card stops being served.

-- Tokens of a name, normalised: accents folded, split on spaces and hyphens,
-- initials and nobiliary particles dropped. "N. O'Reilly" -> {o'reilly}.
CREATE OR REPLACE FUNCTION public.player_name_tokens(txt text)
RETURNS text[] LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT COALESCE(array_agg(s.t), '{}'::text[])
  FROM (
    SELECT btrim(tok, '.''-') AS t
    FROM regexp_split_to_table(
           translate(lower(txt),
             'áàâäãåéèêëíìîïóòôöõúùûüñçøšžý',
             'aaaaaaeeeeiiiiooooouuuuncoszy'),
           '[ \-]+') AS tok
  ) s
  WHERE length(s.t) >= 3
    AND s.t NOT IN ('van','de','der','den','dos','da','di','el','al')
$$;

-- The squad member this card is about, or NULL. Exactly one candidate or
-- nothing: an ambiguous name is not a link, and a card we cannot place is a
-- card we should not be serving.
CREATE OR REPLACE FUNCTION public.resolve_player_id(p_team_id text, p_name text)
RETURNS integer LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT CASE WHEN count(*) = 1 THEN min(pl.api_player_id) END
  FROM public.players pl
  WHERE pl.team_id = p_team_id
    AND public.player_name_tokens(pl.name) && public.player_name_tokens(p_name)
$$;

ALTER TABLE public.player_cards
  ADD COLUMN IF NOT EXISTS api_player_id integer
    REFERENCES public.players(api_player_id) ON DELETE SET NULL;

UPDATE public.player_cards
   SET api_player_id = public.resolve_player_id(team_id, player_name)
 WHERE api_player_id IS NULL;

-- gd-player-dossier does not know about this column, so the database fills it.
CREATE OR REPLACE FUNCTION public.player_cards_link_player()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF NEW.api_player_id IS NULL THEN
    NEW.api_player_id := public.resolve_player_id(NEW.team_id, NEW.player_name);
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS player_cards_link ON public.player_cards;
CREATE TRIGGER player_cards_link
  BEFORE INSERT OR UPDATE OF player_name, team_id ON public.player_cards
  FOR EACH ROW EXECUTE FUNCTION public.player_cards_link_player();

-- The app's read needs the embed; the FK above is what exposes it to PostgREST.
GRANT SELECT ON public.player_cards TO anon;

-- Verification:
--   SELECT count(*) FILTER (WHERE api_player_id IS NULL) FROM player_cards pc
--     JOIN teams t ON t.id = pc.team_id WHERE t.league_id = 39 AND t.is_active;
