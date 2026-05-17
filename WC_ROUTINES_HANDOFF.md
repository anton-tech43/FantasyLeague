# V2.0 World Cup — Cloud Routines Handoff

> **For:** Anton (routines repo owner)
> **From:** V2.0 backend + iOS work (this repo)
> **Status:** ✅ Prompts updated + new `gd-news-wc` routine landed 2026-05-17 (anton-tech43/goaldigger-routines `b724f5d` → `fe6e3c2` → gd-news-wc setup). Smoke test pending first scheduled fire.
> **Deadline:** Routine prompts updated + redeployed before **June 4** so first WC content surfaces a few days before kickoff (June 11). Daily routines fire from June 5 onwards to validate, with full production traffic from June 11.

---

## Context

The main app (this repo) is fully V2.0-ready: `teams` table is polymorphic (`entity_type IN ('club','country')`), data-fetcher pulls API-Football data for all 48 WC 2026 countries, team-page-generator + team-season-state-generator already produce country pages with manager + 3 players (with photos) + group position labels. match-watcher + matchday-scheduler are parameterised and pick up WC fixtures automatically alongside PL.

What's NOT yet adapted: the **Cloud Routine prompts** that produce daily news / matchday briefs / Saturday quiz / Sunday brief / Insider items / Player Dossier / Live brief. Their voice + structure assume "Premier League team" context. They need to detect whether the trigger payload's `team_id` is a club or country and shift voice accordingly.

The wrapper script for each routine already reads `team_id` from the trigger payload. The new field to add is **`entity_type`**: a one-line SQL lookup at the start of each post-script returning `'club'` or `'country'`, then inject that into the prompt as `{{league_context}}`.

---

## The pattern — every routine follows this shape

### Wrapper script (`post_<routine>.sh`)

At the top, after sourcing env vars, add a single Supabase REST call to resolve the entity type. Example:

```bash
ENTITY_TYPE=$(curl -s \
  "$SUPABASE_URL/rest/v1/teams?id=eq.$TEAM_ID&select=entity_type" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  | jq -r '.[0].entity_type // "club"')

case "$ENTITY_TYPE" in
  country)
    LEAGUE_CONTEXT="FIFA World Cup 2026 (national team competing at the tournament in USA, Canada, Mexico from June 11 to July 19, 2026). Players represent their country, NOT their club. The 'season' is the tournament window only."
    ;;
  club|*)
    LEAGUE_CONTEXT="Premier League (2025-26 season — August to May). Standard club football context."
    ;;
esac

# Then pass $LEAGUE_CONTEXT to the prompt as {{league_context}}
```

### Prompt file (`<ROUTINE>_PROMPT.md`)

Replace any hardcoded "Premier League" / "PL" mentions with the placeholder, and add a CONTEXT section near the top:

```markdown
## COMPETITION CONTEXT
{{league_context}}
```

Then update other PL-assumption text to be entity-agnostic ("his team" → "his lot", or context-dependent variants).

---

## Per-routine changes

### 1. `gd-news` (daily, 06:30 12:30 18:30 00:30 UTC, 4 fires/day) — **PL CLUBS ONLY**

**File:** `PROMPT.md` and `post_news.sh`

**Changes landed 2026-05-17:**
- COMPETITION CONTEXT block at top + WC-MODE NOTES block at bottom (both inserted by the iOS/backend agent).
- Workflow Step 2 `a-bis` instructs Claude to run the entity_type lookup per team (no-op for `gd-news` since all 20 PL clubs are `entity_type='club'`, but the structure exists for parity with `gd-news-wc`).
- This routine stays scoped to **20 PL clubs** to avoid context blowout.

### 1b. `gd-news-wc` (daily, 06:35 12:35 18:35 00:35 UTC, 4 fires/day) — **48 WC COUNTRIES**

**File:** `PROMPT_WC.md` and `fetch_news_wc.sh` (NEW — added 2026-05-17)

