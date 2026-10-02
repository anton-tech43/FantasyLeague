-- What a club's SUPPORTERS are called, where they have a name of their own
-- (Gooners, Kopites), as distinct from the club nickname basics already has.
-- Human-verified like manager_name (085): researched 2026-10-02 against each
-- club's Wikipedia supporters section. NULL where fans are just "[club]
-- fans" or go by the club nickname (14 of 20): no invented names. Never
-- add Spurs' "Yid Army" (an antisemitic slur the club asks fans to drop).
ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS fan_name text,
  ADD COLUMN IF NOT EXISTS fan_name_verified_at timestamptz;

UPDATE public.teams t SET fan_name = v.fan_name, fan_name_verified_at = '2026-10-02'
FROM (VALUES ('arsenal', 'Gooners'), ('coventry', 'Sky Blue Army'), ('everton', 'Evertonians'),
             ('liverpool', 'Kopites'), ('newcastle', 'Toon Army'), ('sunderland', 'Mackems')) v(id, fan_name)
WHERE t.id = v.id;
