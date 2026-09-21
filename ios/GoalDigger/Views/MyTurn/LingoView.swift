import SwiftUI

/// Module 2 — Lingo. What he just said, and what it meant.
///
/// Two screens in one view. The landing screen is this weekend: a hero built
/// from the cached team page ("Before Spurs", "Derby week. 7 words you'll hear
/// before Saturday."), then the whole glossary folded into four categories for
/// the four-second look-up during a match. Pressing the hero deals seven words
/// and hands over to `LingoOverheardView`, which is the round.
///
/// Leaving a round pauses it, it does not end it (`showingLanding`): the
/// look-up is the reason this module exists and must not cost her the seven she
/// is halfway through, and a word arriving from Say This has to land on the
/// word, not on the round card.
///
/// The old shape — a twelve-level ladder and a flip deck — went on 2026-09-22.
/// A flashcard tested recall of a definition, which is not the job: he says a
/// thing, she needs to know what it meant. `level` survives as the sort key.
struct LingoView: View {
    let content: LingoContent
    /// For the "Lines that use this" jump on a reveal.
    let sayThis: SayThisContent
    @Bindable var store: MyTurnStore
    /// The club she follows, for the deal seed and her row in the table.
    let team: Team?
    /// The cached team page, already refreshed by `MyTurnView`'s task. Nil is
    /// fine: the context falls back to "7 words you'll hear at any match."
    let page: TeamPageContent?
    @Environment(AppState.self) private var appState

    /// Which category folds are open. Not persisted: a fold is a glance, and
    /// she comes back to the hero, not to where she left the list.
    @State private var openCategories: Set<LingoCategory> = []
    /// Which of the two screens is drawn when a round exists. Set by "The
    /// words" on an unfinished round and by a word arriving from Say This;
    /// cleared by Continue and by any fresh deal.
    ///
    /// Deliberately view state and not persisted: the round itself survives a
    /// relaunch (it is in `MyTurnStore`), and a relaunch should drop her back
    /// into the word she was on, the way Quiz does.
    @State private var showingLanding = false
    /// This weekend and the seven it would deal right now, rebuilt only when
    /// something it actually depends on moves — never on a keystroke in the
    /// search field, which is a deck build over 158 words per character.
    @State private var weekend: Weekend?
    #if DEBUG
    /// Set by `-gdLingoContext`, so a screenshot can pin a derby weekend.
    @State private var debugContext: MatchContext?
    /// `onAppear` fires again on every return to the tab; the harness must not.
    @State private var appliedArguments = false
    #endif

    /// The hero's two facts: what weekend it is, and which words it would deal.
    private struct Weekend {
        /// With `refresher` already filled in from the deck below.
        var context: MatchContext
        var ids: [String]
    }

    // MARK: What weekend it is

    private var context: MatchContext {
        #if DEBUG
        if let debugContext { return debugContext }
        #endif
        return MatchContext(page: page, team: team, now: Date())
    }

    private var known: Set<String> {
        Set(content.terms.map(\.id).filter { store.bucket(deckId: LingoWeekendDeck.deckId, cardId: $0) == .known })
    }

    private var learning: Set<String> {
        Set(content.terms.map(\.id).filter { store.bucket(deckId: LingoWeekendDeck.deckId, cardId: $0) == .learning })
    }

    /// The seven this context would deal right now.
    private func dealt(_ context: MatchContext?) -> (ids: [String], refresher: Bool) {
        LingoWeekendDeck.build(
            terms: content.terms, known: known, learning: learning, context: context,
            seed: LingoWeekendDeck.seed(team: team, context: context, now: Date(), nonce: store.lingoDealNonce))
    }

    /// Everything the hero depends on, and nothing else. `store.lingoQuery` is
    /// pointedly absent: search filters the word list below and has no say in
    /// which seven get dealt, so typing must not rebuild the deck.
    private struct HeroKey: Hashable {
        let fixture: String?
        let result: String?
        let team: String?
        let nonce: Int
        let known: Int
        let day: String
        let debug: String?
    }

    private var heroKey: HeroKey {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        #if DEBUG
        let debug = debugContext.map { "\($0.title)|\($0.fixtureKey)|\($0.tags.joined(separator: ","))" }
        #else
        let debug: String? = nil
        #endif
        return HeroKey(
            fixture: page?.cards.nextFixture?.date,
            result: page?.cards.recentResults?.first?.date,
            team: team?.rawValue,
            nonce: store.lingoDealNonce,
            known: store.knownCount(deckId: LingoWeekendDeck.deckId),
            day: "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)",
            debug: debug)
    }

