-- 022_drop_season_state_edge_cron.sql
-- Unschedule the team-season-state-daily cron that migration 021 created.
--
-- Why: the team-season-state-generator Edge Function path was replaced by
-- the gd-season-state cloud routine (Anthropic-hosted Claude Code session,
-- runs daily at 01:00 UTC). The Edge Function path consistently drifted
-- into fan voice with Haiku 4.5 and once hallucinated a Champions League
-- semi-final for Arsenal when only PL data was in its input. The routine
-- path uses Sonnet 4.6, inherits PROMPT.md sister-voice rules, and has
-- hard validators in post_season_state.sh that reject fan-voice patterns.
--
-- Without dropping the cron, the Edge Function would fire daily at 06:00
-- UTC (5 hours after the routine) and overwrite the routine's well-voiced
-- rows with the older drift-prone output.
--
-- The Edge Function itself is left deployed but dormant. Re-attach a cron
-- if we ever want to fall back to the API path. The team-season-state
-- (read) endpoint stays in place and is unaffected — iOS still calls it.

SELECT cron.unschedule('team-season-state-daily')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'team-season-state-daily');
