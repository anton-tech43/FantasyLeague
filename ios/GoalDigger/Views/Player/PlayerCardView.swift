import SwiftUI

struct PlayerCardModal: View {
    let player: PlayerCard
    /// Quiz context. She has just answered a question about him, so the sheet
    /// carries his shirt number and face, and is not gated: a locked sheet
    /// there would be a dead end in the middle of a round.
    var number: Int? = nil
    var photoURL: String? = nil
    /// "5 goals · 2 assists · 4 starts" from the quiz's `QuizPlayer`, and the
    /// one line worth remembering him for. Both nil outside the quiz.
    var stats: String? = nil
    var hook: String? = nil
    var gated: Bool = true
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    /// Three rendering modes for the modal:
    /// - `.locked`: user is below T3, show a soft teaser inviting them to upgrade
    /// - `.empty`: T3 user but the routine hasn't generated a dossier yet
    /// - `.full`: T3 user with a real dossier row
    private enum Mode { case locked, empty, full }

    private var mode: Mode {
        if gated, !TierGating.isAvailable(.playerDossier, tier: appState.selectedTier) { return .locked }
        if player.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        return .full
    }

    /// "Number 8 · 27" under the position, when the facts are there.
    private var facts: String? {
        let bits = [number.map { "Number \($0)" }, player.age.map { "\($0) years old" }].compactMap { $0 }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.cardBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                if let photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.textSecondaryOnCard)
                        }
                    }
                    .frame(width: 76, height: 76)
                    .background(Color.softBlush)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                }

                Text(player.playerName)
                    .font(.detailTitle)
                    .foregroundColor(.textPrimaryOnCard)

                Text(player.position)
                    .font(.feedBadge)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(.hotRose)

                if let facts {
                    Text(facts)
                        .font(.feedTimestamp)
                        .foregroundColor(.textSecondaryOnCard)
                }

                if let stats {
                    Text(stats)
                        .font(.feedTimestamp)
                        .foregroundColor(.textSecondaryOnCard)
                }

                if let hook {
                    Text(hook)
                        .font(.detailBody)
                        .foregroundColor(.textPrimaryOnCard)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

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

        Text("Bump to T3 in Settings to unlock who \(appState.pSubject) \(appState.usesHeVoice ? "is" : "are"), how \(appState.pSubject) \(appState.usesHeVoice ? "plays" : "play"), and what to mention.")
            .font(.feedTimestamp)
            .foregroundColor(.textSecondaryOnCard)
            .padding(.top, 2)
    }

    /// T3+ but no row yet (routine hasn't run for this player). Sister-voice
    /// "lands Sunday" copy so she knows it's coming, not broken.
    @ViewBuilder
    private var emptyBody: some View {
        // From the quiz there is no Sunday routine to promise: only fifteen or
        // so players a club have a dossier, by design. Say so plainly rather
        // than implying something is missing.
        Text(gated ? "\(player.playerName)'s dossier lands Sunday evening."
                   : "No dossier on him yet.")
            .font(.detailBody)
            .foregroundColor(.textPrimaryOnCard)

        Text(gated ? "Fresh details every week so you always know who's who."
                   : "The facts above are all we can vouch for.")
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
