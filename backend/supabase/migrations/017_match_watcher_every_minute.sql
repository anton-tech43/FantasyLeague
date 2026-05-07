-- 017_match_watcher_every_minute.sql
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
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3Z3BzbWJ1bnJvY3JvZnppcWFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDYwNjc1NiwiZXhwIjoyMDkwMTgyNzU2fQ.YfGy-tG-7h7_rsAX3lLQ9mYJr-MtSWhtK1K7xAQlvGI'
        ),
        body := '{}'::jsonb
    )$$
);
