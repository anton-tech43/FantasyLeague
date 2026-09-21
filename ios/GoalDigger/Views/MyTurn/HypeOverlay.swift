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
/// the result screen, where it stays until she leaves. Four or eight correct
/// in a row shows the same card as an overlay over whatever module she is in,
/// which slides in from the right and takes itself away after 2.2 s.

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
    /// three-question retry round can be perfect too. The rest is a fraction
    /// out of ten, not an absolute: a Lingo round is seven, and six of seven
    /// read as "mid" while the bands were counted in whole questions
    /// (2026-09-22). A ten-question round is byte-identical either way.
    static func band(score: Int, of total: Int) -> HypeCategory {
        if total > 0, score == total { return .perfect }
        switch score * 10 / max(total, 1) {
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
        // Past four in a row, a line that says "four" is a lie. `streakTick` is
        // the run that just triggered, and it is the only source: the streak
        // now comes from the quiz or from a Lingo round, and reading
        // `quizRound` would say "four" over an eight in Lingo (2026-09-22).
        let pastFour = category == .streak && store.streakTick > 4
        return store.hypeLine(category, from: MyTurnContentService.shared.hype.lines(category),
                              excluding: { pastFour && $0.lowercased().contains("four") })
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
/// `store.streakTick`, which the quiz and the Lingo round both set to the run
/// that just triggered (4, then 8), and shows one line for 2.2 s. Tapping it
/// takes it away early. The tick is cleared once shown: it used to survive a
/// tab switch, so opening My Turn an hour after a run replayed the card
/// (2026-09-16).
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
            guard store.streakTick > 0 else { return }
            // No line to show is still the tick handled. Leaving it set means
            // the next run of the same length never changes `streakTick`, so
            // `task(id:)` never fires again and the card is gone for good.
            guard let next = Hype.line(.streak, store: store) else {
                store.streakTick = 0
                return
            }
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) { line = next }
            try? await Task.sleep(for: Self.dwell)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) { line = nil }
        store.streakTick = 0
    }
}
