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

    // MARK: When she gets to say it

    /// The moment a trigger marks, in the words she would use for it: "If one
    /// of their forwards scores", "If we're ahead at half-time".
    ///
    /// The fallback behind `LingoCall.situation`, so all 59 published lines
    /// carry a when from day one rather than waiting on 59 hand-written ones.
    /// Pure, total and never empty — a card with a blank line above it is worse
    /// than a card with a dull one.
    ///
    /// It is a fallback and not the answer, which is why the authored field
    /// exists: the grammar cannot say everything the copy wants to. 59 calls
    /// share 48 triggers, so several cards read alike; a minute window becomes
    /// a bucket rather than a number, because nobody says "in minute 90 or
    /// later"; and `conceded: 0` is "we have not let one in", never "nil-nil",
    /// because the feed cannot see from here whether WE have scored.
    ///
    /// Same reading rule as `resolve`: an absent field is don't-care and says
    /// nothing, `any` is how the content spells absent, and a field that IS
    /// present is always spoken, so the sentence never promises a wider moment
    /// than the trigger will mark.
    static func moment(_ trigger: LingoCallTrigger?) -> String {
        guard let trigger, let kind = trigger.kind.flatMap(Kind.init(rawValue:)) else {
            // A kind this build has never heard of is never offered (`usable`),
            // so this is the shape of a bug rather than a card she will read.
            return "Some time in this match"
        }
        switch kind {
        case .goal:     return goalMoment(trigger)
        case .halftime: return halftimeMoment(trigger)
        case .fulltime: return fulltimeMoment(trigger)
        }
    }

    /// `any` is the content's spelling of "don't care", same as in `implies`.
    private static func named(_ raw: String?) -> String? { raw == "any" ? nil : raw }

    private static func goalMoment(_ t: LingoCallTrigger) -> String {
        let side = named(t.side)
        var clause: String
        if t.ownGoal == true {
            // An own goal is credited to the side that BENEFITED, per
            // API-Football and `Outcome`, so `side: "us"` is one of THEIRS
            // putting it into his own net.
            switch side {
            case "us":   clause = "one of theirs puts it in his own net"
            case "them": clause = "one of ours puts it in his own net"
            default:     clause = "there's an own goal"
            }
        } else if let role = named(t.scorerRole), let phrase = scorer(role: role, side: side) {
            clause = phrase
        } else {
            switch side {
            case "us":   clause = "we score"
            case "them": clause = "they score"
            default:     clause = "there's a goal"
            }
        }
        if t.penalty == true { clause += " from the spot" }
        if let window = window(from: t.minuteFrom, to: t.minuteTo) { clause += " " + window }
        return "If " + clause
    }

    /// The four values `players.position` actually holds, in the words she
    /// hears them called. Nil for a position this build does not know, which
    /// falls back to the plain goal rather than inventing a word for it.
    private static func scorer(role: String, side: String?) -> String? {
        let ours = side == "us", theirs = side == "them"
        func one(_ singular: String, _ plural: String) -> String {
            ours ? "one of our \(plural) scores"
                : theirs ? "one of their \(plural) scores" : "a \(singular) scores"
        }
        switch role {
        // There is only ever one of him, so he does not take "one of".
        case "Goalkeeper": return ours ? "our keeper scores"
                                : theirs ? "their keeper scores" : "a keeper scores"
        case "Defender":   return one("defender", "defenders")
        case "Midfielder": return one("midfielder", "midfielders")
        case "Attacker":   return one("forward", "forwards")
        default:           return nil
        }
    }

    /// A minute window as a part of the match rather than a number. The
    /// buckets are wide on purpose: "in minute 46 or later" is not a thing
    /// anybody says, and the sentence has to survive being read out loud.
    private static func window(from: Int?, to: Int?) -> String? {
        switch (from, to) {
        case let (f?, t?):
            return "between the \(f)th and the \(t)th minute"
        case let (f?, nil):
            if f >= 90 { return "in added time" }
            if f >= 86 { return "in the last few minutes" }
            if f >= 76 { return "in the last ten minutes" }
            if f >= 61 { return "late on" }
            if f >= 46 { return "after half-time" }
            return "after the first \(f) minutes"
        case let (nil, t?):
            if t <= 10 { return "in the first ten minutes" }
            if t <= 20 { return "in the first twenty minutes" }
            if t <= 45 { return "before half-time" }
            if t <= 60 { return "in the first hour" }
            return "in the first \(t) minutes"
        case (nil, nil):
            return nil
        }
    }

    private static func halftimeMoment(_ t: LingoCallTrigger) -> String {
        // `conceded: 0` is what the feed can see: nothing has gone in at OUR
        // end. It says nothing about whether we have scored, so it is never
        // "nil-nil" here.
        let clean = t.conceded == 0
        switch t.state {
        case "ahead":
            return clean ? "If we're ahead at half-time and haven't let one in"
                         : "If we're ahead at half-time"
        case "level":
            return clean ? "If it's level at half-time with nothing let in"
                         : "If it's level at half-time"
        case "behind":
            return "If we're behind at half-time"
        default:
            if clean { return "If we haven't let one in by half-time" }
            if let n = t.conceded { return "If we've let \(n) in by half-time" }
            return "At half-time"
        }
    }

    private static func fulltimeMoment(_ t: LingoCallTrigger) -> String {
        if t.comeback == true {
            return t.state == nil || t.state == "win"
                ? "If we come from behind to win" : "If we come from behind"
        }
        let sheet: String
        switch t.cleanSheet {
        case true?:  sheet = " without letting one in"
        case false?: sheet = " having let one in"
        default:     sheet = ""
        }
        switch t.state {
        case "win":  return "If we win" + sheet
        case "draw": return "If it's a draw" + sheet
        case "loss": return "If we lose" + sheet
        default:
            switch t.cleanSheet {
            case true?:  return "If we keep a clean sheet"
            case false?: return "If we let one in"
            default:     return "At full-time"
            }
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

    /// Does every moment that satisfies `a` also satisfy `b`?
    ///
    /// Two lines on one slip where this holds are one bet wearing two hats:
    /// `{fulltime, state: win, cleanSheet: true}` cannot land without
    /// `{fulltime, cleanSheet: true}` landing with it, so a slip carrying both
    /// marks two lines for one event and reads as a slip that came in twice.
    /// The reveal is where it shows, and it showed.
    ///
    /// Read off the closed grammar, constraint by constraint: for each thing
    /// `b` states, `a` must state the same or tighter. A constraint `b` leaves
    /// out is don't-care and is satisfied by anything; one `a` leaves out
    /// cannot satisfy a stated one, because `resolve` refuses a stated
    /// constraint against an unknown outcome field and `a` therefore admits
    /// moments `b` would turn down. `any` on `side` and `scorerRole` is the
    /// explicit spelling of absent, so it reads as don't-care on both sides.
    ///
    /// Minutes are the one constraint that is not simple equality: a window has
    /// to sit inside the other window, so `minuteFrom: 88` implies
    /// `minuteFrom: 85` and not the other way round.
    ///
    /// Reflexive on purpose (a trigger implies itself), so the same line twice
    /// is caught by the same test that catches a superset.
    static func implies(_ a: LingoCallTrigger?, _ b: LingoCallTrigger?) -> Bool {
        guard let a, let b, let kind = a.kind.flatMap(Kind.init(rawValue:)),
              kind == b.kind.flatMap(Kind.init(rawValue:)) else { return false }
        /// What `b` asks for is either not asked for, or asked for identically.
        func holds<T: Equatable>(_ wanted: T?, _ stated: T?) -> Bool { wanted == nil || wanted == stated }

        switch kind {
        case .goal:
            guard holds(named(b.side), named(a.side)),
                  holds(named(b.scorerRole), named(a.scorerRole)),
                  holds(b.penalty, a.penalty), holds(b.ownGoal, a.ownGoal) else { return false }
            if let from = b.minuteFrom { guard let mine = a.minuteFrom, mine >= from else { return false } }
            if let to = b.minuteTo { guard let mine = a.minuteTo, mine <= to else { return false } }
            return true
        case .halftime:
            return holds(b.state, a.state) && holds(b.conceded, a.conceded)
        case .fulltime:
            return holds(b.state, a.state) && holds(b.cleanSheet, a.cleanSheet)
                && holds(b.comeback, a.comeback)
        }
    }

    /// Would these two lines land together, whichever way round the implication
    /// runs? Then they are not two bets and they do not share a slip.
    static func clash(_ a: LingoCall, _ b: LingoCall) -> Bool {
        implies(a.trigger, b.trigger) || implies(b.trigger, a.trigger)
    }

    /// Three lines for this fixture: one banker, one likely, one long shot, in
    /// that order, filtered by the context's tags and seeded by `fixtureKey` so
    /// a slip she comes back to is the slip she left.
    ///
    /// No two of them can land on the same moment (`clash`). Having drawn the
    /// banker, a likely that implies it or is implied by it is skipped, and the
    /// long shot is drawn against both. A band with nothing legal left comes
    /// back empty and the slip is shorter, on the rule the banker already
    /// establishes: a short slip beats a dishonest one.
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

        func best(_ band: Band, avoiding chosen: [LingoCall]) -> LingoCall? {
            let banded = pool.filter { call in
                call.band == band.rawValue && !tags(call).isDisjoint(with: allow)
                    && !chosen.contains { clash(call, $0) }
            }
            guard !banded.isEmpty else { return nil }
            // A line about the game she is actually walking into beats a line
            // for any match; inside either group the draw is seeded, so the
            // same fixture offers the same slip every time it is drawn.
            let relevant = banded.filter { !tags($0).isDisjoint(with: live) }
            let group = relevant.isEmpty ? banded : relevant
            return group.min { draw(context.fixtureKey, $0) < draw(context.fixtureKey, $1) }
        }

        guard let banker = best(.banker, avoiding: []) else { return [] }
        var slip = [banker]
        if let likely = best(.likely, avoiding: slip) { slip.append(likely) }
        if let longshot = best(.longshot, avoiding: slip) { slip.append(longshot) }
        return slip
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
    // MARK: - Screenshot harness

    /// `-gdLingoCalls`. `lingo.json` publishes 59 calls, so this is no longer
    /// the only way to see a slip: it pins three fixture lines instead, for a
    /// shot that does not move when the content does. It changes nothing
    /// outside DEBUG and nothing about how a published call is offered,
    /// resolved or uploaded — the bands, the tags, the banker rule and the
    /// fixture gate all still apply to these.
    static let debugArgument = "-gdLingoCalls"

    /// `-gdLingoCallsPick`, which fills the slip in out of whatever content is
    /// loaded — the published calls unless `-gdLingoCalls` is there too. See
    /// `LingoView.debugPickCalls`.
    static let debugPickArgument = "-gdLingoCallsPick"

    /// Only the fixture lines. Kept separate from the pick flag so a slip can
    /// be filled in from the REAL deck, which is what a screenshot of the
    /// published content needs.
    static var debugRequested: Bool { ProcessInfo.processInfo.arguments.contains(debugArgument) }

    static var debugPickRequested: Bool { ProcessInfo.processInfo.arguments.contains(debugPickArgument) }

    /// One of each band, with triggers straight out of the contract: a goal for
    /// us, a clean sheet, and their forward scoring, which is the example the
    /// contract itself is written around. Nothing here says anything the feed
    /// cannot confirm.
    ///
    /// The clean sheet is deliberately the one a full-time result can resolve
    /// on its own (`outcomes(after:)`), so the reveal has something to mark.
    ///
    /// Unquoted, like the published 59: the card draws the quote marks itself,
    /// and a fixture that carried its own put a second pair on the screenshot.
    static let debugCalls: [LingoCall] = [
        LingoCall(id: "debug-we-score", line: "Get in. That's more like it.",
                  trigger: .init(kind: "goal", side: "us"), band: Band.banker.rawValue,
                  when: ["any"], termId: nil),
        LingoCall(id: "debug-clean-sheet", line: "Nothing let in. That'll do.",
                  trigger: .init(kind: "fulltime", cleanSheet: true), band: Band.likely.rawValue,
                  when: ["any"], termId: nil),
        LingoCall(id: "debug-their-forward", line: "We've given him far too much space there.",
                  trigger: .init(kind: "goal", side: "them", scorerRole: "Attacker"),
                  band: Band.longshot.rawValue, when: ["any", "opp-set-piece"], termId: "space"),
    ]

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
    ///
    /// `published` is whatever content is loaded, so the `moment` rules below
    /// are checked against the 59 lines actually on the device rather than
    /// against a fixture that cannot go out of date.
    @MainActor
    static func selfCheck(published: [LingoCall] = []) {
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
        // Three different bets, so nothing here is dropped for a clash: our
        // goal, level at half-time, and their penalty.
        let full = [call("b1", .banker), call("b2", .banker),
                    call("l1", .likely, trigger: .init(kind: "halftime", state: "level")),
                    call("s1", .longshot, trigger: .init(kind: "goal", side: "them", penalty: true))]

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

        // --- One bet, two hats -------------------------------------------------
        // The pair the reveal screenshot caught: a clean-sheet win cannot land
        // without the clean sheet landing with it, so the two never share a slip.
        let cleanSheet = LingoCallTrigger(kind: "fulltime", cleanSheet: true)
        let wonToNil = LingoCallTrigger(kind: "fulltime", state: "win", cleanSheet: true)
        assert(implies(wonToNil, cleanSheet), "a clean-sheet win does not imply a clean sheet")
        assert(!implies(cleanSheet, wonToNil), "a clean sheet was read as implying a win with it")
        assert(clash(call("a", .likely, trigger: cleanSheet), call("b", .longshot, trigger: wonToNil)),
               "the pair from the reveal shot is not a clash")

        // Same kind, and genuinely two bets: either side can score without the
        // other scoring.
        let weScore = LingoCallTrigger(kind: "goal", side: "us")
        let theyScore = LingoCallTrigger(kind: "goal", side: "them")
        assert(!implies(weScore, theyScore) && !implies(theyScore, weScore),
               "our goal and their goal were read as one event")
        // `any` is don't-care, so the narrower one implies the broader one.
        let anyoneScores = LingoCallTrigger(kind: "goal", side: "any", scorerRole: "any")
        assert(implies(weScore, anyoneScores), "our goal does not imply somebody scoring")
        assert(!implies(anyoneScores, weScore), "somebody scoring was read as implying it was us")
        // A stated constraint is never satisfied by an absent one.
        assert(implies(LingoCallTrigger(kind: "goal", side: "us", penalty: true), weScore),
               "our penalty does not imply our goal")
        assert(!implies(weScore, LingoCallTrigger(kind: "goal", side: "us", penalty: true)),
               "our goal was read as implying a penalty")
        // Minutes contain rather than match: 88 upwards sits inside 85 upwards.
        assert(implies(LingoCallTrigger(kind: "goal", minuteFrom: 88),
                       LingoCallTrigger(kind: "goal", minuteFrom: 85)),
               "the 88th minute is not inside the last five")
        assert(!implies(LingoCallTrigger(kind: "goal", minuteFrom: 85),
                        LingoCallTrigger(kind: "goal", minuteFrom: 88)),
               "the last five minutes was read as sitting inside the last two")

        // Across kinds, never: a goal and a full-time result are different
        // moments even when one always follows the other.
        assert(!implies(weScore, LingoCallTrigger(kind: "fulltime", state: "win"))
               && !implies(LingoCallTrigger(kind: "fulltime", state: "win"), weScore),
               "a goal and a full-time result were read as one moment")

        // And through the offer: the likely is the banker again in other words,
        // so it goes, and the long shot (a different kind of moment) stays.
        let doubled = offer(calls: [call("b1", .banker, trigger: anyoneScores),
                                    call("l1", .likely, trigger: weScore),
                                    call("s1", .longshot, trigger: .init(kind: "fulltime", state: "win"))],
                            context: fixture)
        assert(doubled.map(\.id) == ["b1", "s1"],
               "a likely implied by the banker stayed on the slip: \(doubled.map(\.id))")
        // Worth stating because it reshapes real slips: a banker as broad as
        // "somebody scores" swallows every other goal line on the card,
        // whichever side it is about, because they all land with it. The rest
        // of the slip then has to come from half-time and full-time.
        assert(offer(calls: [call("b1", .banker, trigger: anyoneScores),
                             call("s1", .longshot, trigger: theyScore)],
                     context: fixture).map(\.id) == ["b1"],
               "their goal shared a slip with somebody scoring")
        assert(offer(calls: [call("b1", .banker, trigger: anyoneScores),
                             call("l1", .likely, trigger: weScore)], context: fixture).map(\.id) == ["b1"],
               "a band with nothing legal left did not come back empty")
        // The invariant, stated where it can be read: no two lines on one slip
        // can land on the same moment.
        for (i, one) in slip.enumerated() {
            for other in slip.dropFirst(i + 1) {
                assert(!clash(one, other), "\(one.id) and \(other.id) landed on the same moment")
            }
        }

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

        // The empty slip she gets by saying no to all three is checked against
        // a real store in `myTurnSlipSelfCheck`, which is where the throwaway
        // one can be built.
        assert(matched(stored: MyTurnStore.MatchCalls(fixtureId: 1387422, fixtureKey: fixture.fixtureKey,
                                                      pickedIds: [], pickedAt: won),
                       fixtureId: 1387422, calls: picks, outcomes: win).isEmpty,
               "an empty slip marked a line as having come up")

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

        momentCheck(published: published)
    }

    /// How long a hand-written `situation` may be, and therefore how long the
    /// derived one is allowed to get: the card draws it on one or two lines
    /// above the quote, and a third line pushes the line itself under the fold.
    static let situationCap = 72

    /// `moment(trigger:)`: the shapes it has to render, and the two properties
    /// every card on the slip leans on.
    private static func momentCheck(published: [LingoCall]) {
        let table: [(LingoCallTrigger, String)] = [
            // Who scored, and for whom. `any` says nothing, the way it does
            // everywhere else.
            (.init(kind: "goal", side: "us"), "If we score"),
            (.init(kind: "goal", side: "them"), "If they score"),
            (.init(kind: "goal", side: "any", scorerRole: "any"), "If there's a goal"),
            (.init(kind: "goal", side: "them", scorerRole: "Attacker"),
             "If one of their forwards scores"),
            (.init(kind: "goal", side: "any", scorerRole: "Goalkeeper"), "If a keeper scores"),
            (.init(kind: "goal", side: "us", scorerRole: "Defender"),
             "If one of our defenders scores"),
            // An own goal is credited to the side that benefited, so this one
            // is OUR goal, put in by one of theirs. Getting it the wrong way
            // round is the whole reason it is in the table.
            (.init(kind: "goal", side: "us", ownGoal: true), "If one of theirs puts it in his own net"),
            (.init(kind: "goal", side: "them", ownGoal: true), "If one of ours puts it in his own net"),
            (.init(kind: "goal", side: "us", penalty: true), "If we score from the spot"),
            // Minutes are parts of a match, not numbers.
            (.init(kind: "goal", side: "any", minuteFrom: 90), "If there's a goal in added time"),
            (.init(kind: "goal", side: "us", minuteFrom: 88), "If we score in the last few minutes"),
            (.init(kind: "goal", side: "them", minuteFrom: 80), "If they score in the last ten minutes"),
            (.init(kind: "goal", side: "any", minuteFrom: 75), "If there's a goal late on"),
            (.init(kind: "goal", side: "us", minuteFrom: 46), "If we score after half-time"),
            (.init(kind: "goal", side: "them", minuteTo: 10), "If they score in the first ten minutes"),
            (.init(kind: "goal", side: "us", scorerRole: "Attacker", minuteTo: 20),
             "If one of our forwards scores in the first twenty minutes"),
            (.init(kind: "goal", side: "us", minuteTo: 45), "If we score before half-time"),
            (.init(kind: "goal", side: "any", minuteTo: 60), "If there's a goal in the first hour"),
            (.init(kind: "goal", side: "any", penalty: true, minuteFrom: 75),
             "If there's a goal from the spot late on"),
            // Half-time. `conceded: 0` is only that nothing has gone in at our
            // end — the feed cannot see from here whether we have scored, so
            // this must never read as nil-nil.
            (.init(kind: "halftime", state: "ahead"), "If we're ahead at half-time"),
            (.init(kind: "halftime", state: "level"), "If it's level at half-time"),
            (.init(kind: "halftime", state: "behind"), "If we're behind at half-time"),
            (.init(kind: "halftime", conceded: 0), "If we haven't let one in by half-time"),
            (.init(kind: "halftime", state: "ahead", conceded: 0),
             "If we're ahead at half-time and haven't let one in"),
            // Full-time.
            (.init(kind: "fulltime", state: "win"), "If we win"),
            (.init(kind: "fulltime", state: "draw"), "If it's a draw"),
            (.init(kind: "fulltime", state: "loss"), "If we lose"),
            (.init(kind: "fulltime", cleanSheet: true), "If we keep a clean sheet"),
            (.init(kind: "fulltime", state: "win", cleanSheet: true), "If we win without letting one in"),
            (.init(kind: "fulltime", state: "draw", cleanSheet: true),
             "If it's a draw without letting one in"),
            (.init(kind: "fulltime", comeback: true), "If we come from behind to win"),
            // Nothing stated is still a moment, and a kind this build cannot
            // resolve still has to render something rather than a blank line.
            (.init(kind: "fulltime"), "At full-time"),
            (.init(kind: "halftime"), "At half-time"),
            (.init(kind: "redcard"), "Some time in this match"),
        ]
        for (trigger, expected) in table {
            assert(moment(trigger) == expected,
                   "moment rendered \"\(moment(trigger))\" for \(trigger), expected \"\(expected)\"")
        }
        assert(!moment(nil).isEmpty, "a call with no trigger at all rendered nothing")

        // Every published line has a when, and one short enough to draw above
        // the quote. This is the property the whole fallback exists for.
        for call in published where usable(call) {
            let text = moment(call.trigger)
            assert(!text.isEmpty, "\(call.id) has no moment, so its card would carry a blank line")
            assert(text.count <= situationCap,
                   "\(call.id)'s moment runs to \(text.count) characters: \"\(text)\"")
        }

        // Two lines that READ the same must be two lines that can never share
        // a slip, or the card asks her the same question twice in other words.
        // `clash` is what `offer` filters on, so this is the check that ties
        // the sentence back to the rule.
        for (i, one) in published.enumerated() where usable(one) {
            for other in published.dropFirst(i + 1) where usable(other) {
                guard moment(one.trigger) == moment(other.trigger) else { continue }
                assert(clash(one, other),
                       "\(one.id) and \(other.id) both read \"\(moment(one.trigger))\" and can share a slip")
            }
        }
    }
}
#endif
