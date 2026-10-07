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
    @Bindable var store: MyTurnStore
    /// The club she follows, for the deal seed and her row in the table.
    let team: Team?
    /// The cached team page, already refreshed by the tab view's task. Nil is
    /// fine: the context falls back to "7 words you'll hear at any match."
    let page: TeamPageContent?
    /// The same view in two places. `.prep` is Pre-game, Matchday › Before:
    /// the opponent quiz, this fixture's seven words and the slip, each a
    /// full-screen card. `.dictionary` is the Lingo segment: the
    /// search and the 158 words, for the four-second look-up mid-match. One
    /// view rather than two so the round, the slip and the deck keep one home.
    var mode: Mode = .prep
    enum Mode { case prep, dictionary }
    @Environment(AppState.self) private var appState
    /// The two device-built caches, for the real players a card can name.
    /// Read-only here: the tab view's task owns refreshing them.
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
    /// The opponent quiz, hosted in the prep over its cards while a round of
    /// it is going and she has not stepped back to them.
    @State private var showingOpponentQuiz = false
    /// She pressed the words card this visit. A round already going waits
    /// behind an unfilled slip, but the one she just asked for opens over it.
    @State private var pressedRound = false
    #if DEBUG
    /// Set by `-gdLingoContext`, so a screenshot can pin a derby weekend.
    @State private var debugContext: MatchContext?
    /// `onAppear` fires again on every return to the tab; the harness must not.
    @State private var appliedArguments = false
    /// `-gdLingoHeroTap` presses the hero once, not on every rebuild of it.
    @State private var pressedHero = false
    /// `-gdLingoFrames`: where the two cards actually ended up.
    @State private var frames: [String: CGRect] = [:]
    #endif

    /// The scroll view's own coordinate space, so a measured frame is a
    /// position in the column rather than on the screen.
    static let frameSpace = "lingo"

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
        return MatchContext(page: page, team: team, now: .gdNow, preferBefore: mode == .prep)
    }

    private var known: Set<String> {
        Set(content.terms.map(\.id).filter { store.bucket(deckId: LingoWeekendDeck.deckId, cardId: $0) == .known })
    }

    private var learning: Set<String> {
        Set(content.terms.map(\.id).filter { store.bucket(deckId: LingoWeekendDeck.deckId, cardId: $0) == .learning })
    }

    /// The seven this context would deal right now.
    private func dealt(_ context: MatchContext?) -> (ids: [String], refresher: Bool) {
        // Only promise the deck a named card when there is a man to name, or a
        // plain "their defender" line takes the slot a fixture word would have.
        let theirs = context.map(inputs(for:))
        let canName = theirs.map { $0.opponentKnown && !($0.theirPicks.isEmpty && $0.theirCurated.isEmpty) } ?? false
        return LingoWeekendDeck.build(
            terms: content.terms, known: known, learning: learning, context: context,
            seed: LingoWeekendDeck.seed(team: team, context: context, now: .gdNow, nonce: store.lingoDealNonce),
            canNameTheirs: canName,
            avoid: context == nil ? Set(store.prepRoundDone?.ids ?? []) : [])
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
        let day = Calendar.current.dateComponents([.year, .month, .day], from: .gdNow)
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
        let theirClub = opponent.flatMap { name in Team.allCases.first { MatchContext.sameClub($0.displayName, name) } }
        let theirs = theirClub.map { live.clubPlayers(teamId: $0.rawValue) } ?? .init()
        return PlayerSlots.Inputs(
            squad: squad.players,
            ourCurated: page?.cards.onesToKnow?.players ?? [],
            theirPicks: theirs.picks,
            // The gated opponent side off his own page first — it was written
            // for this fixture — then the opponent's own curated three.
            theirCurated: PlayerSlots.opponentCurated(page: page, context: context) + theirs.curated,
            opponentKnown: opponent != nil,
            ourTeam: team?.displayName,
            theirTeam: theirClub?.displayName ?? opponent)
    }

    private func buildWeekend() -> Weekend {
        var shown = context
        let deck = dealt(shown)
        shown.refresher = deck.refresher

        // `LingoWeekendDeck.build` stays pure and knows nothing about players.
        // The names go on afterwards, over the seven it dealt, in dealt order.
        let byId = Dictionary(content.terms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var plain = deck.ids.compactMap { byId[$0] }
        var ids = deck.ids
        #if DEBUG
        if PlayerSlots.debugRequested {
            plain = PlayerSlots.debugInjected(plain, from: content.terms)
            ids = plain.map(\.id)
        }
        #endif
        var prep = false
        if case .before = shown.phase { prep = true }
        let resolved = PlayerSlots.apply(plain, inputs: inputs(for: shown),
                                         seed: shown.fixtureKey + "|\(store.lingoDealNonce)",
                                         max: prep ? PlayerSlots.prepPlayerCards : PlayerSlots.maxPlayerCards)
        var named: [String: LingoTerm] = [:]
        for (before, after) in zip(plain, resolved) where before != after { named[after.id] = after }
        #if DEBUG
        // `-gdLingoPrintDeck`: the seven, as dealt, for checking a round
        // without playing it through on a simulator that cannot tap.
        if ProcessInfo.processInfo.arguments.contains("-gdLingoPrintDeck") {
            print("LINGO-DECK \(shown.tags) " + resolved.map { "\($0.id): \($0.overheard ?? "")" }.joined(separator: " | "))
        }
        #endif
        return Weekend(context: shown, ids: ids, named: named)
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
        // A visible, tappable hero that answers a tap with nothing is exactly
        // what the hero bug looked like from the outside, and a silent return
        // is how it stayed invisible. The hero is hidden when the deck cannot
        // fill a round, so reaching here with nothing means those two
        // conditions have come apart.
        guard !queue.isEmpty else {
            assertionFailure("the hero was pressed with nothing to deal, so the tap did nothing")
            return
        }
        store.startDrill(deckId: LingoWeekendDeck.deckId, queue: queue, origin: origin,
                         fixtureKey: mode == .prep ? (context ?? self.context).fixtureKey : nil)
        // And only once the round actually exists: leaving the landing screen
        // behind a refused `startDrill` is a blank screen with no way back.
        guard ownsSession else {
            assertionFailure("startDrill refused a queue of \(queue.count), and the landing screen was about to go with it")
            return
        }
        pressedRound = true
        withAnimation(.easeInOut(duration: 0.2)) { showingLanding = false }
    }

    /// "Go again" on the end card.
    private func dealAgain() {
        // Two taps before the redraw would otherwise deal twice, throwing the
        // first fresh seven away between them.
        guard store.drillSession?.finished == true else { return }
        store.lingoDealNonce += 1
        let context = roundContext
        let ids = dealt(context).ids
        // A content refresh can leave nothing playable. An end card with a
        // button that does nothing is worse than going back to the words.
        if ids.isEmpty {
            withAnimation(.easeInOut(duration: 0.2)) { store.endDrill() }
        } else {
            deal(context, ids: ids)
        }
    }

    // MARK: Body

    /// Which tab's round this view deals and resumes: the prep's is the
    /// fixture's (nil, as every round was before 2026-09-29), Lingo's is the
    /// general one. The two share the store's one round slot.
    private var origin: String? { mode == .dictionary ? "practise" : nil }

    /// The context a round from this tab is dealt for: the fixture in the
    /// prep, none at all in Lingo — seven from anywhere, nobody named.
    private var roundContext: MatchContext? { mode == .prep ? context : nil }

    private var ownsSession: Bool {
        store.drillSession?.deckId == LingoWeekendDeck.deckId && store.drillSession?.origin == origin
    }

    private var showingRound: Bool { ownsSession && !showingLanding }

    /// The round, on screen. Behind an unfilled slip only until she presses
    /// the words card: before this the slip cover won outright, and a tap on
    /// the pink card below it dealt a round nobody could see. In Lingo only
    /// once she presses Practise: the tab opens on the words.
    private var roundOnScreen: Bool {
        showingRound && (pressedRound || (mode == .prep && !showingCalledIt))
    }

    /// The Called It offer fills the Lingo content — the first thing she meets
    /// coming into Lingo on a match week — whenever there is a slip to offer she
    /// has not yet acted on. Once she has picked or passed, it gives way to the
    /// round and the words.
    private var showingCalledIt: Bool {
        store.matchCalls(for: context) == nil
            && !LingoCalls.offer(calls: calls, context: context).isEmpty
    }

    /// The reveal, whenever there is one to draw: a round on screen, on a card
    /// she has answered, whose word and options this build can still resolve.
    ///
    /// Derived rather than stored — every part of it is already true somewhere
    /// else. "The words" clears `showingRound` and the popup goes with it,
    /// leaving the round exactly where it was; `selected` is persisted, so a
    /// relaunch brings the popup back on the card she was answering; and it
    /// cannot get out of step with the card underneath it, because it is read
    /// off the same session.
    private var reveal: (term: LingoTerm, correct: Bool, last: Bool)? {
        // Not over the slip: when the Called it cover takes the content the
        // round is not on screen, so neither is its popup.
        guard roundOnScreen, let session = store.drillSession, !session.finished,
              let selected = session.selected,
              let id = session.queue[safe: session.index],
              let term = weekend?.named[id] ?? content.terms.first(where: { $0.id == id }),
              let options = LingoWeekendDeck.options(for: term, salt: session.salt) else { return nil }
        return (term, selected == options.answer && session.missed == nil,
                session.index + 1 >= session.queue.count)
    }

    var body: some View {
        ZStack {
            if mode == .prep, showingOpponentQuiz, let pack = live.opponentPack,
               store.quizRound?.packId == pack.id {
                QuizView(content: QuizContent(contentVersion: "", packs: []), store: store, clubId: nil,
                         livePack: nil, squadPack: nil, leaguePack: nil, opponentPack: pack,
                         onExit: { withAnimation(.easeInOut(duration: 0.2)) { showingOpponentQuiz = false } })
            } else {
                scroller
            }
            if let reveal {
                LingoRevealPopup(term: reveal.term, correct: reveal.correct, last: reveal.last,
                                 store: store)
                    .transition(.opacity)
            }
        }
    }

    private var scroller: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                    if roundOnScreen {
                        LingoOverheardView(
                            content: content, store: store, context: context,
                            named: weekend?.named ?? [:],
                            onDealAgain: dealAgain,
                            backLabel: mode == .dictionary ? "Lingo" : "Pre-game",
                            onPause: { withAnimation(.easeInOut(duration: 0.2)) { showingLanding = true } })
                    } else if mode == .dictionary {
                        practiseButton
                        searchField
                        wordList
                    } else if showingCalledIt {
                        // Fills the Lingo content, with the module tabs above and
                        // the bottom bar below still in view — Anton's "helskärm
                        // men så att man fortfarande ser menyn". The round and the
                        // words come back once she has been through it.
                        // Get to know them, the words, then the sayings (Anton,
                        // 2026-10-01): she can't pick lines for a game against
                        // a side she has never heard of. Each card is full
                        // screen (its own containerRelativeFrame), so she
                        // scrolls down through the three.
                        opponentCard
                        hero
                        calledItTakeover.id("prep-calls")
                    } else {
                        landing
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            // No `.animation(_:value:)` here. Hanging it on the ScrollView
            // animated every layout change in the whole subtree, including a
            // card arriving with its own transition — and a view mid-transition
            // is hit-tested at its interpolated frame, which is a neighbouring
            // card swallowing taps meant for the hero. Each mutation site
            // animates its own change instead.
            .coordinateSpace(name: LingoView.frameSpace)
            // One build per thing the deck actually depends on.
            .task(id: mode == .prep ? heroKey : nil) { if mode == .prep { weekend = buildWeekend() } }
            // A slip that never reached the device row is a slip nothing can
            // tell her about, so every open of the app has another go.
            .task { if mode == .prep { await uploadSlip() } }
            // The opponent quiz, for whoever this fixture is against.
            .task(id: OpponentKey(team: opponentTeam, meeting: lastMeeting, ready: live.hasSources)) {
                if mode == .prep { await live.refreshOpponent(opponentTeam, mine: team, lastMeeting: lastMeeting) }
            }
            // "Carry on with your words" dealt a practise round and sent her
            // here: put it on screen.
            .onChange(of: store.practiseHandoff, initial: true) { _, handoff in
                guard mode == .dictionary, handoff else { return }
                store.practiseHandoff = false
                pressedRound = true
                showingLanding = false
            }
            // A word sent here from Say This or a seeAlso: the dictionary's job.
            .onChange(of: store.lingoExpandedId) { _, new in if mode == .dictionary { jump(to: new, proxy: proxy) } }
            #if DEBUG
            // One hop after appear: the launch arguments deal a round and answer
            // it, and doing that inside the first body evaluation would mutate
            // state SwiftUI is in the middle of reading.
            .onAppear { Task { mode == .prep ? applyLingoArguments() : applyDictionaryArguments() } }
            // `-gdPrepFocus hero|opponent` scrolls the prep to that card, and
            // `-gdPrepOpponentQuiz` opens the opponent quiz: simctl cannot
            // scroll or tap. Keyed on the pack so it waits for it to build.
            // The audit dump, again whenever a pack or the deck lands, after
            // the screen has had a moment: the last write is the full one.
            .task(id: "\(live.opponentPack?.questions.count ?? -1)|\(live.pack?.questions.count ?? -1)|\(squad.pack?.questions.count ?? -1)|\(live.leaguePack?.questions.count ?? -1)|\(weekend?.ids.joined() ?? "")") {
                try? await Task.sleep(for: .seconds(2))
                auditDump()
            }
            .task(id: live.opponentPack?.id) {
                guard mode == .prep, live.opponentPack != nil else { return }
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-gdPrepFocus"), i + 1 < args.count {
                    try? await Task.sleep(for: .milliseconds(600))
                    proxy.scrollTo("prep-" + args[i + 1], anchor: .top)
                }
                if args.contains("-gdPrepOpponentQuiz"), let pack = live.opponentPack {
                    // With `-gdMyTurnQuestion <id>` a one-question round, and
                    // `-gdQuizAnswer N` answers it, as in the Quiz tab.
                    if let j = args.firstIndex(of: "-gdMyTurnQuestion"), j + 1 < args.count {
                        store.startRetryRound(pack: pack, missedIds: [args[j + 1]])
                    } else {
                        store.startRound(pack: pack, fixtureKey: context.fixtureKey)
                        // `-gdMyTurnFirst <id>`: a full round, that question first.
                        if let j = args.firstIndex(of: "-gdMyTurnFirst"), j + 1 < args.count {
                            store.debugMoveFirst(args[j + 1])
                        }
                    }
                    if let j = args.firstIndex(of: "-gdQuizAnswer"), j + 1 < args.count, let a = Int(args[j + 1]),
                       let id = store.quizRound?.questionIds.first,
                       let q = pack.questions.first(where: { $0.id == id }) {
                        store.answer(a, correct: a == q.answer, questionId: id)
                    }
                    showingOpponentQuiz = true
                }
                // `-gdPrepOpponentDone`: play the opponent quiz through, all
                // but one right, and come back to the prep with it done.
                if args.contains("-gdPrepOpponentDone"), let pack = live.opponentPack {
                    store.startRound(pack: pack, fixtureKey: context.fixtureKey)
                    let byId = Dictionary(pack.questions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                    for (i, id) in (store.quizRound?.questionIds ?? []).enumerated() {
                        guard let q = byId[id] else { continue }
                        let pick = i == 0 ? (q.answer + 1) % q.options.count : q.answer
                        store.answer(pick, correct: pick == q.answer, questionId: id)
                        store.nextQuestion()
                    }
                    store.endRound()
                }
            }
            .onPreferenceChange(LingoFramePreference.self) { measured in
                Task { @MainActor in frames = measured }
            }
            // Keyed on the frames themselves: every move cancels the pending
            // check and starts another, so the assertion only ever runs
            // against a screen that has stopped moving — which is the whole
            // reason the instrumented prints were a lead and not a finding.
            .task(id: frames) { await checkFrames() }
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

    /// Called it leads, the hero sits under it, and the look-up is below both.
    ///
    /// The slip is the thing that puts her in the match, so it is the first
    /// thing she meets; the round is the thing she chooses, so it waits to be
    /// chosen. Search and the 158 words stay where they were — a wall of terms
    /// to someone who does not know football, and the four-second look-up she
    /// will hardly ever need.
    ///
    /// Not a takeover: `showingRound` is reserved for something she pressed.
    /// Gating the tab on the slip would put a door between her and the
    /// glossary, which is the one thing this module promised not to do.
    @ViewBuilder
    private var landing: some View {
        opponentCard
        hero
        callsCard
    }

    private var calls: [LingoCall] { LingoCalls.published(content) }

    /// Called it: up to seven lines she might get to say, under the one thing
    /// to press. Draws nothing at all when this fixture has no slip to offer
    /// and she has none saved.
    private var callsCard: some View {
        // On the landing, once she has acted: the compact "watching for these"
        // card. Draws nothing while an offer is un-acted, because that is the
        // takeover's job above.
        LingoCallsView(calls: calls, store: store, context: context,
                       presentation: .inline) { _ in
            Task { await uploadSlip() }
        }
        // `-gdPrepFocus calls` scrolls here, as it does to the offer.
        .id("prep-calls")
        #if DEBUG
        .lingoFrame("calls")
        #endif
    }

    /// The offer filling the Lingo content: a cover, then one line at a time.
    private var calledItTakeover: some View {
        LingoCallsView(calls: calls, store: store, context: context,
                       presentation: .takeover) { _ in
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

    /// "Continue · 3 of 7" while a round is paused, in place of the invitation
    /// to deal a new one.
    private var continueLabel: String? {
        guard ownsSession, let s = store.drillSession, !s.finished else { return nil }
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
            if continueLabel == nil, store.prepRoundDone?.fixtureKey == weekend.context.fixtureKey {
                carryOnCard
            } else if playable || continueLabel != nil {
                fullScreenHero(weekend)
            } else {
                // The search field below is the whole screen now, so say so
                // rather than leaving a gap where the hero was.
                MyTurnEmptyText(text: "Nothing to deal yet. Search for a word you heard.")
            }
        }
    }

    /// The pink "Before Chelsea" hero, full screen like the blush calls cover —
    /// Anton's second sketch, drawn by the same `SketchCard` so the two differ
    /// only in colour: the opponent white on rose, the arrow dark, the whole
    /// card pressing into the round. Fills the Lingo viewport; the glossary scrolls
    /// below it. No subtitle — the sketch is the line and the arrow, the same
    /// restraint the calls cover keeps.
    private func fullScreenHero(_ weekend: Weekend) -> some View {
        Button {
            pressHero(weekend)
        } label: {
            MatchdayCard(title: heroTitle(weekend).replacingOccurrences(of: "\n", with: " "),
                         text: heroLine, fill: .hotRose, ink: .white, arrow: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .containerRelativeFrame(.vertical) { h, _ in h * 0.82 }
        .id("prep-hero")
        .accessibilityLabel("\(heroTitle(weekend).replacingOccurrences(of: "\n", with: " ")). Start.")
        #if DEBUG
        .lingoFrame("hero")
        // simctl cannot tap, so `-gdLingoHeroTap` presses it — the hero's own
        // closure, with the weekend it has actually built.
        .task(id: weekend.ids) { await debugPressHero(weekend) }
        #endif
    }

    /// Lingo's one thing to press, the same box Quiz and Say This lead with:
    /// seven words from anywhere, for practice. The game's own seven live in
    /// the prep; this is for any other evening.
    private var practiseButton: some View {
        MyTurnPractiseButton(title: "Practise",
                             subtitle: continueLabel ?? "\(LingoWeekendDeck.roundLength) words, any game") {
            if continueLabel != nil {
                pressedRound = true
                withAnimation(.easeInOut(duration: 0.2)) { showingLanding = false }
            } else {
                deal(nil)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private struct OpponentKey: Hashable { let team: Team?; let meeting: MatchContext.LastMeeting?; let ready: Bool }

    /// The last time the two met, off his page's matchup card for this fixture.
    private var lastMeeting: MatchContext.LastMeeting? {
        guard let opponent = PlayerSlots.opponent(of: context) else { return nil }
        return MatchContext.lastMeeting(page?.cards.matchup, opponent: opponent, fixtureId: context.fixtureId)
    }

    /// The game's seven, done: the card goes small, and pressing it carries
    /// on in Lingo with seven she has not just played — the same seven again
    /// under the same card was the round repeating itself (2026-10-01).
    private var carryOnCard: some View {
        MyTurnPractiseButton(title: "Carry on with your words",
                             subtitle: "Done for the game. Seven more in Lingo.",
                             systemImage: "arrow.right") { carryOn() }
        .padding(.vertical, 8)
        .id("prep-hero")
        #if DEBUG
        // `-gdPrepCarryOn` presses it: simctl cannot tap.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-gdPrepCarryOn") else { return }
            try? await Task.sleep(for: .seconds(1))
            carryOn()
        }
        #endif
    }

    private func carryOn() {
        let ids = dealt(nil).ids
        guard !ids.isEmpty else { return }
        store.startDrill(deckId: LingoWeekendDeck.deckId, queue: ids, origin: "practise")
        store.practiseHandoff = true
        withAnimation(.spring(duration: 0.25)) { store.lastModule = .lingo }
        // Pre-game is in Matchday; the rest of the words are in My Turn.
        if mode == .prep { appState.requestedTab = .myTurn }
    }

    /// The club this fixture is against, when it is one we have a page for.
    /// From the context, never `next_fixture` (see `PlayerSlots.opponent`).
    private var opponentTeam: Team? {
        PlayerSlots.opponent(of: context).flatMap { name in
            Team.allCases.first { MatchContext.sameClub($0.displayName, name) }
        }
    }

    /// "Get to know Chelsea": the first full-screen card, blush with the rose
    /// arrow (Anton, 2026-10-01). Opens the opponent quiz in place; a round
    /// already going is picked up rather than dealt again.
    @ViewBuilder
    private var opponentCard: some View {
        if let pack = live.opponentPack, let club = opponentTeam?.shortName,
           let done = store.opponentQuizDone, done.fixtureKey == context.fixtureKey,
           !(store.quizRound?.packId == pack.id && store.quizRound?.finished == false) {
            // Done for this game: small, like the words card once played, in
            // its own blush (Anton, 2026-10-02). Pressing it goes again.
            MyTurnPractiseButton(title: "You know \(club)",
                                 subtitle: "\(done.score) of \(done.total) right. Go again?",
                                 systemImage: "checkmark",
                                 fill: .cardBackground, ink: .textPrimaryOnCard,
                                 badge: .hotRose, badgeInk: .warmWhite) {
                store.startRound(pack: pack, fixtureKey: context.fixtureKey)
                withAnimation(.easeInOut(duration: 0.2)) { showingOpponentQuiz = true }
            }
            .padding(.vertical, 8)
            .id("prep-opponent")
        } else if let pack = live.opponentPack, let club = opponentTeam?.shortName {
            Button {
                if store.quizRound?.packId != pack.id || store.quizRound?.finished == true {
                    store.startRound(pack: pack, fixtureKey: context.fixtureKey)
                }
                withAnimation(.easeInOut(duration: 0.2)) { showingOpponentQuiz = true }
            } label: {
                MatchdayCard(title: "Get to know \(club)",
                             text: "A quick quiz on the side \(team?.shortName ?? "his team") play next, so their names mean something on the day.",
                             fill: .cardBackground, ink: .textPrimaryOnCard, arrow: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .containerRelativeFrame(.vertical) { h, _ in h * 0.82 }
            .id("prep-opponent")
            .accessibilityLabel("Get to know \(club). A quiz about the side you're playing.")
        }
    }

    /// The pink card's line: what it does, the way the blush one says "Prepare
    /// some sayings for the game". A paused round says it carries on.
    private func heroTitle(_ weekend: Weekend) -> String {
        if continueLabel != nil { return "Carry on with\nyour words" }
        if case .before = weekend.context.phase { return "\(LingoWeekendDeck.roundLength) words for\nthe game" }
        let title = weekend.context.title
        return title.replacingOccurrences(of: " ", with: "\n", options: [], range: title.range(of: " "))
    }

    /// The serif line under "7 words for the game" (Matchday card, 2026-10-07).
    private var heroLine: String {
        if let continueLabel { return "\(continueLabel). Pick up where you left off." }
        return "Seven words you'll hear during the game, and what each one means."
    }

    /// What the hero does when she presses it.
    private func pressHero(_ weekend: Weekend) {
        if continueLabel != nil {
            pressedRound = true
        withAnimation(.easeInOut(duration: 0.2)) { showingLanding = false }
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
        // No "23 of 158" under the label, and no "12 of 46 got" on a fold
        // (Anton, 2026-10-07): both read as a course she never signed up for.
        // The buckets are still kept, because they decide which words come
        // round again; they are just not shown as a score.
        MyTurnSectionLabel(text: "All the words")
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
        let count = content.terms.filter { $0.category == category }.count
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
            MyTurnRow(title: category.tag, subtitle: "\(count) words") {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.hotRose)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        // The tag, not the title: it is what the row says on screen, and a
        // VoiceOver label that names something else is a second control.
        .accessibilityLabel("\(category.tag). \(count) words.")
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
    ///   `-gdLingoCallsIndex N`
    ///                         starts the slip on line N (zero-based), for a
    ///                         shot of the second or third card without
    ///                         tapping through the ones before it.
    ///   `-gdLingoCallsPass`   stores the empty slip she gets by saying no to
    ///                         all three, which is the state that stops the
    ///                         same three coming back on every open.
    ///   `-gdLingoPlayerVariant`
    ///                         names a real player on two of the dealt cards,
    ///                         with their published lines: it deals a real
    ///                         term with a `theirs.forward` variant and one
    ///                         with an `ours` variant first, and hands
    ///                         `PlayerSlots` a fixture squad and a fixture
    ///                         opponent (`PlayerSlots.debugInputs`) so the
    ///                         caches do not have to have landed. It exercises
    ///                         the real resolver — the cap, the claim and the
    ///                         gate all still apply — and touches nothing
    ///                         outside DEBUG. Pair it with `-gdLingoContext
    ///                         derby -gdLingoPlay`.
    ///   `-gdLingoHeroTap`     presses the hero once, two seconds after the
    ///                         screen has settled, through its own closure,
    ///                         and asserts a round opened. It proves the hero's
    ///                         path works; it cannot prove the hero is
    ///                         REACHABLE, because it calls the closure rather
    ///                         than delivering a tap. `-gdLingoFrames` is the
    ///                         one that speaks to being covered.
    ///   `-gdLingoFrames`      measures the calls card and the hero on a
    ///                         settled screen and asserts they do not overlap,
    ///                         since a hero covered by its neighbour looks
    ///                         identical in a screenshot to one that works.
    ///   `-gdLingoRevealExpand`
    ///                         opens the reveal popup's `+` on arrival. Pair it
    ///                         with `-gdLingoAnswer`.
    /// simctl cannot tap, so these are the only way to a screenshot of
    /// anything past the landing screen.
    /// The dictionary's share of the launch arguments: only the fold to open.
    /// Everything that deals or answers a round belongs to the prep.
    private func applyDictionaryArguments() {
        guard !appliedArguments else { return }
        appliedArguments = true
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-gdLingoOpenCategory"), i + 1 < args.count,
           let category = LingoCategory(rawValue: args[i + 1]) {
            openCategories.insert(category)
        }
        // `-gdLingoPractise`: press Practise, for a screenshot of the round.
        if args.contains("-gdLingoPractise") { deal(nil) }
    }

    private func applyLingoArguments() {
        // `onAppear` fires on every return to the My Turn tab; dealing a round
        // again each time would throw away the one she is on.
        guard !appliedArguments else { return }
        appliedArguments = true

        // Cheap, and this is the one screen that owns the deck: a wrong
        // `sameClub` mislabels every derby weekend silently.
        lingoDeckSelfCheck(bundled: content)
        if let fixture = LingoFixtures.page("matchup", now: Date()) {
            assert(LiveClubPack.opponentSelfCheck(page: fixture),
                   "the opponent quiz spoke as though she follows the other side, or dealt a wrong-shaped question")
        }
        myTurnSlipSelfCheck()
        myTurnMissSelfCheck()
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
            // The named-player shot deals the order `debugInjected` built,
            // which is the weekend's; a plain deal skips the injection.
            if continueLabel == nil {
                deal(current, ids: PlayerSlots.debugRequested ? buildWeekend().ids : nil)
            } else { showingLanding = false }
        }
        if let n = intValue("-gdLingoAnswer") { debugAnswer(n) }
        if let target = intValue("-gdLingoFinish") { debugFinish(right: target, context: current) }
        if args.contains(LingoCalls.debugPickArgument) { debugPickCalls(current) }
        if args.contains("-gdLingoCallsPass") { debugPassCalls(current) }
    }

    /// `-gdLingoFrames`: the two cards, where they actually ended up, once the
    /// screen has stopped moving.
    ///
    /// The instrumented prints this replaces read the hero at y 232…356 and the
    /// calls card at y 314…729, which is 52 points of overlap — but they were
    /// taken mid-layout from `onAppear`, so they were a lead and not a finding.
    /// This waits for a settled screen, and it stays in the tree, which a print
    /// does not.
    ///
    /// The rule it holds, in the order the landing screen is in now: the calls
    /// card starts at or after the hero ends. Two views that overlap are two
    /// views where the one on top takes the taps, and a hero covered by its
    /// neighbour is indistinguishable in a screenshot from one that works.
    private func checkFrames() async {
        // The round replaces the landing screen, and neither card is on it —
        // including after `-gdLingoHeroTap` has pressed the hero, which is the
        // one run where both flags are on at once.
        guard ProcessInfo.processInfo.arguments.contains("-gdLingoFrames"), !showingRound else { return }
        // Cancelled and restarted by the next measurement, so reaching the far
        // side of this means nothing has moved for two seconds.
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
        guard let hero = frames["hero"] else {
            assertionFailure("-gdLingoFrames measured no hero (it measured \(frames.keys.sorted())): the hero is hidden, or the deck cannot fill a round")
            return
        }
        // No slip for this fixture is a legal screen — then the hero leads and
        // there is nothing to overlap with.
        guard let calls = frames["calls"], calls.height > 0 else { return }
        // The calls card sits below the hero since 2026-10-01.
        assert(calls.minY >= hero.maxY - 0.5,
               "the calls card starts at \(calls.minY) and the hero ends at \(hero.maxY): they overlap, so whichever is on top is taking the other's taps")
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

    /// `-gdLingoCallsPass`: the slip she walked and fancied none of. Stored
    /// empty, which is the state that stops the same three coming back on
    /// every open, and the one a tap cannot reach from here.
    private func debugPassCalls(_ context: MatchContext) {
        store.commitMatchCalls(fixtureId: context.fixtureId ?? 900001,
                               fixtureKey: context.fixtureKey, pickedIds: [])
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
        if option == opts.answer { store.answerDrill(option, correct: true) } else { store.missDrill(option) }
    }

    /// `-gdAuditDump`: everything the prep would show this club, and the
    /// packs Quiz would deal, as JSON in Documents, for the pre-launch audit
    /// to read for all twenty clubs rather than photograph. `-gdAuditLabel`
    /// names the file.
    private func auditDump() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-gdAuditDump"), mode == .prep, let weekend else { return }
        func q(_ x: MyTurnQuestion) -> [String: Any] {
            ["id": x.id, "question": x.question, "options": x.options, "answer": x.options[safe: x.answer] ?? "?",
             "explanation": x.explanation, "why": x.why ?? "", "use": x.use ?? "", "image": x.image ?? "", "answerImage": x.answerImage ?? ""]
        }
        func pack(_ p: QuizPack?) -> Any { p.map { ["id": $0.id, "label": $0.label, "questions": $0.questions.map(q)] } ?? NSNull() }
        func term(_ id: String) -> [String: Any] {
            let t = weekend.named[id] ?? content.terms.first { $0.id == id }
            return ["id": id, "term": t?.term ?? "?", "overheard": t?.overheard ?? "", "sayIt": t?.sayIt ?? "",
                    "gist": t?.gist ?? "", "decoy": t?.decoy ?? "", "when": t?.when ?? [],
                    "named": t?.namedPlayer.map { ["name": $0.name, "role": $0.role] } ?? NSNull()]
        }
        let c = weekend.context
        var phase: [String: Any] = ["kind": "any"]
        switch c.phase {
        case .before(let o, let k): phase = ["kind": "before", "opponent": o, "kickoff": ISO8601DateFormatter().string(from: k)]
        case .after(let o, let out, let ts, let os):
            phase = ["kind": "after", "opponent": o, "outcome": out ?? "", "teamScore": ts ?? -1, "oppScore": os ?? -1]
        case .any: break
        }
        let slip = LingoCalls.offer(calls: calls, context: context).map {
            ["id": $0.id, "band": $0.band ?? "", "line": $0.line, "kind": $0.trigger?.kind ?? "",
             "situation": $0.situation ?? LingoCalls.moment($0.trigger)] as [String: Any]
        }
        let dump: [String: Any] = [
            "team": team?.rawValue ?? "", "now": ISO8601DateFormatter().string(from: .gdNow),
            "context": ["phase": phase, "title": c.title, "tags": c.tags, "fixtureId": c.fixtureId ?? -1,
                        "fixtureKey": c.fixtureKey, "sixPointer": c.sixPointer],
            "opponentTeam": opponentTeam?.rawValue ?? NSNull(),
            "lastMeeting": lastMeeting.map { ["date": $0.date, "weAreHome": $0.weAreHome, "ours": $0.ours, "theirs": $0.theirs] } ?? NSNull(),
            "opponentPack": pack(live.opponentPack),
            "clubPack": pack(live.pack), "leaguePack": pack(live.leaguePack), "squadPack": pack(squad.pack),
            "words": weekend.ids.map(term),
            "slip": slip,
            "practise": dealt(nil).ids.map(term),
        ]
        let label = args.firstIndex(of: "-gdAuditLabel").flatMap { args[safe: $0 + 1] } ?? "now"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("myturn-audit-\(team?.rawValue ?? "none")-\(label).json")
        if let data = try? JSONSerialization.data(withJSONObject: dump, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
            print("AUDIT-DUMP \(url.path)")
        }
    }

    private func debugFinish(right: Int, context: MatchContext?) {
        deal(context)
        guard let session = store.drillSession else { return }
        for (i, id) in session.queue.enumerated() {
            guard let opts = debugOptions(id, salt: session.salt) else { continue }
            if i >= right { store.missDrill((opts.answer + 1) % opts.options.count) }
            store.answerDrill(opts.answer, correct: true)
            store.nextDrillCard()
        }
    }
    #endif
}

#if DEBUG
/// Where the landing screen's two cards ended up, keyed by name. Only ever
/// filled while `-gdLingoFrames` is on.
struct LingoFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Report this view's frame under `name`, and nothing at all unless
    /// `-gdLingoFrames` is on: a GeometryReader behind every card is a layout
    /// pass nobody asked for.
    func lingoFrame(_ name: String) -> some View {
        guard ProcessInfo.processInfo.arguments.contains("-gdLingoFrames") else {
            return AnyView(self)
        }
        return AnyView(background(GeometryReader { geo in
            Color.clear.preference(key: LingoFramePreference.self,
                                   value: [name: geo.frame(in: .named(LingoView.frameSpace))])
        }))
    }
}
#endif
