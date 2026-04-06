import SwiftUI
import SwiftData

@main
struct GoalDiggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(for: CachedContentItem.self)
        }
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
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            FeedView(navigationPath: $navigationPath)
                .navigationDestination(for: UUID.self) { contentId in
                    ContentDetailView(contentId: contentId)
                }
                .navigationDestination(for: String.self) { destination in
                    if destination == "settings" {
                        SettingsView()
                    }
                }
        }
        .onChange(of: appState.deepLinkContentId) { _, newId in
            if let id = newId {
                navigationPath.append(id)
                appState.deepLinkContentId = nil
            }
        }
    }
}
