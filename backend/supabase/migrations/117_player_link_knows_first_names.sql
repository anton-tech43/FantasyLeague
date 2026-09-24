-- 117_player_link_knows_first_names.sql
-- The squad link could name the wrong man, and once broken it never healed.
--
-- Red-team review of migrations 112-114 (2026-09-23). All 334 links live at the
-- time were correct, so nothing was wrong on screen — but four mechanisms were,
-- and every one of them bites on the NEXT write rather than this one.
--
-- 1. THE RANKING NEVER LOOKED AT THE FORENAME. A candidate sharing only the
--    surname scored 2 + 1 = 3, and if exactly one squad member held that
--    surname, 3 won outright. Demonstrated against live rows:
--        resolve_player_id('argentina','E. Martínez')   -> Lautaro Martínez
--        resolve_player_id('ecuador','Moisés Caicedo')  -> J. Caicedo
--        resolve_player_id('uruguay','Ronald Araújo')   -> M. Araújo
--        resolve_player_id('liverpool','Iliman Ndiaye') -> T. Ndiaye
--    Combined with 114's trigger this is not a mislabel, it is a DELETE:
--    Argentina's card lists both "E. Martínez" and "Lautaro Martínez", both
--    resolved to 217, and writing the second would have destroyed the first.
--
-- 2. THE SAME RULE MADE HONEST CARDS INVISIBLE. "Winner must beat the runner-up
--    strictly" turns every same-surname pair into NULL as soon as the card
--    spells the forename out, and `!inner` then never serves it. Live pairs:
--    R./Z. Christie (Bournemouth), J./T. Fletcher (United), N./J. Angulo
--    (Sunderland), two T. Hall at Spurs.
--
-- 3. A LINK, ONCE BROKEN, NEVER HEALED. The FK is ON DELETE SET NULL and
--    `prune_departed_players()` runs nightly, so one day where the feed omits a
--    player nulls his link — and nothing recomputed it. The trigger fires only
--    on INSERT and on UPDATE OF player_name, team_id, and an FK's own SET NULL
--    touches neither.
--
-- 4. A RENAME DELETED USING A STALE ID. `IF NEW.api_player_id IS NULL THEN
--    resolve` meant an UPDATE of player_name kept the OLD id and then deleted
--    whatever held it.
--
-- The fix is one signal and one habit. The signal is the first initial, which is
-- the only thing separating two Martínez or two Christie. The habit is to
-- re-resolve rather than trust a stored id, and to refuse rather than guess.

BEGIN;

-- Tokens with particles removed but NO length floor. Needed to tell "this name
-- carries a forename" from "this name is a single word", which the scoring
-- floor below would otherwise hide.
CREATE OR REPLACE FUNCTION public.player_name_parts(txt text)
RETURNS text[] LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT COALESCE(array_agg(s.t ORDER BY s.ord), '{}'::text[])
  FROM (
    SELECT btrim(tok, '.''-') AS t, ord
    FROM regexp_split_to_table(public.fold_name(txt), '[ \-]+')
         WITH ORDINALITY AS x(tok, ord)
  ) s
  WHERE s.t <> ''
    AND s.t NOT IN ('van','de','der','den','dos','da','di','el','al')
$$;

-- The forename's initial, or NULL when the name has no forename. "R. Christie"
-- and "Ryan Christie" both give 'r'; "Alisson" and "Rodri" give NULL, because
-- taking 'a' off a lone surname is how you link the wrong man.
CREATE OR REPLACE FUNCTION public.player_first_key(txt text)
RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT CASE WHEN cardinality(p) > 1 THEN left(p[1], 1) END
  FROM (SELECT public.player_name_parts(txt) AS p) s
$$;

-- Floor lowered from 3 to 2: Sunderland's "J. Bi" had no tokens at all and so
-- could never hold a dossier under any spelling.
CREATE OR REPLACE FUNCTION public.player_name_tokens(txt text)
RETURNS text[] LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT COALESCE(array_agg(t ORDER BY o), '{}'::text[])
  FROM unnest(public.player_name_parts(txt)) WITH ORDINALITY AS u(t, o)
  WHERE length(t) >= 2
$$;

