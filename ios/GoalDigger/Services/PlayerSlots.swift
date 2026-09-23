import Foundation

/// A real player from the actual fixture, in a Lingo card.
///
/// Static content may never name a current player (CONTENT_PRINCIPLES.md §4: a
/// name goes stale the week he is sold, and the file ships in the binary), so
/// a term carries a `playerVariant` with a `{slot}` token instead and the
/// phone fills it. Same escape hatch `LiveClubPack.positionUse` already uses in
/// Quiz, and the same four archetypes, because `players.position` has exactly
/// four values and nothing else about a man's job is trustworthy.
///
/// Pure and deterministic: the same inputs and the same seed give the same
/// cards, which is what lets a paused round come back with the same names on
/// it. Nothing here reads the network, the clock or the store, so the table
/// test at the bottom is the whole test.
///
/// Rules that are not negotiable:
/// - **A templated line may only say what the data we hold actually says about
///   him: his position, his club, that he is in the squad, and his shirt
///   number. Nothing else.** Not what he did, not what he will do, and not what
///   he is like — no form, reputation, quality or fitness. "{theirs.forward} is
///   their target man" holds because position is data. "They're strong from set
///   pieces. Watch the corners." reads perfectly and is groundless: API-Football
///   sells us no style-of-play data at all, and `teams/statistics` — the closest
///   endpoint — was last fetched in April and has no set-piece breakdown
///   anyway. A named line that cannot be sourced is the app putting a false
///   sentence in her partner's mouth, and it collapses the moment she repeats
///   it back to him. `players` also has no injury or suspension column, so
///   every line must still read correctly with him on the bench.
/// - **The opponent is gated on the context, not on the page.** `onesToKnow.
///   opponent` is rebuilt against `next_fixture`, and `MatchContext` walks away
///   from `next_fixture` when a fixture is postponed or its calendar row has
///   aged out. Printing an Everton player's name before a Fulham match is the
///   worst thing this feature can do.
/// - `minutes > 0` for anyone out of the squad table. A squad can carry a man
///   who has left (DATA_SOURCES.md), and nil minutes is unknown, not zero.
/// - A surname is a name only when one man in the source carries it, and a man
///   the feed lists twice by his whole name is dropped: nothing we can print
///   separates Spurs' two "T. Hall".
/// - At most `maxPlayerCards` of the seven, one a side. One named card is
///   invisible; three turns a vocabulary round into the squad quiz.
enum PlayerSlots {
    // MARK: Slots

    enum Side: String, CaseIterable { case ours, theirs }
    enum Archetype: String, CaseIterable { case keeper, defender, midfielder, forward }

    /// One of the eight. Parsed from the raw string a variant carries; nil for
    /// anything this build does not know, which then never resolves.
    struct Slot: Hashable {
        let side: Side
        let archetype: Archetype

        init(_ side: Side, _ archetype: Archetype) { self.side = side; self.archetype = archetype }

        init?(_ raw: String) {
            let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 2, let side = Side(rawValue: String(parts[0])),
                  let archetype = Archetype(rawValue: String(parts[1])) else { return nil }
            self.init(side, archetype)
        }

        var raw: String { "\(side.rawValue).\(archetype.rawValue)" }
    }

    /// A man we can print, and where he can stand.
    struct Named: Equatable {
        /// Who he is, for claiming him once across every source that offers
        /// him. His folded surname: the squad table writes "M. Ødegaard" and
        /// the curated card writes "Martin Ødegaard", and they are one player.
        let key: String
        /// What goes on screen.
        let display: String
        let slot: Slot
        /// Which source he came from, lower first. Only a sort key.
        let tier: Int
    }

    /// Longer than this and the bubble runs to four lines, which is what makes
    /// the content validator's worst-case arithmetic a guarantee rather than a
    /// hope.
    static let nameCap = 22
    /// Two of the seven.
    static let maxPlayerCards = 2

    // MARK: Inputs

