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
                        // Reset to team context and notify FeedView to reset scroll positions
                        if let team = appState.selectedTeam {
                            appState.activeContext = .team(team)
                        }
                        appState.isContextSwitcherOpen = false
                    }
                }
        }
    }
}

struct ContentDetailDestination: Hashable {
    let contentId: UUID
    let scrollToTalkingPoints: Bool
    let isEveryoneContext: Bool

    init(contentId: UUID, scrollToTalkingPoints: Bool, isEveryoneContext: Bool = false) {
        self.contentId = contentId
        self.scrollToTalkingPoints = scrollToTalkingPoints
        self.isEveryoneContext = isEveryoneContext
    }
}

struct RootView: View {
    @Environment(AppState.self) var appState
    @State private var purchaseManager = PurchaseManager.shared

    var body: some View {
        if appState.hasCompletedOnboarding {
            #if DEBUG
            MainTabView()
            #else
            if purchaseManager.isPurchased {
                MainTabView()
            } else {
                PaywallView()
            }
            #endif
        } else {
            OnboardingFlow()
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab = 0
    @State private var feedPath = NavigationPath()

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
                        ContentDetailView(contentId: dest.contentId, scrollToTalkingPoints: dest.scrollToTalkingPoints, isEveryoneContext: dest.isEveryoneContext)
                    }
                    .navigationDestination(for: String.self) { destination in
                        if destination == "playerCards",
                           let teamId = appState.selectedTeam?.rawValue {
                            PlayerCardsListView(teamId: teamId)
                        }
                    }
            }
            .tabItem {
                Label("Feed", systemImage: "house")
            }
            .tag(0)

            // Tab 2: His Team
            NavigationStack {
                if let teamId = appState.selectedTeam?.rawValue {
                    TeamPageView(teamId: teamId)
                }
            }
            .tabItem {
                Label("His Team", systemImage: "shield")
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
    }
}
