-- 112_club_style.sql
--
-- How each club plays, as a handful of hand-verified flags.
--
-- No feed we hold carries style of play at all. API-Football does not break a
-- goal down by set piece, counter attack or zone, so there is nothing to sync
-- and nothing automated writes this table. It exists for the same reason
-- `teams.manager_name` does (migration 085): the fact is customer-visible, the
-- feed cannot answer it, so the answer moves into our own table with a
-- `verified_at` and every consumer reads ours. See DATA_SOURCES.md, "The rule".
--
-- The seed below is the read in tools/myturn/OPPONENT_STYLE_NOTES.md: published
-- league tables (WhoScored team statistics, Premier League) for 2025/26 and the
-- first five games of 2026/27, read 2026-09-23. No figures are copied here,
-- only the conclusions.
--
-- THREE COLUMN STATES, and they are not the same thing:
--   NULL  — we have not verified this. The card renders it as false; nothing
--           is claimed. This is the default and most of the table.
--   true  — safe to say, on the basis in source_note.
--   false — we checked and it is NOT true, recorded so nobody writes the line
--           again (crystal_palace on the counter is the only one so far).
--
-- WHY SO FEW true VALUES. The notes' own invalidation rule — "a club that
-- changes manager has no usable history until the new one has a season" — takes
-- out most of the list once it is applied against teams.manager_started_on.
-- Eleven of the twenty active clubs appointed their manager in 2026, i.e. after
-- 2025/26 had started, so last season's pattern was somebody else's team and
-- five games of this one is noise (the gap between the best and worst set-piece
-- side in the league right now is four goals). That drops Newcastle and Chelsea
-- from the set-piece list, Bournemouth and Manchester City from the counter,
-- Fulham from goals-from-range, Manchester City from goals-from-close-in, and
-- Fulham, Bournemouth and Crystal Palace from the sides of the pitch — every
-- one of them a claim the notes would otherwise allow.
--
-- Hull, Ipswich and Coventry have no Premier League season behind them at all,
-- so they get a row and nothing set.
--
-- WHEN TO REVISIT (both are in the stale-data-audit skill):
--   * a manager change — re-read this file's assumptions against
--     teams.manager_started_on and clear anything that predates the new man;
--   * midwinter, when 2026/27 is twenty games old and can carry a claim on its
--     own without last season underneath it.

CREATE TABLE IF NOT EXISTS club_style (
  team_id      text PRIMARY KEY REFERENCES teams(id) ON DELETE CASCADE,
  -- Scores from dead balls more than most.
  set_piece    boolean,
  -- Scores on the break.
  counter      boolean,
  -- Wins the ball in the air.
  aerial       boolean,
  -- Scores from outside the box more than most.
  long_range   boolean,
  -- Scores from inside the six-yard box more than most.
  close_range  boolean,
  -- Which side of the pitch the attack goes down.
  attacks_side text CHECK (attacks_side IN ('left', 'right', 'middle')),
  -- When a human last checked the row. NULL = nothing verified yet.
  verified_at  date,
  -- What was read, and on which season's evidence. Carries the qualifier the
  -- copy needs ("last season", "must be dated") that a boolean cannot.
  source_note  text
);

ALTER TABLE club_style ENABLE ROW LEVEL SECURITY;

-- The app reads it through the team page, but the row is also readable
-- directly so a future surface does not need a new function.
DROP POLICY IF EXISTS club_style_read ON club_style;
CREATE POLICY club_style_read ON club_style
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS club_style_write ON club_style;
CREATE POLICY club_style_write ON club_style
  TO service_role USING (true) WITH CHECK (true);

-- Supabase's default grants hand anon the whole table and let RLS do the
-- gating. Nothing in the app writes style, so take the write grant away too.
REVOKE ALL ON club_style FROM anon, authenticated;
GRANT SELECT ON club_style TO anon, authenticated;
GRANT ALL ON club_style TO service_role;

-- ── Seed ────────────────────────────────────────────────────────────────────
-- One row per active club. Ordered as the notes are, not alphabetically.

