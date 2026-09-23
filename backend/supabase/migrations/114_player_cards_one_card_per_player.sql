-- 114_player_cards_one_card_per_player.sql
-- One dossier per player, not one per spelling.
--
-- `player_cards` is unique on (team_id, player_name), so when the feed or the
-- routine changes how a name is written the old row stays and the club's list
-- shows the man twice. The link added in 112/113 makes them provably the same
-- person. Ten pairs today, e.g. "J. Pickford" and "Jordan Pickford" at Everton,
-- "Ismaïla Sarr" and "Ismaila Sarr" at Palace, "Nikola Milenkovic" and
-- "N. Milenković" at Forest.
--
-- One of them was not a spelling at all. Brentford had "Demarai Ouattara"
-- (2026-08-02) and "Dango Ouattara" (2026-09-06), both linked to squad member
-- 284797 — and there is exactly one Ouattara at Brentford, a 23-year-old
-- Burkina Faso international, which is Dango. The August card had invented the
-- first name, presumably out of Demarai Gray, and the September rewrite fixed
-- it without removing the wrong one. She could open either.
--
-- Newest wins, because the newest is the one the routine most recently stood
-- behind. No unique constraint: gd-player-dossier upserts on
-- (team_id, player_name), so a constraint would make it fail on the rename
-- instead of completing it. The trigger clears the way instead.

BEGIN;

DELETE FROM public.player_cards pc
 USING public.player_cards keep
 WHERE pc.team_id = keep.team_id
   AND pc.api_player_id IS NOT NULL
   AND pc.api_player_id = keep.api_player_id
   AND (keep.updated_at, keep.id) > (pc.updated_at, pc.id);

CREATE OR REPLACE FUNCTION public.player_cards_link_player()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF NEW.api_player_id IS NULL THEN
    NEW.api_player_id := public.resolve_player_id(NEW.team_id, NEW.player_name);
  END IF;
  -- A rename arrives as a new row, because the natural key is the name. Retire
  -- the card this one supersedes rather than leaving her two of the same man.
  IF NEW.api_player_id IS NOT NULL THEN
    -- Not aliased `old`: that is a reserved trigger variable and the reference
    -- is ambiguous, which fails at runtime on every insert, not at creation.
    DELETE FROM public.player_cards superseded
     WHERE superseded.team_id = NEW.team_id
       AND superseded.api_player_id = NEW.api_player_id
       AND superseded.id IS DISTINCT FROM NEW.id;
  END IF;
  RETURN NEW;
END
$$;

COMMIT;

-- Verification (expect no rows):
--   SELECT team_id, api_player_id, count(*) FROM player_cards
--    WHERE api_player_id IS NOT NULL GROUP BY 1,2 HAVING count(*) > 1;
