# GoalDigger iOS App — Brief Alignment Implementation Plan

## Overview

This plan covers all changes needed to align the GoalDigger iOS app with the new product brief. The app currently has 28 Swift files across a SwiftUI / iOS 17+ / NavigationStack architecture backed by Supabase. Changes span the design system, navigation architecture, onboarding flow, feed, detail view, settings, team page, and player cards.

---

## Phase 1: Design System Foundation (Theme.swift)

**Priority: CRITICAL — blocks every other phase**

All subsequent UI work depends on the design tokens being correct first.

### File: `ios/GoalDigger/Design/Theme.swift`

**Color changes:**

1. **Remove** `accentGreen` (#3DA66C) entirely. The brief says "never use green anywhere."
2. **Remove** `accentWarm` (#D4725C) and `accentSoft` (#F0DDD5) — not in the brief palette.
3. **Add** `charcoal = Color(hex: "#2C2C2C")` — used for all text on light/blush surfaces.
4. **Add** `mutedText = Color(hex: "#9B8FA0")` — for timestamps, secondary labels, placeholder text.
5. **Replace** `textPrimaryOnCard` from `#2D1B2E` (deepMauve) to `#2C2C2C` (charcoal).
6. **Replace** `textSecondaryOnCard` from `#8A7080` to `#9B8FA0` (mutedText).
7. **Replace** `textTertiary` from `#B8A0AA` to `#9B8FA0` (mutedText) — unify secondary/tertiary into one muted tone.
8. **Update badge colors:**
   - `badgeNews` bg: `Color.hotRose` (was accentSoft)
   - `badgeNewsText`: `Color.warmWhite` (was accentWarm)
   - `badgeMatchday` bg: `Color.gold` (was accentGreen.opacity(0.2))
   - `badgeMatchdayText`: `Color.charcoal` (was accentGreen)
9. **Fix win/lose tints** — `winTint` and `winBar` use `Color.green`, replace with `Color.hotRose.opacity(0.08)` and `Color.hotRose.opacity(0.5)` (or gold). `loseTint`/`loseBar` using red is fine per brief.
10. **Replace all remaining references** to `accentWarm` and `accentSoft` throughout the codebase (ContentCard "Read more", TalkingPointCard bar, PostMatchCard, shareSection) with `Color.hotRose` variants.

**Typography changes:**

11. The brief specifies "Plus Jakarta Sans." This is a custom font that must be bundled:
    - Add PlusJakartaSans .ttf/.otf files to `ios/GoalDigger/Resources/Fonts/`
    - Register in `Info.plist` under `UIAppFonts` (the plist already exists)
    - Create a `Font` extension wrapping `Font.custom("PlusJakartaSans-...", size:)` for each weight
    - Update all `Font.system(.., design: .rounded)` references to use the custom font
    - **Fallback option**: If bundling is deferred, keep `Font.system(.., design: .rounded)` as closest system equivalent and leave a TODO

**Layout changes:**

12. Add `Layout.badgeCornerRadius: CGFloat = 999` — fully rounded pills for badges/tags (currently 8).
13. Change `Layout.cardSpacing` from `12` to `10`.

**Cursor tint:**

14. Add a global `UITextField.appearance().tintColor = UIColor(Color.hotRose)` in `AppDelegate` or at app init to make all text input cursors rose.

### Ripple effect — files referencing removed colors:

After removing `accentWarm`, `accentSoft`, `accentGreen`, grep and replace across:
- `ContentCard.swift` — "Read more" color (accentWarm -> hotRose)
- `ContentDetailView.swift` — TalkingPointCard bar (accentWarm -> hotRose), PostMatchCard tint (accentSoft -> softBlush), share button (accentWarm -> hotRose)
- `BadgeView.swift` — badge colors (handled by semantic aliases above)
- `FeedView.swift` — FreshnessCard uses `.green` for "caught up" icon (line 116) — change to hotRose

---

## Phase 2: Navigation Architecture (TabView)

**Priority: HIGH — structural change affecting routing for His Team and Settings**

### File: `ios/GoalDigger/App/GoalDiggerApp.swift`

The current `MainTabView` is a `NavigationStack` with no tabs. It needs to become a real `TabView`.

**Changes:**

1. **Rewrite** `MainTabView` to wrap a `TabView` with three tabs:
   - Tab 1: **Feed** — `house.fill` icon, contains FeedView inside its own NavigationStack
   - Tab 2: **His Team** — `tshirt.fill` or custom icon, contains TeamPageView inside its own NavigationStack
   - Tab 3: **Settings** — `gearshape.fill` icon, contains SettingsView inside its own NavigationStack

2. **Tab bar styling:**
   - Background: `Color.deepMauve`
   - Inactive icon color: `Color.warmWhite.opacity(0.5)`
   - Active icon color: `Color.hotRose`
   - Top border: `Color.hotRose.opacity(0.2)`, 1px line
   - Use `UITabBar.appearance()` in AppDelegate for colors

3. **Each tab owns its own NavigationStack** — this eliminates the need to pass a shared `navigationPath` binding. FeedView creates its own `@State private var navigationPath`.

4. **Remove from FeedView.swift:**
   - The toolbar trailing gear icon (settings is now a tab)
   - The `"settings"` and `"teamPage"` cases from `.navigationDestination(for: String.self)`

5. **Deep link handling** stays on the Feed tab's NavigationStack.

### File: `ios/GoalDigger/Views/Feed/FeedView.swift`

6. Change `@Binding var navigationPath: NavigationPath` to `@State private var navigationPath = NavigationPath()` — FeedView now owns its own navigation state.

---

## Phase 3: Team Model Expansion (Team.swift)

**Priority: HIGH — blocks onboarding TeamSelectionView and His Team tab**

### File: `ios/GoalDigger/Models/Team.swift`

1. **Expand** the `Team` enum from 3 cases to all 20 Premier League teams:
   arsenal, astonVilla, bournemouth, brentford, brighton, chelsea, crystalPalace, everton, fulham, ipswich, leicester, liverpool, manCity, manUtd, newcastle, nottmForest, southampton, tottenham, westHam, wolves

2. **Add** `displayName` and `shortName` for all 20 teams.

3. **Add** `badgeImageName: String` computed property for each club crest asset. Add 20 badge images to `Resources/Assets.xcassets`. Use placeholder SF Symbols initially if images unavailable.

4. **Add** `searchableText: String` combining displayName, shortName, and common nicknames to support search.

### File: `ios/GoalDigger/Models/MockData.swift`

5. Update mock data team IDs if needed for expanded enum.

---

## Phase 4: Onboarding Flow Updates

**Priority: HIGH — first-run experience**

### New File: `ios/GoalDigger/Design/Components/ProgressDotsView.swift`

1. Create reusable progress dots component:
   - Takes `totalSteps: Int` and `currentStep: Int`
   - Current dot: filled `Color.hotRose`; others: `Color.deepMauve.opacity(0.4)`
   - Centered, at top of screen below safe area

### File: `ios/GoalDigger/Views/Onboarding/OnboardingFlow.swift`

2. Add `CaseIterable` to `OnboardingStep` enum and integrate `ProgressDotsView` into the ZStack overlay, computing the current index.

### File: `ios/GoalDigger/Views/Onboarding/WelcomeView.swift`

3. Change `"Goal Digger"` to `"GoalDigger"`.
4. Change icon from `"bubble.left.and.bubble.right"` to `"bubble.left"` (single chat bubble with football stitch pattern — use placeholder, mark TODO for custom asset).
5. Tighten spacing, pin button to bottom 40px from safe area.

### File: `ios/GoalDigger/Views/Onboarding/HerNameView.swift`

6. Rose cursor handled globally (Phase 1 step 14).
7. Add conditional rose border overlay on the TextField: `Color.hotRose` stroke when focused, no border when unfocused and empty.

### File: `ios/GoalDigger/Views/Onboarding/HisNameView.swift`

8. Same border treatment as HerNameView.
9. Change headline from `"And what's his?"` to `"And what's his name?"`.

### File: `ios/GoalDigger/Views/Onboarding/WhatToFollowView.swift`

10. **Recommended: Remove this screen entirely.** The brief says remove "Coming soon" options, and only Premier League is available — the screen adds friction without value. Update `OnboardingFlow` to skip from `.hisName` to `.teamSelection`. Remove `.whatToFollow` from the enum.
    - Alternative: Make all 3 selectable with rose border + checkmark, add contextual icons, remove chevrons.

### File: `ios/GoalDigger/Views/Onboarding/TeamSelectionView.swift`

11. Show all 20 teams (iterates `Team.allCases` after Phase 3 expansion).
12. Add search bar at the top: `@State private var searchText`, `TextField` with rose tint, filtering by `searchableText`.
13. Add club badge images to each row.
14. Remove chevron arrows on unselected rows.
15. Change subtitle from `"Pick one and we'll keep you in the loop."` to `"His team. Your new obsession."`.

### File: `ios/GoalDigger/Design/Components/TeamPickerCard.swift`

16. Mirror the same changes (badges, no chevrons on unselected) for the Settings team picker.

### File: `ios/GoalDigger/Views/Onboarding/TierSelectionView.swift`

17. Add tier icons: Tier 1 `"cup.and.saucer"`, Tier 2 `"bolt"`, Tier 3 `"crown"`.
18. Update descriptions: Tier 1 `"Just the essentials. No overload."`, Tier 2 `"Enough to hold your own in any conversation."`, Tier 3 `"She knows things he hasn't even googled yet."`.
19. Dynamic button text: Tier 1 → `"Sounds good"`, Tier 2 → `"Let's do this"`, Tier 3 → `"Say less"`.

### File: `ios/GoalDigger/Views/Onboarding/NotificationPromptView.swift`

20. Add rose glow behind bell icon: `.shadow(color: Color.hotRose.opacity(0.4), radius: 20)`.
21. Change `"maybe later"` to `"I'll do this later"`.

---

## Phase 5: Feed Redesign

**Priority: HIGH — core daily experience**

### New File: `ios/GoalDigger/Views/Feed/YourMoveCard.swift`

1. Create YOUR MOVE hero card:
   - Rose background (`Color.hotRose`), warm white text
   - "YOUR MOVE" tag pill: charcoal bg, warm white text, 999 corner radius
   - Content varies by tier (tier 1: 1 sentence, tier 2-3: full context)
   - Derive from first talking point of most recent ContentItem
   - Always first card in feed

### New File: `ios/GoalDigger/Views/Feed/MatchDayCard.swift`

2. Create MATCH DAY card:
   - Deep mauve bg with gold border (2px)
   - "MATCH DAY" tag pill: gold text on dark bg
   - Shows: teams, kickoff, stakes, 3 players to watch
   - Tapping navigates to ContentDetailView

### File: `ios/GoalDigger/Views/Feed/FeedView.swift`

3. Reorder cards: YOUR MOVE first, then MATCH DAY, then NEWS by date.
4. Separate matchday items from news in the items array.
5. Remove gear icon from toolbar (moved to tab in Phase 2).
6. Update team pill: rose border, rose chevron color.

### File: `ios/GoalDigger/Design/Components/ContentCard.swift`

7. Update "Read more" color from `.accentWarm` to `.hotRose`.

### File: `ios/GoalDigger/Design/Components/BadgeView.swift`

8. Update corner radius from `8` to `999` for fully rounded pills.
9. Badge colors already updated via Theme.swift in Phase 1.

---

## Phase 6: Article Detail Redesign

**Priority: MEDIUM — read experience improvements**

### File: `ios/GoalDigger/Views/Detail/ContentDetailView.swift`

1. **Headline font heavier**: Update `detailTitle` in Theme.swift to `.heavy` or `.black` weight.
2. **Increase spacing** between tag row and headline.
3. **"THINGS TO SAY" icon**: Make rose and slightly larger (14-16pt instead of 12pt).
4. **Talking point left border**: Change `accentWarm` to `hotRose` in TalkingPointCard.
5. **"THE BACKSTORY" collapsible**: Add `@State private var isBackstoryExpanded = false`, wrap bodySection in a custom expandable. Collapsed by default with rose chevron.
6. **Share icon to top right**: Move ShareLink to `.toolbar(placement: .topBarTrailing)`. Remove the bottom full-width share button.
7. **Remove em dashes**: Add stripping to `AppState.personalise()`.
8. **Update PostMatchCard colors**: Replace `accentSoft`/`accentWarm` with `softBlush`/`hotRose`.

---

## Phase 7: Settings Overhaul

**Priority: MEDIUM — settings restructuring**

### File: `ios/GoalDigger/Views/Settings/SettingsView.swift`

1. `"Goal Digger"` → `"GoalDigger"` in About.
2. Green checkmark → rose: change `.foregroundColor(.green)` to `.foregroundColor(.hotRose)` on line 76.
3. `"Your Team"` → `"[His name]'s Team"`.
4. `"Your Level"` → `"Your Mode"`.
5. Add "Your Name" and "His Name" editable rows (tap → sheet with text field).
6. Group rows under section headers: "YOUR SETUP", "NOTIFICATIONS", "ABOUT". Style: small uppercase muted rose text.
7. About copy: `"For the girlfriend who's done nodding along. Made for her, not him."`.
8. Delete My Data text: `.foregroundColor(.red)` → `.foregroundColor(.hotRose)`.
9. Version number: `.font(.caption2)` and more muted color.

---

## Phase 8: His Team Page Rebuild

**Priority: MEDIUM — accessed via new tab**

### File: `ios/GoalDigger/Views/Team/TeamPageView.swift`

1. Rebuild with 5 card sections: Basics, Manager, Ones to Know, Rivalry, Right Now.
2. Club badge centered at top.
3. Fix text colors: ensure warm white text on dark backgrounds throughout.
4. Remove founded year, trophy cabinet, stats (exclude from the redesign).
5. Data model: existing `TeamPageContent` has nickname/stadium/manager/topPlayers/biggestRival/funFact/seasonSummary — roughly maps to 5 cards but may need reorganization.

---

## Phase 9: Player Card Modal

**Priority: LOW — interaction pattern change**

### File: `ios/GoalDigger/Views/Player/PlayerCardView.swift`

1. Change from navigation push to modal (`.sheet` or custom overlay).
2. Add `@State var presentedPlayer: PlayerCard?` to a shared coordinator or AppState.
3. Attach `.sheet(item: $presentedPlayer)` at root view level.
4. Background: soft blush (`Color.softBlush`).
5. Dismiss: tap outside or swipe down (default sheet behavior).

### File: `ios/GoalDigger/Views/Matchday/OnesToWatchView.swift`

6. Make player names tappable, triggering the player card modal.

---

## Phase 10: Polish and Cleanup

**Priority: LOW — final pass**

1. Em-dash removal globally via `AppState.personalise()`.
2. Verify "your boyfriend" replacement uses placeholders in server content.
3. FreshnessCard: change `.green` icon to `.hotRose`.
4. Global audit for remaining green references.
5. Test all onboarding paths with progress dots.
6. Test deep linking with new TabView architecture.

---

## New Files Summary

| File | Purpose |
|------|---------|
| `ios/GoalDigger/Design/Components/ProgressDotsView.swift` | Reusable onboarding progress indicator |
| `ios/GoalDigger/Views/Feed/YourMoveCard.swift` | Hero YOUR MOVE card |
| `ios/GoalDigger/Views/Feed/MatchDayCard.swift` | Redesigned match day card |

## Dependency Graph

```
Phase 1 (Theme) ──────────────────────── blocks everything
    │
    ├── Phase 2 (TabView) ─────────────── blocks Phase 5, 7, 8
    │       │
    │       ├── Phase 5 (Feed) ────────── needs TabView + Theme
    │       ├── Phase 7 (Settings) ────── needs TabView + Theme
    │       └── Phase 8 (Team Page) ───── needs TabView + Theme + Phase 3
    │
    ├── Phase 3 (Team Model) ──────────── blocks Phase 4 (TeamSelection), Phase 8
    │       │
    │       └── Phase 4 (Onboarding) ──── needs Theme + Team Model
    │
    ├── Phase 6 (Detail View) ─────────── needs Theme only
    │
    └── Phase 9 (Player Modal) ────────── needs Theme + Phase 8
         │
         └── Phase 10 (Polish) ────────── final pass after all phases
```

## Estimated Scope

- **Files modified**: 19 existing files
- **Files created**: 3 new files
- **Font assets**: 4-6 font weight files for Plus Jakarta Sans (if bundling)
- **Image assets**: 20 club badge images (can use placeholders initially)
- **Risk areas**: TabView migration (navigation state management), 20-team expansion (API compatibility), font bundling (binary size)
