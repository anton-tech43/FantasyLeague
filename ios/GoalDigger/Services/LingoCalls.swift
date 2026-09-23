import Foundation

/// Called it: the slip, and the rule that decides whether a line came up.
///
/// Before kick-off she is offered three lines she might get to say — one
/// near-certain, one likely, one long shot. She picks them and watches the
/// match hunting for her moment. **The app never asks whether she said it.**
/// It knows what happened on the pitch, and that is enough.
///
/// Pure and deterministic, like `PlayerSlots`: values in, values out. No
/// networking, no store, no `Date()` of its own, so the self-check at the
/// bottom is the whole test.
///
/// The trigger grammar is fixed by `tools/myturn/CALLED_IT_CONTRACT.md` and its
/// semantics by `tools/myturn/call_vectors.json`, which this file's self-check
/// reads and `_shared/match-calls.ts`'s test reads too. The same file, not a
/// copy: the two resolvers cannot come to disagree without one of them going
/// red. Nothing here may be "improved" without a vector.
///
/// The reading rule where the vectors are silent, copied from the Deno side
/// word for word: an ABSENT trigger field means "don't care"; a trigger field
/// that IS present is never satisfied by an unknown outcome field. The feed
/// publishes a score a beat before it publishes the scorer, and a pick must not
/// land on a goal we cannot attribute.
enum LingoCalls {
    // MARK: The three bands

    /// One banker, one likely, one long shot. A round of three that all miss is
    /// the failure mode that kills this feature, so `offer` refuses to deal a
    /// slip without a banker at all.
    enum Band: String, CaseIterable {
        case banker, likely, longshot

        /// What the slip calls it. Not odds and not a score — a hint at how
        /// hard she is making it for herself.
        var label: String {
            switch self {
            case .banker:   return "Near certain"
            case .likely:   return "Likely"
            case .longshot: return "Long shot"
            }
        }
    }

    /// The only moments that can resolve, because the push is the delivery and
    /// these are the only moments that push. A kind this build does not know
    /// never resolves, which is what makes a newer content file safe.
    enum Kind: String { case goal, halftime, fulltime }

    // MARK: What happened

    /// One resolvable moment, FROM HER DEVICE'S POINT OF VIEW: `us` is the club
    /// she follows. Mirrors `Outcome` in `_shared/match-calls.ts`, except that
    /// every field the feed can be late with is optional here as well as
    /// nullable there — unknown is unknown, and it never satisfies a trigger
    /// that asks about it.
    ///
    /// An own goal's side follows API-Football: the event is credited to the
    /// side that BENEFITED, so `side: "us", ownGoal: true` is our goal, put in
    /// by one of theirs.
    enum Outcome: Equatable {
        case goal(side: String, scorerRole: String?, penalty: Bool?, ownGoal: Bool?, minute: Int?)
        case halftime(state: String?, conceded: Int?)
        case fulltime(state: String?, cleanSheet: Bool?, comeback: Bool?)

        var kind: Kind {
            switch self {
            case .goal:     return .goal
            case .halftime: return .halftime
            case .fulltime: return .fulltime
            }
        }
    }

    // MARK: The rule

    /// Does this trigger describe the moment that just happened?
    ///
    /// Total: any shape of nonsense answers false rather than throwing. This is
    /// the Swift half of the pair the vectors pin down; every change to it is a
    /// change to `triggerMatches` in `_shared/match-calls.ts` as well.
    static func resolve(trigger: LingoCallTrigger?, outcome: Outcome) -> Bool {
        guard let trigger, let kind = trigger.kind.flatMap(Kind.init(rawValue:)),
              kind == outcome.kind else { return false }

        switch outcome {
        case .goal(let side, let role, let penalty, let ownGoal, let minute):
            if let want = trigger.side, want != "any", want != side { return false }
            if let want = trigger.scorerRole, want != "any" {
                // Unknown scorer never satisfies a role trigger.
                guard let role, role == want else { return false }
            }
            if let want = trigger.penalty, penalty != want { return false }
            if let want = trigger.ownGoal, ownGoal != want { return false }
            if trigger.minuteFrom != nil || trigger.minuteTo != nil {
                // Unknown minute never satisfies a minute window.
                guard let minute else { return false }
                if let from = trigger.minuteFrom, minute < from { return false }
                if let to = trigger.minuteTo, minute > to { return false }
            }
            return true

        case .halftime(let state, let conceded):
            if let want = trigger.state, state != want { return false }
            if let want = trigger.conceded, conceded != want { return false }
            return true

        case .fulltime(let state, let cleanSheet, let comeback):
            if let want = trigger.state, state != want { return false }
            if let want = trigger.cleanSheet, cleanSheet != want { return false }
            if let want = trigger.comeback, comeback != want { return false }
            return true
        }
    }

