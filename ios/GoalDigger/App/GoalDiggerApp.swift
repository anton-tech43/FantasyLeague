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
                        // Reset to the user's anchor entity on resume. V2.0:
                        // country takes precedence over team (matches AppState.init
                        // priority — WC is the primary anchor when both are set).
                        // Without this, a V2.0 country-only user returning from
                        // background lands on .team(nil) which renders nothing.
                        if let country = appState.selectedCountry {
                            appState.activeContext = .country(country)
                        } else if let team = appState.selectedTeam {
                            appState.activeContext = .team(team)
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
        appState.hasCompletedOnboarding
          && appState.selectedCountry == nil
          && !appState.hasSeenWCPrompt
    }

    // Paid app on App Store (£4.99) — no in-app paywall. Purchase is enforced at the
    // storefront before download. PurchaseManager + PaywallView are kept in the
    // codebase but unreferenced; can be re-wired if we add an IAP later
    // (e.g. World Cup pass).
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
    }
}

struct MainTabView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab = 0
    @State private var feedPath = NavigationPath()

    /// V2.0: The "His Team" tab follows the active feed context, so the team
    /// page shows whatever the user has currently selected in the switcher.
    /// Fallback (when on the cross-team `.everyoneTalking` feed): country
    /// preferred over team, matching AppState's activeContext default picker.
    /// teamId keys into the same `team_pages` table for both entity types.
    private var teamPageEntityId: String? {
        switch appState.activeContext {
        case .team(let team):
            return team.rawValue
        case .country(let country):
            return country.rawValue
        case .everyoneTalking:
            return appState.selectedCountry?.rawValue ?? appState.selectedTeam?.rawValue
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
            return country.displayName
        case .everyoneTalking:
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
                    .navigationDestination(for: String.self) { destination in
                        if destination == "playerCards",
                           let teamId = teamPageEntityId {
                            // V2.0: WC-only users can navigate here too — use
                            // teamPageEntityId (country-first fallback) so the
                            // PlayerCardsListView gets a valid entityId. The
                            // view itself handles "no rows" empty state.
                            PlayerCardsListView(teamId: teamId)
                        }
                    }
            }
            .tabItem {
                Label("Feed", systemImage: "house")
            }
            .tag(0)

            // Tab 2: His Team — V2.0: prefer country (WC primary) over team
            // (PL). If neither is set, render an empty NavigationStack
            // (shouldn't happen in normal flow but defensive).
            NavigationStack {
                if let teamId = teamPageEntityId {
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
            }
            .tabItem {
                Label(teamTabLabel, systemImage: "shield")
            }
            .tag(1)

            // Tab 3: Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(2)
        }
        .tint(.hotRose)
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
                selectedTab = tab
                appState.pendingTabAfterPrimer = nil
            }
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
