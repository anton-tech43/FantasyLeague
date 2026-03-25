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
        }
        .modelContainer(for: CachedContentItem.self)
    }
}

// MARK: - Root Navigation

struct RootView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            FeedView()
        } else {
            OnboardingFlow()
        }
    }
}

// MARK: - Onboarding Flow Container

struct OnboardingFlow: View {
    @Environment(AppState.self) var appState
    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case teamSelection
        case notificationPrompt
    }

    var body: some View {
        switch step {
        case .welcome:
            WelcomeView {
                withAnimation { step = .teamSelection }
            }
        case .teamSelection:
            TeamSelectionView { team in
                appState.selectedTeam = team
                withAnimation { step = .notificationPrompt }
            }
        case .notificationPrompt:
            NotificationPromptView {
                appState.notificationPermissionRequested = true
                appState.hasCompletedOnboarding = true
            }
        }
    }
}
