import SwiftUI

struct NotificationPromptView: View {
    @Environment(AppState.self) var appState
    let onComplete: () -> Void

    /// First "I'll do this later" tap opens a smaller explainer instead of
    /// skipping outright — the app is almost nothing without push, so we make
    /// the case once more before accepting the skip.
    @State private var showSecondChance = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                // Subtle rose glow behind bell
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.hotRose.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "bell.badge")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.hotRose)
            }
            .padding(.bottom, 8)

            Text("It only works if\nwe can reach you.")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Text("GoalDigger lives in your notifications: the heads-up before kickoff, the score as it happens, the one line that starts the conversation. Turn them off and you'll miss the moments that matter.")
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Spacer()

            VStack(spacing: 12) {
                Button("Yes, keep me posted") {
                    Task {
                        _ = await NotificationService.shared.requestPermission()
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("I'll do this later") {
                    showSecondChance = true
                }
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.6))
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showSecondChance) {
            secondChanceSheet
        }
    }

    /// A lighter-weight nudge after the first skip, giving her a second tap to
    /// allow before we let her through.
    private var secondChanceSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.hotRose)
                .padding(.top, 8)

            Text("One more thing.")
                .font(.feedHeadline)
                .foregroundColor(.warmWhite)

            Text("Without notifications, you won't know he's playing until he's already talking about it. It's the whole point of the app, and you can mute it any time.")
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button("Allow notifications") {
                    showSecondChance = false
                    Task {
                        _ = await NotificationService.shared.requestPermission()
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("I'll risk missing it") {
                    showSecondChance = false
                    finish()
                }
                .font(.onboardingBody)
                .foregroundColor(.warmWhite.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.deepMauve)
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appState.notificationPermissionRequested = true
        // Token registration happens at the END of onboarding (in OnboardingFlow's
        // completion handler) so we register with the actual tier the user picks.
        onComplete()
    }
}