    /// Everything the resolver needs, as plain values. No services, no cache,
    /// no page: the call site does the reaching, this does the deciding.
    struct Inputs {
        /// His club's cached squad rows (`LiveSquadService.players`).
        var squad: [LiveSquadPack.Player] = []
        /// His team page's three curated players (`ones_to_know.players`).
        var ourCurated: [TopPlayer] = []
        /// The opponent's two league picks, from the league-wide cache.
        var theirPicks: [LiveSquadPack.Player] = []
        /// The gated `ones_to_know.opponent.players` first (see
        /// `opponentCurated(page:context:)`), then the opponent's own curated
        /// three out of the cached team-page slices.
        var theirCurated: [TopPlayer] = []
        /// False when the context has no opponent to prepare for at all, which
        /// empties every `theirs` slot whatever the caches happen to hold.
        var opponentKnown: Bool = false
    }

    // MARK: Names

    /// How a set of feed names prints: keyed by the name as the feed wrote it,
    /// missing entirely for anyone who cannot be printed unambiguously.
    ///
    /// The surname where one man in this source carries it, the whole name
    /// where two do, and nothing at all where the feed repeats a whole name.
    /// `LiveSquadPack.build` prints squad names through this same function so
    /// the quiz and the round cannot disagree about what to call him.
    static func displayNames(_ names: [String]) -> [String: String] {
        var shortCounts: [String: Int] = [:], fullCounts: [String: Int] = [:]
        for n in names where !n.isEmpty {
            shortCounts[LiveClubPack.shortName(n), default: 0] += 1
            fullCounts[n, default: 0] += 1
        }
        var out: [String: String] = [:]
        for n in names where !n.isEmpty && fullCounts[n] == 1 {
            let short = LiveClubPack.shortName(n)
            out[n] = shortCounts[short] == 1 ? short : n
        }
        return out
    }

    /// The claim key: his folded surname, so one man offered by two sources is
    /// still one man.
    static func key(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
            .lowercased().split(separator: " ").last.map(String.init) ?? ""
    }

    /// The four buckets, from either vocabulary. `players.position` only ever
    /// holds Goalkeeper, Defender, Midfielder or Attacker; the curated cards
    /// carry free-text plain English. Anything else, or nothing at all, is nil
    /// and the man is unusable for a slot — a guess here would put a keeper's
    /// line under a winger's name.
    static func archetype(_ raw: String?) -> Archetype? {
        switch (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "goalkeeper", "keeper":
            return .keeper
        case "defender", "centre-back", "center-back", "full-back", "fullback", "wing-back", "wingback":
            return .defender
        case "midfielder", "midfield":
            return .midfielder
        case "attacker", "forward", "striker", "winger":
            return .forward
        default:
            return nil
        }
    }

    // MARK: Pools

    /// Every man who could stand in each slot, best first.
    ///
    /// `ours`: his squad on `minutes > 0`, most minutes first, then his three
    /// curated players. `theirs`: the opponent's league picks, then the gated
    /// opponent side and the opponent's own curated three — and nothing at all
    /// when the context has no opponent.
    static func pools(_ inputs: Inputs,
                      print printer: ([String]) -> [String: String] = displayNames) -> [Slot: [Named]] {
        var out: [Slot: [Named]] = [:]

        func add(_ side: Side, _ tier: Int, _ candidates: [(name: String, position: String?)]) {
            let printable = printer(candidates.map(\.name))
            for c in candidates {
                guard let display = printable[c.name], display.count <= nameCap,
                      let archetype = archetype(c.position) else { continue }
                let slot = Slot(side, archetype)
                let man = Named(key: key(c.name), display: display, slot: slot, tier: tier)
                guard !man.key.isEmpty else { continue }
                out[slot, default: []].append(man)
            }
        }

        // A squad row can be a man who has left; `minutes > 0` is what every
        // customer-facing surface reads, and nil is unknown rather than zero.
        // Sorted by minutes, with the id breaking a tie so two men on the same
        // total do not swap places between launches.
        let playing = inputs.squad
            .filter { ($0.minutes ?? 0) > 0 && !$0.name.isEmpty }
            .sorted { ($0.minutes ?? 0, -$0.api_player_id) > ($1.minutes ?? 0, -$1.api_player_id) }
        add(.ours, 0, playing.map { ($0.name, $0.position) })
        add(.ours, 1, inputs.ourCurated.map { ($0.name, $0.position) })

        if inputs.opponentKnown {
            let theirs = inputs.theirPicks
                .filter { ($0.minutes ?? 0) > 0 && !$0.name.isEmpty }
                .sorted { ($0.minutes ?? 0, -$0.api_player_id) > ($1.minutes ?? 0, -$1.api_player_id) }
            add(.theirs, 0, theirs.map { ($0.name, $0.position) })
            add(.theirs, 1, inputs.theirCurated.map { ($0.name, $0.position) })
        }

        for (slot, men) in out { out[slot] = men.sorted { $0.tier < $1.tier } }
        return out
    }