CREATE OR REPLACE FUNCTION public.resolve_player_id(p_team_id text, p_name text)
RETURNS integer LANGUAGE sql STABLE SET search_path = ''
AS $$
  WITH want AS (
    SELECT public.player_name_tokens(p_name) AS toks,
           public.fold_name(p_name)          AS full,
           public.player_first_key(p_name)   AS fkey
  ),
  cand AS (
    SELECT pl.api_player_id, pl.name,
           public.player_name_tokens(pl.name) AS toks,
           w.toks AS want, w.full, w.fkey AS want_fkey
    FROM public.players pl, want w
    WHERE pl.team_id = p_team_id
      AND public.player_name_tokens(pl.name) && w.toks
      -- Two different forenames means two different people. When either side
      -- has no forename we cannot tell, so we do not rule the candidate out —
      -- the tie-break below catches that case instead.
      AND NOT (public.player_first_key(pl.name) IS NOT NULL
               AND w.fkey IS NOT NULL
               AND public.player_first_key(pl.name) <> w.fkey)
  ),
  scored AS (
    SELECT c.api_player_id,
           (CASE WHEN public.fold_name(c.name) = c.full THEN 8 ELSE 0 END)
         + (CASE WHEN c.toks[array_length(c.toks,1)] = c.want[array_length(c.want,1)] THEN 2 ELSE 0 END)
         + cardinality(ARRAY(SELECT unnest(c.toks) INTERSECT SELECT unnest(c.want))) AS score
    FROM cand c
  ),
  ranked AS (
    SELECT api_player_id, score,
           row_number() OVER (ORDER BY score DESC, api_player_id) AS rn,
           lead(score)  OVER (ORDER BY score DESC, api_player_id) AS next_score,
           count(*)     OVER ()                                   AS n
    FROM scored
  )
  SELECT r.api_player_id FROM ranked r, want w
   WHERE r.rn = 1
     AND (r.next_score IS NULL OR r.score > r.next_score)
     -- A card with no forename ("Pedro" at a club with João Pedro AND Pedro
     -- Neto) cannot be told apart. Refuse; a wrong link here is a deleted
     -- dossier, not a cosmetic error.
     AND (w.fkey IS NOT NULL OR r.n = 1)
$$;

-- Always re-resolve. Trusting a stored id across a rename is how a rename came
-- to delete a different player's card.
CREATE OR REPLACE FUNCTION public.player_cards_link_player()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  NEW.api_player_id := public.resolve_player_id(NEW.team_id, NEW.player_name);

  IF NEW.api_player_id IS NOT NULL THEN
    -- Retire the card this one supersedes. Guarded on a shared name token so a
    -- rename that lands on a DIFFERENT player cannot take his dossier with it;
    -- a spelling variant ("Bruno Guimaraes" / "Bruno Guimarães") always shares
    -- one. Not aliased `old` — that is a reserved trigger variable and the
    -- reference fails at runtime, on every insert, not at creation.
    DELETE FROM public.player_cards superseded
     WHERE superseded.team_id = NEW.team_id
       AND superseded.api_player_id = NEW.api_player_id
       AND superseded.id IS DISTINCT FROM NEW.id
       AND public.player_name_tokens(superseded.player_name)
           && public.player_name_tokens(NEW.player_name);
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS player_cards_link ON public.player_cards;
CREATE TRIGGER player_cards_link
  BEFORE INSERT OR UPDATE OF player_name, team_id ON public.player_cards
  FOR EACH ROW EXECUTE FUNCTION public.player_cards_link_player();

-- The healing half. `prune_departed_players()` nulls links through the FK every
-- night; this puts back the ones that can be resolved again, and is a no-op
-- otherwise. Returns how many it repaired.
CREATE OR REPLACE FUNCTION public.relink_player_cards()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE n integer;
BEGIN
  WITH fixed AS (
    UPDATE public.player_cards pc
       SET api_player_id = public.resolve_player_id(pc.team_id, pc.player_name)
     WHERE pc.api_player_id IS NULL
       AND public.resolve_player_id(pc.team_id, pc.player_name) IS NOT NULL
    RETURNING 1
  )
  SELECT count(*) INTO n FROM fixed;
  RETURN n;
END
$$;
REVOKE EXECUTE ON FUNCTION public.relink_player_cards() FROM PUBLIC, anon, authenticated;

-- Re-resolve everything under the new rules.
UPDATE public.player_cards
   SET api_player_id = public.resolve_player_id(team_id, player_name);

COMMIT;

-- Run the repair nightly, right after the prune that can break a link.
-- cron.schedule replaces the job of the same name.
SELECT cron.schedule(
  'goaldigger-players-sync', '30 5 * * *',
  $job$SELECT public.sync_players_from_squads(); SELECT public.prune_departed_players(); SELECT public.relink_player_cards();$job$
);

-- Self-check: the six cases the review found, asserted rather than eyeballed.
DO $check$
DECLARE
  bad text := '';
BEGIN
  IF public.resolve_player_id('argentina','E. Martínez') IS NOT NULL
    THEN bad := bad || ' E.Martinez-should-refuse'; END IF;
  IF public.resolve_player_id('chelsea','Pedro') IS NOT NULL
    THEN bad := bad || ' bare-Pedro-should-refuse'; END IF;
  IF public.resolve_player_id('bournemouth','Ryan Christie') IS DISTINCT FROM 1125
    THEN bad := bad || ' Ryan-Christie'; END IF;
  IF public.resolve_player_id('sunderland','J. Bi') IS DISTINCT FROM 492528
    THEN bad := bad || ' J.Bi'; END IF;
  IF public.resolve_player_id('arsenal','Martin Ødegaard') IS DISTINCT FROM 37127
    THEN bad := bad || ' Odegaard'; END IF;
  IF public.resolve_player_id('liverpool','Alisson') IS DISTINCT FROM 280
    THEN bad := bad || ' Alisson'; END IF;
  IF bad <> '' THEN RAISE EXCEPTION 'resolve_player_id self-check failed:%', bad; END IF;
  RAISE NOTICE 'resolve_player_id self-check passed';
END
$check$;
