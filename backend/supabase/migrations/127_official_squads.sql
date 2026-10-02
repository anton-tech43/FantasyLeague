-- 127: the Premier League's own squad lists as the second source for players.
--
-- API-Football's squads carry stale shirt numbers (Mitoma 22, officially 7;
-- two men on one number at 15 clubs) and youth players who are not in the
-- registered squad ("What number does Luka Bentt wear?"). The pre-launch audit
-- on 2026-10-02 checked all twenty clubs against the Premier League's squad
-- endpoint, which agreed with every human check. Per DATA_SOURCES.md the field
-- moves into our own columns: the official-squads Edge Function writes these
-- after the daily squad sync, and the app reads them.

BEGIN;

ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS pl_squad_id integer;
UPDATE public.teams t SET pl_squad_id = v.pl FROM (VALUES
  ('arsenal', 3), ('aston_villa', 7), ('bournemouth', 91), ('brentford', 94), ('brighton', 36),
  ('chelsea', 8), ('coventry', 9), ('crystal_palace', 31), ('everton', 11), ('fulham', 54),
  ('hull', 88), ('ipswich', 40), ('leeds', 2), ('liverpool', 14), ('man_city', 43),
  ('man_utd', 1), ('newcastle', 4), ('nottm_forest', 17), ('spurs', 6), ('sunderland', 56)
) AS v(id, pl) WHERE t.id = v.id;

ALTER TABLE public.players ADD COLUMN IF NOT EXISTS official_number integer;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS in_official_squad boolean;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS official_checked_at timestamptz;

-- After the 05:30 squad sync, which would otherwise put the feed's numbers back.
SELECT cron.schedule(
  'goaldigger-official-squads',
  '50 5 * * *',
  $$
    SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/official-squads',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 60000
    )
  $$
);

COMMIT;

-- Verification:
--   SELECT count(*) FILTER (WHERE in_official_squad), count(*) FILTER (WHERE in_official_squad = false)
--     FROM players WHERE team_id IN (SELECT id FROM teams WHERE pl_squad_id IS NOT NULL);
