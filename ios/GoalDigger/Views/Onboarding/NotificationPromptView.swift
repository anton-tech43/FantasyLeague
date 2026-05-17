import SwiftUI

struct NotificationPromptView: View {
    @Environment(AppState.self) var appState
    let onComplete: () -> Void

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

            Text("We'll handle the rest.\nJust let us in.")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Text("We'll only ping you when it matters. Never spam. Promise.")
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
                    finish()
                }
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.6))
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appState.notificationPermissionRequested = true
        // Token registration happens at the END of onboarding (in OnboardingFlow's
        // completion handler) so we register with the actual tier the user picks.
        // V1.1 registered here with `appState.selectedTier`, which was still the
        // default (2) because tier selection came AFTER this step in the old order.
        // The new flow puts notifications BEFORE tier — keep registration deferred.
        onComplete()
    }
}
