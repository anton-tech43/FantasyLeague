import SwiftUI

/// Lingo practise: ten cards, tap to flip, knew it or didn't.
///
/// Shown in place of the word list (not as a sheet) so the module keeps its
/// own state: leaving the tab and coming back lands back on the card she was
/// on, because the session lives in `MyTurnStore`.
///
/// The deck is one level at a time. She graduates by knowing eight of a
/// level's words, but nothing is locked — the chips at the top let her drop
/// back or jump ahead whenever she likes.
struct LingoFlashcardsView: View {
    let content: LingoContent
    @Bindable var store: MyTurnStore
    /// The end-screen hype line, picked once when the session finishes. View
    /// state, not session state: the end screen does not outlive the tab.
    @State private var hype: String?

    /// How many she knew this session, from the session itself.
    private var knew: Int { store.drillSession?.knew ?? 0 }

    private var session: MyTurnStore.DrillSession? {
        guard let s = store.drillSession, s.deckId == LingoDrill.deckId else { return nil }
        return s
    }

    private var byId: [String: LingoTerm] {
        Dictionary(uniqueKeysWithValues: content.terms.map { ($0.id, $0) })
    }

    private var card: LingoTerm? {
        guard let s = session, s.index < s.queue.count else { return nil }
        return byId[s.queue[s.index]]
    }

    /// The level this session is drilling — the level of its first card.
    private var sessionLevel: Int {
        guard let first = session?.queue.first, let term = byId[first] else {
            return content.currentLevel(store: store)
        }
        return content.level(of: term)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if let s = session, s.finished || card == nil {
                    finished(s)
                } else if let term = card, let s = session {
                    levelPicker
                    cardStack(term, session: s)
                        .id(s.index)
                    grading(flipped: s.flipped)
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                store.endDrill()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("The words")
                        .font(.jakarta(15, weight: .medium))
                }
                .foregroundColor(.warmWhite.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to the words")

            Spacer(minLength: 0)

            if let s = session, !s.finished {
                Text("\(min(s.done + 1, LingoDrill.cardsPerSession)) of \(LingoDrill.cardsPerSession)")
                    .font(.jakarta(15, weight: .semiBold))
                    .foregroundColor(.warmWhite.opacity(0.8))
                    .accessibilityLabel("Card \(min(s.done + 1, LingoDrill.cardsPerSession)) of \(LingoDrill.cardsPerSession)")
            }
        }
    }

