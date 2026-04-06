import SwiftUI

struct WhatToFollowView: View {
    @Environment(AppState.self) var appState
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What does \(appState.hisName.isEmpty ? "he" : appState.hisName) care about?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            VStack(spacing: Layout.cardSpacing) {
                // Premier League — enabled
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("Premier League")
                            .font(.feedHeadline)
                            .foregroundColor(.textPrimaryOnCard)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.textSecondaryOnCard)
                    }
                    .cardStyle()
                }

                // World Cup 2026 — coming soon
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("World Cup 2026")
                            .font(.feedHeadline)
                            .foregroundColor(.textSecondaryOnCard)
                        Text("Coming soon")
                            .font(.feedBadge)
                            .foregroundColor(.textTertiary)
                    }
                    Spacer()
                }
                .cardStyle()
                .opacity(0.6)

                // Both — coming soon
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Both")
                            .font(.feedHeadline)
                            .foregroundColor(.textSecondaryOnCard)
                        Text("Coming soon")
                            .font(.feedBadge)
                            .foregroundColor(.textTertiary)
                    }
                    Spacer()
                }
                .cardStyle()
                .opacity(0.6)
            }
            .padding(.horizontal, Layout.screenPadding)

            Spacer()
        }
    }
}
