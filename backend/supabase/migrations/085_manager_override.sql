-- 085_manager_override.sql
-- A curated, human-verified manager per club — because API-Football's /coachs
-- feed cannot be trusted for this (audit 2026-09, A31).
--
-- What we found on 2026-09-06, checking every club against premierleague.com
-- and khelnow's 2026-27 manager list (and, for the two biggest changes, ESPN /
-- Sky / Al Jazeera match reports):
--   * The feed OMITS four of the summer's new managers entirely. Marco Rose
--     (Bournemouth), Enzo Maresca (Man City), Matthias Jaissle (Newcastle) and
--     Oliver Glasner (Forest) still show their PREVIOUS clubs on their own
--     /coachs?id record. Nothing in the team payload can point at them.
--   * The team payload lists assistants and caretakers with an OPEN stint
--     (career.end = null) at the club. "Newest open stint wins" therefore
--     picked J. Tindall over Marco Rose, L. Baines over David Moyes and
--     Bruno Saltor over Roberto De Zerbi — all three are assistants.
-- So the deterministic pick is a fallback, not a source of truth. This table is
-- the source of truth, and the skill `stale-data-audit` is the process that
-- keeps it honest after every transfer window.
--
-- manager_photo_url uses API-Football's coach CDN (media.api-sports.io/
-- football/coachs/<coach_id>.png), which serves a correct headshot even for the
-- coaches whose club record is stale — the ids below were resolved via
-- /coachs?search= and verified one by one.
--
-- Applied manually (schema_migrations only tracks 001–017, see A12).

ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS manager_name text,
  ADD COLUMN IF NOT EXISTS manager_photo_url text,
  ADD COLUMN IF NOT EXISTS manager_started_on date,
  ADD COLUMN IF NOT EXISTS manager_verified_at timestamptz;

-- Verified 2026-09-06 against premierleague.com/en/managers + khelnow.
WITH truth(id, mgr, coach_id, started) AS (VALUES
  ('arsenal',        'Mikel Arteta',      7248,  DATE '2019-12-22'),
  ('aston_villa',    'Unai Emery',        18,    DATE '2022-11-01'),
  ('bournemouth',    'Marco Rose',        1540,  DATE '2026-06-01'),
  ('brentford',      'Keith Andrews',     25364, DATE '2025-06-27'),
  ('brighton',       'Fabian Hürzeler',   19253, DATE '2024-06-15'),
  ('chelsea',        'Xabi Alonso',       6801,  DATE '2026-07-01'),
  ('coventry',       'Frank Lampard',     20,    DATE '2024-11-28'),
  ('crystal_palace', 'Pierre Sage',       21562, DATE '2026-06-15'),
  ('everton',        'David Moyes',       5662,  DATE '2025-01-11'),
  ('fulham',         'Álvaro Arbeloa',    25679, DATE '2026-07-07'),
  ('hull',           'Sergej Jakirović',  2721,  DATE '2025-06-11'),
  ('ipswich',        'Gary O''Neil',      25729, DATE '2026-06-23'),
  ('leeds',          'Daniel Farke',      2,     DATE '2023-07-04'),
  ('liverpool',      'Andoni Iraola',     2108,  DATE '2026-06-04'),
  ('man_city',       'Enzo Maresca',      12629, DATE '2026-06-29'),
  ('man_utd',        'Michael Carrick',   25762, DATE '2026-01-13'),
  ('newcastle',      'Matthias Jaissle',  13959, DATE '2026-08-05'),
  ('nottm_forest',   'Oliver Glasner',    1534,  DATE '2026-07-06'),
  ('spurs',          'Roberto De Zerbi',  2424,  DATE '2026-03-31'),
  ('sunderland',     'Régis Le Bris',     6279,  DATE '2024-07-01')
)
UPDATE teams t SET
  manager_name        = truth.mgr,
  manager_photo_url   = 'https://media.api-sports.io/football/coachs/' || truth.coach_id || '.png',
  manager_started_on  = truth.started,
  manager_verified_at = now()
FROM truth WHERE t.id = truth.id;

-- Push the truth into the pages now, rather than waiting for the next
-- dynamic_only run. Where the NAME changes, the old prose described the old
-- manager, so blank it and flag it: gd-team-page rewrites it and clears the
-- flag. iOS renders the card on `name` alone, so nothing disappears meanwhile.
UPDATE team_pages tp SET
  content = jsonb_set(
    tp.content,
    '{cards,manager}',
    COALESCE(tp.content->'cards'->'manager', '{}'::jsonb)
      || jsonb_build_object(
           'name', t.manager_name,
           'photo_url', t.manager_photo_url,
           'updated_at', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
      || CASE
           WHEN tp.content->'cards'->'manager'->>'name' IS DISTINCT FROM t.manager_name
           THEN jsonb_build_object('summary', '', 'talking_point', NULL, 'summary_stale', true)
           ELSE '{}'::jsonb
         END,
    true),
  updated_at = now()
FROM teams t
WHERE t.id = tp.team_id AND t.manager_name IS NOT NULL;

-- Verification:
--   SELECT id, manager_name, manager_verified_at::date FROM teams
--    WHERE league_id=39 AND is_active ORDER BY id;
--   SELECT team_id, content->'cards'->'manager'->>'name',
--          content->'cards'->'manager'->>'summary_stale'
--     FROM team_pages ORDER BY 1;
