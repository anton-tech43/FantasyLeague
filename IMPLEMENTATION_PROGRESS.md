# GoalDigger iOS — Product Brief Implementation Progress

Tracking implementation of the updated product brief (April 2026).
Each phase is marked with its status and a summary of changes made.

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
