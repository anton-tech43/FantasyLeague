import SwiftUI

struct MatchDayCard: View {
    let item: ContentItem
    let appState: AppState
    let players: [PlayerCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tag
            Text("MATCH DAY")
                .font(.feedBadge)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundColor(.gold)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color.deepMauve)
                .cornerRadius(Layout.badgeCornerRadius)

            // Headline (teams + what's at stake)
            Text(appState.personalise(item.headline))
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
                .lineLimit(3)

            // Kickoff time
            if let kickoff = item.kickoffTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(kickoff.formatted(date: .omitted, time: .shortened))
                        .font(.feedTimestamp)
                }
                .foregroundColor(.textSecondaryOnCard)
            }

            // Ones to watch (max 3)
            if !players.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ONES TO WATCH")
                        .font(.feedBadge)
                        .tracking(0.5)
                        .foregroundColor(.textSecondaryOnCard)

                    ForEach(Array(players.prefix(3))) { player in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.hotRose.opacity(0.15))
                                .frame(width: 6, height: 6)
                            Text(player.playerName)
                                .font(.feedTimestamp)
                                .foregroundColor(.textPrimaryOnCard)
                                .fontWeight(.medium)
                            Text(player.position)
                                .font(.feedTimestamp)
                                .foregroundColor(.textSecondaryOnCard)
                        }
                    }
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.gold, lineWidth: 2)
        )
        .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
    }
}
