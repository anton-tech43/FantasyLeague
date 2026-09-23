-- 111_drop_departed_player_cards.sql
-- Twenty-seven players the app still lists for a club they have left.
--
-- Found by the stale-data audit, 2026-09-23. `APIClient.fetchPlayerCards`
-- (`ios/GoalDigger/Services/APIClient.swift:287`) asks PostgREST for every
-- `player_cards` row with `team_id=eq.<club>` and applies no squad filter, so a
-- dossier written in May is still on the club's player list in September.
-- `gd-player-dossier` only ever writes; nothing has ever deleted.
--
-- What she would have seen: Mohamed Salah on Liverpool's list, Rodri on
-- Manchester City's, Bruno Guimarães, Sandro Tonali and Anthony Gordon on
-- Newcastle's, Ollie Watkins and Emi Martínez on Aston Villa's. Marquee names,
-- at the wrong clubs, months out of date.
--
-- How the list was built, because naming is where this goes wrong: normalise
-- accents, split on spaces and hyphens, drop the nobiliary particles, and keep
-- a card only if it shares a token of three characters or more with somebody in
-- that club's current squad. Four rows that a cruder surname match called
-- departed are NOT here, and each was checked by hand:
--   * `liverpool / Alisson` — the squad says "Alisson Becker", so a last-token
--     match compared "alisson" with "becker".
--   * `arsenal / E. Eze`, `spurs / M. Tel`, `spurs / M. van de Ven` — surnames
--     too short for a length filter to keep.
-- Eze appears below for CRYSTAL PALACE and is in Arsenal's squad, which is the
-- transfer, not a mistake. Same for Guéhi, Palace to Manchester City.
--
-- Three players appear twice, once per spelling ("Emi Martinez" and
-- "Emi Martínez", "Bruno Guimaraes" and "Bruno Guimarães", "I. Ndiaye" and
-- "Iliman Ndiaye"): the dossier routine writes a new row when the feed changes
-- how it abbreviates a name, rather than updating the old one. Both copies go.
--
-- This clears today's rows. It does not stop it happening again — the app has
-- no squad filter, so the next window puts the same problem back. That is an
-- iOS/API change and it is written up in AUDIT_FINDINGS.md rather than done
-- here.

BEGIN;

CREATE TEMP TABLE departed(team_id text, player_name text) ON COMMIT DROP;
INSERT INTO departed(team_id, player_name) VALUES
  ('aston_villa', 'Emi Martinez'),
  ('aston_villa', 'Emi Martínez'),
  ('aston_villa', 'Ollie Watkins'),
  ('bournemouth', 'Antoine Semenyo'),
  ('bournemouth', 'Marcos Senesi'),
  ('brentford', 'Bryan Mbeumo'),
  ('brentford', 'Ethan Pinnock'),
  ('brentford', 'Yoane Wissa'),
  ('brighton', 'Danny Welbeck'),
  ('brighton', 'Joao Pedro'),
  ('chelsea', 'Marc Cucurella'),
  ('chelsea', 'Nicolas Jackson'),
  ('crystal_palace', 'Eberechi Eze'),
  ('crystal_palace', 'Marc Guehi'),
  ('everton', 'I. Ndiaye'),
  ('everton', 'Iliman Ndiaye'),
  ('ipswich', 'G. Hirst'),
  ('leeds', 'Illan Meslier'),
  ('leeds', 'Wilfried Gnonto'),
  ('liverpool', 'Mohamed Salah'),
  ('man_city', 'Rodri'),
  ('newcastle', 'Anthony Gordon'),
  ('newcastle', 'Bruno Guimaraes'),
  ('newcastle', 'Bruno Guimarães'),
  ('newcastle', 'Sandro Tonali'),
  ('spurs', 'Dejan Kulusevski'),
  ('sunderland', 'Dennis Cirkin');

DELETE FROM public.player_cards pc
 USING departed d
 WHERE pc.team_id = d.team_id AND pc.player_name = d.player_name;

COMMIT;

-- Verification (expect 27 fewer, and nothing on the list below):
--   SELECT count(*) FROM player_cards pc JOIN teams t ON t.id = pc.team_id
--    WHERE t.league_id = 39 AND t.is_active;                       -- 334