    // MARK: The slip

    /// Is this call something this build can put in front of her at all? A line
    /// with no words, no band this build knows or no trigger it can resolve is
    /// dropped rather than offered: an unresolvable pick is a promise the app
    /// cannot keep.
    static func usable(_ call: LingoCall) -> Bool {
        !call.id.isEmpty && !call.line.isEmpty
            && Band(rawValue: call.band ?? "") != nil
            && Kind(rawValue: call.trigger?.kind ?? "") != nil
    }

    /// Three lines for this fixture: one banker, one likely, one long shot, in
    /// that order, filtered by the context's tags and seeded by `fixtureKey` so
    /// a slip she comes back to is the slip she left.
    ///
    /// **It refuses to deal a slip with no banker**, returning nothing at all.
    /// Three lines that all miss is the one outcome that kills this feature —
    /// she watches a whole match for a moment that was never coming, and the
    /// app has nothing to tell her at the end of it. The banker is the promise
    /// that at least one of them lands; without one in the pool there is no
    /// slip worth offering, and fewer than three (a banker and a likely, a
    /// banker alone) is a perfectly good round.
    ///
    /// Nothing at all before there is a fixture to play, and nothing for a
    /// fixture the calendar has no id for: a pick that cannot be keyed to a
    /// fixture is one the push could never resolve, and the reveal afterwards
    /// could never tie to a result. Same gate, same reason, as
    /// `MatchContext.matchupTags`.
    static func offer(calls: [LingoCall], context: MatchContext) -> [LingoCall] {
        guard case .before = context.phase, context.fixtureId != nil else { return [] }
        let pool = calls.filter(usable)
        guard !pool.isEmpty else { return [] }

        // The context's tags always end in `any`, so a call tagged `any` (or
        // tagged nothing at all) fits every fixture.
        let allow = Set(context.tags)
        let live = Set(context.tags.filter { $0 != "any" })
        func tags(_ call: LingoCall) -> Set<String> { Set(call.when ?? ["any"]) }

        func best(_ band: Band) -> LingoCall? {
            let banded = pool.filter { $0.band == band.rawValue && !tags($0).isDisjoint(with: allow) }
            guard !banded.isEmpty else { return nil }
            // A line about the game she is actually walking into beats a line
            // for any match; inside either group the draw is seeded, so the
            // same fixture offers the same slip every time it is drawn.
            let relevant = banded.filter { !tags($0).isDisjoint(with: live) }
            let group = relevant.isEmpty ? banded : relevant
            return group.min { draw(context.fixtureKey, $0) < draw(context.fixtureKey, $1) }
        }

        guard let banker = best(.banker) else { return [] }
        return [banker, best(.likely), best(.longshot)].compactMap { $0 }
    }

    /// One seeded draw per call, so the offer does not move under her.
    private static func draw(_ fixtureKey: String, _ call: LingoCall) -> (UInt64, String) {
        var rng = LiveClubPack.SeededGenerator(seed: fixtureKey + "|" + call.id)
        return (rng.next(), call.id)
    }

    // MARK: Afterwards

    /// Which of her picks came up, in the order they were offered.
    ///
    /// A stale fixture id resolves to nothing, the same rule `matchedCalls` has
    /// on the server: a slip filled in for last week's game must never be told
    /// it came up at this week's.
    static func matched(stored: MyTurnStore.MatchCalls?, fixtureId: Int,
                        calls: [LingoCall], outcomes: [Outcome]) -> [LingoCall] {
        guard let stored, fixtureId > 0, stored.fixtureId == fixtureId,
              !outcomes.isEmpty else { return [] }
        let picked = Set(stored.pickedIds)
        return calls.filter { picked.contains($0.id) }
            .filter { call in outcomes.contains { resolve(trigger: call.trigger, outcome: $0) } }
    }

    /// What the app can say for itself happened, out of the result on the team
    /// page. Full-time only, and only what the scoreline actually proves.
    ///
    /// The real delivery is the goal push, which resolves server-side against
    /// the feed's events while she is watching. This is the backstop for the
    /// reveal afterwards, and it is deliberately narrow: `recent_results`
    /// carries a score and nothing else, so a goal's scorer, his position and
    /// its minute — and whether the win was a comeback — are all unknown here,
    /// and unknown never satisfies a trigger that asks about them. That is why
    /// the reveal marks what came up and never claims that anything did not.
    ///
    /// // ponytail: full-time only. To resolve goals locally the app would have
    /// to cache the fixture's events with each scorer's `players.position`,
    /// which nothing on the device holds today — `ContentItem.scorers` has the
    /// name and the minute but no position, and it is a feed row rather than
    /// per-fixture state. Plumb that through when a second surface needs it.
    static func outcomes(after context: MatchContext) -> [Outcome] {
        guard case .after(_, let result, _, let oppScore) = context.phase else { return [] }
        let state: String
        switch result {
        case "W": state = "win"
        case "D": state = "draw"
        case "L": state = "loss"
        default:  return []
        }
        return [.fulltime(state: state, cleanSheet: oppScore.map { $0 == 0 }, comeback: nil)]
    }
}