    // MARK: The opponent gate

    /// The opponent's curated players off *his* team page, and only when the
    /// page is talking about the club the context is walking into.
    ///
    /// `ones_to_know.opponent` is rebuilt against `next_fixture`, which carries
    /// no status: a postponed game sits there with a date that has gone by, and
    /// `MatchContext` deliberately steps past it to the next fixture the
    /// calendar still believes in (`LingoFixtures.page("postponed")` and
    /// `("phantom")` are exactly that). Without this check the round would name
    /// a Chelsea player before a Fulham match.
    static func opponentCurated(page: TeamPageContent?, context: MatchContext?) -> [TopPlayer] {
        guard let side = page?.cards.onesToKnow?.opponent, let opponent = opponent(of: context),
              MatchContext.sameClub(side.teamName, opponent) else { return [] }
        return side.players
    }

    /// Who she is about to watch them play, or nil. Only `.before`: a name for
    /// a game already played is a line with nowhere to go.
    static func opponent(of context: MatchContext?) -> String? {
        guard let context, case .before(let opponent, _) = context.phase,
              !opponent.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return opponent
    }

    // MARK: Assignment

    /// A card that came out named.
    struct Resolved: Equatable {
        let variant: LingoTerm.PlayerVariant
        let named: Named
    }

    /// Which of the dealt words get a name, keyed by term id.
    ///
    /// Walks the deck in dealt order, so the relevance ordering the deck spent
    /// its whole build on survives: the first word that can be named is. Each
    /// man is claimed once, no slot is used twice, and when both sides have a
    /// pool the two cards are one a side.
    static func assign(_ dealt: [LingoTerm], pools: [Slot: [Named]], seed: String) -> [String: Resolved] {
        guard !pools.isEmpty else { return [:] }
        let bothSides = Side.allCases.allSatisfy { side in pools.keys.contains { $0.side == side } }

        var out: [String: Resolved] = [:]
        var claimed: Set<String> = [], usedSlots: Set<Slot> = [], usedSides: Set<Side> = []

        for term in dealt where out.count < maxPlayerCards {
            guard let variants = term.playerVariants, !variants.isEmpty else { continue }
            // A term may carry two variants (one a side). Which one it offers
            // first is seeded, so the same fixture deals the same card twice.
            var rng = LiveClubPack.SeededGenerator(seed: seed + "|" + term.id)
            for variant in variants.shuffled(using: &rng) {
                guard let slot = Slot(variant.slot), !usedSlots.contains(slot),
                      !(bothSides && usedSides.contains(slot.side)) else { continue }
                // The contract says the token appears in `overheard`. This is
                // downloaded content, so check rather than trust: a variant
                // that prints no name would spend one of the two cards on a
                // line indistinguishable from the plain one.
                guard variant.overheard.contains("{\(variant.slot)}"),
                      let man = pools[slot]?.first(where: { !claimed.contains($0.key) }) else { continue }
                out[term.id] = Resolved(variant: variant, named: man)
                claimed.insert(man.key); usedSlots.insert(slot); usedSides.insert(slot.side)
                break
            }
        }
        return out
    }

    /// The dealt words, with at most two of them naming a real player.
    /// Returns the input unchanged when nothing resolves, which is the cold
    /// start, the off-season and every term published without a variant.
    static func apply(_ dealt: [LingoTerm], inputs: Inputs, seed: String,
                      print printer: ([String]) -> [String: String] = displayNames) -> [LingoTerm] {
        let picks = assign(dealt, pools: pools(inputs, print: printer), seed: seed)
        guard !picks.isEmpty else { return dealt }
        return dealt.map { term in
            picks[term.id].map { term.naming($0.named.display, $0.variant) } ?? term
        }
    }

    // MARK: - Table test

