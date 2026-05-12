import SwiftUI

struct PlayerCardModal: View {
    let player: PlayerCard
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    /// Three rendering modes for the modal:
    /// - `.locked`: user is below T3, show a soft teaser inviting them to upgrade
    /// - `.empty`: T3 user but the routine hasn't generated a dossier yet
    /// - `.full`: T3 user with a real dossier row
    private enum Mode { case locked, empty, full }

    private var mode: Mode {
        if !TierGating.isAvailable(.playerDossier, tier: appState.selectedTier) { return .locked }
        if player.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        return .full
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.cardBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                Text(player.playerName)
                    .font(.detailTitle)
                    .foregroundColor(.textPrimaryOnCard)

                Text(player.position)
                    .font(.feedBadge)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(.hotRose)

                switch mode {
                case .locked:
                    lockedBody
                case .empty:
                    emptyBody
                case .full:
                    fullBody
                }
            }
            .padding(Layout.cardPadding)
            .padding(.top, 24) // space for close button

            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.charcoal)
                    .frame(width: 28, height: 28)
                    .background(Color.softBlush)
                    .clipShape(Circle())
            }
            .padding(16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Modes

    /// T3+ with a real dossier: name, position, summary, optional vibe + form.
    @ViewBuilder
    private var fullBody: some View {
        Text(appState.personalise(player.summary))
            .font(.detailBody)
            .foregroundColor(.textPrimaryOnCard)
            .lineLimit(5)

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

    /// T1/T2: soft teaser. Doesn't promise a specific paywall flow — Settings
    /// is the only tier-switch surface today (paywall was removed when the app
    /// went paid-up-front on the App Store), so just point her there.
    @ViewBuilder
    private var lockedBody: some View {
        Text("Player dossiers are part of the Premium tier.")
            .font(.detailBody)
            .foregroundColor(.textPrimaryOnCard)

        Text("Bump to T3 in Settings to unlock who he is, how he plays, and what to mention.")
            .font(.feedTimestamp)
            .foregroundColor(.textSecondaryOnCard)
            .padding(.top, 2)
    }

    /// T3+ but no row yet (routine hasn't run for this player). Sister-voice
    /// "lands Sunday" copy so she knows it's coming, not broken.
    @ViewBuilder
    private var emptyBody: some View {
        Text("\(player.playerName)'s dossier lands Sunday evening.")
            .font(.detailBody)
            .foregroundColor(.textPrimaryOnCard)

        Text("Fresh details every week so you always know who's who.")
            .font(.feedTimestamp)
            .foregroundColor(.textSecondaryOnCard)
            .padding(.top, 2)
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

// Legacy list view (still used for navigation from feed)
struct PlayerCardsListView: View {
    let teamId: String
    @State private var players: [PlayerCard] = []
    @State private var isLoading = true
    @State private var presentedPlayer: PlayerCard?

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
                            Button {
                                presentedPlayer = player
                            } label: {
                                PlayerCardRow(player: player)
                            }
                            .buttonStyle(.plain)
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
        .sheet(item: $presentedPlayer) { player in
            PlayerCardModal(player: player)
        }
    }

    private func loadPlayers() async {
        do {
            players = try await APIClient.shared.fetchPlayerCards(teamId: teamId)
        } catch {
            #if DEBUG
            print("⚠️ loadPlayers failed: \(error.localizedDescription)")
            #endif
        }
        isLoading = false
    }
}

struct PlayerCardRow: View {
    let player: PlayerCard

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.playerName)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Text(player.position)
                    .font(.feedTimestamp)
                    .foregroundColor(.textSecondaryOnCard)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.textSecondaryOnCard)
        }
        .cardStyle()
    }
}
