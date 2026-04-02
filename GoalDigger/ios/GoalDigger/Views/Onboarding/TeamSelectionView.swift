import SwiftUI

struct TeamSelectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTeam: Team?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            // Title
            Text("Which team does\nhe support?")
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

            // Continue button — appears when team selected
            if selectedTeam != nil {
                Button {
                    appState.selectedTeam = selectedTeam
                    onContinue()
                } label: {
                    Text("Continue")
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: selectedTeam)
    }
}
