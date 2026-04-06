import SwiftUI

struct OnesToWatchView: View {
    let players: [PlayerCard]
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "Ones to Watch", icon: "eye")

            ForEach(players.prefix(3)) { player in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.playerName)
                            .font(.feedHeadline)
                            .foregroundColor(.textPrimaryOnCard)

                        Text(player.position)
                            .font(.feedBadge)
                            .textCase(.uppercase)
                            .foregroundColor(.hotRose)
                    }

                    Spacer()

                    Text(appState.personalise(player.summary))
                        .font(.feedTimestamp)
                        .foregroundColor(.textSecondaryOnCard)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: 180)
                }
                .cardStyle()
            }
        }
    }
}
