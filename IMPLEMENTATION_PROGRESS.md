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

### 63. Routine quota economics — schedule for the busy day, not the average day

**What happened (May 17 2026):** Phase J observability (just-shipped pipeline_health rows on every match-watcher fire attempt) immediately surfaced 4 matchday_fire failures with HTTP 429 from the Anthropic routine API. Initial hypothesis: per-second rate limiting on concurrent fires. Actual cause from claude.ai/code/routines UI: **"25/25 included remote daily runs used"**. The project hit the daily routine-run quota.

The math we'd been ignoring:

Routine fires consumed today (Saturday):
- gd-season-state (03:00 daily): 1
- gd-insider (04:00 daily): 1
- gd-news (00:30 06:30 12:30 18:30 daily): 4
- gd-news-wc (00:35 06:35 12:35 18:35 daily): 4
- gd-saturday-quiz (Sat 09:00): 1
- iclttm-pipeline (22:02 daily, different project): 1
- Match-driven (6 PL matches today × 4 live-brief fires + 2 matchday fires): up to 36

Total demand on a 6-match Saturday: ~48. Quota: 25.

The scheduled cron routines were sized for an "average day" but PL Saturdays have 4-8 matches. We never modeled the match-day surge. The matchday fires for 4 PL clubs (Crystal Palace, Brentford, Leeds, Brighton) silently 429'd this afternoon — users got no FT push.

**Fix shipped 2026-05-17:**

*Tier 1 — weekday-only routines:* `gd-insider` cron `0 2 * * *` → `0 2 * * 1-5`; `gd-season-state` cron `0 1 * * *` → `0 1 * * 1-5`. These are background/curiosity content that doesn't need weekend coverage when match content dominates. Saves 2 runs each weekend day.

*Tier 2 — reduce news cadence:* `gd-news` cron `30 6,12,18,0 * * *` → `30 6,18 * * *` (4×/day → 2×/day, morning + evening). Same for `gd-news-wc`. Saves 4 runs per day across both, every day. Less news cadence but the gd-matchday FT push covers the weekend marquee content.

*Tier 3 — drop 75' live-brief trigger:* match-watcher only fires `live_brief` at HT now. The 75' trigger fired 2 × 2 perspectives = 4 routine runs per match for marginal UX value. HT brief is the high-leverage in-match moment; 75' was redundant for most users. Cuts live_brief fires from 4/match to 2/match.

**Future-state quota fit (typical 4-match PL Saturday):**

- Scheduled (after Tier 1+2 cuts): 0 (insider+season-state) + 2 (gd-news+gd-news-wc once daily fires) + 1 (gd-saturday-quiz) = 3
- Match-driven (after Tier 3 cut): 4 matches × (2 HT live-brief + 2 matchday) = 16
- Total: 19/25 → fits comfortably

**Rules:**
1. **Model the busy day, not the average.** Routine quotas are a daily cap; schedule for your peak match-day load, not your typical Tuesday.
2. **Weekend-content vs. weekday-content.** If a routine produces background data (insider snippets, state primers), it doesn't need to compete with match-day fires. Move it to weekdays.
3. **Per-perspective fires double everything.** If your routine fires once per (home, away) pair, you're using 2× the slots per match. Consider whether the "away perspective" is actually different content or if one shared output works.
4. **Phase J observability paid off within 5 minutes of deploy.** Before this work, the 429s would have been invisible. Always instrument every pipeline hop with a durable DB row — `console.error` is a black hole.

### 64. The morning-after Phase J playbook (and CHECK 5 was overdue)

**Context:** Phase J P.1–P.5 plus P.4 (routines repo) shipped May 17 evening. Live verification against prod that same night caught three things:

- ✅ P.2 (match-watcher) emits `pipeline_health` rows on every fire — 288 failure rows in 71 min during tonight's 429 storm proved the instrumentation works.
- ✅ P.3 (notification-sender per-attempt `apns_send`) was deployed but waiting for a fresh push to validate (all today's matchday content_items were created before the deploy, so nothing pushed afterward).
- 🔴 **Migration 038 silently dropped `safety_review` from the stage CHECK.** content-reviewer/index.ts:257 has been writing rows that fail the CHECK since 038 went out. The surrounding try/catch swallowed the error so no one noticed. Fixed by migration 040 (drop+re-add CHECK with safety_review preserved). Cost: ~6 hours of degraded observability for the safety-review hop.
- 🔴 **match-watcher retries matchday_fire every minute indefinitely** when the fire returns non-2xx. `fired_finished_at` only gets set on success, so on a 429 it stays NULL and the next tick fires again. Tonight: 4 stuck fixtures × 4 fires/min × 30+ min = 288 wasted API calls. CHECK 4 misses this case (it only fires when `fired_finished_at` IS set), which is why CHECK 5 was added in migration 041.
- 🟡 P.4 (routine post-scripts in goaldigger-routines) validation deferred to tomorrow ~06:35 UTC after the first scheduled `gd-news` fire. No quota-allowed fire today.

**Lesson:** "Shipped" ≠ "verified in production." Always allocate a verification window the SAME day as deploy, not the next morning. Tonight's verification caught the safety_review bug within 30 minutes of `/simplify` running on the diff.

**Tomorrow's verification SQL (paste-ready):**

```sql
-- 06:35 UTC — first P.4 evidence after gd-news at 06:30
SELECT team_id, status, http_status, target, error_class,
       to_char(created_at AT TIME ZONE 'Europe/Stockholm','HH24:MI') AS local_t
FROM pipeline_health
WHERE stage = 'routine_post'
  AND created_at > NOW() - INTERVAL '15 minutes'
ORDER BY created_at DESC;
-- Expected: ~20 success rows (one per PL team).

-- 07:00 UTC — what fired overnight?
SELECT error_type, message,
       to_char(created_at AT TIME ZONE 'Europe/Stockholm','HH24:MI') AS local_t
FROM client_errors
WHERE created_at > NOW() - INTERVAL '12 hours'
ORDER BY created_at DESC;
-- Expected: tonight's persistent_fire_failure row should still be there
-- (one row, throttled). Any matchday_silent_failure rows aged out the
-- moment fired_finished_at fell outside the 1h window.

-- After lunch — every-stage coverage check
SELECT stage, status, COUNT(*) AS rows,
       MIN(to_char(created_at AT TIME ZONE 'Europe/Stockholm','MM-DD HH24:MI')) AS first,
       MAX(to_char(created_at AT TIME ZONE 'Europe/Stockholm','MM-DD HH24:MI')) AS last
FROM pipeline_health
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY stage, status
ORDER BY stage, status;
-- Expected (in some order): rows for fetch, generate, review, safety_review,
-- live_brief_fire, matchday_fire, routine_post, apns_send, publish. Every
-- stage that ran in the last day should be visible.

-- Manual heartbeat smoke test
SELECT check_pipeline_heartbeat();
-- Should return void. Then re-query client_errors for new rows.
```

**Escalation rules:**

| Symptom | Likely cause | Next step |
|---|---|---|
| `routine_post` rows zero at 06:35 UTC | Routine cron disabled, or 06:30 fire didn't complete | Check claude.ai/code/routines for last run status |
| `routine_post` rows < ~20 | Some routine sessions crashed without reaching post script | Open the routine session log in claude.ai UI |
| `apns_send` rows show 410 spike | Stale tokens in `device_tokens` | Run sweep manually; check `is_active=false` count |
| `persistent_fire_failure` still firing | match-watcher retry loop is still hot | Investigate: quota reset? Enable Extra Usage. |
| `matchday_silent_failure` only | Fire succeeded, routine session crashed | Open routine session log |
| `safety_review` stage rows zero in last 24h | content-reviewer never ran, OR the 038 fix didn't apply | Verify CHECK constraint via `pg_get_constraintdef` |

**V2.1 candidates filed from tonight:**
- **Match-watcher retry-loop fix.** Track attempt count + give up after N attempts or T minutes since FT. Today's behavior wastes API calls and pollutes pipeline_health.
- **pipeline_health retention sweep.** At ~5 rows/min baseline, this table grows ~2.6M rows/year. Add a `DELETE FROM pipeline_health WHERE created_at < NOW() - INTERVAL '90 days'` cron.
- **Index on `match_status_state.fired_finished_at`.** CHECK 4 does a full scan every 30 min. Tiny table today; will matter when WC season adds 48 countries × fixture rows.
- **`error_class` as a typed union in `_shared/types.ts`.** Currently `string | null` — typos slip through. Convert to `"success" | "fire_failed" | "fire_threw" | ...` so the TS compiler catches divergence.

### 65. WC pre-launch hardening sweep (May 17 night-final)

**What we shipped, all in one continuation pass right after Lesson 64:**

The four V2.1 candidates in Lesson 64 were all bounded and shippable in one session. We did. Plus the data-fetcher cadence bump. Five backend phases, two deploys.

- **Mig 042 + match-watcher** (`cce7980`): matchday-fire retry cap (N=5, T=2h). Adds `match_status_state.matchday_fire_capped`, pre-checks pipeline_health for failure history per fixture's targets, marks capped on trip. Backfilled the 3 stuck fixtures tonight. Verified live: zero new matchday_fire rows 90s post-deploy. Live_brief NOT modified — already has implicit single-attempt protection via `briefs_fired` written unconditionally regardless of fire outcome.
- **Mig 043** (`e20ec68`): pipeline_health 90-day retention sweep cron at 03:00 UTC daily. Day-one no-op; first real DELETE around mid-August.
- **Mig 044** (`82b2572`): partial indexes on `match_status_state(fired_finished_at)` and `content_items(match_id, type)` for CHECK 4 efficiency at WC scale. Both `WHERE` partials because most rows have NULL on the leading column.
- **Mig + types.ts** (`37bf565`): `PipelineHealthLog.error_class` narrowed from `string | null` to a 9-value union plus null. notification-sender's `errorClass` local + `APNS_STATUS_TO_ERROR_CLASS` map narrowed too so the call site is type-safe. Both functions redeployed — the bundler's typecheck would have failed if narrowing was wrong, so the union is sound.
- **Mig 045** (`becedc7`): data-fetcher cron `0 7 * * *` → `0 * * * *` (daily → hourly). Was up to 23-hour latency for squad announcements landing during May 28+ WC squad window. Now 60 min worst case. ~1,900 API-Football calls/day = comfortable under the Pro tier 7,500/day ceiling. Permanent change.

**Three live findings during the planning phase:**
1. Migration 003 in the repo claims `*/30 8-23 * * *` for data-fetcher but the live state was `0 7 * * *` — a later (un-migrated?) schedule change. Lesson: always verify cron state via `SELECT … FROM cron.job` instead of grepping migrations.
2. The backfill for matchday_fire_capped caught 3 fixtures, not the 2 I initially expected — Newcastle vs West Ham also FT'd and started its own 429 retry storm in the time between Phase J P.5 and tonight's hardening pass. Observability surfaced it as soon as we queried.
3. Live_brief's "infinite retry loop" hypothesis (raised in /simplify's exploration) was wrong — the `briefs_fired` upsert at end of tick is unconditional, providing implicit single-attempt protection. Read the code, not just the surrounding comments.

**Net result:** WC backend is launch-ready. All pre-existing matchday-fire retry-loop bugs are stopped (current fixtures capped + future stuck fixtures will cap automatically). pipeline_health stays bounded. Type system catches taxonomy typos. Data freshness covers WC squad announcements. The only remaining items before launch are user-side: enable claude.ai Extra Usage as a safety net, onboard the dev iPhone through the V2.0 flow to E2E-test country routing, and the App Store submission flow.

**Out of scope after this sweep:** FA Cup coverage (V2.2), two-Vault-entry split, secondary alert channel (explicitly deferred — chicken-egg risk accepted), live-brief HT retry within window. None block the June 11 launch.

### 66. `/security-review` caught three unauthenticated diagnostic Edge Functions

**What happened (May 17 night-finale):** Ran the bundled `/security-review` skill against the full WC branch diff (130+ files, ~1MB of diff content). One MEDIUM-confidence cluster: `register-dev-device`, `push-probe`, `diagnose-matchday` — three diagnostic Edge Functions that were deployed with `--no-verify-jwt` per Lesson 37 but never added their own auth check, leaving them callable by anyone with the Supabase project URL.

The risk wasn't credential theft — each function's privilege was bounded — but each had a clear PII / abuse vector:
- `register-dev-device` → harvest the internal client-error push stream (team_id, app_version, OS, error messages)
- `push-probe` → on-demand push spam to any team's most-recent device
- `diagnose-matchday` → structural exfiltration: subscriber counts, APNs token prefixes, recent client_errors, HTTP response previews

**Fix:** identical pattern across all three, lifted from Lesson 37's own recommendation: validate `Authorization: Bearer == SUPABASE_SERVICE_ROLE_KEY` at the top of the handler before any DB read/write or external call.

**Rules:**

1. **`--no-verify-jwt` MUST be paired with an in-function auth check.** Lesson 37 said this; we did it for production functions (notification-sender, etc.) but missed it for the diagnostics, because diagnostics felt "internal" — until they didn't. Going forward, treat every deploy of a `--no-verify-jwt` function as triggering an auth-check audit.

2. **"Diagnostic-only" is not a security boundary.** The function is on the public Internet the moment you deploy. Auth must be the first line of the handler.

3. **Run `/security-review` before every meaningful merge to main.** Tonight's review took ~3 minutes of agent time and caught a class of issues that had been live for weeks. Cheap insurance.

4. **When local `.env` digests drift from runtime secrets, document it.** Tonight's `SUPABASE_SERVICE_ROLE_KEY` mismatch (local `c37311…` vs runtime `6c086b…`) meant I couldn't curl-test the legitimate-bearer pass case from this machine. The auth-gate's correctness was established by the two REJECTION cases; the pass case follows from the code. Future-me: if curl-tests can only rejection-test, the gate is still verified — just note it.

**LOW-confidence-7 finding intentionally deferred:** `device_tokens` anon SELECT (migration 030) exposes full 64-char APNs tokens to anyone with the publishable key. Already documented in migration 030's own header as a V1.1 follow-up. Not a launch blocker; will tighten via RLS policy post-WC.

**The night-finale commit:** `6448a22`. Branch state: pushed, ready for launch.

### 67. Three bugs hide behind every "data missing" claim

**What happened (May 17 night-finale-2):** Sweden's onboarding manager card rendered the literal string `<UNKNOWN>` in the sim. Investigation went through four layers before all 48 WC countries had real coach data.

- **Layer 1 — Prompt ambiguity (the "obvious" bug):** team-page-generator's user-message told Claude "pick the FIRST entry whose career.end is null." API-Football's `/coachs` returns every coach who's ever managed the team; Sweden had two with `end=null` (E. Hamrén 2023 + J. Tomasson 2024). Claude picked the first in list order (Hamrén). Fixed by replacing the natural-language rule with a deterministic JS pre-filter that selects the single coach whose most-recent career stint matches the team's `api_football_id` AND has `end == null`. Sweden updated to Tomasson on first re-run. **But 11 other countries stayed `<UNKNOWN>`.**

- **Layer 2 — Iteration overwrite (the "hidden" bug):** Netherlands also stayed `<UNKNOWN>` even with the new filter. Throw-debugged the function and saw `coachsData` contained a rate-limit error response, not coach data. raw_fetch_logs has multiple `api_football_coachs` rows for the same team over time. The fetcher loop iterated newest-first BUT overwrote `coachsData` on every match — so the LAST iteration (the OLDEST row in the 20-row window) won. Netherlands' May-16 row was a rate-limit error from API-Football; that overwrote May-17's successful fetch. Fix: `if (coachsData) continue` — newest good row sticks.

- **Layer 3 — JSON truncation (the "could be the bug" bug):** related discovery: the single-coach `JSON.stringify().slice(0, 2000)` was cutting mid-payload for coaches with long careers (Koeman has 12 stints, ~2200 chars). Even with the right coach picked, Claude got broken JSON and could default to `<UNKNOWN>`. Fix: strip `career[]` to just the current stint before serialising — small + complete payload.

- **Layer 4 — Upstream data quality (the "not a code bug" bug):** Even with Layers 1-3 fixed, France/Spain/Scotland/Uruguay still got wrong picks. The reason: API-Football's `/coachs` data for those countries is internally inconsistent. For France (team_id=2), the only active stint listed is Luis de la Fuente — but his `career[0].team.id` is 9 (Spain). For Scotland and Uruguay, no career entries have `end=null` at all. My filter correctly returns "no match" → falls back to `coachsData = jsonStr` → Claude picks from messy data → ends up with the wrong coach. Real fix: a `manager_overrides` table seeded from a trusted source. V2.1, ~30 min.

**Rules:**

1. **Don't trust "data missing" until you've verified at multiple layers.** Each layer here looked like the same symptom from above — "manager is UNKNOWN" — but each had a different root cause requiring a different fix. Layer 1's fix alone didn't help Netherlands; Layer 2's alone didn't help Koeman; Layer 3's didn't fix France.
2. **Iteration overwrite is a recurring bug pattern.** When a `for` loop iterates a sorted list and assigns to a single variable per match, you get the LAST match — often the OPPOSITE of what you want. Either `break` after the first good match, sort ascending if you want newest-wins, or guard the assignment with `if (alreadySet) continue`.
3. **`.slice(N)` on a JSON string truncates structure, not just content.** When the payload is a JSON object/array, slicing produces invalid JSON. Prefer trimming logical fields (drop irrelevant nested data) before serialising. If slicing is unavoidable, `JSON.parse()` afterwards to validate.
4. **Upstream data quality is a launch risk for V2.0.** API-Football's PL coverage is excellent; their national-team coach data is patchy. We need a manual override layer for ~5 countries' managers before launch, and likely similar gaps elsewhere (squads, fixtures). Filed as V2.1.

**Bonus — the V2.0 sim walkthrough findings that triggered all of this:**

The Layer 1-4 chain only got opened because the user ran the V2.0 onboarding in the simulator end-to-end and reported what they saw. Five issues surfaced in one walkthrough (`98f945d` shipped all five):

- Country missing from the feed switcher dropdown (`ContextSwitcherView` only listed the team) → country now first
- "His Team" tab locked to country-first regardless of feed selection → now follows `activeContext` (label + content both)
- MeetTeamView CTA "Show me how this works" navigated to the manager screen, not the how-it-works screen → copy now "Meet the boss"
- iOS rendered the literal `<UNKNOWN>` placeholder when team-page-generator had no manager data → belt-and-suspenders gate hides the card in both MeetManagerView and TeamPageView
- gd-saturday-quiz cron `0 7 * * 6` fired at 07:00 UTC = 4-5h before the "Saturday lunchtime" promise on the onboarding "How this fits into your week" screen → bumped to `0 11 * * 6` = lunchtime BST

**Files touched tonight:** `ContextSwitcherView.swift`, `GoalDiggerApp.swift`, `MeetTeamView.swift`, `MeetManagerView.swift`, `TeamPageView.swift`, `team-page-generator/index.ts`. Cron updated via RemoteTrigger. team_pages rows regenerated for 21 teams (18 WC + 3 PL).

**Commits:** `98f945d` (sim walkthrough sweep), `456b2a9` (team-page-generator follow-ups). After these, all 48 WC countries + 20 active PL clubs have a real manager name + photo URL; 4 countries (France/Spain/Scotland/Uruguay) reflect upstream data-quality issues — filed as V2.1.

### 68. The hardcoded list was the bug — and so was the fetch script — and so was the validator

**What happened (May 18):** User reported during the V2.0 sim that Sweden's team page had no "history" surface and no "Things he doesn't know" section. Investigation revealed the entire insider system had been silently scoped to PL clubs since V1.1 launch, plus the section had only ever rendered one of four available types — wasting the variety the schema already supported.

The fix took three iterations, each surfacing a deeper version of the same architectural pattern: "this part of the system was hardcoded for the V1 scope and never reviewed when V2 added countries."

- **Layer 1 — Hardcoded iteration list.** `INSIDER_PROMPT.md` step 3 enumerated the 20 PL teams alphabetically in markdown. WC countries were never iterated. Fix: replaced with a live `teams` table query (`entity_type IN ('club','country') ORDER BY id ASC`). PL clubs and countries now interleave alphabetically (algeria → argentina → arsenal → aston_villa → australia → ...). Commit `bbdcb3e`.

- **Layer 2 — Hardcoded fetch script.** Step 2 ran only `fetch_news.sh` — which hardcodes 20 PL teams. So the iteration query (post-fix) returned 68 teams, but Claude couldn't read `/tmp/fetch_<country_id>.json` for any country because the fetch step never produced those files. The routine's "failure mode" rule kicked in ("skip if no data") and the WHOLE country was skipped — including `history` and `oddity` types that don't actually need fetch data. Fix: also call `fetch_news_wc.sh` in step 2 AND narrow the failure-mode rule to only skip data-dependent types (`stat`, `anecdote`). `history`/`oddity` can compose from training-data anchored on year/scoreline/named person. Commit `91f0c5b`. After this, 48/48 countries had `stat`/`history`/`oddity` but only 6 had `anecdote`.

- **Layer 3 — Hardcoded validator.** The `anecdote` rule required "directly references something in today's RSS — quote a phrase if quotable." `fetch_news_wc.sh` has thin RSS coverage for most WC countries (no per-FA RSS feed). When RSS was empty for a country, Claude couldn't anchor an anecdote and skipped the type. Fix: for countries specifically, allow anecdotes composed from training-data knowledge of recent (last 6-12 months) federation news — squad call-ups, manager appointments, friendly results, controversy — with the same anchor rule as history/oddity. Commit `134dc6d`. After this, all 48 countries reached 4/4 types.

