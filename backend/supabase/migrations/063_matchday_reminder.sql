-- 063_matchday_reminder.sql
-- "His team plays" matchday reminder push.
--
-- Why: the live goal/HT/FT pushes only fire DURING a match, so a follower got
-- no heads-up that his team plays today. This adds a single deterministic
-- reminder per fixture, fired the morning of the match (09:00 Europe/Stockholm,
-- the audience market). For after-midnight kickoffs (this WC is US-hosted, so
-- European kickoffs are often 02:00-04:00 local) the morning-of would land
-- after the game, so the fixture instead falls into the PREVIOUS morning's 24h
-- window and the reminder fires the day before. The matchday-reminder Edge
-- Function reads team_season_state.next_fixtures (known days ahead) and pushes
-- to the playing country's followers.

-- Idempotency store: one row per (team, kickoff). The function claims a row
-- before sending; a duplicate-key insert means the reminder already went out.
CREATE TABLE IF NOT EXISTS matchday_reminders_sent (
  team_id      text NOT NULL,
  kickoff_time timestamptz NOT NULL,
  sent_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (team_id, kickoff_time)
);

-- Service-only, matching the rest of the schema (post-launch RLS sweep).
ALTER TABLE matchday_reminders_sent ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "matchday_reminders_sent_service_only" ON matchday_reminders_sent;
CREATE POLICY "matchday_reminders_sent_service_only" ON matchday_reminders_sent
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Daily at 07:00 UTC = 09:00 Europe/Stockholm (CEST, the WC window is entirely
-- in DST). Reminds about any followed-team fixture kicking off in the next 24h.
SELECT cron.schedule(
  'goaldigger-matchday-reminder',
  '0 7 * * *',
  $$
    SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/matchday-reminder',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || get_cron_service_key()
        ),
        body := '{}'::jsonb
    )
  $$
);

-- Verification:
--   SELECT jobname, schedule, active FROM cron.job
--    WHERE jobname = 'goaldigger-matchday-reminder';
-- Expected: schedule = '0 7 * * *', active = true.
