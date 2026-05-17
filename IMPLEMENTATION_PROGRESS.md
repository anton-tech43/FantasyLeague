# GoalDigger iOS — Product Brief Implementation Progress

Tracking implementation of the updated product brief (April 2026).
Each phase is marked with its status and a summary of changes made.

> 👋 **New here?** Start with **[STATUS.md](./STATUS.md)** for a one-page snapshot of where the project is right now. Then come back here for the deep history.
>
> **Quick phase navigation:**
> - **Phase 1-15** — V1.0 build (Feb-April 2026): design system, models, content pipeline, PostgREST/RLS, push, paywall, App Store prep.
> - **Phase 16-22** — Pre-launch hardening (April-May 2026): launch-prep, matchday auto-trigger, push voice, ultrareview, App Store submission.
> - **Phase 23** — V1.1 content surfaces (May 12-13): Season Primer, Insider, Sunday Brief, Saturday Quiz, Player Dossier, Match-day Live.
> - **Phase 24-25** — V1.2/V1.3 onboarding redesign (May 15-16): value-first restructure, team crests, MeetTeam + MeetManager, SeasonPrimer kill.
> - **Phase 26 (current)** — V2.0 World Cup support (May 16+): polymorphic teams table, 48 countries, country-aware backend, iOS Country enum.
> - **Lessons learned** — Numbered rules (#1-52) appended to phases as we hit gotchas. See bottom of doc.

---

## Phase 1: Design System Foundation — COMPLETE

**Files modified:** Theme.swift, BadgeView.swift, ContentCard.swift, ContentDetailView.swift, FeedView.swift, SettingsView.swift, AppDelegate.swift, Info.plist

### 1.1 Color palette overhaul
- Removed `accentGreen` (#3DA66C), `accentWarm` (#D4725C), `accentSoft` (#F0DDD5)
- Added `charcoal` (#2C2C2C) and `mutedText` (#9B8FA0)
- `textPrimaryOnCard` → charcoal, `textSecondaryOnCard` → mutedText, `textTertiary` → mutedText
- `winTint`/`winBar` changed from green to hotRose opacity variants
- Zero green references remain in codebase

### 1.2 Badge colors
- NEWS badge: hotRose background, warmWhite text
- MATCH DAY badge: gold (#E8C547) background, charcoal text
- Badge corner radius: 8 → 999 (fully rounded pills)

### 1.3 Typography
- SF Rounded retained as fallback; TODO added for Plus Jakarta Sans font bundle
- `feedBadge` weight: bold → semibold
- `sectionHeader` weight: bold → semibold

### 1.4 Spacing & layout
- `cardSpacing`: 12 → 10
- Added `badgeCornerRadius` = 999

### 1.5 System appearance
- `UIUserInterfaceStyle` = Dark added to Info.plist (fixed brand colors, no dark mode adaptation)

### 1.6 Cursor tint
- Rose cursor (`#E8397D`) set globally via `UITextField.appearance()` and `UITextView.appearance()` in AppDelegate

### 1.7 Cascade fixes (removed color references)
- ContentCard.swift: "Read more" accentWarm → hotRose
- ContentDetailView.swift: talking point border accentWarm → hotRose
- ContentDetailView.swift: talking point background accentSoft.opacity(0.3) → hotRose.opacity(0.06)
- ContentDetailView.swift: bold prediction card accentSoft/accentWarm → hotRose variants
- ContentDetailView.swift: share button border/text accentWarm → hotRose
- FeedView.swift: freshness "caught up" checkmark .green → .hotRose
- SettingsView.swift: notification checkmark .green → .hotRose

**Build status:** Compiles successfully (iPhone 17 Simulator, Xcode 26 beta)

---

## Phase 2: Navigation Architecture — COMPLETE

**Files modified:** GoalDiggerApp.swift, FeedView.swift

### 2.1 TabView with 3 tabs
- Replaced single NavigationStack with `TabView` containing 3 tabs
- Tab 1: "Feed" (house icon) — own NavigationStack with feed path
- Tab 2: "His Team" (shield icon) — own NavigationStack with TeamPageView
- Tab 3: "Settings" (gearshape icon) — own NavigationStack with SettingsView

### 2.2 Tab bar styling
- Background: deep mauve (#2D1B2E) via UITabBarAppearance
- Top border: rose at 20% opacity (shadowColor)
- Active icon + label: rose (#E8397D)
- Inactive icon + label: warmWhite at 40% opacity
- Labels: "Feed", "His Team", "Settings"

### 2.3 FeedView toolbar cleanup
- Removed gear icon (Settings is now a tab)
- Removed NavigationLink to "teamPage" (His Team is now a tab)
- Team name pill: rose border, no chevron (display only)
- Removed `@Binding var navigationPath` — FeedView no longer owns nav path

### 2.4 Deep link handling
- Deep links switch to Feed tab (selectedTab = 0) then append to feedPath
- Auto-expand first item after onboarding uses deepLinkContentId via AppState

**Build status:** Compiles successfully

---

## Phase 3: Team Model Expansion — COMPLETE

**Files modified:** Team.swift

### 3.1 Expanded to all 20 PL clubs (2025/26 season)
- Added: Aston Villa, Bournemouth, Brentford, Brighton, Chelsea, Crystal Palace, Everton, Fulham, Ipswich, Leicester, Liverpool, Man City, Newcastle, Nottm Forest, Southampton, Spurs, Wolves
- Each has: rawValue (snake_case id), displayName, shortName, badgeImageName
- TODO comment: team list needs backend-driven updates before 2026/27 (relegation changes)

### 3.2 Search support
- Added `searchableText` property combining displayName + shortName + nicknames (lowercase)
- Nicknames: Gunners, Villans, Cherries, Bees, Seagulls, Blues, Eagles, Toffees, Cottagers, Tractor Boys, Foxes, Reds, Citizens, Red Devils, Magpies/Toon, Tricky Trees, Saints, Hammers

### 3.3 Badge assets
- `badgeImageName` property returns "{rawValue}_badge" for asset catalog lookup
- Actual badge image assets deferred (placeholder SF Symbols used in views)

**Build status:** Compiles successfully

---
## Phase 4: Onboarding Flow — COMPLETE

**Files modified:** OnboardingFlow.swift, WelcomeView.swift, HerNameView.swift, HisNameView.swift, TeamSelectionView.swift, TierSelectionView.swift, NotificationPromptView.swift, project.pbxproj
**Files created:** ProgressDotsView.swift
**Files deleted:** WhatToFollowView.swift

### 4.1 Progress dots
- Created `ProgressDotsView` component (8pt dots, 8pt spacing, rose active, muted inactive)
- Added to top of every onboarding screen via OnboardingFlow

### 4.2 Back navigation
- Rose chevron top-left on all screens except Welcome
- Decrements step enum on tap

### 4.3 WelcomeView fixes
- "Goal Digger" → "GoalDigger" (one word)
- Icon: `bubble.left.and.bubble.right` → `bubble.left` (single chat bubble)
- Tighter vertical spacing (grouped as VStack with 16pt spacing)

### 4.4 HerNameView / HisNameView fixes
- Rose border (2pt) on input field when focused and non-empty
- HisNameView headline: "And what's his?" → "And what's his name?"
- Added contextual icons: sparkles (her name), soccerball (his name)

### 4.5 WhatToFollowView removed
- File deleted, enum case removed, pbxproj references cleaned
- Flow: HisName → TeamSelection (skips WhatToFollow)
- Now 6 onboarding screens (was 7)

### 4.6 TeamSelectionView overhaul
- Shows all 20 PL teams (sorted alphabetically)
- Search bar with rose tint: "Search his team..."
- Club badge image to left of each team name
- Removed chevron.right from unselected rows
- Rose checkmark circle on selected row
- Subtitle: "His team. Your new obsession."
- Shield icon above title

### 4.7 TierSelectionView fixes
- Icons per tier: cup.and.saucer (T1), bolt.fill (T2), crown.fill (T3)
- Updated descriptions per brief
- Dynamic button text: "Sounds good" / "Let's do this" / "Say less"

### 4.8 NotificationPromptView fixes
- Rose radial gradient glow behind bell icon
- "maybe later" → "I'll do this later"

**Build status:** Compiles successfully

---
## Phase 5: Feed Redesign — COMPLETE

**Files modified:** FeedView.swift, ContentCard.swift, project.pbxproj
**Files created:** YourMoveCard.swift, MatchDayCard.swift

### 5.1 YOUR MOVE card
- Hot rose background, warm white text, charcoal "YOUR MOVE" pill tag
- Relevance priority: match day today > big news last 24h > most recent with talking points
- Shows first talking point as teaser, chevron indicating expansion
- Always first card in feed

### 5.2 MATCH DAY card
- Soft blush background with gold border (2px)
- Gold "MATCH DAY" pill tag on dark background
- Shows kickoff time, headline, and "ones to watch" (max 3 players)
- Second in feed after YOUR MOVE

### 5.3 Feed card ordering
- YOUR MOVE → MATCH DAY (if applicable) → NEWS cards (reverse chronological)
- YOUR MOVE and MATCH DAY items excluded from news list to prevent duplication

### 5.4 Talking point teasers on news cards
- Chat bubble icon + first talking point in muted rose, truncated to one line
- Only shown when item has talking points

### 5.5 Skeleton loading
- YOUR MOVE skeleton: rose card with warm white shimmer at 10% opacity
- News skeletons: soft blush cards with hotRose 8% shimmer

### 5.6 Error state
- Styled card with soft blush background, charcoal text
- "Try again" rose button that retriggers feed fetch

### 5.7 Matchday player fetch
- Fetches player cards after feed load if matchday item present

**Build status:** Compiles successfully

---
## Phase 6: Article Detail Redesign — COMPLETE

**Files modified:** ContentDetailView.swift, AppState.swift

### 6.1 Headline treatment
- Font weight increased to `.heavy` for stronger visual impact
- Added top padding between badge row and headline

### 6.2 Expandable backstory
- Body section collapsed by default behind "The backstory" header
- Rose chevron rotates 90 degrees when expanded
- Animated expand/collapse with opacity + slide transition

### 6.3 Share button moved to toolbar
- Removed full-width share button from bottom of detail view
- Added rose share icon in top-right toolbar
- ShareLink text updated: "via GoalDigger" (one word, no em dash)

### 6.4 Scroll anchor for THINGS TO SAY
- `.id("thingsToSay")` on section header
- `scrollToTalkingPoints` parameter (default false)
- When true: ScrollViewReader scrolls to anchor after 300ms delay

### 6.5 Em-dash removal
- `personalise()` now strips " — " → ", " and "—" → ", "

**Build status:** Compiles successfully

---
## Phase 7: Settings Overhaul — COMPLETE

**Files modified:** SettingsView.swift

### 7.1 Section grouping with headers
- YOUR SETUP: Your Name, His Name, His Team, Your Mode
- NOTIFICATIONS: Enabled/Disabled with rose checkmark
- ABOUT: "GoalDigger" one word, new tagline
- Footer: Contact Us, Privacy Policy, Delete My Data (hotRose text)

### 7.2 Editable names
- Tapping name rows opens alert with text field for inline editing
- Saves to AppState (which persists to UserDefaults via didSet)
- All views reading from AppState via @Environment re-render automatically

### 7.3 Copy updates
- "Your Team" → "[His name]'s Team"
- "Your Level" → "Your Mode"
- "About Goal Digger" → "GoalDigger" with new tagline
- Tier descriptions updated to match brief
- Version number made smaller and more muted

**Build status:** Compiles successfully

---

## Phase 8: His Team Page Rebuild — COMPLETE

**Files modified:** TeamPageView.swift

### 8.1 Layout restructure
- Club badge centered at top with display name below in warm white
- 5 content cards: The basics, The manager, Ones to know, The rivalry, Right now

### 8.2 Loading state
- Badge circle placeholder + 5 skeleton cards with shimmer

### 8.3 Error state
- "Couldn't load [his name]'s team right now." with rose retry button

**Build status:** Compiles successfully

---

## Phase 9: Player Card Modal — COMPLETE

**Files modified:** PlayerCardView.swift

### 9.1 Modal overlay
- `PlayerCardModal` presented as `.sheet` with `.medium` detent
- 28x28 close button (top right): softBlush circle with charcoal X
- Drag indicator visible, swipe to dismiss supported

### 9.2 PlayerCardsListView updated
- Uses `.sheet(item:)` to present modal instead of navigation push
- `PlayerCardRow` simplified view for list items

**Build status:** Compiles successfully

---

## Phase 10: Polish & Global Rules — COMPLETE

### 10.1 Em-dash removal
- `personalise()` strips "—" and " — " from all content

### 10.2 "your boyfriend" removal
- MockData.swift: all "your boyfriend" instances replaced with "[his name]" placeholder

### 10.3 Green audit
- Zero references to `.green`, `accentGreen`, `accentWarm`, `accentSoft` in codebase

### 10.4 Copy consistency
- "Goal Digger" → "GoalDigger" everywhere (Info.plist CFBundleDisplayName, SettingsView, ShareLink)

**Build status:** Compiles successfully

---

## Phase 11: Brand & Visual Identity — COMPLETE

**Files created:** GoalDiggerWordmark.swift

### 11.1 GoalDigger wordmark
- "Goal" in warm white, "Digger" in hot rose
- Reusable `GoalDiggerWordmark` component with configurable font size
- Used on WelcomeView (onboarding first screen)

**Build status:** Compiles successfully

---

## Phase 12: Haptic Feedback — COMPLETE

### 12.1 Onboarding haptics
- Team selection tap: UIImpactFeedbackGenerator .light
- Tier card selection tap: UIImpactFeedbackGenerator .light
- Continue/tier button: UIImpactFeedbackGenerator .medium
- Onboarding completion: UINotificationFeedbackGenerator .success

### 12.2 Settings haptics
- Name save (her name + his name): UINotificationFeedbackGenerator .success

**Build status:** Compiles successfully

---

## Phase 14: His Team Page Rebuild — COMPLETE

**Files modified:** TeamPageView.swift, ContentItem.swift, MockData.swift, AppState.swift, APIClient.swift (no changes needed), project.pbxproj
**Files created:** arsenal.json (MockData/team_pages/), team-page-generator/index.ts, 004_seed_all_pl_teams.sql
**Backend files modified:** data-fetcher/index.ts, content-generator/index.ts

### 14.1 Backend — Seed all 20 PL teams
- Migration `004_seed_all_pl_teams.sql`: all 20 PL teams with API-Football IDs
- 20 `team_context` rows, 20 `team_pages` rows with static cards (basics + rivalry)
- Versioned JSONB schema (`schema_version: 1`) with per-card `updated_at` timestamps
- pg_cron job: Monday 08:00 UTC full team page refresh

### 14.2 Backend — team-page-generator edge function
- Two modes: `"full"` (Claude regeneration) and `"dynamic_only"` (structured data only)
- Full mode: fetches raw_fetch_logs, calls Claude with enforced tool schema, preserves static cards (basics, rivalry), upserts dynamic cards (manager, ones_to_know, form, season, next_fixture)
- Dynamic mode: parses API-Football standings/fixtures directly, updates form and next_fixture JSONB keys without Claude call
- System prompt enforces GoalDigger voice, no jargon, factual next fixture preview

### 14.3 Backend — Wire triggers
- data-fetcher: triggers `team-page-generator` with `mode: "dynamic_only"` after standings/fixtures data changes
- content-generator: added `team_page_impact` field to NEWS_TOOL (`none`, `manager_change`, `squad_change`), triggers `team-page-generator` with `mode: "full"` on manager/squad changes
- On-select trigger: Postgres trigger on `device_tokens` INSERT checks if team's page has dynamic content, fires `team-page-generator` via pg_net if not

### 14.4 iOS — Model + Cache + Mock Data
- Rewrote `TeamPageContent` to match versioned JSONB: `schemaVersion`, `cards` dict with per-card structs
- New structs: `BasicsCard`, `ManagerCard`, `OnesToKnowCard`, `RivalryCard`, `FormCard`, `SeasonCard`, `NextFixtureCard`
- `CachedTeamPage` struct + `TeamPageCache` utility (UserDefaults, 24h staleness check)
- Mock JSON: `MockData/team_pages/arsenal.json` with all 7 cards populated
- `MockData.teamPage(for:)` loader from bundled JSON
- `AppState.clearAllData()` now clears team page cache

### 14.5 iOS — View changes (7 cards)
- Card 1 (The basics): reads from `cards.basics` (nickname, stadium, fun_fact)
- Card 2 (The manager): `cards.manager.name` (bold) + `cards.manager.summary`
- Card 3 (Ones to know): tappable players → PlayerCardModal when matching `PlayerCard` exists. Fetched in parallel with team page. No tap affordance when no matching card.
- Card 4 (The rivalry): reads from `cards.rivalry.text`
- Card 5 (How they're doing): NEW — league position label, form dots (8x8pt, hotRose W, mutedText D, red L), form_summary
- Card 6 (The season so far): renamed from "Right now", reads `cards.season.summary`
- Card 7 (Coming up): NEW — opponent + home/away tag + formatted date + preview. Hides when nil.
- Cache-first loading: show cache immediately, fetch fresh in background, update on completion
- Warm placeholder: "We're getting [his name]'s team ready. Check back in a moment."
- DEBUG mock fallback when API not configured

**Build status:** Compiles successfully (iPhone 17 Simulator, Xcode 26 beta)

---

## Phase 15: Context Switcher + Immersive Feed + Everyone's Talking About — COMPLETE

**Backend files created:** `005_everyone_talking.sql`
**Backend files modified:** `_shared/types.ts`, `content-generator/index.ts`, `_shared/apns-client.ts`, `notification-sender/index.ts`
**iOS files created:** `FeedContext.swift`, `UnreadTracker.swift`, `ImmersiveCard.swift`, `ImmersiveSkeletonCard.swift`, `ContextSwitcherView.swift`, `EveryoneEmptyStateCard.swift`, `ClassicFeedView.swift`
**iOS files modified:** `ContentItem.swift`, `AppState.swift`, `APIClient.swift`, `CacheService.swift`, `BadgeView.swift`, `ContentCard.swift`, `FeedView.swift`, `ContentDetailView.swift`, `GoalDiggerApp.swift`, `AppDelegate.swift`, `SettingsView.swift`, `OnboardingFlow.swift`, `MockData.swift`, `project.pbxproj`

### Phase A: Schema + Backend

#### A1: Migration 005 — everyone_talking + immersive + analogy system
- Added 12 columns to `content_items`: `everyone_talking`, `everyone_talking_headline`, `everyone_talking_body`, `everyone_talking_talking_points`, `worth_knowing`, `immersive_headline`, `immersive_context`, `immersive_context_fallback`, `analogy_reviewed`, `analogy_approved`, `analogy_auto_published`, `analogy_critic_score`
- Created `analogy_rejections` monitoring table (tracks AI critic + human rejections)
- Added pg_cron `analogy-auto-publish` job: every 30 mins, auto-publishes items with unreviewed analogies older than 4 hours using fallback context
- Created `everyone_talking_daily` monitoring view for daily volume tracking
- Created partial index `idx_content_everyone_talking` for efficient cross-team feed queries

#### A2: Shared types update
- Added 11 new fields to `ContentItem` interface in `_shared/types.ts`
- Added `AnalogyScore` interface (naturalness, relevance, audience_fit, cringe_risk, total, verdict, reason)

#### A3: Content generator — immersive + analogy + everyone fields
- Added 9 new properties to `NEWS_TOOL` schema: `immersive_headline`, `immersive_context`, `immersive_context_fallback`, `everyone_talking`, `neutral_headline`, `neutral_body`, `neutral_talking_points`, `worth_knowing`
- Appended immersive headline rules (all lowercase, visual rhythm, max 3 lines) to `NEWS_SYSTEM_PROMPT`
- Appended analogy rules with bad example catalogue and good analogy checklist
- Appended cross-team significance rules
- Added `worth_knowing` daily cap enforcement (max 1/day, query before insert)
- Expanded news insert to include all new columns
- Added `ANALOGY_CRITIC_TOOL` definition and `runAnalogyAICritic()` function
  - Second Claude call (claude-sonnet) scores analogy on 4 dimensions (1–5 each)
  - Approve threshold: total ≥ 16/20 AND no single dimension ≤ 2
  - Rejected analogies logged to `analogy_rejections` table with scores + reason
  - Approved analogies stored in `analogy_critic_score` JSONB column

#### A4: Notification wiring
- Added `everyone_talking?: boolean` to `APNsPayload` interface in `apns-client.ts`
- Updated `buildAPNsPayload()` with optional `everyoneTalking` parameter
- Updated `notification-sender/index.ts` to pass `item.everyone_talking` to payload

### Phase B: iOS Models + API

#### B1: FeedContext enum
- New `FeedContext` enum with `.team(Team)` and `.everyoneTalking` cases
- Properties: `displayName`, `storageKey`, `iconName`, `dropdownLabel`

#### B2: ContentItem — 11 new fields
- Everyone fields: `everyoneTalking`, `everyoneTalkingHeadline`, `everyoneTalkingBody`, `everyoneTalkingTalkingPoints`, `worthKnowing`
- Immersive fields: `immersiveHeadline`, `immersiveContext`, `immersiveContextFallback`
- Analogy fields: `analogyReviewed`, `analogyApproved`, `analogyAutoPublished`
- Custom `init(from:)` with `decodeIfPresent` + defaults for full backward compatibility with cached items
- `displayContext` computed property: returns approved analogy or fallback

#### B3: AppState additions
- `activeContext: FeedContext` — session-only, not persisted, resets to team on launch
- `isContextSwitcherOpen: Bool` — session-only
- `feedStyle: FeedStyle` — persisted to UserDefaults, default `.immersive`
- `FeedStyle` enum with `.immersive` and `.classic` cases

#### B4: APIClient — everyone feed
- `contentSelectColumns` static constant with all column names for consistent select clauses
- `fetchEveryoneFeed(limit:offset:)` — queries `everyone_talking=eq.true&status=eq.published`
- Updated `fetchFeed` and `fetchItem` to use `contentSelectColumns`

#### B5: UnreadTracker service
- `@Observable` class with `UserDefaults`-based per-context `lastViewedAt` timestamps
- Methods: `lastViewedAt`, `markViewed`, `unreadCount`, `badgeText`, `totalUnread`, `aggregateBadgeText`, `clearAll`
- Badge shows "9+" if count exceeds 9

### Phase C: iOS UI Components

#### C1: ImmersiveCard — full-screen two-zone card
- 65/35 vertical split: Zone 1 (deepMauve) + Zone 2 (hotRose or gold)
- Zone 1: 64pt bold headline (minimumScaleFactor 0.75, max 3 lines), analogy/context line, "Press for more info and things to say" hint, 3px hotRose inset border
- Zone 2: rotating labels, first talking point (italic), double-chevron scroll indicator
- Gold zone 2 for matchday + worth_knowing (black text for WCAG AA contrast)
- Separate `onZone1Tap` (→ detail top) and `onZone2Tap` (→ THINGS TO SAY section) callbacks
- Context-aware: neutral content for everyone context, personalised for team context
- Zone 2 label rotation: deterministic cycling via `feedPosition % labelCount`
  - YOUR MOVE: fixed "Your move:"
  - MATCH DAY: time-based ("Tonight:", "This afternoon:", "Today:")
  - Team NEWS: "Top talking point:", "Say this:", "Drop this:", "Your opener:", "Use this:"
  - Everyone NEWS: "The chat:", "Everyone's saying:", "Drop this:", "Talk about it:", "Conversation starter:"

#### C2: ImmersiveSkeletonCard
- Same 65/35 zone split with shimmer animation (1.5s repeating linear sweep)
- Zone 1: deepMauve + warmWhite 8% shimmer; Zone 2: hotRose + warmWhite 10% shimmer

#### C3: ContextSwitcherView — floating dropdown
- deepMauve background, hotRose 30% opacity border, 16px corner radius
- 48pt rows: team row (badge + short name) + everyone row (soccerball + "Everyone's talking about")
- 3px rose left border on selected row, rose text; warmWhite 60% on unselected
- Per-row unread badges (rose circle, warmWhite number, caption2)
- Full-screen transparent tap catcher for dismiss

#### C4: BadgeView — customLabel
- Added optional `customLabel: String?` parameter
- "Everyone" feed uses `customLabel: "FOOTBALL"` instead of type-based default

#### C5: EveryoneEmptyStateCard
- Full-height softBlush card with soccerball icon, "Nothing huge in football today." message
- "Back to [team name]" rose button that switches context

### Phase D: iOS Wiring

#### D1: FeedView — complete rewrite
- Dual data sources: `teamItems` + `everyoneItems` with per-context offsets and loading states
- Context pill button with aggregate unread badge overlay (top-trailing, rose capsule)
- Context switcher overlay with animated show/hide (opacity + move transition)
- Immersive/classic feed switch via `appState.feedStyle`
- Immersive feed: `ScrollView` → `LazyVStack(spacing: 0)` → `.scrollTargetBehavior(.viewAligned)`, cards at 88% screen height
- Migration banner for existing users (`hasSeenImmersiveBanner` AppStorage)
- `switchContext()` method: marks viewed, switches active context, loads data if empty
- `navigateToDetail()` via `NotificationCenter.default.post(.feedNavigateToDetail)` for immersive card taps
- Scroll position memory via `@State` (session-only, resets on app reopen)
- `.onReceive(.feedResetScrollPositions)` resets scroll on return from background

#### D2: ClassicFeedView — extracted
- Original card-list layout preserved as separate view
- Includes WorthKnowingCard (gold hero for everyone feed, charcoal "WORTH KNOWING" pill)
- YOUR MOVE + MATCH DAY for team context, WORTH KNOWING for everyone context
- Freshness states preserved

#### D3: ContentDetailView — context-aware
- Added `isEveryoneContext: Bool` parameter
- Context-aware computed properties: `displayHeadline`, `displayBody`, `displayTalkingPoints`
- Everyone context uses neutral headline/body/talking points, skips personalisation
- Removed bold prediction card (replaced with comment)

#### D4: AppDelegate — deep link routing
- `UIScrollView.appearance().backgroundColor` set to deepMauve for overscroll
- Notification tap handler checks `everyone_talking` in userInfo, switches `activeContext` before setting `deepLinkContentId`

#### D5: GoalDiggerApp — scroll reset
- `ContentDetailDestination` extended with `isEveryoneContext: Bool` + backward-compatible init
- Scene phase observation: background → active resets to team context, closes context switcher, posts `.feedResetScrollPositions`
- `.onReceive(.feedNavigateToDetail)` in MainTabView for immersive card navigation

#### D6: Settings — feed format toggle
- "FEED FORMAT" section at top of SettingsView
- Two-option selector: "Immersive" (rectangle.stack) / "Classic" (list.bullet)
- Rose bg for selected, softBlush for unselected, 44pt height, 12px corner radius
- Switches immediately on tap, no restart

#### D7: Migration banner
- SoftBlush banner above feed content when `hasSeenImmersiveBanner == false && feedStyle == .immersive`
- Dismissible with rose X button, never shown again after dismiss

#### D8: Onboarding wiring
- `UnreadTracker.shared.markViewed(.team(team))` and `.markViewed(.everyoneTalking)` on onboarding completion
- Ensures first feed open has zero false unread counts

### Phase E: Polish + Cache + Mock Data

#### E1: MockData — immersive + everyone items
- Added `example6Everyone` with all immersive + everyone fields populated
- Fields: `everyone_talking`, `everyone_talking_headline/body/talking_points`, `worth_knowing`, `immersive_headline`, `immersive_context`, `immersive_context_fallback`, `analogy_reviewed/approved/auto_published`
- Updated feed array to include `example6Everyone`

#### E2: CacheService — everyone feed support
- Added `everyoneTalking: Bool` property to `CachedContentItem` @Model
- Added `fetchCachedEveryoneFeed(in:)` method with `#Predicate` filter on `everyoneTalking == true`
- FeedView `loadEveryoneFeed()` now shows cached everyone items immediately, then fetches fresh
- Everyone pagination (`loadMore`) now caches fetched items

### Additional Tasks

#### Task 6: Bold prediction card removed
- Replaced bold prediction section in ContentDetailView with comment
- PostMatchCheatSheet struct retained for backward compatibility

#### Task 7: WhatToFollowView confirmed clean
- Previously removed in Phase 4; no orphan references found

**Build status:** Compiles successfully (iPhone 17 Pro Simulator, iOS 26.4, Xcode 26 beta)

---

---

## Task 8: Plus Jakarta Sans Font Bundle — COMPLETE

**Files created:** `Resources/Fonts/PlusJakartaSans-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf`, `-Bold.ttf`, `-Italic.ttf`, `-MediumItalic.ttf`
**Files modified:** `Theme.swift`, `Info.plist`, `project.pbxproj`, `ImmersiveCard.swift`, `ContextSwitcherView.swift`, `EveryoneEmptyStateCard.swift`, `GoalDiggerWordmark.swift`, `WelcomeView.swift`, `HerNameView.swift`, `HisNameView.swift`, `TeamSelectionView.swift`, `ContentDetailView.swift`, `FeedView.swift`, `SettingsView.swift`

### 8.1 Font files
- Downloaded 6 static TTF weights from Google Fonts (gstatic CDN): Regular (400), Medium (500), SemiBold (600), Bold (700), Italic (400i), MediumItalic (500i)
- Placed in `GoalDigger/Resources/Fonts/` directory
- PostScript names verified: `PlusJakartaSans-Regular`, `-Medium`, `-SemiBold`, `-Bold`, `-Italic`, `-MediumItalic`
- Total bundle size: ~380KB (6 files × ~63KB each)

### 8.2 Info.plist registration
- Added `UIAppFonts` array with all 6 font filenames

### 8.3 Xcode project
- Added PBXFileReference entries (AB000070–AB000075) for all 6 fonts
- Added PBXBuildFile entries (AA000070–AA000075) in Resources build phase
- Added `Fonts` PBXGroup (AC000022) under Resources group

### 8.4 Theme.swift — central typography system
- Replaced TODO comment with full Plus Jakarta Sans integration
- Added `Font.jakarta(_:weight:)` helper with `JakartaWeight` enum mapping to PostScript names
- Replaced all 10 semantic font tokens from `Font.system(.X, design: .rounded)` to `Font.jakarta(size, weight:)`
- Added 3 new immersive-specific tokens: `.immersiveHeadline` (64pt bold), `.immersiveContext` (18pt regular), `.immersiveHint` (13pt regular)
- Updated `PrimaryButtonStyle` from `.system(.body, design: .rounded)` to `.jakarta(17, weight: .semiBold)`

### 8.5 Inline font migration (29 instances across 11 files → 0 remaining)
- **ImmersiveCard.swift**: headline 64pt bold, context 18pt, hint 13pt, zone2 label/talking point, "scroll" hint → all Jakarta
- **ContextSwitcherView.swift**: dropdown label, team abbreviation, unread badge → Jakarta
- **EveryoneEmptyStateCard.swift**: title, subtitle, button → Jakarta
- **GoalDiggerWordmark.swift**: default size → Jakarta 28pt bold
- **WelcomeView.swift**: wordmark size → Jakarta 34pt bold
- **HerNameView.swift / HisNameView.swift**: text field → Jakarta 20pt medium
- **TeamSelectionView.swift**: search bar → Jakarta 17pt regular
- **ContentDetailView.swift**: headline → Jakarta 22pt bold
- **FeedView.swift**: unread badge, migration banner → Jakarta
- **SettingsView.swift**: feed format selector, section headers, version text → Jakarta
- **Zero** `design: .rounded` references remain in codebase
- SF Symbol icon sizing (`Image(systemName:)`) correctly kept as `.system(size:)` — these are not text

**Build status:** Compiles successfully. All 6 fonts verified in app bundle.

---

## E3: Post-Phase 15 Review — COMPLETE

Systematic code review and fix pass across the entire Phase 15 + Task 8 codebase.

### Fix 1: ContentCard — incorrect default feedContext
- Removed `= .everyoneTalking` default; made `feedContext` a required `let` parameter
- Only one call site (ClassicFeedView) always passes explicitly, so no callers affected

### Fix 2: ContentDetailView — compiler warning
- Changed `if let item` to `if item != nil` in toolbar to eliminate "value was defined but never used" warning
- The `item:` in `ShareLink(item:)` is a parameter name, not the bound variable

### Fix 3: Deep link bug — everyone context lost on notification tap
- `deepLinkContentId` handler was appending bare `UUID` to feedPath, hitting `navigationDestination(for: UUID.self)` which defaulted `isEveryoneContext: false`
- Fixed: now creates `ContentDetailDestination(isEveryoneContext:)` based on `appState.activeContext`
- Everyone-context notification taps now correctly show neutral content in detail view

### Fix 4: SettingsView — inconsistent FEED FORMAT header
- FEED FORMAT used `.sectionHeader` + `.textTertiary`, other headers used `.jakarta(11)` + `.hotRose.opacity(0.7)`
- Aligned to match: rose color, 11pt, left padding, same tracking

### Fix 5: FeedView — dead code removal
- Removed unused `NavigateAction` EnvironmentKey/EnvironmentValues extension (NotificationCenter used instead)
- Removed unused `@Environment(\.navigate)` property

### Fix 6: ClassicFeedView — MatchDayCard navigation consistency
- Changed from bare `NavigationLink(value: matchItem.id)` to `ContentDetailDestination` for consistency
- Removed now-unused `navigationDestination(for: UUID.self)` from GoalDiggerApp

### Fix 7: CacheService — SwiftData migration safety
- Added `= false` default to `everyoneTalking: Bool` on `CachedContentItem`
- Ensures lightweight migration succeeds for existing cached items missing the new column

### Fix 8: SettingsView — unused @Bindable
- Removed `@Bindable var state = appState` from `feedFormatSection` — never used as a binding

### Fix 9: ImmersiveCard — double personalise call
- `contextLine` was calling `appState.personalise()` twice on the same string
- Refactored to guard-let + single call + cache result

### Fix 10: FeedView — unused scroll position state
- Removed `teamScrollPosition` and `everyoneScrollPosition` @State variables (declared but never read)

### Fix 11: Magic numbers → Layout constants
- Extracted `0.88`, `0.65`, `0.35` to `Layout.immersiveCardHeightRatio`, `.immersiveZone1Ratio`, `.immersiveZone2Ratio`
- Updated ImmersiveCard, ImmersiveSkeletonCard, FeedView to use constants

### Fix 12: Silent error swallowing → DEBUG logging
- FeedView `loadMore()`: two empty catch blocks now print errors in DEBUG
- PlayerCardView `loadPlayers()`: empty catch block now prints in DEBUG
- AppDelegate APNs registration failure wrapped in `#if DEBUG`

### Fix 13: Dead notification cleanup
- Removed `feedResetScrollPositions` notification (posted but never consumed)
- Removed the Notification.Name extension declaration

**Build status:** Compiles successfully with zero warnings (iPhone 17 Pro Simulator, iOS 26.4)

---

## Phase 13: Privacy Policy — NOT STARTED (non-code, pre-App Store)
- Domain purchase, hosting, and privacy policy writing needed before submission
- Not an app code task

---

## Post-Implementation Review — COMPLETE

All phases (2–12) reviewed and corrected. Fixes applied:

### Phase 3: Team.swift
- Removed redundant words from `searchableText` nicknames (e.g., "Villans Villa" → "Villans", "Eagles Palace" → "Eagles", "Citizens City" → "Citizens", "Red Devils United" → "Red Devils", "Forest Tricky Trees" → "Tricky Trees")
- Replaced redundant displayName repeats with actual nicknames ("Tottenham" → "Lilywhites", "Wolverhampton" → "Wanderers")

### Phase 5: ContentCard.swift + FeedView.swift + GoalDiggerApp.swift
- Talking point teaser text opacity changed from .hotRose.opacity(0.8) → .hotRose.opacity(0.6) ("muted rose")
- Added `ContentDetailDestination` struct for typed navigation
- YOUR MOVE card now navigates with `scrollToTalkingPoints: true` so detail opens at THINGS TO SAY section

### Phase 9: PlayerCardView.swift
- Close button icon font increased from 12pt → 14pt for better visual balance in 28x28 frame

### Phase 10: MockData.swift + project.pbxproj
- Fixed 2 remaining "Your boyfriend" → "[his name]" in mock data body text
- Fixed "Goal Digger" → "GoalDigger" (one word) in INFOPLIST_KEY_CFBundleDisplayName (2 build configs)

### Phase 11: FeedView.swift
- Added club badge thumbnail (16x16pt) to feed top bar pill

### Phase 12: TierSelectionView.swift + NotificationPromptView.swift + SettingsView.swift
- Added tier card selection haptic (.light)
- Added onboarding completion haptic (.success)
- Added settings name save haptic (.success)

**Build status:** Compiles successfully (all fixes verified)

---

## Phase 16: Pre-App Store Submission Cleanup — COMPLETE (2026-05-04)

Final pass before clicking *Submit for Review*. Two goals: collapse the in-app paywall (the app is shipping as a paid £4.99 App Store app, not Free+IAP, so the paywall would either double-charge users or brick the app for them), and verify the content + push pipeline so users actually receive notifications when news drops.

**Files modified:** `ios/GoalDigger/App/GoalDiggerApp.swift`, `ios/GoalDigger/Views/Settings/SettingsView.swift`, `backend/supabase/functions/notification-sender/index.ts`, `/Users/anton/goaldigger-routines/post_news.sh`

### 16.1 Paywall removed from RootView
- `GoalDiggerApp.swift` — removed the `#if DEBUG / #else / #endif` block in `RootView`. Post-onboarding always shows `MainTabView`. No more `purchaseManager.isPurchased || isTestFlight` gate.
- `PurchaseManager.swift` and `PaywallView.swift` left in the codebase but unreferenced. Dormant code, no rejection risk; we can re-wire them if we add an IAP later (e.g. World Cup pass for v1.1).

### 16.2 "Restore Purchases" row removed from Settings
- `SettingsView.swift` — removed the row at lines ~210–230 plus the now-unused `@State private var purchaseManager = PurchaseManager.shared`. Paid apps don't need an in-app restore button; the App Store handles redownloads automatically when the user reinstalls.

### 16.3 Backend pipeline audit (no changes needed)
- `data-fetcher` content-generator trigger already gated behind `CONTENT_GENERATOR_ENABLED` env var (line 309). Verified the routine pipeline is the sole content source — DB shows 149 routine items in the last 7 days, 0 edge_function items.
- `goaldigger-daily-pipeline` cron (07:00 UTC daily) is the actual data-fetcher trigger; not a duplicate (earlier audit confused it with `matchday-scheduler` from migration 003 which never landed remote).
- `match-watcher-5min` cron (every 5 min) deployed and live. Migration `008_match_watcher_cron.sql` applied. Polls API-Football for PL fixture status transitions, fires `gd-matchday` routine on FT/AET/PEN.

### 16.4 Push notification gap — fixed
**Problem found:** `gd-news` and `gd-matchday` routines insert into `content_items` directly with `status='published'` via `post_news.sh`. The notification-sender function only fired when called by `content-reviewer` (gated off) and its query filtered for `status='approved' AND published_at IS NULL` — routine items never matched. **Routine-published items appeared in the feed but no APNs push ever fired.** For a notification-driven app, that's the whole product gone.

**Fix — two changes:**

1. **`notification-sender/index.ts`** — added a "specific item, already published" mode. When called with `content_item_id`, the function fetches that row regardless of status (drops the `status='approved'` and `published_at IS NULL` filters). Skips the "flip to published" update step if the item is already published — preserves the original timestamp from `post_news.sh`. Sweep mode (no `content_item_id` passed) still works for the legacy edge-function flow.

   Also fixed the no-tokens early-return path that was unconditionally writing `published_at = NOW()` — now skipped if already published.

2. **`post_news.sh`** — switched insert from `Prefer: return=minimal` to `return=representation` to capture the new item id, then fires `POST /functions/v1/notification-sender` with `{content_item_id: <id>}`. Push trigger is best-effort — if the curl fails, the script logs and exits 0 (item is already in the feed; push is bonus, not blocking).

**Effect:** every `gd-news` + `gd-matchday` post now triggers APNs pushes within ~1 second of insert. Anti-spam rules, tier limits, quiet hours, and result-bypass logic all keep working — none of that lives in `post_news.sh`, all in notification-sender.

**Deployed:** `notification-sender` redeployed via `npx supabase functions deploy notification-sender`.

**Smoke test pending:** `device_tokens` table is empty (no real users yet). End-to-end push validation needs: build app to phone → register token → fire `gd-news` for that team → confirm push lands. First real test is the user's; if APNs auth fails it'll show in `notification-sender` function logs.

### 16.5 Out of scope (intentional)
- World Cup support — deferred to v1.1, must ship before 2026-06-11
- IAP / subscription flows — keeping `PurchaseManager` dormant for future use
- App Store description copy update (remove "no subscriptions" wording from Free+IAP draft) — manual edit in App Store Connect, not in repo

**Build status:** Code changes ready; iOS Archive + upload via Xcode is the next step.

---

## Phase 17: Decoupled push_text from headline — COMPLETE (2026-05-04)

The push notification body is the single most important piece of text the app produces. It's what lands on the user's lock screen, it's what they read at a glance, and it determines whether they open the app or eventually delete it. Pre-launch audit found that two of the three most recent routine items had headlines exceeding the 160-char "soft" cap (173 and 156 chars), so ~67% of pushes were truncating mid-word on real iPhone lock screens. The headline serves the immersive feed card well — long, story-style, with parenthetical name explanations — but those same properties make for a terrible push.

Decoupled the two by adding a `push_text` field, written by the routine alongside the headline, optimized specifically for the lock screen.

**Files modified:** `backend/supabase/migrations/011_push_text.sql` (new), `backend/supabase/functions/_shared/apns-client.ts`, `backend/supabase/functions/notification-sender/index.ts`, `/Users/anton/goaldigger-routines/schema.json`, `/Users/anton/goaldigger-routines/PROMPT.md`, `/Users/anton/goaldigger-routines/MATCHDAY_PROMPT.md`, `/Users/anton/goaldigger-routines/post_news.sh`.

### 17.1 Schema migration
- New column `push_text TEXT` on `content_items`. Soft target ≤90 chars; DB CHECK enforces ≤100 as a safety net. NULL allowed for backward compatibility with pre-migration rows.
- Migration `011_push_text.sql` created and pushed to remote DB. Verified via `information_schema.columns` query.

### 17.2 Routine prompt updates
- `schema.json` — added `push_text` as a required field with `minLength: 5, maxLength: 90`.
- `PROMPT.md` — added a new section **PUSH TEXT RULES (the most important text in the app)** between NAME EXPLANATIONS and IMMERSIVE HEADLINE RULES. Hard constraints: max 90 chars, self-contained, no parenthetical name explanations (those clutter a tiny push), no emoji, no "click to read" cliffhangers. Voice rules: lead with the WHAT not the build-up, lead with quotes when present, active voice. Includes 3 worked before/after examples drawn from real recent items in the DB (Forest 3-1 Chelsea, Cunha on Carrick, City vs Everton).
- `MATCHDAY_PROMPT.md` — added matchday-specific `push_text` examples (win, loss, expected-win draw, underdog draw) and pointer to the canonical rules in PROMPT.md.

### 17.3 Backend wiring
- `apns-client.ts` `buildAPNsPayload()` — added optional `pushText` parameter. When present, used as the lock-screen body. When absent (pre-migration items), falls back to `headline.slice(0, 200)`.
- Also restructured the lock-screen layout: dropped the redundant `title: "Goal Digger"` (iOS already shows the app icon + name automatically) and the `subtitle: teamShortName`. Now: `title = teamShortName` (e.g. "Forest"), no subtitle, `body = push_text || headline`. Frees a line for the actual content.
- `notification-sender/index.ts` — passes `item.push_text` through to `buildAPNsPayload`.
- Deployed via `npx supabase functions deploy notification-sender`.

### 17.4 Hard validation in post_news.sh
The model has a track record of ignoring soft length rules in the prompt. Soft caps don't work; hard rejection in the post script does. Added pre-insert validation that exits 1 (forcing the routine to retry with a compliant payload) when:
- `push_text` is missing or empty
- `push_text` length > 90 chars
- `headline` length > 160 chars

Validation runs after the em-dash sanitizer but before the Supabase POST, so a bad payload never reaches the DB. Exit-1 surfaces a clear error message in the routine session log explaining what to fix.

Verified by feeding the script invalid payloads with no `SUPABASE_URL` set:
- Missing push_text → "ERROR: push_text is required" + payload dump → exit 1 ✓
- Push_text 145 chars → "ERROR: push_text is 145 chars (max 90)" → exit 1 ✓

### 17.5 Lock-screen rendering before vs after

**Before (headline-as-push):**
```
Goal Digger
Forest
Forest beat Chelsea 3-1 away from home today and are now six points
clear of relegation danger. Their manager Vitor Pereira (Forest's…
```
4 lines, last line truncates mid-word.

**After (push_text dedicated):**
```
Forest
Forest beat Chelsea 3-1, now six points clear of relegation.
```
2 lines, complete thought, no truncation.

### 17.6 Out of scope (future)
- Backfill of `push_text` for the 149 existing `pipeline_source='routine'` rows. Old items won't trigger fresh pushes (they're already published past the throttle window) so no user impact, but if we ever want to re-push them, they'll fall back to the long headline.
- Per-team push tone tuning (e.g. ironic vs deferential per club). v2 territory.
- A/B testing different push styles. Need scale first.

**Smoke test pending:** real-device push validation. `device_tokens` is still empty until first build hits TestFlight or App Store. First user with push enabled will be the test.

---

## Phase 18: Older-sister voice for push notifications — COMPLETE (2026-05-05)

Phase 17 decoupled `push_text` from headline so the body could be lock-screen-optimized. This phase pushes further: it gives the push its own sister-voice **title** (replacing the team short name in the title slot), introduces a brand-voice character spec, and locks in 22+ canonical examples in the prompt as in-context training so the routine consistently nails the voice.

The motivation: even with a tight 90-char `push_text`, draft examples were reading as either app-y newsroom prose ("Plot twist", "Big swing", "Worth knowing") or unintentionally crisis-coded ("Brace yourself", "He'll be unbearable", "Pretend you didn't see"). Both register as "this is from a sports app" — the second category is worse, framing him as a threat she has to survive instead of a goofy boy who cares too much. For an app whose whole product premise is "your funny older sister tells you what's about to happen with your boyfriend," that voice mismatch IS the product failing.

**Files modified:** `backend/supabase/migrations/012_push_title.sql` (new), `backend/supabase/functions/_shared/apns-client.ts`, `backend/supabase/functions/notification-sender/index.ts`, `/Users/anton/goaldigger-routines/schema.json`, `/Users/anton/goaldigger-routines/PROMPT.md`, `/Users/anton/goaldigger-routines/MATCHDAY_PROMPT.md`, `/Users/anton/goaldigger-routines/post_news.sh`.

### 18.1 New `push_title` field
- Migration `012_push_title.sql`: `ALTER TABLE content_items ADD COLUMN push_title TEXT CHECK (length ≤ 35)`. Soft target ≤25 chars. NULL allowed for backward compat.
- `schema.json` — added `push_title` as required, minLength 3, maxLength 35.

### 18.2 Lock-screen layout
- `apns-client.ts` `buildAPNsPayload()` — added optional `pushTitle` param. Lock-screen title now reads `push_title` when present (the sister-voice opener), falls back to `team.short_name` for legacy rows.
- `notification-sender/index.ts` — passes `item.push_title` through.
- Deployed.

### 18.3 PROMPT.md — full rewrite of PUSH RULES section
The replaced section is now ~150 lines defining: the character (older sister, fond not threatened by him), four kinds of titles she can write (observational about him / sister advice / vivid scene / wry mood-naming), kicker craft rules (must be full sentences, idioms, or imperatives — never bare noun phrases that dangle), banned patterns (sports-app categories, Twitter clickbait, crisis-counsellor framing, wire-service tags), and 22 locked canonical examples covering:
- Match wins (5 examples)
- Match losses (5 examples)
- Draws (2)
- Last-minute drama (2)
- Transfer news (3)
- Manager news (2)
- Player / injury news (2)
- Quotes (3)
- League context (2)

Each example is the bar — the routine reads them as in-context examples and matches the voice. Self-check rubric at the bottom (read aloud, sister or sports-app? sentence or chyron? warm or threat-coded?).

### 18.4 MATCHDAY_PROMPT.md
Replaced the bullet-list push examples with 9 full lock-screen renders (title + body) in the new sister voice, covering big wins, derbies, last-minute drama, derby losses, draws when expected to win, etc. Cross-references `PROMPT.md` PUSH RULES for full spec.

### 18.5 Voice character (the spec we're writing as)

The character is the **older sister**:
- Smart, observational, warm but dry
- Affectionate without being saccharine
- Knows him better than he knows himself, finds his football obsession sweet
- Lets HER in on the joke
- NEVER warns, manages, or victim-frames her relative to him

The voice rule that crystallised after iteration: **observational about him, never threatened by him.** Flag-and-rewrite triggers include "brace yourself", "he'll be unbearable", "pretend you didn't see", "bad mood loading" — anything that frames him as a problem rather than a boy.

### 18.6 Kicker craft rule
The body's optional kicker (e.g. "He'll narrate every goal twice." after "Forest just beat Chelsea 3-1 away.") must be either:
- A full sentence with subject + verb
- A complete idiom with implied verb ("Crisis averted." / "T-shirt material." / "Comfort-food night.")
- A short imperative ("Order in tonight." / "Brace for the analysis.")

It must NOT be a bare noun phrase. The rejected example was "The whole address book." — reads as a press-release tag, not human speech. Replaced with "He'll work the whole address book." — same image, completes as a sentence. The test: read the kicker aloud on its own; if it sounds like a chyron under a TV news segment, rewrite.

### 18.7 Hard validation in post_news.sh
Extended the existing length-validation block:
- `push_title` is required (was: only push_text + headline). Missing → exit 1.
- `push_title` length > 35 chars → exit 1.

Verified: missing `push_title` → "ERROR: push_title is required" + exit 1. 56-char title → "ERROR: push_title is 56 chars (max 35)" + exit 1.

### 18.8 Lock-screen rendering — full evolution

Phase 16 (pre-fix):
```
Goal Digger
Forest
Forest beat Chelsea 3-1 away from home today and are now six points
clear of relegation danger. Their manager Vitor Pereira (Forest's…
```

Phase 17:
```
Forest
Forest just beat Chelsea 3-1, now six points clear of relegation.
```

Phase 18 (now):
```
Stories incoming
Forest just beat Chelsea 3-1 away. He'll narrate every goal twice.
```

That last one is what should land on her phone. The title is the conversational opener, the body is the fact + the wise-and-fond kicker. It reads like a text from an older sister who knows him too well, and lets her in on the joke.

### 18.9 Out of scope (future)
- Backfill `push_title` for the 149 existing routine rows. Not needed (they won't re-fire pushes).
- A/B testing voice variants per user. Need scale first.
- Per-team voice nuance (more cynical for clubs in long decline, more reverent for elite clubs). v2.

**Build status:** Backend deployed. Routine prompts updated. Next gd-news fire produces the new format.

---

## Phase 19: Pre-Submission Ultrareview Fixes — COMPLETE (2026-05-05)

Three parallel pre-launch audit agents (iOS / backend / routine+content) surfaced one true ship-blocker, one confabulation risk, and several polish items. Fixed all of them before App Store submission.

**Files modified:** `ios/GoalDigger/Services/APIClient.swift`, `ios/GoalDigger/Views/Settings/SettingsView.swift`, `ios/GoalDigger/Models/AppState.swift`, `backend/supabase/functions/_shared/apns-client.ts`, `/Users/anton/goaldigger-routines/post_news.sh`, `/Users/anton/goaldigger-routines/PROMPT.md`.

### 19.1 (✗ critical) APNs environment now sent on token registration
- **Bug:** `APIClient.registerToken()` didn't include `apns_environment` in the device_tokens insert. The DB column defaults to `'development'` → all production App Store tokens would have been routed to APNs sandbox endpoint → sandbox would have rejected them with 400 → tokens deactivated → **zero pushes after launch**. The conversation summary said this was fixed earlier; verified via grep that it never landed in this worktree.
- **Fix:** added `APIClient.apnsEnvironment` static computed property (`#if DEBUG → "development" #else → "production"`). `registerToken()` now sends it in the body.
- **Impact:** push notifications will actually work in App Store builds.

### 19.2 (✗ confabulation risk) PROMPT.md GROUNDING + SAFE-REWRITE tightened
- **Bug:** Audit found two recent routine items with confabulated facts: a Spurs item naming "Conor Gallagher (Spurs midfielder)" — Gallagher was never at Spurs — and a Chelsea item naming "interim boss Calum McFarlane" — name appears fabricated. Both passed `post_news.sh` validation because the validator only checks length, not facts. The GROUNDING rule existed but was being ignored.
- **Fix:** added a new **PLAYER AFFILIATIONS** subsection — explicit rule that the player's current club must appear next to their name in the RSS text before the routine can claim the affiliation. Added a **SAFE-REWRITE PRINCIPLE** subsection with worked examples: "A Chelsea midfielder said..." beats "Gallagher said..." when the club isn't verified. Added the two new failure modes (Gallagher, McFarlane) to the past-failures list. Extended the post-run sanity check to include a SOURCE TRACE audit step with a DELETE-row example for items that can't be traced.
- **Impact:** the prompt now has 5 concrete "this exact failure happened" examples. The model has stronger negative training signal.

### 19.3 (⚠ silent failure) iOS Delete My Data now surfaces server errors
- **Bug:** `SettingsView.deleteData()` used `try? await APIClient.shared.deleteMyData(token:)`. Server failures (500, network) were silently swallowed; the success alert showed regardless. User would believe their data was deleted when it wasn't — privacy-impact, possible GDPR issue.
- **Fix:** replaced `try?` with `do/catch`. On error, shows a new `Couldn't Delete` alert ("We couldn't reach the server. Check your connection and try again."). Local data is NOT cleared on error so the user can retry. Added `@State showDeleteError`. Edge case: if there's no `apnsToken` in UserDefaults at all (never granted permission), success path runs immediately since there's nothing server-side to delete.

### 19.4 (⚠ rendering bug) `personalise()` now handles capitalised + possessive variants
- **Bug:** Audit query found 29 of ~150 routine rows use `[His name]` / `[Her name]` capitalised at sentence-start. `AppState.personalise()` only substituted lowercase forms. Those 29 items would render with the literal placeholder visible in the UI on iPhone — clearly broken.
- **Fix:** `personalise()` now handles `[his name]`, `[His name]`, `[her name]`, `[Her name]`, plus the `'s` possessive variant of each (8 patterns total). Empty-name fallback returns "your partner" / "Your partner" / "you" / "You" so the field is always grammatical.

### 19.5 (⚠ AI tell) Em-dash sanitizer now catches all four glyphs
- **Bug:** Audit hex-dumped recent DB rows and found em-dashes (U+2014) still present in body text. The jq regex was using literal — and –, missing rarer glyphs the model had been producing (e.g. U+2015 horizontal bar, U+2212 minus sign).
- **Fix:** `post_news.sh` now uses a bracket character class `[–—―−]` covering U+2013, U+2014, U+2015, U+2212. Verified syntax-OK and end-to-end strip via test payload.
- Also added matching strip in iOS `personalise()` as defence-in-depth.

### 19.6 (⚠ style violation) ALL-CAPS validator added to post_news.sh
- **Bug:** PROMPT.md style rule line 124 forbids ALL-CAPS emphasis ("DOUBLED", "MASSIVE"). A West Ham item shipped with "...DOUBLED in 48 hours...". Soft rule ignored, validation didn't catch it.
- **Fix:** new validator in `post_news.sh` that greps every string field for words matching `[A-Z]{4,}` and rejects if any found. Allowlists known acronyms (UEFA, FIFA, EFL, VAR, USA, GOAT, MOTD, XBOX). Verified: "DOUBLED" → exit 1 with clear error message. Acronym false positives are easy to grow as needed.

### 19.7 (⚠ TS hygiene) APNsPayload subtitle now optional in interface
- **Bug:** `apns-client.ts` interface declared `subtitle: string` as required, but `notification-sender` (correctly) omits it under the new lock-screen layout. Deno doesn't strictly enforce TS interfaces at runtime, so APNs received clean payloads. Cosmetic but misleading for future readers.
- **Fix:** changed to `subtitle?: string`. Comment notes `client-error-alert` still uses it for app-version metadata. Redeployed `notification-sender`.

### 19.8 (✓ non-blocker) Configuration.xcconfig "credentials" finding dismissed
Audit flagged the `SUPABASE_ANON_KEY` in xcconfig as a "showstopper for App Store review." This was wrong — anon keys are public-by-design (the Supabase equivalent of a Firebase API key). They only grant access to whatever RLS policies allow for `role=anon`. The service-role key (which would be a real leak) is server-side only. No action taken.

### Final pre-submission verification
Smoke test plan from the plan file:
1. APNs env on registration: query `device_tokens` after Release build install — confirmed prep, awaits real-device test
2. Push e2e: fire `gd-news` for test team, watch lock screen — pending
3. Routine field population: `push_title`/`push_text` non-NULL — pending fresh fire
4. Em-dash absence in new rows — pending fresh fire
5. Confabulation spot-check — pending fresh fire + manual audit
6. Delete My Data error path: verified via code review + alert wired

**Build status:** All known launch blockers fixed. Awaiting one fresh routine fire to validate push fields populate, then iOS Archive + upload + Submit.

---

## Phase 20: Bulletproofing — silent-failure detection across the pipeline (2026-05-06/07)

After the ultrareview shipped, two near-misses arrived during the actual launch sequence — both from blind spots that the audit hadn't catalogued: routine ran with stale uncommitted code, and 9 NULL-`published_at` rows pushed real items off the feed. Both were silent failures discovered only because the user happened to look. At launch scale, "discovered by chance" doesn't scale — silent failures become uninstalls before we hear about them.

We then ran three parallel deep-review agents covering all 9 pipeline stages. ~50 failure modes triaged into 6 P0 fixes that ship before submission, 5 P1 nice-to-haves, and 9 P2 v1.1 backlog items. This phase shipped the P0 set. Principle: every silent failure must become a loud failure; every stage that "should be working" must prove itself without a human watching.

**Files modified:** `backend/supabase/migrations/013_cron_heartbeat_alert.sql` (new), `backend/supabase/migrations/014_pushed_at.sql` (new), `backend/supabase/functions/notification-sender/index.ts`, `ios/GoalDigger/Services/APIClient.swift`, `ios/GoalDigger/Services/CacheService.swift`, `ios/GoalDigger/App/GoalDiggerApp.swift`, `/Users/anton/goaldigger-routines/PROMPT.md`, `/Users/anton/goaldigger-routines/post_news.sh`.

### 20.1 Cron silent-failure alarm
- **Bug:** if pg_cron stops firing `data-fetcher` (Supabase issue, secret rotation, job removed), nobody notices until users complain about a stale feed days later.
- **Fix:** new SQL function `check_pipeline_heartbeat()` queries `pipeline_health` for the most-recent successful `fetch` row. If older than 26h (data-fetcher runs daily), inserts a `cron_silent_failure` row into `client_errors` AND fires the existing `client-error-alert` edge function via `pg_net.http_post`, which pushes the alert to the dev iPhone via APNs. Throttled to one alert per 2h. Migration 013 schedules the check every 30 min via pg_cron.
- **Effect:** cron failure → push to dev phone within 30 min, instead of finding out tomorrow.

### 20.2 `pushed_at` column + re-push sweep
- **Bug:** no record of which items actually shipped pushes vs not. If APNs is down for 30 min, items publish but pushes are lost forever; no audit trail, no recovery.
- **Fix:** migration 014 adds `pushed_at TIMESTAMPTZ` to `content_items`. Backfilled all existing published rows so the sweep doesn't re-fire 150+ historical items. `notification-sender` writes `pushed_at` on every terminal outcome (successful send, anti-spam blocked, no eligible tokens). Sweep mode (called by hourly `notification-sweep` cron) now picks up `status='published' AND pushed_at IS NULL AND published_at < NOW() - 5 min` — 5-min grace window prevents racing post_news.sh's own push trigger.
- **Effect:** any push miss self-heals within 1 hour. Queryable audit ("which items haven't been pushed").

### 20.3 APNs 403 → loud alert
- **Bug:** APNs auth failure (`.p8` rotated, wrong Team ID, expired key) was logged as CRITICAL and stopped iteration, but no alert. Discovered only when users complain.
- **Fix:** `notification-sender` now fires `client-error-alert` via internal HTTP fetch on 403, with `error_type='apns_auth_failure'`. Existing throttling (30 min per error_type) prevents spam if multiple items hit the bad auth in sequence.
- **Effect:** auth break → push on dev phone within minutes.

### 20.4 Partial decode resilience for `[ContentItem]`
- **Bug:** `JSONDecoder.decode([ContentItem].self, ...)` is all-or-nothing. One bad row in a 20-item feed → entire array throws → user sees blank feed. Server-side filters help against specific causes but don't generalize. Today's `published_at=NULL` was one such instance, but field renames/type changes could trigger the same.
- **Fix:** new `APIClient.decodeContentItems(from:)` private helper. Parses the JSON as `[Any]`, then attempts per-item `decoder.decode(ContentItem.self, ...)`, swallowing per-item failures with a `#if DEBUG print()` log. All three feed/item call sites now use the helper. One bad row → 19 visible items instead of 0.
- **Effect:** schema drift no longer turns into user-facing blank screens. Bug is loud in DEBUG, gracefully degraded in Release.

### 20.5 SwiftData cache schema-version invalidation
- **Bug:** `CachedContentItem` is `@Model` and persists across upgrades. If a future release renames or restructures any persisted field, users on old caches can crash on first read (per past pitfall #6).
- **Fix:** new `CacheService.cacheSchemaVersion: Int = 1` constant. `CachedContentItem` gains `var schemaVersion: Int = CacheService.cacheSchemaVersion`. New `purgeStaleVersionItems(in:)` method deletes rows whose version doesn't match current. Called from `RootView.task(id:)` on app launch — cheap no-op when versions match, transparent purge when they don't.
- **Effect:** future schema bumps don't crash anyone. Bumping the constant is the only change needed when adding required fields.

### 20.6 Routine git-staleness preflight
- **Bug:** the bug we hit during launch prep — local edits to `post_news.sh` and `PROMPT.md` weren't committed; routine pulled `origin/main` (old code) and shipped a broken Arsenal item. No way to tell from the routine log which code was running.
- **Fix:** PROMPT.md step 0 now instructs the routine to print `[ROUTINE VERSION] <sha> <commit-message>` first thing on every run. `post_news.sh` separately prints its own `[POST_NEWS VERSION] <sha>` on every invocation. Both visible in the dashboard log; mismatch with what's on origin/main is a flag to push and re-fire.
- **Effect:** "is this version of the prompt running?" is answerable at a glance. Lock screen against the recurring "summary said it shipped, but it didn't" failure mode.

### 20.7 Verification

| # | Check | Expected | Done |
|---|---|---|---|
| 1 | `SELECT column_name FROM information_schema.columns WHERE table_name='content_items' AND column_name='pushed_at'` | row returned | ✓ |
| 2 | `SELECT jobname FROM cron.job WHERE jobname='goaldigger-cron-heartbeat-check'` | row returned, schedule `*/30 * * * *` | ✓ |
| 3 | `notification-sender` deployed with new sweep + 403 alert + pushed_at writes | Supabase deploy success | ✓ |
| 4 | `purgeStaleVersionItems` wired into RootView's `.task` | code review | ✓ |
| 5 | post_news.sh syntax-OK + new version-tag echo present | bash -n + grep | ✓ |
| 6 | PROMPT.md step 0 instructs routine to print [ROUTINE VERSION] | grep | ✓ |

Outstanding live tests (need fresh routine fire + real device):
- Cron alarm fires when no fetch row exists in 26h window
- pushed_at populates after a real fire
- APNs 403 alert lands on phone (would require deliberately corrupting `APNS_KEY_P8` — only worth doing if we suspect the path is broken)

### 20.8 Out of scope (P2 backlog)

Logged for v1.1 work; not blocking submission:
- Per-token push audit log (`push_audit` table)
- Per-user-timezone quiet hours
- Idempotency-Key headers on Supabase POSTs
- CAPS allowlist sourced from external file
- Onboarding uninitialized-state recovery
- Background-fetch error surfaced to UI ("stale" badge)
- Schema-version field embedded in JSON for routine
- Exponential backoff on 5xx in post_news.sh
- RSS / API-Football fetch retry loop

**Build status:** P0 bulletproofing shipped. Backend + iOS + routine prompts all updated. Pipeline now has 3 alerting layers (cron heartbeat, APNs 403, sweep retry) and 2 client-side resilience layers (partial decode, schema-version cache invalidation). Ready for App Store Archive + upload.

---

## Phase 21: Match-day pipeline unblocked + every-minute polling (2026-05-07)

The actual Phase 20 verification revealed THREE silent failures in the production pipeline that the bulletproofing work itself didn't catch — and one false start (a manager-name whitelist that was rolled back the same day after the user correctly questioned the maintenance burden). End of day, the matchday auto-trigger pipeline is — for the first time — actually capable of firing for a real Premier League match.

**Files modified:** new migrations `015_fix_cron_settings.sql`, `016_notification_sweep_cron.sql`, `017_match_watcher_every_minute.sql`. Routine repo: PROMPT.md, MATCHDAY_PROMPT.md, post_news.sh (multiple back-and-forth commits ending at `70d6021`).

### 21.1 Match-watcher cron: 2,444 silent failures since deployment
- **Discovery:** queried `cron.job_run_details` and saw `match-watcher-5min` with 2,444 runs and **zero** successes. Every tick had been failing with `ERROR: unrecognized configuration parameter "app.settings.supabase_url"`. The cron command from migration 008 referenced `current_setting('app.settings.supabase_url')` — a Postgres GUC that was never configured on this Supabase project (and `ALTER DATABASE ... SET` is blocked for our role).
- **Same bug in my own bulletproofing:** the heartbeat check from migration 013 used the same broken pattern with `current_setting(..., true)` (silent NULL return). My alarm system was itself broken because of the very issue it was meant to detect. Galaxy-brain blind spot.
- **Fix:** migration 015 unschedules both broken jobs and re-creates them with hardcoded URL + service-role key (matching the working `goaldigger-daily-pipeline` cron pattern from migration 006). Replaced `check_pipeline_heartbeat()` function with a version that hardcodes the URL too. Verified next tick succeeded ("1 row" return at 18:50 UTC).

### 21.2 Notification-sweep cron didn't exist
- **Discovery:** `notification-sweep` cron was supposed to exist per migration 003. Querying `cron.job` showed it was never actually scheduled — same pattern as match-watcher's broken cron. Without this, Phase 20's `pushed_at` resilience mechanism couldn't actually retry: items would just sit with `pushed_at IS NULL` forever.
- **Fix:** migration 016 schedules `notification-sweep` hourly at `:15`, hardcoded URL + key. Manually invoked notification-sender once (curl with service-role key) to flush the existing 23-item backlog (5 from the day's broken-prompt run + 18 from earlier). Confirmed `pushed_at` populated for all of them.

### 21.3 Routine git-staleness verified working
- First fire of `gd-news` after pushing commit `71f22b1` produced items with the OLD format (no `push_title`/`push_text`). The `[ROUTINE VERSION]` log line — added in `a77ab3d` — was absent from stdout, confirming the routine had pulled `origin/main` BEFORE the commit landed.
- Second fire after pushing `a77ab3d` showed `[ROUTINE VERSION] a77ab3d Add git-staleness preflight: ...` as the first log line, and the resulting Chelsea item had populated `push_title="He'll take sides"` and `push_text` with the sister-voice format.
- The git-staleness preflight from Phase 20 worked exactly as designed: when the version mismatch was visible, we knew immediately to re-fire after the push completed.

### 21.4 False start: manager-name whitelist (rolled back)
- The Chelsea item that proved push_title/push_text worked also contained "interim boss Calum McFarlane" — a fabricated name (same class as "Liam Rosenior" earlier). Built a hard whitelist: `data/managers.json` source of truth, `{{manager}}` placeholder requirement in prompt, post_news.sh substitution + validation block.
- User pushed back on three correct grounds: (1) maintenance burden ("I don't ever want to change anything myself"), (2) false rejection risk (genuine new-manager appointment would block the routine until file updated), (3) confabulation rate is ~2% — solving 100% via maintained-state was the wrong tradeoff.
- **Rollback shipped same-day** (`70d6021`): deleted `data/managers.json`, removed substitution + validation block from post_news.sh, dropped MANAGERS rule from PROMPT.md. Kept the expanded past-failures list (Rosenior + Gallagher + McFarlane) because it serves as in-context training without enforcement teeth. If McFarlane-class fabrications become a real launch-day pain, revisit with a programmatic RSS-grep approach (no whitelist to maintain).

### 21.5 Match-day routine end-to-end manual test
- Triggered `gd-matchday` from the routines dashboard with a fake fixture trigger:
  ```
  team_id=arsenal; fixture_id=99999; status=finished; opponent=chelsea; score=2-1; kickoff_time=2026-05-07T19:00:00+00:00
  ```
- Routine produced an item with `push_title="Phone-his-dad moment"` (20 chars) and `push_text="Arsenal beat Chelsea 2-1 in the London derby. He'll work the whole address book."` (80 chars). Self-critique scored 17/20 on the immersive analogy.
- The model picked the **exact canonical example template** from PROMPT.md ("Phone-his-dad moment" was one of the 22 locked examples). In-context examples worked: model recognised the scenario type (derby win for subject team) and reused the registered voice template verbatim.
- This is the first time the matchday pipeline has been observed working end-to-end on the new sister-voice format. The auto-trigger chain (match-watcher → /fire) still requires a real PL fixture to fully validate — Saturday or whenever the next fixture day is.

### 21.6 Switched match-watcher to every-minute polling
- API-Football paid tier is ~7,500 calls/day; 1,440 calls/day from per-minute polling = ~20% utilisation. Migration 017 unschedules `match-watcher-5min` and creates `match-watcher-1min` at `* * * * *`. Same hardcoded URL + key.
- Effect: when a real match transitions to FT, the post-match push lands within ~1–2 min of the final whistle (capped by API-Football's own ~30–60s reporting lag) instead of ~3–5 min worst case under 5-min polling. For the brand promise — "she gets the heads-up before he calls/arrives" — those minutes matter.

### 21.7 Verification status

| Pipeline | Verified | Notes |
|---|---|---|
| `gd-news` routine end-to-end | ✓ | "He'll take sides" Chelsea item, sister voice, push fired |
| `gd-matchday` routine end-to-end (manual fire) | ✓ | "Phone-his-dad moment" Arsenal item, full pipeline |
| `match-watcher` cron healthy | ✓ | succeeds every tick since 015 |
| `notification-sweep` cron healthy | ✓ | exists since 016 |
| Match-watcher → `/fire` chain (auto-trigger) | ✗ | needs a real PL fixture; Saturday will be the first test |
| `MATCHDAY_ROUTINE_URL` + `_TOKEN` validity | ⚠ | secrets present in Supabase (digests visible); haven't validated by actually firing |

### 21.8 What's left for launch

- **Saturday's fixtures** prove the auto-trigger chain end-to-end with zero human input. If post-match cards land for both teams within ~2 min of FT, ship.
- **iOS Archive + upload** to App Store Connect.
- **App Store description copy update** (remove any "no subscription" leftover from the Free+IAP draft now that we're paid £4.99).

**Build status:** Match-day pipeline unblocked for the first time in the project's history. Daily routine pipeline confirmed working with sister-voice format. Whitelist false-start rolled back. One real PL match away from full launch confidence.

---

## Development Pitfalls & Lessons Learned

Recurring patterns that caused bugs or required fixes during development. Reference this list before starting new features.

### 1. Navigation context loss through deep links
**What happened:** Notification taps for "Everyone's talking about" content set `activeContext = .everyoneTalking` correctly, but the deep link handler appended a bare `UUID` to the navigation path. The `navigationDestination(for: UUID.self)` created a detail view with `isEveryoneContext: false`, so the user saw personalised team content instead of neutral cross-team content.
**Rule:** Always navigate with a typed destination struct (e.g. `ContentDetailDestination`) that carries all context. Never pass a bare ID when the destination needs to know _which feed context_ it came from. When adding a new context or parameter to the detail view, audit every entry point (deep links, notifications, NavigationLinks, NotificationCenter posts).

### 2. Default parameter values hiding semantic bugs
**What happened:** `ContentCard` had `feedContext: FeedContext = .everyoneTalking` with a comment saying "defaults to team context." The default was wrong but callers always passed explicitly, so it never caused a visible bug — just a time bomb.
**Rule:** If a parameter must always be provided by the caller, don't give it a default. Make it a required `let`. Reserve defaults for genuinely optional convenience parameters where the default is obviously correct.

### 3. Dual-computation in computed properties
**What happened:** `ImmersiveCard.contextLine` called `appState.personalise()` twice on the same string — once to check emptiness, once for the return value.
**Rule:** In computed properties with expensive or side-effect-free transforms, always compute once into a local variable, then branch on it. Pattern: `let result = transform(input); return result.isEmpty ? nil : result`.

### 4. Dead code accumulation during refactors
**What happened:** When switching from `NavigationLink` to `NotificationCenter` for immersive card navigation, the `NavigateAction` EnvironmentKey, `@Environment(\.navigate)` property, scroll position state variables, and `feedResetScrollPositions` notification were left behind — declared but never used.
**Rule:** After any navigation or architecture refactor, grep for the old pattern and remove all orphans. Specifically check: (1) Environment keys/values, (2) @State/@Binding properties, (3) Notification.Name declarations, (4) `navigationDestination(for:)` registrations that no longer have matching `NavigationLink(value:)` pushes.

### 5. Magic numbers scattered across files
**What happened:** The immersive card zone ratios (0.65/0.35) and card height ratio (0.88) were hardcoded in ImmersiveCard, ImmersiveSkeletonCard, FeedView, and EveryoneEmptyStateCard. Changing the split would require finding and updating 6+ locations.
**Rule:** Any numeric value used in more than one file belongs in `Layout` (Theme.swift). Even if it starts in one file, move it to Layout the moment a second file needs it.

### 6. SwiftData @Model migrations need defaults
**What happened:** Adding `everyoneTalking: Bool` to `CachedContentItem` without a default value risked a SwiftData lightweight migration failure on devices with existing cached data.
**Rule:** When adding a new property to any `@Model` class, always provide a default value (`= false`, `= ""`, `= nil` for optionals). SwiftData's automatic lightweight migration can only add columns when it knows the default.

### 7. Inconsistent styling across similar UI sections
**What happened:** The "FEED FORMAT" section header in SettingsView used `.sectionHeader` font + `.textTertiary` color, while all other settings section headers used a different font size and `.hotRose.opacity(0.7)`. This created a visually inconsistent settings page.
**Rule:** When adding a new section that lives alongside existing sections, always copy the styling from a sibling section — don't re-derive it from the theme. If the shared pattern isn't already a reusable helper/modifier, make it one (like `settingsSection(header:)`).

### 8. Silent error swallowing hides real failures
**What happened:** `loadMore()` and `loadPlayers()` had empty `catch {}` blocks. During development, network failures and decoding errors were silently swallowed, making it hard to debug why data wasn't appearing.
**Rule:** Never leave a `catch {}` truly empty. At minimum: `#if DEBUG print("⚠️ context: \(error)") #endif`. For user-facing errors, set an error state. Only suppress errors when you've explicitly decided the user doesn't need to know (e.g. pagination fails but existing data is still visible).

### 9. Font migration requires a full audit
**What happened:** Replacing SF Rounded with Plus Jakarta Sans required updating 29 inline font references across 11 files, plus the 10 semantic tokens in Theme.swift. Some references used `.system(.body, design: .rounded)`, others used `.system(size: 64, weight: .bold, design: .rounded)` — two different API shapes to find.
**Rule:** Centralise ALL text fonts through Theme.swift semantic tokens. Never use inline `.font(.system(...))` for text — always create a named token (`.feedHeadline`, `.immersiveHeadline`, etc.) and reference that. SF Symbol icon sizing (`.font(.system(size: 14))` on `Image(systemName:)`) is the exception — those stay as `.system`. When doing a font migration, grep for both `design: .rounded` AND `.system(size:` to catch all patterns.

### 10. Backward-compatible Codable decoding for cached data
**What happened:** Adding 11 new fields to `ContentItem` broke decoding of items already cached in SwiftData (encoded before the new fields existed). Fixed by replacing the default `Decodable` conformance with a custom `init(from:)` using `decodeIfPresent` with defaults for every new field.
**Rule:** Any time you add a field to a `Codable` struct that might already be persisted (in SwiftData, UserDefaults, or on-disk JSON), use `decodeIfPresent` with a sensible default. Never rely on the auto-generated decoder for models that evolve over time. Consider adding a schema version field for complex models.

### 11. Build destination matters
**What happened:** Initial build commands used `iPhone 16 Pro` which doesn't exist on Xcode 26. The correct simulator is `iPhone 17 Pro` with `OS=26.4`.
**Rule:** Always run `xcodebuild -showdestinations` or check the error output for available destinations before scripting builds. The destination string must match exactly: platform, OS version, and device name.

### 12. xcconfig values get truncated at `//`
**What happened:** `SUPABASE_URL = https://cwgpsmbunrocrofziqad.supabase.co` was stored in `Configuration.xcconfig`. The built `Info.plist` contained `"https:"` — the host was silently stripped because the `//` was treated as a comment marker by the Info.plist build phase. Every API call resolved to `https://rest/v1/...` (host = "rest") and failed. The iOS app silently fell back to SwiftData cache, so the bug was invisible until someone tapped a team that wasn't cached.
**Rule:** Never store a full URL with `://` in xcconfig. Store the bare hostname (`SUPABASE_HOST = cwg...supabase.co`) and prepend `https://` in Swift. Also: print Info.plist values at app launch in DEBUG and verify what actually built in.

### 13. `UIScrollView.appearance()` poisons every text field
**What happened:** Onboarding name fields rendered with a dark transparent background when typing — black text became invisible. Spent hours trying SwiftUI fixes (`.textFieldStyle(.plain)`, ZStack, `RoundedRectangle.fill`, even a UIViewRepresentable wrapping `UITextField`). Real culprit: `UIScrollView.appearance().backgroundColor = UIColor(deepMauve)` in `AppDelegate.swift`, added to fix overscroll flash. Appearance proxies apply globally — including to the `UIScrollView` `UITextField` uses internally to scroll long text.
**Rule:** Never call `UIScrollView.appearance().backgroundColor = ...` in an app with text input. If you need overscroll backgrounds, set them per-ScrollView in SwiftUI (`.background(...)` directly on the ScrollView). UIKit appearance proxies cast a wider net than you expect — they hit *every* instance of that class anywhere in the app, including views nested inside other controls.

### 14. Forced dark mode + SwiftUI `.environment(\.colorScheme, .light)` doesn't override UIKit
**What happened:** App forces dark mode via `UIUserInterfaceStyle = Dark` in Info.plist + `.preferredColorScheme(.dark)` on root. Trying to override for a single TextField with `.environment(\.colorScheme, .light)` had no effect — UIKit-rendered controls inside still rendered dark.
**Rule:** SwiftUI environment values flow only through SwiftUI views; UIKit reads `UITraitCollection` set at the window/UIViewController level. To force light treatment on a specific UIKit control, use `overrideUserInterfaceStyle = .light` directly on the `UIView` (e.g. via UIViewRepresentable) — not SwiftUI environment values.

### 15. `displayContext` was gated on the wrong approval flag
**What happened:** AI critic was approving analogies (`analogy_critic_score.verdict = "approve"`), but iOS still showed the factual fallback line because `displayContext` checked `analogyApproved` — a *human review flag* that's always `false` for auto-pipeline content. Result: the entire "girl reference" feature was hidden behind fallbacks.
**Rule:** When the pipeline has multiple approval signals (AI critic, human review, auto-publish), be deliberate about which one the UI trusts. Default to the one that's actually populated by your live pipeline. Document the ladder: AI critic gates the data into the DB; if the field is non-null, it's safe to show.

### 16. AI critic without a rewrite path = product features quietly disappearing
**What happened:** Original critic flow was score → if reject, null out → fallback shown. Most analogies got rejected and silently nulled. The product feature (witty cross-world analogies = the actual "girl reference") was disappearing into the fallback for the majority of items.
**Rule:** When the AI critic gates content into production, give it a rewrite-on-reject path. Score → reject → rewrite using the critic's specific feedback → re-score → save the rewrite if it now passes, else fall back. Most "rejected" content can be rescued by a focused rewrite. Log both the original failure and the rewrite for audit.

### 17. SwiftData cache masks API failures
**What happened:** `FeedView.loadInitial()` shows SwiftData-cached items immediately for fast UX, then re-fetches in the background. When the URL bug (#12) broke fetches, users saw cached items and assumed the app was fine. Hours wasted debugging "why isn't the API returning fresh data?" when the API was working — iOS just couldn't reach it.
**Rule:** Cache-first patterns need explicit error states surfaced when the background re-fetch fails — don't let a fetch error fall through silently while the cache UI keeps showing. When debugging "no fresh data," always confirm the iOS app is actually receiving the API response (curl with the iOS-shape `select=` query string, check Xcode console for `-1003` or decoding errors).

### 18. Detail view blank screen from a missed empty-state branch
**What happened:** Tapping a feed card sometimes led to a fully blank detail screen (only the back button). `ContentDetailView.loadItem()` did `fetchItem(id:)` which sometimes returned empty (transient blip, stale UUID from cache). `item` stayed `nil`, `isLoading` flipped `false`, and the body had `if let item { ... } else if isLoading { spinner }` — *no else branch* for `item == nil && !isLoading`.
**Rule:** Two things. First, always have an explicit empty/error state in any view that conditionally renders based on loaded data — never fall off the end of an `if/else if` chain. Second, when navigating from a list view to a detail view, pass the loaded model through navigation (`preloadedItem`) so detail renders immediately. Re-fetching by ID is brittle and unnecessary when the source view already has the data.

### 19. Worktree confusion with multiple `.xcodeproj` copies
**What happened:** Edited Swift files in `/ios/GoalDigger/`, rebuilt in Xcode — change wasn't in the build. Compiled dylib still had the old code. Cause: Xcode was open on a worktree at `.claude/worktrees/intelligent-thompson/ios/GoalDigger.xcodeproj`, not the main repo.
**Rule:** Every time you start an editing session, confirm Xcode's project path matches your edit path. Check via `cat ~/Library/Developer/Xcode/DerivedData/<APP>-*/info.plist | PlistBuddy -c 'Print :WorkspacePath' /dev/stdin` or just look at the Xcode title bar.

### 20. Auto-expand-first-item dressed up as a feature, felt like a bug
**What happened:** First-launch-after-onboarding logic auto-set `appState.deepLinkContentId = firstItem.id`, which routed the user straight into a detail view of the first article. Users perceived this as "the app starts on an article, not a feed." Tapping back was the only way out.
**Rule:** "Magic moment" auto-actions (auto-open, auto-expand, auto-play) almost always read as bugs — users don't have the mental model that explains them. Default to neutral starting state. If you really want a guided first-experience, do it visibly (e.g. tooltip overlay) so the user sees it as intentional.

### 21. `geo.size.height` vs `UIScreen.main.bounds.height` for full-screen cards
**What happened:** Immersive feed cards built with `cardHeight = geo.size.height` — each card filled the visible viewport, but a sliver of the next card peeked under the bottom during scroll. Switched to `UIScreen.main.bounds.height` to extend the card behind the tab bar — but didn't adjust zone proportions, so zone 2 (the talking-point pink area) ended up mostly *behind* the tab bar, making the talking point invisible.
**Rule:** When choosing card height, the trade-off is "viewport-fitting (next card peeks during scroll)" vs "screen-fitting (card extends behind tab bar)". Pick one deliberately, and if you go screen-fitting, recalculate zone ratios so all important content stays inside the visible viewport (~85% of screen height on iPhone). Don't put the most-readable content in the bottom 15% of a full-screen card.

### 22. Two write paths into the same table mean two notification paths to test
**What happened:** Pre-launch audit found that `gd-news` and `gd-matchday` routines insert into `content_items` directly with `status='published'` via `post_news.sh`, but `notification-sender` only triggered for items written by the legacy edge-function pipeline (its query filtered `status='approved' AND published_at IS NULL`, which routine items never matched). Result: feed populated correctly via pull-to-refresh, but no APNs push ever fired. For a notification-driven app, that's the entire product silently broken — the kind of bug that doesn't manifest until a real user installs the app.
**Rule:** When you have multiple write paths into the same table (edge-function pipeline + Routine pipeline + manual inserts), enumerate every downstream consumer (push, analytics, indexing) and verify each one fires for each write path. Document the matrix explicitly. A simple "what triggers a push?" question answered upfront would have caught this in 30 seconds; instead it took a remote-DB cron-job audit to surface. Also: empty-state side-effects (no `device_tokens` registered yet) hide push gaps in dev — always trace the code path even when there's no test data to exercise it.

### 23. Plan exploration on the wrong git branch produces phantom issues
**What happened:** During pre-launch planning, an Explore subagent reviewed backend code from `main` while the actual deployment source was the `claude/intelligent-thompson` worktree. The agent reported "content-generator not gated" and "duplicate cron job in 006_pipeline_schedule.sql" — both of which were already fixed in the worktree (the gating is at line 309 of data-fetcher; the worktree's `006` is `pipeline_source.sql`, not the duplicate-cron migration). Real issues were elsewhere (push notification trigger gap).
**Rule:** When delegating exploration to a subagent for a worktree-based task, tell the agent the exact worktree path explicitly and confirm in the response that it read from there. `git worktree list` first to know which paths exist; pass the worktree path in the prompt; spot-check the agent's findings by reading 1-2 key files yourself before acting on the report. Phantom issues waste planning time and erode trust in subsequent agent reports.

### 24. Soft length caps in prompts don't work — enforce in code
**What happened:** PROMPT.md said "Headline max 160 characters. iOS truncates push notifications around there. Count yours and rewrite if longer." The model ignored it: 2 of the 3 most-recent routine items pre-launch were 173 and 156 chars (one truncating, the other right at the edge). For text that goes to a user-facing lock screen, "soft cap in a prompt" means "broken 67% of the time."
**Rule:** Any model-generated field with a hard rendering constraint (push body length, headline length, image dimensions) needs hard validation in the write path — not just a polite request in the prompt. In our case, `post_news.sh` now exits 1 if `push_text > 90` or `headline > 160`, forcing the routine to retry with a compliant payload. The prompt rule still lives there as guidance to reduce retry rate, but the script is the actual enforcer. Pattern: prompt for the happy path, validate at the boundary, fail loud and force retry.

### 25. Brand-voice copy needs "what NOT to sound like" lists, not just "what to sound like" guidelines
**What happened:** First-draft push examples kept slipping into either sports-app newsroom prose ("Big swing", "Plot twist", "Worth knowing") or crisis-counsellor language ("Brace yourself", "He'll be unbearable", "Pretend you didn't see"). Both read as wrong-voice — the second category was actively bad, framing him as a threat she has to survive. Repeated guidance like "warm, conversational, sister voice" wasn't enough; the model knew the destination but kept landing in the wrong neighbourhood.
**Rule:** For brand-voice copy that has to hit a specific register, the prompt must include explicit BANNED PATTERNS lists, not just positive guidance. "Don't sound like X" with concrete examples is more effective than "do sound like Y" alone, because the model can recognise patterns it's about to produce. We now ship four banned categories: sports-app push categories, Twitter clickbait, wire-service tags, and crisis-counsellor framing — each with 5+ concrete examples. The locked canonical examples (22 of them) anchor the positive direction. Both pieces are needed.

### 26. Kickers fail when they compress past sentence-shape
**What happened:** Drafted "Phone-his-dad moment / Arsenal beat Spurs 2-1 in the derby. The whole address book." User flag: "The whole address book is a bit lonely so it doesn't make sense really." Right — "The whole address book" is a bare noun phrase with no verb, no subject. It reads as a TV-news chyron tag, not as something a person says. The same compression that works for headlines kills push kickers, which need to read as actual speech.
**Rule:** Kickers (the trailing observational fragment after a fact) must contain a verb explicitly OR be a complete idiom with an implied verb ("Crisis averted." / "T-shirt material." / "Comfort-food night.") OR be a short imperative ("Order in tonight."). Never a bare noun phrase. The test is to read the kicker aloud on its own — if it sounds like a sentence a person would say, ship it. If it sounds like a TV ticker, rewrite. This rule lives in PROMPT.md PUSH RULES with both ✓ and ❌ examples.

### 27. "Conversation summary said it was fixed" doesn't mean it shipped
**What happened:** The pre-launch audit re-found the APNs-environment-on-registration bug that the conversation summary explicitly listed as fixed ("added `apnsEnvironment` static let with `#if DEBUG`"). The fix had never actually landed in this worktree — `grep -rn "apnsEnvironment" ios/GoalDigger/` returned zero matches. A long session compaction can list intent and outcome as if they happened, when only the intent did. Without the audit, this would have shipped to App Store with zero pushes working in production.
**Rule:** When a context-window compaction summarises completed work, treat it as a hypothesis, not a guarantee. Verify by grep-or-read for the specific identifier the summary names, especially before launch. Trust but verify, even within your own session memory.

### 28. Audit agents over-flag "credentials" in client-side config
**What happened:** The iOS audit agent flagged `SUPABASE_ANON_KEY` in `Configuration.xcconfig` as a "showstopper for App Store review — credentials must be rotated immediately." This is wrong. Supabase anon keys are public-by-design (analogous to Firebase API keys); they're meant to be embedded in clients and gated by RLS. Service-role keys would be the real leak — those are server-side only. The audit agent didn't have the context that anon ≠ service_role.
**Rule:** When an agent flags "credentials in source," before acting check: is this a public-by-design key (anon, publishable, API key with RLS gating) or a true secret (service role, master key, signing key)? The first is a non-issue; the second is a true leak. Rotate only on the second. Don't burn time rotating keys that were never meant to be private.

### 29. Soft style rules in prompts need code-level enforcement when image is at stake
**What happened:** PROMPT.md style rule explicitly forbade ALL CAPS emphasis. A routine item shipped with "...have DOUBLED in 48 hours..." anyway. Same pattern earlier with em-dashes (rule said "no em dashes," items shipped with em-dashes). Pattern: soft style rules that the model can technically violate WILL be violated occasionally, and "occasionally" at scale means hundreds of bad pushes a year.
**Rule:** For any voice/style constraint where a single violation would embarrass the brand on the user's lock screen, add a hard validator in `post_news.sh` that rejects payloads breaking the rule. Soft rule in prompt for happy path; hard reject at the boundary. Acronyms etc. need an explicit allowlist (we ship with UEFA/FIFA/EFL/VAR/USA/GOAT/MOTD/XBOX as initial allowlist; grow as needed).

### 30. Player–club affiliations are the highest-confabulation-risk field
**What happened:** Two recent routine items confidently named players with the wrong club ("Conor Gallagher (Spurs midfielder)" — never at Spurs) or fabricated names entirely ("Calum McFarlane interim Chelsea boss" — no such person). Player–club mappings change every transfer window, the model's training data lags reality, and the GROUNDING rule alone wasn't enough — the model would name a player and assign them to a plausible-feeling club without checking the RSS.
**Rule:** PROMPT.md now has an explicit PLAYER AFFILIATIONS subsection — the player's current club must appear next to their name in the RSS text, no inferring from training-data memory. Plus a SAFE-REWRITE PRINCIPLE: when in doubt, drop the specific name in favour of a role tag ("a Chelsea midfielder said..."). Vague is always better than wrong. The brand promise is "she'll know what to say tonight" — a confidently wrong name is the failure mode that breaks that promise.

### 31. Postgres NULLs sort first in DESC — and that breaks feeds
**What happened:** 9 historical routine items had `status='published'` but `published_at=NULL`. iOS feed query ordered by `published_at DESC`. Postgres places NULLs first in descending order, so those broken rows pushed the genuinely-fresh Declan Rice item to position #3 — invisible on first scroll. iOS Date decoder is also non-optional, so attempts to decode the NULL would fail; the user saw only stale cache. Conversation summary said `not.is.null` filter had been added; verification showed it had been reverted/never landed.
**Rule:** Any iOS query that orders by a nullable timestamp DESC must include `not.is.null` server-side filter. Any iOS Codable field that the server can return as NULL must be optional in Swift. And: when adding a defensive filter to fix a bug, also add a backfill so the broken rows are gone for everyone, not just hidden behind one client's filter. Belt + braces + clean-up.

### 32. Pipeline silent failures need at least three independent alarms
**What happened:** The launch sequence revealed two whole classes of silent failure that the original audit didn't catch — uncommitted code shipping to production, and NULL data in non-nullable iOS decoders. Both invisible until a user noticed. At launch scale, "until a user noticed" is too late.
**Rule:** Every cron job needs a heartbeat check with auto-alerting. Every push needs a `pushed_at` audit column. Every API auth failure needs to fire an alert (not just log). Every iOS array decode needs partial-decode tolerance. Every persisted cache needs a schema version. And every script with versioned content needs to print its version on each run. Five layers of "did this thing work?" — independent of each other so one failing doesn't blind the others.

### 33. `pg_cron` failures are visible only in `cron.job_run_details` — query it
**What happened:** match-watcher's cron had been failing every 5 min for weeks (2,444 consecutive failures, zero successes) before discovery. The cron was scheduled and `active=true`, so it LOOKED fine on a casual check. The actual failures were only visible by querying `cron.job_run_details`. Nothing else surfaced this — no Supabase dashboard alert, no email, no degraded service signal (because the function the cron called was working fine when invoked manually). The user-visible bug ("matchday content never appears") looked like routine-side flakiness for weeks.
**Rule:** Whenever a pg_cron job is suspected of misbehaving, the diagnostic is `SELECT count(*) FILTER (WHERE status='succeeded') FROM cron.job_run_details WHERE jobid = <id>;`. If it's 0, the job has been failing silently — check `return_message` for the error. Add this query to the standard launch-day pre-flight. Better: bake it into the bulletproofing heartbeat (the heartbeat function should query `cron.job_run_details` for ALL cron jobs and alert on any with 0% success rate over the last hour).

### 34. The same blind spot can poison the alarm meant to detect it
**What happened:** Phase 20's heartbeat alarm (migration 013) was specifically designed to catch silent cron failures by alerting on missing `pipeline_health` rows. It used `current_setting('app.settings.supabase_url', true)` — the same broken pattern that caused match-watcher to fail in the first place. Worst: the `(..., true)` variant returns NULL silently rather than erroring, so the heartbeat would have run successfully every 30 min while doing absolutely nothing. The very mechanism designed to catch silent failures was itself silently failing.
**Rule:** When designing an alarm for a class of bug X, audit whether the alarm can suffer from X. If yes, build it on a different foundation. If you can't, the alarm needs its own meta-alarm — or you need to test it by deliberately triggering X. Before trusting any monitoring system, deliberately break the thing it's supposed to monitor and confirm the alarm fires.

### 35. Hard whitelists demand maintenance the user may not consent to
**What happened:** Built a manager-name whitelist (managers.json + post_news.sh validation + prompt placeholder requirement) to eliminate manager-name confabulations. Solved the problem cleanly. But the user immediately flagged: "I don't ever want to change anything myself." Every PL manager change (sacking, appointment, interim) would silently break the routine until the JSON was edited. For a 2% confabulation rate, this is a wildly worse tradeoff: trading occasional bad content for guaranteed silent breakage on every transfer-window event.
**Rule:** Before shipping a hard-state validation system (whitelist, allowlist, version registry), explicitly write down the maintenance contract: "On EVENT, USER must update FILE within DURATION or BAD_THING happens." Read it back. If "USER" is the founder and the cadence is anything more than monthly, the system is wrong for the workflow. Soft enforcement (prompt rules, in-context examples) almost always wins for solo / small-team operators. Hard validation is for teams with on-call rotation and runbooks.

### 36. Multiple plan files in `~/.claude/plans/` cause confusion
**What happened:** During a long session, multiple plan files were created in `~/.claude/plans/`. The "active" one was referenced in system reminders but old ones lingered with stale content, leading to UI showing outdated plan headlines.
**Rule:** When in doubt, `ls -la ~/.claude/plans/` and check mod times. Mark stale plans as superseded. Better: write to a single named plan file per multi-day work stream rather than letting random-name files accumulate.

---

## Phase 22: Match-watcher rescue, JWT rotation, Round-4 voice, first auto-fire — COMPLETE (2026-05-11)

Single day. Roughly 12 hours of work that turned the matchday auto-trigger from "never produced a single item end-to-end" into "first ever auto-fired matchday content landed at 21:13 UTC, 5 minutes after Spurs-Leeds final whistle." Plus an emergency JWT rotation closing a 4-day public-repo leak. Plus four rounds of iteration on the content quality recipe with the user. Plus iOS team-list + team-page fixes for the three 2025-26 promoted clubs.

### 22.1 Match-watcher fix #1: missing API-Football `season` param

**Symptom:** `match_status_state` empty for weeks. Manual curl to the edge function returned `fixtures_seen: 0` every day, even on Saturdays with a full PL slate. The cron itself was firing correctly.

**Root cause:** `backend/supabase/functions/match-watcher/index.ts` built the API-Football URL as `/fixtures?league=39&date=<today>` — missing the required `season` parameter. Without it, the endpoint returned an empty array (or an errors object), and the code's `fixturesJson.response ?? []` swallowed the failure. Every fire processed an empty loop.

**Fix (commit `04996fd`):**
- Added `const SEASON = 2025;` with a "BUMP THIS EACH AUGUST" comment.
- Loud error guard: if response shape is wrong or `errors` non-empty, return 500. The original silent-swallow pattern is exactly the failure mode we're locking against.
- Switched `today` computation from UTC to `Europe/London` via `Intl.DateTimeFormat` to stabilise the date across BST/GMT transitions.

After redeploy, manual curl returned `fixtures_seen: 1` — but `state_updates: 0`. The API call now worked; somewhere else was the next bug.

### 22.2 Match-watcher fix #2: stale `teams` table

**Symptom:** With `fixtures_seen: 1` we expected at least one row in `match_status_state`. Got zero. The function was silently `continue`ing past every fixture.

**Diagnosis approach:** Deployed a new `diagnose-matchday` edge function that returns: env-var presence, today's fixtures from API-Football, the next 7 days, the full 2025-26 PL roster from API-Football, the contents of our `teams` table, and a diff. The diff revealed it instantly:

```json
"pl_teams_missing_from_our_db": [
    {"id": 44, "name": "Burnley"},
    {"id": 63, "name": "Leeds"},
    {"id": 746, "name": "Sunderland"}
]
```

The `teams` table was seeded in migration 004 with the 2024-25 PL squad. Three teams have since been relegated (Ipswich, Leicester, Southampton) and three promoted (Burnley, Leeds, Sunderland). The watcher's `if (!homeTeamId || !awayTeamId) continue` guard short-circuited on every fixture involving a promoted team — including tonight's Spurs vs Leeds and the upcoming May 16-17 weekend.

**Fix (commit `9edc51f`, migration 018):** Insert the three promoted teams. Kept the relegated three for historical content_items backfill compatibility (Postgres FK on match_status_state and content_items both point at `teams(id)`).

After insert, the watcher immediately tracked Spurs-Leeds with `status=NS` and started firing every minute. Pipeline alive.

### 22.3 Content quality audit + Round-4 voice recipe

In parallel, ran a content quality audit on 25 recent routine items, identified 6 systematic patterns (talking-points formulaic, headlines as prompts, body verbosity, Cyrillic typos, verbose openings, repeated role tags). The user pushed back on most and approved a focused set of fixes. Then four rounds of iteration on 10 representative cards:

- **Round 1:** Establish the voice — action-first verbs, time markers, single dry payoffs.
- **Round 2:** Push for sharper images, more specific named anchors.
- **Round 3:** Different angles, fresh references.
- **Round 4:** Apply learnings, tighten to a 16-word girl-ref ceiling.

The user identified that I had been confusing fields (push title ≠ "girl ref" — that's `immersive_context`, the analogy paragraph). Voice rules locked: directionality matters, the football payoff pivots from the setup, anchors must be in HER world (no creative-industry roles), references must snap on first read, TPs respect what HE already knows.

**Committed (routines repo `bb51c26`):** PROMPT.md "BATTLE-TESTED VOICE RULES" section with 18 rules + ~60 SHIP / NEVER-SHIP canonical examples. New TP1 broadcast-question validator in `post_news.sh` (`Did you know` / `Did you see` reject pattern).

### 22.4 Emergency: legacy service_role JWT was in the public repo

A `/security-review` slash command on the branch surfaced one HIGH-confidence finding the routine audits had missed: migrations 015, 016, 017 each embedded the full legacy service_role JWT verbatim in a `cron.schedule` body, and the repo is publicly readable on GitHub. The JWT bypasses RLS, expires in 2090, and was committed on 2026-05-07 — a 4-day exposure window before discovery.

Migrated to the new Supabase API key model in a graceful, no-downtime sequence:

1. User created `sb_publishable_*` + `sb_secret_*` keys in dashboard.
2. User stored the new secret in Postgres Vault under name `cron_service_key` (one-off SQL editor).
3. Migration 019 dropped the three crons that embedded the JWT and re-created them reading from `vault.decrypted_secrets` by name.
4. Migration 020 added a SECURITY DEFINER accessor `get_cron_service_key()` because pg_cron's role couldn't read Vault directly — see Pitfall #38 below.
5. Edge functions: added a new `SERVICE_KEY` custom secret in Supabase. Updated `_shared/supabase-client.ts` (+ four direct readers) to prefer `SERVICE_KEY` with a fallback to the legacy `SUPABASE_SERVICE_ROLE_KEY` for the transition window.
6. iOS `Configuration.xcconfig` updated to `sb_publishable_*`.
7. Routines (`goaldigger-routines`) had `SUPABASE_SERVICE_KEY` env var updated in the Anthropic Routine dashboard for both `gd-news` and `gd-matchday`.
8. Deployed cron-called and inter-function-called edge functions with `--no-verify-jwt` — see Pitfall #37 below.
9. User disabled legacy `anon` + `service_role` keys via Settings → API Keys → Legacy tab.
10. User rotated the legacy JWT signing key: added a new ES256 standby in JWT Signing Keys, promoted it to current, then revoked the old HS256.

Post-rotation tests:
- Legacy JWT as `apikey: ...` → 401 "Legacy API keys are disabled" ✓
- Legacy JWT as `Authorization: Bearer ...` → 401 "No suitable key was found to decode the JWT" (cryptographic invalidation) ✓
- `sb_secret_*` → 200 ✓
- `sb_publishable_*` → 200 via PostgREST ✓
- Watcher continued ticking throughout ✓

**Compromise audit** (commit `b11497f`) over the 4-day window: 109 `content_items` all `pipeline_source=routine`, zero `device_tokens` (no users yet), zero `dev_alert_devices`, only one stale `client_errors` from May 4 (a self-test). No exploitation traces.

**Pre-commit hook** installed (`scripts/pre-commit-secret-scan.sh`, hooks-dir copy) blocking any future commit containing `eyJhbGciOi[A-Za-z0-9_-]{8,}` (JWT header) or `sb_secret_[A-Za-z0-9_-]{8,}`. Allows `sb_publishable_*` by design. Smoke-tested against legitimate and rogue payloads.

### 22.5 First end-to-end matchday auto-fire test

Real PL match: Tottenham vs Leeds, kickoff 19:00 UTC, May 11. The watcher tracked the fixture from `NS` → `1H` → `HT` → `2H` and detected `FT` at 21:08:03 UTC. Within the same tick:

- `fired_finished_at: 2026-05-11T21:08:03` populated on the fixture row.
- Routine fired for both teams via the Anthropic Routine API.
- Leeds matchday content_item landed at 21:11:49 (3 min 46 s after FT).
- Spurs matchday content_item landed at 21:13:19 (5 min 16 s after FT).

Both items passed the Round-4 voice tests:
- Spurs title: `spurs 1-1 leeds.\ntel put them ahead, then a penalty.\nstill 17th.` — three-line designed, score + scorer + league-position-context.
- Spurs push: *"Twenty minutes of huffing — Tel scored, Leeds got a penalty to level it. Spurs drew 1-1. He'll replay the call."* — locked-example title + new kicker.
- Spurs girl ref (post user feedback): *"Your situationship cancelling at the venue door. Spurs took the punch at 74'."* — gossip-zone anchor, specific timing.
- Spurs TP1: *"Tell him you thought Tel ran the show in the second half. He'll confirm or top it."* — Tell-him + named player + reaction prediction.

### 22.6 Two bugs caught in production output

**The slash bug (routines repo `18a8b28`):** When the Round-4 canonical examples landed in PROMPT.md, the title SHIP/NEVER-SHIP code blocks used `/` as chat-shorthand for a line break (e.g. `arsenal won. / chelsea trudged home.`). The routine read this literally and produced `immersive_headline` strings with visible " / " characters. Fix: rewrote the canonical examples to use JSON-encoded `\n` (`"arsenal won.\nchelsea trudged home."`) and added a "CRITICAL" preamble explicitly stating the format. Also patched the two existing affected items via direct PostgREST UPDATE.

**Team-page hallucination (routines repo `f8dbb87`):** When user clicked into Leeds in the simulator, the "His Team" page said *"2nd in the Championship, chasing promotion back to the Premier League."* Wrong — Leeds is in the 2025-26 PL. Root cause: `data-fetcher` (which reads from the `teams` table) had been picking up the new teams, but `fetch_news.sh` still had the 2024-25 hardcoded TEAMS array. With no fresh RSS data for Leeds in `raw_fetch_logs`, `team-page-generator`'s Claude call had nothing to ground on and fell back to its 2024-25 training-data view. Fix: updated `fetch_news.sh` and `MATCHDAY_PROMPT.md` to include the promoted teams; deleted the three bad team_pages rows; triggered `data-fetcher` to populate `raw_fetch_logs`; re-ran `team-page-generator` with mode=full for each team. Final result: all three now correctly show "X in the Premier League" with real form data, real recent results.

### 22.7 iOS roster cleanup

- `Team.swift` enum: added Leeds / Sunderland / Burnley; removed Ipswich / Leicester / Southampton.
- Swift 6 strict concurrency: `nonisolated static let cacheSchemaVersion: Int = 1` to satisfy the non-isolated `CachedContentItem` init reading a MainActor-isolated static. See Pitfall #39 below.

### 22.8 Known remaining issues (non-blocking)

- **THE MANAGER card shows `<UNKNOWN>`** for the three promoted teams in the regenerated team_pages. The team-page-generator correctly refuses to confabulate (lesson learned from the earlier McFarlane saga). Needs a real manager source — either API-Football's `/coachs?team=<id>&season=2025` endpoint, or a hand-curated `managers.json` (rejected once already for maintenance burden). Next task.
- **Player name spelling** — Leeds page surfaced "Brandan Aaronson" (real name: Brenden Aaronson). Specific names from Claude's training data drift one letter when not read verbatim from RSS source. Acceptable for v1; will tighten in the team-page-generator prompt to prefer API-Football squad data over freeform generation.

### 22.9 Where we are at end of day

Launch-critical pipeline fully alive:
- ✓ `match-watcher` polls API-Football every minute on the new auth path (Vault + SECURITY DEFINER + verify_jwt=false + sb_secret_*)
- ✓ `match_status_state` populates fixtures, tracks state transitions
- ✓ `gd-matchday` Routine fires on FT, produces correctly-voiced matchday items in 3-5 minutes
- ✓ Round-4 voice recipe verified in production (Spurs item is the proof)
- ✓ Public-repo JWT leak fully closed (rotation + revoke)
- ✓ Pre-commit hook prevents recurrence
- ✓ iOS team picker matches the 2025-26 PL roster
- ✓ All three promoted teams have correct, RSS-grounded "His Team" pages (modulo `<UNKNOWN>` manager)

**Files modified or added today (across two repos):**

Worktree (`FantasyLeague` / `claude/intelligent-thompson`):
- `backend/supabase/functions/match-watcher/index.ts` — SEASON const, error guard, London tz
- `backend/supabase/functions/_shared/supabase-client.ts` — SERVICE_KEY with legacy fallback
- `backend/supabase/functions/_shared/trigger.ts` — same fallback
- `backend/supabase/functions/matchday-scheduler/index.ts` — same fallback
- `backend/supabase/functions/notification-sender/index.ts` — same fallback
- `backend/supabase/functions/diagnose-matchday/index.ts` — new diagnostic endpoint
- `backend/supabase/migrations/018_add_2025_26_promoted_teams.sql` — Leeds/Sunderland/Burnley
- `backend/supabase/migrations/019_crons_use_vault_secret.sql` — first cron refactor
- `backend/supabase/migrations/020_vault_read_via_security_definer.sql` — SECURITY DEFINER accessor
- `ios/GoalDigger/Configuration.xcconfig` + `.example` — sb_publishable_*
- `ios/GoalDigger/Models/Team.swift` — 2025-26 PL roster
- `ios/GoalDigger/Services/CacheService.swift` — nonisolated static let
- `scripts/pre-commit-secret-scan.sh` + hook install

Routines (`goaldigger-routines` / `main`):
- `PROMPT.md` — Round-4 voice rules + canonical examples; slash bug fix
- `MATCHDAY_PROMPT.md` — updated team mapping list
- `fetch_news.sh` — added promoted teams to TEAMS array
- `post_news.sh` — TP1 broadcast-question validator

---

### 37. Edge Function gateway rejects `sb_secret_*` / `sb_publishable_*` as "Invalid JWT format"

**What happened:** After rotating from legacy `service_role` JWT to the new `sb_secret_*` model and routing it through Vault to cron, every cron tick returned HTTP 200 from `net.http_post` (request queued) but `pg_net._http_response` showed every response was `401 UNAUTHORIZED_INVALID_JWT_FORMAT`. The function gateway specifically expects a JWT-format Authorization header. The new sb_secret keys are not JWTs — they're a different format entirely. The gateway hadn't been updated for the new model.
**Rule:** Edge Functions called with the new `sb_secret_*` or `sb_publishable_*` keys need `verify_jwt = false` (or `--no-verify-jwt` at deploy time) so the gateway skips the JWT-format check. Functions then need to validate auth downstream themselves (via env var comparison, signed payload, etc). This applies to **every** function called by cron, every inter-function fetch, every iOS call. Public functions called by the iOS app are the exception — they can keep `verify_jwt = true` only if the iOS app continues sending a legacy JWT (which means the legacy key model has to stay alive). For our pre-launch state we set internal functions to `--no-verify-jwt` and kept the legacy anon JWT alive for iOS's single edge-function call (`delete-my-data`). Long-term, when Supabase updates the gateway to accept the new key format, we can re-enable verify_jwt on all of them.

### 38. pg_cron's role can't read `vault.decrypted_secrets` directly

**What happened:** Migration 019 wired cron job bodies to read the service-role key from `vault.decrypted_secrets` by name at fire time, so the secret value never appeared in committed SQL. Looked correct. After deploy, every cron tick returned `succeeded` from `cron.job_run_details` (because `net.http_post` queued the request successfully), but `pg_net._http_response` showed `401 UNAUTHORIZED_INVALID_JWT_FORMAT` — and the actual `Authorization` header sent by the cron's `net.http_post` was `Bearer ` (empty). The Vault read inside the cron body returned NULL because the role pg_cron runs as didn't have read access to that view. `'Bearer ' || NULL = NULL` in Postgres string concatenation, so the header degenerated to empty.
**Rule:** Vault read access is restricted by the platform. Wrap any Vault read needed by pg_cron in a `SECURITY DEFINER` Postgres function owned by a role that DOES have access. Lock down the function's `search_path` to `''` to prevent search-path injection. Grant EXECUTE only to specific roles, REVOKE PUBLIC. Single-purpose accessors (one function per named secret) are safer than a generic Vault-reader. See migration 020 for the pattern.

### 39. Swift 6 strict concurrency rejects non-isolated reads of `@MainActor static let`

**What happened:** Build failed on `Main actor-isolated static property 'cacheSchemaVersion' can not be referenced from a nonisolated context`. The constant was declared on a `@MainActor` class (CacheService) and read from a `CachedContentItem` initialiser that wasn't on the main actor. Under Swift 6 strict concurrency, this is a compile error (Swift 5 would have warned).
**Rule:** Static `let` constants that are read across actor boundaries should be marked `nonisolated`. The value is immutable, so there's no race; the keyword just tells the compiler "this can be read from any actor context." Apply to any constant declared inside a `@MainActor` type that needs to be read from background actors, non-isolated inits, Codable conformances, or SwiftData model contexts.

### 40. Multiple parallel team-list sources of truth

**What happened:** After adding Leeds / Sunderland / Burnley to the `teams` DB table, the iOS picker still didn't show them. Once iOS was fixed, the "His Team" page hallucinated for Leeds saying "2nd in the Championship". Investigation revealed at least five separate code paths each carried their own copy of the team list:
1. Supabase `teams` table (authoritative — updated via migration 018)
2. iOS `Team.swift` enum (Swift CaseIterable)
3. `backend/.../data-fetcher/index.ts` — reads from `teams` table at runtime (already correct)
4. `goaldigger-routines/fetch_news.sh` — hardcoded TEAMS array
5. `goaldigger-routines/MATCHDAY_PROMPT.md` — hardcoded mapping list

The mismatch produced a cascade: fetch_news.sh never fetched RSS for Leeds → `raw_fetch_logs` empty for Leeds → team-page-generator's Claude call had no source data → fell back to training data → produced 2024-25-Championship narrative.
**Rule:** Every system with a "list of N entities" that maps to user-facing functionality (PL teams, supported currencies, language list, etc) should have **one** runtime source of truth, and every consumer should read from it. Hardcoded arrays in scripts are technical debt — they look fine until a season transition exposes the cross-pipeline drift. The remediation order: identify every consumer of the list, update them to a single source, deprecate the hardcoded copies. For routines that can't query the DB at startup, generate the list from the DB at deploy time and commit the snapshot — with a "regenerate from DB" pre-commit hook to keep it fresh.

### 41. Chat shorthand bleeds into prompt examples bleeds into production output

**What happened:** During Round-4 voice iteration, I used `/` in chat as a readable line-break marker for multi-line immersive titles (`derby done. / arsenal beat chelsea.`). When the locked recipe landed in PROMPT.md, the canonical SHIP examples preserved that `/` shorthand. The routine read the literal slash and produced `immersive_headline` strings with visible " / " characters, which iOS rendered as visible slashes on the swipe card.
**Rule:** Prompt examples that show structured output must be encoded **exactly** as the model should reproduce them. For JSON string fields, write them as quoted JSON values with `\n` for newlines, not human-readable line breaks or visual separators. If chat shorthand is needed for human readability, translate it to the production format before committing to the prompt. Better: include both the "wrong" version and the "right" version side-by-side in the prompt as a deliberate teaching pair (we added the `/` bug pattern to the NEVER-SHIP list after this).

---

## Phase 23: V1.1 content surfaces shipped — A1 / C1 / C2 / C3 / C4 / C5 — COMPLETE (2026-05-12 → 2026-05-13)

The full V1.1 content stack landed in an extended session spanning ~24 hours: Season Primer (A1), Insider (C1), Sunday Brief (C2), Saturday Quiz (C3), Player Dossier (C4), and Match-day Live (C5). All six surfaces use the **canonical cloud-routine pattern** (Sonnet 4.6 via `claude.ai/code/routines`, post-script validators in `goaldigger-routines` repo, PostgREST upserts) — no direct Anthropic API calls anywhere. Plus a meaningful bug-fix punch list along the way and a Primer redesign after live UX review.

### 23.1 The canonical cloud-routine pattern, locked in

Five identical-shape feature stacks shipped in sequence (gd-insider, gd-sunday-brief, gd-live-brief, gd-player-dossier, gd-saturday-quiz). The pattern stabilised to a 5-layer template:

1. **Postgres migration** — table + RLS public-read + index.
2. **Routine prompt** (`*_PROMPT.md`) — sister-voice rules, source-trace requirement, anti-hallucination guard, output schema, ✓/✗ examples.
3. **Post script** (`post_*.sh`) — validators (length caps, banned-pattern reject, em-dash strip, Cyrillic check, broadcaster-question reject, ALL-CAPS check) then PostgREST INSERT/UPSERT with the cron service key.
4. **Routine registration** via `/schedule` skill — cron schedule + Sonnet 4.6 + sources pointing at `anton-tech43/goaldigger-routines`.
5. **iOS** — Codable model + Card view + APIClient method + `.pbxproj` registration + render gate.

By the third surface this was muscle memory. Each subsequent surface took roughly one focused session from green-field to shipped + voice-checked.

### 23.2 A1 Season Primer — built, then redesigned in the same day

Initial ship: phase-aware headline ("It's the run-in"), 2-sentence stat summary, sparkle key-fact pill, 3 "things to send him now" quotables, two CTAs ("Teach me more" + "Take me to the news"). All driven by `gd-season-state` routine writing `team_season_state` rows.

Sim smoke test surfaced the screen as **overwhelming for brand-new users**: six competing content blocks on first paint, body voice reading like a BBC match report, jargon ("run-in", "summit", "clean sheets") without context, premature copy-to-clipboard surface, two competing CTAs. The voice was exactly what her boyfriend already consumes — exactly NOT what orientation needs.

**Redesign (migration 028 + prompt rewrite + view rewrite):**
- Schema collapsed routine output to two strings: `state_line` (2-5 word personalised headline) + `feeling_line` (1-2 sentences on how HE will feel/act this week).
- Old `summary`/`key_fact`/`welcome_lines` columns made nullable; old rows keep data, new ones land sparse.
- View stripped to: one bold title + one body paragraph (wrapped in `GlossaryText` so jargon stays tappable) + the two CTAs. Lots of breathing room.
- Routine prompt fully rewritten with phase-keyed examples ("Arsenal are flying" / "Forest are scrapping" / "It's quiet at City"). Voice spot-check: all 20 teams produced sister-voice, anchored, emotional-translation content.

Lesson: smoke-testing in the simulator before declaring "done" is non-negotiable. The original spec passed Round-4 voice review and shipped clean; only sitting in front of the screen as a brand-new user revealed the problem.

### 23.3 C1 Insider — daily rotation through four types

`team_insider_items` table (migration 023) + `gd-insider` routine fires daily at 02:00 UTC. Type rotation is `(day-of-year mod 4)` → one of `stat | anecdote | history | oddity`, same type for all 20 teams on a given day. Each team rotates through all four types over a week.

The post-script length caps (title 20-80 chars, body 100-600) + banned-pattern set + ALL-CAPS reject set + broadcaster-question opener reject ("Did you know..." / "Did he..." pattern) became the canonical template for every subsequent routine's `post_*.sh`.

### 23.4 C2 Sunday Brief — first feed-item surface with tier-gated push

Weekly recap (migration 024 adds `'sunday_brief'` to `content_items.type` CHECK). `gd-sunday-brief` routine fires Sun 09:00 UTC. Notification-sender now filters by `min_tier_for_type` so T1 users never get the push, even if their device is registered. iOS feed renderer also filters via `applyTierFilter` so T1 users never see the brief in-app.

Known gap caught during simulator review: the routine emits factual `immersive_context` (no girl-reference analogy bridge). The gd-news pipeline runs every article through an analogy critic; the Sunday Brief routine bypasses that. Flagged for a v1.1.1 prompt update (add a sister-voice analogy field).

### 23.5 C3 Saturday Quiz — shipped, voice still in flux

Built end-to-end by a background sub-agent in an isolated worktree (first time the Agent tool's `isolation: "worktree"` flag carried real value — agent reset onto `origin/claude/intelligent-thompson` after detecting a stale base, then built cleanly). Cherry-picked into main thread.

`saturday_quiz_items` (migration 026) + `quiz-current` Edge Function (`--no-verify-jwt`) + `gd-saturday-quiz` routine (cron `0 7 * * 6` — Sat 07:00 UTC) + iOS `SaturdayQuizCard` rendered in feed. T3-gated.

**Output quality is the open question.** First two fires produced 24 quizzes in fixture-trivia shape (opponent / standings / recent score) — competent but generic, ignored the team-learning rotation we'd designed. The prompt was rewritten to enforce a 3-slot shape: Q1+Q2 team-learning (rotating through players / club basics / history / rivalry / upcoming game), Q3 conversation-setup ("If he says X, the smarter reply is:"). A strict Q3-shape validator was added.

Three subsequent fires produced **zero rows** — strongly suggesting either:
- (a) session queuing in the routine runtime (multiple `RemoteTrigger run` calls during one day stack up)
- (b) validator-rewrite loops where the LLM can't escape its fixture-trivia prior
- (c) silent session failures we have no visibility into

A `POST_QUIZ_BYPASS_ALL=1` diagnostic mode was added so a future fire could skip every validator and ship raw output for inspection. Still produced 0 rows in our session, which rules out validators and points at (a) or (c). The Saturday 2026-05-16 07:04 UTC scheduled fire is the next observable point — if it also produces 0 rows we need to inspect the cloud session log at `claude.ai/code/routines/trig_011wwfZyJaXPCF3gPbA3crFC` directly.

### 23.6 C4 Player Dossier — almost entirely already-built infrastructure

Migration 002 (from way back) created `player_cards` + the iOS `PlayerCard` Codable struct + `PlayerCardModal` view. `OnesToKnowCard` on the Team Page already wired player taps to `presentedPlayer = matchingCard`. Only the writer was missing.

`gd-player-dossier` routine fires weekly Sun 17:00 UTC, reads each team's `ones_to_know.players` list from `team_pages`, generates 3 dossiers per team (~60 rows/week). Output voice clean on first fire: 59/60 dossiers landed, sister-voice consistent.

Two iteration loops:
- **Diacritic-fold lookup** for player names: original code's lowercased `contains` matched "Saka" against "Bukayo Saka" but failed on "Ødegaard" (em-dash and "O" are different code points). Fix: `.folding(options: [.diacriticInsensitive, .caseInsensitive])` on both sides.
- **Tier-gate dropped**: original spec gated dossiers behind T3, but a sim test of the locked-state teaser ("Player dossiers are part of the Premium tier") read punitive for what's basically "who is this player". User overruled the gate — dossiers now visible to all tiers. `.locked` branch remains in `PlayerCardModal` as defensive code if we ever flip the gate back.

### 23.7 C5 Match-day Live — first time-sensitive surface

API-triggered routine (`gd-live-brief`, no cron — fired on demand by `match-watcher`). At HT or 75' of a live PL fixture involving a tracked team, match-watcher POSTs match context to the routine's webhook URL with a Bearer token. Routine generates one brief, INSERTs to `live_match_briefs`. iOS polls `live-brief-current` Edge Function every 60s during the live window (kickoff − 10min through kickoff + 130min), with `scenePhase` awareness so polling pauses when backgrounded.

`briefs_fired` JSONB column on `match_status_state` (migration 025) is the idempotency guard: each minute the cron sees the same fixture in the HT window, but we only fire the routine once per trigger label. Without this we'd fire ~15 routines per HT.

`LIVE_BRIEF_ROUTINE_URL` + `LIVE_BRIEF_ROUTINE_TOKEN` Supabase secrets had to be set manually via `supabase secrets set`. Match-watcher logs `live_brief_configured: false` and silently skips when these are missing — we hit that during sim testing and the user noticed via a missing Live card.

Goal-triggered briefs (the original V1.1 spec listed kickoff, 30', HT, 75', FT triggers) deferred to v1.1.1. A `mcp__ccd_session__spawn_task` chip exists for the goal-trigger work — match-watcher would need to poll `/fixtures/events`, track `last_event_id` per fixture, and fire on each new goal. T3-only gate proposed for that follow-up.

### 23.8 Bug fixes shipped alongside the features

The session caught and fixed a meaningful list of cross-cutting issues:

- **Glossary popover dark-on-dark unreadable** — replaced `.popover` (system bubble) with on-brand `.sheet` using `.presentationBackground(Color.deepMauve)`, rose accent bar, jakarta typography.
- **Share button placement** — moved from bottom-right (below tab bar) to top-right of zone 2 next to "Your move:" label.
- **team-page-generator standings filter** — `extractLeaguePosition` was indexing `standings.standings[0]` (always the league leader), so every team's "How they're doing" card said "1st in the Premier League". Fixed with explicit `api_football_id` filter.
- **live-brief endpoint hardened to LIVE-only** — added `.in("status", LIVE_STATUSES)` filter so a finished match (FT/AET/PEN) within the time window doesn't trigger the card.
- **Word-boundary truncation on Team Page cards** — `String.prefix(50)` cut mid-word ("Chelsea and Brentford, Fulham are sandwiched betwe"). Added `truncateAtWord` helper used by rivalry / season summary / post-match cards.
- **Rivalry card headline shows team names** — split on em/en/regular dash to extract just the rival names ("Chelsea and Brentford") instead of a truncated sentence.
- **`immersive_headline` per-line cap** — added 22-char-per-line validator + `POST_NEWS_FALLBACK=1` rescue mode that auto-truncates on second retry. Routine bumped from "reject + skip on second failure" to "reject + rewrite, then auto-truncate on second failure" so news isn't lost over formatting.
- **Quiz Q3 validator loosened** — accepts `If`/`When`/`Imagine`/`Picture` openers (was only `If`). Plus `POST_QUIZ_FALLBACK=1` rescue.
- **`delete-my-data` legacy JWT fix** — function was deployed before the legacy `service_role` key rotation, so it returned 401 to the new `sb_publishable_*` key. Redeployed with `--no-verify-jwt` (the function does its own apns_token-based auth, gateway JWT was redundant). Then patched iOS to swallow 404 ("nothing to delete") and 400 ("Invalid token format" — simulator has a 160-char extended-format token that fails the function's strict 64-char hex regex) as success.
- **`fetchTeamSeasonState` SELECT bug** — after the Season Primer redesign, the fetcher's explicit `select=` query parameter still enumerated only the legacy columns. PostgREST returned rows without `state_line`/`feeling_line`, Swift decoded them as nil, view fell through to skip-to-feed. One-line fix to add the new columns to the SELECT.

### 23.9 Working pattern: foreground + background-agent parallelism

C3 Saturday Quiz was built by a background `general-purpose` agent in a `worktree`-isolated environment while C4 Player Dossier was built in the foreground. The agent reported back twice — once when it hit a stale-base issue (refused to proceed without permission to `git reset --hard`), once when it shipped. The committed C3 branch was cherry-picked clean into `claude/intelligent-thompson` with no iOS file conflicts (`.pbxproj` UUIDs were fresh, `APIClient.swift` additions were in different sections, `FeedView.swift` additions were in different lines).

Lesson: parallel agent work is productive when the agent's task touches disjoint files. The pre-flight conflict prediction in the prompt ("anticipated merge conflicts: .pbxproj, APIClient, FeedView") set the right expectations and the actual merge was painless.

### 23.10 Where we are at end of day

Six new content surfaces in production:
- ✓ A1 Season Primer — one-beat redesign, sister-voice across all 20 teams, 2 CTAs.
- ✓ C1 Insider — daily 02:00 UTC, four-type rotation.
- ✓ C2 Sunday Brief — weekly Sun 09:00 UTC, T2+ push-gated.
- ⚠️ C3 Saturday Quiz — shipped, awaiting first clean Saturday fire on the new prompt.
- ✓ C4 Player Dossier — weekly Sun 17:00 UTC, all tiers, 59/60 dossiers populated.
- ✓ C5 Match-day Live — HT + 75' triggers wired, secrets set, awaiting first real match.

**Files modified / added today (across two repos):**

`FantasyLeague` worktree (`claude/intelligent-thompson`):
- 6 new migrations: 023 (team_insider_items), 024 (sunday_brief type), 025 (live_match_briefs + briefs_fired), 026 (saturday_quiz_items), 027 — skipped (player_cards already had RLS), 028 (state_line + feeling_line + nullable legacy).
- 4 new Edge Functions: `live-brief-current`, `quiz-current`, `gd-player-dossier` is a routine not a function, plus `team-page-generator` got the standings-filter fix.
- 8 new iOS files: `TeamSeasonState.swift`, `InsiderItem.swift`, `LiveMatchBrief.swift`, `SaturdayQuiz.swift`, `SeasonPrimerView.swift`, `InsiderCard.swift`, `LiveMatchCard.swift`, `SaturdayQuizCard.swift`, `PlayerDossierSheet.swift` (later collapsed into existing `PlayerCardModal`).
- 7+ iOS files modified: `APIClient.swift`, `FeedView.swift`, `TeamPageView.swift`, `PlayerCardView.swift`, `AppState.swift`, `GoalDiggerApp.swift`, `Models/ContentItem.swift`, `Models/TierGating.swift`, `Design/Components/GlossaryText.swift`, `Design/Components/ImmersiveCard.swift`.

`goaldigger-routines` repo:
- 5 new routine prompts: `INSIDER_PROMPT.md`, `SUNDAY_BRIEF_PROMPT.md`, `LIVE_BRIEF_PROMPT.md`, `PLAYER_DOSSIER_PROMPT.md`, `QUIZ_PROMPT.md`.
- 5 new post scripts: `post_insider.sh`, `post_live_brief.sh`, `post_player_dossier.sh`, `post_quiz.sh` (Sunday Brief reuses `post_news.sh`).
- `SEASON_STATE_PROMPT.md` + `post_season_state.sh` rewritten end-to-end for the one-beat redesign.
- `PROMPT.md` + `post_news.sh` patched for the immersive-headline 22-char cap.

**Pending follow-ups:**
- C3 Saturday Quiz: investigate why bypass-mode fire produced 0 rows. Saturday 2026-05-16 07:04 UTC is the next observable point.
- C5 goal-triggered briefs (T3): spawn-task chip queued.
- C2 Sunday Brief: add girl-reference analogy field to the prompt (currently emits factual `immersive_context`).
- Sweep other Edge Functions for the same `--no-verify-jwt` issue that hit `delete-my-data`.

---

### 42. Migrations are additive — but the read path may not know it

**What happened:** Migration 028 added `state_line` + `feeling_line` columns to `team_season_state`. Routine populated all 20 rows cleanly. iOS view's gate `if let stateLine = state.stateLine` evaluated to false on every team. Skip-to-feed fired. User saw no Primer.
Root cause: `APIClient.fetchTeamSeasonState(teamId:)` had an explicit `select=team_id,phase,summary,key_fact,welcome_lines,next_fixture` query parameter. PostgREST honoured the SELECT, returned rows WITHOUT the new columns, Swift decoded them as `nil` (the model declared them optional for backward compat).
**Rule:** When a schema adds columns AND the read path uses explicit `select=` enumeration, both sides have to be updated. The "additive only" property of the migration creates a false sense of security — the migration is safe but the system is broken. Audit checklist when adding columns: (1) routine post script emits them, (2) every PostgREST consumer's `select=` includes them, (3) every iOS/Swift model decodes them, (4) every view that depends on them gates correctly when nil.

### 43. iOS extended device-token format breaks strict regex

**What happened:** `delete-my-data` Edge Function's regex was `/^[a-fA-F0-9]{64}$/` — the historic APNs device-token format. iOS-17+ simulators store a 160-char hex token in UserDefaults. Function rejected with HTTP 400 "Invalid token format" before any DB lookup. User saw "Couldn't reach the server" generic error.
**Rule:** Strict format regexes on iOS device tokens should accommodate the wider range Apple now ships (64 → 200 chars hex), OR the iOS client should treat "format-rejected by server" as semantically equivalent to "not in the DB anyway". We chose the latter — narrower scope, doesn't weaken the production regex check, and preserves the right end-state ("her data isn't on the server"). The 400 swallow is keyed on the exact error body string ("Invalid token format") so unrelated 400s (missing field, malformed JSON) still surface.

### 44. SwiftUI `.sheet(item:)` needs Identifiable, and team-scoping must be in the id

**What happened:** `PlayerCard.id = playerName` worked when only one team was on screen. After ungating dossiers across tiers + always-tappable rows, switching from Arsenal to a hypothetical second team with a "Smith" player on both would reuse the sheet without refreshing. SwiftUI sees same `id`, treats as same item.
**Rule:** Any model used with `.sheet(item:)` whose values can co-exist across collections needs a composite ID that includes every dimension of uniqueness. For player data: `id = "\(teamId)_\(playerName)"`. This was a latent bug we caught preemptively while reviewing the sheet wiring; it would have shipped silently and surfaced only once a user happened to switch teams mid-tap.

### 45. Diacritic-aware name matching is required for non-Anglo squads

**What happened:** Player Dossier routine emitted "Martin Ødegaard" (diacritic from training data). OnesToKnow card stored the curated short name "Odegaard". iOS lookup used lowercased `String.contains` — `"odegaard"` is not a substring of `"martin ødegaard"` because Ø and O are different code points. Result: Ødegaard's dossier exists in the DB but the modal shows "lands Sunday evening" empty state because the lookup misses.
**Rule:** Any user-facing name match that crosses data sources (LLM training data ↔ curated short name ↔ API-Football full name) needs `.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)` on BOTH sides of the comparison. The bug class is invisible to QA done with Anglo-only player names — only surfaces on Norwegian / Spanish / Portuguese / Turkish squads.

### 46. Validator-rewrite loops can starve a routine to zero output

**What happened:** Quiz routine + strict Q3-shape validator ("must start with 'If '"). LLM kept generating fixture-trivia Q3 ("What was the score?"). Validator rejected. LLM rewrote once. Validator rejected again (LLM defaulted back to fixture-trivia). Routine prompt's flow said "Reject → rewrite once, then skip the team." Result: every team skipped, 0 rows for three consecutive fires.
**Rule:** When a validator enforces something against a strong model prior, the reject-rewrite-once loop will produce zero output, not just degraded output. Two mitigations: (a) loosen the validator to a broader accept-set the model can naturally hit (we accepted `If/When/Imagine/Picture` instead of just `If`); (b) add a fallback mode (`POST_*_FALLBACK=1`) that ships the article anyway on second failure with the bad field flagged for review. Voice-rule violations (fan slang, em-dash, broadcaster question) still hard-reject — those are real semantic errors the LLM should rewrite. Mechanical-shape failures (length, format) should fallback to mechanical-fix instead of dropping the whole article.

### 47. Multi-block onboarding cards fail at "brand-new user" smoke test

**What happened:** A1 Season Primer shipped with six competing content blocks: phase headline, 2-sentence stat summary, sparkle key-fact, 3 quotables under "THREE THINGS TO SEND HIM NOW", and two CTAs. Each block tested clean in isolation. The aggregate read like a BBC bulletin to a brand-new user who knew nothing about football. The whole purpose of the surface — to give her an emotional anchor about his team — was buried under stats and quotables she had no context to use.
**Rule:** Orientation surfaces (first-launch primers, empty-state intros, post-onboarding welcomes) take ONE action and carry ONE message. Stats / quotables / share affordances belong on surfaces she returns to after she has context. The smoke test for an orientation surface is: "If I'd never used this app before and didn't know what football was, would I understand why I'm here?" The redesign collapsed Primer to (one bold state line + one body sentence + a CTA), with the actual data — fixtures, standings, player lists — discoverable on the Team Page that follows.

### 49. PostgREST `Prefer: resolution=merge-duplicates` needs SELECT permission

**What happened:** First TestFlight install on launch night. iOS app onboarded, granted push, but no row landed in `device_tokens`. The `try?` swallow in `NotificationService.handleTokenRegistration` hid the underlying 401. Direct curl reproduced: plain `INSERT` returned 201 ✓, INSERT with `Prefer: resolution=merge-duplicates` returned 401 with PostgreSQL error 42501 ("new row violates row-level security policy"). Confused us because the policy was `FOR INSERT TO public WITH CHECK (true)` — should always pass.

**Root cause:** PostgREST's merge-duplicates translates to `INSERT ... ON CONFLICT (apns_token) DO UPDATE SET ...`. PostgreSQL's ON CONFLICT path requires SELECT permission on the row to detect the conflict — even with `return=minimal` on the response. The `device_tokens` table only had INSERT + UPDATE policies for anon; no SELECT policy. So the internal conflict check 42501'd before either INSERT or UPDATE was evaluated.

**Rule:** Any table that iOS upserts via `Prefer: resolution=merge-duplicates` needs an anon SELECT policy alongside the INSERT/UPDATE policies. If you don't want to expose the table to anon reads, move the upsert behind a SECURITY DEFINER Edge Function instead. Migration 030 added `device_tokens_anon_select` as the launch-night fix; the proper long-term shape is a `register-device` Edge Function that bypasses RLS via service_role.

### 48. pg_cron "succeeded" hides downstream HTTP failures

**What happened:** Man City vs Crystal Palace (PL, 2026-05-13 19:00 UTC) finished FT around 21:00 UTC, but no matchday content_items landed for either team. Investigation showed `match_status_state` was frozen at one row (Spurs-Leeds from May 11 22:59 UTC) — three days of silence despite `cron.job_run_details` reporting every minute's run as `status="succeeded"`. Smoking gun: pg_cron's success status only reports whether the `SELECT net.http_post(...)` SQL executed, NOT the HTTP response from the function. The cron's hardcoded legacy service_role JWT (from migration 017) was disabled at 2026-05-11T20:58:36 UTC — same minute the table froze. Every subsequent tick POSTed with a dead bearer token, got 401 at the Supabase gateway, and the function was never reached. Migration 020 (Vault-based auth via SECURITY DEFINER `get_cron_service_key()`) was written but only applied to prod days later, so the cron stayed silent for ~72h while looking healthy in `cron.job_run_details`.
**Rule:** When debugging "cron isn't running" symptoms, `cron.job_run_details` is necessary but not sufficient. Always cross-check `net._http_response` (the actual function reply, with status codes + body) and the downstream effect (rows written, content delivered). Build a SECURITY DEFINER diagnostics RPC (we now have `get_pipeline_diagnostics()` via migration 029) that surfaces all three layers in one call: cron command bodies (so you can see whether the auth header path is Vault-based or has a stale literal JWT), recent run details, and recent HTTP responses. Recovery requires (a) deploying the Vault-based migration, (b) re-firing the watcher with a `?date=YYYY-MM-DD` replay override for any matches that fell through the dead window. Match-watcher now accepts `?date=` for exactly this kind of recovery.

---

## Phase 24: Onboarding V1.2 — value-first restructure (2026-05-15)

The V1.0/V1.1 onboarding was transactional: name, name, team, tier, notifications, done. The user landed on the feed without ever feeling the app's value. Persona-driven smoke test (Emma, 28, dating an Arsenal fan, doesn't follow football) flagged this hard — she'd quit within 30 seconds because she'd been asked four things and given nothing back.

V1.2 reorganises onboarding around three new value-cards inserted *after* the mechanics, and bundles the two system permissions (notifications + calendar) into one "permissions moment" rather than scattering them.

### 24.1 New flow order

```
1.  Welcome
2.  Her name
3.  His name
4.  Team pick
5.  Notifications        ← moved up — asked while emotion is highest ("his team!")
6.  Meet team            ← NEW — star player + result mood + table verdict
7.  How it works         ← NEW — 3 scenario cards (Sunday morning / Match day / Saturday pub)
8.  Tier select          ← moved later — framed by the scenarios above
9.  Calendar opt-in      ← NEW — one-tap fixture sync via existing CalendarSyncService
10. (SeasonPrimer)       ← shipped in V1.1, KILLED in V1.3 after Anton flagged redundancy
```

Welcome (step 0) was re-enabled — V1.0/V1.1 had skipped it via a temp `step: .herName` constant.

### 24.2 New view files

- `Views/Onboarding/MeetTeamView.swift` — three-row card: star player (top_players[0] with photo + name + position + one_liner), last result mood (mapped from `post_match.state`: "They won. {hisName} was happy" / "They lost. Don't bring it up tomorrow" / "They drew. {hisName}'s feelings are complicated"), table verdict (mapped from `form.league_position`: "Top of the league chase" / "Pushing for Europe" / "Mid-table, quietly fine" / "In a relegation fight. {hisName} is stressed"). Reads from `team_pages.cards`; caches via existing `TeamPageCache.save()` so the TeamPage tab opens instantly later.

- `Views/Onboarding/HowItWorksView.swift` — three vertically stacked scenario cards. Static copy, personalised via `[his name]` placeholders. No fetch.

- `Views/Onboarding/CalendarOptInView.swift` — fixture sync. Three-tier fallback for fixture source: (1) `team_season_state.next_fixtures` (array, V1.2 backend), (2) `team_season_state.next_fixture` (singular legacy), (3) `team_pages.cards.next_fixture` (singular ISO string — the same source the Settings calendar toggle uses). Picks whichever has data. Permission flow uses the existing `CalendarSyncService` (built in V1.1 for the Settings toggle, never exposed in onboarding until now). When the user grants permission, syncs all fixtures into a "GoalDigger - Arsenal" calendar.

### 24.3 Model + service plumbing

- `Models/ContentItem.swift` — `TopPlayer.photoURL: String?` (Codable key `photo_url`).
- `Models/TeamSeasonState.swift` — `nextFixtures: [NextFixture]?` plus a `fixturesForSync` accessor that returns the array if present, else wraps the singular `nextFixture` in a one-item array, else empty. Single source of truth callers can use without branching.
- `Services/APIClient.swift:fetchTeamSeasonState` — added `next_fixtures` to the explicit SELECT (the Pitfall #42 audit rule).
- `Views/Onboarding/NotificationPromptView.swift` — removed in-line `registerToken` call. In the V1.1 order, this step was last; in V1.2 it's step 5 *before* tier select, so registering here would always POST with the default tier=2. Registration deferred to `OnboardingFlow.completeOnboarding()`.
- `Services/NotificationService.swift:handleTokenRegistration` — gated on `AppState.shared.hasCompletedOnboarding`. iOS may deliver the APNs token any time between the notification grant (step 5) and onboarding completion (step 9). Without this guard the auto-register fires with default tier=2 and creates a stale row that `completeOnboarding` then has to overwrite. Token is still persisted to UserDefaults during the gap so `completeOnboarding` can pick it up.
- `App/AppDelegate.swift:didFinishLaunchingWithOptions` — launch-time retry hook. If `apnsToken` exists in UserDefaults but `apnsTokenRegistered` flag is false (meaning the V1.1 path POSTed but the server returned an error), re-call `UIApplication.shared.registerForRemoteNotifications()` so iOS re-delivers the token and the registration pipeline runs again.

### 24.4 Backend support (migrations + Edge Functions)

- **Migration 031** — `team_season_state.next_fixtures JSONB`. Adds the array column for V1.2's calendar opt-in.
- **`backend/supabase/functions/team-page-generator/index.ts`** — schema gains `top_players[*].photo_url` + `manager_photo_url`. System prompt instructs Claude to pull these from API-Football's squad and coachs data. Squad slice limit bumped from 2000→6000 chars so 20-player rosters fit including their photo URLs (was truncating past player 8-9). Backticks in prompt strings escaped (the `` `photo_url` `` literal in markdown-style instructions broke the template literal — replaced with plain-text references).
- **`backend/supabase/functions/team-season-state-generator/index.ts`** — `buildNextFixturesArray()` helper parses raw API-Football fixtures response into the `next_fixtures` JSONB shape. Filters to a `COMPETITIVE_LEAGUE_IDS` allowlist (39 PL, 2 UCL, 3 UEL, 848 UECL, 45 FA Cup, 48 EFL Cup, 143 Community Shield) to drop pre-season friendlies that API-Football's `?next=10` happily returns mid-May for the next season. WC league IDs added in V2.0 (see Phase 26).
- **`backend/supabase/functions/data-fetcher/index.ts`** — `?next=5` → `?next=10` so the season-state generator has enough fixtures to build a meaningful calendar slate.

### 24.5 Persona-driven design notes

The "Meet team" card's mood-line approach was driven by a deliberate writing rule: show ONE star player not three, frame results as feelings not scorelines, give table position a verdict not a number. The persona check was "would Emma, who doesn't know football, find this useful?" — three players would overwhelm; "2nd, 47 points" would mean nothing. "Top of the league chase" is the kind of phrase she could repeat back to her partner.

How-it-works follows the same rule: scenarios instead of feature names. "Sunday morning, before his Sunday League: a 30-second brief" not "Daily Brief Push Notifications". The product feature lives inside a moment she can imagine.

---

## Phase 25: Onboarding V1.3 — team crests + Meet-team fix + SeasonPrimer kill (2026-05-15 PM → 2026-05-16)

Three things landed between V1.2 going to TestFlight and the WC pivot.

### 25.1 Team crests across three surfaces

Pre-V1.3, `TeamSelectionView` referenced `Image(team.badgeImageName)` — a local asset like `"arsenal_badge"`. No such assets ever existed in the bundle, so the picker rendered blank circles. V1.3 wires up the API-Football team-crest CDN (`https://media.api-sports.io/football/teams/{api_football_id}.png`).

- `Models/Team.swift` — added `apiFootballId: Int` mapping (values verified against the live `teams` table) and `crestURL: URL?` computed property.
- `Design/Components/TeamCrestView.swift` — new reusable component. `AsyncImage` with a soft-blush circle fallback containing a shield SF Symbol. Takes `team: Team` and `size: CGFloat`.
- `Views/Onboarding/TeamSelectionView.swift` — replaced the broken `Image(team.badgeImageName)` with `TeamCrestView(team: team, size: 32)`.
- `Views/Onboarding/MeetTeamView.swift` and `MeetManagerView.swift` — added a 44pt crest to each header next to "Meet his lot" / "Meet the boss".

### 25.2 Meet-team three-row guarantee

V1.2's MeetTeamView dropped to two rows for any team without a fresh `post_match` card (i.e., any team that wasn't immediately post-fixture). For Arsenal — currently top of the table with no recent post-match in the DB — the screen rendered Saka + table verdict only, while the header still said "Three things about Arsenal". Lie.

Fix: rename `lastResultLine` to `middleRowLine`, fall back to `form.form_summary` (a personalised one-sentence "they're on a run / wobbling lately" line written by the routine, present whenever the form card exists). Header text now always matches what's on screen.

Also hardened the `expiresAt` parser — was using a single `ISO8601DateFormatter` with `.withInternetDateTime` only, which silently failed on fractional-second timestamps (`"2026-04-13T15:00:00.000Z"`). Parse failure caused the if-let guard to fall through, rendering expired post-match rows. Switched to a dual-formatter pattern matching `APIClient.decoder`'s strategy. Parse failure now treats the row as expired (drops it) — safer than showing a stale "they won!" line.

### 25.3 SeasonPrimer killed

User flagged that the post-onboarding SeasonPrimer ("Arsenal are flying. Top of the league with two games to go.") was restating what MeetTeam already showed ("Top of the league chase"). Pure redundancy.

Fix: `OnboardingFlow.completeOnboarding()` now sets `appState.hasSeenSeasonPrimer = true` so `RootView` skips straight to `MainTabView`. The `SeasonPrimerView` file remains wired for the rare V1.1-upgrade edge case (user with `hasCompletedOnboarding=true` but `hasSeenSeasonPrimer=false` from before this build). For all V1.3-onboarded users, the flow ends at HowItWorks → feed.

### 25.4 Manager photos + bulk regen

`team-page-generator` schema got `manager_photo_url` (from API-Football's `/coachs` endpoint, where each coach has a `photo` field). System prompt instructs Claude to populate it. `MeetManagerView` now renders the photo via AsyncImage with a `person.fill` SF Symbol fallback.

Bulk regen of all 20 PL teams completed in parallel batches of 5 (each Edge Function invocation processes one team in ~15-20s; the previous 60-second cap was hitting around team 13 of 20 when running them all in one call). Resulting state for Arsenal: Saka photo loads, Arteta photo loads, three-row Meet team renders cleanly.

---

## Phase 26: World Cup 2026 prep — schema + data + iOS model (2026-05-16, IN PROGRESS)

Marketing pivots to the World Cup (June 11 – July 19, 2026) in early June. The inbound user wave will be **WC-curious people who don't follow the Premier League at all**. V1.0-1.3 onboarding asks "which PL club does he support?" — a non-starter for that audience.

V2.0 re-anchors the app around the World Cup as the primary onboarding context, with Premier League optional. The infrastructure (routines, content cards, calendar sync, push) generalises from "PL team" to "team-where-team-is-either-a-club-or-a-country." Existing PL users keep working; new WC users get a flow that doesn't assume PL knowledge.

**Hard deadline: June 11, 2026.**

### 26.1 Architecture — polymorphic teams table

The cleanest implementation makes `teams` polymorphic via two new columns. PL clubs and WC countries live in the same table, share the same downstream pipelines (content_items, device_tokens, raw_fetch_logs, match_status_state). One set of code paths, two sets of data.

**Migration 032** (`032_wc_entity_type.sql`):
```sql
ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS entity_type TEXT NOT NULL DEFAULT 'club'
    CHECK (entity_type IN ('club', 'country')),
  ADD COLUMN IF NOT EXISTS league_id INTEGER;
UPDATE teams SET league_id = 39 WHERE entity_type = 'club';
INSERT INTO teams (id, display_name, short_name, api_football_id, entity_type, league_id) VALUES
  ('belgium','Belgium','Belgium',1,'country',1),
  ('france','France','France',2,'country',1),
  -- ... 46 more rows
ON CONFLICT (id) DO NOTHING;
```

Post-apply: 23 clubs (entity_type='club', league_id=39) + 48 countries (entity_type='country', league_id=1) coexisting. `content_items.team_id`, `device_tokens.team_id`, etc. all just store strings and don't care whether the entity is a club or a country — so no FK or downstream-table changes were required.

WC 2026 = API-Football `league_id=1`, `season=2026`. Verified via `/leagues?search=world%20cup`. 48 qualified teams pulled from `/teams?league=1&season=2026`. The qualifier list will be finalised after the March 2026 intercontinental play-offs; the migration uses `ON CONFLICT DO NOTHING` so any UPDATE to fix a misqualifier would need to be a separate migration (don't DELETE — content_items may reference the row, and history should survive).

### 26.2 Edge Function parameterisation

The hardcoded `PL_LEAGUE_ID = 39, SEASON = 2025` constants in three functions had to go. Verdict from initial audit: **HARD** — multiple functions tightly coupled to PL-only assumptions.

**`backend/supabase/functions/_shared/types.ts`** — `Team` interface gains optional `entity_type` + `league_id` fields. Existing PL code reads them with `?? 'club'` / `?? 39` defaults so back-compat is preserved.

**`backend/supabase/functions/data-fetcher/index.ts`**:
- `seasonForLeague(leagueId: number): number` helper maps 39→2025, 1→2026, else current UTC year as fallback.
- `/standings?league=X&season=Y` builds league + season from `team.league_id` instead of literal `39` / `2025`.
- `/injuries?team=X&season=Y` same.
- `computeTeamContext` gated to clubs only. PL-specific concepts (title_race, cl_spot, relegation) don't apply to WC group stage (4 teams per group, different shape). team-season-state-generator handles country group standings instead.
- Function now accepts optional `{team_id: "..."}` payload to fan out per-team. Without payload it iterates all teams in one call. With payload it processes just that one team. Useful for parallelising the bulk fetch when the Edge Function 60-second CPU cap stops the all-in-one path partway through (it stopped at 28 of 48 countries on first run).

**`backend/supabase/functions/team-page-generator/index.ts`**:
- System prompt rewritten from "Premier League team" → "football team" with a `{{league_context}}` template variable.
- `leagueContext` injected per team:
  - For clubs: "Premier League (2025-26 season). PHASE MAPPING: ..."
  - For countries: "FIFA World Cup 2026 — a national team competing at the tournament hosted by USA/Canada/Mexico from June 11 to July 19, 2026. ... For league_position_label use 'Xst in Group Y' format (look at the Standings data for the group letter and the team's position within that group)."
- `league_position_label` schema description updated to cover both shapes.
- `updateDynamicFields` (the dynamic-only fast path used by data-fetcher) gated to clubs only. WC standings are 12 groups of 4 with a completely different concept of "position"; countries always go through the Claude full path which handles group stage semantics.

**`backend/supabase/functions/team-season-state-generator/index.ts`**:
- Same `{{league_context}}` pattern. PHASE MAPPING per league: PL uses calendar-based (Aug-Mar mid_season, Apr-May run_in, etc.). WC uses tournament-relative (before kickoff → pre_season, group + knockouts → run_in, eliminated mid-tournament → off_season, post-final → post_season). The existing `phase` CHECK constraint enum (pre_season / mid_season / run_in / off_season / post_season) is preserved — WC just maps onto it semantically rather than expanding the enum.
- `COMPETITIVE_LEAGUE_IDS` set expanded from PL+UCL+UEL+UECL+FA+EFL+CommunityShield to also include WC `league_id=1` plus regional WC qualifiers (29-37). Without this addition, `buildNextFixturesArray` filtered out every country's WC fixtures and the iOS Calendar opt-in would have hit empty-state for all 48.

### 26.3 Data fan-out (47 of 48 countries fully populated)

Bulk fetch + bulk regen of 48 countries:

- **`data-fetcher`** — first all-in-one run completed 20 of 48 countries before hitting the 60-second cap. Backfilled 28 missing via parallel single-team curls (6 batches of 5, ~3-10s each). All 48 now have complete API-Football data: squad, fixtures_next, fixtures_last, standings, transfers, coachs, injuries.

- **`team-page-generator` full mode** — 48 countries regenerated in 10 batches of 5 parallel calls. ~12-22s per team. Verification SQL shows all 48 with: manager + manager photo, 3 top_players + 3 photos, group_position_label. Most read "1st in Group X" / "2nd in Group X" — three teams (England, Japan, USA) all landed on "1st in Group C" because API-Football's pre-tournament group standings have everyone tied at rank=1, so Claude picks alphabetically. Will self-correct once games start populating positions.

- **`team-season-state-generator`** — same 10-batch-of-5 pattern. All 48 countries in `team_season_state`, phase='pre_season' (correct for May 16, 2026). 45 of 48 have next_fixtures arrays populated (avg 2.8 fixtures per country). The 3 holdouts — Jordan, Paraguay, Qatar — have zero upcoming WC fixtures listed in API-Football's database yet (group stage assignments not finalised). Daily cron will pick them up automatically as API-Football publishes the schedule. The iOS Calendar opt-in already handles "no fixtures known" via its "Got it" empty-state button.

### 26.4 iOS model layer

- **`Models/Country.swift`** (new) — `enum Country: String, CaseIterable, Identifiable, Codable` with 48 cases. Properties parallel to `Team`: `displayName`, `shortName`, `apiFootballId` (matches the value in the Supabase `teams.api_football_id` column), `crestURL` (same CDN as Team), `searchableText` (with common alternate spellings like "United States America" for USA, "Korea Republic" for South Korea, "Holland Dutch" for Netherlands).

- **`Models/FeedContext.swift`** — added `case country(Country)` alongside `.team(Team)` and `.everyoneTalking`. The pre-existing comment `// Future: .nation(Nation) for World Cup mode` is now reality. `storageKey`, `displayName`, `dropdownLabel`, `iconName` all extended with the new case.

- **`Models/AppState.swift`** — `selectedCountry: Country?` with UserDefaults persistence (`selectedCountry` key). Both `selectedTeam` and `selectedCountry` can be set simultaneously for users who follow both. `clearAllData()` includes the new key.

- **Exhaustive switch fixes** — adding `.country` to FeedContext surfaced two compile errors (ContextSwitcherView lines 88+106) and five errors in FeedView (lines 51, 252, 547, 585, 676). Each one was a switch over `appState.activeContext` that needed the new case. Strategy: where the country path should behave identically to team (feed loading, pagination, unread badge), use `case .team, .country:` shorthand; where country needs its own rendering (icon row), add an explicit `.country(let country)` case that renders via `TeamCrestView(team:)` or its country equivalent. `FeedView.loadMore` got a new `loadMoreEntity(teamId:)` helper to dedupe the .team/.country branches. **Build green** after all switches updated.

### 26.5 Local Postgres access (no more "paste SQL into the chat")

Mid-Phase 26 the user (rightly) flagged that I'd been pasting the legacy service_role JWT inline in curl commands, exposing it in chat scrollback. Going-forward fix: source the key from `backend/.env` via `$(grep '^SUPABASE_SERVICE_ROLE_KEY=' backend/.env | cut -d= -f2)` so the value never appears in tool calls or stdout.

For DB read access (instead of pasting SQL output): added `SUPABASE_DB_URL` to `backend/.env`. The user pasted the Session-pooler URI from Supabase Dashboard → Database settings; the password is on local disk only, gitignored. `psql` (installed via `brew install libpq`) reads the URL from env, runs queries directly. The chat no longer needs to round-trip SQL output. Pattern for all future DB queries:
```bash
psql "$(grep '^SUPABASE_DB_URL=' backend/.env | cut -d= -f2-)" -c "SELECT ..."
```

### 26.6 Where Phase 26 stands

**Done:**
- ✓ Migration 032 (schema + 48 country seeds)
- ✓ data-fetcher parameterised + 48 countries fetched
- ✓ team-page-generator country-aware + 48 country pages with manager + 3 players (all with photos)
- ✓ team-season-state-generator country-aware + 45/48 country season-states with fixtures (3 awaiting API-Football schedule data)
- ✓ iOS Country enum + FeedContext.country + AppState.selectedCountry
- ✓ All exhaustive switches updated, **build green**
- ✓ Local `psql` connection set up for direct DB access

**In progress (Week 2 of 4):**
- `CountrySelectionView` (mirror of TeamSelectionView with confederation grouping)
- `OptionalPLTeamView` ("does he follow a PL team too?" with Skip button)
- `OnboardingFlow.swift` reorder — new step order: Welcome → Her → His → **Country** → (Optional) PL Team → Tier → Notif → Calendar → Meet country → Meet country manager → How it works
- `MeetTeamView` + `MeetManagerView` entity-agnostic — accept either a club ID or country ID via a single `teamId: String` parameter (the `team_pages` table holds both)

**Coming (Weeks 3-4):**
- `match-watcher` + `matchday-scheduler` parameterisation (drop hardcoded `PL_LEAGUE_ID = 39`)
- Cloud routine prompts updated to be league-aware (`gd-news`, `gd-matchday`, `gd-saturday-quiz`, `gd-sunday-brief`, `gd-season-state`) — country variants for WC content
- Existing-user WC migration prompt (one-time "World Cup is coming, who's he backing?" sheet for users already through PL onboarding)
- TestFlight beta + App Store submission **by June 4** (7-day Apple review buffer before June 11 tournament kickoff)

---

### 50. Edge Function CPU cap stops bulk multi-team loops partway through

**What happened:** First run of `data-fetcher` with no team_id payload iterated 71 teams (23 clubs + 48 countries) × 7 endpoints = ~500 outbound HTTP calls. Function returned HTTP 200 after ~60s. Investigation showed only 20-ish countries had `raw_fetch_logs` rows. Same pattern repeated with `team-season-state-generator` — first batch run completed 13 of 23 teams before the CPU cap hit and the function returned a 546 `WORKER_RESOURCE_LIMIT`.

**Rule:** Supabase Edge Functions have a 60-second wall-clock + CPU budget that's fine for 20-team PL loops but not for 70+ teams or multi-Claude-call sequences. Two mitigations: (a) make the function accept an optional `team_id` filter so callers can fan out per-team, (b) drive the fan-out from outside via parallel curls (batches of 5 work well — each invocation gets its own budget). For routines that internally call Claude per team, the per-team approach is necessary regardless of team count; sequential Claude calls within one function invocation can easily exceed 60s for 4+ teams.

### 51. Adding an enum case forces exhaustive-switch audits across the whole codebase

**What happened:** Added `case country(Country)` to `FeedContext`. Build failed in two files I expected (ContextSwitcherView) and three more I didn't (FeedView at five separate lines: displayItems, pillIcon, refresh, loadMore, plus a related switch). The compiler caught every one of them, but only because I'd been disciplined about exhaustive switches (no `default:` branches) throughout the FeedContext consumers.

**Rule:** Lean into exhaustive switches when designing enums that may grow. The compile failures are free design audits — every switch the compiler flags is a place a future enum case needs an explicit decision (does country behave like team here? Or differently?). The opposite anti-pattern is sprinkling `default:` branches "to be safe" — those branches silently absorb the new case with whatever the default was, often the wrong behaviour, and the bug only surfaces in runtime testing. The 5-error V2.0 build was a 10-minute fix; the equivalent search-and-fix without compile errors would have been an afternoon.

### 52. Polymorphic entity tables coexist if the FK is `TEXT` not enum

**What happened:** V2.0 needed PL clubs and WC countries to share the same downstream tables (content_items, device_tokens, raw_fetch_logs, match_status_state, team_pages, team_season_state). All of these reference `team_id TEXT REFERENCES teams(id)`. Adding `entity_type` to teams and seeding 48 country rows was a 1-migration change. No FK alterations. No content-table migrations. No iOS model changes outside FeedContext + AppState.

**Rule:** When designing FK references for entity types you might polymorphically extend later, use `TEXT REFERENCES entity(id)` rather than constrained-string columns or compile-time enums. PostgreSQL doesn't care whether the referenced row is a "club" or a "country" as long as the ID matches. iOS doesn't either — `String` IDs flow through API signatures unchanged. The polymorphism lives in one column (`entity_type`) on the parent table, gated by application logic in the Edge Functions that actually need to branch ("if entity_type = 'country' use the WC standings parser"). The downstream pipelines stay unaware.

---

## Phase 26 (continued) — V2.0 World Cup iOS + Backend closeout (2026-05-17)

After the May 16 backend foundation (schema, data, country pages), the remaining V2.0 iOS work landed in a single autonomous push on May 17.

### 26.7 iOS onboarding views built

- **`CountrySelectionView`** — 48 countries grouped by FIFA confederation (UEFA, CONMEBOL, CONCACAF, AFC, CAF, OFC). Search collapses sections to a flat alphabetical list. Crests via `TeamCrestView(country:size:)` (new init overload) against `media.api-sports.io/football/teams/{id}.png`.
- **`OptionalPLTeamView`** — Premier League team picker with explicit "Skip, World Cup only" secondary button. Reuses the team-picker layout pattern from `TeamSelectionView` but with the dual-button footer.
- **`WCMigrationSheetView`** — modal sheet for V1.x users on app launch after V2.0 update. Embeds `CountrySelectionView` with a "Maybe later" skip option. Triggered when `hasCompletedOnboarding=true && selectedCountry==nil && !hasSeenWCPrompt`. Once dismissed (pick or skip), `hasSeenWCPrompt=true` is persisted so it never reappears.

### 26.8 Entity-agnostic info cards

`MeetTeamView` and `MeetManagerView` were rewritten to accept an explicit `entityId: String` init parameter instead of reading `appState.selectedTeam` directly. Caller (`OnboardingFlow`) computes `meetEntityId = selectedCountry?.rawValue ?? selectedTeam?.rawValue ?? "arsenal"` and passes it through. The views look up `Team(rawValue:)` first, then `Country(rawValue:)`, then fall back to the generic shield icon — clean, no AppState coupling.

### 26.9 OnboardingFlow V2.0 step order

```
0.  Welcome
1.  Her name
2.  His name
3.  Country selection      ← primary entity (WC 2026 national team)
4.  Optional PL team       ← skippable
5.  Tier selection
6.  Notification ask
7.  Calendar opt-in
8.  Meet team              ← entityId = country (preferred) or team
9.  Meet the boss
10. How it works
```

11 steps total. The progress dots component renders correctly (verified via the welcome screenshot — dot 1 of 11 highlighted).

### 26.10 Match-watcher + matchday-scheduler parameterisation

Dropped `PL_LEAGUE_ID = 39, SEASON = 2025` constants. Both functions now:
1. Query `SELECT DISTINCT league_id FROM teams WHERE league_id IS NOT NULL` at request time.
2. Iterate each active league, calling `seasonForLeague(leagueId)` from `_shared/league-helpers.ts`.
3. Combine fixtures from all leagues into a single processing loop.
4. Return `active_leagues` in the response payload for diagnostics.

Smoke test on May 17: `match-watcher` returned `active_leagues: [39, 1]`, `fixtures_seen: 6` (all PL — WC fixtures don't exist until June 11). `matchday-scheduler` returned `scheduled: 6`. Zero errors.

Debugging note: first deploy had `f.league?.id` referencing an undefined `f` (loop variable was `fx`). The fix shipped with a top-level try/catch + stack trace returner so the next "Internal Server Error" surfaces the actual exception. **Rule for future Edge Functions: wrap the serve handler in try/catch and return the message + stack. Saves an hour of "what does the function actually do".**

### 26.11 Device token country routing

- Migration 033 (`device_tokens.country_id TEXT REFERENCES teams(id)` + `team_id` made nullable + partial index for non-null country_id).
- `APIClient.registerToken(_:teamId:countryId:tier:)` — both entity IDs are optional, body only includes the keys that are set (so a country-only re-registration doesn't blank out a previously-set team_id via merge-duplicates upsert).
- `NotificationService.handleTokenRegistration` reads both from `AppState.shared` and passes whichever are non-nil.
- `OnboardingFlow.completeOnboarding()` does the canonical first registration with both IDs after the user finishes the flow.

### 26.12 V2.0 closeout — what's done vs what remains

**Done (this repo):**
- All schema migrations (032, 033)
- All Edge Function parameterisation
- All iOS code paths
- All bulk data population (48 country team pages + season states)
- Build green, V2.0 welcome screen visually verified

**Handed off to Anton (separate concerns):**
- Cloud Routine prompt updates (in `goaldigger-routines` repo) — spec'd in `WC_ROUTINES_HANDOFF.md`
- App Store submission — manual Xcode flow, target June 4
- Marketing assets / App Store screenshots
- Final visual walkthrough verification on simulator (accessibility automation blocked from autonomous runs)

### 26.13 Lessons learned in V2.0 push

#### 53. Edge Functions need a top-level try/catch with stack-trace return

**What happened:** First match-watcher V2.0 deploy threw a `ReferenceError: f is not defined` deep in the upsert loop. The default Supabase Edge Function error response was "Internal Server Error" — body. No clue where the error was. Spent 10 minutes adding diagnostic logging when the same minutes could've been a one-line fix.

**Rule:** Every Edge Function's `serve(async (req) => { ... })` should wrap the body in `try { return await handleRequest(req); } catch (e) { return new Response(JSON.stringify({error, message, stack: e.stack})); }`. Production-safe (only fires on actual exceptions, doesn't leak sensitive data unless secrets appear in stack traces — they don't in our codebase). Saves debugging time.

#### 54. Bulk team operations need per-team fan-out on the caller side

**What happened (already noted in lesson #50 but now confirmed across THREE functions):** data-fetcher, team-page-generator, and team-season-state-generator ALL hit 60s CPU cap when iterating 70+ teams in a single invocation. The pattern that works: add a `team_id?: string` payload filter to each function so callers can fan out via parallel curls (batches of 5 work).

**Rule:** Any Edge Function that iterates over a large entity set (teams, content_items, etc.) should accept a per-entity payload from day one. Cheap to add (one query filter), saves you the fan-out refactor when you hit the cap.

#### 55. Polymorphic enums in iOS need explicit init overloads, not protocol witnesses

**What happened:** `TeamCrestView` started as `init(team: Team, size:)`. When `Country` came along, I added `init(country: Country, size:)` and `init(url: URL?, size:)` overloads rather than abstracting via a `CrestSource` protocol. The protocol approach would have unified the entry points but added an extra layer of type machinery for two trivial accessors (`team.crestURL` and `country.crestURL` are both `URL?`).

**Rule:** When you have 2-3 concrete sources for the same view, prefer init overloads over abstraction. Three init methods is shorter than one protocol + two conformances + an init. Reserve the protocol approach for N≥4 sources or for cases where the source set is open (third-party plugins).

---

## Phase 27: Push pipeline dead since May 11, V2.0 cluster B + Migration 034 (2026-05-17)

Two distinct streams shipped in this phase.

### 27.1 Cluster B iOS fixes (final V2.0 closeout)

Five issues raised in the V2.0 skeptical review landed:
- **H2** — `activeContext` now switches to `.country(country)` immediately when the user picks a country in `WCMigrationSheetView`. Mirror priority in `scenePhase` resume handler (country preferred over team).
- **H3** — Sheet binding's `set` closure now flips `hasSeenWCPrompt = true` on system-initiated dismiss, so swipe-down + force-quit + relaunch doesn't loop the sheet.
- **H4** — `UnreadTracker.totalUnread` and `aggregateBadgeText` extended with `countryItems` + `selectedCountry` params. Symmetric to the team-side branches. FeedView caller passes `countryItems: []` for V2.0 (single active-context items list) — V2.1 will split.
- **L1** — `MainTabView` `navigationDestination(for: String.self)` for `"playerCards"` now uses `teamPageEntityId` (country-first) so WC-only users land on a valid view.
- **L2** — `OnboardingFlow.meetEntityId` gains `assertionFailure` in DEBUG when neither country nor team is set; production keeps the `"arsenal"` fallback.

### 27.2 Migration 034 — `teams.league_id NOT NULL`

After application-layer guards landed in data-fetcher (V2.0 M2) and match-watcher (V2.0 M1) — both skip-and-log when a row's `league_id` is null — the DB-level constraint was free to add. Pre-check confirmed zero null rows. Schema is now `league_id INTEGER NOT NULL` with no FK (we deliberately don't have a `leagues` table; the IDs match API-Football's external numbering).

### 27.3 Push pipeline was completely dead since May 11

User reported "City played today, no push notification" on May 17. Investigation traced the entire pipeline and surfaced the real failure: **every push cron tick since May 11 was returning HTTP 401 from the Supabase gateway** — but `cron.job_run_details` reported `status="succeeded"` because the SQL `SELECT net.http_post(...)` completed cleanly. Phase 48 documented this exact pattern; this is the second occurrence.

Root cause: the Vault entry `cron_service_key` contained the new `sb_secret_*` format key (41 chars, prefix `sb_secret_`). The Supabase Edge Function gateway requires a JWT-format Bearer token for invocation. The legacy service_role JWT (which is still valid for Edge Function invocation despite being rotated out of PostgREST) IS in our `backend/.env` as `SUPABASE_SERVICE_ROLE_KEY`. Direct curl with that key returned 200 all day; the cron failed because it pulled the wrong format key from Vault.

Fix: `vault.update_secret(uuid, legacy_jwt, name, comment)` to put the legacy JWT back. Within one minute (next match-watcher cron tick at minute mark), HTTP responses flipped from 401 → 200. Manual notification-sender invocation processed the 20-item 24h backlog. `push-probe` to the user's production device returned `success: true, status: 200`.

The May 12 → May 17 backlog (items >24h old) intentionally NOT pushed — the sweep's `published_at > NOW() - INTERVAL '24h'` filter is correct (don't push 5-day-old news).

### 27.4 Discovered gap: FA Cup Final missed match-watcher entirely

The user's expected push was for the Chelsea vs Man City FA Cup Final on May 16. We had it in `raw_fetch_logs` (via `fixtures_next`), but match_status_state has no row for it. Why: match-watcher's V2.0 refactor reads `SELECT DISTINCT league_id FROM teams`. That returns `[39, 1]` (PL + WC). FA Cup is league=45 — not in the active_leagues set. So match-watcher never queries API-Football for FA Cup fixtures, never observes a status transition, never fires gd-matchday.

This is a **pre-V2.0 architectural limitation** (V1.x match-watcher hardcoded `league=39` so FA Cup matches were missed too). V2.0 made it visible by widening to WC but not other competitions. iOS-side news routine still produced great content_items for the match because gd-news scrapes BBC, but matchday-style cards + push-on-FT only fire via match-watcher.

V2.1 candidate: extend match-watcher's active_leagues to include FA Cup (45), EFL Cup (48), UCL (2), UEL (3) for the limited subset of PL teams that play in them. Currently flagged in `team-season-state-generator.COMPETITIVE_LEAGUE_IDS` for the calendar slate but not in match-watcher's live-fire path.

---

### 56. pg_cron "succeeded" twice — when the wrong key shape is in Vault

**What happened:** Same silent-cron-failure class as Phase 48. Cron reports `status=succeeded` because the SQL succeeded. Net._http_response shows 401 UNAUTHORIZED_INVALID_JWT_FORMAT because Vault contained a non-JWT-shape key (the new `sb_secret_*` format). The gateway specifically checks for JWT shape.

**Rule:** Watch the actual `net._http_response` rows, not just `cron.job_run_details`. For any cron that calls an Edge Function, the success criterion is `status_code = 200 AND content does not contain "UNAUTHORIZED"`. Build that into the heartbeat check — `goaldigger-cron-heartbeat-check` cron should verify recent 2xx responses, not just that cron ran.

### 57. Key rotation across two consumer types needs explicit dual-storage

**What happened:** Supabase has two key formats: legacy `service_role` JWT (still works for Edge Function invocation, disabled for PostgREST data writes) and new `sb_secret_*` (works for both). Edge Function INTERNAL code uses `SUPABASE_SERVICE_ROLE_KEY` env (which is the new format). Edge Function INVOCATION (the Bearer the caller sends) needs JWT format because the gateway is strict.

If you rotate one and not the other, you silently break the cron-driven half of the pipeline. **Two separate Vault entries** would be cleaner: `bearer_token_for_edge_functions` and `service_role_for_postgrest_writes`. Today they share `cron_service_key` and the wrong format silently broke pushes for 6 days.

### 58. Match-watcher league coverage is bounded by `teams.league_id`

**What happened:** Match-watcher's V2.0 refactor pulls active leagues from the `teams` table. Clubs in our table have `league_id=39` (PL), countries have `league_id=1` (WC). So FA Cup, UCL, UEL fixtures for PL teams aren't observed — they happen, content_items get written by news routines, but no matchday cards / push-on-FT fires.

**Rule:** Match-watcher's competition coverage is a separate concern from the team-membership table. Either: (a) maintain a `leagues` config table with `is_live_watched` boolean, or (b) hardcode a superset of competitive leagues that any of our teams could appear in. The current "DISTINCT league_id from teams" pattern under-covers cup matches.

---

## Phase 28: JWT auth audit + monitoring hardening (2026-05-17, post-V2.0)

Same-day follow-up to Phase 27.3 (push pipeline dead for 6 days due to wrong-shape Vault key). The May 17 outage was the **second** silent cron failure in 6 days (Phase 48 was the first — legacy JWT rotated and crons had stale inline bearers). Pattern is clear: cron auth is fragile, monitoring doesn't catch it, push pipeline silently dies.

This phase shipped the codebase-wide audit + monitoring fixes so we never lose 6 days to this again.

### 28.1 Inventory of every JWT/auth surface

Recon found:
- **Three historical migrations with inline JWTs**: `015_fix_cron_settings.sql`, `016_notification_sweep_cron.sql`, `017_match_watcher_every_minute.sql`. Dead in prod (overwritten by migrations 019 + 020 which moved to Vault) but live in the migration history. Annotated with a callout block at the top explaining they're historical and that future crons should use `get_cron_service_key()`.
- **One live cron still using inline JWT**: `goaldigger-daily-pipeline` (data-fetcher daily). Migration 035 rewrote it to use Vault.
- **Diagnostic gap**: `get_pipeline_diagnostics()` returned cron job bodies + cron run details + Vault secret existence, but NOT `net._http_response` rows. The 401 was visible there for 6 days; nobody looked because the existing diagnostics didn't surface it.
- **Heartbeat blind spot**: `check_pipeline_heartbeat()` only checked `pipeline_health.stage='fetch'` rows. data-fetcher was on its own inline-JWT cron and DID write rows, so the heartbeat stayed silent while push-related crons 401'd.

### 28.2 What landed

**Documentation (Stream A):**
- `IOS_GOTCHAS.md` #14 — new pitfall entry covering "Supabase has two service-role formats. Gateway INVOCATION requires JWT shape." Has the symptom + 5-line psql diagnosis + fix snippet.
- `RUNBOOK.md` — new SOP "Push pipeline health check (user says no push)" with 6-step traversal (cron gateway → match-watcher → content_items → sender → APNs → iOS). Each step has a fail-action.

**Migrations (Stream B):**
- `035_data_fetcher_cron_vault.sql` — unschedule + reschedule `goaldigger-daily-pipeline` with Vault auth. Live; verified `command NOT LIKE '%Bearer eyJ%'`.
- `036_diagnostics_rpc_http_responses.sql` — extends `get_pipeline_diagnostics()` with three new fields: `recent_http_responses` (last 20 rows from `net._http_response`), `http_health_summary_24h` (count by status_code), `key_shape_check` (prefix + length + `is_jwt_shape` bool). One RPC call surfaces the silent-failure pattern. Live; verified all three fields present and `is_jwt_shape=true`.
- `037_heartbeat_http_health_check.sql` — extends `check_pipeline_heartbeat()` with a CHECK 2 block: if >50% of `net._http_response` rows in the last hour are non-200 (with at least 10 samples), insert into `client_errors` + push alert. Chicken-egg: the alert push uses the same Vault key it's trying to detect — so if the key is broken the push will fail too. The `client_errors` insert is the durable trail (still recorded even when push fails). Live; manual `SELECT check_pipeline_heartbeat()` returned cleanly.

**Tooling (Stream B):**
- `scripts/verify-cron-auth.sh` — runnable check that confirms Vault entry exists, accessor function exists, key starts with `eyJ` and length > 100, and recent `net._http_response` rows show no non-200s. Designed to run after any Vault update. Exit 0 = healthy.

**Annotations:**
- Migrations 015, 016, 017 — header comment block calling them out as historical artifacts. No functional change. Just signals to future agents reading the migration history.

### 28.3 What couldn't be solved with monitoring alone

The chicken-and-egg in check 2: when the Vault key breaks, the alert push that should fire on detection ALSO uses the same Vault key. So the push 401s alongside everything else. The user wouldn't get an in-app alert.

Mitigation in this phase: the `INSERT INTO client_errors` happens BEFORE the push attempt. The durable database trail exists even when the push doesn't fire. Anyone manually running `diagnose-matchday` or `get_pipeline_diagnostics()` post-incident will immediately see both the http_health_summary spike AND the client_errors row.

V2.1+ candidate: a second alert path that doesn't depend on the same Vault key (e.g., direct PostgREST-table polled by iOS app, or a webhook to a third-party service like Slack). Out of scope tonight.

### 28.4 What success looks like next time

Future scenario: someone rotates the Vault key to the wrong format again. Within 60 minutes:
1. `notification-sweep` cron tick 401s.
2. By minute 30 (heartbeat tick), `check_pipeline_heartbeat()` notices the 401 spike via Check 2, inserts a `client_errors` row, attempts the alert push (probably fails — chicken-egg).
3. Anyone running `diagnose-matchday` sees `key_shape_check.is_jwt_shape: false` AND `http_health_summary_24h: {401: N}` in one response.
4. The `verify-cron-auth.sh` script can be run by anyone with `backend/.env` access — passes/fails in <2 seconds.
5. Lesson: monitoring catches it within minutes, not days.

---

### 59. Two-layer monitoring: pg_cron success ≠ HTTP success

**What happened (twice in 6 days):** pg_cron's `status='succeeded'` means the SQL `SELECT net.http_post(...)` ran without error. It says nothing about whether the HTTP request reached the function or got rejected at the gateway. May 11-14 (Phase 48): hardcoded JWT in cron was rotated out, 401s, silent. May 11-17 (Phase 27.3): Vault held wrong-shape key, 401s, silent for 6 days.

**Rule:** Any monitoring that watches cron health MUST cross-check `net._http_response`. The existence of a cron run details row tells you the SQL ran; the existence of a 200 response tells you the function got called. Both are necessary. Build this into diagnostic RPCs (migration 036) and heartbeat functions (migration 037).

### 60. Alert paths can have the same root cause as the failure they're alerting on

**What happened:** May 17's heartbeat check has its own push-via-Edge-Function alert path. Both paths use `get_cron_service_key()` from Vault. If the Vault key breaks, the heartbeat detects the problem but its alert push also 401s. No notification reaches the user.

**Rule:** When designing alert mechanisms, identify single points of failure that would also disable the alert. Either (a) provide a secondary alert path that doesn't share the failure mode (e.g., direct table polling by client, third-party webhook), or (b) accept that the database-only trail is the fallback and design diagnostics to make it discoverable post-incident. Migration 037 chose (b) — the `client_errors` row is the durable trail. V2.1 candidate: add (a).

### 61. Migration history vs live state

**What happened:** Migrations 015, 016, 017 had inline JWTs. Migration 019 + 020 rewrote them to use Vault. In prod, the final state after all migrations apply is correct. But `supabase db reset` replays in order, so the intermediate states (with inline JWTs) briefly exist. More importantly: the migration files are what future agents READ to understand the system. They saw the inline-JWT pattern in the history, didn't realize it was deprecated, and applied it for new crons.

**Rule:** Annotate any migration whose code pattern is no longer the recommended approach. A header callout naming the superseding migration + linking to the relevant gotcha entry is cheap. Future agents read top-down and won't miss it.

### 62. Five "silent push failures" weren't the same class

**What happened (May 17 2026 audit):** User reported "5 instances of silent push failures over the last few weeks." Each prior fix targeted a different specific bug:

1. **Phase 48** — Legacy JWT disabled, inline-JWT crons started 401-ing
2. **Phase 27.3** — Vault `cron_service_key` held wrong-shape (sb_secret_*) key, gateway 401-ed every tick
3. **Phase 28 hardening** — preemptive: 4 migrations + verify-cron-auth.sh + heartbeat CHECK 2 to catch future shape regressions
4. **today's HT brief confusion** — turned out the live brief landed correctly in `live_match_briefs`; the missing push was by design (live briefs are browse-only — see IOS_GOTCHAS #16)
5. **the ACTUAL missing pushes today** — anti-spam gap-check compared each item against itself (see IOS_GOTCHAS #15)

I (and the prior agents) kept pattern-matching: "another silent push failure ≈ another instance of the silent-cron-failure class." Built increasingly elaborate observability for the cron→Edge Function hop (Phase 28). But the ACTUAL cause today was downstream of all of that — `notification-sender`'s anti-spam check, which has nothing to do with cron auth.

**Rule:** When investigating "no push arrived," don't assume the failure mode is the same as the last incident. Always trace the full path: pg_cron → Edge Function → routine API → routine session → content_items insert → notification-sender → APNs. Each hop has its own failure modes. The symptom (no push) is identical across all of them; the cause is not.

**Specific anti-pattern caught here:** anti-spam was logging `"Anti-spam blocked for tier N: <reason>"` to `console.log` (Edge Function stderr — not in the DB) AND writing `"All tiers blocked by anti-spam rules"` to `pipeline_health` WITHOUT preserving the reason. The aggregated log surface erased the specific failure mode. **Rule for future logging:** always preserve the specific reason, not just the high-level outcome. If the high-level outcome is "blocked," the reason field is doing 80% of the work.
