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

## Security Audit (2026-04-03) — Agent 2

Full audit of iOS codebase. Findings below must be resolved before App Store submission.

### CRITICAL — Fix Before Launch

| # | Issue | File | Action |
|---|-------|------|--------|
| 1 | **API key hardcoded in source** — Supabase anon key (`sb_publishable_...`) is in `APIClient.swift:9`. Even though it's a publishable key, it's grep-able in the repo and can't differ per environment. | `Services/APIClient.swift` | Move to `.xcconfig` file excluded from git. Load via `Bundle.main.infoDictionary`. |
| 2 | **APNs device token stored in UserDefaults** — Full hex token stored unencrypted at `NotificationService.swift:34`. Readable on jailbroken devices or backup extraction. | `Services/NotificationService.swift` | Migrate to Keychain storage. Use `SecItemAdd`/`SecItemCopyMatching`. |

### HIGH — Fix Before Beta

| # | Issue | File | Action |
|---|-------|------|--------|
| 3 | **Clipboard writes without expiration** — Talking points copied to clipboard persist indefinitely and sync via Universal Clipboard. | `ContentDetailView.swift`, `SavedPointsView.swift` | Use `UIPasteboard.general.setItems()` with `.localOnly: true` and `.expirationDate: +120s`. |
| 4 | **Deep link doesn't validate team** — Push notification with crafted `content_id` could navigate to content from another team. | `FeedView.swift:287` | After fetch, verify `item.teamId` matches `appState.selectedTeam?.rawValue`. |
| 5 | **ISO8601DateFormatter race condition** — Decoder closure mutates shared `formatter.formatOptions`. Concurrent API calls corrupt parsing. | `Services/APIClient.swift:24` | Create two separate formatter instances (with/without fractional seconds). |

### MEDIUM — Fix Before v1.1

| # | Issue | File | Action |
|---|-------|------|--------|
| 6 | **SavedPointsService not thread-safe** — Read-modify-write on UserDefaults without atomicity. | `Services/SavedPointsService.swift` | Mark class `@MainActor`. |
| 7 | **No input length validation on names** — TextField accepts unlimited text. | `App/GoalDiggerApp.swift:118` | Add `.onChange` with 50-char cap. |
| 8 | **No storage limit on saved points** — Could exceed UserDefaults ~1MB limit. | `Services/SavedPointsService.swift` | Cap at 100 items in `toggle()`. |
| 9 | **CacheService silently swallows errors** — `try?` discards save/fetch failures. | `Services/CacheService.swift` | Add `#if DEBUG` logging on catch. |
| 10 | **selectedTeam nil not persisted** — `didSet` only saves non-nil values. | `Models/AppState.swift:12` | Call `removeObject(forKey:)` when nil. |

### Passed

- All `print()` wrapped in `#if DEBUG` — no production log leaks
- `moodEmoji` uses hardcoded allowlist — no injection possible
- Deep link UUID parsing validates format
- Clipboard is plain text only — no HTML/rich text
- No force unwraps in production code
- No WebViews or URL scheme handlers

---

## Next Steps

- [ ] Set up Supabase (backend database)
- [ ] Set up Anthropic Claude API (AI content generation)
- [ ] Build data-fetcher Edge Function (fetch from API-Football)
- [ ] Build content-generator Edge Function (Claude API integration)
- [ ] Test entire pipeline with 2024 season data
- [ ] Before launch: Upgrade API or switch to current season API
