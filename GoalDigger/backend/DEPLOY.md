# Goal Digger Backend — Deployment Guide

## Prerequisites

1. **Supabase account** — sign up at https://supabase.com
2. **Supabase CLI** — `brew install supabase/tap/supabase` (macOS) or download from https://github.com/supabase/cli/releases
3. **API keys** (see `.env.example` for full list):
   - `ANTHROPIC_API_KEY` — from https://console.anthropic.com
   - `API_FOOTBALL_KEY` — from https://www.api-football.com (Pro plan ~$30/month)
   - Apple Developer account ($99/year) for APNs keys (Phase 5, can skip for now)

## Step 1: Create Supabase Project

```bash
supabase login
supabase projects create "goal-digger" --org-id <your-org-id> --region eu-west-1
```

Note the **Project URL** and **Service Role Key** from the dashboard.

## Step 2: Link and Deploy Database

```bash
cd GoalDigger/backend
supabase link --project-ref <project-ref>

# Apply the schema migration
supabase db push

# Seed the 3 teams
psql <database-url> -f seed/seed_teams.sql
```

Or use the Supabase SQL editor to run `seed/seed_teams.sql` manually.

## Step 3: Set Secrets

```bash
supabase secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  API_FOOTBALL_KEY=... \
  APNS_KEY_ID=... \
  APNS_TEAM_ID=... \
  APNS_KEY_P8=... \
  APNS_BUNDLE_ID=com.goaldigger.app \
  APNS_ENVIRONMENT=development
```

## Step 4: Deploy Edge Functions

```bash
supabase functions deploy data-fetcher
supabase functions deploy content-generator
supabase functions deploy content-reviewer
supabase functions deploy notification-sender
supabase functions deploy matchday-scheduler
supabase functions deploy health-check
```

## Step 5: Enable pg_cron Jobs

Uncomment the cron jobs at the bottom of `001_initial_schema.sql` and run them via the SQL editor, replacing `xxxxx.supabase.co` with your actual project URL:

```sql
-- Data fetcher: every 30 minutes between 08:00 and 23:00 GMT
SELECT cron.schedule(
    'data-fetcher',
    '*/30 8-23 * * *',
    $$SELECT net.http_post(
        url := 'https://<project-ref>.supabase.co/functions/v1/data-fetcher',
        body := '{}'::jsonb,
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer <service-role-key>"}'::jsonb
    )$$
);

-- Matchday scheduler: daily at 07:00 UTC
SELECT cron.schedule(
    'matchday-scheduler',
    '0 7 * * *',
    $$SELECT net.http_post(
        url := 'https://<project-ref>.supabase.co/functions/v1/matchday-scheduler',
        body := '{}'::jsonb,
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer <service-role-key>"}'::jsonb
    )$$
);
```

## Step 6: Verify

```bash
# Test health check
curl https://<project-ref>.supabase.co/functions/v1/health-check \
  -H "Authorization: Bearer <anon-key>"

# Manual data fetch
curl -X POST https://<project-ref>.supabase.co/functions/v1/data-fetcher \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json"
```

## Local Development (requires Docker)

```bash
cd GoalDigger/backend
supabase start        # Starts local Postgres, Auth, etc.
supabase db reset     # Applies migrations + seed
supabase functions serve  # Serves all Edge Functions locally
```

Local URLs will be printed by `supabase start` (typically `http://localhost:54321`).

## Environment Variables Reference

| Variable | Required | Source |
|----------|----------|--------|
| `SUPABASE_URL` | Auto-set | Supabase dashboard |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-set | Supabase dashboard |
| `SUPABASE_ANON_KEY` | Auto-set | Supabase dashboard |
| `ANTHROPIC_API_KEY` | Yes | console.anthropic.com |
| `API_FOOTBALL_KEY` | Yes | api-football.com |
| `APNS_KEY_ID` | Phase 5 | Apple Developer portal |
| `APNS_TEAM_ID` | Phase 5 | Apple Developer portal |
| `APNS_KEY_P8` | Phase 5 | .p8 file contents |
| `APNS_BUNDLE_ID` | Phase 5 | Xcode project |
| `APNS_ENVIRONMENT` | Phase 5 | "development" or "production" |
