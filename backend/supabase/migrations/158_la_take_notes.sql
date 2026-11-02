-- 158_la_take_notes.sql
--
-- Live takes phase 1 (docs/LIVE_TAKES_PLAN.md): the take is the `note` line
-- under the score on the Live Activity, per side.
--
-- la_takes     {"home": "<line>", "away": "<line>"}: the note each side's
--              followers see now. Carried in every update until a score
--              change, the change to HT or the end clears it (trap 2).
-- la_note_sig  the notes last sent, so a note change has its own signature
--              and never looks like a goal in la_sig (trap 3).
-- la_channels  {"production": {"home": id, "away": id, "neutral": id},
--               "development": {...}}: up to three broadcast channels per
--              environment, because a broadcast reaches everyone on the
--              channel and "they" must have an owner (trap 1). A device
--              following exactly one side starts on that side's channel;
--              both or neither starts on neutral, which never gets a note.
--              Replaces la_channel_id / la_channel_id_dev (157), whose values
--              move to the neutral slot. ponytail: the 157 columns stay
--              (unused) until a deploy that no longer selects them has run
--              for a while; drop them then.
--
-- la_channel_put() sets or removes one channel atomically; removal only when
-- the slot still holds the expected id, and empty objects collapse to NULL so
-- la_sweep_due() and the sweep can test IS NOT NULL.

BEGIN;

ALTER TABLE public.match_status_state
  ADD COLUMN IF NOT EXISTS la_takes jsonb,
  ADD COLUMN IF NOT EXISTS la_note_sig text,
  ADD COLUMN IF NOT EXISTS la_channels jsonb;

UPDATE public.match_status_state
   SET la_channels = jsonb_strip_nulls(jsonb_build_object(
         'production', CASE WHEN la_channel_id IS NOT NULL THEN jsonb_build_object('neutral', la_channel_id) END,
         'development', CASE WHEN la_channel_id_dev IS NOT NULL THEN jsonb_build_object('neutral', la_channel_id_dev) END)),
       la_channel_id = NULL,
       la_channel_id_dev = NULL
 WHERE la_channel_id IS NOT NULL OR la_channel_id_dev IS NOT NULL;

CREATE OR REPLACE FUNCTION public.la_channel_put(
  p_fixture_id integer,
  p_env text,
  p_audience text,
  p_channel_id text,
  p_expect text DEFAULT NULL
)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_n integer;
BEGIN
  IF p_env NOT IN ('production', 'development') OR p_audience NOT IN ('home', 'away', 'neutral') THEN
    RAISE EXCEPTION 'invalid env or audience';
  END IF;
  IF p_channel_id IS NOT NULL THEN
    UPDATE match_status_state
       SET la_channels = jsonb_set(
             COALESCE(la_channels, '{}'::jsonb) || jsonb_build_object(p_env, COALESCE(la_channels -> p_env, '{}'::jsonb)),
             ARRAY[p_env, p_audience], to_jsonb(p_channel_id))
     WHERE fixture_id = p_fixture_id;
  ELSE
    UPDATE match_status_state
       SET la_channels = NULLIF(
             jsonb_strip_nulls(la_channels || jsonb_build_object(p_env,
               NULLIF((la_channels -> p_env) - p_audience, '{}'::jsonb))),
             '{}'::jsonb)
     WHERE fixture_id = p_fixture_id
       AND la_channels -> p_env ->> p_audience = p_expect;
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n > 0;
END;
$function$;

REVOKE ALL ON FUNCTION public.la_channel_put(integer, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.la_channel_put(integer, text, text, text, text) TO service_role;

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
    -- 157/158: a channel left on a fixture that is over.
    SELECT 1
    FROM match_status_state s
    WHERE (s.la_channels IS NOT NULL OR s.la_channel_id IS NOT NULL OR s.la_channel_id_dev IS NOT NULL)
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
