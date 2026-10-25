-- 133_match_watcher_gate.sql
-- Stop paying for the 1 100 minutes a day when there is no football.
--
-- match-watcher-1min has fired every minute since migration 017, whether or not
-- anything is playing. Each tick costs a Vault read (get_cron_service_key), a
-- pg_net queue insert, an HTTPS round trip, a net._http_response row, and then
-- inside the function a claim_match_watcher_tick() write, a teams SELECT and a
-- poll_leagues() call — before it discovers there is nothing to watch and
-- returns. On an instance with six worker processes that is the single largest
-- repeated cost we control.
--
-- The gate introduces NO new judgement. poll_leagues() (migration 094) is
-- already the only thing deciding what the watcher polls: when it returns no
-- rows, buildPollPairs produces an empty plan, no fixtures are fetched and the
-- function does nothing. This migration asks the same question one layer
-- earlier, in SQL, before the HTTP call is paid for.
--
-- Its window is -4 hours to +35 minutes around a kickoff, plus anything
-- observed and unfinished, plus a per-club degrade branch for a stale fixture
-- feed. So the watcher still wakes 35 minutes before kick-off and stays awake
-- through the game and the hangover.
--
-- IT FAILS OPEN, and that is the whole safety argument. Between 21 August and
-- 6 September 2026 match-watcher was blind to all 30 Premier League fixtures
-- and nobody noticed (audit A17) — a gate that fails closed is how that
-- happens again, quietly. Any exception, and any NULL, means fire.
--
-- Note what is deliberately NOT changed: the job still runs every minute, so
-- pg_cron still writes a cron.job_run_details row every minute, so
-- db-health.sh section 3 ("recorded N of 1440 minutes") keeps working
-- unchanged. Unscheduling the job would have broken our best signal that the
-- watcher is alive.
--
-- Side effect to know about: match-watcher writes an hourly 'watch' heartbeat
-- row to pipeline_health from inside the function, so that row now appears only
-- around fixtures. Nothing alerts on it (checked 2026-10-25), and the external
-- heartbeat's new get_cron_startup_health() check covers liveness better.

CREATE OR REPLACE FUNCTION public.match_watcher_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, pg_temp
AS $$
DECLARE
  should_fire boolean;
BEGIN
  BEGIN
    SELECT EXISTS (SELECT 1 FROM public.poll_leagues()) INTO should_fire;
  EXCEPTION WHEN OTHERS THEN
    -- Fail open: a broken gate must never be the reason a goal goes unpushed.
    should_fire := true;
  END;

  IF should_fire IS NOT TRUE THEN
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || public.get_cron_service_key()
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
END;
$$;

REVOKE ALL ON FUNCTION public.match_watcher_tick() FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule('match-watcher-1min')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-watcher-1min');

SELECT cron.schedule('match-watcher-1min', '* * * * *',
                     $$SELECT public.match_watcher_tick()$$);

-- Verification:
--   SELECT command FROM cron.job WHERE jobname = 'match-watcher-1min';
--   SELECT has_function_privilege('anon','public.match_watcher_tick()','EXECUTE'); -- f
--   -- with no fixture in window, this writes no net._http_response row:
--   SELECT max(id) FROM net._http_response; SELECT match_watcher_tick();
--   SELECT max(id) FROM net._http_response;  -- unchanged