#if DEBUG
extension LingoCalls {
    // MARK: - The shared vectors

    /// `tools/myturn/call_vectors.json`, referenced by the app target rather
    /// than copied into it: the Deno resolver's test reads the same bytes, and
    /// a copy is a way for the two to drift apart quietly.
    private struct VectorFile: Decodable {
        let vectors: [Vector]

        struct Vector: Decodable {
            let name: String
            let outcome: RawOutcome
            let trigger: LingoCallTrigger
            let matches: Bool
        }

        /// The vector's outcome, flat, because JSON has no enums.
        struct RawOutcome: Decodable {
            let kind: String
            let side: String?
            let scorerRole: String?
            let penalty: Bool?
            let ownGoal: Bool?
            let minute: Int?
            let state: String?
            let conceded: Int?
            let cleanSheet: Bool?
            let comeback: Bool?

            var outcome: Outcome? {
                switch Kind(rawValue: kind) {
                case .goal:
                    return .goal(side: side ?? "any", scorerRole: scorerRole,
                                 penalty: penalty, ownGoal: ownGoal, minute: minute)
                case .halftime: return .halftime(state: state, conceded: conceded)
                case .fulltime: return .fulltime(state: state, cleanSheet: cleanSheet, comeback: comeback)
                case nil:       return nil
                }
            }
        }
    }

    /// How many vectors the contract had when this was written. The file is
    /// shared with the Deno test, so a shrinking one means somebody deleted a
    /// case rather than added one, and this build should say so.
    static let expectedVectors = 20

    // MARK: - Self-check

