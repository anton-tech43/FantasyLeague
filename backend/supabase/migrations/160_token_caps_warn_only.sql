-- 160: the token-registration caps warn, they no longer refuse (bug hunt
-- 2026-11-03 A-C2, MEDIUM).
--
-- The hard caps (129: 1 000 new device_tokens / 2 000 new live_activity_tokens
-- an hour, counted over ALL rows) were a lever, not a bound: 1 000 made-up
-- 64-hex tokens an hour with the key in the binary refused every REAL new
-- install's registration (reproduced in a rolled-back transaction: the next
-- genuine call raised "device_tokens registration flood: 1000 rows"), and the
-- same against register_la_token froze the lock-screen score of every Live
-- Activity started that hour. Real peaks are 3 and 33 an hour (10 and 43 a day).
--
-- A per-caller cap would fix both, but needs a client IP the caller cannot
-- forge. Whether x-forwarded-for reaching PostgREST is that could not be
-- verified from SQL (request.headers is empty outside an HTTP request, and
-- probing over HTTP needs the key), so it is not used. Instead:
--   * no refusal: a flood can no longer lock real devices out;
--   * a pipeline_health row when the hour crosses the warn line and the old
--     cap (once each, not one per insert as before, so the log cannot flood);
--   * the count stops at the old cap + 1 (LIMIT), so a flood does not make
--     every registration slower (anon's statement_timeout is 3 s);
--   * scripts/db-health.sh §4 alarms on new token rows per 24 h.
-- Format is still enforced by the RPCs (64 hex; LA 16-512 hex + CHECK).
--
-- ponytail: warn-only. If junk ever shows up, the upgrade is a per-IP cap
-- once Anton confirms x-forwarded-for is set by Supabase's gateway.

BEGIN;

CREATE OR REPLACE FUNCTION public.check_token_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    warn_per_hour  CONSTANT INTEGER := 25;
    alarm_per_hour CONSTANT INTEGER := 1000;   -- 129's hard cap, now a log line
    recent         INTEGER;
BEGIN
    -- A token we already hold is not new volume (the RPC's ON CONFLICT upsert).
    IF EXISTS (SELECT 1 FROM public.device_tokens WHERE apns_token = NEW.apns_token) THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO recent FROM (
        SELECT 1 FROM public.device_tokens
         WHERE created_at > now() - interval '1 hour'
         LIMIT alarm_per_hour + 1) s;

    IF recent = warn_per_hour OR recent = alarm_per_hour THEN
        -- Best effort. A failure to log must never fail a registration.
        BEGIN
            INSERT INTO public.pipeline_health (stage, status, message, target)
            VALUES ('token_register',
                    CASE WHEN recent >= alarm_per_hour THEN 'failure' ELSE 'partial' END,
                    format('%s device_tokens rows in the last hour (warn at %s, alarm at %s; never refused since 160)',
                           recent, warn_per_hour, alarm_per_hour),
                    'rate_limit');
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_la_token_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    -- Twice device_tokens': an install vends one push-to-start token and one
    -- update token per live match it shows.
    warn_per_hour  CONSTANT INTEGER := 50;
    alarm_per_hour CONSTANT INTEGER := 2000;
    recent         INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM public.live_activity_tokens WHERE token = NEW.token) THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO recent FROM (
        SELECT 1 FROM public.live_activity_tokens
         WHERE created_at > now() - interval '1 hour'
         LIMIT alarm_per_hour + 1) s;

    IF recent = warn_per_hour OR recent = alarm_per_hour THEN
        BEGIN
            INSERT INTO public.pipeline_health (stage, status, message, target)
            VALUES ('token_register',
                    CASE WHEN recent >= alarm_per_hour THEN 'failure' ELSE 'partial' END,
                    format('%s live_activity_tokens rows in the last hour (warn at %s, alarm at %s; never refused since 160)',
                           recent, warn_per_hour, alarm_per_hour),
                    'la_rate_limit');
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_token_rate_limit()    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_la_token_rate_limit() FROM PUBLIC, anon, authenticated;

COMMIT;