**Changes landed 2026-05-17:**
- New `fetch_news_wc.sh` script: hardcoded 48 WC country mappings (id:api_football_id:display_name), queries `league=1&season=2026`, curated 4-RSS international shortlist (BBC Sport, Guardian, ESPN FC, Goal.com), shared global standings fetch (single call for all 12 groups instead of per-country).
- New `PROMPT_WC.md` (~80 lines): delta-on-PROMPT.md. Reuses all voice rules + GROUNDING + SAFE-REWRITE + BATTLE-TESTED rules + post pipeline; only diffs are entity scope (48 countries), fetch script (`fetch_news_wc.sh`), and pacing (compact every 6 countries vs 5).
- `gd-news-wc` cloud routine created via RemoteTrigger, 5-min offset from `gd-news` to avoid API-Football rate-limit overlap.

**Per-country processing**: same `b → h` sub-steps as PROMPT.md. RSS filtering uses the `display_name` field from the fetch output (`"Argentina"` not `"argentina"`).

**Verify:** Trigger `gd-news-wc` manually. Audit recent `content_items` rows where `team_id IN (SELECT id FROM teams WHERE entity_type='country')`. Check 5 rows: voice country-aware, `team_id` matches a country row, no club-affiliation hallucinations for national-team players.

### 2. `gd-matchday` (post-FT, fired by match-watcher)

**File:** `MATCHDAY_PROMPT.md` and `post_matchday.sh`

**Changes:**
- Add `{{league_context}}` injection.
- The MATCH DAY card structure (immersive_headline + headline + body + talking_points) is the same. Just the framing differs.
- For WC group stage: emphasise group implications ("3 points + 3 goals = top of Group D for now"), advancement math ("they need to beat X to qualify").
- For WC knockouts: even higher stakes ("if they lose this, the next World Cup is 4 years away").
- Voice stays cheeky-friend.
- Be careful about score data — the prompt already gets `home_goals`/`away_goals` from match-watcher's payload. For WC group stage there's also the wider group context that's NOT in the payload — leave it to the LLM to know "Group D" facts unless the upstream payload adds it.

**Verify:** When the first WC match finishes on June 11, match-watcher fires `gd-matchday` for both teams. Check `content_items` for two rows with the country team_ids.

### 3. `gd-saturday-quiz` (Saturday 07:00 UTC)

**File:** `QUIZ_PROMPT.md` and `post_quiz.sh`

**Changes:**
- During WC (June 11 - July 19, all of which contains 5 Saturdays), the quiz should be tournament-themed.
- Specific tweaks:
  - Q1 (factual): can be about the team's WC history, group rivals, manager
  - Q2 (recent): about the previous game or upcoming opponent
  - Q3 (hypothetical "If..."): tournament narrative ("If they beat Spain in the QF...")
- Outside tournament window for country users (pre-June 11 and post-July 19), the quiz can fall back to general team trivia OR be suppressed (post-script can return early if `entity_type == 'country'` and date is outside tournament window).

### 4. `gd-sunday-brief` (Sunday 09:00 UTC, T2+)

**File:** `SUNDAY_BRIEF_PROMPT.md` and `post_sunday_brief.sh`

**Changes:**
- "Week ahead" framing shifts for WC.
- During tournament: "this week his team plays X on Day, Y on Day" with implications per game.
- Pre-tournament: countdown framing ("11 days until kickoff", "his squad finally announced — here's who made it").
- Post-tournament: appropriate wind-down or off-season holding pattern.

### 5. `gd-insider` (daily 02:00 UTC)

**File:** `INSIDER_PROMPT.md` and `post_insider.sh`

**Changes:**
- Insider rotates through 4 types (player_form, club_news, fan_culture, history). For countries:
  - `player_form` → fitness check, injury risk, recent club form (for players from PL clubs)
  - `club_news` → squad announcements, FA-level news (manager appointments, federation tensions)
  - `fan_culture` → tournament atmosphere, country-specific traditions
  - `history` → past WC moments for this country
- The Insider voice is more conspiratorial — keep that even for WC.

### 6. `gd-player-dossier` (Sunday 17:00 UTC)

**File:** `PLAYER_DOSSIER_PROMPT.md` and `post_player_dossier.sh`

