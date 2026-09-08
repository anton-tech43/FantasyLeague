import SwiftUI

/// Module 2 — Lingo. Plain explanations of football words.
///
/// Anton's read of the first build (2026-09-09): 157 words on one screen is
/// demoralising when you do not know football. So the words come in levels —
/// ten to start with, the rest folded away — and the first thing on the
/// screen is not a list at all, it is the button that practises ten of them.
///
/// Order: Practise, search, then Level 1 open and every higher level a
/// closed row. Nothing is locked; a level opens with one tap. Search ignores
/// the folding entirely and shows every match, grouped by level.
struct LingoView: View {
    let content: LingoContent
    @Bindable var store: MyTurnStore

    /// Levels she has opened by hand. Level 1 is open from the start; the
    /// rest stay closed until she asks. Not persisted: opening a level costs
    /// one tap, and reopening the tab on the first ten is the calmer landing.
    @State private var openLevels: Set<Int> = [1]

    private var query: String { store.lingoQuery.trimmingCharacters(in: .whitespaces).lowercased() }
    private var searching: Bool { !query.isEmpty }

    private var matches: [LingoTerm] {
        guard searching else { return content.terms }
        return content.terms.filter {
            $0.term.lowercased().contains(query) || $0.meaning.lowercased().contains(query)
        }
    }

    private var byId: [String: LingoTerm] {
        Dictionary(uniqueKeysWithValues: content.terms.map { ($0.id, $0) })
    }

    var body: some View {
        Group {
            if let session = store.drillSession, session.deckId == LingoDrill.deckId {
                // In place, not a sheet: the module keeps its own state and a
                // half-finished session is still here when she comes back.
                LingoFlashcardsView(content: content, store: store)
            } else {
                browse
            }
        }
        #if DEBUG
        .onAppear {
            // One hop, so this lands after MyTurnView's own launch-argument
            // pass (which may have just called store.clearAll()).
            Task { @MainActor in applyLingoArguments() }
        }
        #endif
    }

    private var browse: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                    MyTurnPractiseButton(title: "Practise", subtitle: practiseSubtitle) {
                        let level = content.currentLevel(store: store)
                        if store.drillSession?.deckId != LingoDrill.deckId {
                            LingoDrill.start(store, ids: content.terms(atLevel: level).map(\.id))
                        }
                    }

                    searchField
                        .padding(.bottom, 4)