    private func buildWeekend() -> Weekend {
        var shown = context
        let deck = dealt(shown)
        shown.refresher = deck.refresher
        return Weekend(context: shown, ids: deck.ids)
    }

    /// Start a round. `ids` is the deck the hero already built and already
    /// described in its subtitle; without it the deal is computed fresh.
    private func deal(_ context: MatchContext?, ids: [String]? = nil) {
        let queue = ids ?? dealt(context).ids
        // Nothing to deal keeps whatever round she has rather than silently
        // doing nothing to it.
        guard !queue.isEmpty else { return }
        store.startDrill(deckId: LingoWeekendDeck.deckId, queue: queue)
        showingLanding = false
    }

    /// "Go again" on the end card.
    private func dealAgain() {
        // Two taps before the redraw would otherwise deal twice, throwing the
        // first fresh seven away between them.
        guard store.drillSession?.finished == true else { return }
        store.lingoDealNonce += 1
        let ids = dealt(context).ids
        // A content refresh can leave nothing playable. An end card with a
        // button that does nothing is worse than going back to the words.
        if ids.isEmpty { store.endDrill() } else { deal(context, ids: ids) }
    }

    // MARK: Body

    private var showingRound: Bool {
        store.drillSession?.deckId == LingoWeekendDeck.deckId && !showingLanding
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                    if showingRound {
                        LingoOverheardView(
                            content: content, sayThis: sayThis, store: store,
                            onDealAgain: dealAgain,
                            onPause: { showingLanding = true })
                    } else {
                        landing
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .animation(.easeInOut(duration: 0.2), value: store.drillSession?.index)
            .animation(.easeInOut(duration: 0.2), value: store.drillSession?.finished)
            // One build per thing the deck actually depends on.
            .task(id: heroKey) { weekend = buildWeekend() }
            .onChange(of: store.lingoExpandedId) { _, new in jump(to: new, proxy: proxy) }
            #if DEBUG
            // One hop after appear: the launch arguments deal a round and answer
            // it, and doing that inside the first body evaluation would mutate
            // state SwiftUI is in the middle of reading.
            .onAppear { Task { applyLingoArguments() } }
            #endif
        }
    }