**Changes:**
- For PL clubs: covers the 3 top_players from team_pages.
- For WC countries: same — covers the country's 3 top_players (which we've already populated, e.g., Bellingham/Saka/Foden for England).
- Voice: the dossier should mention CLUB context for a national-team player ("he plays for Real Madrid the rest of the year, but in the white shirt..."). Adds richness vs. just listing stats.

### 7. `gd-live-brief` (HT + 75', fired by match-watcher)

**File:** `LIVE_BRIEF_PROMPT.md` and `post_live_brief.sh`

**Changes:**
- The live brief is fired with `home_goals`/`away_goals` from match-watcher.
- Tournament context (group standings, advancement implications) should be referenced for WC matches but the LLM may or may not have this data — leave it as freeform "react to the scoreline" content rather than forcing context that isn't in the payload.

### 8. `gd-season-state` (daily 06:30 UTC) — ALREADY GENERIC

**File:** `SEASON_STATE_PROMPT.md` and `post_season_state.sh`

This one is **already updated** in the backend repo (this repo) via the team-season-state-generator's `{{league_context}}` template variable. Equivalent change should land in the routines repo for consistency, but it's not blocking (the Edge Function path is what runs in prod).

---

## Order of rollout

1. **By May 23:** `gd-news` updated. First country news (England, Brazil, etc.) starts appearing in country users' feeds.
2. **By May 30:** `gd-matchday` updated (only fires for WC after June 11 anyway, but needs to be ready).
3. **By June 4:** `gd-saturday-quiz` + `gd-sunday-brief` + `gd-insider` + `gd-player-dossier` updated.
4. **June 5-10:** Soft testing — manually trigger each routine for a country and verify output quality.
5. **June 11:** Tournament kickoff. All routines firing for both PL and WC entities.

---

## What I (the iOS/backend agent) already verified

- ✅ Migration 032 applied — 23 PL clubs + 48 WC countries coexist in `teams`.
- ✅ Migration 033 applied — `device_tokens.country_id` column with nullable `team_id`.
- ✅ `data-fetcher` parameterised — pulls API-Football data for both leagues.
- ✅ `team-page-generator` country-aware — 48 country pages generated with managers + photos + group positions.
- ✅ `team-season-state-generator` country-aware — 45/48 country season states populated (3 awaiting WC schedule from API-Football).
- ✅ `match-watcher` parameterised — reads `SELECT DISTINCT league_id FROM teams`, iterates leagues, deploys cleanly, smoke-tested with `active_leagues: [39, 1]`.
- ✅ `matchday-scheduler` parameterised — same pattern, smoke-tested.
- ✅ iOS V2.0 onboarding flow: Welcome → Her → His → **Country** → **Optional PL** → Tier → Notif → Calendar → Meet team (country-aware) → Meet manager (country-aware) → How it works.
- ✅ `CountrySelectionView` (48 countries grouped by confederation), `OptionalPLTeamView`, `WCMigrationSheetView` for existing users.
- ✅ `MeetTeamView` and `MeetManagerView` accept `entityId: String` (works for both clubs and countries via `team_pages` table).
- ✅ `FeedContext.country(Country)` case + `AppState.selectedCountry` persisted.
- ✅ FeedView country empty state — "We're warming up his {country} coverage" — exists for the pre-routines-running window.
- ✅ TeamPageView resolves either Team or Country by ID for the "His Team" tab.
- ✅ NotificationService + APIClient.registerToken pass `country_id` to device_tokens.

---

## What I (the iOS/backend agent) need from you

- [ ] Update + deploy the 7 Cloud Routine prompts (above).
- [ ] Smoke test each routine for England (or any country) before June 11.
- [ ] App Store submission for V2.0 — schedule for **June 4** to leave a 7-day Apple review buffer. Process is manual via Xcode Archive + App Store Connect.
- [ ] Marketing assets — screenshots showing the WC onboarding flow + the empty-state copy for "his country" feed. The V2.0 build is on the simulator now; screenshots can be captured via Xcode → Window → Devices.
