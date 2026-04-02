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
                    subtitle: "We'll use it to make updates feel more relevant to you.",
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

// MARK: - Name Input View

struct NameInputView: View {
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            TextField(placeholder, text: $name)
                .font(Theme.detailTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .focused($isFocused)
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onContinue(name.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                Text(name.isEmpty ? "Skip" : "Continue")
                    .font(Theme.feedHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Theme.accentWarm, Theme.accentPeach],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Theme.accentWarm.opacity(0.3), radius: 8, y: 4)
            }

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear { isFocused = true }
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

            // Animated celebration
            ZStack {
                Circle()
                    .fill(Theme.accentWarm.opacity(0.12))
                    .frame(width: 130, height: 130)
                    .scaleEffect(showCheck ? 1.0 : 0.5)
                    .opacity(showCheck ? 1.0 : 0.0)

                Text("🎉")
                    .font(.system(size: 60))
                    .scaleEffect(showCheck ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheck)

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(Theme.onboardingTitle)
                    .foregroundStyle(Theme.textPrimary)

                Text("We'll keep you in the loop on \(appState.selectedTeam?.shortName ?? "your team").\nTime to impress 💕")
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
        .background(Theme.backgroundGradient.ignoresSafeArea())
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
