-- 103_match_watcher_tick_lease.sql
-- Eight identical kickoff pushes (2026-09-09, Napoli v Arsenal).
--
-- pg_cron hit "job startup timeout" at 18:26 UTC and then ran the eight ticks it
-- had queued within three seconds of each other at 18:33. Every one of them read
-- match_status_state before any had written PREKICK_PUSH, so every one of them
-- sent the kickoff push: eight bodies, one phone. The marker was persisted
-- inside the tick, which is at-most-once only when ticks do not overlap.
--
-- Two locks, both in the database where the race is:
--
--  1. claim_match_watcher_tick(at): one tick per UTC minute. The first caller
--     inserts the minute and proceeds; every other caller in that minute gets
--     false and returns at once. A backlog of queued ticks collapses to one.
--
--  2. claim_fixture_marker(fixture_id, marker): an atomic append to
--     briefs_fired that returns true only for the caller that added it. Every
--     push (kickoff, each goal, half-time, full-time) claims its marker right
--     before sending, so even two ticks that slipped past the minute lock
--     cannot both send.

CREATE TABLE IF NOT EXISTS public.match_watcher_ticks (
  minute      timestamptz PRIMARY KEY,
  claimed_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.match_watcher_ticks ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.match_watcher_ticks IS
  'One row per UTC minute match-watcher has run for. Insert-or-nothing is the lock; rows older than a day are swept by the claim function.';

CREATE OR REPLACE FUNCTION public.claim_match_watcher_tick(at timestamptz DEFAULT now())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  won boolean;
BEGIN
  INSERT INTO public.match_watcher_ticks (minute)
  VALUES (date_trunc('minute', at))
  ON CONFLICT (minute) DO NOTHING;
  won := FOUND;
  IF won THEN
    DELETE FROM public.match_watcher_ticks WHERE minute < at - INTERVAL '1 day';
  END IF;
  RETURN won;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_fixture_marker(p_fixture_id integer, p_marker text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  UPDATE public.match_status_state
     SET briefs_fired = COALESCE(briefs_fired, '[]'::jsonb) || to_jsonb(p_marker)
   WHERE fixture_id = p_fixture_id
     AND NOT (COALESCE(briefs_fired, '[]'::jsonb) @> to_jsonb(ARRAY[p_marker]));
  RETURN FOUND;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_match_watcher_tick(timestamptz) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_fixture_marker(integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_match_watcher_tick(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_fixture_marker(integer, text) TO service_role;

-- Self-check, rolled back by the caller if wrapped; harmless otherwise.
DO $$
DECLARE a boolean; b boolean;
BEGIN
  a := public.claim_match_watcher_tick('2000-01-01 00:00:30+00');
  b := public.claim_match_watcher_tick('2000-01-01 00:00:45+00');
  IF NOT a OR b THEN RAISE EXCEPTION 'tick lease: expected (true,false), got (%,%)', a, b; END IF;
  DELETE FROM public.match_watcher_ticks WHERE minute = '2000-01-01 00:00:00+00';
END $$;
