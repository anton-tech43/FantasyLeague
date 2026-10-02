-- 125: the day-before push, "Leeds tomorrow", which opens Pre-game in My Turn.
--
-- matchday-reminder?mode=prep sends it once per (team, kickoff) to the club's
-- followers at 09:00 London on the day before the game (Anton, 2026-10-02).
-- The cron runs at 07:00 and 08:00 UTC; the function sends only when it is
-- 09:00 in London, so the hour holds on both sides of the clock change.

BEGIN;

-- Idempotency, as matchday_reminders_sent (063): claim the row, then send.
CREATE TABLE IF NOT EXISTS public.prep_reminders_sent (
  team_id      text NOT NULL,
  kickoff_time timestamptz NOT NULL,
  sent_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (team_id, kickoff_time)
);

ALTER TABLE public.prep_reminders_sent ENABLE ROW LEVEL SECURITY;
-- Service role only. Name the roles: Supabase's default privileges give anon
-- and authenticated explicit grants that FROM PUBLIC does not touch.
REVOKE ALL ON TABLE public.prep_reminders_sent FROM PUBLIC, anon, authenticated;

SELECT cron.schedule(
  'goaldigger-prep-reminder',
  '0 7,8 * * *',
  $$
    SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/matchday-reminder?mode=prep',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb
    )
  $$
);

COMMIT;

-- Verification:
--   SELECT has_table_privilege('anon', 'public.prep_reminders_sent', 'SELECT');  -- f
--   SELECT schedule FROM cron.job WHERE jobname = 'goaldigger-prep-reminder';     -- 0 7,8 * * *
