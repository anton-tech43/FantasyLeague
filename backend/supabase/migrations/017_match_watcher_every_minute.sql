-- 017_match_watcher_every_minute.sql
--
-- ⚠️  HISTORICAL ARTIFACT — DO NOT EMULATE THE INLINE JWT BELOW.
-- The `Bearer eyJ...` literal is overwritten by migrations 019 + 020 (Vault
-- accessor pattern). May 17 2026 outage was caused by drifting Vault state
-- against this exact pattern. See IOS_GOTCHAS.md #14 + lesson 57.
--
-- Original migration purpose:
-- Switch match-watcher from every 5 min to every minute.
--
-- Rationale: on paid API-Football tier (~7,500 calls/day quota), 1,440
-- calls/day is ~20% utilisation with 5x headroom. The user-facing payoff is
-- post-match push latency dropping from ~3-5 min worst case to ~1-2 min
-- (capped by API-Football's own ~30-60s reporting lag). For "your
-- boyfriend's team just won" pings, those minutes matter — he's still on
-- the walk home from the pub when she gets the heads-up.

-- Drop the old 5-min schedule
SELECT cron.unschedule('match-watcher-5min')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'match-watcher-5min');

-- Re-create at every-minute cadence. Same hardcoded URL+key pattern.
SELECT cron.schedule(
    'match-watcher-1min',
    '* * * * *',
    $$SELECT net.http_post(
        url := 'https://cwgpsmbunrocrofziqad.supabase.co/functions/v1/match-watcher',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer <REDACTED-LEGACY-SERVICE-ROLE-JWT-ROTATED-2026-05-11>'
        ),
        body := '{}'::jsonb
    )$$
);
