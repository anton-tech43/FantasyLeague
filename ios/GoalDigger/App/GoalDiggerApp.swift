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

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainTabView()
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
        // Tab bar appearance: deep mauve background with rose top border
        let deepMauve = UIColor(red: 45/255, green: 27/255, blue: 46/255, alpha: 1)
        let hotRose = UIColor(red: 232/255, green: 57/255, blue: 125/255, alpha: 1)
        let warmWhiteDim = UIColor(red: 245/255, green: 240/255, blue: 240/255, alpha: 0.4)

        let normalAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: warmWhiteDim]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: hotRose]

        // Configure both standard and scrollEdge identically so no iOS override can slip in
        for appearance in [UITabBarAppearance(), UITabBarAppearance()] {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = deepMauve
            appearance.shadowColor = UIColor(red: 232/255, green: 57/255, blue: 125/255, alpha: 0.2)

            appearance.stackedLayoutAppearance.normal.iconColor = warmWhiteDim
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.stackedLayoutAppearance.selected.iconColor = hotRose
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs

            appearance.inlineLayoutAppearance.normal.iconColor = warmWhiteDim
            appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.inlineLayoutAppearance.selected.iconColor = hotRose
            appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs

            appearance.compactInlineLayoutAppearance.normal.iconColor = warmWhiteDim
            appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.compactInlineLayoutAppearance.selected.iconColor = hotRose
            appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        UITabBar.appearance().barTintColor = deepMauve
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().unselectedItemTintColor = warmWhiteDim
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