INSERT INTO club_style (team_id, set_piece, counter, aerial, long_range, close_range, attacks_side, verified_at, source_note)
VALUES
  -- Set pieces, both seasons agreeing, manager in place since before 2025/26.
  ('brighton', true, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Set pieces: mid-to-high in 2025/26 and near the top of the league on set-piece goals after five games of 2026/27. The strongest of the group. Hurzeler since 2024-06.'),
  ('brentford', true, true, NULL, NULL, true, NULL, DATE '2026-09-23',
   'Set pieces: scored this way in both seasons. Counter: joint-best counter-attacking side in 2025/26 and has scored on the break again this season — the safest counter claim in the league. Close in: lowest share of goals from outside the box in 2025/26 by some way, same this season. Andrews since 2025-06, so both seasons are his.'),
  ('everton', true, NULL, true, NULL, NULL, 'left', DATE '2026-09-23',
   'Set pieces: scored this way in both seasons. Aerial: won more aerial duels than any side in 2025/26, comfortably — but they have dropped to mid-table on it this season, so the line MUST be dated to last season and must not say "they win everything in the air". Left side: one of the three most left-leaning attacks, both seasons. Moyes since 2025-01.'),
  ('leeds', true, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Set pieces: scored this way in both seasons. Farke since 2023-07. Top two on aerial duels this season, but that is five games against an Everton season, so aerial is left unset.'),

  -- Set pieces on 2025/26 alone. The claim stands (five games cannot overturn
  -- a season) but the copy has to say "last season".
  ('arsenal', true, NULL, NULL, NULL, NULL, 'right', DATE '2026-09-23',
   'Set pieces: one of the three biggest set-piece sides in the league in 2025/26, and has not scored from one yet in 2026/27 — DATE THE CLAIM to last season. Right side: second most one-sided attack in the league, both seasons. Arteta since 2019-12. Their goals have moved out of the six-yard box this season; five games, not seeded.'),

  -- Goals from range.
  ('aston_villa', NULL, NULL, NULL, true, NULL, NULL, DATE '2026-09-23',
   'From range: about a quarter of their goals came from outside the box in 2025/26, the highest share in the league, and the same share this season. The safest claim in the whole file. Emery since 2022-11.'),

  -- A verified negative. "Dangerous on the counter" was a straightforwardly
  -- false line about them: zero counter-attacking goals in the whole of
  -- 2025/26. One this season. Recorded so nobody writes it again.
  ('crystal_palace', NULL, false, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Counter: ZERO counter-attack goals in 2025/26, one so far this season — "dangerous on the counter" is false about them. They go through the middle more than anyone, but Sage has only been in post since 2026-06 so the side of the pitch is not seeded.'),

  -- Everything else: a row, a date, and a reason nothing is set.
  ('newcastle', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Jaissle appointed 2026-08, so 2025/26 was another manager''s side. Their set-piece record (mid-to-high last season, scored this way already this season) is the best candidate to re-seed at midwinter.'),
  ('chelsea', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Alonso appointed 2026-07. Near the top of the league on set-piece goals after five games and high on the counter list too, but that is five games with no usable season under it. Re-seed at midwinter.'),
  ('man_city', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Maresca appointed 2026-06. Joint-best on the counter in 2025/26 (none this season) and scored from inside the box despite having the most of the ball — both were the previous manager''s team.'),
  ('bournemouth', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Rose appointed 2026-06. One of the two best counter-attacking sides in 2025/26 and one of the most left-leaning attacks, both under Iraola.'),
  ('fulham', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Arbeloa appointed 2026-07. Second in the league for goals from distance in 2025/26 and a hard left lean, both under the previous manager.'),
  ('liverpool', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Iraola appointed 2026-06, and the notes have no entry for Liverpool in any section.'),
  ('nottm_forest', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Glasner appointed 2026-07, and the notes have no entry for Forest in any section.'),
  ('man_utd', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Carrick took over 2026-01, so 2025/26 is split between two managers. They were one of the three biggest set-piece sides across that season, and have gone from almost never scoring from distance to doing it often — five games, explicitly not to be written.'),
  ('spurs', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: De Zerbi took over 2026-03, so only the last weeks of 2025/26 were his. Four in ten of that season''s goals came from set pieces, the most striking in the league — the single biggest thing this table is giving up, and the first to re-seed once he has a season.'),
  ('sunderland', NULL, NULL, NULL, NULL, NULL, NULL, DATE '2026-09-23',
   'Nothing seeded: Le Bris in post since 2024-07, but the notes have no entry for Sunderland in any section.'),

  -- Promoted. No Premier League season behind them at all.
  ('hull', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
   'Promoted: no Premier League baseline. Do not claim anything about how they play.'),
  ('ipswich', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
   'Promoted: no Premier League baseline. Do not claim anything about how they play.'),
  ('coventry', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
   'Promoted: no Premier League baseline. Do not claim anything about how they play.')
ON CONFLICT (team_id) DO UPDATE SET
  set_piece    = EXCLUDED.set_piece,
  counter      = EXCLUDED.counter,
  aerial       = EXCLUDED.aerial,
  long_range   = EXCLUDED.long_range,
  close_range  = EXCLUDED.close_range,
  attacks_side = EXCLUDED.attacks_side,
  verified_at  = EXCLUDED.verified_at,
  source_note  = EXCLUDED.source_note;

-- West Ham are the most one-sided attack in the league (right) in the notes and
-- are deliberately absent: they are not an active Premier League club.

-- Self-check: every active club has a row, and nothing is claimed about a club
-- whose manager arrived after 2025/26 kicked off.
DO $$
DECLARE missing int; suspect text;
BEGIN
  SELECT count(*) INTO missing
    FROM teams t LEFT JOIN club_style s ON s.team_id = t.id
   WHERE t.is_active AND t.entity_type = 'club' AND s.team_id IS NULL;
  IF missing > 0 THEN
    RAISE EXCEPTION 'club_style: % active clubs have no row', missing;
  END IF;

  SELECT string_agg(t.id, ', ') INTO suspect
    FROM club_style s JOIN teams t ON t.id = s.team_id
   WHERE t.manager_started_on > DATE '2025-08-01'
     AND (s.set_piece OR s.counter OR s.aerial OR s.long_range OR s.close_range
          OR s.attacks_side IS NOT NULL);
  IF suspect IS NOT NULL THEN
    RAISE EXCEPTION 'club_style: claim seeded for a club that changed manager since 2025/26 began: %', suspect;
  END IF;
END $$;
