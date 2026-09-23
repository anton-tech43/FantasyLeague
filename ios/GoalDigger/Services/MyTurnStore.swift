import Foundation
import Observation

/// Everything My Turn remembers, in one object, persisted as one JSON blob in
/// UserDefaults. Per the spec: every module keeps its own state while the app
/// runs, switching modules preserves it, leaving the tab and coming back
/// restores the last module, a cold start opens the last-used module, and a
/// quiz round in progress is paused, never thrown away.
///
/// Kept deliberately flat. Three drill buckets, best score per pack, a set of
/// starred line ids. No streaks, no daily goals, no reminders — the user did
/// not choose this hobby, and obligation mechanics get the app deleted.
@MainActor
@Observable
final class MyTurnStore {
    static let shared = MyTurnStore()

    // MARK: Persisted state

    struct PackProgress: Codable, Equatable {
        var best: Int = 0
        var played: Int = 0
        var seenQuestionIds: [String] = []
    }

    struct QuizRound: Codable, Equatable {
        let packId: String
        let questionIds: [String]
        var index: Int = 0
        var score: Int = 0
        var missedIds: [String] = []
        /// The option she picked on the current question, if any. Non-nil
        /// means the explanation is showing and "Next" is the only way on.
        var selected: Int? = nil
        var finished: Bool = false
        /// Correct answers in a row, reset by any miss. Drives the hype card
        /// at three, six and nine; not a score, not persisted as one.
        ///
        /// This is a run inside one round, not the streak the header rule
        /// forbids: it starts at nought every round, any miss clears it,
        /// nothing adds it up across rounds and there is nowhere it is shown
        /// as a total. It is written into the paused round only so a round she
        /// comes back to does not hand her a hype card she already earned.
        var streak: Int = 0
        /// The hype line for this round's result screen, picked once when the
        /// round finished so the card does not reshuffle on every redraw.
        var hypeLine: String? = nil

        init(packId: String, questionIds: [String]) {
            self.packId = packId
            self.questionIds = questionIds
        }

