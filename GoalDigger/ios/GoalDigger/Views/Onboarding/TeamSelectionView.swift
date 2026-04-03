import SwiftUI

// MARK: - TeamSelectionView
// Team selection during onboarding — updated with gradient CTA.
//
// Design decisions for other agents:
// - Uses partner's name if available: "Which team does Jake support?"
// - Gradient CTA button matches new design system
// - Selected team gets terracotta border highlight

struct TeamSelectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTeam: Team?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            // Title — personalized if partner name is known
            Text(titleText)
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text("Pick one and we'll keep you in the loop.")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)

            // Team cards
            VStack(spacing: Theme.cardSpacing) {
                ForEach(Team.allCases) { team in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTeam = team
                        }
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    } label: {
                        HStack {
                            Text(team.displayName)
                                .font(Theme.feedHeadline)
                                .foregroundStyle(Theme.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.body)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(Theme.cardPadding)
                        .frame(height: 80)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                .stroke(
                                    selectedTeam == team ? Theme.accentWarm : .clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: Theme.cardShadow,
                            radius: Theme.cardShadowRadius,
                            x: 0,
                            y: Theme.cardShadowY
                        )
                        .scaleEffect(selectedTeam == team ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Gradient CTA — appears when team selected
            if selectedTeam != nil {
                Button {
                    appState.selectedTeam = selectedTeam
                    onContinue()
                } label: {
                    Text("Continue")
                        .gradientButton()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: selectedTeam)
    }

    private var titleText: String {
        if let partner = appState.partnerName {
            return "Which team does\n\(partner) support?"
        }
        return "Which team does\nhe support?"
    }
}
