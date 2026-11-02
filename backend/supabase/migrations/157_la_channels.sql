-- 157_la_channels.sql
--
-- Broadcast-channel Live Activities (docs/LIVE_ACTIVITY_PLAN.md §5 step 3),
-- behind match-watcher's LA_CHANNELS secret (off by default).
--
-- A fixture's channel id, one per APNs environment: a channel created in the
-- sandbox cannot be used in production. Set when the first channel start for
-- the fixture goes out, cleared once the channel is deleted after the end.
--
-- la_sweep_due() also wakes the 10-minute la-end-sweep for a finished fixture
-- that still holds a channel, so a failed end broadcast is re-sent and the
-- channel deleted (Apple allows 10,000 per environment).

BEGIN;

ALTER TABLE public.match_status_state
  ADD COLUMN IF NOT EXISTS la_channel_id text,
  ADD COLUMN IF NOT EXISTS la_channel_id_dev text;

CREATE OR REPLACE FUNCTION public.la_sweep_due()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM live_activity_tokens t
    LEFT JOIN match_status_state s ON s.fixture_id = t.fixture_id
    WHERE t.kind = 'update' AND t.is_active
      AND (
        s.status IN ('FT','AET','PEN','ABD','CANC','PST','AWD','WO')
        OR (s.kickoff_time < now() - interval '3 hours'
            AND s.status NOT IN ('1H','HT','2H','ET','BT','P','INT','SUSP','LIVE'))
        OR s.kickoff_time < now() - interval '6 hours'
        OR (s.fixture_id IS NULL AND t.created_at < now() - interval '3 hours')
      )
  ) OR EXISTS (
    -- 157: a channel left on a fixture that is over.
    SELECT 1
    FROM match_status_state s
    WHERE (s.la_channel_id IS NOT NULL OR s.la_channel_id_dev IS NOT NULL)
      AND (
        s.status IN ('FT','AET','PEN','ABD','CANC','PST','AWD','WO')
        OR (s.kickoff_time < now() - interval '3 hours'
            AND s.status NOT IN ('1H','HT','2H','ET','BT','P','INT','SUSP','LIVE'))
        OR s.kickoff_time < now() - interval '6 hours'
      )
  );
$function$;

REVOKE ALL ON FUNCTION public.la_sweep_due() FROM PUBLIC, anon, authenticated;

COMMIT;