                    if matches.isEmpty {
                        MyTurnEmptyText(text: "Nothing for that yet. Try a shorter word.")
                    } else {
                        ForEach(content.levelNumbers, id: \.self) { level in
                            levelSection(level, proxy: proxy)
                        }
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 40)
            }
        }
    }

    private var practiseSubtitle: String {
        if let s = store.drillSession, s.deckId == LingoDrill.deckId, !s.finished {
            return "Continue"
        }
        let level = content.currentLevel(store: store)
        return level == 1 ? "10 flashcards from the first ten words" : "10 flashcards from level \(level)"
    }

    // MARK: Levels

    /// A level is showing if she opened it, if she is searching (search sees
    /// everything), or if a seeAlso jump landed on a word inside it.
    private func isOpen(_ level: Int) -> Bool {
        if searching { return true }
        if openLevels.contains(level) { return true }
        if let id = store.lingoExpandedId, let term = byId[id] { return content.level(of: term) == level }
        return false
    }

    @ViewBuilder
    private func levelSection(_ level: Int, proxy: ScrollViewProxy) -> some View {
        let terms = matches.filter { content.level(of: $0) == level }
        if !terms.isEmpty {
            if searching {
                MyTurnSectionLabel(text: level == 1 ? "Level 1 · The first ten" : "Level \(level)")
                    .padding(.top, 6)
            } else {
                levelHeader(level)
            }
            if isOpen(level) {
                ForEach(terms) { term in
                    termRow(term, proxy: proxy)
                        .id(term.id)
                }
            }
        }
    }

    private func levelHeader(_ level: Int) -> some View {
        let terms = content.terms(atLevel: level)
        let known = content.knownCount(atLevel: level, store: store)
        let open = isOpen(level)
        let counted = level == 1 ? "\(terms.count) words" : "\(terms.count) more words"
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if openLevels.contains(level) { openLevels.remove(level) } else { openLevels.insert(level) }
                if !openLevels.contains(level), let id = store.lingoExpandedId, byId[id].map({ content.level(of: $0) }) == level {
                    store.lingoExpandedId = nil
                }
            }
        } label: {
            MyTurnRow(title: level == 1 ? "Level 1 · The first ten" : "Level \(level)",
                      subtitle: "\(counted) · \(known) known") {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.hotRose)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityLabel("Level \(level), \(counted), \(known) known")
        .accessibilityHint(open ? "Tap to fold away" : "Tap to open")
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.warmWhite.opacity(0.6))
            TextField("", text: $store.lingoQuery, prompt: Text("Search a word you heard").foregroundColor(.warmWhite.opacity(0.45)))
                .font(.jakarta(16, weight: .regular))
                .foregroundColor(.warmWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !store.lingoQuery.isEmpty {
                Button {
                    store.lingoQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.warmWhite.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.warmWhite.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hotRose.opacity(0.35), lineWidth: 1))
        .cornerRadius(12)
    }

    // MARK: A word

    private func termRow(_ term: LingoTerm, proxy: ScrollViewProxy) -> some View {
        let expanded = store.lingoExpandedId == term.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.lingoExpandedId = expanded ? nil : term.id
                }
            } label: {
                HStack(spacing: 10) {
                    Text(term.term)
                        .font(.jakarta(16, weight: .semiBold))
                        .foregroundColor(.textPrimaryOnCard)
                    Spacer(minLength: 0)
                    Text(LingoDrill.tag(term.category))
                        .font(.feedBadge)
                        .foregroundColor(.textSecondaryOnCard)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.hotRose)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(term.meaning)
                        .font(.jakarta(15, weight: .regular))
                        .foregroundColor(.textPrimaryOnCard)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "ear")
                            .font(.system(size: 12))
                            .foregroundColor(.hotRose)
                            .padding(.top, 2)
                        Text(term.heard)
                            .font(.jakarta(13, weight: .italic))
                            .foregroundColor(.textSecondaryOnCard)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let sayIt = term.sayIt {
                        // The definition becomes a tool: one line she can say.
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
                    if let refs = term.seeAlso?.compactMap({ byId[$0] }), !refs.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Not to be confused with")
                                .font(.jakarta(12, weight: .regular))
                                .foregroundColor(.textSecondaryOnCard)
                            ForEach(refs) { ref in
                                Button {
                                    // Clear a search that hides the target, and
                                    // open the level it sits in, so the jump
                                    // always lands somewhere visible.
                                    if !matches.contains(where: { $0.id == ref.id }) { store.lingoQuery = "" }
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        openLevels.insert(content.level(of: ref))
                                        store.lingoExpandedId = ref.id
                                        proxy.scrollTo(ref.id, anchor: .top)
                                    }
                                } label: {
                                    Text(ref.term)
                                        .font(.jakarta(12, weight: .semiBold))
                                        .foregroundColor(.hotRose)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
    }

    #if DEBUG
    /// Screenshot harness, alongside MyTurnView's `-gdLingoQuery` /
    /// `-gdLingoExpand`. `-gdLingoOpenLevel 3` opens that level and folds the
    /// rest away,
    /// `-gdLingoLevel 2 -gdLingoPractise` deals ten cards from a level,
    /// `-gdLingoFlip` turns the current card over (on its own it resumes the
    /// stored session and flips that card), `-gdLingoFinish` plays a whole
    /// session out (seven knew, three not) to reach the end screen.
    private func applyLingoArguments() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> Int? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return Int(args[i + 1])
        }
        if let l = value("-gdLingoOpenLevel") { openLevels = [l] }
        if args.contains("-gdLingoPractise") || args.contains("-gdLingoFinish") {
            let level = value("-gdLingoLevel") ?? content.currentLevel(store: store)
            LingoDrill.start(store, ids: content.terms(atLevel: level).map(\.id))
        }
        if args.contains("-gdLingoFinish") {
            for i in 0..<LingoDrill.cardsPerSession {
                store.flip()
                LingoDrill.grade(store, knewIt: i < 7)
            }
        } else if args.contains("-gdLingoFlip") {
            // On its own (no -gdResetMyTurn, no -gdLingoPractise) this turns
            // over the card of the session already in progress.
            store.flip()
        }
    }
    #endif
}
