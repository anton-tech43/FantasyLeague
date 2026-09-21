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

    /// A round of Overheard: seven snippets, three options on each.
    ///
    /// The queue is dealt once and never re-ordered — re-showing a word she
    /// just got wrong, with the same three options in the same order, tests
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
        /// Right in a row, reset by any miss. Drives the hype card at four and
        /// eight; not a score, not persisted as one.
        var streak: Int = 0
        /// The hype line for this round's end screen, picked once when the
        /// round finished so the card does not reshuffle on every redraw.
        var hypeLine: String? = nil
        /// True when this came out of a flashcard session written by the build
        /// before Overheard: its queue can be nineteen long and can repeat a
        /// word, which is not a round of seven. Not persisted — `MyTurnStore`
        /// drops such a session on the launch that decodes it.
        var legacy: Bool = false

        enum CodingKeys: String, CodingKey {
            case deckId, queue, index, selected, finished, knew, streak, hypeLine
        }

        /// Fields the flashcard build wrote and this one does not.
        private enum LegacyKeys: String, CodingKey { case flipped, done }

        init(deckId: String, queue: [String]) {
            self.deckId = deckId
            self.queue = queue
        }

        /// Tolerant: this struct sits inside the one JSON blob that holds every
        /// starred line and quiz score, so a field added later (`knew`
        /// 2026-09-09, `selected`/`streak`/`hypeLine` 2026-09-22) must decode
        /// as its default rather than throw and reset her state. A session
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
            streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
            hypeLine = try c.decodeIfPresent(String.self, forKey: .hypeLine)
            let old = try decoder.container(keyedBy: LegacyKeys.self)
            legacy = old.contains(.flipped) || old.contains(.done)
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
    }

    private var state: Persisted {
        didSet { persist() }
    }

    private static let key = "myTurnState.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
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
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// Called from Settings → Delete My Data alongside the other stores.
    func clearAll() {
        state = Persisted()
        lingoQuery = ""
        streakTick = 0
        lingoDealNonce = 0
        UserDefaults.standard.removeObject(forKey: Self.key)
    }

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

    // MARK: Hype
    //
    // The lines themselves are content (Resources/MyTurn/hype.json); the store
    // only remembers which ones she has already been shown, so nothing repeats
    // until the category runs out.

    /// The run length that just triggered: 4, then 8, and 0 for nothing. Both
    /// the quiz and the Overheard round set it, and the overlay clears it once
    /// shown. Transient: a streak is a moment, not a trophy, and it should not
    /// survive a relaunch.
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
}
#endif