    #if DEBUG
    /// Runs once from `lingoDeckSelfCheck` under an assert. Cheap: a dozen rows
    /// and a handful of synthetic terms.
    static func selfCheck() -> Bool {
        func p(_ id: Int, _ name: String, _ position: String?, minutes: Int?) -> LiveSquadPack.Player {
            LiveSquadPack.Player(api_player_id: id, name: name, position: position, photo_url: nil,
                                 number: nil, appearances: nil, minutes: minutes)
        }
        func t(_ id: String, _ variants: [LingoTerm.PlayerVariant]?) -> LingoTerm {
            LingoTerm(id: id, category: .tactics, term: "target man", meaning: "m", heard: "h",
                      sayIt: "Plain \(id).", seeAlso: nil, level: 1,
                      overheard: "Plain \(id), that.", overheardTerm: "target man", speaker: .him,
                      gist: "g", decoy: "d1", spare: "d2", when: ["any"], basic: nil, moment: "common",
                      playerVariants: variants)
        }
        func variant(_ slot: String) -> LingoTerm.PlayerVariant {
            .init(slot: slot,
                  overheard: "You need a target man in this league. {\(slot)} is one.",
                  overheardTerm: "target man",
                  sayIt: "\u{201C}{\(slot)} is their target man.\u{201D}")
        }
        let theirForward = variant("theirs.forward")
        let ourMid = variant("ours.midfielder")

        // The happy path: one ours card and one theirs card, both named.
        let squad = [p(1, "M. Odegaard", "Midfielder", minutes: 400),
                     p(2, "D. Raya", "Goalkeeper", minutes: 360),
                     p(3, "W. Saliba", "Defender", minutes: 300)]
        let base = Inputs(squad: squad,
                          theirPicks: [p(9, "R. Kolo Muani", "Attacker", minutes: 500)],
                          opponentKnown: true)
        let deck = [t("a", [theirForward]), t("b", [ourMid]), t("c", nil)]
        let out = apply(deck, inputs: base, seed: "f|0")
        guard out.count == 3,
              out[0].overheard?.contains("Kolo Muani") == true,
              out[0].sayIt?.contains("Kolo Muani") == true,
              out[1].overheard?.contains("Odegaard") == true,
              out[2] == deck[2] else { return false }
        // The bolded phrase still exists in the resolved line, and does not
        // land inside the name that was substituted in — a `range(of:)` that
        // hit the name would bold half a real person.
        guard let needle = out[0].overheardTerm, let line = out[0].overheard,
              let bold = line.range(of: needle), let name = line.range(of: "Kolo Muani"),
              String(line[bold]) == "target man", !bold.overlaps(name) else { return false }

        // Two men with the same surname: neither prints it, and both print
        // short enough to stay usable.
        let christies = [p(4, "R. Christie", "Midfielder", minutes: 300),
                         p(5, "Z. Christie", "Midfielder", minutes: 200)]
        let shared = apply([t("b", [ourMid])], inputs: Inputs(squad: christies), seed: "f|0")
        guard shared[0].overheard?.contains("R. Christie") == true,
              shared[0].overheard?.contains("{ours.midfielder}") == false else { return false }
        guard displayNames(christies.map(\.name))["R. Christie"] == "R. Christie" else { return false }

        // The feed listing one name twice: nothing we can print separates them,
        // so both go, and the plain line comes back.
        let halls = [p(6, "T. Hall", "Midfielder", minutes: 300), p(7, "T. Hall", "Midfielder", minutes: 200)]
        guard apply([t("b", [ourMid])], inputs: Inputs(squad: halls), seed: "f|0") == [t("b", [ourMid])],
              displayNames(halls.map(\.name)).isEmpty else { return false }

        // The stray player: a man on zero minutes has left, and one on nil has
        // not synced. Neither resolves.
        for stray in [p(8, "S. Stray", "Midfielder", minutes: 0), p(8, "S. Stray", "Midfielder", minutes: nil)] {
            guard apply([t("b", [ourMid])], inputs: Inputs(squad: [stray]), seed: "f|0") == [t("b", [ourMid])] else { return false }
        }

        // No opponent: every `theirs` slot is empty and a theirs-only deck
        // comes back byte-identical.
        let noOpponent = Inputs(squad: squad, theirPicks: [p(9, "R. Kolo Muani", "Attacker", minutes: 500)],
                                opponentKnown: false)
        guard pools(noOpponent).keys.allSatisfy({ $0.side == .ours }),
              apply([t("a", [theirForward])], inputs: noOpponent, seed: "f|0") == [t("a", [theirForward])] else { return false }

        // The WRONG opponent. The page's `ones_to_know.opponent` was rebuilt
        // against a fixture that was then postponed; the context has moved on
        // to Fulham. Naming a Chelsea player here is the worst outcome there is.
        let now = MatchContext.parseISO("2026-10-17T12:00:00Z")!
        let pst = MatchContext(page: LingoFixtures.page("postponed", now: now), team: .arsenal, now: now)
        let chelseaSide = """
        {"schema_version":1,"cards":{"ones_to_know":{"players":[],
          "opponent":{"team_name":"Chelsea","players":[
            {"name":"Cole Palmer","position":"winger","one_liner":"x"}]}}}}
        """
        let sidePage = try? JSONDecoder().decode(TeamPageContent.self, from: Data(chelseaSide.utf8))
        guard sidePage?.cards.onesToKnow?.opponent?.players.isEmpty == false,
              opponent(of: pst).map({ MatchContext.sameClub($0, "Fulham") }) == true,
              opponentCurated(page: sidePage, context: pst).isEmpty else { return false }
        // The derby context is Tottenham, so the Chelsea card is still refused
        // there — and the gate is not simply always empty: swap the card for
        // the club the context names and it opens.
        let derby = MatchContext(page: LingoFixtures.page("derby", now: now), team: .arsenal, now: now)
        let spursSide = chelseaSide.replacingOccurrences(of: "Chelsea", with: "Tottenham Hotspur")
        let spursPage = try? JSONDecoder().decode(TeamPageContent.self, from: Data(spursSide.utf8))
        guard opponentCurated(page: sidePage, context: derby).isEmpty,
              opponentCurated(page: spursPage, context: derby).count == 1,
              opponentCurated(page: spursPage, context: pst).isEmpty,
              opponentCurated(page: spursPage, context: nil).isEmpty else { return false }

        // One usable forward and two terms that both want him: only one card
        // is named, because a man is claimed once and a slot is used once.
        let oneForward = Inputs(theirPicks: [p(9, "R. Kolo Muani", "Attacker", minutes: 500)], opponentKnown: true)
        let greedy = apply([t("a", [theirForward]), t("a2", [theirForward])], inputs: oneForward, seed: "f|0")
        guard greedy.filter({ $0.overheard?.contains("Kolo Muani") == true }).count == 1 else { return false }

        // The cap of two, and never both on one side when both sides can fill.
        let many = (0..<6).map { t("m\($0)", [theirForward, ourMid]) }
        let capped = apply(many, inputs: base, seed: "f|0")
        let named = capped.filter { $0.overheard?.hasPrefix("You need") == true }
        guard named.count == maxPlayerCards,
              named.contains(where: { $0.overheard?.contains("Kolo Muani") == true }),
              named.contains(where: { $0.overheard?.contains("Odegaard") == true }) else { return false }

        // Determinism: one seed, one answer. A different seed is still a legal
        // round (two cards, one a side) rather than anything at all.
        guard apply(many, inputs: base, seed: "f|0") == capped else { return false }
        for n in 0..<8 {
            let other = apply(many, inputs: base, seed: "f|\(n)")
            guard other.filter({ $0.overheard?.hasPrefix("You need") == true }).count == maxPlayerCards else { return false }
        }

        // The name cap: forty characters is a bubble at four lines.
        let long = p(10, "Maximilian Wolfeschlegelsteinhausenberger", "Midfielder", minutes: 500)
        guard long.name.count >= 40,
              apply([t("b", [ourMid])], inputs: Inputs(squad: [long]), seed: "f|0") == [t("b", [ourMid])] else { return false }

        // Cold start: nothing cached, nothing to say, the deck comes back as it
        // went in. And a slot this build has never heard of never resolves.
        guard apply(deck, inputs: Inputs(), seed: "f|0") == deck,
              pools(Inputs()).isEmpty else { return false }
        let unknownSlot = LingoTerm.PlayerVariant(slot: "ours.sweeper", overheard: "{ours.sweeper} is one.",
                                                  overheardTerm: nil, sayIt: "{ours.sweeper}.")
        guard Slot("ours.sweeper") == nil, Slot("midfielder") == nil, Slot("theirs") == nil,
              apply([t("b", [unknownSlot])], inputs: base, seed: "f|0") == [t("b", [unknownSlot])] else { return false }
        // A variant whose line never prints the name is not worth a card.
        let tokenless = LingoTerm.PlayerVariant(slot: "ours.midfielder", overheard: "No name here.",
                                                overheardTerm: nil, sayIt: "{ours.midfielder}.")
        guard apply([t("b", [tokenless])], inputs: base, seed: "f|0") == [t("b", [tokenless])] else { return false }

        // The position table, both vocabularies at once.
        let table: [(String?, Archetype?)] = [
            ("Goalkeeper", .keeper), ("goalkeeper", .keeper), ("Keeper", .keeper),
            ("Defender", .defender), ("centre-back", .defender), ("Full-back", .defender),
            ("Midfielder", .midfielder), ("midfield", .midfielder),
            ("Attacker", .forward), ("Forward", .forward), ("striker", .forward), ("Winger", .forward),
            ("Sweeper", nil), ("", nil), (nil, nil), ("Left Wing", nil),
        ]
        for (raw, want) in table where archetype(raw) != want { return false }
        guard Slot("theirs.forward")?.raw == "theirs.forward" else { return false }
        return true
    }

