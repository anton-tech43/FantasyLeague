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
        }
    }

    enum Bucket: String, Codable { case new, learning, known }

    struct DrillSession: Codable, Equatable {
        let deckId: String
        var queue: [String]
        var index: Int = 0
        var flipped: Bool = false
        var done: Int = 0
        var finished: Bool = false
        /// Cards graded "Knew it" this session, for the end screen.
        var knew: Int = 0

        init(deckId: String, queue: [String]) {
            self.deckId = deckId
            self.queue = queue
        }

        /// Tolerant: this struct sits inside the one JSON blob that holds every
        /// starred line and quiz score, so a field added later (`knew`, 2026-09-09)
        /// must decode as its default rather than throw and reset her state.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            deckId = try c.decode(String.self, forKey: .deckId)
            queue = try c.decode([String].self, forKey: .queue)
            index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
            flipped = try c.decodeIfPresent(Bool.self, forKey: .flipped) ?? false
            done = try c.decodeIfPresent(Int.self, forKey: .done) ?? 0
            finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
            knew = try c.decodeIfPresent(Int.self, forKey: .knew) ?? 0
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
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
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
            // Three, six and nine. Not every question, or it stops meaning
            // anything, and never on the last one: the result card is the
            // moment there, and two rose cards at once is noise.
            if round.streak % 3 == 0, round.streak <= 9, round.index + 1 < round.questionIds.count {
                streakTick += 1
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

    // MARK: Flashcards
    //
    // The three-bucket engine (new / learning / known) that Drills used to own.
    // Drills went as a tab on 2026-09-09; Lingo's flashcard practise keeps the
    // engine, keyed by deck id, and the persisted field names stay so nothing
    // she has already learned is lost.

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

    /// Ten cards: learning first (they are the ones she asked to see again),
    /// then new, then known — shuffled within each bucket.
    func startDrill(deckId: String, cardIds: [String]) {
        let buckets = state.drillBuckets[deckId] ?? [:]
        func pick(_ b: Bucket) -> [String] { cardIds.filter { (buckets[$0] ?? .new) == b }.shuffled() }
        let ordered = pick(.learning) + pick(.new) + pick(.known)
        state.drillSession = DrillSession(deckId: deckId, queue: Array(ordered.prefix(10)))
    }

    func flip() {
        guard var s = state.drillSession else { return }
        s.flipped = true
        state.drillSession = s
    }

    /// Knew it moves the card up a bucket. Didn't know it sends it to
    /// `learning` and back into this session's queue a few cards later.
    func grade(knewIt: Bool) {
        guard var s = state.drillSession, s.index < s.queue.count else { return }
        let cardId = s.queue[s.index]
        var deck = state.drillBuckets[s.deckId] ?? [:]
        let current = deck[cardId] ?? .new
        if knewIt {
            s.knew += 1
            deck[cardId] = current == .new ? .learning : .known
            if current == .learning || current == .known { deck[cardId] = .known }
        } else {
            deck[cardId] = .learning
            if s.done < 10 - 1 {
                let insertAt = min(s.queue.count, s.index + 3)
                s.queue.insert(cardId, at: insertAt)
            }
        }
        state.drillBuckets[s.deckId] = deck
        s.done += 1
        s.flipped = false
        if s.done >= 10 || s.index + 1 >= s.queue.count {
            s.finished = true
        } else {
            s.index += 1
        }
        state.drillSession = s
    }

    func endDrill() { state.drillSession = nil }

    // MARK: Hype
    //
    // The lines themselves are content (Resources/MyTurn/hype.json); the store
    // only remembers which ones she has already been shown, so nothing repeats
    // until the category runs out.

    /// Bumped at three, six and nine correct in a row. Transient: a streak is
    /// a moment, not a trophy, and it should not survive a relaunch.
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
}
#endif