    /// A word arriving from somewhere else — Say This's Lingo chip, or a
    /// `seeAlso` neighbour in another fold — has to be reachable: the landing
    /// screen rather than a round, out from under a search that hides it, its
    /// category open, and then actually on screen. The hop is because the row
    /// does not exist until the fold has opened.
    private func jump(to id: String?, proxy: ScrollViewProxy) {
        guard let id, let term = content.terms.first(where: { $0.id == id }) else { return }
        showingLanding = true
        if !matches(term) { store.lingoQuery = "" }
        openCategories.insert(term.category)
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
        }
    }

    // MARK: The landing screen

    @ViewBuilder
    private var landing: some View {
        hero
        searchField
        wordList
    }

    /// "Continue · 3 of 7" while a round is paused, in place of the invitation
    /// to deal a new one.
    private var continueLabel: String? {
        guard let s = store.drillSession, s.deckId == LingoWeekendDeck.deckId, !s.finished else { return nil }
        return "Continue · \(min(s.index + 1, s.queue.count)) of \(s.queue.count)"
    }

    /// The one thing to press: this weekend, in a sentence. A deck that cannot
    /// fill a round hides it — an older cached lingo.json has no Overheard
    /// fields at all, and a hero that deals four words is a bug — but a paused
    /// round keeps its way back regardless.
    @ViewBuilder
    private var hero: some View {
        if let weekend {
            let playable = weekend.ids.count >= LingoWeekendDeck.roundLength
            if playable || continueLabel != nil {
                MyTurnPractiseButton(
                    title: weekend.context.title,
                    subtitle: continueLabel ?? appState.personalise(weekend.context.subtitle),
                    subtitleLineLimit: 3
                ) {
                    if continueLabel != nil {
                        showingLanding = false
                    } else {
                        deal(weekend.context, ids: weekend.ids)
                    }
                }

                if playable {
                    Button {
                        deal(nil)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("Or seven from anywhere")
                            .font(.jakarta(15, weight: .semiBold))
                            .foregroundColor(.hotRose)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Seven words from anywhere, whatever this weekend is")
                }
            } else {
                // The search field below is the whole screen now, so say so
                // rather than leaving a gap where the hero was.
                MyTurnEmptyText(text: "Nothing to deal yet. Search for a word you heard.")
            }
        }
    }

    // MARK: Search

    private var query: String { store.lingoQuery.trimmingCharacters(in: .whitespaces).lowercased() }
    private var searching: Bool { !query.isEmpty }

    private func matches(_ term: LingoTerm) -> Bool {
        guard searching else { return true }
        return term.term.lowercased().contains(query)
            || term.meaning.lowercased().contains(query)
            || (term.overheard?.lowercased().contains(query) ?? false)
    }

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
                .accessibilityLabel("Search the words")
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

    // MARK: The words

    /// Everything in a category, easiest first, search applied. Ties keep the
    /// order the content file is written in, which is curated.
    private func terms(in category: LingoCategory) -> [LingoTerm] {
        content.terms.enumerated()
            .filter { $0.element.category == category && matches($0.element) }
            .sorted { (content.level(of: $0.element), $0.offset) < (content.level(of: $1.element), $1.offset) }
            .map(\.element)
    }

    /// Open while she is searching (the match may be anywhere), while she has
    /// opened it, and while the word Say This jumped her to lives in it.
    private func isOpen(_ category: LingoCategory) -> Bool {
        if searching || openCategories.contains(category) { return true }
        guard let id = store.lingoExpandedId else { return false }
        return content.terms.first { $0.id == id }?.category == category
    }

    @ViewBuilder
    private var wordList: some View {
        let knownIds = known
        MyTurnSectionLabel(text: "Words you've got")
            .padding(.top, 8)
        Text("\(knownIds.count) of \(content.terms.count)")
            .font(.jakarta(14, weight: .regular))
            .foregroundColor(.warmWhite.opacity(0.7))
            .padding(.leading, 4)
            .padding(.bottom, 2)
            .accessibilityLabel("You've got \(knownIds.count) of \(content.terms.count) words.")

        let categories = LingoCategory.allCases.filter { !searching || !terms(in: $0).isEmpty }
        if categories.isEmpty {
            MyTurnEmptyText(text: "Nothing for that yet. Try a shorter word.")
        } else {
            ForEach(categories, id: \.self) { category in
                categoryFold(category, known: knownIds)
            }
        }
    }

    @ViewBuilder
    private func categoryFold(_ category: LingoCategory, known: Set<String>) -> some View {
        let all = content.terms.filter { $0.category == category }
        let got = all.filter { known.contains($0.id) }.count
        let open = isOpen(category)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if openCategories.contains(category) {
                    openCategories.remove(category)
                } else {
                    openCategories.insert(category)
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            MyTurnRow(title: category.tag, subtitle: "\(got) of \(all.count) got") {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.hotRose)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        // The tag, not the title: it is what the row says on screen, and a
        // VoiceOver label that names something else is a second control.
        .accessibilityLabel("\(category.tag). \(got) of \(all.count) got.")
        .accessibilityHint(open ? "Hides the words" : "Shows the words")

        if open {
            ForEach(terms(in: category)) { term in
                termRow(term, known: known.contains(term.id))
                    .padding(.leading, 10)
                    .id(term.id)
            }
        }
    }

    private func termRow(_ term: LingoTerm, known: Bool) -> some View {
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
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if known {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.hotRose)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.hotRose)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(known ? "\(term.term). You've got this one." : term.term)
            .accessibilityHint(expanded ? "Hides what it means" : "Shows what it means")

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(term.meaning)
                        .font(.jakarta(15, weight: .regular))
                        .foregroundColor(.textPrimaryOnCard)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    // The line someone would actually say, when there is one.
                    // `heard` is the older, drier "when you'll hear it" note;
                    // showing both says the same thing twice.
                    Text(term.overheard ?? term.heard)
                        .font(.jakarta(14, weight: .italic))
                        .foregroundColor(.textSecondaryOnCard)
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
                    seeAlso(term)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
    }

    @ViewBuilder
    private func seeAlso(_ term: LingoTerm) -> some View {
        let neighbours = (term.seeAlso ?? []).compactMap { id in content.terms.first { $0.id == id } }
        if !neighbours.isEmpty {
            HStack(spacing: 6) {
                ForEach(neighbours) { other in
                    Button {
                        // The neighbour may live in another fold, or under a
                        // search that hides it, or below the fold: `jump`, on
                        // the far side of `lingoExpandedId`, deals with all of
                        // that in one place for this and for Say This's chip.
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.lingoExpandedId = other.id
                        }
                    } label: {
                        Text(other.term)
                            .font(.jakarta(12, weight: .semiBold))
                            .foregroundColor(.textSecondaryOnCard)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().stroke(Color.textSecondaryOnCard.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("See also \(other.term)")
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Screenshot harness

    #if DEBUG
    /// Everything Lingo takes, in one place (`MyTurnView` keeps only
    /// `-gdLingoQuery` and `-gdLingoExpand`, which are plain store writes):
    ///
    ///   `-gdLingoContext derby|cup|after-win|after-loss|postponed|none`
    ///       pins the weekend, so the hero is the same on every run.
    ///   `-gdLingoOpenCategory rules|tactics|match_situations|culture`
    ///       opens one fold, and clears a *finished* round from an earlier
    ///       launch so the list is what shows. A paused round is left alone.
    ///   `-gdLingoPlay`        deals this context's seven and opens the round,
    ///                         unless a round is already in progress.
    ///   `-gdLingoAnswer N`    taps option N on the card she is on.
    ///   `-gdLingoFinish N`    deals, then plays the whole round with the
    ///                         first N right and the rest wrong, for the end
    ///                         card and its hype band.
    ///
    /// simctl cannot tap, so these are the only way to a screenshot of
    /// anything past the landing screen.
    private func applyLingoArguments() {
        // `onAppear` fires on every return to the My Turn tab; dealing a round
        // again each time would throw away the one she is on.
        guard !appliedArguments else { return }
        appliedArguments = true

        // Cheap, and this is the one screen that owns the deck: a wrong
        // `sameClub` mislabels every derby weekend silently.
        lingoDeckSelfCheck(bundled: content)

        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        func intValue(_ flag: String) -> Int? { value(flag).flatMap(Int.init) }

        // Read the context back out of the local, not out of `@State`: the
        // write below has not landed by the time the next line runs.
        var current = context
        if let name = value("-gdLingoContext") {
            let now = Date()
            let pinned = name == "none"
                ? MatchContext(page: nil, team: nil, now: now)
                : MatchContext(page: LingoFixtures.page(name, now: now), team: .arsenal, now: now)
            debugContext = pinned
            current = pinned
        }
        if let raw = value("-gdLingoOpenCategory"), let category = LingoCategory(rawValue: raw) {
            openCategories.insert(category)
            // Asking for a fold means asking for the list, and a round from an
            // earlier launch is drawn on top of it. A finished one is over, so
            // end it; an unfinished one is only paused, which is what a
            // relaunch must keep — and what "Continue · 3 of 7" is a shot of.
            if store.drillSession?.finished == true { store.endDrill() }
            showingLanding = true
        }
        if args.contains("-gdLingoPlay") {
            // Never over a round in progress: the flag means "show me a round",
            // and re-dealing would make a paused one unreachable.
            if continueLabel == nil { deal(current) } else { showingLanding = false }
        }
        if let n = intValue("-gdLingoAnswer") { debugAnswer(n) }
        if let target = intValue("-gdLingoFinish") { debugFinish(right: target, context: current) }
    }

    private func debugOptions(_ id: String) -> (options: [String], answer: Int)? {
        content.terms.first { $0.id == id }.flatMap(LingoWeekendDeck.options(for:))
    }

    private func debugAnswer(_ option: Int) {
        guard let s = store.drillSession, !s.finished, let id = s.queue[safe: s.index],
              let opts = debugOptions(id) else { return }
        store.answerDrill(option, correct: option == opts.answer)
    }

    private func debugFinish(right: Int, context: MatchContext?) {
        deal(context)
        guard let queue = store.drillSession?.queue else { return }
        for (i, id) in queue.enumerated() {
            guard let opts = debugOptions(id) else { continue }
            let correct = i < right
            store.answerDrill(correct ? opts.answer : (opts.answer + 1) % opts.options.count, correct: correct)
            store.nextDrillCard()
        }
    }
    #endif
}
