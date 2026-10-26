-- 135_la_end_sweep.sql
-- End Live Activities whose match is over and was never ended.
--
-- match-watcher sends one end push at the full-time tick, to the update tokens
-- it knows about, and then the fixture drops out of polling for good. A token
-- registered late, a failed send, a scheduler outage through full time, or a
-- match ABANDONED rather than finished (only FT/AET/PEN counted) left the
-- activity on her lock screen until iOS gave up hours later. On 2026-10-27:
-- 22 active update tokens for one abandoned match, 3 for finished ones.
--
-- match-watcher?sweep=la does the ending (it is already a named sender in
-- PUSH_RULES.md §4). This only decides whether there is anything to do, so the
-- cron costs one indexed query on the 99% of ticks with nothing due.

CREATE OR REPLACE FUNCTION public.la_sweep_due()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM live_activity_tokens t
    LEFT JOIN match_status_state s ON s.fixture_id = t.fixture_id
    WHERE t.kind = 'update' AND t.is_active
      AND (
        s.status IN ('FT','AET','PEN','ABD','CANC','PST','AWD','WO')
        OR s.kickoff_time < now() - interval '3 hours'
        OR (s.fixture_id IS NULL AND t.created_at < now() - interval '3 hours')
      )
  );
$$;
REVOKE ALL ON FUNCTION public.la_sweep_due() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.la_sweep_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, pg_temp
AS $$
BEGIN
  IF NOT public.la_sweep_due() THEN RETURN; END IF;
  PERFORM net.http_post(
    url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher?sweep=la',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || public.get_cron_service_key()
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
END;
$$;
REVOKE ALL ON FUNCTION public.la_sweep_tick() FROM PUBLIC, anon, authenticated;

SELECT cron.schedule('la-end-sweep', '*/10 * * * *', $$SELECT public.la_sweep_tick()$$);

-- Verification:
--   SELECT la_sweep_due();
--   SELECT count(*) FROM live_activity_tokens WHERE kind='update' AND is_active;  -- falls after a sweep