    /// Not locked: any level, any time. The current one is filled in.
    private var levelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(content.levelNumbers, id: \.self) { level in
                    let selected = level == sessionLevel
                    Button {
                        LingoDrill.start(store, ids: content.terms(atLevel: level).map(\.id))
                    } label: {
                        Text("\(level)")
                            .font(.jakarta(13, weight: selected ? .bold : .regular))
                            .foregroundColor(selected ? .warmWhite : .warmWhite.opacity(0.6))
                            .frame(width: 34, height: 30)
                            .background(selected ? Color.hotRose : Color.warmWhite.opacity(0.08))
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Level \(level)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: The card

    private func cardStack(_ term: LingoTerm, session s: MyTurnStore.DrillSession) -> some View {
        ZStack {
            face { front(term) }
                .opacity(s.flipped ? 0 : 1)
                .animation(.linear(duration: 0.01).delay(s.flipped ? 0.17 : 0), value: s.flipped)
            face { back(term) }
                .opacity(s.flipped ? 1 : 0)
                .animation(.linear(duration: 0.01).delay(s.flipped ? 0.17 : 0), value: s.flipped)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(s.flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .animation(.easeInOut(duration: 0.35), value: s.flipped)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !s.flipped else { return }
            store.flip()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(s.flipped ? "" : "Tap to flip")
    }

    private func face<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
    }

    private func front(_ term: LingoTerm) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            categoryTag(term)
            Spacer(minLength: 0)
            Text(term.term)
                .font(.jakarta(32, weight: .bold))
                .foregroundColor(.textPrimaryOnCard)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("Tap to flip")
                .font(.jakarta(13, weight: .regular))
                .foregroundColor(.textSecondaryOnCard)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func back(_ term: LingoTerm) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(term.term)
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.textPrimaryOnCard)
            Text(term.meaning)
                .font(.jakarta(16, weight: .regular))
                .foregroundColor(.textPrimaryOnCard)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let sayIt = term.sayIt {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 12))
                        .foregroundColor(.hotRose)
                        .padding(.top, 2)
                    Text(sayIt)
                        .font(.jakarta(14, weight: .semiBold))
                        .foregroundColor(.textPrimaryOnCard)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.hotRose.opacity(0.08))
                .cornerRadius(10)
            }
            Spacer(minLength: 0)
        }
    }

    private func categoryTag(_ term: LingoTerm) -> some View {
        Text(LingoDrill.tag(term.category))
            .font(.feedBadge)
            .foregroundColor(.hotRose)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.hotRose.opacity(0.12))
            .cornerRadius(6)
    }

    // MARK: Grading

    private func grading(flipped: Bool) -> some View {
        HStack(spacing: 12) {
            gradeButton("Didn't know it", filled: false) { LingoDrill.grade(store, knewIt: false) }
            gradeButton("Knew it", filled: true) { LingoDrill.grade(store, knewIt: true) }
        }
        .opacity(flipped ? 1 : 0)
        .allowsHitTesting(flipped)
        .animation(.easeInOut(duration: 0.2).delay(flipped ? 0.25 : 0), value: flipped)
    }

    private func gradeButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
                .font(.jakarta(15, weight: .semiBold))
                .foregroundColor(filled ? .warmWhite : .warmWhite.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(filled ? Color.hotRose : Color.warmWhite.opacity(0.10))
                .cornerRadius(Layout.buttonCornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: End of session

    private func finished(_ s: MyTurnStore.DrillSession) -> some View {
        VStack(spacing: 14) {
            Text("That's ten.")
                .font(.jakarta(26, weight: .bold))
                .foregroundColor(.warmWhite)
                .padding(.top, 30)
            // Same bands as a quiz round, graded on what she knew.
            HypeCard(scoreLine: "You knew \(knew) of \(LingoDrill.cardsPerSession).", hype: hype)
                .task(id: s.finished) {
                    guard hype == nil else { return }
                    hype = Hype.line(HypeCategory.band(score: knew, of: LingoDrill.cardsPerSession), store: store)
                }
            Text("The ones you didn't come round again next time.")
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Button {
                LingoDrill.start(store, ids: content.terms(atLevel: content.currentLevel(store: store)).map(\.id))
            } label: {
                Text("Go again")
                    .font(.jakarta(16, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
            }
            .buttonStyle(.plain)

            Button {
                store.endDrill()
            } label: {
                Text("Back to the words")
                    .font(.jakarta(15, weight: .medium))
                    .foregroundColor(.warmWhite.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - The deck

/// Everything both Lingo views need to agree on: the deck id, the tally of
/// what she knew, and the level she is on.
enum LingoDrill {
    static let deckId = "lingo"
    static let cardsPerSession = 10
    /// Know eight of a level's words and the next level becomes the one she
    /// is offered. Eight of ten to fourteen, so it is reachable in a sitting
    /// or two without being a grind.
    static let knownToGraduate = 8

    @MainActor static func start(_ store: MyTurnStore, ids: [String]) {
        guard !ids.isEmpty else { return }
        store.startDrill(deckId: deckId, cardIds: ids)
    }

    @MainActor static func grade(_ store: MyTurnStore, knewIt: Bool) {
        store.grade(knewIt: knewIt)
    }

    /// Short label for a row or a card corner. `LingoCategory.title` is the
    /// section heading ("Match situations"); a tag needs one word.
    static func tag(_ category: LingoCategory) -> String {
        switch category {
        case .rules:           return "Rules"
        case .tactics:         return "Tactics"
        case .matchSituations: return "Match"
        case .culture:         return "Slang"
        }
    }
}

extension LingoContent {
    /// A file written before levels existed decodes with `level == nil`;
    /// treat those as the last level so they sort after everything placed.
    var topLevel: Int { terms.compactMap(\.level).max() ?? 1 }

    func level(of term: LingoTerm) -> Int { term.level ?? topLevel }

    var levelNumbers: [Int] { Array(Set(terms.map { level(of: $0) })).sorted() }

    func terms(atLevel level: Int) -> [LingoTerm] { terms.filter { self.level(of: $0) == level } }

    @MainActor func knownCount(atLevel level: Int, store: MyTurnStore) -> Int {
        terms(atLevel: level).filter { store.bucket(deckId: LingoDrill.deckId, cardId: $0.id) == .known }.count
    }

    /// The lowest level she has not yet learned eight words of. The one the
    /// Practise button offers, and where a new session starts.
    @MainActor func currentLevel(store: MyTurnStore) -> Int {
        levelNumbers.first { knownCount(atLevel: $0, store: store) < LingoDrill.knownToGraduate }
            ?? levelNumbers.last ?? 1
    }
}