        /// Tolerant, for the same reason `DrillSession` is: a round she paused
        /// under the previous build has to survive the fields added since
        /// (`streak`, `hypeLine`, 2026-09-10) rather than throw and take every
        /// quiz score in the blob down with it.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            packId = try c.decode(String.self, forKey: .packId)
            questionIds = try c.decode([String].self, forKey: .questionIds)
            index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
            score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
            missedIds = try c.decodeIfPresent([String].self, forKey: .missedIds) ?? []
            selected = try c.decodeIfPresent(Int.self, forKey: .selected)
            finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
            streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
            hypeLine = try c.decodeIfPresent(String.self, forKey: .hypeLine)
        }
    }

    enum Bucket: String, Codable { case new, learning, known }

    /// A round of Overheard: seven snippets, two options on each.
    ///
    /// The queue is dealt once and never re-ordered — re-showing a word she
    /// just got wrong, with the same two options in the same order, tests
    /// where her thumb was, not what the word means.
    struct DrillSession: Codable, Equatable {
        let deckId: String
        let queue: [String]
        var index: Int = 0
        /// The option she picked on the current card, if any. Non-nil means
        /// the reveal is showing and "Next" is the only way on.
        var selected: Int? = nil
        var finished: Bool = false
        /// Right answers this session, for the end screen.
        var knew: Int = 0
        /// Which words she got right this round. Nothing reads it since the
        /// end card stopped offering her a line to use (2026-09-23); it is the
        /// one record of which seven she got and which of them landed, which is
        /// cheap to keep writing and impossible to recover afterwards. Delete
        /// it if nothing has wanted it by the next content pass.
        var knewIds: [String] = []
        /// Right in a row, reset by any miss. Drives the hype card at four and
        /// eight; not a score, not persisted as one.
        ///
        /// A run inside one round, not the streak the header rule forbids: it
        /// starts at nought every round, any miss clears it, nothing adds it up
        /// across rounds and no screen shows it as a total. It rides along in
        /// the paused round only so resuming does not replay a hype card.
        var streak: Int = 0
        /// The hype line for this round's end screen, picked once when the
        /// round finished so the card does not reshuffle on every redraw.
        var hypeLine: String? = nil
        /// True when this came out of a flashcard session written by the build
        /// before Overheard: its queue can be nineteen long and can repeat a
        /// word, which is not a round of seven. Not persisted — `MyTurnStore`
        /// drops such a session on the launch that decodes it.
        var legacy: Bool = false
        /// Per-deal shuffle salt for `LingoWeekendDeck.options(for:salt:)`.
        /// Without it the option order is seeded from the term id alone, so a
        /// word she got wrong comes back next weekend as the same card with the
        /// right answer in the same slot — thumb position, not meaning. Stable
        /// for the life of the session, which is what a paused round needs.
        let salt: String
        /// How many options the build that dealt this round put on a card.
        /// Stamped because `selected` is a raw index into
        /// `LingoWeekendDeck.options(for:salt:)`, and a two-element shuffle is
        /// not a prefix of a three-element one: under a build that changed the
        /// count, *every* stored `selected` points at a different string, not
        /// just the index that no longer exists. Always the current count once
        /// decoded — the round carries on at this build's arity, and a stamp
        /// left behind would migrate the same session again on every launch.
        let optionCount: Int

        enum CodingKeys: String, CodingKey {
            case deckId, queue, index, selected, finished, knew, knewIds, streak, hypeLine, salt
            case optionCount
        }

        /// Fields the flashcard build wrote and this one does not.
        private enum LegacyKeys: String, CodingKey { case flipped, done }

        init(deckId: String, queue: [String]) {
            self.deckId = deckId
            self.queue = queue
            self.salt = UUID().uuidString
            self.optionCount = LingoWeekendDeck.optionCount
        }

        /// Tolerant: this struct sits inside the one JSON blob that holds every
        /// starred line and quiz score, so a field added later (`knew`
        /// 2026-09-09, `selected`/`streak`/`hypeLine` 2026-09-22, `salt` and
        /// `knewIds` 2026-09-23) must decode as its default rather than throw and reset
        /// her state. An empty `salt` is the right default for a session dealt
        /// before it existed: it reproduces the order she was looking at. A session
        /// paused mid-flashcard carries `flipped` and `done`; they are what
        /// marks it `legacy`, and the store then drops it.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            deckId = try c.decode(String.self, forKey: .deckId)
            queue = try c.decode([String].self, forKey: .queue)
            index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
            selected = try c.decodeIfPresent(Int.self, forKey: .selected)
            finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
            knew = try c.decodeIfPresent(Int.self, forKey: .knew) ?? 0
            knewIds = try c.decodeIfPresent([String].self, forKey: .knewIds) ?? []
            streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
            hypeLine = try c.decodeIfPresent(String.self, forKey: .hypeLine)
            salt = try c.decodeIfPresent(String.self, forKey: .salt) ?? ""
            let old = try decoder.container(keyedBy: LegacyKeys.self)
            legacy = old.contains(.flipped) || old.contains(.done)

            // The arity migration. Three was the count before 2026-09-23, and
            // a session written then has no key.
            let dealtWith = try c.decodeIfPresent(Int.self, forKey: .optionCount) ?? 3
            optionCount = LingoWeekendDeck.optionCount
            // An unanswered card is simply re-dealt at the new count, which is
            // right. An answered one cannot be: `selected` points somewhere
            // else now, and `answerDrill` already banked `knew`, `knewIds` and
            // the bucket move, so re-asking it would count the same word twice.
            // She resumes on the next word with the score she actually had.
            if dealtWith != optionCount, !finished, selected != nil {
                selected = nil
                if index + 1 >= queue.count { finished = true } else { index += 1 }
            }
        }
    }

    /// The slip she filled in before kick-off: which of the three offered lines
    /// she took, and the fixture they are about.
    ///
    /// Only the ids are kept. The lines themselves live in the content bundle
    /// (a call whose id has since been unpublished simply drops off the reveal)
    /// and the copy that has to survive without the bundle is the one uploaded
    /// to the device row, which carries its own text because the server has no
    /// lingo.json.
    ///
    /// Nothing counts these. There is no score, no streak and no history: one
    /// slip at a time, and the next fixture replaces it.
    struct MatchCalls: Codable, Equatable {
        /// API-Football fixture id, the same one the RPC and the push resolve
        /// against. Zero is "written by a build that had none", which no slip
        /// is offered or resolved for.
        var fixtureId: Int = 0
        /// `MatchContext.fixtureKey` as it was when she picked. The id cannot
        /// do this job on its own: an After context has no fixture id at all
        /// (`recent_results` carries none), and this key is the same opponent
        /// and the same day either side of kick-off, so it is what ties the
        /// slip to the game that has just been played.
        var fixtureKey: String = ""
        var pickedIds: [String] = []
        var pickedAt: Date = .distantPast
        /// When the slip reached the device row. Nil is "not yet", and the next
        /// open of the tab tries again: the upload is what lets the push tell
        /// her, and a slip that only ever reached UserDefaults is a feature
        /// that silently does nothing on a flaky train.
        var uploadedAt: Date? = nil

        init(fixtureId: Int, fixtureKey: String, pickedIds: [String], pickedAt: Date) {
            self.fixtureId = fixtureId
            self.fixtureKey = fixtureKey
            self.pickedIds = pickedIds
            self.pickedAt = pickedAt
        }

        /// Tolerant, for the same reason `streak`, `hypeLine` and `salt` are:
        /// this sits inside the one blob holding every quiz score and starred
        /// line, so a field added later — or missing from a blob written by a
        /// build that had none of them — must decode as its default rather
        /// than throw and reset all of it.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fixtureId = try c.decodeIfPresent(Int.self, forKey: .fixtureId) ?? 0
            fixtureKey = try c.decodeIfPresent(String.self, forKey: .fixtureKey) ?? ""
            pickedIds = try c.decodeIfPresent([String].self, forKey: .pickedIds) ?? []
            pickedAt = try c.decodeIfPresent(Date.self, forKey: .pickedAt) ?? .distantPast
            uploadedAt = try c.decodeIfPresent(Date.self, forKey: .uploadedAt)
        }

        /// One fixture, seen from before and from after: `b|Tottenham|2026-10-17`
        /// while she is waiting for it, `a|Tottenham|2026-10-17` once it has
        /// been played. Everything past the first character is the fixture.
        static func sameFixture(_ a: String, _ b: String) -> Bool {
            !a.isEmpty && !b.isEmpty && a.dropFirst() == b.dropFirst()
        }
    }

    private struct Persisted: Codable {
        var lastModule: MyTurnModule = .quiz
        var starredLineIds: [String] = []
        var hasSeenRiskExplainer: Bool = false
        var sayThisSituationId: String? = nil
        var lingoExpandedId: String? = nil
        var quizProgress: [String: PackProgress] = [:]
        var quizRound: QuizRound? = nil
        var drillBuckets: [String: [String: Bucket]] = [:]
        var drillSession: DrillSession? = nil
        /// Hype lines already shown, category -> indices into that category.
        /// Optional so a blob written before hype existed still decodes: the
        /// synthesised decoder throws on a missing non-optional key, and this
        /// blob holds every score she has.
        var hypeSeen: [String: [Int]]? = nil
        /// The slip she filled in before kick-off (2026-09-23). Optional for
        /// the same reason as the two above.
        var matchCalls: MatchCalls? = nil
    }

    private var state: Persisted {
        didSet { persist() }
    }

    private static let key = "myTurnState.v1"

    /// Nil is a store that reads and writes nothing, which is what the
    /// self-check below needs: it exercises the real commit/settle rules
    /// without touching the blob holding her scores.
    private let defaults: UserDefaults?

    fileprivate init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.key),
           var decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            // A flashcard session paused under the previous build would resume
            // as an Overheard round of up to nineteen cards, some of them
            // repeats. Start her on a fresh seven instead.
            if decoded.drillSession?.legacy == true { decoded.drillSession = nil }
            state = decoded
        } else {
            state = Persisted()
        }
        #if DEBUG
        myTurnTolerantDecodeSelfCheck()
        #endif
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            defaults?.set(data, forKey: Self.key)
        }
    }

    /// Called from Settings → Delete My Data alongside the other stores.
    func clearAll() {
        state = Persisted()
        lingoQuery = ""
        streakTick = 0
        lingoDealNonce = 0
        defaults?.removeObject(forKey: Self.key)
        resetTick += 1
    }

    /// Bumped by `clearAll`. MyTurnView hangs the module stack's identity on
    /// it, so a wipe rebuilds the three module views instead of only emptying
    /// the store underneath them.
    ///
    /// The modules keep real state of their own that this store never sees and
    /// a relaunch would have thrown away: SayThisView's practise session
    /// (deliberately `@State`, so "Continue · 4 of 10" survives a segment
    /// switch), QuizView's paused flag, LingoView's dealt weekend deck and open
    /// folds. Without this, Delete My Data leaves her mid-round in a session
    /// she just asked us to forget.
    var resetTick: Int = 0

    // MARK: Module

    var lastModule: MyTurnModule {
        get { state.lastModule }
        set { state.lastModule = newValue }
    }

    // MARK: Say This

    var starredLineIds: Set<String> { Set(state.starredLineIds) }
    func isStarred(_ lineId: String) -> Bool { state.starredLineIds.contains(lineId) }
    func toggleStar(_ lineId: String) {
        if let i = state.starredLineIds.firstIndex(of: lineId) {
            state.starredLineIds.remove(at: i)
        } else {
            state.starredLineIds.append(lineId)
        }
    }
    var hasSeenRiskExplainer: Bool {
        get { state.hasSeenRiskExplainer }
        set { state.hasSeenRiskExplainer = newValue }
    }
    var sayThisSituationId: String? {
        get { state.sayThisSituationId }
        set { state.sayThisSituationId = newValue }
    }

    // MARK: Lingo

    /// The search box, deliberately not persisted: every keystroke would
    /// re-encode the whole blob — scores, starred lines, the paused round —
    /// and write it to UserDefaults on the main thread. Nothing is lost by
    /// coming back to an empty search field.
    var lingoQuery: String = ""
    var lingoExpandedId: String? {
        get { state.lingoExpandedId }
        set { state.lingoExpandedId = newValue }
    }

    // MARK: Quiz

    func progress(for packId: String) -> PackProgress { state.quizProgress[packId] ?? PackProgress() }

    var quizRound: QuizRound? {
        get { state.quizRound }
        set { state.quizRound = newValue }
    }

    /// Ten questions, easier first, avoiding ones she has already seen in
    /// this pack until the pack runs out — so the first weeks do not repeat.
    func startRound(pack: QuizPack) {
        let seen = Set(progress(for: pack.id).seenQuestionIds)
        var pool = pack.questions.filter { !seen.contains($0.id) }
        if pool.count < 10 {
            // Pack exhausted: reset the seen list and start over.
            pool = pack.questions
            var p = progress(for: pack.id); p.seenQuestionIds = []; state.quizProgress[pack.id] = p
        }
        // A pack that arrived empty from a bad publish would otherwise start a
        // round of nothing, and the question screen indexes into it.
        let picked = Array(pool.shuffled().prefix(10)).sorted { $0.difficulty < $1.difficulty }
        guard !picked.isEmpty else { return }
        state.quizRound = QuizRound(packId: pack.id, questionIds: picked.map(\.id))
    }

    /// A round of only the questions she missed, in the same pack.
    func startRetryRound(pack: QuizPack, missedIds: [String]) {
        let byId = Dictionary(uniqueKeysWithValues: pack.questions.map { ($0.id, $0) })
        let qs = missedIds.compactMap { byId[$0] }.sorted { $0.difficulty < $1.difficulty }
        guard !qs.isEmpty else { return }
        state.quizRound = QuizRound(packId: pack.id, questionIds: qs.map(\.id))
    }

    func answer(_ option: Int, correct: Bool, questionId: String) {
        guard var round = state.quizRound, round.selected == nil else { return }
        round.selected = option
        if correct {
            round.score += 1
            round.streak += 1
            // Four and eight (Anton, 2026-09-16: three came too easily). Never
            // on the last question: the result card is the moment there, and
            // two rose cards at once is noise.
            if round.streak % 4 == 0, round.streak <= 8, round.index + 1 < round.questionIds.count {
                streakTick = round.streak
            }
        } else {
            round.missedIds.append(questionId)
            round.streak = 0
        }
        state.quizRound = round
    }

    func nextQuestion() {
        guard var round = state.quizRound else { return }
        if round.index + 1 >= round.questionIds.count {
            round.finished = true
            var p = progress(for: round.packId)
            p.played += 1
            // Best is only meaningful on a full ten-question round.
            if round.questionIds.count == 10 { p.best = max(p.best, round.score) }
            p.seenQuestionIds.append(contentsOf: round.questionIds.filter { !p.seenQuestionIds.contains($0) })
            state.quizProgress[round.packId] = p
        } else {
            round.index += 1
            round.selected = nil
        }
        state.quizRound = round
    }

    func endRound() { state.quizRound = nil }

    // MARK: Overheard
    //
    // The three-bucket engine (new / learning / known) that Drills used to own.
    // Drills went as a tab on 2026-09-09, flashcards on 2026-09-22; Lingo's
    // Overheard round keeps the engine, keyed by deck id, and the persisted
    // field names stay so nothing she has already learned is lost.

    func bucket(deckId: String, cardId: String) -> Bucket {
        state.drillBuckets[deckId]?[cardId] ?? .new
    }

    func knownCount(deckId: String) -> Int {
        (state.drillBuckets[deckId] ?? [:]).values.filter { $0 == .known }.count
    }

    var drillSession: DrillSession? {
        get { state.drillSession }
        set { state.drillSession = newValue }
    }

    /// The queue is stored exactly as dealt — `LingoWeekendDeck` has already
    /// decided which words and in what order, and it knows things the store
    /// does not (this weekend's fixture).
    func startDrill(deckId: String, queue: [String]) {
        guard !queue.isEmpty else { return }
        state.drillSession = DrillSession(deckId: deckId, queue: queue)
    }

    /// One tap on an option. Right moves the word up a bucket (new → learning
    /// → known); wrong drops it to `learning`, so the next deck prefers it.
    func answerDrill(_ option: Int, correct: Bool) {
        guard var s = state.drillSession, s.selected == nil, s.index < s.queue.count else { return }
        let cardId = s.queue[s.index]
        s.selected = option
        var deck = state.drillBuckets[s.deckId] ?? [:]
        let current = deck[cardId] ?? .new
        if correct {
            s.knew += 1
            s.knewIds.append(cardId)
            s.streak += 1
            deck[cardId] = current == .new ? .learning : .known
            // Four and eight, the same rule as the quiz, and never on the last
            // one: the end card is the moment there.
            if s.streak % 4 == 0, s.streak <= 8, s.index + 1 < s.queue.count {
                streakTick = s.streak
            }
        } else {
            deck[cardId] = .learning
            s.streak = 0
        }
        state.drillBuckets[s.deckId] = deck
        state.drillSession = s
    }

    func nextDrillCard() {
        // Only after an answer, the same rule the quiz has: "Next" is the way
        // on from the reveal, not a way to skip a card.
        guard var s = state.drillSession, s.selected != nil else { return }
        if s.index + 1 >= s.queue.count {
            s.finished = true
        } else {
            s.index += 1
            s.selected = nil
        }
        state.drillSession = s
    }

    func endDrill() { state.drillSession = nil }

    /// Transient, deliberately not persisted: "Go again" deals a fresh seven
    /// from the same context, but reopening the tab tomorrow should not.
    var lingoDealNonce: Int = 0

    // MARK: The slip
    //
    // Called it: up to three lines committed before kick-off, and after the
    // match the same three with the ones that came up marked. She is never
    // asked whether she said it, there is nothing to settle and nothing to
    // come back for — the slip simply stops being about anything.

    /// After this the slip is about a match she has stopped thinking about, so
    /// it goes without being mentioned. The same week the settle row gets.
    private static let slipLifetime: TimeInterval = 7 * 24 * 3600

    /// Whatever slip is stored, for the debug harness and the uploader. The
    /// views ask `matchCalls(for:)` instead.
    var matchCalls: MatchCalls? { state.matchCalls }

    /// The slip for the fixture this context is about — the one she is waiting
    /// for, or the one just played — and nil for anybody else's.
    func matchCalls(for context: MatchContext) -> MatchCalls? {
        guard let slip = state.matchCalls, slip.fixtureId > 0,
              MatchCalls.sameFixture(slip.fixtureKey, context.fixtureKey),
              Date().timeIntervalSince(slip.pickedAt) <= Self.slipLifetime else { return nil }
        return slip
    }

    /// She walked the slip. Replaces whatever was there: one fixture at a
    /// time, and an old slip is not worth a second card.
    ///
    /// An EMPTY slip is a slip. She said no to all three, and that has to be
    /// remembered or the same three come back on every open of the tab, which
    /// is the nagging this feature exists not to do. Nothing is sent for one —
    /// `LingoView.uploadSlip` refuses a slip with no picks — and the seven-day
    /// `slipLifetime` retires it like any other.
    func commitMatchCalls(fixtureId: Int, fixtureKey: String, pickedIds: [String],
                          at now: Date = Date()) {
        guard fixtureId > 0 else { return }
        state.matchCalls = MatchCalls(fixtureId: fixtureId, fixtureKey: fixtureKey,
                                      pickedIds: pickedIds, pickedAt: now)
    }

    /// The slip reached the device row, so nothing needs to retry it.
    func noteMatchCallsUploaded(at now: Date = Date()) {
        guard state.matchCalls != nil else { return }
        state.matchCalls?.uploadedAt = now
    }

    // MARK: Hype
    //
    // The lines themselves are content (Resources/MyTurn/hype.json); the store
    // only remembers which ones she has already been shown, so nothing repeats
    // until the category runs out.

    /// The run length that just triggered: 4, then 8, and 0 for nothing. Both
    /// the quiz and the Overheard round set it, and the overlay clears it once
    /// shown. Transient: a streak is a moment, not a trophy, and it should not
    /// survive a relaunch.
    ///
    /// This is not the streak the header rule forbids, and a reviewer reading
    /// the code decided it was (2026-09-23). The rule is about obligation
    /// mechanics: a number she is asked to keep alive across days. This one is
    /// a run of right answers inside a single round, it is never persisted, a
    /// relaunch starts it at nought, no screen shows it as a total, and there
    /// is nothing to lose by not playing tomorrow. Four in a row gets her one
    /// line from a friend and then it is gone.
    var streakTick: Int = 0

    /// One line she has not seen from this category, marked as seen. Returns
    /// nil only when the category is empty (a bad publish, or an old bundle).
    /// `excluding` drops lines that do not fit the moment: a streak line that
    /// says "three" is wrong at six and nine.
    func hypeLine(_ category: HypeCategory, from pool: [String],
                  excluding: (String) -> Bool = { _ in false }) -> String? {
        guard !pool.isEmpty else { return nil }
        let eligible = (0..<pool.count).filter { !excluding(pool[$0]) }
        guard !eligible.isEmpty else { return nil }
        var seen = Set((state.hypeSeen?[category.rawValue] ?? []).filter { $0 < pool.count })
        if eligible.allSatisfy({ seen.contains($0) }) { seen.subtract(eligible) }
        guard let pick = eligible.filter({ !seen.contains($0) }).randomElement() else { return nil }
        seen.insert(pick)
        var all = state.hypeSeen ?? [:]
        all[category.rawValue] = seen.sorted()
        state.hypeSeen = all
        return pool[pick]
    }
}

