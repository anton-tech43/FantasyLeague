# Development Notes

## API-Football Setup (2024-03-20)

### Current Configuration

**API Service:** API-Football (api-sports.io)
**Plan:** Free Tier (100 requests/day)
**API Key:** Stored in `.env` file
**Season Used for Development:** 2024

### Why 2024 Season?

The free tier only provides access to historical seasons (2022-2024), not the current 2025/2026 season. To build and test the app without paying:

- ✅ **Development:** Use 2024 season data
- ✅ **Testing:** Verify all features work with real data
- ✅ **Architecture:** Build entire pipeline end-to-end
- ⏰ **Before Launch:** Upgrade to paid tier ($30/month) or switch to football-data.org (free with current season)

### What Works with 2024 Data

| Endpoint | Status | Notes |
|----------|--------|-------|
| `/fixtures?team={id}&season=2024&league=39` | ✅ Working | All 38 matches per team |
| `/standings?league=39&season=2024` | ✅ Working | Final 2024 standings |
| `/teams/statistics?team={id}&season=2024&league=39` | ✅ Working | Form, goals, etc. |
| `/injuries?team={id}&season=2024&league=39` | ⚠️ Limited | May be empty on free tier |

### Migration Path to Production

When ready to launch with real users:

**Option A: Upgrade API-Football**
- Cost: $30/month
- Change: Update `season=2024` to `season=2025` in all API calls
- Benefit: More comprehensive data, same API structure

**Option B: Switch to football-data.org**
- Cost: Free
- Change: Update API endpoints and authentication header
- Benefit: Free tier includes current season data

### Request Budget

With optimized polling (every 3 hours):
- **Non-matchday:** ~37 requests/day
- **Matchday:** ~65 requests/day
- **Free tier limit:** 100 requests/day ✅

### Team IDs (Verified)

- **Arsenal:** 42 ✅
- **Manchester United:** 33 ✅
- **West Ham:** 48 ✅

### Authentication

All requests require header:
```
x-apisports-key: {YOUR_API_KEY}
```

### Testing Commands

```bash
# Test Arsenal fixtures
curl -H "x-apisports-key: $API_FOOTBALL_KEY" \
  "https://v3.football.api-sports.io/fixtures?team=42&season=2024&league=39"

# Test standings
curl -H "x-apisports-key: $API_FOOTBALL_KEY" \
  "https://v3.football.api-sports.io/standings?league=39&season=2024"

# Test team stats
curl -H "x-apisports-key: $API_FOOTBALL_KEY" \
  "https://v3.football.api-sports.io/teams/statistics?team=42&season=2024&league=39"
```

---

## Next Steps

- [ ] Set up Supabase (backend database)
- [ ] Set up Anthropic Claude API (AI content generation)
- [ ] Build data-fetcher Edge Function (fetch from API-Football)
- [ ] Build content-generator Edge Function (Claude API integration)
- [ ] Test entire pipeline with 2024 season data
- [ ] Before launch: Upgrade API or switch to current season API