    // MARK: - Screenshot harness

    /// `-gdLingoPlayerVariant`. No published term carries a `playerVariants`
    /// key yet, so there is nothing on the device to photograph: this hangs one
    /// variant on each of the first two dealt words and hands the resolver a
    /// fixture squad and a fixture opponent, which is enough for a shot of a
    /// named card. It changes nothing outside DEBUG and nothing about how a
    /// real variant resolves.
    static let debugArgument = "-gdLingoPlayerVariant"

    static var debugRequested: Bool { ProcessInfo.processInfo.arguments.contains(debugArgument) }

    /// The fixture lines say nothing the squad table cannot back: which end of
    /// the pitch he plays at, and then a question, which cannot be wrong and is
    /// on voice. An earlier draft appended "{slot} will punish that." to the
    /// dealt word's own line, which reports one event and predicts another —
    /// the exact failure mode a templated line has to avoid, in a fixture whose
    /// whole job is to be photographed. A line may only say what we hold about
    /// him: his position, his club, that he is in the squad, his shirt number.
    /// It must also read correctly with him on the bench, because `players`
    /// has no injury or suspension column.
    static func debugInjected(_ dealt: [LingoTerm]) -> [LingoTerm] {
        let fixtures = [
            (slot: "theirs.forward",
             says: "{theirs.forward} plays up front for them.",
             asks: "Is {theirs.forward} the one they play up front?"),
            (slot: "ours.midfielder",
             says: "{ours.midfielder} is one of ours in midfield.",
             asks: "Is {ours.midfielder} in midfield for us?"),
        ]
        return dealt.enumerated().map { i, term in
            guard i < fixtures.count, let line = term.overheard else { return term }
            let f = fixtures[i]
            return LingoTerm(
                id: term.id, category: term.category, term: term.term, meaning: term.meaning,
                heard: term.heard, sayIt: term.sayIt, seeAlso: term.seeAlso, level: term.level,
                overheard: term.overheard, overheardTerm: term.overheardTerm, speaker: term.speaker,
                gist: term.gist, decoy: term.decoy, spare: term.spare, when: term.when, basic: term.basic,
                moment: term.moment,
                playerVariants: [.init(slot: f.slot,
                                       overheard: line + " " + f.says,
                                       overheardTerm: term.overheardTerm,
                                       sayIt: LiveClubPack.quote(f.asks))])
        }
    }

    /// Arsenal and Spurs, close enough to the real rows to be a fair picture.
    static let debugInputs = Inputs(
        squad: [
            LiveSquadPack.Player(api_player_id: 1, name: "M. Odegaard", position: "Midfielder",
                                 photo_url: nil, number: nil, appearances: 4, minutes: 400),
            LiveSquadPack.Player(api_player_id: 2, name: "D. Raya", position: "Goalkeeper",
                                 photo_url: nil, number: nil, appearances: 4, minutes: 360),
            LiveSquadPack.Player(api_player_id: 3, name: "W. Saliba", position: "Defender",
                                 photo_url: nil, number: nil, appearances: 4, minutes: 340),
        ],
        theirPicks: [
            LiveSquadPack.Player(api_player_id: 9, name: "D. Solanke", position: "Attacker",
                                 photo_url: nil, number: nil, appearances: 5, minutes: 420),
        ],
        opponentKnown: true)
    #endif
}
