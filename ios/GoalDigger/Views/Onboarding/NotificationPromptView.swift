import SwiftUI

struct NotificationPromptView: View {
    @Environment(AppState.self) var appState
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundStyle(Color.hotRose)
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

                Button("maybe later") {
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
        appState.notificationPermissionRequested = true
        // Register token with server if we have one
        if let token = UserDefaults.standard.string(forKey: "apnsToken"),
           let team = appState.selectedTeam {
            Task {
                try? await APIClient.shared.registerToken(token, teamId: team.rawValue, tier: appState.selectedTier)
            }
        }
        onComplete()
    }
}
