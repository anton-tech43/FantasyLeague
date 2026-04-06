import SwiftUI

struct PlayerCardView: View {
    let player: PlayerCard
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(player.playerName)
                    .font(.detailTitle)
                    .foregroundColor(.textPrimaryOnCard)
                Spacer()
                if let age = player.age {
                    Text("Age \(age)")
                        .font(.feedTimestamp)
                        .foregroundColor(.textSecondaryOnCard)
                }
            }

            Text(player.position)
                .font(.feedBadge)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundColor(.hotRose)

            Text(appState.personalise(player.summary))
                .font(.detailBody)
                .foregroundColor(.textPrimaryOnCard)

            if let vibe = player.vibe {
                HStack(spacing: 6) {
                    Image(systemName: vibeIcon(vibe))
                        .font(.system(size: 12))
                    Text(vibe.capitalized)
                        .font(.feedTimestamp)
                }
                .foregroundColor(.textSecondaryOnCard)
            }

            if let form = player.form {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                    Text(appState.personalise(form))
                        .font(.feedTimestamp)
                }
                .foregroundColor(.textSecondaryOnCard)
            }
        }
        .cardStyle()
    }

    private func vibeIcon(_ vibe: String) -> String {
        switch vibe.lowercased() {
        case "fan favourite": return "heart.fill"
        case "controversial": return "exclamationmark.triangle"
        case "reliable": return "checkmark.shield"
        case "flashy": return "sparkles"
        default: return "person"
        }
    }
}

struct PlayerCardsListView: View {
    let teamId: String
    @State private var players: [PlayerCard] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if players.isEmpty && !isLoading {
                Text("No player cards available yet.")
                    .font(.onboardingBody)
                    .foregroundColor(.textTertiary)
            } else {
                ScrollView {
                    LazyVStack(spacing: Layout.cardSpacing) {
                        ForEach(players) { player in
                            PlayerCardView(player: player)
                        }
                    }
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await loadPlayers() }
    }

    private func loadPlayers() async {
        do {
            players = try await APIClient.shared.fetchPlayerCards(teamId: teamId)
        } catch {}
        isLoading = false
    }
}