#if DEBUG
/// A paused round written by the build before hype existed has none of the new
/// keys. If `QuizRound` ever loses its tolerant `init(from:)` the synthesised
/// one throws here, the whole `Persisted` blob fails to decode, and she loses
/// every score in it. One assert, fired once per launch from `MyTurnStore`.
@MainActor
func myTurnTolerantDecodeSelfCheck() {
    let old = Data("""
    {"packId":"the-basics","questionIds":["a","b"],"index":1,"score":1,"missedIds":[],"finished":false}
    """.utf8)
    guard let round = try? JSONDecoder().decode(MyTurnStore.QuizRound.self, from: old) else {
        assertionFailure("QuizRound lost its tolerant init(from:) — a paused round now resets her scores")
        return
    }
    assert(round.streak == 0 && round.hypeLine == nil && round.index == 1,
           "QuizRound tolerant decode gave the wrong defaults")

    // A flashcard session paused under the build before Overheard (2026-09-22)
    // has `flipped` and `done` and none of the fields the round needs. It has
    // to resume as an Overheard round on the card she was on, not throw and
    // take every quiz score in the same blob with it.
    let flashcards = Data("""
    {"deckId":"lingo","queue":["offside","var","penalty"],"index":1,"flipped":true,"done":1,"finished":false,"knew":1}
    """.utf8)
    guard let session = try? JSONDecoder().decode(MyTurnStore.DrillSession.self, from: flashcards) else {
        assertionFailure("DrillSession lost its tolerant init(from:) — a paused round now resets her state")
        return
    }
    assert(session.selected == nil && session.streak == 0 && session.hypeLine == nil
           && session.index == 1 && session.knew == 1 && session.queue.count == 3,
           "DrillSession tolerant decode gave the wrong defaults")
    // A session persisted before the salt existed (2026-09-23) has no such key.
    // It must come back as "", which is the option order that round was
    // already showing — not a fresh UUID, which would move the right answer
    // under her thumb on the card she is paused on.
    assert(session.salt == "", "a session written before the salt decodes with a salt, so a paused round reshuffles")
    // ...and it has to be recognisable as one, because a flashcard queue can
    // repeat a word and run to nineteen. `MyTurnStore.init` drops it on that.
    assert(session.legacy, "a flashcard session no longer looks legacy, so it resumes as an Overheard round")

    let fresh = MyTurnStore.DrillSession(deckId: "lingo", queue: ["offside"])
    guard let written = try? JSONEncoder().encode(fresh),
          let read = try? JSONDecoder().decode(MyTurnStore.DrillSession.self, from: written) else {
        assertionFailure("DrillSession does not survive its own encoder")
        return
    }
    assert(!read.legacy, "a session this build wrote looks legacy, so every round is dropped on relaunch")
    // The salt has to be in CodingKeys and actually encoded, or a relaunch
    // reshuffles the options on the card she paused on.
    assert(!fresh.salt.isEmpty && read.salt == fresh.salt,
           "DrillSession.salt does not survive its own encoder, so a resumed round moves the right answer")
    assert(read.optionCount == LingoWeekendDeck.optionCount,
           "DrillSession.optionCount does not survive its own encoder, so every relaunch migrates the round again")

    // The arity migration (2026-09-23). A round paused mid-reveal under the
    // three-option build: `selected` is an index into an order that no longer
    // exists, and the card it belongs to is already banked. It has to resume on
    // the NEXT word, with the score untouched and no reveal showing.
    let midReveal = Data("""
    {"deckId":"lingo","queue":["offside","var","penalty"],"index":1,"selected":2,"finished":false,\
    "knew":2,"knewIds":["offside","var"],"salt":"s"}
    """.utf8)
    guard let moved = try? JSONDecoder().decode(MyTurnStore.DrillSession.self, from: midReveal) else {
        assertionFailure("a round paused under the three-option build no longer decodes")
        return
    }
    assert(moved.index == 2 && moved.selected == nil && !moved.finished,
           "a three-option round resumed on the card she had already answered, at index \(moved.index)")
    assert(moved.knew == 2 && moved.knewIds == ["offside", "var"],
           "the arity migration moved her score, and that card was already banked")
    assert(moved.optionCount == LingoWeekendDeck.optionCount,
           "the migrated round kept the old stamp, so the next launch advances her again")

    // The same round paused on its last card ends, rather than walking off the
    // end of the queue.
    let lastCard = Data("""
    {"deckId":"lingo","queue":["offside","var"],"index":1,"selected":1,"finished":false,"knew":2,"salt":"s"}
    """.utf8)
    assert((try? JSONDecoder().decode(MyTurnStore.DrillSession.self, from: lastCard))?.finished == true,
           "a three-option round answered on its last card did not finish")

    // And an UNANSWERED card is not migrated: it is simply re-dealt at the new
    // count, which is the card she is looking at.
    let unanswered = Data("""
    {"deckId":"lingo","queue":["offside","var"],"index":0,"finished":false,"knew":0,"salt":"s"}
    """.utf8)
    assert((try? JSONDecoder().decode(MyTurnStore.DrillSession.self, from: unanswered))?.index == 0,
           "an unanswered card was skipped by the arity migration, so she never sees that word")
}

