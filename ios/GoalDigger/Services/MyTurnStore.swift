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
        /// Which words she got right, for the line the end screen offers her.
        /// Kept alongside `knew` rather than replacing it: a round paused under
        /// an older build has the count and not the ids, and a resumed round
        /// must still show the score she actually had.
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

        enum CodingKeys: String, CodingKey {
            case deckId, queue, index, selected, finished, knew, knewIds, streak, hypeLine, salt
        }

        /// Fields the flashcard build wrote and this one does not.
        private enum LegacyKeys: String, CodingKey { case flipped, done }

        init(deckId: String, queue: [String]) {
            self.deckId = deckId
            self.queue = queue
            self.salt = UUID().uuidString
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
        }
    }

    /// One line she said she would use, and whether she did.
    ///
    /// The whole of the commitment loop's state. One at a time, keyed by
    /// fixture, and it retires itself: three sightings, or seven days, or the
    /// moment she answers, whichever comes first. Nothing counts it, nothing
    /// adds it up, and ignoring it leaves no debt — see the header rule.
    struct SaidLine: Codable, Equatable {
        /// `MatchContext.fixtureKey`, stable across kick-off time nudges.
        let fixtureKey: String
        let termId: String
        /// The sayIt text as it was shown, so later copy cannot drift under
        /// the question we are about to ask her about it.
        let line: String
        /// "Saturday" / "the Leeds game", for the settle row's wording.
        let occasion: String
        let committedAt: Date
        /// Settle-row impressions. Dropped after three.
        var shownCount: Int = 0
        var settledAt: Date? = nil
        var used: Bool? = nil

        init(fixtureKey: String, termId: String, line: String, occasion: String, committedAt: Date) {
            self.fixtureKey = fixtureKey
            self.termId = termId
            self.line = line
            self.occasion = occasion
            self.committedAt = committedAt
        }

        /// Tolerant for the same reason every other struct in this blob is: it
        /// sits in the one JSON that holds every quiz score and starred line,
        /// so a field added to it later must decode as its default rather than
        /// throw and take all of that down with it.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fixtureKey = try c.decode(String.self, forKey: .fixtureKey)
            termId = try c.decode(String.self, forKey: .termId)
            line = try c.decode(String.self, forKey: .line)
            occasion = try c.decode(String.self, forKey: .occasion)
            committedAt = try c.decode(Date.self, forKey: .committedAt)
            shownCount = try c.decodeIfPresent(Int.self, forKey: .shownCount) ?? 0
            settledAt = try c.decodeIfPresent(Date.self, forKey: .settledAt)
            used = try c.decodeIfPresent(Bool.self, forKey: .used)
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
        /// The one line she said she would use. Optional for the same reason
        /// `hypeSeen` is: the synthesised decoder throws on a missing
        /// non-optional key, and every blob written before today lacks this one.
        var saidLine: SaidLine? = nil
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

    // MARK: The line she said she would use
    //
    // The only thing a round leaves behind. One line, one fixture, one
    // question about it afterwards, and then it is gone whatever she does —
    // including nothing. Every rule that retires it lives here so the views
    // only ask "is there a row" and "she tapped this one".

    /// Three sightings of the settle row is enough of an ask. `fileprivate`
    /// only so the self-check at the bottom of this file counts to the same
    /// three the rule does.
    fileprivate static let lineImpressions = 3
    /// After a week the question is about a match she has stopped thinking
    /// about, so it is dropped without ever being mentioned.
    private static let lineLifetime: TimeInterval = 7 * 24 * 3600

    /// Replaces whatever was there. One at a time, keyed by fixture: a second
    /// round this week means the newer line is the one in her hand, and an
    /// older unsettled one is not worth two rows or a queue.
    func commitLine(_ line: SaidLine) { state.saidLine = line }

    /// The line waiting to be settled, or nil when there is nothing to ask.
    ///
    /// `currentFixture` is the fixture the app is looking at now: a line can
    /// only be settled once its own fixture is no longer the current one,
    /// which is the only way the store can tell the game has been played. It
    /// holds no calendar and no team page, so this one fact comes in.
    func pendingLine(currentFixture: String) -> SaidLine? {
        guard let line = state.saidLine, line.settledAt == nil,
              line.fixtureKey != currentFixture,
              line.shownCount < Self.lineImpressions,
              Date().timeIntervalSince(line.committedAt) <= Self.lineLifetime else { return nil }
        return line
    }

    /// The unsettled line committed for this fixture, so the end screen can
    /// show its confirmation instead of offering again.
    func committedLine(fixture: String) -> SaidLine? {
        guard let line = state.saidLine, line.settledAt == nil,
              line.fixtureKey == fixture else { return nil }
        return line
    }

    /// One settle-row impression. The third is the last.
    func noteLineShown() {
        guard var line = state.saidLine, line.settledAt == nil else { return }
        line.shownCount += 1
        state.saidLine = line
    }

    /// "I did" retires the word; "Not yet" puts it back in the deck. Either
    /// way the row is over, and nothing is counted.
    func settleLine(used: Bool) {
        guard var line = state.saidLine, line.settledAt == nil else { return }
        line.settledAt = Date()
        line.used = used
        state.saidLine = line
        // The commitment only ever comes out of a Lingo round, so the bucket
        // it moves is that deck's.
        var deck = state.drillBuckets[LingoWeekendDeck.deckId] ?? [:]
        deck[line.termId] = used ? .known : .learning
        state.drillBuckets[LingoWeekendDeck.deckId] = deck
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
}

/// The commitment loop's rules, against a store that persists nothing.
///
/// Every one of these is a way the loop turns into the thing the module's
/// header rule forbids: a row that never goes away, a question about a match
/// from last month, a line she settled coming back, or two lines queued up
/// waiting for her. Fired once per launch alongside `lingoDeckSelfCheck`.
@MainActor
func myTurnSaidLineSelfCheck() {
    let store = MyTurnStore(defaults: nil)
    let fixture = "b|Tottenham|2026-10-17"
    func line(_ id: String = "squeaky-bum-time", fixture: String = fixture,
              committedAt: Date = Date()) -> MyTurnStore.SaidLine {
        MyTurnStore.SaidLine(fixtureKey: fixture, termId: id, line: "Right, squeaky bum time.",
                             occasion: "Saturday", committedAt: committedAt)
    }

    // It has to survive the blob it is written into.
    guard let data = try? JSONEncoder().encode(line()),
          let read = try? JSONDecoder().decode(MyTurnStore.SaidLine.self, from: data) else {
        assertionFailure("SaidLine does not survive its own encoder, so a committed line is lost on relaunch")
        return
    }
    assert(read == line(committedAt: read.committedAt) && read.shownCount == 0
           && read.settledAt == nil && read.used == nil,
           "SaidLine came back from its encoder changed")

    // Before the game: nothing to ask, because she has not had the chance yet.
    store.commitLine(line())
    assert(store.pendingLine(currentFixture: fixture) == nil,
           "the settle row shows before the game has been played")
    assert(store.committedLine(fixture: fixture)?.termId == "squeaky-bum-time",
           "the end screen cannot see the line she just committed")

    // After it: one row, and three sightings is the whole of the asking.
    let next = "b|Fulham|2026-10-24"
    assert(store.pendingLine(currentFixture: next) != nil, "no settle row after the game was played")
    for _ in 0..<MyTurnStore.lineImpressions { store.noteLineShown() }
    assert(store.pendingLine(currentFixture: next) == nil,
           "the settle row is still asking after three openings")

    // A week old is a question about a match she has forgotten.
    let stale = MyTurnStore(defaults: nil)
    stale.commitLine(line(committedAt: Date().addingTimeInterval(-8 * 24 * 3600)))
    assert(stale.pendingLine(currentFixture: next) == nil, "a line older than a week still asks")

    // "I did" retires the word, "Not yet" puts it back in the deck, and either
    // way the row is over.
    let did = MyTurnStore(defaults: nil)
    did.commitLine(line())
    did.settleLine(used: true)
    assert(did.bucket(deckId: LingoWeekendDeck.deckId, cardId: "squeaky-bum-time") == .known,
           "\"I did\" did not retire the word")
    assert(did.pendingLine(currentFixture: next) == nil, "a settled line is still asking")
    assert(did.committedLine(fixture: fixture) == nil, "a settled line still reads as committed")

    let notYet = MyTurnStore(defaults: nil)
    notYet.commitLine(line())
    notYet.settleLine(used: false)
    assert(notYet.bucket(deckId: LingoWeekendDeck.deckId, cardId: "squeaky-bum-time") == .learning,
           "\"Not yet\" did not put the word back in the deck")

    // One at a time: a second round replaces the line, it does not queue up.
    let twice = MyTurnStore(defaults: nil)
    twice.commitLine(line())
    twice.commitLine(line("clean-sheet", fixture: next))
    assert(twice.pendingLine(currentFixture: fixture)?.termId == "clean-sheet",
           "committing twice left the older line waiting as well")
}
#endif
