import SwiftUI
import UIKit

/// Onboarding step where the user picks their partner's team.
struct TeamSelectionView: View {
    let onTeamSelected: (Team) -> Void

    @State private var selected: Team?

    var body: some View {
        VStack(spacing: 0) {
            Text("Which team does\nhe support?")
                .font(.onboardingTitle)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 60)

            Text("Pick one and we'll keep you in the loop.")
                .font(.onboardingBody)
                .foregroundColor(.textSecondary)
                .padding(.top, Layout.elementSpacing)

            Spacer().frame(height: Layout.sectionSpacing)

            VStack(spacing: Layout.cardSpacing) {
                ForEach(Team.allCases) { team in
                    TeamPickerCard(
                        team: team,
                        isSelected: selected == team
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = team
                        }
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)

            Spacer()

            if let team = selected {
                Button {
                    onTeamSelected(team)
                } label: {
                    Text("Continue")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentWarm)
                        .cornerRadius(16)
                }
                .padding(.horizontal, Layout.screenPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 40)
        }
        .background(Color.appBackground)
        .animation(.easeInOut(duration: 0.3), value: selected)
    }
}

#Preview {
    TeamSelectionView(onTeamSelected: { _ in })
}
