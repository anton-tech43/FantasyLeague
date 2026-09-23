-- 108_token_rate_limit_stops_punishing_the_victim.sql
--
-- check_token_rate_limit (migration 001) raises when more than 500 device_tokens
-- rows were created in the last hour, counted GLOBALLY with no per-caller
-- identity. It has the failure mode backwards.
--
-- Anyone can call register_device_token — it is granted to anon by design, that
-- is how a phone registers. So ~500 cheap calls with random 64-hex strings trip
-- the trigger, and from then on every REAL new install fails to register for the
-- next hour. The iOS call site is a `try?`, so the user sees nothing: they
-- finish onboarding and simply never get a push. The attacker loses nothing.
-- The junk rows, meanwhile, are harmless and self-cleaning: the first send to a
-- fake token gets an APNs 400/410 and notification-sender deactivates it.
--
-- So the exception is the damage and the rows are not. Inverted:
--
--   * up to WARN_PER_HOUR      — silence, as now
--   * WARN_PER_HOUR and above  — one pipeline_health row per insert, visible in
--                                db-health.sh, registration still succeeds
--   * HARD_CAP and above       — reject. At 20k rows an hour against a user base
--                                in the tens this is not a launch spike, and
--                                letting the table grow without bound is then
--                                the greater harm.
--
-- The warning path is why 'token_register' joins the stage CHECK: without a
-- stage that fits, the insert inside the trigger would fail the constraint and
-- take the registration down with it.

BEGIN;

ALTER TABLE pipeline_health DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;
ALTER TABLE pipeline_health ADD CONSTRAINT pipeline_health_stage_check
    CHECK (stage = ANY (ARRAY[
        'fetch', 'generate', 'review', 'safety_review', 'publish',
        'live_brief_fire', 'matchday_fire', 'routine_post', 'apns_send',
        'cron_invoke', 'morning_push', 'starting_xi_fire', 'consequence_fire',
        'content_audit', 'watch', 'page_refresh', 'news_feeds',
        'token_register'
    ]));

CREATE OR REPLACE FUNCTION check_token_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    -- Organic signup for this app is in the single digits per day. 500 in an
    -- hour is already nothing like normal, which is why it is worth a row in
    -- pipeline_health; it is just not worth locking out the next real install.
    warn_per_hour CONSTANT INTEGER := 500;
    hard_cap      CONSTANT INTEGER := 20000;
    recent        INTEGER;
BEGIN
    SELECT COUNT(*) INTO recent
    FROM public.device_tokens
    WHERE created_at > NOW() - INTERVAL '1 hour';

    IF recent >= hard_cap THEN
        RAISE EXCEPTION 'device_tokens registration flood: % rows in the last hour', recent;
    END IF;

    IF recent >= warn_per_hour THEN
        -- Best effort. A failure to log must never fail a registration.
        BEGIN
            INSERT INTO public.pipeline_health (stage, status, message, target)
            VALUES ('token_register', 'partial',
                    format('%s device_tokens rows in the last hour (warn at %s, reject at %s)',
                           recent, warn_per_hour, hard_cap),
                    'rate_limit');
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$;

-- SECURITY DEFINER above is deliberate and narrow: the trigger now writes to
-- pipeline_health, which anon cannot reach, and it runs on an INSERT anon can
-- cause. search_path is pinned empty and every reference is schema-qualified,
-- so there is nothing for a caller to shadow.
REVOKE EXECUTE ON FUNCTION public.check_token_rate_limit() FROM PUBLIC, anon, authenticated;

COMMIT;
