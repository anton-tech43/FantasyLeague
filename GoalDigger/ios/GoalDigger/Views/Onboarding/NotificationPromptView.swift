import SwiftUI

/// Explains why notifications matter. Shown ONCE, never again.
struct NotificationPromptView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundColor(.accentWarm)

            Text("Don't miss the\ngood stuff")
                .font(.onboardingTitle)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Layout.sectionSpacing)

            Text("We'll ping you when something interesting happens \u{2014} just the highlights, never spam. Promise.")
                .font(.onboardingBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, Layout.elementSpacing)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        _ = await NotificationService.shared.requestPermission()
                        onComplete()
                    }
                } label: {
                    Text("Turn on Notifications")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentWarm)
                        .cornerRadius(16)
                }

                Button {
                    onComplete()
                } label: {
                    Text("Maybe Later")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
    }
}

#Preview {
    NotificationPromptView(onComplete: {})
}
