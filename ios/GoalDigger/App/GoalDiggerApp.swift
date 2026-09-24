import SwiftUI
import SwiftData

@main
struct GoalDiggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase


    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(for: CachedContentItem.self)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if oldPhase == .background && newPhase == .active {
                        // Only REPAIR an invalid active context on resume; never
                        // override a still-valid one. V2.2: a user following two
                        // entities who switched to their 2nd tab must stay there
                        // after backgrounding (the old code snapped everyone back
                        // to entity #1). We only reset when the current context no
                        // longer points at a followed entity (e.g. a removed team,
                        // or a country-only user left on .team(nil)).
                        let stillValid: Bool = {
                            switch appState.activeContext {
                            // A stored country context is invalid while the
                            // feature is off, so the repair below moves her to
                            // a club (or the cross-team feed) on next launch
                            // rather than leaving her on an empty tab.
                            case .country(let c):
                                return CountryFollowing.isEnabled && appState.selectedCountries.contains(c)
                            case .team(let t):    return appState.selectedTeams.contains(t)
                            case .worldChampionship: return WCSeason.isVisible
                            case .everyoneTalking: return true
                            }
                        }()
                        if !stillValid {
                            // Club first. Country only when the feature is on
                            // — otherwise an invalidated country context would
                            // be repaired straight back to the same country.
                            if let team = appState.selectedTeams.first {
                                appState.activeContext = .team(team)
                            } else if CountryFollowing.isEnabled,
                                      let country = appState.selectedCountries.first {
                                appState.activeContext = .country(country)
                            } else {
                                appState.activeContext = .everyoneTalking
                            }
                        }
                        appState.isContextSwitcherOpen = false
                    }
                    if newPhase == .inactive || newPhase == .background {
                        // Flush pending UserDefaults writes before the app can be
                        // suspended or killed. Defends onboarding state (and the
                        // persisted toggles) against a force-quit that would
                        // otherwise drop unflushed writes. See AppState.persistNow.
                        appState.persistNow()
                    }
                    if newPhase == .active {
                        // Foreground fallback: re-assert the push-to-start
                        // registration and, if the followed country has a live
                        // match with no running activity, start one locally.
                        LiveActivityManager.shared.syncForegroundActivity()
                        // Keep his fixtures calendar current on every return to
                        // the app: add new games, drop finished ones. Throttled
                        // + no-op unless sync is on and access is granted.
                        Task {
                            await CalendarSyncService.shared.autoResync(
                                teams: appState.selectedTeams,
                                countries: appState.selectedCountries,
                                enabled: appState.calendarSyncEnabled
                            )
                        }
                    }
                }
        }
    }
}

struct ContentDetailDestination: Hashable {
    let contentId: UUID
    let scrollToTalkingPoints: Bool
    let isEveryoneContext: Bool
    /// Item to render immediately. Set when navigating from a feed (we already have the item in memory).
    /// Push-notification deep links pass `nil`; the detail view falls back to `fetchItem(id:)` in that case.
    let preloadedItem: ContentItem?

    init(contentId: UUID, scrollToTalkingPoints: Bool, isEveryoneContext: Bool = false, preloadedItem: ContentItem? = nil) {
        self.contentId = contentId
        self.scrollToTalkingPoints = scrollToTalkingPoints
        self.isEveryoneContext = isEveryoneContext
        self.preloadedItem = preloadedItem
    }
}

