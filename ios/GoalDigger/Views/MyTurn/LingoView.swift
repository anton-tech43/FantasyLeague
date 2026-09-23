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
    /// The two device-built caches, for the real players a card can name.
    /// Read-only here: `MyTurnView`'s task owns refreshing them.
    @State private var squad = LiveSquadService.shared
    @State private var live = LiveClubPackService.shared

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
    /// Whether this launch has already counted the settle row as shown.
    @State private var notedLine = false
    #if DEBUG
    /// Set by `-gdLingoContext`, so a screenshot can pin a derby weekend.
    @State private var debugContext: MatchContext?
    /// `onAppear` fires again on every return to the tab; the harness must not.
    @State private var appliedArguments = false
    /// `-gdLingoHeroTap` presses the hero once, not on every rebuild of it.
    @State private var pressedHero = false
    #endif

    /// The hero's two facts: what weekend it is, and which words it would deal.
    private struct Weekend {
        /// With `refresher` already filled in from the deck below.
        var context: MatchContext
        var ids: [String]
        /// The dealt words that came back naming a real player, keyed by term
        /// id. At most two (`PlayerSlots.maxPlayerCards`), and empty whenever
        /// nothing resolved — which is every round until the content carries a
        /// variant, and every round on a cold start after that.
        var named: [String: LingoTerm] = [:]
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
        /// The player caches. A squad or a league fetch landing after the first
        /// build is what turns a plain round into a named one, and without
        /// these the round would stay plain until something else moved.
        let squad: Int
        let ourCurated: Int
        let theirs: Int
        let opponentKnown: Bool
    }

    private var heroKey: HeroKey {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        #if DEBUG
        let debug = debugContext.map { "\($0.title)|\($0.fixtureKey)|\($0.tags.joined(separator: ","))" }
        #else
        let debug: String? = nil
        #endif
        let players = inputs(for: context)
        return HeroKey(
            fixture: page?.cards.nextFixture?.date,
            result: page?.cards.recentResults?.first?.date,
            team: team?.rawValue,
            nonce: store.lingoDealNonce,
            known: store.knownCount(deckId: LingoWeekendDeck.deckId),
            day: "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)",
            debug: debug,
            squad: players.squad.count,
            ourCurated: players.ourCurated.count,
            theirs: players.theirPicks.count + players.theirCurated.count,
            opponentKnown: players.opponentKnown)
    }

    /// Everything `PlayerSlots` needs, gathered from the two device caches.
    ///
    /// The opponent comes from the context, never from `next_fixture`: the two
    /// disagree exactly when a fixture is postponed, and that disagreement is
    /// how a Chelsea player's name ends up on a card before a Fulham match.
    private func inputs(for context: MatchContext) -> PlayerSlots.Inputs {
        #if DEBUG
        if PlayerSlots.debugRequested { return PlayerSlots.debugInputs }
        #endif
        let opponent = PlayerSlots.opponent(of: context)
        let theirs = opponent
            .flatMap { name in Team.allCases.first { MatchContext.sameClub($0.displayName, name) } }
            .map { live.clubPlayers(teamId: $0.rawValue) } ?? .init()
        return PlayerSlots.Inputs(
            squad: squad.players,
            ourCurated: page?.cards.onesToKnow?.players ?? [],
            theirPicks: theirs.picks,
            // The gated opponent side off his own page first — it was written
            // for this fixture — then the opponent's own curated three.
            theirCurated: PlayerSlots.opponentCurated(page: page, context: context) + theirs.curated,
            opponentKnown: opponent != nil)
    }

    private func buildWeekend() -> Weekend {
        var shown = context
        let deck = dealt(shown)
        shown.refresher = deck.refresher

        // `LingoWeekendDeck.build` stays pure and knows nothing about players.
        // The names go on afterwards, over the seven it dealt, in dealt order.
        let byId = Dictionary(content.terms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var plain = deck.ids.compactMap { byId[$0] }
        #if DEBUG
        if PlayerSlots.debugRequested { plain = PlayerSlots.debugInjected(plain) }
        #endif
        let resolved = PlayerSlots.apply(plain, inputs: inputs(for: shown),
                                         seed: shown.fixtureKey + "|\(store.lingoDealNonce)")
        var named: [String: LingoTerm] = [:]
        for (before, after) in zip(plain, resolved) where before != after { named[after.id] = after }
        return Weekend(context: shown, ids: deck.ids, named: named)
    }

    /// The whole word list with this round's named cards swapped in. The
    /// glossary below deliberately does not use it: a name in a definition is
    /// noise when she is looking up what a word means mid-match.
    private var roundTerms: [LingoTerm] {
        guard let named = weekend?.named, !named.isEmpty else { return content.terms }
        return content.terms.map { named[$0.id] ?? $0 }
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
                            content: content, sayThis: sayThis, store: store, context: context,
                            named: weekend?.named ?? [:],
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
            // A slip that never reached the device row is a slip nothing can
            // tell her about, so every open of the app has another go.
            .task { await uploadSlip() }
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
        settleRow
        hero
        callsCard
        searchField
        wordList
    }

    /// The published slip lines, or the harness's three while `lingo.json` has
    /// no `calls` key to publish.
    private var calls: [LingoCall] {
        #if DEBUG
        if LingoCalls.debugRequested { return LingoCalls.debugCalls }
        #endif
        return content.calls ?? []
    }

    /// Called it: three lines she might get to say, under the one thing to
    /// press. Draws nothing at all when this fixture has no slip to offer and
    /// she has none saved, which is every fixture until `lingo.json` carries
    /// `calls`.
    private var callsCard: some View {
        LingoCallsView(calls: calls, store: store, context: context) { _ in
            // Her pick is already in the store. The upload is best effort, and
            // retried on the next open of the tab if it does not land.
            Task { await uploadSlip() }
        }
    }

    /// The slip on the device row, where the goal push can find it.
    ///
    /// Never blocks and never throws: a failed upload leaves the local pick
    /// exactly where it is and the `.task` below tries again next time. Without
    /// a push token there is nothing to attach it to and nothing to deliver it,
    /// so it is not an error either.
    private func uploadSlip() async {
        #if DEBUG
        // A slip the screenshot harness planted is not a pick, and the fixture
        // id under it may not be one either.
        if LingoCalls.debugRequested || LingoCalls.debugPickRequested { return }
        #endif
        guard let slip = store.matchCalls, slip.uploadedAt == nil, slip.fixtureId > 0,
              let token = UserDefaults.standard.string(forKey: "apnsToken"), !token.isEmpty,
              APIClient.shared.isConfigured else { return }
        let byId = Dictionary(calls.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let picks = slip.pickedIds.compactMap { byId[$0] }
        guard !picks.isEmpty else { return }
        do {
            try await APIClient.shared.saveMatchCalls(token: token, fixtureId: slip.fixtureId, picks: picks)
            store.noteMatchCallsUploaded()
        } catch {
            // Deliberately quiet. She has her slip; the next open tries again.
        }
    }

    /// The other half of the commitment loop: the game has been played, so ask
    /// once whether she said the line.
    ///
    /// Two buttons and no third, no history, no score, and no nagging — the
    /// store retires the row after three sightings or seven days whether or
    /// not she ever answers. "Not yet" is a word going back in the deck, not a
    /// miss: the copy has to read as neutral because it is.
    @ViewBuilder
    private var settleRow: some View {
        if let line = store.pendingLine(currentFixture: context.fixtureKey) {
            VStack(alignment: .leading, spacing: 10) {
                Text(line.line)
                    .font(.jakarta(16, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Did you say it?")
                    .font(.jakarta(15, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { store.settleLine(used: true) }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("I did")
                            .font(.jakarta(16, weight: .semiBold))
                            .foregroundColor(.warmWhite)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.hotRose)
                            .cornerRadius(Layout.buttonCornerRadius)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("I did say it")

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { store.settleLine(used: false) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("Not yet")
                            .font(.jakarta(16, weight: .semiBold))
                            .foregroundColor(.hotRose)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius)
                                .stroke(Color.hotRose, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Not yet. The word goes back in the deck.")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.warmWhite.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.35), lineWidth: 1))
            .cornerRadius(Layout.cardCornerRadius)
            .transition(.opacity)
            // Counted once per launch, and only while Lingo is the module on
            // screen: all three module views stay mounted, so an `onAppear`
            // here would spend her three sightings on three launches she
            // opened the quiz in and never mention the line at all. `task(id:)`
            // rather than `onAppear` so switching to Lingo later still counts.
            .task(id: store.lastModule) {
                guard !notedLine, store.lastModule == .lingo else { return }
                notedLine = true
                store.noteLineShown()
            }
        }
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
                    pressHero(weekend)
                }
                #if DEBUG
                // simctl cannot tap, so `-gdLingoHeroTap` presses it — the
                // hero's own closure, with the weekend it has actually built.
                .task(id: weekend.ids) { await debugPressHero(weekend) }
                #endif
            } else {
                // The search field below is the whole screen now, so say so
                // rather than leaving a gap where the hero was.
                MyTurnEmptyText(text: "Nothing to deal yet. Search for a word you heard.")
            }
        }
    }

    /// What the hero does when she presses it.
    private func pressHero(_ weekend: Weekend) {
        if continueLabel != nil {
            showingLanding = false
        } else {
            deal(weekend.context, ids: weekend.ids)
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
        // No "23 of 158" under the label. It read as a completion meter on a
        // syllabus she never signed up for, and it moves by at most seven a
        // week, so it was imperceptible as well as wrong. The per-category
        // counts stay: "12 of 46 got" is useful while she is in that fold.
        MyTurnSectionLabel(text: "Words you've got")
            .padding(.top, 8)
            .padding(.bottom, 2)

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
    ///   `-gdLingoContext derby|cup|after-win|after-loss|postponed|matchup|none`
    ///       pins the weekend, so the hero is the same on every run.
    ///       `matchup` is the fixture carrying a `cards.matchup` card that
    ///       passes the gate (the calendar row's `fixture_id` is the card's,
    ///       and the club on it is the club the context settles on), so the
    ///       round is dealt with the `opp-*`, `h2h-*` and `underdog` tags
    ///       live. `postponed` carries a card for the game that was called
    ///       off, which must tag nothing.
    ///   `-gdLingoOpenCategory rules|tactics|match_situations|culture`
    ///       opens one fold, and clears a *finished* round from an earlier
    ///       launch so the list is what shows. A paused round is left alone.
    ///   `-gdLingoPlay`        deals this context's seven and opens the round,
    ///                         unless a round is already in progress.
    ///   `-gdLingoAnswer N`    taps option N on the card she is on.
    ///   `-gdLingoFinish N`    deals, then plays the whole round with the
    ///                         first N right and the rest wrong, for the end
    ///                         card, its hype band and the line it offers.
    ///   `-gdLingoCommit`      taps "I'll use it" on that offer, for the
    ///                         saved state. Needs a Before context and at
    ///                         least one right answer, so pair it with
    ///                         `-gdLingoFinish`.
    ///   `-gdLingoPending`     plants a committed line for last week's
    ///                         fixture, so the landing shows the settle row
    ///                         without waiting a week for a real one.
    ///   `-gdLingoCalls`      pins three fixture lines on the Called it slip,
    ///                         for a shot that does not move when the 59
    ///                         published calls do; the bands, the tags, the
    ///                         banker rule and the fixture gate all still
    ///                         apply to these. Pair it with
    ///                         `-gdLingoContext matchup`, which is a Before
    ///                         context the calendar has an id for.
    ///   `-gdLingoCallsPick`   fills that slip in, for the two states a tap
    ///                         gets to: waiting for the match before it, and
    ///                         the reveal after it (pair it with
    ///                         `-gdLingoContext after-win`). Never uploaded.
    ///   `-gdLingoPlayerVariant`
    ///                         names a real player on two of the dealt cards.
    ///                         No published term carries `playerVariants` yet,
    ///                         so there is nothing on the device to
    ///                         photograph: this hangs a `theirs.forward`
    ///                         variant on the first dealt word and an
    ///                         `ours.midfielder` one on the second, and hands
    ///                         `PlayerSlots` a fixture squad and a fixture
    ///                         opponent (`PlayerSlots.debugInputs`) so the
    ///                         caches do not have to have landed. It exercises
    ///                         the real resolver — the cap, the claim and the
    ///                         gate all still apply — and touches nothing
    ///                         outside DEBUG. Pair it with `-gdLingoContext
    ///                         derby -gdLingoPlay`.
    ///   `-gdLingoHeroTap`     presses the hero once, two seconds after the
    ///                         screen has settled, through its own closure,
    ///                         and asserts a round opened. It is the only way
    ///                         to prove the hero is reachable, since a hero
    ///                         that is covered by a neighbouring card looks
    ///                         identical in a screenshot to one that works.
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
        myTurnSaidLineSelfCheck()
        // The Swift half of the Called it trigger pair, against the same
        // vectors the Deno resolver's test reads, and the moment rules against
        // whichever calls are actually loaded.
        LingoCalls.selfCheck(published: calls)

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
        if args.contains("-gdLingoCommit"), let session = store.drillSession,
           let offer = LingoWeekendDeck.offer(terms: roundTerms, knewIds: session.knewIds,
                                              context: current, now: Date(),
                                              personalise: appState.personalise) {
            store.commitLine(offer)
        }
        if args.contains("-gdLingoPending") { debugPending(current) }
        if args.contains(LingoCalls.debugPickArgument) { debugPickCalls(current) }
    }

    /// `-gdLingoHeroTap`: press the hero, once, with the weekend on screen.
    private func debugPressHero(_ weekend: Weekend) async {
        guard !pressedHero, ProcessInfo.processInfo.arguments.contains("-gdLingoHeroTap") else { return }
        pressedHero = true
        // The rest of the harness runs off `onAppear`; a press that lands
        // before it is not the press she makes, which is on a settled screen.
        try? await Task.sleep(for: .seconds(2))
        pressHero(weekend)
        // The whole point of the flag: a hero that is on screen and pressed
        // must have opened a round. If it has not, the press went nowhere and
        // that is the bug, not a screenshot that happens to look wrong.
        assert(showingRound, "the hero was pressed and no round opened")
    }

    /// A filled-in slip, for a shot of the two states a tap gets to and simctl
    /// cannot: waiting for the match, and the reveal afterwards.
    ///
    /// It plants the LONGEST line in each band rather than the offer, because
    /// the thing worth photographing here is the worst case for the layout —
    /// the content cap is 50 characters and several lines sit exactly on it.
    /// Where the context can already mark a line (an After context, where
    /// `outcomes(after:)` has the full-time result), it takes the longest of
    /// those instead, so the reveal has a badge to show.
    private func debugPickCalls(_ context: MatchContext) {
        let outcomes = LingoCalls.outcomes(after: context)
        var chosen: [LingoCall] = []
        for band in LingoCalls.Band.allCases {
            // The clash rule applies to a planted slip too, or the screenshot
            // shows exactly the thing the rule exists to stop.
            let pool = calls.filter { call in
                LingoCalls.usable(call) && call.band == band.rawValue
                    && !chosen.contains { LingoCalls.clash(call, $0) }
            }
            let markable = pool.filter { call in
                outcomes.contains { LingoCalls.resolve(trigger: call.trigger, outcome: $0) }
            }
            if let longest = (markable.isEmpty ? pool : markable)
                .max(by: { ($0.line.count, $0.id) < ($1.line.count, $1.id) }) {
                chosen.append(longest)
            }
        }
        let ids = chosen.map(\.id)
        guard !ids.isEmpty else { return }
        // 900001 is a fixture id no calendar row carries, which is the point: a
        // harness slip must never be mistaken for one the push could resolve.
        store.commitMatchCalls(fixtureId: context.fixtureId ?? 900001,
                               fixtureKey: context.fixtureKey, pickedIds: ids)
        if store.drillSession?.finished == true { store.endDrill() }
        showingLanding = true
    }

    /// A line committed at last week's fixture, which is what the settle row
    /// is: the same context with a fixture key that is no longer the current
    /// one. The word is whichever this weekend's deck would deal first, so the
    /// row shows a real sayIt line and "I did" retires a real word.
    private func debugPending(_ context: MatchContext) {
        guard let id = dealt(context).ids.first,
              let line = LingoWeekendDeck.offer(terms: roundTerms, knewIds: [id], context: context,
                                                now: Date(), personalise: appState.personalise)
        else { return }
        store.commitLine(MyTurnStore.SaidLine(
            fixtureKey: line.fixtureKey + "|last-week", termId: line.termId, line: line.line,
            occasion: line.occasion, committedAt: Date().addingTimeInterval(-3 * 24 * 3600)))
        if store.drillSession?.finished == true { store.endDrill() }
        showingLanding = true
    }

    /// The salt matters here too: the harness answers by index, and options
    /// computed without the session's salt would call a right tap wrong.
    private func debugOptions(_ id: String, salt: String) -> (options: [String], answer: Int)? {
        content.terms.first { $0.id == id }.flatMap { LingoWeekendDeck.options(for: $0, salt: salt) }
    }

    private func debugAnswer(_ option: Int) {
        guard let s = store.drillSession, !s.finished, let id = s.queue[safe: s.index],
              let opts = debugOptions(id, salt: s.salt) else { return }
        store.answerDrill(option, correct: option == opts.answer)
    }

    private func debugFinish(right: Int, context: MatchContext?) {
        deal(context)
        guard let session = store.drillSession else { return }
        for (i, id) in session.queue.enumerated() {
            guard let opts = debugOptions(id, salt: session.salt) else { continue }
            let correct = i < right
            store.answerDrill(correct ? opts.answer : (opts.answer + 1) % opts.options.count, correct: correct)
            store.nextDrillCard()
        }
    }
    #endif
}
