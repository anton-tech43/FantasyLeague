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

    /// No dossier yet (the routine hasn't written one for him). The Premium
    /// teaser that used to sit beside this never rendered (council TEAM-06-13).
    private var isEmpty: Bool { player.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// "Number 8 · 27" under the position, when the facts are there.
    private var facts: String? {
        let bits = [number.map { "Number \($0)" }, player.age.map { "\($0) years old" }].compactMap { $0 }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.cardBackground.ignoresSafeArea()

            // Scrolls: photo, facts, hook and a long summary outgrow a medium
            // sheet on an SE or with larger text (bug hunt 2026-10-27).
            ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let asset = PlayerPortrait.assetName(photoURL) {
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76, alignment: .top)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                } else if let photoURL, let url = URL(string: photoURL) {
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

                if isEmpty { emptyBody } else { fullBody }
            }
            .padding(Layout.cardPadding)
            .padding(.top, 24) // space for close button
            .frame(maxWidth: .infinity, alignment: .leading)
            }

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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Modes

    /// A real dossier: the summary. The vibe and form tags under it went
    /// (council TEAM-06-09/10): the form one repeated the summary.
    @ViewBuilder
    private var fullBody: some View {
        Text(appState.personalise(player.summary))
            .font(.detailBody)
            .foregroundColor(.textPrimaryOnCard)
            .lineLimit(5)
    }

    /// No row yet (routine hasn't run for this player). Sister-voice
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
}