/// The slip's one persistence rule, against a store that persists nothing.
///
/// She walks three lines saying yes or no, and the slip commits itself on the
/// last answer. Saying no to all three has to store as an EMPTY slip: without
/// it the next open of the tab deals the same three again, which is exactly the
/// nagging Called it exists not to do. Nothing is sent for one, and the same
/// week retires it.
@MainActor
func myTurnSlipSelfCheck() {
    let store = MyTurnStore(defaults: nil)
    let fixture = MatchContext(page: LingoFixtures.page("matchup", now: Date()), team: .arsenal, now: Date())
    guard let fixtureId = fixture.fixtureId else {
        assertionFailure("the matchup fixture lost its id, so the slip cannot be checked")
        return
    }

    store.commitMatchCalls(fixtureId: fixtureId, fixtureKey: fixture.fixtureKey, pickedIds: [])
    assert(store.matchCalls(for: fixture)?.pickedIds.isEmpty == true,
           "a slip she passed on did not store, so the same three come back on every open")

    // It has to survive the blob it is written into, or the pass is forgotten
    // on the next launch and the cards come back anyway.
    guard let slip = store.matchCalls, let data = try? JSONEncoder().encode(slip),
          let read = try? JSONDecoder().decode(MyTurnStore.MatchCalls.self, from: data) else {
        assertionFailure("MatchCalls does not survive its own encoder, so a walked slip is lost on relaunch")
        return
    }
    assert(read.pickedIds.isEmpty && read.fixtureId == fixtureId,
           "an empty slip came back from its encoder changed")

    // A slip with no fixture behind it is still refused: nothing could resolve
    // it, and nothing could tie it to a result afterwards.
    let unkeyed = MyTurnStore(defaults: nil)
    unkeyed.commitMatchCalls(fixtureId: 0, fixtureKey: fixture.fixtureKey, pickedIds: ["b1"])
    assert(unkeyed.matchCalls == nil, "a slip with no fixture id stored anyway")

    // And a week later it has stopped being about anything.
    let stale = MyTurnStore(defaults: nil)
    stale.commitMatchCalls(fixtureId: fixtureId, fixtureKey: fixture.fixtureKey, pickedIds: [],
                           at: Date().addingTimeInterval(-8 * 24 * 3600))
    assert(stale.matchCalls(for: fixture) == nil, "a slip older than a week is still on the screen")
}

#endif