struct RootView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext

    /// V2.0 migration prompt — fires once for V1.x users who finished
    /// onboarding before V2.0 and haven't picked a country yet. Skipped
    /// for new V2.0 users (they pick country during onboarding).
    private var shouldShowWCPrompt: Bool {
        // Season-gated: onboarding no longer picks a country (Sept 2026), so
        // without the gate every new user would get the "pick a WC country"
        // sheet on first launch for a tournament that ended in July.
        WCSeason.isVisible
          && appState.hasCompletedOnboarding
          && appState.selectedCountry == nil
          && !appState.hasSeenWCPrompt
    }

    // No in-app paywall. PurchaseManager and PaywallView were kept unreferenced
    // "in case we add an IAP later" and were deleted on 2026-09-23 — two files
    // compiled into every build for a purchase flow the app does not have, and
    // git remembers them. The comment they left behind also still said £4.99,
    // which Apple's feed has not agreed with since the World Cup.

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingFlow()
                    .onAppear {
                        #if DEBUG
                        // Confirms (in TestFlight) whether a re-onboarding user
                        // lost state entirely (write-flush bug — all <empty>) vs
                        // a partial/inconsistent state. Logs presence only, not
                        // the names (local-only PII).
                        print("🔄 ONBOARDING shown — herName:\(appState.herName.isEmpty ? "<empty>" : "set") hisName:\(appState.hisName.isEmpty ? "<empty>" : "set") team:\(appState.selectedTeam?.rawValue ?? "nil") country:\(appState.selectedCountry?.rawValue ?? "nil")")
                        #endif
                    }
            } else if !appState.hasSeenSeasonPrimer {
                // One-time Season Primer screen (V1.1 task A1). Shows where
                // his team is in the season + 3 text-message-style openers
                // she can send him now. Dismissed permanently for the install
                // when either CTA fires; re-shown only after Settings →
                // Delete My Data → re-onboard.
                SeasonPrimerView(
                    onTeachMore: {
                        appState.pendingTabAfterPrimer = 1   // His Team tab
                        appState.hasSeenSeasonPrimer = true
                    },
                    onSkipToFeed: {
                        appState.pendingTabAfterPrimer = 0   // Feed tab (explicit)
                        appState.hasSeenSeasonPrimer = true
                    }
                )
            } else {
                MainTabView()
                    .sheet(isPresented: Binding(
                        get: { shouldShowWCPrompt },
                        set: { newValue in
                            // Belt-and-braces: if SwiftUI ever flips the
                            // binding to false via a system-initiated
                            // dismiss (swipe-down, hardware back) we MUST
                            // flip hasSeenWCPrompt too, otherwise the
                            // sheet bounces right back on the next render.
                            // The view itself sets the flag in both Skip
                            // and Continue branches before calling dismiss(),
                            // but this handles the path where neither runs.
                            if !newValue { appState.hasSeenWCPrompt = true }
                        }
                    )) {
                        WCMigrationSheetView()
                    }
            }
        }
        .task(id: "cache-schema-purge") {
            // Drop cached rows from a previous app version with an older
            // CacheService.cacheSchemaVersion. Prevents decoding crashes when
            // the ContentItem schema changes between releases. Cheap on every
            // launch — no-op if the cache is already on the current version.
            CacheService.shared.purgeStaleVersionItems(in: modelContext)
        }
        .task(id: "myturn-content-refresh") {
            // Newer My Turn content lands without an app release. Failure is
            // silent; the bundled files are the floor.
            await MyTurnContentService.shared.refresh()
        }
        .task(id: "calendar-autoresync") {
            // Cold-launch fixtures-calendar refresh, so his games stay current
            // even if the app is launched fresh rather than resumed. No-op
            // unless sync is enabled and calendar access is already granted.
            await CalendarSyncService.shared.autoResync(
                teams: appState.selectedTeams,
                countries: appState.selectedCountries,
                enabled: appState.calendarSyncEnabled
            )
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab = 0
    @State private var feedPath = NavigationPath()

    /// V2.0: The "His Team" tab follows the active feed context, so the team
    /// page shows whatever the user has currently selected in the switcher.
    /// Fallback (when on the cross-team `.everyoneTalking` feed): the first
    /// followed entity, so the tab keeps working. teamId keys into the same
    /// `team_pages` table for both entity types.
    ///
    /// Nil means there is nothing to show and the tab hides itself. That is
    /// the country-only user while `CountryFollowing` is off: her country
    /// page is three months stale (the content pipeline behind it is dead),
    /// so the honest answer is no tab rather than a page of June fixtures.
    private var teamPageEntityId: String? {
        switch appState.activeContext {
        case .team(let team):
            return team.rawValue
        case .country(let country):
            return CountryFollowing.isEnabled ? country.rawValue : nil
        case .worldChampionship, .everyoneTalking:
            // Club first: with country following off, a club+country user
            // would otherwise get a country page on the His Team tab.
            if CountryFollowing.isEnabled {
                return appState.selectedCountry?.rawValue ?? appState.selectedTeam?.rawValue
            }
            return appState.selectedTeam?.rawValue
        }
    }

    /// V2.0: Tab label tracks the active entity so the user sees "Arsenal"
    /// or "Sweden" rather than the generic "His Team" — clarifies which
    /// entity the tab is currently showing. On the cross-team feed we fall
    /// back to "His Team" since neither entity is primary.
    private var teamTabLabel: String {
        switch appState.activeContext {
        case .team(let team):
            return team.displayName
        case .country(let country):
            return CountryFollowing.isEnabled ? country.displayName : "His Team"
        case .worldChampionship, .everyoneTalking:
            return "His Team"
        }
    }

    init() {
        let deepMauve = UIColor(red: 45/255, green: 27/255, blue: 46/255, alpha: 1)
        let hotRose = UIColor(red: 232/255, green: 57/255, blue: 125/255, alpha: 1)
        let warmWhiteDim = UIColor(red: 245/255, green: 240/255, blue: 240/255, alpha: 0.4)

        let normalAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: warmWhiteDim]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: hotRose]

        // Tab bar appearance — transparent so card shows through
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = .clear
        tabAppearance.shadowColor = .clear

        for layout in [tabAppearance.stackedLayoutAppearance, tabAppearance.inlineLayoutAppearance, tabAppearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = warmWhiteDim
            layout.normal.titleTextAttributes = normalAttrs
            layout.selected.iconColor = hotRose
            layout.selected.titleTextAttributes = selectedAttrs
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().barTintColor = .clear
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().unselectedItemTintColor = warmWhiteDim

        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = deepMauve
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Feed
            NavigationStack(path: $feedPath) {
                FeedView()
                    .navigationDestination(for: ContentDetailDestination.self) { dest in
                        ContentDetailView(
                            contentId: dest.contentId,
                            scrollToTalkingPoints: dest.scrollToTalkingPoints,
                            isEveryoneContext: dest.isEveryoneContext,
                            preloadedItem: dest.preloadedItem
                        )
                    }
            }
            .tabItem {
                Label("Feed", systemImage: "house")
            }
            .tag(0)

            // Tab 2: His Team. Hidden entirely when there is no entity to
            // show — an empty stack under a "His Team" label reads as a
            // broken screen, and the one case that reaches it (country-only,
            // country following off) has no page worth opening.
            if let teamId = teamPageEntityId {
                NavigationStack {
                    TeamPageView(teamId: teamId)
                        // V2.0 WC preview surface: TeamPageView's Calendar
                        // tab can navigate to a preview content_item's
                        // detail view via NavigationLink(value:
                        // ContentDetailDestination(...)). Same destination
                        // type as the Feed tab uses, so we register the
                        // handler here too. See Lesson 78.
                        .navigationDestination(for: ContentDetailDestination.self) { dest in
                            ContentDetailView(
                                contentId: dest.contentId,
                                scrollToTalkingPoints: dest.scrollToTalkingPoints,
                                isEveryoneContext: dest.isEveryoneContext,
                                preloadedItem: dest.preloadedItem
                            )
                        }
                }
                .tabItem {
                    Label(teamTabLabel, systemImage: "shield")
                }
                .tag(1)
            }

            // Tab 3: My Turn — the toolbox. Quiz / Lingo / Say This.
            // Static, offline, no live data; everything here is always true,
            // which is the rule that separates it from the Feed.
            NavigationStack {
                MyTurnView()
            }
            .tabItem {
                Label("My Turn", systemImage: "text.book.closed")
            }
            .tag(2)

            // Tab 4: Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
        }
        .tint(.hotRose)
        // Tab 1 can disappear (see teamPageEntityId). A selection pointing at
        // a tag no tab carries leaves the TabView showing nothing at all, so
        // send her to the feed instead.
        .onChange(of: teamPageEntityId) { _, id in
            if id == nil && selectedTab == 1 { selectedTab = 0 }
        }
        .task {
            // ATT, 1.5 s after the tabs first appear — never in onboarding,
            // where the notification prompt already asks for something.
            await Attribution.requestTrackingIfNeeded()
        }
        .onChange(of: appState.deepLinkContentId) { _, newId in
            if let id = newId {
                selectedTab = 0
                let isEveryone = appState.activeContext == .everyoneTalking
                feedPath.append(ContentDetailDestination(
                    contentId: id,
                    scrollToTalkingPoints: false,
                    isEveryoneContext: isEveryone
                ))
                appState.deepLinkContentId = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedNavigateToDetail)) { notification in
            if let dest = notification.object as? ContentDetailDestination {
                selectedTab = 0
                feedPath.append(dest)
            }
        }
        .onAppear {
            // Consume the Season Primer's "Teach me more" / "Take me to the
            // news" preference, set by SeasonPrimerView's CTAs before the
            // primer dismissed. Clear immediately so subsequent re-appears
            // (e.g., scenePhase background→active) don't snap back to it.
            if let tab = appState.pendingTabAfterPrimer {
                selectedTab = (tab == 1 && teamPageEntityId == nil) ? 0 : tab
                appState.pendingTabAfterPrimer = nil
            }
            #if DEBUG
            // Screenshot harness. `xcrun simctl launch <udid> com.goaldigger.app
            // -gdSkipATT -gdTab 2 -gdOpenItem <uuid>` lands on a tab or a
            // detail view without anyone tapping — simctl cannot tap, and a
            // deterministic starting point is what a visual check needs.
            // `-gdSkipATT` belongs on every harness launch: without it the ATT
            // sheet slides up 1.5 s after the tabs appear and covers whatever
            // was being photographed (IOS_GOTCHAS §19).
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-gdTab"), i + 1 < args.count, let tab = Int(args[i + 1]) {
                selectedTab = (tab == 1 && teamPageEntityId == nil) ? 0 : tab
            }
            if let i = args.firstIndex(of: "-gdOpenItem"), i + 1 < args.count, let id = UUID(uuidString: args[i + 1]) {
                appState.deepLinkContentId = id
            }
            #endif
            // Cold-launch deep-link catch. If the user tapped a notification
            // while the app was killed, AppDelegate sets deepLinkContentId
            // during launch — which may run BEFORE this view first mounts.
            // The `.onChange` below only fires on subsequent transitions, so
            // an already-set value would otherwise be silently dropped.
            if let id = appState.deepLinkContentId {
                selectedTab = 0
                let isEveryone = appState.activeContext == .everyoneTalking
                feedPath.append(ContentDetailDestination(
                    contentId: id,
                    scrollToTalkingPoints: false,
                    isEveryoneContext: isEveryone
                ))
                appState.deepLinkContentId = nil
            }
        }
    }
}
