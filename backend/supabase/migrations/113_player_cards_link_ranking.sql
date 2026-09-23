-- 113_player_cards_link_ranking.sql
-- Migration 112's resolver required exactly one candidate and left 8 of 334
-- cards unlinked, which would have hidden them from the app. Every one was the
-- resolver's fault, not a departed player:
--
--   arsenal / Martin Ødegaard    — "Martín Zubimendi" also matches on "martin"
--   chelsea / João Pedro         — collides with "Pedro Neto", and vice versa
--   coventry / B. Thomas         — collides with "B. Thomas-Asante", and vice versa
--   man_city / Matheus Nunes     — collides with "Vitor Nunes"
--   bournemouth / R. Christie    — collides with "Z. Christie"
--   nottm_forest / N. Milenković — "ć" was not in the fold set, so nothing matched
--
-- Two fixes. The fold now covers the rest of Latin Europe, including the
-- letters that expand to two characters and so cannot go through `translate`.
-- And the resolver RANKS instead of counting: an exact name beats a surname
-- match beats a shared token, and a winner has to be strictly better than the
-- runner-up. That keeps the property that matters — a name we cannot place
-- stays unlinked rather than being attached to the wrong man — while placing
-- the ones a person would place without hesitating. "R. Christie" and
-- "Z. Christie" are told apart by the full string, which is the only thing that
-- can tell them apart once initials are dropped.

CREATE OR REPLACE FUNCTION public.fold_name(txt text)
RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT translate(
           replace(replace(replace(replace(replace(
             lower(txt), 'ß', 'ss'), 'æ', 'ae'), 'œ', 'oe'), 'þ', 'th'), 'ð', 'd'),
           'áàâäãåāăąéèêëēĕėęěíìîïĩīĭįóòôöõøōŏőúùûüũūŭůűųñńňçćčđďğĥıĵłŕřśşšţťýÿžźż',
           'aaaaaaaaaeeeeeeeeeiiiiiiiiooooooooouuuuuuuuuunnncccddghijlrrsssttyyzzz')
$$;

COMMENT ON FUNCTION public.fold_name(text) IS
  'Lowercase and strip diacritics for name comparison (mig 113). Two-character expansions are replaced before translate, which is 1:1 only.';

CREATE OR REPLACE FUNCTION public.player_name_tokens(txt text)
RETURNS text[] LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT COALESCE(array_agg(s.t ORDER BY s.ord), '{}'::text[])
  FROM (
    SELECT btrim(tok, '.''-') AS t, ord
    FROM regexp_split_to_table(public.fold_name(txt), '[ \-]+')
         WITH ORDINALITY AS x(tok, ord)
  ) s
  WHERE length(s.t) >= 3
    AND s.t NOT IN ('van','de','der','den','dos','da','di','el','al')
$$;

-- Exact name 8, surname 2, one per shared token. The winner must beat the
-- runner-up outright; a tie is not a link.
CREATE OR REPLACE FUNCTION public.resolve_player_id(p_team_id text, p_name text)
RETURNS integer LANGUAGE sql STABLE SET search_path = ''
AS $$
  WITH want AS (
    SELECT public.player_name_tokens(p_name) AS toks, public.fold_name(p_name) AS full
  ),
  cand AS (
    SELECT pl.api_player_id, pl.name, public.player_name_tokens(pl.name) AS toks, w.toks AS want, w.full
    FROM public.players pl, want w
    WHERE pl.team_id = p_team_id
      AND public.player_name_tokens(pl.name) && w.toks
  ),
  scored AS (
    SELECT c.api_player_id,
           (CASE WHEN public.fold_name(c.name) = c.full THEN 8 ELSE 0 END)
         + (CASE WHEN c.toks[array_length(c.toks, 1)] = c.want[array_length(c.want, 1)]
                 THEN 2 ELSE 0 END)
         + cardinality(ARRAY(SELECT unnest(c.toks) INTERSECT SELECT unnest(c.want))) AS score
    FROM cand c
  ),
  ranked AS (
    SELECT api_player_id, score,
           row_number() OVER (ORDER BY score DESC, api_player_id) AS rn,
           lead(score) OVER (ORDER BY score DESC, api_player_id) AS next_score
    FROM scored
  )
  SELECT api_player_id FROM ranked
   WHERE rn = 1 AND (next_score IS NULL OR score > next_score)
$$;

-- Re-resolve every card, including the ones 112 linked, so the ranking owns
-- the whole table rather than only the leftovers.
UPDATE public.player_cards
   SET api_player_id = public.resolve_player_id(team_id, player_name);

-- Verification:
--   SELECT count(*) FILTER (WHERE api_player_id IS NULL) FROM player_cards pc
--     JOIN teams t ON t.id = pc.team_id WHERE t.league_id = 39 AND t.is_active;  -- 0
