-- 150: pipeline_health stage 'la_send' — Live Activity pushes become visible
-- (app council 2026-10-29).
--
-- match-watcher sent every Live Activity start, update and end without a row,
-- so how many priority-10 updates a match cost (iOS throttles past its budget,
-- and a throttled activity freezes the minute and delays the goal) could not
-- be measured. One row per fan-out now: target la:<fixture>:<event>:p<priority>,
-- message "<n> sent, <m> failed of <t>", http_status and the APNs reasons on
-- failure. Its own stage, not apns_send, so the alert-push counts in the
-- digest and the apns_send audits stay what they were.
-- Volume: about one row a minute per live match (the minute-only updates at
-- priority 5), ~100 a match.

BEGIN;

ALTER TABLE pipeline_health DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;
ALTER TABLE pipeline_health ADD CONSTRAINT pipeline_health_stage_check
    CHECK (stage = ANY (ARRAY[
        'fetch', 'generate', 'review', 'safety_review', 'publish',
        'live_brief_fire', 'matchday_fire', 'routine_post', 'apns_send',
        'cron_invoke', 'morning_push', 'starting_xi_fire', 'consequence_fire',
        'content_audit', 'watch', 'page_refresh', 'news_feeds',
        'token_register', 'la_send'
    ]));

COMMIT;

-- The two questions this answers (the matchday reminder writes apns_send rows
-- with target matchday_reminder:<team>:<fixture>, prep_reminder:… for the day-before one):
--
-- Live Activity pushes per match, by event and priority (fan_outs = updates):
--   SELECT split_part(target, ':', 2) AS fixture_id, split_part(target, ':', 3) AS event,
--          split_part(target, ':', 4) AS priority, count(*) AS fan_outs,
--          sum(substring(message FROM '(\d+) sent')::int)   AS pushes_sent,
--          sum(substring(message FROM '(\d+) failed')::int) AS pushes_failed,
--          string_agg(DISTINCT response_excerpt, ' ')       AS failure_reasons
--     FROM pipeline_health
--    WHERE stage = 'la_send' AND created_at > now() - interval '7 days'
--    GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;
--
-- Did the 07:00 reminder go out, and to how many (a claim with no row = it did not):
--   SELECT m.team_id, m.kickoff_time, p.created_at AS sent_at, p.status,
--          substring(p.message FROM '(\d+) sent')::int AS sent,
--          substring(p.message FROM '(\d+) failed')::int AS failed, p.response_excerpt
--     FROM matchday_reminders_sent m
--     LEFT JOIN pipeline_health p
--       ON p.stage = 'apns_send' AND p.target LIKE 'matchday\_reminder:' || m.team_id || ':%'
--      AND p.created_at BETWEEN m.kickoff_time - interval '1 day' AND m.kickoff_time
--    WHERE m.kickoff_time > now() - interval '7 days'
--    ORDER BY m.kickoff_time DESC, m.team_id;
