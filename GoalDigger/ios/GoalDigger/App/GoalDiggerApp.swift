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
// 6 steps: Welcome → Your Name → Partner Name → Team → Notifications → Celebration
//
// Design decisions for other agents:
// - Name inputs are inline views (not separate files) to avoid pbxproj registration
// - Celebration screen sets hasCompletedOnboarding (not NotificationPromptView)
// - Each step uses gradient background and serif fonts for editorial feel
// - NameInputView is reused for both user name and partner name

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
                NameInputView(
                    title: "What's your name?",
                    subtitle: "So we can make this feel personal.",
                    placeholder: "Your name",
                    onContinue: { name in
                        appState.userName = name.isEmpty ? nil : name
                        withAnimation { currentStep = 2 }
                    }
                )
            case 2:
                NameInputView(
                    title: "And his name?",
                    subtitle: "The football fan in your life.",
                    placeholder: "His name",
                    onContinue: { name in
                        appState.partnerName = name.isEmpty ? nil : name
                        withAnimation { currentStep = 3 }
                    }
                )
            case 3:
                TeamSelectionView {
                    withAnimation { currentStep = 4 }
                }
            case 4:
                NotificationPromptView {
                    withAnimation { currentStep = 5 }
                }
            case 5:
                OnboardingCelebrationView {
                    appState.hasCompletedOnboarding = true
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

// MARK: - Name Input View (inline — used for both user and partner name)
// Kept inline in this file to avoid needing a new pbxproj entry.

private struct NameInputView: View {
    let title: String
    let subtitle: String
    let placeholder: String
    let onContinue: (String) -> Void
    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            Text(title)
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)

            TextField(placeholder, text: $name)
                .font(Theme.detailTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .padding(.vertical, 16)
                .overlay(
                    Rectangle()
                        .fill(Theme.accentPink)
                        .frame(height: 2),
                    alignment: .bottom
                )
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onContinue(name)
            } label: {
                Text(name.isEmpty ? "Skip" : "Continue")
                    .gradientButton()
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear { isFocused = true }
    }
}

// MARK: - Onboarding Celebration View
// Final onboarding step — confirms setup and sets hasCompletedOnboarding.

private struct OnboardingCelebrationView: View {
    @Environment(AppState.self) private var appState
    let onComplete: () -> Void
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Animated celebration
            Text("🎉")
                .font(.system(size: 70))
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.5).repeatCount(1),
                    value: isAnimating
                )

            Text("You're all set!")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: 8) {
                if let partner = appState.partnerName, let team = appState.selectedTeam {
                    Text("We'll keep you in the loop on \(partner)'s \(team.shortName).")
                        .font(Theme.onboardingBody)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("We'll keep you in the loop on \(appState.selectedTeam?.shortName ?? "your team").")
                        .font(Theme.onboardingBody)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("Time to impress.")
                    .font(Theme.conversationStarter)
                    .foregroundStyle(Theme.accentPink)
            }
            .frame(maxWidth: 300)

            Spacer()

            Button(action: onComplete) {
                Text("Let's go!")
                    .gradientButton()
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear { isAnimating = true }
    }
}