**Three backfill fires total via `RemoteTrigger action=run` with `text=backfill=all_types`** (one-shot mode added in the same prompt, generates 4 items per team in a single pass instead of the daily 1-type rotation). The trigger framework forwards the `text` field into Claude's session context — same pattern `gd-live-brief` and `gd-matchday` use. Initial implementation tried bash `$TRIGGER_TEXT` which doesn't exist (the framework doesn't export it as a shell env var); rewrote to instruct Claude directly to inspect the trigger payload it received.

**Final state:** 797 rows in `team_insider_items`. 48/48 WC countries with 4/4 types, 20/20 active PL clubs with 4/4 types, 3 relegated clubs at 2/4 (limited recent data, not selectable in V2.0 onboarding — acceptable).

**iOS side:** the existing card had been rendering ONE insider item with title + 2-line body, expandable on tap. Redesigned to show 4 items, latest of each type, headlines-only (no body, no expand). New `fetchInsiderSet(teamId:)` in `APIClient.swift` makes one REST call (latest 40 rows) and picks `[stat, history, oddity, anecdote]` client-side. New `InsiderHeadlineRow.swift` component is compact (tracker label + headline, same rose accent bar for visual continuity with InsiderCard). `TeamPageView.swift` rewires state from `latestInsider: InsiderItem?` to `insiderSet: [InsiderItem]`. The existing `InsiderCard.swift` (with body) is retained because the FeedView empty-state surface still wants the explanation. Commit `bb21630`.

**Rules:**

1. **When you add a second scope to a system (e.g., countries alongside clubs), audit every hardcoded list in that system.** Don't trust that the surface-level handler (per-team `ENTITY_TYPE` lookup) is enough. The iteration list, the fetch step, AND the validator all had separate PL-only assumptions baked in. Each had to be hunted down independently.

2. **Routine trigger payloads (`text` field) reach Claude through model context, not bash env vars.** Don't write `if [ "$TRIGGER_TEXT" = "x" ]` in routine prompts — Claude reads the trigger payload from its conversation context (same way `gd-live-brief` and `gd-matchday` do). Phrase prompts as instructions to Claude, not shell scripts.

3. **For seed-data work, pair a daily incremental routine with a one-shot batch mode.** Daily 1-type rotation is right for steady-state freshness. But waiting 4+ days for every team to accumulate one of each type is not viable for a launch surface. Adding `text=backfill=all_types` (4 items per team in a single fire) seeded ~272 items in one run.

4. **Routine sessions don't expose progress through their API metadata.** `RemoteTrigger action=get` returns `last_fired_at` from the prior cron fire, NOT the in-progress manual fire. To monitor progress, poll the table the routine writes to — for gd-insider that's `team_insider_items.published_at` rolled up by team/type, or `pipeline_health` for the routine_post stage.

5. **Project-shared permissions reduce friction for everyone.** Shipped `.claude/settings.json` with 24 broad allow patterns (curl, read-only git, utility commands, xcodebuild, simctl, supabase, psql). Replaces the ~500 fragile exact-string entries that had accumulated in `.local.json`. Commit `3487843`. Future sessions stop re-prompting for the same shape of command.

**Files touched:**
- Routines repo: `INSIDER_PROMPT.md` (3 commits — `bbdcb3e`, `91f0c5b`, `134dc6d`).
- iOS: `APIClient.swift`, `InsiderHeadlineRow.swift` (new), `TeamPageView.swift`, `GoalDigger.xcodeproj/project.pbxproj`. Commit `bb21630`.
- Permissions: `.claude/settings.json` (new), `.gitignore`. Commit `3487843`.

**Out of scope (intentional):** retention sweep on `team_insider_items` (table grows ~5 rows/day with the daily routine, can wait), restoring per-type body text behind a tap-to-modal flow (data still in DB, can surface later without backend changes), and the `manager_overrides` table for the 4 broken-coach countries from Lesson 67 (still V2.1).

### 69. When to use Claude vs deterministic merge for team-page data

**What happened (May 18 evening):** the redesigned "His Team" tab needs two new data surfaces — a Calendar tab with per-fixture importance ratings, and a Table tab with full league/group standings. Both ride on the same `team_pages.content.cards` JSONB blob the existing `team-page-generator` Edge Function already writes. The natural-but-wrong move was to ask Claude to also generate the standings rows in the tool call. The actually-right split:

- **Standings → mechanical merge, no LLM.** The standings table is purely factual data already living in `raw_fetch_logs.api_football_standings`. There's no judgment to apply — rank, played, won, drawn, lost, goal diff, points are what the API says they are. Asking Claude to retype 20 PL teams' worth of stats in a tool call would (a) burn tokens on a copy-paste task, (b) risk transcription errors, (c) inflate prompt size for no quality gain. Solution: a `buildStandingsCard(rawLogs, team, now)` helper runs after the tool call, picks the right group (PL=single array, WC=4-team group containing this team's `api_football_id`), and writes the rows directly.

- **Importance labels → Claude judgment, in-tool.** Rating a fixture's importance ("Top-4 race", "Group A decider", "Relegation 6-pointer") requires knowing the standings context AND the rivalry weight AND the season phase. That's the same context Claude already has for the rest of the team-page tool call. Adding `upcoming_fixtures` as an optional array field on the tool schema costs ~150 tokens of output and is the right home for the judgment.

**Three plumbing bugs surfaced during smoke testing — same iteration-overwrite pattern as Lesson 67:**

1. **raw_fetch_logs window was too small.** The function queried 20 rows newest-first. With 14 source-rows per hourly fetch, 20 rows covers ~1.4 hours. When API-Football briefly returns empty responses (a regular occurrence — happened at 17:00 UTC during Arsenal's smoke test), the only-good-data row is OUTSIDE the window and the standings card came back null. Fix: bump LIMIT to 100, covering ~7 hours of fetches per team.

2. **Fetch loop assigned unconditionally — empty rows overwrote good ones.** The existing for-loop did `if (log.source === "api_football_standings") standingsData = jsonStr` — no guard. Since rawLogs is newest-first, the LATEST empty response would set `standingsData = ""`, and a previous good row earlier in the iteration would have already been written first (but then overwritten). The behavior was lossy in the opposite direction from Lesson 67's coachs bug. Same fix shape: "newest GOOD wins" — skip the assignment if (a) we've already filled it or (b) the response is empty.

3. **JSON slice truncated mid-fixture.** Fixtures sliced at 2000 chars cuts roughly between fixture 2 and fixture 3 in a 4-fixture response. Claude received invalid JSON and emitted an empty `upcoming_fixtures` array. Same pattern as the manager-coach truncation in Lesson 67 (Koeman's long career history). Per-source slice limits: squad 6000, fixtures 6000, standings 8000, default 2000.

**Rules:**

1. **Use Claude where the value is JUDGMENT, not copying.** "Should this be 4 dots or 5?" needs context. "What's Arsenal's goal difference?" doesn't. Mixing the two in a single tool call cuts efficiency for both.
2. **`.find()` / `.first` on a newest-first array is a footgun when the newest row can be empty.** Always walk past empties when the data is "the latest GOOD one."
3. **JSON slicing on object/array payloads produces invalid JSON.** When you must slice, either parse-validate-reserialise after the slice OR strip irrelevant nested fields before stringifying. Don't trust the LLM to recover from invalid JSON in its input.
4. **A new field is a new chance to discover the OLD plumbing was already broken.** The `upcoming_fixtures` failure forced us to fix two pre-existing latent bugs in the fetch loop that had been silently degrading the OTHER fields' quality for weeks. Add observability to fields you're already using before adding new ones.

**Files touched:**
- Backend: `team-page-generator/index.ts` (commit `f8024e1` — tool schema + prompt + buildStandingsCard helper + fetch-loop guards).
- iOS Models: `ContentItem.swift` (new `StandingsEntry`, `StandingsCard`, `UpcomingFixture`, plus `TeamPageCards` extension).
- iOS Components: new `Design/Components/CollapsibleSection.swift`, registered in `pbxproj` with the next free `AB000310` ID.
- iOS Views: `TeamPageView.swift` (segmented `TeamTab` enum + `tabSelector` + `tabContent` dispatcher + `calendarTab` + `tableTab` + standings row highlight), `SettingsView.swift` (deleted feedFormatSection, reorganized into Notifications + Calendar visible / Setup + About collapsed at bottom).
- Commits: `f8024e1` (backend), `8f1b540` (iOS).

**Out of scope:** past results on the Calendar tab (upcoming-only per user direction), single-fixture-add tap action on the Calendar (existing CalendarSyncService still syncs the batch from Settings), `ClassicFeedView.swift` source deletion (dead code post-toggle-removal — defer to a cleanup task), importance-rating prompt tuning beyond first-pass (revisit if ratings cluster too uniformly after backfill).

### 70. Reuse the trigger framework you already built — don't bolt on a parallel scheduler

**What happened (May 18 night):** added two new push surfaces. The first — a morning game-day push — was new infrastructure (no existing daily-fixture cron pattern). The second — a starting-XI push fired ~60 min before kickoff — had two plausible homes:

1. **Extend `matchday-scheduler`**: it already runs daily at 07:00 UTC, fetches today's fixtures, and pre-schedules one-off pg_cron jobs at kickoff − 90 min. Add a second pg_cron schedule at kickoff − 65 min for the starting-XI routine.
2. **Add a new trigger label to `match-watcher`**: it already polls every minute, tracks per-fixture state, and has a `briefs_fired` JSONB idempotency guard. Add `STARTING_XI` to the trigger detection logic, branch the fire URL per label.

I went with (2). Why:

- **One source of truth for "fire this routine once per fixture."** match-watcher already had the framework for HT triggers — the idempotency guard, the failure-mode logging, the per-perspective fire loop. Adding STARTING_XI to that pipeline was ~30 lines of new code (trigger detection + URL branch). Going through matchday-scheduler would have meant duplicating the pg_cron scheduling RPC + the same idempotency guard in a different shape + a separate logging path.
- **Time precision is fine at the polling level.** match-watcher runs every minute via pg_cron; the kickoff − 65 min window catches any fixture transitioning into it within 60 s. That's tighter than necessary (lineups don't change second-to-second). A pg_cron one-off scheduled at the exact kickoff − 65 min target would be marginally more precise but pays the cost of a new code path.
- **Single mental model for the fire loop.** The `for (const trigger of newTriggers)` block now handles HT (in-match) and STARTING_XI (pre-match) with a single URL switch. A future "goalscorer" trigger or "kickoff" trigger drops into the same block.

**Rules:**

1. **Before building a new scheduler, look at the one that's already running every minute.** Polling at minute granularity covers most "fire X min before Y" requirements without new infrastructure. The cost of an extra trigger-detection branch is a few cycles per fixture; the cost of a new scheduler is a new failure surface forever.
2. **Idempotency guards travel with the trigger pattern.** `briefs_fired: jsonb[]` exists because in-match polling needs to know "did we already fire HT?". The same array trivially extends to "did we already fire STARTING_XI?". Reusing it gets the dedup for free.
3. **The new trigger label gets a routine URL switch, not a function rewrite.** Branch on `trigger === "STARTING_XI"` to pick the env-var pair (URL + token); everything else — payload shape, idempotency, logging — stays uniform.
4. **The morning push had no equivalent prior pattern** (no daily fixture-announcement cron existed), so it got a new Edge Function + cron. Don't reuse for the sake of reusing — but check for an existing pattern before assuming "new feature = new infrastructure."

**Two surfaces in this same arc:**

- **Morning push** (commit `e5035e4`): new `morning-push` Edge Function, new daily 08:00 UTC cron (migration 048), new pipeline_health stage `morning_push` (migration 047). Pure templated push, no LLM. Pure new build because no comparable pattern existed.
- **Starting-XI** (same commit set): all inside the existing `match-watcher` trigger framework — new trigger label, new fire-URL branch, new content_items type (migration 046), new cloud routine `gd-starting-xi` (routines repo commit `d529bb6`). No new schedulers, no new cron jobs.

**News-item team logos (commit `16c13df`)** — a different category. New optional column `affected_team_ids text[]` on content_items (migration 049), populated by both content-generator and the routine path (PROMPT.md AFFECTED TEAMS section). iOS reads it via a new `AffectedTeamsHeader` component that resolves each id to `TeamCrestView(team:)` or `TeamCrestView(country:)` via the existing PL/WC enums. 1-2 entries → 1-2 crests; 3+ or nil → no crests. Items pre-migration render gracefully without crests.

**Files touched:**
- Backend: `morning-push/index.ts` (new), `match-watcher/index.ts` (STARTING_XI detection + fire-URL branch), `content-generator/index.ts` (affected_team_ids tool + merge), migrations 046/047/048/049.
- Routines repo (`anton-tech43/goaldigger-routines`): `STARTING_XI_PROMPT.md` (new), `post_starting_xi.sh` (new), `PROMPT.md` (AFFECTED TEAMS section), `schema.json`.
- iOS: `ContentItem.swift` (startingXi case + affectedTeamIds field), `BadgeView.swift` (STARTING XI chip), `FeedView.swift` (tier filter), `AffectedTeamsHeader.swift` (new), `ContentDetailView.swift` (render the header), `pbxproj` (registered AB000311).
- Commits: `df24830` (simplify), `e5035e4` (push backend), `c7a5b96` (iOS starting_xi case), `d529bb6` (routines), `16c13df` (news logos backend + iOS), `ca0a839` (routines AFFECTED TEAMS).

**Manual step (superseded by Lesson 71):** initially this lesson said the user needed to generate the routine API token in claude.ai/code/routines UI for `trig_01J8yMGTBu6KRvpWHzXeburj` (gd-starting-xi) and set `STARTING_XI_ROUTINE_URL` + `STARTING_XI_ROUTINE_TOKEN` as Edge Function secrets. The user opted instead for a simpler design (morning push references lineups as a teaser, no fetch) — see Lesson 71. The routine is now disabled via RemoteTrigger, the prompt + post script were deleted from the routines repo, and the match-watcher trigger detection was removed. The two secrets were never set (confirmed by `supabase secrets list` post-cleanup) — nothing to clean up.

**Out of scope:** per-user timezone scheduling for the morning push (V2.1); goalscorer push notifications during live match (over-notification risk); crest-tap-to-navigate from detail to team page; bulk backfill of `affected_team_ids` for historical rows.

### 71. The quota blast radius — a metered upstream and the FT push that didn't come

**What happened (May 18 late night):** Arsenal-Burnley finished ~21:00 UTC. User's team is Arsenal. No FT push arrived. Investigation found: `match-watcher` (per-minute cron, polls API-Football for fixture state transitions) was receiving `"You have reached the request limit for the day, Go to https://dashboard.api-football.com to upgrade your plan."` from ~18:00 UTC onwards. With no fixture data coming back, match-watcher never saw Arsenal transition from `NS` → `FT`, so `matchday_fire` never fired, so notification-sender never pushed.

**The migration that did it.** Migration 045 (shipped ~17:00 UTC the same day) walked `data-fetcher` from daily at 07:00 UTC to hourly (`0 * * * *`). That sounded innocuous in isolation, but the math we never did:

```
data-fetcher per fire: ~430 API-Football calls
                       (71 teams × ~6 endpoints + 2 league standings)
data-fetcher hourly  : 430 × 24 = 10,320 calls/day
match-watcher        : 2 leagues × 1440 ticks/day = 2,880 calls/day
                       ──────
Total                : ~13,200 calls/day
API-Football Pro tier:  7,500 calls/day
                       ──────
Over budget by       :  5,700 calls/day, every day.
```

By ~18:00 UTC the daily budget was gone. From that point until midnight UTC, match-watcher was effectively dead — fixtures couldn't be fetched, transitions couldn't be detected, pushes couldn't be triggered. A whole match day silently broke.

**The misleading user-side suspicion.** User initially thought the issue might be in the FT-push pipeline itself ("we changed crons for HT/75' — did that break FT?"). Worth chasing for ~30 seconds, but no — the HT/75' change (Tier 3 sweep, May 17) only dropped match-watcher's 75' routine fire, not anything in the matchday_fire / API-call path. The actual culprit was a completely different cron (`data-fetcher`) on a completely different code path that happened to share the same metered upstream.

**The fix (migration 050).** Walked `data-fetcher` back to `0 6-22/2 * * *` — every 2 hours during waking hours (06:00–22:00 UTC), quiet overnight. New steady-state math:

```
data-fetcher 9× waking: 430 × 9 = 3,870 calls/day
match-watcher         :          2,880 calls/day
                                ──────
Total                 :          6,750 calls/day  (under 7,500 ceiling)
Headroom              :            750 calls/day  (one-off regenerations,
                                                   manual smoke tests, etc.)
```

Tomorrow at 00:00 UTC the API-Football quota resets and match-watcher resumes seeing fixtures.

**Rules:**

1. **Before changing a cron cadence on any path that consumes a metered upstream, do the math.** `(calls per fire) × (fires per day)` vs `daily quota`. The math takes 30 seconds; the regression takes 4 hours to debug AND breaks user pushes silently. There's no "I'll check later" — the moment a hourly cron hits an over-quota threshold, every downstream consumer of that upstream is impaired and there's no error in your own pipeline pointing at the cron change.

2. **A metered upstream is a shared resource.** `data-fetcher` and `match-watcher` are two completely independent code paths in different cron jobs producing different outputs. They look unrelated until you remember they both call API-Football. Quota is a coupling that doesn't show up in dependency graphs or import statements.

3. **"Waking-hours only" is almost always the right pattern for content fetchers.** Overnight (22:00–06:00 UTC) news is sparse, users are asleep, and the cron fires were doubling spend for zero user value. The user explicitly asked for quiet hours — they were right.

4. **When a regression looks like "the feature path broke," check the upstream-spend path before the feature path.** The fix wasn't in `match-watcher` or `notification-sender` or any push-side code. It was in `data-fetcher` — the OTHER service that happened to share the API-Football quota.

5. **Pipeline-health observability caught this in minutes once we looked.** Querying `net._http_response` for recent match-watcher invocations showed every response saying "request limit reached." Without that table we'd have been chasing ghost states in `match_status_state` and never found the rate-limit cause. Phase J pays for itself.

**Files touched (and not touched):**
- Backend: `migrations/050_data_fetcher_every_2h_waking.sql` (new), reverts migration 045. Also: `match-watcher/index.ts` (delete STARTING_XI trigger block + fire-loop branch, revert `logFire` stage union — tonight's overbuild that wasn't asked for); `morning-push/index.ts` (body copy refresh referencing lineups); routines repo (`STARTING_XI_PROMPT.md` + `post_starting_xi.sh` deleted in commit `e163606`; cloud routine `trig_01J8yMGTBu6KRvpWHzXeburj` disabled via RemoteTrigger).
- iOS: `FeedView.swift` (delete the `loadInitial` unconditional reset that caused Sweden→His Team→Feed to revert to Arsenal).
- Permissions: `.claude/settings.json` expanded 24 → 46 patterns.

**Manual side-effects user took ownership of:** Earlier in the day they set Supabase Edge Function secrets `STARTING_XI_ROUTINE_URL` + `STARTING_XI_ROUTINE_TOKEN`. After tonight's cleanup these are dormant — harmless, optional cleanup via `supabase secrets unset` if they want a tidy dashboard.

### 72. The two-layer iteration-overwrite — when the silent-fallback hides how broad the breakage is

**What happened (May 19 morning):** User flagged "Sweden still shows no coach" as one of two tomorrow-punch-list items. Investigation started narrow (just Sweden) and uncovered a class of bug that had been silently breaking the manager card for **every team except Sweden** — 69 of 70 `team_pages` rows had `cards.manager.name = '<UNKNOWN>'`. We hadn't noticed because the iOS "Meet the boss" card has a graceful-hide gate for `<UNKNOWN>` (Lesson 67's iOS fallback), so a universal data failure rendered as "the card just doesn't show up" — visually indistinguishable from "this team genuinely doesn't have a current coach in API-Football."

Three distinct failure modes were stacked in the same `team-page-generator` coachs branch. Each one had to be fixed in sequence; finding the next required fixing the previous.

**Failure mode 1 — empty-response iteration overwrite.** Lesson 67 had added `if (coachsData) continue;` as a guard against older rows clobbering newer good rows (oldest-empty-clobbers-newer-good). But the else-branch on empty `response: []` was still writing the rate-limit error JSON into `coachsData`:

```ts
} else {
  coachsData = JSON.stringify(log.data).slice(0, sliceLimitFor(log.source));
}
```

Sequence:
1. Newest log: `response: []` (rate-limit error from today's quota burn). Branch executes, sets coachsData = error JSON.
2. Older log: has good coach data. `if (coachsData) continue;` skips it.
3. Claude receives `Coaches: <rate-limit error>`, can't parse a coach, emits `<UNKNOWN>`.

Same iteration-overwrite class as Lesson 67, opposite direction (**newest-empty-blocks-older-good** vs. older-empty-clobbers-newer-good). Fix: replace the writeback with `continue` so the loop walks past empties.

**Failure mode 2 — the main fetch window doesn't cover enough history.** Fix 1 alone resolved Sweden but not Canada. Canada's most-recent good `api_football_coachs` row was from May 17 22:00 UTC; today's 5 most recent coachs logs all had `response: []`. Even with fix 1's `continue`, the loop never reached the good May 17 row because the 100-row main fetch window — sorted newest-first across ALL sources — was dominated by news (6 hourly publishers per team × ~24h ≈ 144 rows) which pushed the good coach row past row 100.

Cheap fix: add a targeted secondary query specifically for `api_football_coachs`, latest 20 rows, appended to `rawLogs`. The newest-good-wins guard from Lesson 67 deduplicates correctly — iteration is still newest-first within the appended source. 20 rows covers ~20h of hourly coach fetches, comfortably past the daily API-Football quota cycle (rate-limit windows reset at 00:00 UTC).

This pattern — "main window for general data, targeted top-up for low-cadence sources at risk of being crowded out" — is worth keeping in mind for future endpoints that fetch less often than the news sources.

**Failure mode 3 — the "no current coach" raw-payload fallback lets Claude guess.** Fixes 1+2 brought 66/70 teams to correct coach data. The remaining 4 (France/Scotland/Uruguay/Spain) rendered visibly-wrong names — R. Caudron (1930) for France, A. McLeish (last stint 2019) for Scotland, Ó. Tabárez (last stint 2021) for Uruguay. Investigation: the pre-filter found zero coaches with `end=null` at the team's `api_football_id`, but the else-branch wrote the raw payload as a fallback so "Claude could decide between a recent ex-coach and `<UNKNOWN>`." Claude picked the most recent-looking name from a list of historical-only stints. Wrong, every time.

Fix: change the no-current-match fallback from "write raw payload" to `continue`. If every snapshot in the window has zero open stints, `coachsData` stays empty → Claude's "Coaches data not available → manager_name = `<UNKNOWN>`" branch fires → iOS card hides. That's the correct behavior. We should NEVER be making the user read a wrong coach name when our pre-filter explicitly determined the data is bad.

Resolved France/Scotland/Uruguay cleanly to `<UNKNOWN>` (iOS card hides — correct outcome). Spain remained wrong ("D. Deschamps") because API-Football has Deschamps incorrectly tagged to Spain's `team_id=9` with `end=null` start 2025-06-01 — upstream data corruption that no client-side filter can repair. Spain is the one true `manager_overrides` table candidate (V2.1).

**Why we didn't notice it sooner.** Lesson 67's iOS gate hides the card for `<UNKNOWN>`. When the gate works, "card hidden" is visually identical for "genuinely no coach data" and "broken data fetch." The Sweden bug was narrow enough to surface as user-visible (Sweden's a higher-profile team than, say, Bournemouth's WC presence, so the user noticed). But the underlying breakage was universal. **Lesson:** when you ship a graceful-hide fallback for one failure case, you simultaneously become unable to detect a regression where every team hits that case. Add a separate observability path that surfaces the FREQUENCY of the fallback firing, not just whether each individual render handled it correctly.

**Rules:**

1. **Every `continue` for one failure case may need a sibling `continue` for adjacent failure cases.** Lesson 67's `if (coachsData) continue;` guard against older-rows-clobbering had a missing partner — `continue` on empty newest rows so the guard isn't tripped with a worthless value. When you write a "skip if already populated" guard, audit every place that populates and make sure none of them populate with garbage.

2. **A graceful UI fallback makes broad regressions invisible.** The iOS gate for `<UNKNOWN>` was correct as a defensive layer. But it meant we couldn't tell "no team has manager data" from "France/Scotland/Uruguay/Spain don't have manager data" without explicitly checking the row count. Add a fallback-rate metric whenever you add a graceful-hide fallback — e.g., a `pipeline_health` row tagged `fallback_fired=true` and a dashboard query that alerts when fallback rate exceeds X% of teams.

3. **Window-size assumptions break silently when adjacent ingestion grows.** The 100-row main window was sized assuming "14 sources × 7h = covers a day's worth of any source." But news sources tripled in count after the V2.0 multi-publisher expansion, while coachs stayed at 1 fetch per data-fetcher fire. The window math went stale. Either compute the window from the ingestion rate, or split fetches per-source so they can't crowd each other out. We chose the latter for coachs via the targeted top-up.

4. **Don't let an LLM guess at output when your deterministic pre-filter has already determined the answer is bad.** The "raw payload fallback to let Claude decide" pattern was a well-intentioned escape hatch — but it converted "I can't find a current coach" into "make something up that sounds current." If the pre-filter says "no current open stint at this team," that's the answer. Emit it directly. Don't push the decision to the LLM.

5. **Investigation should widen the scan, not just narrow it.** User flagged Sweden. Sweden could have been a one-team data issue. The right move after fixing Sweden is "how many other teams are in this state?" — not "great, Sweden's done." The widening query (`SELECT count(*) WHERE manager.name = '<UNKNOWN>'` returning 69) was the moment the lesson landed.

**Files touched:**
- Backend: `team-page-generator/index.ts` — three deltas (coachs top-up query, two else-branch `continue`s) totalling ~60 lines including comments. No new migrations needed (purely runtime logic).
- iOS: `TeamPageView.swift` `tabSelector` (slicker segmented control, separate punch-list item shipped alongside).
- STATUS.md: new May 19 morning section.

**Live backfill result:** 70 team_pages rows re-fired via parallel `curl` loop after deploy. Before: 69 `<UNKNOWN>` (Sweden was somehow the only team with the good log positioned within the main window AND not in the no-open-stint state). After: 66 correct, 3 cleanly hidden (France/Scotland/Uruguay — upstream data has zero open stints for these national teams), 1 still wrong (Spain → "D. Deschamps" — needs `manager_overrides`).

**Out of scope:**
- `manager_overrides` table for Spain (still V2.1 — single team, not blocking June 11 launch).
- Fallback-rate observability metric per rule 2 above (the right structural fix; deferred until a second broad-fallback bug surfaces).
- Splitting the main fetch query per-source (deferred — the targeted top-up for coachs covers the specific risk; we'll revisit if another low-cadence source gets crowded out).

### 73. "The basics" card unlock + the JSONB-null trap + circular player photos in the row context

**What happened (May 20 early morning):** User flagged two team-page polish items on the Sweden team page — (1) no "The basics" card, and (2) no player photos in the "ones to know" expand. Investigation: same graceful-hide-masks-universal-breakage pattern that Lesson 72 surfaced for the manager card.

- For **basics**: migration 004 hand-seeded the card for V1.x's 20 PL clubs (curated voice — Arsenal's 49-game Invincibles, Liverpool's "You'll Never Walk Alone" etc.). The 48 WC countries from migration 032 plus the 3 promoted 2025-26 PL teams from migration 018 (Burnley/Sunderland/Leeds) never got seeded, and the team-page-generator preserved-rather-than-generated (`basics: existingCards.basics ?? null`). iOS gracefully hid the card for null basics. 51 of 71 teams silently lacked the card; we only noticed because Sweden (a higher-profile WC nation) was a user-flagged target.

- For **player photos**: the `photo_url` field had been flowing end-to-end since V2.0 — backend tool schema → iOS `TopPlayer.photoURL` field — and 70 of 71 team_pages rows in production carried headshot URLs (Sweden's Gyökeres/Isak/Lindelöf all set). But the iOS `playerRow()` was rendering text only. The chevron expanded the card; no avatar surface ever consumed the photoURL field.

**Two-prong fix.**

*Backend (basics generation):*

1. Added optional `basics` field to the Claude tool schema with nickname/stadium/fun_fact/talking_point properties. Stadium intentionally outside the `required` array — some smaller WC nations rotate venues across qualifying, and we'd rather omit than guess.
2. Added a new iteration-loop branch for `api_football_teams` (was previously fetched by data-fetcher but never read by team-page-generator). The payload provides deterministic venue.name + venue.city + country.name. This catches venue renames automatically — Sweden's Friends Arena was renamed to Strawberry Arena in late 2024, and our basics output now uses the current name without any hardcoded mapping.
3. Hoisted the existing-team_pages fetch above the prompt build so the prompt could include an `existingBasicsBlock` that flips between PRESERVE-verbatim (curated PL cards stay frozen) and GENERATE-fresh (WC + new PL get Claude-generated).
4. Build step changed from `basics: existingCards.basics ?? null` to `basics: existingCards.basics ?? (input.basics ? { updated_at: now, ...(input.basics as Record<string, unknown>) } : null)`. PL hand-seeded copy wins; otherwise Claude's output gets grafted in. Once stored, the preservation arm wins on subsequent runs.

*iOS (player photos + optional stadium):*

5. New private `playerAvatar(player:size:)` + `playerInitials(name:size:)` helpers inside `TeamPageView`. Mirrors `MeetTeamView.playerAvatar` from the onboarding flow — same AsyncImage + initials fallback + hot-rose tint — at 36pt instead of 72pt. `URLCache.shared` already configured in AppDelegate handles disk caching on re-render.
6. `playerRow(player:tappable:)` switched from a leading `VStack(name + position)` to a leading `playerAvatar` next to that VStack.
7. `BasicsCard.stadium` flipped from `String` to `String?`. Basics block in `cardsSection` now falls back to nickname for the collapsed subtitle when stadium is nil, and wraps the "Home ground" infoLine in `if let stadium = basics.stadium`. PL clubs with stadiums render unchanged.

**The JSONB-null trap surfaced during verification.** First verification query was:

```sql
SELECT count(*) FROM team_pages WHERE content->'cards'->'basics' IS NULL;
```

It returned 0. But 51 rows had `cards.basics` set to a JSONB literal `null` value — not SQL NULL. The two are different in PostgreSQL: `SELECT 'null'::jsonb IS NULL` returns `false`. Correct query is:

```sql
SELECT count(*) FROM team_pages
 WHERE content->'cards'->'basics' IS NULL
    OR jsonb_typeof(content->'cards'->'basics') = 'null';
```

Worth keeping in mind for any future `team_pages.content` audit query — JSONB lookups that return literal-null are common because that's how preservation-style "missing card" patterns get persisted.

**Anthropic credit burn caught us mid-execution.** After the 50-team backfill of basics for the WC countries + 3 promoted PL clubs (Sonnet 4.5 at ~$4-5 of credits burned during the burst), Anthropic returned 429 / "credit balance too low" for every subsequent full-mode call. The Claude client retries with 30s + 2min + 10min backoffs; Supabase Edge Functions kill workers after 150s of idle, so the retry loop trips the timeout before the third retry sleep even starts. Symptom on the user side: every full-mode call returns `IDLE_TIMEOUT` or `WORKER_RESOURCE_LIMIT`.

**This shouldn't have happened.** `team-page-generator` is the only Edge Function still calling Anthropic directly that fires non-trivially. Every other LLM-generated content surface in the system (news/insider/quiz/matchday/live-brief/season-state) is built on the cloud-routine pattern from Lesson 17 onwards — Claude inside the routine session runs the prompt, a `post_*.sh` script writes to Supabase. Cloud routines use the user's claude.ai subscription quota, not the API account's pay-per-token credit balance. The team-page-generator was built before that pattern dominated, never migrated. A 50-team backfill via routines (or a SINGLE one-off `gd-team-pages-backfill` routine that loops in-session) would have cost zero API credits.

**Canada's missing photos — finished via direct SQL UPDATE, no Claude call.** The squad top-up was the wrong tool. The right tool: read the API-Football squad payload that's already sitting in `raw_fetch_logs.api_football_squad`, extract the `player.photo` URLs for the two team_pages players that match by last-name suffix (`J. David` → 8489.png, `C. Larin` → 2001.png), and `jsonb_set` them into `team_pages.content.cards.ones_to_know.players`. Alphonso Davies is genuinely missing from API-Football's current Canada roster (his ACL injury kept him out of recent fixtures, so API-Football trimmed him from the squad endpoint); his row stays photo-less and iOS renders an `AD` initial avatar — graceful by design. Zero credits burned, the patch took ~30 seconds.

```sql
UPDATE team_pages tp
SET content = jsonb_set(
  content,
  '{cards,ones_to_know,players}',
  (
    SELECT jsonb_agg(
      CASE
        WHEN p->>'name' = 'Jonathan David' THEN p || '{"photo_url":"https://media.api-sports.io/football/players/8489.png"}'::jsonb
        WHEN p->>'name' = 'Cyle Larin'     THEN p || '{"photo_url":"https://media.api-sports.io/football/players/2001.png"}'::jsonb
        ELSE p
      END
      ORDER BY ord
    )
    FROM jsonb_array_elements(content->'cards'->'ones_to_know'->'players') WITH ORDINALITY AS x(p, ord)
  )
)
WHERE tp.team_id = 'canada';
```

**Rules:**

1. **A graceful-hide UI fallback hides BOTH legitimate misses AND broken data fetches.** Second time in 48 hours the pattern bit us — first the manager card (Lesson 72), now the basics card. Pattern: add a fallback-rate metric whenever you add a graceful-hide fallback. Lesson 72 rule 2 still stands; we still haven't built the metric.

2. **JSONB `null` is not SQL NULL.** Always check both when auditing JSONB columns. `WHERE x IS NULL OR jsonb_typeof(x) = 'null'`.

3. **Before mass-firing any Anthropic-API-key-backed Edge Function, ask: can this run through routines or direct SQL instead?** The routines pipeline (claude.ai cloud sessions) bills against your claude.ai subscription quota, not the per-token API account. The basics backfill cost ~$4-5 in API credits and bottomed the balance; the same work via a one-off `gd-team-pages-backfill` routine would have been zero credits. The default for any cross-team backfill from here on is: SQL-only if the data is already in `raw_fetch_logs`, routine if it needs LLM judgement, Edge Function only if it's user-triggered single-team on-demand.

4. **The Claude client's retry schedule (30s + 2min + 10min) trips Supabase's 150s idle timeout on the second retry sleep.** If Claude is unhealthy (credit balance, 429, downstream error), the function dies with a misleading `IDLE_TIMEOUT` before the actual Claude error surfaces. The user spent 20 minutes thinking the code was broken when the actual cause was billing. Surface the underlying error: log the response body on the first attempt failure so the user knows whether it's code or credits.

5. **API-Football's `/teams` endpoint is a deterministic source for venue names that survives venue renames.** Friends Arena → Strawberry Arena 2024 happened automatically once we read `venue.name` from the Teams payload instead of relying on Claude's general knowledge. Use the deterministic upstream when it's there.

6. **Direct SQL is the cheapest "backfill" when the upstream data is already in `raw_fetch_logs`.** Canada's missing photos didn't need a regeneration — the squad data was sitting in the DB, the matching was a 3-line CASE expression by last-name suffix, the `jsonb_set` was one statement. Cost: zero credits, ~30 seconds. Whenever you're about to bulk-fire an LLM-backed function, first ask "is the answer already in the DB?" — if yes, SQL it.

**Files touched:**
- Backend: `team-page-generator/index.ts` — basics tool schema slot + `api_football_teams` iteration branch + `existingBasicsBlock` prompt injection + hoisted `existing` query + build-step graft. Commit `11f56c1`.
- iOS: `Views/Team/TeamPageView.swift` (playerRow + playerAvatar + playerInitials + basics-block conditional rendering) + `Models/ContentItem.swift` (BasicsCard.stadium → String?). Commit `8437ede`.
- STATUS.md + this lesson (commit pending).

**Live state after backfill:** 71/71 team_pages rows have a curated basics card (51 Claude-generated this session via the Edge Function — the expensive mistake; 20 PL hand-seeded preserved verbatim). 70/71 rows have player photos on all 3 top players; Canada has 2 of 3 (Davies legitimately absent from API-Football's current roster). Final photo backfill done via direct SQL UPDATE, zero Claude credits burned.

**V2.1 ticket — `team-page-generator` migration to routine pattern.** The Edge Function should be split into two pieces:
1. `gd-team-pages` — a daily cloud routine on claude.ai that iterates teams needing a regen (basics still null, manager `<UNKNOWN>`, stale data) and runs the same prompt in-session against the user's claude.ai quota.
2. `accept-team-page-payload` — a thin Edge Function that does only the JSONB stitching + preservation logic, called by `post_team_page.sh` after the routine produces its tool-call output. Zero LLM call on the Edge Function side.

This is identical to the post_news.sh / post_insider.sh / etc. architecture already in production for every other LLM-generated surface. Migrating closes the per-team-page API-credit drip ($2-6/day at steady state) and means no future cross-team backfill ever burns API credits again.

**Out of scope:**
- `manager_overrides` table for Spain (still V2.1, Lesson 72 carryover).
- Fallback-rate observability metric (rule 1 — still deferred).
- Surfacing the underlying Claude error code through the Edge Function (rule 4 — would have made the credit-balance issue self-diagnose in <30s; deferred as a sweep-up task across all Claude-calling functions).
- Migration of the other Anthropic-API-key Edge Functions (`backfill-analogies`, `content-generator`, `content-reviewer`, `team-season-state-generator`) — most are dormant/gated-off post Lesson 17 routine migration. Audit and clean up separately.

### 74. The cross-team consequence gap — the "Arsenal champion" push that didn't come

**What happened (May 19-21, 2026):** On Tue May 19 at 20:26 UTC, Bournemouth held Manchester City to a 1-1 draw at the Vitality. With Arsenal already on 82 points and one game left, City's failure to win meant their ceiling dropped to 81 — and Arsenal were mathematically Premier League champions for the first time in 22 years. **Arsenal subscribers got zero notification.** No matchday push (Arsenal didn't play). No news (gd-news at 18:30 UTC fired ~2h before kickoff, next fire 06:30 UTC the next morning). Nothing in "Everyone's talking about" surfaced on lock screens. By the time the user noticed, the news routine had already cycled but it wasn't loud enough.

**The diagnostic showed the routine knew.** Reading the `content_items` row for Man City's matchday brief:

```
team_id                     = "man_city"
headline                    = "Haaland salvaged a draw in the 90th, but dropping points at Bournemouth ends City's title chase"
everyone_talking_headline   = "Arsenal confirmed as Premier League champions as City drop points"   ← perfect Arsenal-perspective copy
affected_team_ids           = {man_city, bournemouth}                                                 ← Arsenal MISSING
everyone_talking            = true
```

The LLM in gd-matchday wrote a beautiful Arsenal-angled headline AND flipped the everyone_talking flag. So the model got it right. **The architecture broke between the routine and the push.**

Three structural gaps in priority order:

1. **`notification-sender` only routes by `content_items.team_id`** (lines 100-110 of `notification-sender/index.ts`: `.or("team_id.eq.${teamId},country_id.eq.${teamId}")`). It does NOT read `affected_team_ids` or `everyone_talking` for routing — those fields exist for iOS (crest headers, Everyone's Talking feed surface) but the push router never reaches them. So an item with `team_id=man_city` reaches only Man City subscribers regardless of how the headline reads.

2. **`affected_team_ids` was populated by the routine but never populated FROM consequence-detection logic.** There was no code anywhere in the stack that said "compute the consequence of this result for all teams, then tag the affected ones." gd-matchday's prompt mentions affected teams in an ad-hoc voice-level way but doesn't enumerate consequence-detection.

3. **`gd-news` evening fire was 18:30 UTC** (per Lesson 63's Tier-2 routine quota fit). That's ~2h BEFORE PL evening kickoffs and ~3h before realistic FTs. Same-night news coverage was impossible by construction — the next fire wasn't until 06:30 UTC the following morning. The Arsenal title moment cooled overnight.

**Constraints on the fix** (set by user during planning):

- **No new always-on routines.** Routine quota is 25/day (Lesson 63 budget = ~19/25 with current schedule). The consequence content can't be LLM-generated per-team via a fresh routine.
- **No backfilling May 19.** Treat this as a learning moment — bulletproof the structural gap, don't paper over the specific miss.
- **No more API credit burn** (Lesson 73). Direct `_shared/claude-client.ts` calls are off-limits for cross-team work.

The right shape under those constraints: **pure math in match-watcher + templated content insert + existing notification-sender push pipeline. Zero new routines. Zero LLM calls. Triggered within seconds of FT.**

**The pieces shipped:**

1. **Migration 051**: `ALTER TABLE content_items ADD COLUMN consequence_type TEXT` + partial unique index on `(team_id, consequence_type) WHERE consequence_type IS NOT NULL` + extends `pipeline_health.stage` CHECK with `consequence_fire`. The unique index gives free idempotency — re-detecting the same consequence on the next match is an ON CONFLICT no-op.

2. **`_shared/detect-consequences.ts`** — pure-math detector. Reads latest `raw_fetch_logs.api_football_standings`. With a 5-min age guard on the standings snapshot (to avoid double-counting if data-fetcher has already ingested this result), applies the just-finished fixture to a local copy of the standings. For each non-playing team, computes:

```
min_possible = current_points
max_possible = current_points + 3 × games_remaining

TITLE_WON       — my_min > everyone-else's max
RELEGATED       — my_max < 17th-placed team's min
UCL_CLINCHED    — my_min > 5th-placed team's max
EUROPE_CLINCHED — my_min > 8th-placed team's max
WC_GROUP_WON         — my_min > group's 2nd-placed team's max
WC_KNOCKOUT_QUALIFIED— my_min > group's 3rd-placed team's max
WC_KNOCKOUT_ELIMINATED— my_max < group's 2nd-placed team's min
```

Single dispatch point for both PL (league 39, single 20-team standings array) and WC (league 1, 12-group standings layout — finds the group containing both playing teams).

3. **`_shared/consequence-templates.ts`** — template library. Pure string functions, no LLM. Two body variants per consequence type for seasonal variety. Voice matches `PROMPT.md`'s gf-to-bf older-sister tone. Example TITLE_WON body: `"Done. ${trigger} means it's mathematically impossible for anyone to catch them. Trophy presentation comes Sunday — and so does the chat about how long it's been. Just nod and let him have the moment."` The `${trigger}` is built deterministically from the fixture (e.g. `"Manchester City could only draw 1-1 at Bournemouth"`).

4. **`match-watcher/index.ts` post-matchday hook**. After both home + away `matchday_fire`s succeed, calls `detectConsequences()`, INSERTs each returned consequence row with the appropriate template, and logs every attempt under `stage='consequence_fire'` in `pipeline_health` with proper status taxonomy (success / skipped-deduplicated / failure / threw). Gated on `homeFireOk && awayFireOk` so we never fire consequence content without the underlying matchday content having landed.

5. **News cadence shift via `RemoteTrigger`**. `gd-news` moved from `30 6,18 * * *` → `30 6,22 * * *` UTC; `gd-news-wc` from `35 6,18 * * *` → `35 6,22 * * *`. The evening 22:30 UTC fire lands after the latest realistic PL FT (~21:30 UTC) AND rides the 22:00 UTC `data-fetcher` snapshot (so standings, fixtures_last, and all 6 RSS publishers are fresh). Routine count unchanged at 4 fires/day. UK lock-screen time: 23:30 BST — quiet but readable, perfect "what happened tonight" slot.

**The math worked example (live data):**

```
                rank   points  played  remaining   min   max
Arsenal           1     82      37        1         82    85
Manchester City   2     78      37        1         78    81
Manchester United 3     68      37        1         68    71
...
```

`arsenal_min (82) > others_max (81)` → TITLE_WON ✓. Verified via direct SQL probe against `raw_fetch_logs.api_football_standings` after the May 19 result.

**Rules:**

1. **A routing layer that only knows one identity per content is brittle to cross-team stories.** `notification-sender`'s single-`team_id` routing was correct for 99% of content (a player news item is about one team) but failed catastrophically for the 1% of cross-team consequence stories that ARE the most newsworthy moments of a season. Future routing changes: support a list of routing keys, not a single key, when the content's natural audience is broader than one team.

2. **The LLM knowing something doesn't mean the system knows it.** The gd-matchday routine wrote a perfect Arsenal-perspective headline in `everyone_talking_headline`. That information existed in the database. But no downstream system READ it as a routing signal — it was just decorative copy. When you store information for one purpose (display), don't assume future code paths will route on it. If routing logic NEEDS to read a field, that field needs to be a first-class concept in the routing layer, not a side-effect of content generation.

3. **Deterministic math beats LLM judgement when the math is closed-form.** "Did this result clinch the title for someone else?" is a pure points-arithmetic question. We DON'T need an LLM to answer it — we need to do the math, then USE an LLM (or templates) only to write the prose. The cost-discipline of Lesson 73 + the architectural constraint of "no new routines" forced this shape, and it turned out cleaner than the LLM-judgement path would have been anyway.

4. **News cadence has to fit the league's broadcast clock.** PL midweek FTs land ~21:30 UTC. A `30 6,18 * * *` cron looks reasonable in the abstract but is structurally incapable of covering same-night results — the 18:30 fire is 3h before kickoff. Lesson 63's "twice daily" framing was correct; the times themselves needed to match what the games actually do.

5. **The 5-min age guard prevents a subtle double-count bug.** If `data-fetcher` has just ingested the result before `match-watcher` runs the detector, the standings already include the points delta — applying it again inflates the playing teams' stats and could trip a false-positive UCL_CLINCHED for a 6th-placed team comparing against an inflated 5th-placed team's max. The guard checks `Date.now() - standings.fetched_at < 5 min` and skips `applyResult` when the snapshot is fresh.

6. **Pre-launch consequence types are deliberately PL-and-WC-only.** No EFL, no UCL, no FA Cup. Adding more leagues = more code paths to test = more edge cases on launch night. V2.1 broadens.

**Files touched:**

- Migration: `backend/supabase/migrations/051_consequence_layer.sql` (new).
- Backend: `backend/supabase/functions/_shared/detect-consequences.ts` (new, 220 LOC), `backend/supabase/functions/_shared/consequence-templates.ts` (new, 220 LOC), `backend/supabase/functions/_shared/types.ts` (added `consequence_fire` to `PipelineHealthLog.stage`), `backend/supabase/functions/match-watcher/index.ts` (imports + post-matchday hook + extended `logFire` union).
- Schedule: `gd-news` + `gd-news-wc` cron expressions shifted via `RemoteTrigger`. No repo file change.
- Docs: STATUS.md May 21 section, this lesson.
- Commits: `d8ef854` (backend code + migration); docs commit follows.

**Operational state at time of shipping:** The detector + push pipeline are correct and deployed, but **API-Football account is currently on free tier** and `data-fetcher` returns `"Free plans do not have access to this season"` for both leagues. `match-watcher` runs cleanly but sees zero fixtures, so no FT transitions trigger the new path right now. **Top up at https://dashboard.api-football.com** to resume the live pipeline; the consequence layer kicks in automatically on the next observed FT.

**Out of scope:**

- **WC tiebreaker math** (goal difference / head-to-head / best-3rd cohort). V1 is points-only; ~85% of qualification events resolve on points alone. The remaining ~15% fire one game late (never wrong, just delayed until the deciding result lands). V1.1 if needed during the tournament.
- **Multi-team consequence aggregation.** If three teams all clinch on the same night, each gets its own push to its own subscribers — simpler routing, no aggregation logic.
- **Per-user importance thresholds.** Every consequence pushes to every subscriber of the affected team. Per-user "only the big ones" filtering is a V2.x preference setting.
- **Backfill of last night's Bournemouth-City moment.** User-explicit call — this is a learning moment.
- **PL season-boundary cleanup automation.** First time we hit a new PL season, manual `UPDATE content_items SET consequence_type = NULL WHERE consequence_type IS NOT NULL AND created_at < season_start;` documented in RUNBOOK.
- **`match-watcher` polling-divergence bug** (the Arsenal-Burnley fixture stuck at `status='NS'` 36h after kickoff). Separate ticket — the consequence detector reads from `api_football_standings`, which updates independently, so the polling bug doesn't impair the consequence layer's correctness.

### 75. The dedup-window-off-by-four-minutes — same-event repeats and headline cooldowns

**What happened (May 19-21, 2026):** After Lesson 74 shipped, the user reported getting three Arsenal-title-themed pushes over a 36-hour window:

| When (UTC) | Headline |
|---|---|
| Wed 20 06:37 | "Arsenal are Premier League champions for the first time in 22 years…" |
| Thu 21 06:41 | "Arsenal won the Premier League for the first time in 22 years. Fans are calling…" |
| Thu 21 18:36 | "Arteta could not watch the moment they won the title…" |

The user perceived this as "Arsenal won the league" being pushed three times. The Wed→Thu morning pair is the worst — same news, slightly different prose. The Thu evening Arteta angle is a genuinely new story but the headline still references "won the title" so it lands as a fourth duplicate.

**This was NOT the new consequence layer.** Confirmed via `SELECT count(*) FROM pipeline_health WHERE stage='consequence_fire'` → zero rows. The consequence layer hadn't fired since deploy (API-Football was on free tier from late May 20 until the user topped up Thu evening, so match-watcher saw zero FT transitions). All three pushes came from the existing `gd-news` cloud routine doing its normal twice-daily fire (`30 6,22 * * *` UTC after Lesson 74's news-cadence shift).

**Where the routine's dedup logic broke down.** `PROMPT.md` step 2.c already had a dedup section:

```
c. Dedup check — fetch what this team already has from the last 24h ...
   If a story you're about to write covers the same person/topic/event
   as one already in the response, skip it.
```

Two structural weaknesses surfaced:

1. **The 24h lookback misses by minutes.** Wed 06:37 → Thu 06:41 morning fires are 24h 04m apart. Thursday's `SINCE = now − 24h` query starts at Wed 06:41 UTC → looks AHEAD of the Wed 06:37 item by 4 minutes. The Wed item is **just outside the lookback**. Two morning fires running near the same UTC minute will alternately miss yesterday's item every other day for any major story.

2. **The "same story" rule was structurally narrow.** It told Claude to skip if the EVENT was the same, but didn't handle the "major status-changing event spawns follow-up angles that all reference the event in the headline" pattern. The Arteta-watched-his-son-cry moment is a legitimately new story. It just shouldn't share top billing with "the title" in the headline.

**The fix (single PROMPT.md edit, +16 / -3 lines).** Routines repo `anton-tech43/goaldigger-routines` commit `693bc67`:

- Lookback extended from 24h → 72h. Covers the previous 5-6 fires plus slow-developing stories.
- New MAJOR EVENT cooldown rule added with explicit good/bad headline examples:

```
✅ Acceptable: "Arteta's son cried into his shoulder on the touchline."
❌ Not acceptable: "Arteta couldn't watch the moment Arsenal won the title."
✅ Acceptable: "The post-match speech Saka gave the dressing room."
❌ Not acceptable: "Saka reflects on Arsenal winning the league."
```

The rule: when the lookback contains a status-changing event item (title clinched, team relegated, manager sacked/appointed, major trophy won/lost), follow-ups still publish — but the headline must lead with the new angle and must NOT contain the same key phrase that defined the original headline ("won the league", "are champions", "relegated", "sacked", "lifted the trophy").

A worked example from the May 19-21 Arsenal incident is embedded in the prompt so future runs see exactly what went wrong before the rule landed.

**PROMPT_WC.md inherits this dedup logic verbatim** (its line 7 reads _"dedup logic ... inherited from PROMPT.md verbatim"_), so the single PROMPT.md change covers both `gd-news` and `gd-news-wc` automatically. Zero schema migrations, zero Edge Function changes, zero routine count change.

**Rules:**

1. **Time-window dedup needs slack for cron drift.** Two routines firing at "06:30 daily" can land at 06:30:XX with XX varying by ~5s per day. A `now − 24h` lookback misses yesterday's item the moment XX drifts upward. Use a window that comfortably covers the inter-fire gap plus margin — for a 12h cadence, 72h is the right ratio (covers 5-6 prior fires).

2. **A "same story" rule isn't enough for narrative continuity.** Real news has follow-ups: player reactions, opposition reactions, manager comments. The follow-up angle is a NEW story (deserves to be told). But its HEADLINE shouldn't re-front the original event — otherwise the user reads it as a repeat. The rule needs to be both: skip same-event AND for major events in the lookback, gate the follow-up's headline framing.

3. **Pure prompt fix is cheap when the rule is enforceable by Claude's judgment.** This shipped as 16 lines in PROMPT.md with no system changes. Per Lesson 17 / Lesson 73 / BACKFILL_RULES, content-policy fixes belong in the prompt unless we have evidence the LLM ignores the rule. Add post-script hashing or a dedicated `event_cooldowns` table only if a future major event still slips through.

4. **Worked examples in the prompt are documentation that runs at execution time.** Future routine sessions will see the May 19-21 Arsenal incident in their prompt context. Cheap insurance — Claude reads the example and internalises the rule shape better than abstract instructions alone.

**Files touched:**

- `anton-tech43/goaldigger-routines` PROMPT.md step 2.c (commit `693bc67`).
- This repo: STATUS.md May 21 late-late section + this lesson.

**Cost:** zero. No routines added or rescheduled, no API credits, no migrations.

**Verification:** the next `gd-news` fire (next 22:30 UTC) will output its `[ROUTINE VERSION] 693bc67 ...` preflight log, confirming the new prompt is live. The next time a PL team clinches title / relegation / Europe will be the real-world test.

**Out of scope:**

- **Post-script signature hashing.** Defer until prompt-level rule fails on a future major event.
- **Dedicated `event_cooldowns` table.** Same logic — defer.
- **Backfilling May 19-21 Arsenal pushes.** Already landed; nothing to roll back.
- **Cross-routine dedup** (e.g. an `insider` item and a `news` item covering the same event in the same week). The 72h lookback applies per team but reads any `pipeline_source='routine'` item, so insider items in the window already factor into news routine's dedup. Implicitly addressed.

### 76. The push-eligibility gate — feed-only as a first-class concept

**What happened (May 22, 2026):** A push landed: **"He'll be absolutely buzzing"** / *"Arsenal's captain Odegaard is heading to the World Cup as Norway's captain…"*. The voice opener framed the recipient as having a strong emotional response. But for an Arsenal-ONLY follower, their captain on international duty is fun-to-know trivia — it doesn't move Arsenal's lineup, league position, transfers, or fixtures. He's not buzzing. He's mildly interested.

User clarification, verbatim: _"if he was also a Norway fan this would work for sure but not now, should just be in feed."_

**The architectural gap.** The routine prompt already had voice rules to prevent the WORST cases — no "Brace yourself", no "He'll be unbearable", no sports-app push categories. But the rules calibrated tone based on `emotional_context` (exciting/bad_news/drama/boring). They didn't have a layer above that asking _"is this even push-worthy for the team_id you're writing for?"_. So the routine, classifying the Odegaard story as `exciting` (positive story about an Arsenal player), reached for an emotional opener — correctly per the existing rules, wrongly per the user's mental model of what merits a notification.

Worse, `post_news.sh` REQUIRES `push_title` and `push_text` for every content_item it accepts. So even if the routine had concluded "this is fun trivia, skip the push," it had no way to express that — the choice was binary: ship the item with a push, or don't ship it at all. Most fun-trivia items are still good FEED content (Arsenal fans casually care about Odegaard's international form), so dropping them entirely was the wrong default.

**The fix — push-eligibility as a first-class column.** A new `content_items.push_eligible BOOLEAN NOT NULL DEFAULT TRUE` column. notification-sender's sweep filters `WHERE push_eligible = true`. The routine, when classifying a story under the new TEAM IMPACT gate, sets `push_eligible: false` for items that should publish to the feed but not trigger a notification.

Crucially: `push_title` and `push_text` stay REQUIRED in the schema. They're rendered in non-push surfaces in the app (immersive card, contextual previews, share UI). Feed-only items still write them — they just write them NEUTRALLY:

- ✅ `push_title: "Odegaard, Norway captain"` / `push_text: "Arsenal's Odegaard will lead Norway at the World Cup."`
- ❌ `push_title: "He'll be absolutely buzzing"` / `push_text: "Arsenal's captain Odegaard is heading to the World Cup as Norway's captain…"`

**The cross-team symmetry.** The SAME Odegaard story, when written by `gd-news-wc` for Norway, IS team-impact for Norway followers ("our captain is leading us at the WC"). That item ships with `push_eligible: true` and gets the appropriate Norway-fan opener. Result:

- Arsenal-only followers: see the Arsenal item in their feed, no push. ✓
- Norway-only followers: see the Norway item in their feed AND get a push. ✓
- Arsenal+Norway dual followers: see BOTH items in their feed AND get one push (the Norway one). ✓

Each team's audience gets the angle they care about, at the salience level they care about. No user-level routing logic in notification-sender required — the team_id-level gate plus the two-routine architecture (gd-news for clubs, gd-news-wc for countries) handles it naturally.

**Pieces shipped:**

1. **Migration 052** — `ALTER TABLE content_items ADD COLUMN push_eligible BOOLEAN NOT NULL DEFAULT TRUE` + a long COMMENT explaining why. Backward-compatible: every existing row stays push-eligible, every routine that doesn't know about the new field continues shipping legacy behaviour.

2. **`notification-sender/index.ts`** — added `.eq("push_eligible", true)` to the sweep query (the `else` branch around line 71). Kept the `specificItemId` path unchanged so manual recovery of a feed-only item is still possible — an operator who explicitly targets an item by ID can override the gate.

3. **PROMPT.md** in `goaldigger-routines` (commit `b6a3e19`) — new "TEAM IMPACT gate" section inserted before the existing `emotional_context` calibration. Six ✅ team-impact categories (wins/losses/signings/injuries/fixtures/management) vs six ❌ fun-trivia categories (international duty/off-pitch interviews/anniversaries/tactical analysis/ex-players/training photos), each with explicit good/bad push-field examples. The 2026-05-22 Odegaard incident is embedded as a worked example.

4. **schema.json** — added optional `push_eligible: boolean`. NOT in `required` — omission means DB default TRUE.

5. **`post_news.sh`** — unchanged. The payload passes through to Supabase REST as-is (lines 273-285), so `push_eligible` flows through naturally when the routine includes it.

6. **PROMPT_WC.md** — unchanged. Inherits PROMPT.md's content rules verbatim per its line 7. gd-news-wc automatically picks up the TEAM IMPACT gate; the WC side of the same Odegaard story ships with `push_eligible: true` because "captain confirmed for WC" IS team-impact for Norway followers.

**Rules:**

1. **Push-worthiness is a separate concept from publishability.** The old binary "ship + push" vs "drop entirely" was a false dichotomy. Most apps need a third state: feed-only. We didn't have it for 18 months; the cost was a steady drip of low-value pushes (fun trivia in emotional voice). Add the feed-only concept early in any notification-driven app's lifecycle.

2. **The team_id IS the audience signal.** Notification-sender routes to whoever follows that team_id. So push-worthiness is per-(content_item, team_id) — not per-content-item-globally. The Odegaard story is push-worthy for Norway-tagged audiences, not Arsenal-tagged. Same story, two content_items, two team_ids, two `push_eligible` values. Clean.

3. **A schema-level required field can still be a content-policy variable.** `push_title` + `push_text` stay required for ALL items (they appear in non-push surfaces). For `push_eligible: false` items, they go neutral. We didn't have to remove the requirement to add the gate — the routine just writes both the push fields AND the eligibility flag.

4. **`emotional_context` is a tone calibration, not a push gate.** Conflating the two was the structural confusion. `exciting` describes the EMOTIONAL VALENCE of the story (positive vs negative); the TEAM IMPACT gate is upstream of that, asking whether the story belongs in the push channel at all. Both layers exist now.

5. **Default-TRUE on the column makes the migration safe.** Routines that don't know about `push_eligible` continue shipping at the old behaviour. The gate is OPT-OUT — the routine has to explicitly opt out of pushing for an item. Zero risk of accidentally silencing legitimate pushes during the rollout window.

**Files touched:**

- This repo: `backend/supabase/migrations/052_push_eligible.sql` (new), `backend/supabase/functions/notification-sender/index.ts` (+10 lines, sweep query filter + comment), STATUS.md May 22 section, this lesson.
- `anton-tech43/goaldigger-routines` commit `b6a3e19`: PROMPT.md (+~40 lines, TEAM IMPACT gate + worked example + self-check update) and schema.json (+5 lines, optional property).

**Cost:** zero new routines, zero Anthropic API credits, one additive migration. The notification-sender redeploy was the only deploy required in this repo.

**Verification:** next `gd-news` fire (next 22:30 UTC) will preflight commit `b6a3e19`. Two checks for whether the gate is honoured:

```sql
-- Fun-trivia items should now show up with push_eligible = false
SELECT count(*) FROM content_items
WHERE created_at > '<last fire>' AND push_eligible = false;
-- > 0 expected if any fun-trivia items shipped this run.

-- And those team_ids should have ZERO apns_send rows in pipeline_health
-- for that content_item's window:
SELECT count(*) FROM pipeline_health ph
JOIN content_items ci ON ci.team_id = ph.team_id
WHERE ph.stage = 'apns_send'
  AND ci.push_eligible = false
  AND ph.created_at > ci.created_at
  AND ph.created_at < ci.created_at + interval '5 minutes';
-- 0 expected — push_eligible: false items should never trigger an APNs send.
```

**Out of scope:**

- **Per-user push routing** (only push X story to users who follow BOTH team A AND team B). Would need user-level preference signals in notification-sender's fanout. Defer until V2.x — the team_id-level gate handles the 80% case cleanly.
- **Automatic detection of fun-trivia headlines** via post-script regex/hash. Trust the prompt rule. Add automated enforcement only if real fun-trivia items still ship with `push_eligible: true` after the rule lands.
- **iOS UI distinguishing feed-only items** (e.g. a "no push" indicator). They render identically in the feed; the difference is only at notification dispatch time. No iOS change needed.
- **Backfilling May 22's Odegaard push.** Already landed. Move forward.
- **Lifting the `push_title`/`push_text` requirement for feed-only items.** Keep them required — they appear in non-push surfaces. Marginal extra prompt budget; not worth removing the schema invariant.

### 77. Script-level enforcement of the TEAM IMPACT gate — the prompt rule didn't hold

**What happened (May 22, 2026):** Lesson 76's prompt-level TEAM IMPACT gate failed on its first live fire (06:30 UTC `gd-news`, ~7 hours after the routines-repo commit `b6a3e19`). The routine session correctly loaded the new prompt — confirmed by checking `origin/main` HEAD vs fire time — but the LLM ignored the classification rule. Two pushes landed in the user's lock screen:

| Time UTC | Team | Headline (truncated) | What it actually was |
|---|---|---|---|
| 06:41 | arsenal | "Lewis Hamilton (F1 world champion) shed a tear watching Arsenal clinch the title" | Celebrity-fan reaction to the title win |
| 06:45 | aston_villa | "Prince William was pictured sharing a beer with Aston Villa players" | Royal cameo |

Both shipped with `push_eligible: true` and emotional sister-voice openers. Both pushed via APNs.

The user surfaced it with a screenshot of the Hamilton card and a tight diagnostic: _"How can this come as a push, how is that news AND push worthy"_. Two complaints in one — the story isn't push-worthy, AND the story barely belongs as news for Arsenal followers.

**The Lesson 76 out-of-scope predicted exactly this case:** _"Add automated enforcement only if real fun-trivia items still ship with `push_eligible: true` after the rule lands."_ The fall-back plan was already in place; it just had to be built.

**Same playbook as Lesson 17.** Headline length caps were "soft" in the prompt for the first 6 weeks of routine ops — the model drifted past the 160-char limit on ~67% of items. Lesson 17 added a hard-reject in `post_news.sh` and the drift stopped overnight. Lesson 77 applies the same shape to the TEAM IMPACT classification — except force-downgrade rather than reject (the item itself is fine, only the push channel is wrong).

**The two patterns shipped (commit `82b18aa` in `goaldigger-routines`):**

1. **Non-football observer + reaction verb.** Observer keywords name the SPEAKER's domain (F1 driver / F1 world champion / Formula 1 / NBA / tennis star / Wimbledon / Olympic / boxing champion / rapper / musician / singer / actor / Hollywood / royal / Prince [Name] / Princess [Name] / King [Name] / Queen [Name] / President [Name]). Reaction verbs are any observational third-person verb (shed a tear / cried / congratulated / pictured / gushed / raved / sent best wishes / toasted). If both match in the headline (either order), force-downgrade.

2. **Country possessive + national-team keyword, written for a PL club.** `team_id` is one of the 20 PL clubs AND the headline contains `<Country>'s (squad|World Cup|national team|captain|coaching staff|starting eleven)`. The possessive form is the trigger — "Brazil at the new stadium" doesn't match; "Brazil's World Cup squad" does. Country list mirrors `Country.swift`'s 48-nation enum.

Both patterns fire as a silent **force-downgrade** (`payload = jq '.push_eligible = false' <<< "$payload"`) right before the Supabase REST INSERT. The story still publishes to the feed for the team's subscribers; it just doesn't trigger an APNs send. Every downgrade is logged to stderr with reason + team_id + headline so routine session logs surface every catch.

**False-positive audit against 28 items shipped in the prior 18h:** zero items would have been wrongly downgraded under the new rules.

**Test fixture (10/10 pass):**

- ✓ Hamilton crying (`arsenal`) → downgraded (Pattern 1)
- ✓ Prince William beer (`aston_villa`) → downgraded (Pattern 1)
- ✓ Foden miss England squad (`man_city`) → downgraded (Pattern 2)
- ✓ Maguire out of England squad (`man_utd`) → downgraded (Pattern 2)
- ✓ Odegaard captain (`norway` team_id) → push stays — for Norway followers this IS team-impact
- ✓ Foden miss England squad (`england` team_id) → push stays — same logic
- ✓ Arsenal transfer signing → push stays
- ✓ Arteta crying (Arsenal manager) → push stays — Arteta is a football figure, not on the observer list
- ✓ Liverpool match win → push stays
- ✓ "Arsenal will face Brazil at..." → push stays — no possessive form

**Rules:**

1. **Soft rules in the prompt are unreliable for binary classifications.** "Voice" can be calibrated via prompt rules (Lesson 17 confirmed). But binary gates — should this push? does this exceed N chars? — drift the moment the model judges differently. For binary gates, script-level enforcement is the durable answer. Lesson 17 was the canary; Lesson 76 → 77 is the cementing pattern.

2. **Force-downgrade beats hard-reject when only the channel is wrong.** Lesson 17's headline-cap rejects the whole item because a too-long headline ships nothing usable. Lesson 77's fun-trivia detection downgrades the push channel only because the item is still fine in the feed. Distinguish "the content is broken" (reject) from "the routing is wrong" (silent fix).

3. **Heuristic patterns should be narrow enough to audit by hand.** Two patterns × ~50 keywords each = ~100 ways to trigger. Tested against 28 real items + 10 fixtures = 38 known-shape cases. Tighten the regex if a real false-positive surfaces; widen it if a real fun-trivia case slips through. The narrow scope is the feature.

4. **Log every catch loudly.** Every downgrade writes to stderr with reason + team_id + headline. Routine session logs become the audit trail. If the next morning's audit shows a downgrade you disagree with, the data to argue back is in the log.

5. **Don't ship the V2 of a fragile fix during exhaustion.** The Lesson 76 out-of-scope explicitly said "Add automated enforcement only if real fun-trivia items still ship after the rule lands." The fall-through-to-enforcement plan was logged before the failure. When the failure hit, the answer was already filed. Lesson: when shipping a soft rule, write down what the hard backup looks like — half the work of the V2 is done.

**Files touched:**

- Routines repo `goaldigger-routines` commit `82b18aa`: `post_news.sh` (+54 lines, two pattern blocks after the existing length-validation section).
- This repo: STATUS.md May 22 morning section + this lesson.

**Cost:** zero new routines, zero API credits, zero schema migrations.

**Verification:** next `gd-news` fire is tonight at 22:30 UTC. Two checks:

```sql
-- Items downgraded by Lesson 77 — should match fun-trivia patterns
SELECT to_char(created_at AT TIME ZONE 'UTC', 'HH24:MI') AS t,
       team_id, push_eligible, substring(headline FROM 1 FOR 80) AS headline
FROM content_items
WHERE created_at > now() - interval '90 minutes'
ORDER BY push_eligible, team_id;

-- No apns_send for push_eligible=false items
SELECT count(*) AS feed_only_leaks
FROM content_items ci
JOIN pipeline_health ph ON ph.stage='apns_send' AND ph.team_id=ci.team_id
 AND ph.created_at BETWEEN ci.created_at AND ci.created_at + interval '5 minutes'
WHERE ci.push_eligible = false AND ci.created_at > now() - interval '90 minutes';
-- Expected: 0
```

**Out of scope:**

- **Pattern 3 — player's CLUB news when writing for the COUNTRY** (e.g. Vinícius's Real Madrid fixture absence written for Brazil-tagged audience). Requires a player→country map; defer to V2.1.
- **Anniversary nostalgia detection.** Low frequency; skip.
- **Ex-player commentary catching.** Would need a recently-active-players list. Skip.
- **Hard-rejecting the writing of fun-trivia items entirely.** The force-downgrade keeps the items in the feed; user said _"should just be in feed"_. Don't go further than that until evidence suggests the feed surface is itself harmed by these items.

### 78. Pre-tournament preview content — primer for an empty WC feed + calendar tap detail

**What prompted this (May 22, 2026):** The World Cup kicks off June 11. The user base will lean UK-heavy. **Right now England's feed is empty** — no PL season news (England aren't in the PL), and `gd-news-wc` has nothing newsworthy because the tournament hasn't started. A first-time UK user downloading the app today opens it, picks England as their country, lands on a barren feed. Poor first impression.

User's framing: _"Since there are no news until WC starts we should fill the page with something else, something that creates value for the first time user."_ Plus _"this info about the games could also be in the calendar when you click on the game"_ — the same content powers a second surface, the Calendar tab's previously-inert fixture rows.

**The architecture (one source of truth, two surfaces).** Pre-tournament preview content lives as **content_items rows** (no new content type — reuse `type='news'`). Two surfaces consume them:

1. **Feed** — the team's regular feed picks these up via the existing pipeline. They render as feed cards alongside any other team content.
2. **Calendar tap** — tapping a fixture row in the Calendar tab navigates to the matching preview via the existing `ContentDetailDestination` / `ContentDetailView`. A new optional column `preview_fixture_id TEXT` on `content_items` links a preview to its specific upcoming fixture.

Each WC country gets **4 preview items**:
- 1 group overview ("Group F at a glance — Croatia, Ghana, Panama")
- 3 per-opponent previews (one per group game)

All `push_eligible: false` (Lessons 76+77). These are evergreen feed content, not notification-worthy. The user downloading today needs a feed that has something to read; they don't need a push about Croatia's preview.

**Synthetic fixture-id linkage.** The `upcoming_fixtures` entries in `team_pages.content.cards` don't carry an API-Football fixture id today (only `date`, `opponent`, `venue`, `importance_dots`, `importance_label`). To link a content_item to a specific fixture without a schema change to `upcoming_fixtures`, the linkage is a synthetic string of the form:

```
"<team_id>:<iso-date>:<opponent-slug>"

e.g. "england:2026-06-17:croatia"
```

Built identically on both sides:
- **SQL INSERT**: sets `content_items.preview_fixture_id` to this string at write time.
- **iOS lookup** (`TeamPageView.previewKey(for: fixture)`): builds the same string from the `UpcomingFixture.date.prefix(10)` + `opponent.lowercased().replacingOccurrences(of: " ", with: "_")`.

Deterministic, stable across minor timestamp drift, doesn't require API-Football's fixture.id to be plumbed through to iOS.

**iOS wiring.** The His Team tab's NavigationStack already had a child view (`TeamPageView`) but no registered `.navigationDestination(for: ContentDetailDestination.self)` — that destination handler lived only on the Feed tab. Adding it to the His Team tab is one block; ContentDetailView is unchanged. `TeamPageView.calendarRow` becomes conditionally wrapped in `NavigationLink(value: ContentDetailDestination(...))` when a matching preview exists, and renders the same visual but tap-inert when it doesn't (graceful for friendlies and post-group fixtures). The chevron-right hint on the row signals tap affordance only when a preview exists.

**V1 — England as canonical.** Four hand-curated content_items INSERTed via SQL. Zero LLM cost. Quality entirely under our control. Acts as the gold-standard reference for the V1.1 routine.

Content shape per item:
- Headline (≤280 chars) — narrative, not wire-service
- Body (2-4 short paragraphs) — storyline, key opponent player to watch, England's task, what to expect at the pub
- Talking points (3) — variety rule (at most one "Ask him"), mix of Tell/Notice/Ask
- Immersive headline (lowercase, ~22 chars/line per the immersive-headline rule)
- Immersive context (analogy in GoalDigger voice)
- Push fields (neutral fact-only, push_eligible=false so they never fire but the schema still requires them)

All voice rules from PROMPT.md held: British register, no emoji, no crisis-counsellor "He'll be unbearable" framing, no broadcast-question TP1 opener.

**V1.1 — template across the 47 other WC countries (after Tuesday submission, before June 11).** Build a one-off `gd-wc-preview` claude.ai routine that loops the 48 WC countries, reads their group + opponents + key squad data from `team_pages.content` + `raw_fetch_logs`, writes 4 content_items per country in the same shape, POSTs via Supabase REST. Fires ONCE. Zero API credits (routine quota, not API account — per `BACKFILL_RULES.md` discipline). Optional refresh after each group game; knockout-stage previews are V1.2.

**Rules:**

1. **Empty-feed-day-one is a real product problem.** Apps that ship with an empty feed for a country's launch day get a bad first impression and get deleted. Pre-tournament evergreen content is the cheapest, most controllable fill — write it once, ships silently to feed, gives the user 5 minutes of curated reading before any live news.

2. **One content_item type can power multiple iOS surfaces with a single optional linkage column.** Adding a new content `type='preview'` would have required iOS rendering changes, type-specific filtering, possibly new view components. Reusing `type='news'` with `preview_fixture_id` as a marker for the Calendar surface kept the iOS code tiny. **Linkage columns are cheaper than type proliferation.**

3. **Synthetic IDs beat scheme migrations when the data is locally derivable.** The `team_pages.content.cards.upcoming_fixtures` entries lack a stable id today. Adding one would have required schema change + backend regen + iOS model update. Instead, both sides derive the same synthetic id from `team_id + date + opponent` — zero migration on the existing data, full bidirectional lookup.

4. **Hand-curate the canonical, template the rest.** England is the V1. The voice, structure, depth all set the bar for what the 47 other WC countries should match. The routine that writes them later doesn't have to invent the shape; it has 4 strong reference items to pattern-match against.

5. **`push_eligible=false` is the right default for pre-launch evergreen content.** Per Lessons 76+77, anything that isn't direct team-impact stays in the feed only. Pre-tournament previews are 100% in this bucket — the user discovers them on app open, doesn't need a push.

**Files touched:**

- `backend/supabase/migrations/053_content_preview_fixture_id.sql` (new) — `preview_fixture_id TEXT` column + partial index.
- `ios/GoalDigger/Models/ContentItem.swift` — `previewFixtureId: String?` field + CodingKey + custom-decoder line.
- `ios/GoalDigger/Services/APIClient.swift` — `fetchPreviewItems(teamId:)` (single REST call filtered on `preview_fixture_id=not.is.null`).
- `ios/GoalDigger/Views/Team/TeamPageView.swift` — new `@State previewByFixtureId`, `fetchPreviewItems()` + `indexPreviews()` + `previewKey(for:)` helpers, `calendarTab` + `calendarRow` accept preview and wrap in NavigationLink conditionally, chevron hint when tappable.
- `ios/GoalDigger/App/GoalDiggerApp.swift` — His Team tab's NavigationStack gets `.navigationDestination(for: ContentDetailDestination.self)` so the new Calendar-tap NavigationLink lands somewhere.
- Direct SQL INSERT — 4 England content_items via `/tmp/england_previews.sql` (committed inline as part of this lesson narrative; the live rows are in Supabase, not in git).

**Cost:** zero new routines, zero Anthropic API credits. One additive migration. Four hand-curated content rows. Build time ~3 hours.

**Verification:**

```sql
-- Column + index exist
\d content_items   -- preview_fixture_id present
\di+ idx_content_items_team_preview

-- 4 England previews land
SELECT count(*) FROM content_items
WHERE team_id='england' AND preview_fixture_id IS NOT NULL OR
      (team_id='england' AND headline ILIKE 'England''s World Cup starts%');
-- Expected: 4

-- iOS build green
xcodebuild -scheme GoalDigger -destination 'iPhone 17 Pro,OS=26.4' build

-- Sim verify (manual, owner: user before submission)
-- 1. Open app → switch context to England
-- 2. Feed shows 4 new preview cards
-- 3. Switch to His Team tab → Calendar tab
-- 4. Tap each group fixture (Jun 17 Croatia / Jun 23 Ghana / Jun 27 Panama)
-- 5. Each opens the matching ContentDetailView with full body + talking points
-- 6. Tap friendlies (Jun 6 NZ, Jun 10 Costa Rica) → no navigation (graceful)
```

**Out of scope:**

- **The other 47 WC countries.** V1.1 — one-off `gd-wc-preview` routine. Fires once before Jun 11.
- **Knockout-stage previews.** Defer until group standings settle. V1.2.
- **Refreshing preview content after each group game.** Static V1; dynamic refresh in V1.2.
- **A new content `type='preview'`.** Reuse `type='news'` with `preview_fixture_id` as the marker. Smaller blast radius on iOS rendering.
- **Push notifications for previews.** Per Lessons 76+77, fun-tier evergreen content is feed-only.
- **Per-user preview customisation.** Implicit via `team_id` scope.

### 79. Launch-day DB security audit — the SECURITY DEFINER function that leaked the service key

**What prompted this (May 27, launch day):** User asked, before public users hit the DB, _"do we need to double check that our database is safe, RLS and so on?"_ Yes. A full RLS + privilege sweep found three classes of issue, one of them catastrophic.

**🔴 The catastrophic one — `get_cron_service_key()` anon-EXECUTEable.** This SECURITY DEFINER function (migration 020) decrypts and returns the `cron_service_key` from `vault.decrypted_secrets` — i.e. the service-role JWT. It exists so pg_cron jobs can authenticate their `net.http_post` calls to Edge Functions. The trap: **Postgres grants EXECUTE to PUBLIC by default on every function at creation time, and PostgREST exposes public-schema functions as RPC endpoints.** So the function was reachable as:

```
POST /rest/v1/rpc/get_cron_service_key
apikey: <publishable key — extractable from the iOS binary>
```

→ returns the service-role key → bypass ALL RLS, read/modify/delete every table, dump the entire user base. Total compromise, exploitable by anyone who decompiles the app. **Verified the hole was live** (the function returned the 219-char JWT) and **verified it closed** after the fix (`permission denied for function` from the publishable key).

Fix (migration 055): `REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC, anon, authenticated` on `get_cron_service_key` + two internal diagnostics (`get_device_tokens_acl`, `get_pipeline_diagnostics`) that had the same default-PUBLIC-grant exposure. pg_cron is unaffected — it runs as the postgres owner, which executes regardless of the PUBLIC grant.

**🔴 Two tables with RLS OFF — `match_status_state` + `analogy_rejections`.** Shipped with RLS disabled AND full anon grants (incl. TRUNCATE/DELETE). Anyone with the publishable key could TRUNCATE `match_status_state` → match-watcher's fixture-state ledger gone → no FT detection → no matchday/live pushes. Fix (migration 054): ENABLE RLS + service_role-only policy + REVOKE anon/authenticated grants. Neither table is touched by the iOS app directly (both server-side only), so zero client risk.

**🟠 `device_tokens` anon SELECT/UPDATE (`USING true`).** Accepted for launch. The anon SELECT is genuinely needed for the `Prefer: resolution=merge-duplicates` registration upsert — Postgres's ON CONFLICT path needs SELECT visibility on the conflicting row, and without it registration 401s (the exact bug migration 030 fixed). The exposure is medium-severity griefing (enumerate the follow graph; mass-reassign teams or set is_active=false to silence pushes), not a data breach — APNs tokens are useless without the .p8 key, no passwords/payment/identity. Fast-follow: route token writes through the `register-dev-device` Edge Function (service_role) then revoke anon entirely.

**Confirmed safe (no action):**
- All other 14 public tables already RLS-locked correctly.
- Vault secrets live in the `vault` schema — PostgREST only exposes `public` (+ `graphql_public`), never `vault`.
- `pg_net` http functions (http_get/post/delete): owned by `supabase_admin`, and the `net` schema isn't in Supabase's default REST-exposed schemas → anon can't reach them via the API. The default PUBLIC EXECUTE grant is moot for a REST attacker. Defense-in-depth revoke deferred (not exploitable from the attack surface; would also need supabase_admin ownership to revoke).
- `everyone_talking_daily` view (postgres-owned, anon SELECT): aggregate COUNT()s over content_items only — no PII, benign.

**Rules:**

1. **SECURITY DEFINER + the default PUBLIC EXECUTE grant + PostgREST = a service-key leak waiting to happen.** Any SECURITY DEFINER function in the `public` schema that touches secrets/privileged data is an RPC endpoint callable by `anon` unless you explicitly `REVOKE EXECUTE ... FROM PUBLIC`. This is the highest-leverage thing to audit in any Supabase project. The vault-accessor pattern (definer function reading `vault.decrypted_secrets`) is especially dangerous — it MUST have its EXECUTE locked the moment it's created. Migration 020 created it without the revoke; it sat exposed until this audit.

2. **Verify from the attack surface, not just the grant table.** Reading `has_function_privilege('anon', ...)` tells you the grant; actually hitting `POST /rest/v1/rpc/...` with the publishable key tells you the EXPLOIT. Do both — the live test caught that the fix worked end-to-end (permission denied) AND that the legit path (anon reading published content_items) still worked.

3. **RLS-disabled is wide-open in Supabase, not closed.** A table without RLS + the default anon grants is fully readable/writable/TRUNCATEable by anyone with the publishable key. "No policy" doesn't mean "no access" — it means "no restriction." Every public table needs RLS ON with explicit policies.

4. **"Needed for a legit flow" doesn't mean "leave it wide" — but sometimes you accept it with eyes open.** device_tokens anon SELECT is needed for the upsert; the proper fix (Edge Function registration) is real work and risky on launch day. Documenting the accepted risk + the fast-follow is the honest call, vs. either silently leaving it or breaking registration hours before launch.

5. **Launch day is the right forcing function for this audit, but it should have happened at every `SECURITY DEFINER` / `CREATE TABLE` along the way.** The holes existed for weeks (migration 020 = the vault accessor, the no-RLS tables). A standing checklist — "new table → RLS + policy; new definer function → REVOKE PUBLIC" — catches these at write time instead of in a panicked launch-day sweep.

**Files touched:**
- `backend/supabase/migrations/054_lock_open_tables.sql` (new) — RLS + revoke on the two open tables.
- `backend/supabase/migrations/055_revoke_definer_fn_execute.sql` (new) — revoke anon/authenticated/PUBLIC EXECUTE on the three definer functions.
- STATUS.md launch-day security-audit section.

**Cost:** zero app changes, two additive migrations, ~zero risk (cron + legit app paths verified intact post-fix).

**Out of scope / fast-follow:**
- device_tokens → Edge Function registration + anon revoke (this week).
- pg_net PUBLIC-grant revoke (defense-in-depth; needs supabase_admin; not REST-exposed so low priority).
- A standing "new table/definer-function security checklist" baked into the migration workflow.

### 80. The full security sweep — caller-auth gate, the verify_jwt trap, and a fix that nearly broke the crons

**What prompted this (May 27-28, launch window):** After Lesson 79 closed the service-key RPC leak + the no-RLS tables, the user asked for the rest of the threat model — "any other cyberattacks?" — and then "we will do all fixes, both red, orange and lower." This lesson is the full sweep.

**🔴 The biggest live hole: unauthenticated Edge Function invocation → cost-drain.** `team-page-generator` (and 10 other server-only functions) had NO internal caller check. Confirmed live: a POST with **zero auth header** ran the function (returned "Team not found", not 401) — so an attacker could loop `POST {team_id:"arsenal"}` and bill the Anthropic balance ~$0.045/call indefinitely. Same primitive against `data-fetcher` drains the API-Football quota; against `morning-push`/`notification-sender` spams APNs.

**The verify_jwt trap (the insight that reshaped the scope).** I initially assumed `data-fetcher` was safe because it 401'd on a no-auth request. Wrong: Supabase's gateway `verify_jwt` flag only validates a JWT is **present + signed + unexpired** — NOT its role. The anon/publishable key is a valid JWT that **ships in the iOS binary**. So `verify_jwt: on` blocks no-auth requests but NOT anon-key requests. **Any sensitive function without an INTERNAL service-key check is exploitable by anyone with the anon key, regardless of the deploy flag.** The fix had to be an internal check on every server-only function, not a deploy-flag toggle.

**The fix that nearly broke everything — key fragmentation.** Built `_shared/require-service-auth.ts` (reject unless the Authorization bearer matches the service key) and gated `team-page-generator` first. Test: the service key got **401**. The cause — the May-11 rotation left THREE distinct service credentials in play:
- `SERVICE_KEY` (sb_secret_*) — what `triggerFunction` + the DB client use.
- `SUPABASE_SERVICE_ROLE_KEY` (auto-injected legacy JWT) — what the Edge runtime exposes.
- The Vault `cron_service_key` — what pg_cron sends via `get_cron_service_key()`, byte-identical to `backend/.env`'s key but DIVERGED from the auto-injected one.

A naive `== SUPABASE_SERVICE_ROLE_KEY` check rejects every cron → would have 401'd `match-watcher` (every 60s), `notification-sweep`, `data-fetcher`, `morning-push` → **total push + pipeline outage on launch day.** Caught only because I gated ONE function first and tested before rolling out. Fix: the helper accepts the union of all three (`SERVICE_KEY ∪ SUPABASE_SERVICE_ROLE_KEY ∪ CRON_AUTH_KEY`), where `CRON_AUTH_KEY` is a new secret set to the Vault cron key value. Then gated all 11, redeployed, and **verified the live crons stayed 200 (watched `net._http_response` for a post-deploy cron tick: 200 ×2, zero 401s)** before declaring done.

**🟠 device_tokens — the narrowing that broke registration.** Tried column-restricting anon SELECT to `apns_token` to kill the follow-graph enumeration. It 401'd the `merge-duplicates` registration upsert (PG's ON CONFLICT path needs SELECT on more than the conflict key). Verified live (registration 401'd, then 201'd after restoring full table SELECT), backed it out. What DID land: revoked anon's `DELETE/TRUNCATE/TRIGGER/REFERENCES` (it had a table-wipe TRUNCATE grant). Full follow-graph lockdown moves to Wave 2 (route registration through an Edge Function, then revoke anon SELECT/UPDATE).

**🟠 Content-safety guard.** content-reviewer is gated off → routine output publishes unfiltered, and the routines ingest attacker-influenceable RSS (prompt-injection vector to every subscriber). Added a hard-reject guard to `post_news.sh` (injection signatures + PII shapes), same enforcement shape as Lesson 17/77. 8/8 fixture tests.

**🟡 pg_net revoke — correctly NOT done.** The plan called for revoking PUBLIC EXECUTE on `net.http_*` as defence-in-depth. On inspection: `net` isn't REST-exposed (no live exploit), AND a blanket `REVOKE FROM PUBLIC` would strip `postgres`'s ability to call `net.http_post` in the cron jobs → kill the entire pipeline. Skipped deliberately; revisit post-launch with role-scoped grants. **A defence-in-depth fix that risks a production outage on a non-exploitable surface is a bad trade.**

**Rules:**

1. **Supabase `verify_jwt` ≠ authorization.** It authenticates (valid JWT) but doesn't authorize (role). The anon key passes it. Treat every public Edge Function as anon-reachable and add an internal service-key check to the ones that do privileged/paid work. The deploy flag is not a security boundary.

2. **Gate ONE function, test all its real callers, THEN roll out.** The cron-key mismatch would have caused a total launch-day outage if applied to all 11 at once. Testing team-page-generator first surfaced it cheaply. Never batch-apply an auth change across a fleet without proving the caller contract on one.

3. **Know exactly what credential each caller presents before locking a door.** Key rotation fragments the credential set silently — the Vault key, the auto-injected key, and the custom secret can all differ. Fingerprint them (hash, don't print) and make the gate accept the real set. Verify in production (`net._http_response` post-deploy) — a green unit test doesn't prove the cron still authenticates.

4. **Verify a hardening change didn't break the legit path, every time.** The device_tokens SELECT-narrowing and the auth gate both LOOKED correct and both broke a real flow (registration upsert; cron auth). Only the live re-test caught them. For security changes especially: test the attack is blocked AND the legit user still works.

5. **A defence-in-depth fix on a non-exploitable surface is not worth a production-outage risk.** pg_net wasn't reachable from the attack surface; revoking it risked the cron pipeline. Skipping was the disciplined call. Match the fix's risk to the threat's reality.

**Files touched:**
- New: `_shared/require-service-auth.ts`. Gate added to 11 functions. Migration 056 (device_tokens grants). New Supabase secret `CRON_AUTH_KEY`.
- Routines repo `520b4d3`: `post_news.sh` content-safety guard.
- This repo: STATUS launch-day audit table + this lesson.

**Verification:** no-auth + anon-key → 401 on all 11; service key → runs; live crons → 200 (zero 401s post-deploy); registration upsert → 201; content filter 8/8; published-content read (anon) → still works.

**Out of scope / Wave 2-3:**
- device_tokens full lockdown (Edge Function registration + revoke anon) — needs iOS change.
- delete-my-data rate-limit / token-ownership.
- OpenAPI introspection restriction, Cloudflare rate-limiting, dashboard 2FA, key-rotation runbook — platform/user actions.

### 81. Secret-audit + filter-injection verification pass — both clean, and why a non-fix is still worth writing down

**What prompted this (May 28, launch window):** After Lessons 79-80 closed the live holes, the user asked "what other security checks do you recommend?" Two from that list were runnable read-only against the working tree: (1) confirm the iOS app ships only the publishable key, never the `.p8`/service/API-Football secret; (2) confirm no PostgREST raw-filter (`.or()/.filter()`) interpolates attacker-controlled input. Both came back clean — but the *reasoning* is the lesson, because "looks clean" and "is clean" diverge exactly where injection lives.

**iOS secret audit — method + result.** `grep -rnE 'sk-ant-|sb_secret_|BEGIN PRIVATE KEY|api-sports|service_role|API_FOOTBALL' ios/`. Every hit triaged: the only secret-shaped match is `sb_publishable_*` (the anon key, which is *meant* to ship). Every `api-sports.io` hit is the **public image CDN** (`media.api-sports.io/football/{teams,players}/{id}.png`) — unauthenticated URLs, no key attached. `git check-ignore` confirmed the real `Configuration.xcconfig` is ignored; only `Configuration.xcconfig.example` (placeholder) is tracked. No `.p8/.pem/.env/.key/.p12/.mobileprovision` tracked. PASS.

**Filter injection — the triage that matters.** 3 sites interpolate into a PostgREST raw-filter string. The risk: PostgREST's `.or("team_id.eq.${x}")` is *string-built*, so if `x` were attacker-controlled and could carry `,`, `.`, `(`, `)`, `=`, an attacker could rewrite the filter (e.g. broaden a `device_tokens` read). The triage:
- `live-brief-current:68` — the ONLY site reachable with **request input** (`?team_id=`). It validates `/^[a-z_]{2,32}$/` BEFORE the `.or()`. That allow-list rejects every character injection needs. Safe.
- `notification-sender:128`, `morning-push:147` — interpolate `item.team_id` / `fix.home_team_id`, which are **DB-sourced**, not request input. Three independent reasons they're not exploitable: (a) both functions are now behind `require-service-auth` (Lesson 80); (b) anon **can't write the source tables** — `content_items` has no anon INSERT policy (SELECT-published only, mig 001), fixtures are server-written; (c) even a successful injection only widens a push fanout — nothing is returned to the caller, so there's no exfiltration. Defense-in-depth at most.
- The other 3 anon iOS endpoints (`quiz-current`, `team-season-state`, `delete-my-data`) all validate input (`/^[a-z_]{2,32}$/`, or `/^[a-fA-F0-9]{64}$/` for the apns_token) AND use parameterized `.eq("col", value)` — which the supabase-js client sends as a literal value, not a filter expression. Safe by construction.

**The decision: declined the optional guard.** The "fix" on the table was a shared `isValidEntityId()` applied to the two DB-sourced sites. Declined — the values are DB-sourced + constrained + the functions are service-gated, so there is no live path to mitigate. Writing a validator for an input that can't be attacker-controlled is motion without protection.

**Rules:**

1. **Injection risk = raw-filter string + attacker-controlled value. Both required.** `.or()/.filter()/.match()` build a filter *expression* from a string → injectable. `.eq("col", value)` sends `value` as a literal param → not injectable regardless of contents. When auditing PostgREST, grep for the raw-filter forms specifically, then for each one ask "where does the interpolated value originate?" A raw filter over a DB-sourced value is a different risk class than one over `?team_id=`.

2. **Trace provenance before severity.** The same `.or("...${teamId}...")` line is CRITICAL if `teamId` is `req` input and a non-issue if it's a server-written DB column behind an auth gate. The line looks identical; the data flow decides. Don't grade the pattern — grade the source.

3. **An allow-list regex at the boundary closes a whole class.** `/^[a-z_]{2,32}$/` on every user-supplied entity id means no downstream raw-filter, log line, or query can be injected through it — one cheap check, applied at all 4 anon endpoints, removes the need to reason about each sink. Validate at the door, not at each sink.

4. **A non-fix is still worth recording.** Declining the redundant validator is a decision a future reader (or auditor) will second-guess. Writing down *why* it's safe (provenance + gate + no-exfil) is the durable artifact — it prevents both the "why didn't we guard this?" re-litigation and the reflexive "add validation everywhere" that buries the real boundaries in noise. Same discipline as Lesson 80's pg_net skip: documenting the deliberate non-action is part of the audit.

**Files touched:** STATUS.md (audit-table verification row + dateline) + this lesson. No code, no migration, no deploy.

**Verification:** read-only — grep across `ios/` + `backend/supabase/functions/`, `git check-ignore` on the xcconfig, and an RLS/grant trace confirming anon has no INSERT on `content_items`/fixtures. Nothing to re-test live (no behavior changed).

### 82. Speculation + opaque-teaser push downgrade — Arsenal user feedback turned into two new script patterns

**What prompted this (2026-05-28, launch window).** Real Arsenal-user feedback on the last seven days of pushes. Four items, four complaints:

| Push title | Push text | Feedback |
|---|---|---|
| "He'll quote this all week" | "Four Arsenal players told the BBC it's already written. He'll repeat this all week." | "How come this is a push? Also a bit unclear." |
| "He's going to have opinions" | "Arsenal want £20m for striker Jesus this summer." | "Nobody cares about our third striker." |
| "He'll have spreadsheets out" | "Arsenal reportedly targeting Villa winger Rogers this summer." | "Nobody cares." |
| "He'll have opinions" | "Arsenal reportedly eyeing Villa midfielder Rogers this summer." | "Potentially, nothing of value here. Would skip." |

Three of four are the same root cause: **speculative transfer rumours dressed up with the strong "He'll [verb]" certainty voice.** All three use "reportedly / want £ / eyeing." None are confirmed moves. The fourth is a separate failure mode: **opaque teaser** — the push hints at his reaction without conveying what the news IS ("it's already written" — what is?).

The TEAM IMPACT gate (Lesson 76) classifies any signing/sale as team-impact, but it doesn't distinguish *confirmed* from *speculative*, or *first-XI* from *third-choice*. So speculation slipped through into pushes wearing the same emotional opener as a real signing.

**The fix — same shape as Lesson 77 (soft prompt rule + hard script enforcement).** Two new force-downgrade patterns in `post_news.sh` and a paired PROMPT.md gate:

- **Pattern 3 — speculative transfer rumour.** Regex on `headline + push_text` for `reportedly|rumou?red|eyeing|interested in|linked with|set to (bid|swoop|offer|move)|according to (reports|sources)|wants? to (sign|land|bring in)|wants? £|wants? \$[0-9]|in the market for|considering a (move|bid)`. Hit → `push_eligible=false`. Confirmed moves (announced, signed, medical complete) don't match, stay push-eligible.
- **Pattern 4 — opaque-teaser headline.** Regex for `it'?s already written|you won'?t believe|wait until you hear|you have to (see|hear) this`. Starter list — iterate as new variants surface.
- **PROMPT.md** gains a **TRANSFER PUSH-WORTHINESS gate** (CONFIRMED vs SPECULATIVE + hedged voice for the latter — "he might have opinions" rather than "He'll have spreadsheets out") and a **HEADLINE CLARITY rule** ("push_text must state the news; title can tease his reaction, text must convey the event"). Self-check list extended.

**Tested 13/13 before shipping.** All four user-flagged items downgrade (3 by speculation, 1 by teaser). Nine legitimate pushes from the same week (UCL final ×2, Arteta MOTS, Sunday brief, "Arteta says he knew in March", Hamilton-and-Odegaard, Arteta-BBQ, Kroupi-chelsea-tag) all correctly allow. Hamilton + Odegaard remain caught upstream by Lesson 77 Patterns 1+2 — Lesson 82 doesn't double-handle them.

**Rules:**

1. **The same enforcement shape keeps working: prompt rule + script backup.** Lesson 17 (headline-cap), Lessons 76/77 (fun-trivia gate), and now Lesson 82 (speculation + teaser) all use the same pattern — write the soft rule in PROMPT.md to teach the model the principle, then enforce the binary decision in `post_news.sh` so drift can't reach the lock screen. Three independent confirmations now: when a soft prompt rule guards a binary outcome (push y/n, length cap, voice category), pair it with a script-level check. The script is the durable layer.

2. **"He'll [verb]" is the certainty voice — match it to certain news.** The Lesson 76 emotional opener was framed as a TEAM IMPACT distinction (does the story affect the team?). Lesson 82 adds a CERTAINTY distinction: even when the story does affect the team, if it's *speculation* about the team, hedge the voice. "Arsenal want X" is a price expectation, not a deal — write it like a maybe, not like a foregone conclusion. The voice carries information about confidence; mismatched confidence reads as hype and erodes trust.

3. **The reader who sees ONLY the push must know what happened.** Push_text is the entire surface area for users who don't open the app — the lock-screen preview is the product for them. "He'll quote this all week" + "it's already written" tells the reader something happened, but not what. That's bait, not news. The HEADLINE CLARITY rule encodes the test: does push_text contain a concrete subject + verb + object describing the event? If no, rewrite. Title can tease the reaction; text states the event.

4. **Listen to user feedback like it's an audit log.** The Arsenal user gave exact phrasing on four pushes — "nobody cares," "would skip," "a bit unclear." That's a labelled dataset. The patterns derived directly from those four items, then verified against the prior week's 15 pushes for false positives, are way more reliable than abstract principles about "speculation is bad." Real complaints → concrete patterns → fixture-tested → shipped. Same loop as Lessons 17, 77.

**Files touched:** routines repo `1222ed7` — `post_news.sh` + `PROMPT.md`. This repo — this lesson + STATUS note.

**Verification:** 13/13 fixture tests passed pre-commit (4 user-flagged → downgrade, 9 legit → allow). Live verification deferred to the next routine fire — confirm in the morning that any new speculation items ship with `push_eligible=false` and any confirmed-transfer items still push. If false positives surface, narrow the regex; if speculation items slip through with new phrasing, extend the pattern list (same iterative pattern as Lessons 17 + 77).

**Known follow-up — the depth-player threshold (NOT in scope here, flagged for a later version).** The Arsenal user's "nobody cares about our third striker" feedback identifies a class Lesson 82 doesn't catch: roster moves involving depth players. A CONFIRMED sale of a third-choice striker IS technically team-impact (Lesson 76 ✓) and IS confirmed (Lesson 82 transfer gate ✓), so both gates pass — and the push goes out. But the user doesn't want it. The fix needs either (a) a per-team "key players" list (top-XI + immediate rotation, ~14 names) that the prompt consults to differentiate "Saka leaving" from "fourth-choice keeper leaving," OR (b) a script-level deny-list of "depth/third/fourth-choice/youth/reserve" qualifier phrases in push_text. Deferred — the speculation downgrade catches the Jesus case anyway (he's described with "want £20m," not "completes move"), so the depth-player gap is real but not currently leaking to lock screens. Re-evaluate after a week of Lesson 82 data: if a confirmed-but-depth move still pushes and draws feedback, build (a) or (b).

### 83. The feed-only side door — push_eligible defeated by the direct push trigger

**What happened (2026-06-01):** Arsenal user got a push — "He might have opinions / Arsenal are linked with Aston Villa's Rogers this summer. PSG want him too." Lesson 82 was supposed to stop exactly this. Investigation: the item DID ship `push_eligible=false` (the speculation downgrade worked) — but `pushed_at` was set. It pushed anyway.

**Root cause — two push paths, one gated, one not.** `post_news.sh` inserts the content_item, then POSTs `{content_item_id}` to notification-sender to fire the push immediately. notification-sender has two modes: the **sweep** (hourly cron) filters `.eq("push_eligible", true)`, but the **specific-item** path (`if specificItemId`) deliberately skipped that filter — a comment said "manual recovery may want to push a feed-only item, operator decides." So the routine's own post-insert trigger went through the ungated side door. The Lesson 82 downgrade was real but cosmetic.

**The blast radius was wider than the one reported push.** `verify-push-eligible.sh` against the prior two fires found **5** feed-only items that pushed (Rogers ×2, Alisson-to-Juventus speculation, Ugarte + Fletcher international call-ups). The entire feed-only mechanism — Lessons 76, 77, AND 82 — was being bypassed for every routine item, because every routine item goes through that direct trigger.

**Fix.** notification-sender specific-item path now also `.eq("push_eligible", true)` UNLESS the body carries `force_push: true` (preserves the manual-recovery escape hatch). `post_news.sh` additionally skips the trigger entirely when it set `push_eligible=false` (saves a wasted call). Verified live: POSTing the Rogers item's id now returns "No items to publish".

**Rules:**
1. **A flag is only as strong as every code path that reads it.** push_eligible was correct in the DB the whole time; one of two consumers ignored it. When you add a gate, grep for EVERY reader of the gated field and confirm each honours it. The sweep honoured it; the trigger didn't; the bug hid for three lessons.
2. **"Operator override" defaults are footguns when an automated caller uses the same path.** The specific-item path was designed for human recovery, but the routine is its highest-volume caller. Safe-by-default + explicit opt-out (`force_push`) beats unsafe-by-default + implicit trust.
3. **Build the regression check the moment you fix the leak.** `verify-push-eligible.sh` both proved the fix and quantified the historical blast radius. A fix you can't measure is a fix you can't trust held.

### 84. The Disk IO budget — a missing composite index, not the row count

**What prompted this (2026-06-01):** Supabase alert — "project depleting its Disk IO Budget." User didn't want to pay for an upgrade.

**The obvious suspect was wrong.** `raw_fetch_logs` had grown to 93,727 rows / 340MB of large JSONB, never pruned. Easy to assume "table too big → trim it." But `pg_stat_user_tables` showed only **32 seq scans** vs **25,058 index scans** — it wasn't being scanned to death. The real signal: `idx_tup_fetch = 1.39M`, ~55 heap rows fetched per index scan.

**Root cause — the index didn't match the query.** The hot reads (detect-consequences after every FT, team-page-generator per source) are `.eq("team_id", X).eq("source", Y).order("fetched_at" DESC).limit(1)`. The only index was `(team_id, fetched_at)`. So Postgres seeked the team, then walked ~55 recent rows (all sources) reading each large JSONB heap tuple to filter by source. That heap churn — not the row count — drained the IO budget.

**Fix (all free):** (a) composite index `(team_id, source, fetched_at DESC)` → single seek + 1 heap fetch; (b) one-time trim of 61,475 stale rows preserving the latest snapshot per (source, team_id) + last 7 days; (c) migration 057 daily retention cron. Crons verified green post-change.

**Rules:**
1. **"Big table" and "IO problem" are not the same diagnosis.** Read `pg_stat_user_tables` (seq vs idx scans, tuples fetched per scan) before assuming size is the issue. The fix here was an index, not a delete — the delete was secondary.
2. **An index must cover the WHOLE predicate, in the right order.** `(team_id, fetched_at)` looked reasonable but left `source` to be filtered in-heap. For `eq + eq + order-by-limit`, the index needs all three columns with the ordering column last. Each in-heap filter on a large-JSONB row is amplified IO.
3. **Match the fix to the alert.** The alert was IO budget, not disk space — so a regular VACUUM (mark reusable, no lock) + index was right; a locking VACUUM FULL to reclaim 340MB of disk would have spiked the very budget we were trying to protect.

### 85. WC consequence math — three bugs that would fire wrong or contradictory pushes

**What prompted this (2026-06-01):** Pre-WC quality audit of the cross-team consequence detector (`detect-consequences.ts`). Three bugs found, all WC-launch-relevant.

**B1 — false "you're OUT" (the worst one).** `WC_KNOCKOUT_ELIMINATED` fired when a team couldn't reach top-2 in its OWN group. But the 2026 format advances top-2 + the **8 best third-placed** teams. A 3rd-place team on 4 pts that can't reach 2nd can still advance as a best-third. The code's own comments admitted best-third was "V1.1/unhandled" — yet it shipped as live logic. Telling a fan their team is out when it isn't is the single worst push, and unlike a false "you're through," it can't be walked back. **Disabled ELIMINATED entirely** until a cross-group best-third comparator exists; group-stage exit is conveyed by the team's own matchday brief.

**B2 — no knockout-stage gate.** WC knockout fixtures still carry `league.id=1`. Running group-qualification math against a stale group table after a knockout match could fire a contradictory QUALIFIED/GROUP_WON for a team already knocked out. Now match-watcher passes `league.round`; the detector early-returns for any non-"Group" round.

**B3 — points-only re-rank ignored goal difference.** `applyResult` re-sorted by points alone, so on tied points (common on the final group matchday) the 2nd/3rd "boundary" team a check compares against was arbitrary — and differed between the fresh-snapshot path (kept API's GD-correct rank) and the stale path (re-ranked points-only). Now ranks by points, then GD, then goals-for. Added `goalsDiff`/`goals` to StandingsEntry/cloneGroup/applyResult.

QUALIFIED and GROUP_WON *direction* math confirmed correct via a standalone node test (top-2 clinch guarantees advancement regardless of best-third); ELIMINATED confirmed never to fire.

**Rules:**
1. **A false negative that can't be retracted is worse than a false positive.** "You qualified" turning out wrong is embarrassing; "you're eliminated" turning out wrong is a betrayal. When the math is uncertain (best-third), suppress the unrecoverable direction and keep the recoverable one.
2. **Idempotency ≠ consistency.** The `(team_id, consequence_type)` unique index prevents duplicate QUALIFIED, but a team can still hold BOTH a QUALIFIED and an ELIMINATED row (different types). The index guards duplication, not contradiction — B1/B2/B3 were the real contradiction sources.
3. **A re-rank must use the same tiebreakers as the real table, or it ranks the wrong team.** Points-only ordering silently mislabels the boundary team a threshold compares against. Half-right tiebreakers (points + GD) remove the worst flips even before full H2H.

### 86. The WC pre-launch quality review — active-entity bugs and the content gap

**What prompted this (2026-06-01):** User asked for a "higher intelligence" pass to find WC bugs/contradictions before launch. Ran three parallel review agents (push/news logic, content correctness, iOS) plus live-data checks.

**The iOS theme: the app asked for the wrong team.** A cluster of bugs all shared one root — fetches keyed off `appState.selectedTeam` (the PL club) instead of the active entity (which can be a WC country):
- **Immersive feed didn't reload on a club↔country switch** — `switchContext` guarded reload on `if teamItems.isEmpty`, but that array held the PREVIOUS entity's stories, so it never refetched. Only pull-to-refresh (which bypasses the guard) worked. User reported this independently.
- **"Things he doesn't know" (insider), matchday player cards, the Saturday quiz, and the live-match card** all fetched by `selectedTeam`. A WC-only user (no club) saw none of them; a dual-follower viewing their country saw the CLUB's data. Countries have their own insider (693 items) and quiz support — the data existed; the app asked for the wrong id.

Fix: an `activeEntityId` computed property resolving club/country from `activeContext`, threaded through every feed fetch + the `.task(id:)` lifecycles so they reload on a context switch. All build-verified.

**The content theme: the feeds are empty.** 47 of 48 countries have NO preview content (only England was hand-curated); **14 have zero content_items of any kind**. The `gd-wc-preview` routine was never built. Also found: England had 2 leftover content_items still saying "Group F" (England is Group L) plus an invented "runners-up of Group E" bracket route — the Lesson-78 fix had corrected team_pages but missed content_items free-text. Fixed via targeted SQL (NOT a blind Group F→L swap — Japan/Netherlands/Sweden/Tunisia are legitimately Group F). Canada (host) has null standings.

**Product direction noted (2026-06-02):** With the PL season over, club quizzes are dormant; the value now is country quizzes + bite-size team info during the WC window. The quiz routine already does this (WC-MODE, suppressed until ~June 4) — the active-entity fix above is what makes it actually surface to country followers.

**Rules:**
1. **A polymorphic entity needs ONE resolver, used everywhere.** The club/country duality leaked because each fetch re-derived "which team" independently and several defaulted to the club. Centralising `activeEntityId` and threading it through is the durable fix; scattered `selectedTeam` reads are the bug factory.
2. **"The data exists" and "the app shows it" are separate audits.** Country insider/quiz content was present; the iOS layer just never requested it. Verify both ends.
3. **A migration-era fix can miss a sibling table.** Lesson 78's group-label correction fixed team_pages but not content_items — same data, different table, different fix pass. When correcting denormalised/duplicated data, enumerate every place it lives.
4. **Parallel review agents earn their cost on breadth.** Three agents across logic/content/iOS surfaced more in one pass than a serial read would have — and each finding was then verified against live data or the actual code before acting.

**Open follow-ups (documented, not done):**
- **Content gap** — build `gd-wc-preview` (4 items/country, grounded on standings competition_label, push_eligible=false) for the 47 empty feeds; prioritise the 14 zero-content countries; fix Canada standings. Free (subscription quota). Deferred per user.
- **iOS 2.0.1 fast-follow** — the active-entity fixes above + lighter review findings (TeamPageView reload on context change, group-table verdict scale, sparse-item decode guard, multi-word-country calendar slug). Ship after the in-review build clears; not in the current submission.

### 87. Insights from data we already have — server-side tracking that honours "we don't track you"

**What prompted this (2026-06-02):** Post-submission, the user wanted launch insights — which team/country people pick, push opens, deletes/refunds, sessions — but asked the sharp question: *can we get it server-side WITHOUT a new App Store build? If yes, do that; only instrument the app if we must.* The app's brand promise is "we don't track you. No accounts, no ads, no personal data beyond what's needed to send you notifications."

**The split (after mapping each ask to the data we already collect):**
- **Server-side NOW (no build, no new tracking):** team/country chosen (`device_tokens.team_id`/`country_id`), growth (`created_at`), tier mix, TestFlight-vs-App-Store (`apns_environment`), churn/uninstalls (`is_active=false` — notification-sender ALREADY flips this on APNs 410/Unregistered + 400/BadDeviceToken and logs it to `pipeline_health`), push delivery success, content production.
- **Needs the app (Phase B / iOS 2.0.1):** push OPENS (Apple never reports them; the tap handler exists but POSTs nothing) and in-app SESSIONS (inherently client-side; feed fetches aren't per-user attributable).
- **N/A:** refunds — the app is free.

**What shipped (Phase A):** migration 058 — seven read-only aggregate VIEWs + a service-role `get_insights(days)` RPC (mirroring `everyone_talking_daily` + `get_pipeline_diagnostics`), all locked off the anon surface. Plus `scripts/insights.sh`, an on-demand psql dashboard. Every output is a COUNT — no `apns_token`, no per-user rows. Zero iOS change, no resubmit, no privacy-policy change.

**It earned its keep on first run:** surfaced the 13 zero-content WC feeds (quantifying the empty-feed gap), the historical push-delivery dips (May 19–22 bad-token failures, pre-rotation), and the Lesson 83 feed-only leak (2026-06-01: 10 pushed vs 7 push-eligible → 3 leaked).

**Rules:**
1. **Most "we need analytics" questions are answerable from operational data you already keep.** Registration rows, token state, and delivery logs already encode audience, growth, churn, and reach — no behavioral tracking required. Inventory what you have before instrumenting.
2. **Privacy posture is a design input, not an afterthought.** Framing it as "aggregate-only from data we already collect to run the service" keeps the insights layer squarely inside the "we don't track you" promise; opens/sessions are the line where you must consciously opt into client analytics.
3. **Churn was free because a side-effect already captured it.** notification-sender deactivates dead tokens to avoid wasting APNs calls — that same mechanism IS the uninstall signal. Look for signals that fall out of existing correctness logic before building new capture.
4. **Caveat-in-the-output beats silent imprecision.** Churn is lazy (only detected on the next push attempt to a dead token); the dashboard and view comments say so, so nobody reads the trend as real-time.

**Open (Phase B, decision-gated):** push opens + sessions via an anonymous `track-event` Edge Function + `AppDelegate` fire-and-forget, bundled into iOS 2.0.1 — needs the user's opt-in to anonymous (no-PII) analytics + one privacy-policy line (the PRD already scoped TelemetryDeck for this).

### 88. Deterministic content auditor — the West Ham miscount → a $0 standings-claim linter

**What prompted this (2026-06-05):** A Sunday brief told West Ham followers they "stayed up" while they finished **18th** (relegated — the PL drops the bottom THREE). The routine had the correct standings; it reasoned wrongly about them ("17 points clear of 19th, so safe" — forgetting 18th is itself a drop place). An LLM re-reading the same data can repeat the mistake, so the robust check is **deterministic**: compare the CLAIM to the RANK.

**What shipped:** `content-audit` Edge Function + `_shared/audit-claims.ts` (pure regex + integer comparison — **zero Claude/API-Football calls, never pushes, never mutates content**) + migration 059 (a `content_audit` pipeline_health stage + nightly cron). It flags content whose terminal claims (safe / relegated / champions / top-four) contradict the actual table, logging contradictions for human review.

**The build's real lesson — precision is the whole product.** A naive first pass produced **24 false positives and 0 true positives** on the live 729-item corpus (the one real bug was already fixed). A linter that cries wolf 24× trains you to ignore it. Three tightening rounds got it to **0 false positives while still catching the real bug** (18 unit tests pin both directions):
1. **Subject attribution** — the claim must be about the *tagged* team. A club's feed constantly references other clubs ("Arsenal are champions" inside Man City's feed must not flag City). Match the team whose alias is *nearest* the claim.
2. **Terminal-only phrasing** — "stayed up" not "fighting to stay up"; "avoided relegation" (past) not "avoid relegation" (a goal). Whole-sentence blockers kill conditionals/predictions ("if both happen, West Ham stay up"; "Sky predict they go down").
3. **Competition + temporal escapes** — "Europa League champions" ≠ PL champions; "won the league last season" / "in 2012" / "went from champions to" are history, not claims.

**Rules:**
1. **Deterministic guards beat hoping the LLM follows prose.** Same philosophy as the post_news.sh char/voice guards: when correctness matters, enforce it in code, not in the prompt.
2. **A noisy detector is worse than none.** Bias hard toward precision; missing a rare real bug is acceptable, crying wolf is not. Tune against the live corpus until false positives hit zero.
3. **The app's data can be fresher than the model's training.** (Carried into Lesson 89 — see the Semenyo reversal.)

### 89. The 577-push audit — the rules existed, enforcement didn't

**What prompted this (2026-06-05):** After the West Ham fix, the user asked for a full audit: PL news (7d), WC news (all), and **every push of the last 30 days (577)** scored on relevant / timing / quality / true / prompt-fix. Run in-session via the `content-audit` linter (truth) + 10 fan-out evaluation agents (one per team-group). Findings: `CONTENT_PUSH_AUDIT_2026-06.md`.

**Result:** the system is voice-competent and (where checkable) truthful, but **massively over-pushes** — ~a third of pushes flagged. The dominant leaks were unconfirmed transfer/manager speculation pushed as certain, and international call-ups pushed on club feeds with emotional openers — **exactly the cases the PROMPT.md TEAM IMPACT (Lesson 76) and TRANSFER (Lesson 82) gates already forbade.** The rules existed and were ignored at scale.

**The fix — widen the deterministic guards in `post_news.sh`, don't add more prose:**
- Speculation guard: added "in talks / close to / chasing / shortlist / could join / open to / bid rejected / manager-search" phrasings + a CONFIRMED-news override.
- Int'l-duty guard: it still searched for "World Cup" — but the FIFA-5.2.1 sweep renamed everything to **"World Championship"**, so the guard had been silently missing every call-up since. Added the new term + non-possessive forms + call-up verbs.
- New banned-register hard-reject on `push_title` ("Big drama", "The plot twist at keeper", "Strong reaction incoming"…).
- PROMPT.md: opener-rotation rule + SAGA/REPEAT cooldown (one push per result/fixture/rumour-thread). SUNDAY_BRIEF: internal-consistency rule (points gaps, qualification, cup rounds).

**Rules:**
1. **A gate that the LLM "should" honour is not a gate.** If a prompt rule is being violated at scale, the rule isn't the fix — deterministic enforcement in the publish path is. Audit whether your guards actually fire, not just whether the rule is written down.
2. **A rename can silently disable a guard.** The int'l-duty downgrade broke the moment "World Cup" → "World Championship" shipped, because the regex hard-coded the old term. When you rename a domain term, grep every guard/pattern that matches on it.
3. **The model's "fact-checks" are stale; trust the data.** Agents flagged "Semenyo plays for Bournemouth" as a content error — but he'd transferred to Man City, so the app was right and the agents (and I) were wrong. A "fix" applied on that basis was reverted. For roster/transfer facts, the live squad data is the source of truth, not the LLM. Reliable truth signals = deterministic standings checks + internal self-contradictions only.
4. **Verify "spam" before reporting it.** The scariest-looking findings (23-push bursts, null-title pushes, 1:37am sends) were largely BACKFILL artifacts (bulk-stamped `pushed_at` over many hours), not real user notifications. Check `created_at` vs `pushed_at` spread before claiming users were spammed.

### 90. "Removed from the App Store" was EU DSA trader status, not a rejection

**What prompted this (2026-06-09):** The user reported the app showed as removed from the App Store. It was NOT a review rejection — V2.0 (build 1.0(3)) had in fact **passed review** ("eligible for distribution"). Two account/availability-level causes, both separate from App Review:
1. **App Availability was empty** — Apple's redesigned Pricing & Availability split "Prices" (175 regions of price tiers) from "App Availability" (where it actually sells); the availability list had cleared, so the app was live in **zero** regions. Fix: *Set Up Availability* → all regions → Save.
2. **EU DSA trader status** — since Feb 2025 Apple requires verified trader status (a publicly-displayed business contact) to distribute in the **27 EU states**; without it those regions stay blocked. Submitted; now "under review" by Apple.

**The unlock:** the **UK is not in the EU (Brexit)**, so the primary market is unaffected. Availability was set for the **148 non-EU regions** (incl. UK + US) → app live immediately for kickoff; the EU-27 join automatically once trader status verifies.

**Rules:**
1. **App Store Connect has two independent statuses.** Version status (review verdict) ≠ app availability (where it sells). "Removed" is the availability layer; a passed review can still be invisible.
2. **EU DSA trader status only gates the EU-27.** Don't let it block a global launch — set availability for everything else and let the EU follow.
3. **I can't (and won't) operate App Store Connect** — login + legal attestations are the user's; my job is to diagnose against the live notice and tell them exactly where to click.

### 91. WC team pages went 8 days stale — the cheap refresh path bailed out for countries

**What prompted this (2026-06-09):** 2 days before kickoff, Sweden's page showed "next up: Norway, 1 June" — an 8-day-old friendly. Root cause: `data-fetcher` *was* pulling fresh fixtures+standings for all 48 countries every 2h (raw data fresh in `raw_fetch_logs`), but `team-page-generator.updateDynamicFields` **bailed out for `entity_type==="country"`** and routed them to the *paid weekly Claude regen* — so the dynamic cards (next_fixture/standings/calendar) only refreshed ~weekly. Confirmed in prod: `next_fixture.updated_at` = May 18 while standings raw log = fetched 1h ago.

**What shipped (Phase A, server-side, zero Claude):**
- `updateWcDynamicFields` — a deterministic WC branch (removed the bail-out): rebuilds standings (reuse `buildStandingsCard`), stakes-annotated `upcoming_fixtures`, `next_fixture` (+ templated preview), `this_week`, and `form` ("Xst in Group Y") from raw logs. Past-fixture forward-walk guard on `extractNextFixture` (no more stale "next up"). Verified: all **48/48 countries fresh, 0 stale fixtures, 1-2s refreshes (no Claude)**, PL unchanged.
- `_shared/stakes-engine.ts` + `stakes-templates.ts` — per-fixture stakes (importance dots + "what they need" label), tone keyed on reason.
- `match-watcher` — factual **WC_RIVAL_RESULT** push to the non-playing same-group teams at FT (score only, no derived math) + a deterministic `post_match` card. `notification-sender` unchanged (routes by team_id/country_id, honours `push_eligible`). Migration 060: rival-result idempotent per `(team_id, match_id)` via `unique_matchday_content`, excluded from the once-per-type index.
- **PL → feed-only for the WC window** — date-gated block in `post_news.sh` (routines repo, pushed `4141fbd`) sets `push_eligible:false` for `$pl_clubs` from 2026-06-09→07-20. WC feeds unaffected; auto-resumes.

**Rules:**
1. **Fresh DB data ≠ fresh app.** A page can be stale even when its inputs are current — find the regeneration step, not just the fetch.
2. **A cost guard can become a staleness bug.** The country bail-out existed to avoid 48 paid Claude calls every 2h; the right answer was a *deterministic* refresh on the cheap path, not skipping the refresh.
3. **Rival-result pushes state the FACT, not the consequence.** The score is known at FT; "what you now need" depends on a refreshed table + tiebreakers, so it lives in-app. Never push a derived claim you can't yet back.

### 92. Exact WC group-stage qualification math — assert only what is mathematically locked

**What prompted this (2026-06-09/10):** The user wanted the group-stage math made *exact* — "England will at worst be 2nd" — and the cross-group **best-third** qualification computed ("8 of the 12 thirds go through; we can count it out"). Goal: **no push is ever wrong.**

**Format verified vs FIFA/ESPN (don't trust training):** 48 teams → 12 groups of 4 → top 2 + **8 best of 12 thirds** = 32 → Round of 32. The 2026 within-group tiebreaker changed to **head-to-head FIRST** (then overall GD → goals → conduct → FIFA ranking); best-third ranking is points → GD → goals → conduct → FIFA ranking (no H2H). API-Football returns all 12 groups + a "Ranking of third-placed teams" array in one standings payload; no head-to-head data.

**What shipped (zero Claude, deterministic, 45 Deno tests):**
- `_shared/group-scenarios.ts` — brute-force ≤3^6 remaining results → exact within-group position bounds (worst/best rank with **pessimistic/optimistic tie handling**, so claims are **tiebreaker-agnostic** → correct under the new H2H rule without implementing H2H). `coarseThirdPointsBounds`: provably-valid upper/lower 3rd-place bounds (order-statistic domination).
- `_shared/best-third.ts` — cross-group 8-of-12 comparator → `guaranteed_in / out / soft`, points-only strict separation, + a **completeness guard** (snapshot missing groups → soft, never a false "in").
- Labels: "Won the group" / **"At worst 2nd"** / "Through as a best third" / in-app **"Out of the tournament"**; the **freshness/completeness gate** defers hard pushes on an incomplete simultaneous-final-matchday snapshot (re-fires idempotently). **WC_BEST_THIRD_QUALIFIED** pushes (good news); **elimination is in-app only, never pushed** (user decision). post_match tone is best-third-aware (through = upbeat, out = definitive, pending = "still in play, decided by other groups"). Final-matchday tightening: when pairings are fully determined, enumerate to catch "at worst 2nd because the two rivals play each other" (which points-only can't prove).

**Rules:**
1. **Make the conservative direction the only direction.** Every claim asserts only what's locked on POINTS; ties are resolved pessimistically. So the engine can *under-claim* (stay soft) but can never be wrong — which is the entire requirement.
2. **The format's tiebreakers can change between cycles — verify, then design around them.** We dodged implementing H2H entirely by being tiebreaker-agnostic, but only because we checked the 2026 rules first.
3. **Good news pushes; bad news is discovered.** A "you're out" notification is harsh and redundant (the result push already landed) — surface elimination in-app, push only qualification.
4. **Loose-but-sound bounds are fine for the cross-group comparison.** Coarse per-group bounds (3rd-highest of maxes / of floors) over the other 11 groups are stale-safe and only ever make us more conservative — no need for every group's exact pairings.

### 93. US-market parity was a content gap, not a code gap — and the preview coverage was patchy

**Trigger:** "Focus on the US market. Compare what England has that the USA doesn't, and what we can add server-side with no new build." (2026-06-11, WC kickoff day; US opener vs Paraguay June 13.)

**Finding — the engine is fully country-agnostic.** USA has the identical 10 team-page cards, all populated by the deterministic `updateWcDynamicFields` path (Pochettino bio, 3 `ones_to_know`, host-nation fun fact, Group D standings, stakes-annotated fixtures). The stakes engine, consequence pushes, and `gd-news-wc` feed have **zero `england` hardcoding** (grep-confirmed). The only England-vs-USA difference was **hand-curated pre-tournament preview `content_items`** (1 group overview + 3 per-opponent previews) linked to fixtures via `preview_fixture_id` (mig 053), which (a) seed a rich feed first-read and (b) make Calendar rows tappable → `ContentDetailView`.

**The iOS feature already shipped in V2.0**, so seeding rows server-side lights up the calendar with **no build** — `fetchPreviewItems` (filters `status=eq.published`), `previewByFixtureId`, `previewKey(for:)`. The synthetic id iOS computes is `"<team_id>:<date.prefix(10)>:<opponent.lowercased(), spaces→_>"` — note it uses the **raw UTC date prefix** and keeps non-ASCII (the Türkiye slug is `türkiye`, with `ü`). A psql cross-check (derive the key from `upcoming_fixtures`, compare to the inserted `preview_fixture_id`) is the way to guarantee the match before trusting a tap.

**What shipped:** 4 hand-curated USA previews (Group D overview + Paraguay/Australia/Türkiye), `push_eligible=false` (feed-only), `status='published'`, gold-standard depth (~890 chars, like England) with **accurate opponent players/managers pulled from each opponent's own `ones_to_know`/`manager` card** (Almirón/Alfaro, Mat Ryan/Popović, Güler/Çalhanoğlu/Montella) — never from model memory (stale-model rule). Voice: gf-to-bf, no em-dashes, "World Championship" not "World Cup". Zero API/Claude cost (prose written by hand, inserted via SQL).

**Two traps:**
1. **England's own previews were dark.** All 4 were `status='archived'` — collateral of a blanket `UPDATE … WHERE pipeline_source='routine'` cleanup (routines `README.md:90`), and `fetchPreviewItems` requires `published`. Republished them (Group L: Croatia/Ghana/Panama, still accurate). **Lesson: protect curated content from blanket archival by scoping the cleanup (exclude `preview_fixture_id IS NOT NULL` + the overview, or scope by date) — NOT by a source tag, because** `pipeline_source` has a CHECK allowing only `edge_function`/`routine`; **`'manual'` is impossible** (the original plan assumed it). Curated previews therefore live as `pipeline_source='routine'`, indistinguishable from churn unless the cleanup is scoped.
2. **The "47 of 48 have no previews" note (Lesson 86/79) is STALE.** A routine seeded ~14 countries with *lighter* (~300-char) previews around June 3-4, but skipped 34 — including **Brazil, Argentina, France, Germany, Spain, and both co-hosts Canada + Mexico** (Japan's got seeded then archived). After this work, 14 countries have published previews (USA + England at gold-standard depth, the rest routine-light). **Extending to the missing 34 is the same server-side / no-build lever** (re-run the partial routine, or hand-curate the marquee nations + co-hosts) — documented follow-up, deliberately out of the USA-only scope the user chose.

### 94. Opponent context on the team page — reuse the opponent's own card, don't rewrite

**Trigger:** "Coming up vs Tunisia is nice, but tell me more about Tunisia in that card. And the 'ones to know' could also be for Tunisia, updating per opponent, clearly the away team." (2026-06-11.) User's key insight: *"every team has their own ones to know, so we can just take that from the opposing team... when they're meeting someone else it shows up in both feeds."*

**The shape.** Each WC country already has a curated `manager` + `ones_to_know` card. So opponent context is a **copy, not a generation**: at refresh time, look up the upcoming opponent's own team_page and reuse it. Sweden vs Tunisia → Tunisia's manager + danger men show on Sweden's page; symmetric on Tunisia's. Zero Claude, accurate, self-updating per fixture.

**What's live now (server-side, no build, all 48 countries):**
- `next_fixture.preview` gets the opponent's FULL ones-to-know appended — `renderOpponentDetail()` in stakes-templates.ts: manager line + each player's name, **position** and the opponent's own description, e.g. *"Tunisia are managed by Sabri Lamouchi. Their ones to watch: Hannibal Mejbri (midfielder): The 22-year-old playmaker ... Ellyes Skhiri (midfielder): ... Elias Achouri (winger): ..."* So expanding the "Coming up" card shows the same depth as the team's own ones-to-know, **minus photos** (those are the 2.0.1 in-card block). Always names the opponent (never "your"); multi-line text in the existing rendered field, so no app change. (Upgraded 2026-06-11 from a one-line names-only blurb after the user asked for positions + descriptions.) No em-dashes; "World Championship" not "World Cup".
- `loadOpponentCardInfo(supabase, opponentApiId)` resolves opponent API id → `teams.id` → their `team_pages` card (robust to name spelling; null for a non-WC friendly → graceful).
- A forward-compatible `ones_to_know.opponent = {team_name, venue, players[]}` block (the opponent's curated players + photos), refreshed per fixture, cleared when no opponent. Current clients ignore the unknown key (Codable); 2.0.1 renders it.

**Build-gated piece (coded + compiles, ships with 2.0.1):** the opponent's danger men render **inside the same "Ones to know" card** (user's call — not a separate card) under a hot-rose `"Up next: <Team>" / "Their ones to watch"` header, reusing `playerRow` (photos), non-tappable. iOS: `OnesToKnowCard.opponent: OpponentSide?` + `opponentSection()`. The current live app **hard-caps that card at `players.prefix(3)` and has no opponent label**, which is exactly why the in-card version needs a build while the Coming-up blurb does not.

**Bonus fix found in the act:** the WC next_fixture refresh used only the *newest* `fixtures_next` log; a transient empty fetch (Sweden's 06:00 today returned 0 fixtures) blanked the whole rebuild. Switched to **newest-good-wins** (walk fixtures_next logs newest-first, take the first with any future fixture — mirrors `buildStandingsCard`). Sweden recovered immediately; all 48 now carry the blurb.

**Next-fixture rollover hardening (user follow-up: "backtrack against known dates so we know if it's been played").** Newest-good-wins introduced a hazard: a *stale* fixtures_next snapshot can still list a game that's since been played, and a kickoff date is a weak "played" signal (a just-finished game lingers inside the 3h grace; postponements lie). Fix: corroborate against `api_football_fixtures_last`, the authoritative finished list (each entry carries `fixture.id` + `FT/AET/PEN/WO` status). New pure, tested `_shared/fixture-rollover.ts`: `collectFinishedFixtureIds()` (unions played ids across recent fixtures_last logs — once played, always played, tolerant of empty/junk) + `dropFinished()`. The WC refresh now picks the newest fixtures_next log whose fixtures survive BOTH the date-grace AND the finished-set, so a played game is excluded the moment it's known-finished (not 3h later), and the card recomputes the next opponent + blurb + `ones_to_know.opponent` from it. We never surgically add/remove a fixture — every refresh recomputes from fresh data; we just made "played?" authoritative. Rollover speed stays the data-fetcher ~2h cadence (user chose this over an instant match-watcher FT trigger). Can't live-verify yet (no WC group games played on 2026-06-11), so it's covered by 5 unit tests incl. "stale snapshot listing a played opener rolls to game 2"; deployed, behavior identical today (finished-set is empty of group games, so `dropFinished` is a no-op).

**Lessons:**
1. **Curated data is reusable across pages — copy it, don't regenerate.** The opponent's own page is the source of truth for "who are they"; pulling it costs nothing and stays consistent with what that team's own followers see.
2. **Know exactly what the live binary renders before promising "no build".** Text in an existing field (preview) = free. A new field, a new label, or lifting a `prefix(N)` cap = build. Same data, two very different delivery timelines.
3. **A transient empty upstream fetch should never blank a derived card** — newest-*good*-wins, not newest-wins, anywhere a single bad poll can erase good state.
4. **"Has it happened?" deserves an authoritative source, not a clock.** Date math is a fallback; the finished-games feed (with stable fixture ids) is the truth. Newest-good-wins made this necessary — a robustness fix can open a correctness hole if you don't follow it through.
5. **Reused content carries its ORIGINAL audience's voice (caught in adversarial review).** The opponent block reuses the opponent's own `ones_to_know`, whose one-liners are written for *that team's* fans and personalised with `[his name]` (e.g. "[his name] will be buzzing if he starts"). On the opponent's page that token resolves to the *reader's* partner and reads backwards — a USA fan is not buzzing about a Türkiye player (10 such one-liners across 8 pages). Fix: strip token-bearing one-liners from the opponent block (keep the neutral, factual ones — 0 of those carry fan-framing); the focal card keeps them, because there the reader *is* that fan. Lesson: when you re-surface content in a different context, its implied audience comes with it.

### 95. API-Football's national-team coach data is broadly stale — 12 of 48 were wrong

**Trigger:** user spotted missing coach photos (France/Scotland/Uruguay) and, critically, "Sweden doesn't even have that coach anymore" — the app showed Jon Dahl Tomasson, sacked in October 2025.

**Root cause:** API-Football does not reliably maintain national-team coach records. It does not backdate a sacked coach's stint end, nor open the new appointee's. Sweden's feed still had Tomasson with an OPEN stint AND a top-level `team: Sweden`, while Graham Potter (the real coach since Oct 2025) was in the response but still listed `team: West Ham`. So neither the career array nor the top-level team field pointed to Potter — **no signal in the data could have produced the right answer.** Our "most-recent open stint" matcher therefore returned a coach who'd left. Three other teams had no open stint at all → `<UNKNOWN>`.

**The audit:** because one silent error implies more, ran a web-verified sweep of ALL 48 WC countries (4 parallel agents, 2026 sources — Wikipedia/ESPN/FIFA/FAs — not training memory). **12 of 48 (25%) were wrong or missing:** Sweden (Tomasson→**Potter**), France/Scotland/Uruguay (`<UNKNOWN>`→**Deschamps/Clarke/Bielsa**), Spain (showed **Deschamps** — France's coach! →**de la Fuente**), Ghana (Addo, fired 72 days pre-WC→**Queiroz**), Tunisia (Trabelsi→**Lamouchi**), South Africa (a fabricated "V. Khumalo"→**Broos**), Senegal (a fabricated "Joseph Senghor"→**Thiaw**), Saudi Arabia (Renard→**Donis**), Czech Republic (Hašek→**Koubek**), New Zealand (Schmid→**Bazeley**). The other 36 verified correct.

**Fix:** a web-verified `COACH_OVERRIDES` map (name + real API-Football photo id + a short factual summary) applied deterministically in `updateWcDynamicFields` on every refresh, so it survives the weekly full regen. Photos pulled from the correct coach's record in the raw `api_football_coachs` data (they were present, just not matched). Each entry documents its removal condition (Sweden until API reflects Potter; the others once a full regen is confirmed to populate them). Country manager-photo coverage went 45/48 → **48/48, 0 `<UNKNOWN>`**.

**Cascade caught:** Tunisia's wrong coach had already propagated into Sweden's opponent blurb ("Tunisia are managed by S. Trabelsi"). Fixing Tunisia's card + a double-pass refresh (overrides apply pass 1; opponent blurbs re-read corrected opponents pass 2) corrected it to Lamouchi.

**Lessons:**
1. **A single trusted upstream can be confidently wrong about facts that change discretely** (hirings/firings). For a launch, verify against authoritative sources rather than assume the API is current.
2. **A matcher returning a *plausible* answer is more dangerous than one returning nothing.** Tomasson/Trabelsi looked fine; only a human noticing or an external check caught them. `<UNKNOWN>` at least advertises the gap.
3. **One silent error is a sampling signal, not an isolated bug** — when Sweden turned out wrong, the right move was to audit all 48, which surfaced 11 more.

**Not yet audited (follow-ups):** player `ones_to_know` (squad data, changes less; drives the opponent danger-men), and PL club head coaches (off-season, PL is feed-only during the WC window).

### 96. Player-club staleness + the 7-day archive cron that was eating the previews

**Trigger:** user QA: "the opponent ones-to-know card needs breathing room + bold names"; "calendar didn't work for my friend's FIRST add either"; "onboarding shows wrong player info — Gyökeres is an Arsenal striker, not Sporting."

**Coming-up card polish.** Breathing room between players shipped server-side (blank lines in `renderOpponentDetail`, plain text — markdown bold can't render in the current build's verbatim `Text`). Bold names + photos ship as a structured opponent block in the Coming-up card (iOS 2.0.1, built + compiles), replacing the task-18 placement in the Ones-to-know card.

**Calendar (all on-device EventKit, no server lever — 2.0.1):** the re-add bug AND the friend's first-time failure traced to two things: (a) the long-lived `EKEventStore` going stale after an external delete (saves silently no-op'd — `try? store.save`), and (b) `findOrCreateCalendar` relying on `defaultCalendarForNewEvents?.source`, which is nil on devices with no default/writable calendar → first-time create threw. Fixes: `store.reset()` before every sync, a robust `writableSource()` fallback (iCloud → local → any modifiable), propagate save errors (so a failure reverts the toggle + shows a message), sync the FULL upcoming schedule (not just next), and a "Re-add fixtures" button for when the toggle is already On.

**Player-club staleness (same class as the coaches, broader).** Onboarding shows `ones_to_know.players[0]`; Sweden's star read "Sporting Lisbon striker" (Gyökeres moved to Arsenal in summer 2025). A 144-player web sweep (6 agents, 2026 sources) confirmed it's pervasive — the summer-2025 window post-dated the card generation. Corrected the heavy-traffic markets with verified clubs: Sweden (Gyökeres→Arsenal, Isak→Liverpool, Lindelöf→Aston Villa), Germany (Wirtz→Liverpool), Croatia (Modrić→AC Milan), Canada (Jonathan David→Juventus), Belgium (Openda→Juventus). England/USA/France/Spain/Brazil/Argentina/Portugal/Netherlands/Norway were already correct or named no club. Rest queued. **Durable:** corrections live in `team_pages.ones_to_know`, which the 2-hourly `dynamic_only` path preserves and **no full-regen cron exists** (verified `cron.job`), so SQL fixes stick.

**The real archive bug (corrects Lesson 93's assumption).** Listing `cron.job` revealed `goaldigger-archive-old-content` (jobid 2, daily 06:00): `UPDATE content_items SET status='archived' WHERE status='published' AND published_at < now()-7 days`. **This** — not a manual sweep — is what archived England's previews (their `published_at` is 3 weeks old, so they were re-archived nightly), and it would have silently deleted the USA previews 7 days after seeding, mid-tournament. Fix: gave the two overview previews synthetic `preview_fixture_id`s (`<team>:group:overview`) and altered the cron to add `AND preview_fixture_id IS NULL`, so all evergreen preview content (opponent previews + overviews, across every country) is excluded from the stale-news sweep. **Lesson: when a published row mysteriously reverts to archived, list `cron.job` before assuming a human did it — a blanket time-based sweep doesn't distinguish evergreen content from stale news.**

### 97. Whole-app WC data-correctness audit on kickoff day + a freshness lens

**Trigger:** user, on the day the WC kicked off — "go through the whole application, check ALL the World Cup info is correct: dates, games played/to-play, players, managers. And track stale pages so it's easy to follow in future." Full report: [WC_DATA_AUDIT_2026-06-11.md](./WC_DATA_AUDIT_2026-06-11.md).

**Method.** In-session, free (no paid `callClaude()` loop — honoured the hard rule): SQL inventory + 12 parallel web-verification agents (one per group) + one to source replacements. Every correction is web-sourced for June 2026, never model memory — because both the API feed and any single model are stale on discretely-changing facts.

**Managers — 48/48 correct; the verify-don't-assume rule fully vindicated.** Six managers I'd have "corrected" from memory were all REAL recent changes already right in the DB: Morocco/Ouahbi (Regragui resigned Mar 2026), Ghana/Queiroz (Addo sacked Mar 2026), Tunisia/Lamouchi, Saudi/Donis (Renard sacked Apr 2026), Uruguay/Bielsa, Curaçao/Advocaat. The 12 `COACH_OVERRIDES` from Lesson 95 were all vindicated. Only edit: Qatar `Lopetegui` → full `Julen Lopetegui`. **The dangerous instinct here is "fix" — a confident wrong correction beats the data; the agents' job was to confirm the data, not trust the model.**

**Fixtures — dates are correct; the bug was a competition leak.** Agents flagged many openers as "a day late vs Wikipedia." That is UTC-vs-host-local rendering: an evening kickoff in the Americas crosses midnight UTC (USA–Paraguay 18:00 PT Jun 12 = `01:00 UTC Jun 13`). The stored *instant* is right; iOS renders device-local. **No date changed — reasoning this through avoided "correcting" 30+ correct timestamps into errors.** The real bug (🔴, all 48): `updateWcDynamicFields` parsed `api_football_fixtures_next` without a competition filter, so a country's post-tournament Nations League / qualifier games (England: 3 WC + 6 NL) leaked into `upcoming_fixtures` — most as 2-dot "Warm-up game", but any whose opponent name matched a group rival (England vs Croatia in Oct/Nov) got mislabeled "Group stage game" with 4 dots. Fix: new tested pure helper `filterFixturesByLeague` (`_shared/fixture-rollover.ts`) + `parseUpcomingFixtures(..., WC_LEAGUE_ID=1)`. Post-deploy: **every team now shows exactly its 3 group games**; future-proofs knockouts (also league 1).

**Players — 4 absences + ~41 corrections.** The worst class: a featured "one to know" who isn't in the final squad — En-Nesyri (Morocco, omitted), Mitoma (Japan, injured), Palmer (England, cut), Al Naimat (Jordan, ACL) — replaced with verified squad members (El Kaabi, Kamada, Saka, Olwan). Plus ~29 stale clubs explicitly named in one-liners (Son→LAFC, McTominay→Napoli, Kudus→Spurs, Partey→Villarreal, Semenyo→Man City, Xhaka→Sunderland, Kessié→Al-Ahli, Taremi→Olympiacos, Luis Díaz→Bayern, …) and age/record fixes (Ronaldo 41, Džeko 40, Larin not top scorer, Souček no longer captain). All via SQL on `ones_to_know.players` — **durable** (dynamic_only preserves it; no full-regen cron); the refresh propagated them into opponents' "Coming up" blocks. Also cleaned 2 pre-existing em-dashes (Egypt).

**Freshness lens (the "track staleness" ask).** Migration 061 — `v_wc_page_freshness` (page + per-card ages) + service-role `get_wc_freshness()` RPC + `scripts/wc-freshness.sh` (mirrors the insights dashboard). Two tiers: dynamic cards (standings/next_fixture/form, ~2h SLA by day) vs static/LLM cards (manager/ones_to_know/season, days old is normal); `stale` trips at >14h so the overnight fetch gap doesn't false-positive. Currently 48/48 fresh; the tool also reveals the LLM cards were last fully regenerated 2026-05-18.

**Lessons:**
1. **On discretely-changing facts (transfers, sackings, squad cuts), the model's instinct to "fix" is the hazard.** Six "obviously wrong" managers were all correct; the agents' value was confirming, with a June-2026 source, not correcting.
2. **A timezone difference is not a data error.** Stored UTC instants + device-local rendering is correct; the "off-by-one-day" pattern was a rendering artifact, and blindly fixing it would have introduced 30+ real errors.
3. **A feed scoped to an entity can still carry out-of-scope rows** — `fixtures_next` is per-team, not per-competition; filter by `league.id`.
4. **Freshness needs a tier-aware SLA** — flagging LLM cards (legitimately weeks old) as "stale" is noise; only the deterministically-refreshed cards have a tight SLA, and even those must tolerate the overnight gap.

### 98. Some users re-enter all onboarding on relaunch — UserDefaults flush durability

**Trigger:** live App Store users reported that after closing and reopening the app, they have to re-enter ALL onboarding info (her name, his name, team, country). Not most users; not reproducible on the reporter's or a friend's phone.

**Root cause.** All onboarding state persists to `UserDefaults.standard` via `didSet` ([AppState.swift](ios/GoalDigger/Models/AppState.swift)) and is read back synchronously in `AppState.init()`; the launch gate is a plain `if !appState.hasCompletedOnboarding` ([GoalDiggerApp.swift](ios/GoalDigger/App/GoalDiggerApp.swift)). `UserDefaults` does NOT write to disk synchronously — `cfprefsd` batches writes and flushes on a timer / on app suspension. `completeOnboarding()` flipped the flag but never forced a flush. So a user who finishes onboarding in one foreground sitting and then **force-quits** (swipes the app away) — or hits a crash / jetsam kill — before that async flush loses every onboarding write at once and re-onboards next launch.

**Why it fits all three observations:** "re-enter *everything*" (all keys lost together, unflushed); "only *some* users, *every* time" (habitual swipe-to-close users + crashy/low-memory devices never get the flush, and it recurs because each session is force-quit again); "not on my/my friend's phone" (normal backgrounding triggers iOS's suspension flush, so it sticks).

**Ruled out** (so the fix stays targeted): Codable-decode reset (state is key-value, not a blob); Caches purge (UserDefaults lives in `Library/Preferences`, not purgeable — the storage-pressure guess was wrong); launch/async race (init + gate are synchronous); background-launch-while-locked data-protection read (no silent-push/background handler in `AppDelegate`); accidental reset (only `clearAllData()` via Settings).

**Fix (iOS 2.0.1; builds clean):** `AppState.persistNow()` calls `UserDefaults.standard.synchronize()` (the only public API to force a flush — Apple's "usually unnecessary" assumes the process isn't killed first, which is exactly this bug). Called at the load-bearing moment (end of `completeOnboarding()`, after the flag) where it flushes the whole suite atomically, and on `scenePhase` resign-active as defense-in-depth. Also fixed the `selectedTeam` `didSet` to `removeObject` on nil (symmetry with `selectedCountry`; skipping the optional PL team no longer leaves a stale club). A `#if DEBUG` log in `RootView` reports field presence (not the names — local-only PII) so a TestFlight build can confirm empty-state (write-loss) vs inconsistent-state.

**No server lever** — names are local-only by design, so this can't be hotfixed remotely; affected users keep losing state until the 2.0.1 build is approved. **Lesson: for the single most important local state, never rely on UserDefaults' lazy flush — force `synchronize()` at the write that gates everything, because users force-quit and `cfprefsd` hasn't persisted yet.**
