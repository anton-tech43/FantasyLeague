import SwiftUI

/// The bit of the app that talks back.
///
/// Finishing a round used to be "3 out of 3." and a button. This is the same
/// score with a friend's voice attached to it: a rose card, black text, one
/// line, and nothing to tap. It is not a points system — the lines are in
/// `Resources/MyTurn/hype.json` and the validator refuses anything that reads
/// like one (see `validate_hype`).
///
/// Two places use it. A round ending renders `HypeCard` inline at the top of
/// the result screen, where it stays until she leaves. Three, six or nine
/// correct in a row shows the same card as an overlay over whatever module she
/// is in, which slides in from the right and takes itself away after 2.2 s.

// MARK: - Content

/// `{contentVersion, categories: {perfect: [...], ...}}`. Unknown categories
/// are kept and ignored, so a publish can add one before the app knows it.
struct HypeContent: Codable {
    let contentVersion: String
    let categories: [String: [String]]

    func lines(_ category: HypeCategory) -> [String] { categories[category.rawValue] ?? [] }
}

enum HypeCategory: String {
    case perfect, strong, mid, rough, streak

    /// Perfect means every question of the round she actually played, so a
    /// three-question retry round can be perfect too. The rest is the ten-
    /// question scale, which is also how Lingo's ten cards are graded.
    static func band(score: Int, of total: Int) -> HypeCategory {
        if total > 0, score == total { return .perfect }
        switch score {
        case 7...: return .strong
        case 4...6: return .mid
        default: return .rough
        }
    }
}

/// The one place that knows both the store (which remembers what she has been
/// shown) and the content service (which holds the lines).
enum Hype {
    @MainActor
    static func line(_ category: HypeCategory, store: MyTurnStore) -> String? {
        // Past three in a row, a line that says "three" is a lie.
        let streak = store.quizRound?.streak ?? 0
        let pastThree = category == .streak && streak > 3
        return store.hypeLine(category, from: MyTurnContentService.shared.hype.lines(category),
                              excluding: { pastThree && $0.lowercased().contains("three") })
    }
}

// MARK: - The card

/// Full-width rose card: the score on the first line when there is one, the
/// hype on the second. Black text on rose, because it has to read as a person
/// talking and not as the rest of the dark UI.
struct HypeCard: View {
    /// "8 out of 10." — omitted for a streak and for Say This.
    var scoreLine: String? = nil
    let hype: String?
    /// Fired once, when the card appears.
    var haptic: HypeHaptic = .packFinished

    /// Say This resolves its line a frame after the card mounts, so the card
    /// has to be nothing at all until there is something to say.
    private var isEmpty: Bool { scoreLine == nil && hype == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let scoreLine {
                Text(scoreLine)
                    .font(.jakarta(20, weight: .bold))
                    .foregroundColor(.charcoal)
            }
            if let hype {
                Text(hype)
                    .font(.jakarta(20, weight: .bold))
                    .foregroundColor(.charcoal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(isEmpty ? 0 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isEmpty ? Color.clear : Color.hotRose)
        .cornerRadius(Layout.cardCornerRadius)
        .accessibilityElement(children: .combine)
        .onAppear { if !isEmpty { haptic.fire() } }
    }
}

enum HypeHaptic {
    case packFinished, streak

    @MainActor
    func fire() {
        switch self {
        case .packFinished: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .streak: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }
}

// MARK: - The streak overlay

/// Sits above the module content in `MyTurnView`'s ZStack. Watches
/// `store.streakTick`, which the store bumps at three, six and nine correct in
/// a row, and shows one line for 2.2 s. Tapping it takes it away early.
struct HypeStreakOverlay: View {
    @Bindable var store: MyTurnStore
    @State private var line: String?

    private static let dwell: Duration = .seconds(2.2)

    var body: some View {
        VStack {
            if let line {
                HypeCard(hype: line, haptic: .streak)
                    .padding(.horizontal, Layout.screenPadding)
                    .onTapGesture { dismiss() }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .allowsHitTesting(line != nil)
        // `task(id:)` and not `onChange`, so a tick set by the screenshot
        // harness before this view appears is not missed.
        .task(id: store.streakTick) {
            guard store.streakTick > 0, let next = Hype.line(.streak, store: store) else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) { line = next }
            try? await Task.sleep(for: Self.dwell)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) { line = nil }
    }
}
