-- 126: pause the day-before push until the app version that opens Pre-game
-- from it is out (Anton, 2026-10-02). The current App Store build would only
-- open the app on a tap. Turn it back on with:
--   SELECT cron.alter_job((SELECT jobid FROM cron.job WHERE jobname = 'goaldigger-prep-reminder'), active := true);
SELECT cron.alter_job((SELECT jobid FROM cron.job WHERE jobname = 'goaldigger-prep-reminder'), active := false);
