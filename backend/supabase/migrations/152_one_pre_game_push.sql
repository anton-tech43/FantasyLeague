-- 152: one pre-game push per match, and it retries (app council 2026-11-01,
-- LOCK-02-10/11).
--
-- matchday-reminder now runs every hour 07:00–19:00 UTC. The first run sends;
-- each later run reminds only for today's fixtures that have no row in
-- matchday_reminders_sent yet, until an hour before kickoff. That row was
-- already the lock, so a fixture is never reminded twice. It replaces:
--   * gd-morning-push (08:00 UTC fallback, its own templated copy): removed,
--     and the morning-push Edge Function is deleted with it.
--   * goaldigger-prep-reminder (day-before push, paused since 126): removed
--     with its code; 130_unpause_prep_reminder.sql.DO_NOT_APPLY is deleted.
-- prep_reminders_sent keeps its rows (history); nothing writes to it now.

SELECT cron.unschedule('gd-morning-push')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'gd-morning-push');
SELECT cron.unschedule('goaldigger-prep-reminder')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'goaldigger-prep-reminder');

SELECT cron.alter_job(
  (SELECT jobid FROM cron.job WHERE jobname = 'goaldigger-matchday-reminder'),
  schedule := '0 7-19 * * *'
);
