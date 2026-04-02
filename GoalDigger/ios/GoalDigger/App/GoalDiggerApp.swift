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
    @Environment(AppState.self) private var appState
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
                    withAnimation { currentStep = 3 }
                }
            case 3:
                OnboardingCelebrationView()
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

// MARK: - Onboarding Celebration

struct OnboardingCelebrationView: View {
    @Environment(AppState.self) private var appState
    @State private var showCheck = false
    @State private var showText = false

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Theme.accentGreen.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showCheck ? 1.0 : 0.5)
                    .opacity(showCheck ? 1.0 : 0.0)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(Theme.accentGreen)
                    .scaleEffect(showCheck ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheck)

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(Theme.onboardingTitle)
                    .foregroundStyle(Theme.textPrimary)

                Text("We'll keep you in the loop on \(appState.selectedTeam?.shortName ?? "your team"). Time to impress.")
                    .font(Theme.onboardingBody)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .opacity(showText ? 1.0 : 0.0)
            .offset(y: showText ? 0 : 10)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: showText)

            Spacer()
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.appBackground.ignoresSafeArea())
        .onAppear {
            showCheck = true
            showText = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Auto-advance to feed after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    appState.hasCompletedOnboarding = true
                }
            }
        }
    }
}