    /// Every vector in the shared file, plus the rules the vectors do not
    /// cover: no banker, no calls, no fixture, determinism, and a stale slip.
    /// Fired once per launch from Lingo's `onAppear`, next to
    /// `lingoDeckSelfCheck`.
    static func selfCheck() {
        // --- The shared vectors ---------------------------------------------
        guard let url = Bundle.main.url(forResource: "call_vectors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(VectorFile.self, from: data) else {
            assertionFailure("call_vectors.json is not in the bundle, so the Swift and Deno resolvers are untested against each other")
            return
        }
        assert(file.vectors.count >= expectedVectors,
               "call_vectors.json has \(file.vectors.count) vectors, was \(expectedVectors): a case was deleted")
        for vector in file.vectors {
            guard let outcome = vector.outcome.outcome else {
                assertionFailure("vector \(vector.name) has outcome kind '\(vector.outcome.kind)', which this build cannot resolve")
                continue
            }
            assert(resolve(trigger: vector.trigger, outcome: outcome) == vector.matches,
                   "vector \(vector.name): Swift says \(!vector.matches), the vector says \(vector.matches)")
        }

        // --- The slip --------------------------------------------------------
        let now = MatchContext.parseISO("2026-10-17T12:00:00Z")!
        // A Before context with a live calendar row, so it has a fixture id.
        let fixture = MatchContext(page: LingoFixtures.page("matchup", now: now), team: .arsenal, now: now)
        assert(fixture.fixtureId == 1387422, "the matchup fixture lost its id: \(fixture.fixtureId.map(String.init) ?? "nil")")

        func call(_ id: String, _ band: Band, when: [String]? = nil,
                  trigger: LingoCallTrigger = .init(kind: "goal", side: "us")) -> LingoCall {
            LingoCall(id: id, line: "Line \(id).", trigger: trigger, band: band.rawValue, when: when)
        }
        let full = [call("b1", .banker), call("b2", .banker),
                    call("l1", .likely), call("s1", .longshot)]

        let slip = offer(calls: full, context: fixture)
        assert(slip.count == 3, "a full pool dealt \(slip.count) lines, not three")
        assert(slip.map { $0.band } == [Band.banker.rawValue, Band.likely.rawValue, Band.longshot.rawValue],
               "the slip is not one banker, one likely, one long shot: \(slip.map { $0.band ?? "nil" })")
        assert(offer(calls: full, context: fixture).map(\.id) == slip.map(\.id),
               "the same fixture dealt a different slip, so a slip reshuffles under her")

        // No banker: nothing at all, rather than a slip that can go nought for
        // three. Fewer than three WITH one is fine.
        assert(offer(calls: [call("l1", .likely), call("s1", .longshot)], context: fixture).isEmpty,
               "a pool with no banker still dealt a slip")
        assert(offer(calls: [call("b1", .banker)], context: fixture).map(\.id) == ["b1"],
               "a banker on its own is a slip and was refused")
        assert(offer(calls: [], context: fixture).isEmpty, "no calls at all still dealt something")

        // Only before a game, and only one we can key to a fixture. The derby
        // page has no calendar row, so it has no id.
        let derby = MatchContext(page: LingoFixtures.page("derby", now: now), team: .arsenal, now: now)
        assert(derby.fixtureId == nil, "the derby fixture grew an id")
        assert(offer(calls: full, context: derby).isEmpty,
               "a fixture the calendar has no id for was offered a slip nothing could resolve")
        let after = MatchContext(page: LingoFixtures.page("after-win", now: now), team: .arsenal, now: now)
        assert(offer(calls: full, context: after).isEmpty, "a slip was offered for a game already played")

        // Tags: this fixture is tagged opp-set-piece, and not derby.
        assert(fixture.tags.contains("opp-set-piece") && !fixture.tags.contains("derby"),
               "the matchup fixture's tags moved: \(fixture.tags)")
        let tagged = offer(calls: [call("b1", .banker), call("b2", .banker, when: ["opp-set-piece"])],
                           context: fixture)
        assert(tagged.map(\.id) == ["b2"], "the fixture's own tag did not win the banker slot: \(tagged.map(\.id))")
        assert(offer(calls: [call("d1", .banker, when: ["derby"])], context: fixture).isEmpty,
               "a derby-only line was dealt for a game that is not one")

        // Unusable content is dropped, not offered: a band or a trigger kind
        // this build has never heard of cannot resolve, so it cannot be a pick.
        let junk = [LingoCall(id: "", line: "No id.", trigger: .init(kind: "goal"), band: "banker"),
                    LingoCall(id: "blank", line: "", trigger: .init(kind: "goal"), band: "banker"),
                    LingoCall(id: "noband", line: "L.", trigger: .init(kind: "goal"), band: nil),
                    LingoCall(id: "future", line: "L.", trigger: .init(kind: "redcard"), band: "banker"),
                    LingoCall(id: "notrigger", line: "L.", trigger: nil, band: "banker")]
        assert(junk.allSatisfy { !usable($0) }, "an unusable call passed the gate")
        assert(offer(calls: junk, context: fixture).isEmpty, "an unusable call was dealt")

        // --- Afterwards -------------------------------------------------------
        let won = MatchContext.parseISO("2026-10-17T12:00:00Z")!
        let win = [Outcome.fulltime(state: "win", cleanSheet: true, comeback: nil)]
        let picks = [call("w", .banker, trigger: .init(kind: "fulltime", state: "win")),
                     call("cs", .likely, trigger: .init(kind: "fulltime", cleanSheet: true)),
                     call("cb", .longshot, trigger: .init(kind: "fulltime", comeback: true))]
        let stored = MyTurnStore.MatchCalls(fixtureId: 1387422, fixtureKey: fixture.fixtureKey,
                                            pickedIds: picks.map(\.id), pickedAt: won)
        let landed = matched(stored: stored, fixtureId: 1387422, calls: picks, outcomes: win)
        assert(landed.map(\.id) == ["w", "cs"],
               "a 1-0 win did not land the win and the clean sheet, or claimed the comeback we cannot see: \(landed.map(\.id))")

        // A stale fixture id resolves to nothing, whatever happened.
        assert(matched(stored: stored, fixtureId: 1387423, calls: picks, outcomes: win).isEmpty,
               "last week's slip came up at this week's game")
        assert(matched(stored: nil, fixtureId: 1387422, calls: picks, outcomes: win).isEmpty,
               "no slip at all still matched something")
        assert(matched(stored: stored, fixtureId: 1387422, calls: picks, outcomes: []).isEmpty,
               "a match with nothing known about it still marked a pick")

        // The slip belongs to one fixture, seen from either side of kick-off.
        assert(MyTurnStore.MatchCalls.sameFixture("b|Tottenham|2026-10-17", "a|Tottenham|2026-10-17"),
               "the same fixture before and after kick-off read as two")
        assert(!MyTurnStore.MatchCalls.sameFixture("b|Tottenham|2026-10-17", "b|Fulham|2026-10-24"),
               "two different fixtures read as one")
        assert(!MyTurnStore.MatchCalls.sameFixture("", "a|Tottenham|2026-10-17"),
               "a slip with no fixture key matched a real fixture")

        // What we can say for ourselves out of a result: the 3-0 win on the
        // after-win page is a win and a clean sheet, and nothing about how it
        // was built.
        let derived = outcomes(after: after)
        assert(derived == [.fulltime(state: "win", cleanSheet: true, comeback: nil)],
               "a 3-0 win derived \(derived)")
        assert(outcomes(after: fixture).isEmpty, "a game not yet played derived an outcome")
    }
}
#endif
