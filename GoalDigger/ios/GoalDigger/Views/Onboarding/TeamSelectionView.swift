import SwiftUI

// TODO: Implement in I6
struct TeamSelectionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Text("Pick your team")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)

            ForEach(Team.allCases) { team in
                TeamPickerCard(
                    team: team,
                    isSelected: appState.selectedTeam == team,
                    action: { appState.selectedTeam = team }
                )
            }
        }
        .padding(Theme.screenPadding)
        .background(Theme.appBackground)
    }
}
