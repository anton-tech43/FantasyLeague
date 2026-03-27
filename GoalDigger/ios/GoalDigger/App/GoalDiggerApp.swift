import SwiftUI
import SwiftData

@main
struct GoalDiggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(for: [CachedContentItem.self])
    }
}

/// Root view that switches between onboarding and the main feed
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
    }
}

/// Placeholder for main tab-based navigation (Feed + Settings)
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack(path: Binding(
            get: { appState.navigationPath },
            set: { appState.navigationPath = $0 }
        )) {
            FeedView()
                .navigationDestination(for: ContentItem.self) { item in
                    ContentDetailView(item: item)
                }
        }
    }
}

/// Placeholder onboarding flow container
struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView(selection: Binding(
            get: { appState.onboardingStep },
            set: { appState.onboardingStep = $0 }
        )) {
            WelcomeView()
                .tag(0)
            TeamSelectionView()
                .tag(1)
            NotificationPromptView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}
