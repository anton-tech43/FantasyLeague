-- 073_match_status_reaper.sql
-- PUSH-1 (AUDIT_FINDINGS): match_status_state had no reaper. A fixture that
-- stops being returned by the API while still in a live status (API drop,
-- date-roll edge, cancellation mid-feed) stays "live" forever in our state.
-- Consequences: if the feed later resumes, match-watcher's detectGoal compares
-- the resumed score against the FROZEN one and can fire a phantom goal / late-FT
-- push; and a stuck la_started=true, la_ended=false row means match-watcher
-- never server-ends the Live Activity.
--
-- No real match is 4h past kickoff while still live (max ~2.5h incl. extra time
-- + penalties), so terminalizing past-kickoff non-terminal rows is always safe.
-- Pure-SQL daily cron (no HTTP/APNs): flips stuck rows to 'ABD' and marks the
-- Live Activity ended in our state (the device's Live Activity then auto-dismisses
-- on its stale date). Stops phantom goals + match-watcher churn on dead rows.

SELECT cron.schedule(
  'match-status-reaper',
  '0 5 * * *',   -- daily 05:00 UTC (quiet hour, after any late US-night WC game)
  $reaper$
    UPDATE match_status_state
    SET status = 'ABD',
        la_ended = true,
        last_checked = now()
    WHERE status NOT IN ('FT','AET','PEN','ABD','PST','CANC','AWD','WO','TBD')
      AND kickoff_time < now() - interval '4 hours'
  $reaper$
);
