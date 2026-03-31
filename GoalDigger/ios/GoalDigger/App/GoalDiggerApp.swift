import SwiftUI
import SwiftData

@main
struct GoalDiggerApp: App {
    @State private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            FeedView()
        } else {
            OnboardingFlow()
        }
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    @State private var currentStep = 0

    var body: some View {
        Group {
            switch currentStep {
            case 0:
                WelcomeView {
                    withAnimation { currentStep = 1 }
                }
            case 1:
                TeamSelectionView {
                    withAnimation { currentStep = 2 }
                }
            case 2:
                NotificationPromptView {
                    // Onboarding complete — RootView will switch to FeedView
                    // because hasCompletedOnboarding is now true
                }
            default:
                EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ))
    }
}
